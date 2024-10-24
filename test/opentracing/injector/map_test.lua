local t = require('luatest')
local g = t.group()

local span_context = require('tracing.opentracing.span_context')
local map_inject = require('tracing.opentracing.injectors.map')


g.test_map = function()
    local context = span_context.new({
        should_sample = true,
        baggage = {key = 'value'}
    })

    local map = {
        field = 'dummy',
    }

    t.assert_equals({
        field = 'dummy',
        trace_id = context.trace_id,
        span_id = context.span_id,
        parent_id = context.parent_id,
        sample = context.should_sample,
        baggage = {key = 'value'},
    }, map_inject(context, map), 'Inject context into map')
end
