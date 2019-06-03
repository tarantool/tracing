#!/usr/bin/env tarantool

local digest = require('digest')
local test = require('tap').test('HTTP injector')
local http_injector = require('opentracing.injectors.http')

test:plan(2)

local empty_context = {
    each_baggage_item = function() return function() end end
}

local http_headers = {
    ['content-type'] = 'application/json',
}
http_injector(empty_context, http_headers)

test:is('application/json', http_headers['content-type'], 'Old headers are saved')

local trace_id = digest.urandom(16)
local span_id = digest.urandom(8)

local context = {
    each_baggage_item = function() return function() end end,
    trace_id = trace_id,
    span_id = span_id,
}

local http_headers = {
    ['content-type'] = 'application/json',
}

http_injector(context, http_headers)
test:is_deeply({
    ['x-b3-traceid'] = trace_id,
    ['x-b3-spanid'] = span_id,
    ['content-type'] = 'application/json',
    ['x-b3-sampled'] = '0',
}, http_headers, 'Inject headers')

os.exit(test:check() and 0 or 1)
