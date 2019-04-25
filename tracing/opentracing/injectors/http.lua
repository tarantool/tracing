-- For details see
-- https://github.com/openzipkin/b3-propagation
-- https://www.envoyproxy.io/docs/envoy/v1.6.0/configuration/http_conn_man/headers
-- Semantic conventions: https://opentracing.io/specification/conventions/
local ffi = require('ffi')
local checks = require('checks')

ffi.cdef([[
    typedef void CURL;
    CURL *curl_easy_init(void);
    void curl_easy_cleanup(CURL *handle);
    char *curl_easy_escape(CURL *handle, const char *string, int length);
    void curl_free(void *p);
]])

--- URL encodes the given string
-- See https://curl.haxx.se/libcurl/c/curl_easy_escape.html
-- @function url_encode
-- @string       inp    the string
-- @returns      result string or nil
local function url_encode(inp)
    local handle = ffi.C.curl_easy_init()
    if not handle then
        return nil
    end

    local escaped_str = ffi.C.curl_easy_escape(handle, inp, #inp)
    ffi.C.curl_easy_cleanup(handle)
    if escaped_str == nil then
        return nil
    end

    local out = ffi.string(escaped_str)
    ffi.C.curl_free(escaped_str)
    return out
end

local function inject(context, headers)
    checks('table', '?table')
    headers = headers or {}
    headers["x-b3-traceid"] = context.trace_id and string.hex(context.trace_id)
    headers["x-b3-parentspanid"] = context.parent_id and string.hex(context.parent_id) or nil
    headers["x-b3-spanid"] = context.span_id and string.hex(context.span_id)
    headers["x-b3-sampled"] = context.should_sample and "1" or "0"
    for key, value in context:each_baggage_item() do
        -- XXX: https://github.com/opentracing/specification/issues/117
        headers["uberctx-" .. key] = url_encode(value)
    end
    return headers
end

return inject
