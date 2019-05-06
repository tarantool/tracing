#!/usr/bin/env tarantool

local test = require('tap').test('HTTP extractor')
local http_extractor = require('opentracing.extractors.http')

test:plan(6)

local empty_context = http_extractor({ ["x-b3-sampled"] = '1' })
test:ok(empty_context.trace_id, 'Generate trace_id for new context')
test:ok(empty_context.span_id, 'Generate span_id for new context')
test:ok(empty_context.should_sample == true, 'Sampling is enabled')

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
test:ok(result.should_sample, 'Sampling is enabled')
test:is('baggage item', result:get_baggage_item('item'), 'Extract baggage item')

os.exit(test:check() and 0 or 1)
