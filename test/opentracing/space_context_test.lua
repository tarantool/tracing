local t = require('luatest')
local g = t.group()

local opentracing_span_context = require("tracing.opentracing.span_context")
g.new_context = opentracing_span_context.new

g.test_fail_constructing_with_invalid_trace_id = function()
    t.assert_error(g.new_context, { trace_id = 321 })
end

g.test_fail_constructing_with_invalid_span_id = function()
    t.assert_error(g.new_context, { span_id = 123 })
end

g.test_fail_constructing_with_invalid_parent_id = function()
    t.assert_error(g.new_context, { parent_id = 123 })
end

g.test_construct_with_baggage_items = function()
    local baggage_arg = {
        foo = "bar",
        somekey = "some value",
    }
    local context = g.new_context({ baggage = baggage_arg })

    t.assert_equals(context:get_baggage_item("foo"), "bar")
    t.assert_equals(context:get_baggage_item("somekey"), "some value")

    baggage_arg.modified = "other"
    t.assert_equals(context:get_baggage_item("modified"), nil)
end

g.test_dummy_span_context = function()
    local context1 = g.new_context({ parent_id = '0000000000000000', should_sample = false })
    t.assert_equals(context1.span_id, '0000000000000000')
    t.assert_equals(context1.trace_id, '00000000-0000-0000-0000-000000000000')

    local context2 = g.new_context({ parent_id = '0000000000000000', should_sample = true })
    t.assert_not_equals(context2.span_id, '0000000000000000')
    t.assert_not_equals(context2.trace_id, '00000000-0000-0000-0000-000000000000')

    local dummy_child = context1:child()
    t.assert_equals(dummy_child.span_id, '0000000000000000')
    t.assert_equals(dummy_child.trace_id, '00000000-0000-0000-0000-000000000000')
end