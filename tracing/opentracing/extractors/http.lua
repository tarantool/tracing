-- For details see
-- https://github.com/openzipkin/b3-propagation
-- https://www.envoyproxy.io/docs/envoy/v1.6.0/configuration/http_conn_man/headers
-- Semantic conventions: https://opentracing.io/specification/conventions/

local checks = require('checks')
local span_context = require('opentracing.span_context')
local utils = require('tracing.utils')

local function extract(headers)
    checks('table')
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

    local trace_id = headers["x-b3-traceid"]

    -- Validate trace id
    if trace_id == nil or ((#trace_id ~= 16 and #trace_id ~= 32) or trace_id:match("%X")) then
        return nil, 'Invalid trace id'
    end

    local parent_span_id = headers["x-b3-parentspanid"]
    -- Validate parent_span_id
    if parent_span_id ~= nil and (#parent_span_id ~= 16 or parent_span_id:match("%X")) then
        return nil, 'Invalid parent span id'
    end

    local request_span_id = headers["x-b3-spanid"]
    -- Validate request_span_id
    if request_span_id ~= nil and (#request_span_id ~= 16 or request_span_id:match("%X")) then
        return nil, 'Invalid span id'
    end

    -- Process baggage header
    local baggage = {}
    for k, v in pairs(headers) do
        local baggage_key = k:match("^uberctx%-(.*)$")
        if baggage_key then
            baggage[baggage_key] = utils.url_decode(v)
        end
    end

    trace_id = string.fromhex(trace_id)
    parent_span_id = parent_span_id and string.fromhex(parent_span_id)
    request_span_id = request_span_id and string.fromhex(request_span_id)

    return span_context.new(trace_id, request_span_id, parent_span_id, sample, baggage)
end

return extract
