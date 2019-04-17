-- For details see
-- https://github.com/openzipkin/b3-propagation
-- https://www.envoyproxy.io/docs/envoy/v1.6.0/configuration/http_conn_man/headers
-- Semantic conventions: https://opentracing.io/specification/conventions/

local checks = require('checks')
local span_context = require('opentracing.span_context')
local carrier_validate = require('opentracing.extractors.validate')
local utils = require('tracing.utils')

local function extract(headers)
    checks('table')

    local carrier = table.new(0, 3)
    carrier.trace_id = headers["x-b3-traceid"]
    carrier.parent_span_id = headers["x-b3-parentspanid"]
    carrier.span_id = headers["x-b3-spanid"]

    local ok, err = carrier_validate(carrier)
    if not ok then
        return nil, err
    end

    -- X-B3-Sampled: if an upstream decided to sample this request, we do too.
    local sample = headers["x-b3-sampled"]
    if sample == "1" or sample == "true" then
        sample = true
    elseif sample == "0" or sample == "false" then
        sample = false
    elseif sample ~= nil then
        sample = nil
    end

    -- X-B3-Flags: if it equals '1' then it overrides sampling policy
    -- We still want to warn on invalid sample header, so do this after the above
    local debug = headers["x-b3-flags"]
    if debug == "1" then
        sample = true
    end

    -- Process baggage header
    local baggage = {}
    for k, v in pairs(headers) do
        local baggage_key = k:match("^uberctx%-(.*)$")
        if baggage_key then
            baggage[baggage_key] = utils.url_decode(v)
        end
    end

    local trace_id = string.fromhex(carrier.trace_id)
    local parent_span_id = carrier.parent_span_id and string.fromhex(carrier.parent_span_id)
    local span_id = carrier.span_id and string.fromhex(carrier.span_id)

    return span_context.new(trace_id, span_id, parent_span_id, sample, baggage)
end

return extract
