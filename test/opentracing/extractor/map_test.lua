local t = require('luatest')
local g = t.group()

local span_context = require('tracing.opentracing.span_context')
local map_extract = require('tracing.opentracing.extractors.map')

g.test_map_extractor = function()
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

    t.assert_equals(context.trace_id, new_context.trace_id, 'Extract trace id')
    t.assert_equals(context.span_id, new_context.span_id, 'Extract span id')
    t.assert_equals(context.parent_id, new_context.parent_id, 'Extract parent span id')
    t.assert_equals(context.should_sample, new_context.should_sample, 'Extract sample flag')
    t.assert_equals(context.baggage, new_context.baggage, 'Extract baggage')
end
