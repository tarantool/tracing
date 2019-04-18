#!/usr/bin/env tarantool

local test = require('tap').test('HTTP extractor')
local http_extractor = require('opentracing.extractors.http')

test:plan(3)

local empty = http_extractor({})
test:isnil(empty, 'Headers without traceId')

local headers = {
    ['x-b3-traceid'] = '80f198ee56343ba864fe8b2a57d3eff7',
    ['x-b3-parentspanid'] = '05e3ac9a4f6e3b90',
    ['x-b3-spanid'] = 'e457b5a2e4d86bd1',
    ['x-b3-sampled'] = '1',
    ['http-header'] = 'useless',
    ['uberctx-item'] = 'baggage item'
}

local result, _ = http_extractor(headers)
test:isnt(nil, result, 'Headers are decoded')
test:is('baggage item', result:get_baggage_item('item'), 'Extract baggage item')

os.exit(test:check() and 0 or 1)
