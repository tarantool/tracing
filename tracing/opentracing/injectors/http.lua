-- For details see
-- https://github.com/openzipkin/b3-propagation
-- https://www.envoyproxy.io/docs/envoy/v1.6.0/configuration/http_conn_man/headers
-- Semantic conventions: https://opentracing.io/specification/conventions/
local checks = require('checks')

local http_injector = {}

local function url_escape(str)
   local pattern = "^A-Za-z0-9%-%._~"
   str = str:gsub("[" .. pattern .. "]", function(c) return string.format("%%%02X",string.byte(c)) end)
   return str
end

local function inject(_, context, headers)
    checks('?', 'table', '?table')
    headers = headers or {}
    headers["x-b3-traceid"] = string.hex(context.trace_id)
	headers["x-b3-parentspanid"] = context.parent_id and string.hex(context.parent_id) or nil
	headers["x-b3-spanid"] = string.hex(context.span_id)
	headers["x-b3-sampled"] = context.should_sample and "1" or "0"
	for key, value in context:each_baggage_item() do
		-- XXX: https://github.com/opentracing/specification/issues/117
		headers["uberctx-"..key] = url_escape(value)
	end
end

setmetatable(http_injector, {
    __call = inject,
})

return http_injector
