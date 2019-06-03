-- For details see
-- https://github.com/openzipkin/b3-propagation
-- https://www.envoyproxy.io/docs/envoy/v1.6.0/configuration/http_conn_man/headers
-- Semantic conventions: https://opentracing.io/specification/conventions/

local checks = require('checks')
local span_context = require('opentracing.span_context')

local function extract(carrier)
    checks('table')
    return span_context.new({
        trace_id = carrier.trace_id,
        span_id = carrier.span_id,
        parent_id = carrier.parent_span_id,
        should_sample = carrier.sample,
        baggage = carrier.baggage
    })
end

return extract
