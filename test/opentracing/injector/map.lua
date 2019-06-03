#!/usr/bin/env tarantool

local test = require('tap').test('text map injector')
local span_context = require('opentracing.span_context')
local map_inject = require('opentracing.injectors.map')

test:plan(1)

local context = span_context.new({
    should_sample = true,
    baggage = {key = 'value'}
})

local map = {
    field = 'dummy',
}

test:is_deeply({
    field = 'dummy',
    trace_id = context.trace_id,
    span_id = context.span_id,
    parent_id = context.parent_id,
    sample = context.should_sample,
    baggage = {key = 'value'},
}, map_inject(context, map), 'Inject context into map')

os.exit(test:check() and 0 or 1)
