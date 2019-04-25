#!/usr/bin/env tarantool

local test = require('tap').test('text map extractor')
local span_context = require('opentracing.span_context')
local map_extract = require('opentracing.extractors.map')

test:plan(5)

local context = span_context.new({
    should_sample = true,
    baggage = {key = 'value'}
})

local map = {
    field = 'dummy',
    trace_id = context.trace_id,
    span_id = context.span_id,
    parent_id = context.parent_id,
    sample = context.should_sample,
    baggage = {key = 'value'},
}

local new_context = map_extract(map)

test:is(context.trace_id, new_context.trace_id, 'Extract trace id')
test:is(context.span_id, new_context.span_id, 'Extract span id')
test:is(context.parent_id, new_context.parent_id, 'Extract parent span id')
test:is(context.should_sample, new_context.should_sample, 'Extract sample flag')
test:is_deeply(context.baggage, new_context.baggage, 'Extract baggage')

os.exit(test:check() and 0 or 1)
