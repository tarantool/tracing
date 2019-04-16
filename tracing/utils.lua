-- TODO: https://github.com/tarantool/tarantool/pull/4153

local ffi = require('ffi')

ffi.cdef([[
 typedef void CURL;
 CURL *curl_easy_init(void);
 char *curl_easy_escape(CURL *handle, const char *string, int length);
 char *curl_easy_unescape(CURL *handle, const char *string, int length, int *outlength);
 void curl_free(void *p);
]])

local utils = {}

local err_string_arg = "bad argument #%d to '%s' (%s expected, got %s)"

--- URL encodes the given string
-- See https://curl.haxx.se/libcurl/c/curl_easy_escape.html
-- @function url_encode
-- @string       inp    the string
-- @returns      result string or nil
function utils.url_encode(inp)
    if type(inp) ~= 'string' then
        error(err_string_arg:format(1, "string.url_encode", 'string', type(inp)), 2)
    end
    local handle = ffi.C.curl_easy_init()
    if not handle then
        return nil
    end

     local escaped_str = ffi.C.curl_easy_escape(handle, inp, #inp)
    if escaped_str == nil then
        return nil
    end

     escaped_str = ffi.gc(escaped_str, ffi.C.curl_free)
    return ffi.string(escaped_str)
end

 --- URL decodes the given string
-- See https://curl.haxx.se/libcurl/c/curl_easy_unescape.html
-- @function url_decode
-- @string       inp    the string
-- @returns      result string or nil
function utils.url_decode(inp)
    if type(inp) ~= 'string' then
        error(err_string_arg:format(1, "string.url_decode", 'string', type(inp)), 2)
    end
    local handle = ffi.C.curl_easy_init()
    if not handle then
        return nil
    end

    local outlength = ffi.new("int[1]")
    local unescaped_str = ffi.C.curl_easy_unescape(handle, inp, #inp, outlength)
    if unescaped_str == nil then
        return nil
    end

     unescaped_str = ffi.gc(unescaped_str, ffi.C.curl_free)
    return ffi.string(unescaped_str, outlength[0])
end

return utils
