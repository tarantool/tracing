-- For details see
-- https://github.com/openzipkin/b3-propagation
-- https://www.envoyproxy.io/docs/envoy/v1.6.0/configuration/http_conn_man/headers
-- Semantic conventions: https://opentracing.io/specification/conventions/

local checks = require('checks')
local span_context = require('opentracing.span_context')

local function extract(carrier)
    checks('table')
    return span_context.new(carrier.trace_id, carrier.span_id, carrier.parent_span_id,
            carrier.sample, carrier.baggage)
end

return extract
