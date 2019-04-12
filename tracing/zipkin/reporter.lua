local fun = require('fun')
local json = require('json')

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

    local span_kind  = tags.kind
    tags.kind = nil

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
        shared = true,
        localEndpoint = localEndpoint,
        remoteEndpoint = remoteEndpoint,
        annotations = span.logs,
        tags = setmetatable(tags, json.map_mt),
    }
end

local reporter_mt = {}
reporter_mt.__index = reporter_mt

-- Should we persist it?
function reporter_mt:report(span)
    table.insert(self.spans, span)
end

-- Should we clear spans after successful request to zipkin?
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
    return setmetatable(self, reporter_mt)
end

return Reporter
