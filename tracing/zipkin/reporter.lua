local fun = require('fun')
local json = require('json')
local checks = require('checks')
local httpc = require('http.client')
local bounded_queue = require('zipkin.bounded_queue')

local Reporter = {}

local DEFAULT_SPANS_LIMIT = 1e3

local span_kind_map = {
    client = "CLIENT",
    server = "SERVER",
    producer = "PRODUCER",
    consumer = "CONSUMER",
}

local function format_span(span)
    local ctx = span:context()
    local tags = {}

    for k, v in span:each_tag() do
        -- Zipkin tag values should be strings
        -- see https://zipkin.io/zipkin-api/#/default/post_spans
        -- and https://github.com/Kong/kong-plugin-zipkin/pull/13#issuecomment-402389342
        tags[k] = tostring(v)
    end

    local span_kind  = tags['span.kind']
    tags['span.kind'] = nil

    local localEndpoint = json.null
    local serviceName = tags["component"]
    if serviceName ~= nil then
        tags["component"] = nil
        localEndpoint = {
            serviceName = serviceName,
        }
    end

    local remoteEndpoint = json.null
    local peer_port = span:get_tag("peer.port") -- get as number
    if peer_port ~= nil then
        tags["peer.port"] = nil
        remoteEndpoint = {
            serviceName = tags["peer.service"],
            ipv4 = tags["peer.ipv4"],
            ipv6 = tags["peer.ipv6"],
            port = peer_port, -- port is *not* optional
        }
        tags["peer.ipv4"] = nil
        tags["peer.ipv6"] = nil
        tags["peer.service"] = nil
    end

    return {
        traceId = ctx.trace_id,
        name = span.name,
        parentId = ctx.parent_id,
        id = ctx.span_id,
        kind = span_kind_map[span_kind],
        timestamp = span.timestamp,
        duration = span.duration,
        debug = span:get_baggage_item('debug'),
        -- TODO: set if there is remote call
        shared = false,
        localEndpoint = localEndpoint,
        remoteEndpoint = remoteEndpoint,
        annotations = span.logs,
        tags = setmetatable(tags, json.map_mt),
    }
end

local DEFAULT_HTTP_TIMEOUT = 5
local function send_traces(self, traces)
    if self._client == nil then
        self._client = httpc.new()
    end
    local client = self._client

    local ok, data = pcall(json.encode, traces)
    if not ok then
        self.on_error(data)
        return
    end

    local headers = {['Content-Type'] = 'application/json'}
    local ok, result = pcall(client.request, client, self.api_method, self.base_url, data,
            { headers = headers, timeout = DEFAULT_HTTP_TIMEOUT })
    if not ok then
        self.on_error(result)
        return
    end
    if result.status < 200 or 300 <= result.status then
        self.on_error(('%s [%s] (%s)'):format(result.reason, result.status, result.body))
    end
end

local function background_report(self, span)
    self.spans:push(span)
end

local function immediately_report(self, span)
    self:send_traces({format_span(span)})
end

-- Should we clear spans after unsuccessful request to zipkin?
local function flush(self)
    local spans = self.spans:dump()
    local formatted_spans = fun.iter(spans):map(format_span):totable()
    if #spans > 0 then
        self.spans:clear()
    end
    return formatted_spans
end

local function check_api_method(method)
    local available_methods = {
        ['POST'] = true,
        ['GET'] = true,
        ['PUT'] = true,
    }
    return available_methods[method]
end

function Reporter.new(config)
    checks({ base_url = 'string',
             api_method = 'string',
             report_interval = 'number',
             spans_limit = '?number',
             on_error = '?function' })
    if not check_api_method(config.api_method) then
        local error_str = config.api_method .. ' is invalid API method. Use POST, GET or PUT'
        return nil, error_str
    end

    local self = {
        spans = bounded_queue.new(config.spans_limit or DEFAULT_SPANS_LIMIT),
        base_url = config.base_url,
        api_method = config.api_method,
        report_interval = config.report_interval,
        on_error = config.on_error or function() end,
        flush = flush,
        send_traces = send_traces,
    }

    if self.report_interval > 0 then
        self.report = background_report
    else
        self.report = immediately_report
    end

    return self
end

return Reporter
