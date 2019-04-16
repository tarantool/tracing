-- For details see
-- https://github.com/openzipkin/b3-propagation
-- https://www.envoyproxy.io/docs/envoy/v1.6.0/configuration/http_conn_man/headers
-- Semantic conventions: https://opentracing.io/specification/conventions/
local checks = require('checks')
local utils = require('tracing.utils')

local function inject(context, headers)
    checks('table', '?table')
    headers = headers or {}
    headers["x-b3-traceid"] = context.trace_id and string.hex(context.trace_id)
    headers["x-b3-parentspanid"] = context.parent_id and string.hex(context.parent_id) or nil
    headers["x-b3-spanid"] = context.span_id and string.hex(context.span_id)
    headers["x-b3-sampled"] = context.should_sample and "1" or "0"
    for key, value in context:each_baggage_item() do
        -- XXX: https://github.com/opentracing/specification/issues/117
        headers["uberctx-" .. key] = utils.url_encode(value)
    end
    return headers
end

return inject
