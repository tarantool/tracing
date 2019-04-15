local fun = require('fun')
local log = require('log')
local json = require('json')
local httpc = require('http.client')

local Reporter = {}

local span_kind_map = {
	client = "CLIENT";
	server = "SERVER";
	producer = "PRODUCER";
	consumer = "CONSUMER";
}

local function format_span(span)
    local ctx = span:context()
    local tags = {}

    -- TODO: export tags as strings
	for k, v in span:each_tag() do
		-- Zipkin tag values should be strings
		-- see https://zipkin.io/zipkin-api/#/default/post_spans
		-- and https://github.com/Kong/kong-plugin-zipkin/pull/13#issuecomment-402389342
		tags[k] = tostring(v)
	end

    local span_kind  = tags['span.kind']
    tags['span.kind'] = nil

    local localEndpoint = json.null
	local serviceName = tags["peer.service"]
	if serviceName ~= nil then
		tags["peer.service"] = nil
		localEndpoint = {
			serviceName = serviceName,
		}
	end

    local remoteEndpoint = json.null
	local peer_port = span:get_tag("peer.port") -- get as number
	if peer_port ~= nil then
		tags["peer.port"] = nil
		remoteEndpoint = {
			ipv4 = tags["peer.ipv4"],
			ipv6 = tags["peer.ipv6"],
			port = peer_port; -- port is *not* optional
		}
		tags["peer.ipv4"] = nil
		tags["peer.ipv6"] = nil
	end

    return {
        traceId = string.hex(ctx.trace_id),
        name = span.name,
        parentId = ctx.parent_id and string.hex(ctx.parent_id) or nil,
        id = string.hex(ctx.span_id),
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

local reporter_mt = {}
reporter_mt.__index = reporter_mt

function reporter_mt.send_traces(reporter, traces)
    local client = httpc.new()
    local ok, data = pcall(json.encode, traces)
    if not ok then
        log.error('Handler error: %s', data)
        return
    end

    local result = client:request(reporter.api_method, reporter.base_url, data)
    if 200 > result.status or result.status >= 300 then
        log.error('Handler http request error: %s [%s] (%s)',
                result.reason, result.status, result.body)
    else
        log.info('Report %d spans to zipkin [%s]', #traces, result.status)
    end
end

-- Should we persist it?
local function background_report(self, span)
    table.insert(self.spans, span)
end

local function cli_report(self, span)
    self:send_traces({format_span(span)})
end

-- Should we clear spans after unsuccessful request to zipkin?
function reporter_mt:flush()
    local spans = self.spans
    self.spans = {}
    return fun.iter(spans):map(format_span):totable()
end

function Reporter.new(config)
    local self = {
        spans = {},
        base_url = config.base_url,
        api_method = config.api_method,
        report_interval = config.report_interval,
    }

    if self.report_interval > 0 then
        self.report = background_report
    else
        self.report = cli_report
    end

    return setmetatable(self, reporter_mt)
end

return Reporter
