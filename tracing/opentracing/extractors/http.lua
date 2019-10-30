-- For details see
-- https://github.com/openzipkin/b3-propagation
-- https://www.envoyproxy.io/docs/envoy/v1.6.0/configuration/http_conn_man/headers
-- Semantic conventions: https://opentracing.io/specification/conventions/

local ffi = require('ffi')
local checks = require('checks')
local span_context = require('opentracing.span_context')
local carrier_validate = require('opentracing.extractors.validate')

ffi.cdef([[
    typedef void CURL;
    CURL *curl_easy_init(void);
    void curl_easy_cleanup(CURL *handle);
    char *curl_easy_unescape(CURL *handle, const char *string, int length, int *outlength);
    void curl_free(void *p);
]])

local outlength = ffi.new("int[1]")
--- URL decodes the given string
-- See https://curl.haxx.se/libcurl/c/curl_easy_unescape.html
-- @function url_decode
-- @string       inp    the string
-- @returns      result string or nil
local function url_decode(inp)
    local handle = ffi.C.curl_easy_init()
    if not handle then
        return nil
    end

    local unescaped_str = ffi.C.curl_easy_unescape(handle, inp, #inp, outlength)
    ffi.C.curl_easy_cleanup(handle)
    if unescaped_str == nil then
        return nil
    end

    local out = ffi.string(unescaped_str, outlength[0])
    ffi.C.curl_free(unescaped_str)
    return out
end

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
    else
        sample = false
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
            baggage[baggage_key] = url_decode(v)
        end
    end

    local trace_id = carrier.trace_id
    local parent_span_id = carrier.parent_span_id
    local span_id = carrier.span_id

    return span_context.new({
        trace_id = trace_id,
        span_id = span_id,
        parent_id = parent_span_id,
        should_sample = sample,
        baggage = baggage,
    })
end

return extract
