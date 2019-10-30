#!/usr/bin/env tarantool

local tap = require('tap')

local test = tap.test('opentracing.span_context')

test:plan(5)
local opentracing_span_context = require("opentracing.span_context")
local new_context = opentracing_span_context.new

test:test("doesn't allow constructing with invalid trace id", function(test)
    test:plan(1)
    local ok, _ = pcall(function()
        new_context({ trace_id = 321 })
    end)
    test:ok(not ok)
end)

test:test("doesn't allow constructing with invalid span id", function(test)
    test:plan(1)
    local ok, _ = pcall(function()
        new_context({ span_id = 123 })
    end)
    test:ok(not ok)
end)

test:test("doesn't allow constructing with invalid parent id", function(test)
    test:plan(1)
    local ok, _ = pcall(function()
        new_context({ parent_id = 123 })
    end)
    test:ok(not ok)
end)

test:test("allows constructing with baggage items", function(test)
    test:plan(3)
    local baggage_arg = {
        foo = "bar",
        somekey = "some value",
    }
    local context = new_context({ baggage = baggage_arg })
    test:is("bar", context:get_baggage_item("foo"))
    test:is("some value", context:get_baggage_item("somekey"))
    baggage_arg.modified = "other"
    test:is(nil, context:get_baggage_item("modified"))
end)

test:test("dummy span_context", function(test)
    test:plan(6)

    local context1 = new_context({ parent_id = '0000000000000000', should_sample = false })
    test:is(context1.span_id, '0000000000000000', "span_id is not generated without sampling")
    test:is(context1.trace_id, '00000000-0000-0000-0000-000000000000', "trace_id is not generated without sampling")

    local context2 = new_context({ parent_id = '0000000000000000', should_sample = true })
    test:isnt(context2.span_id, '0000000000000000', "span_id is generated without sampling")
    test:isnt(context2.trace_id, '00000000-0000-0000-0000-000000000000', "trace_id is generated without sampling")

    local dummy_child = context1:child()
    test:is(dummy_child.span_id, '0000000000000000', "span_id is not generated without sampling for child")
    test:is(dummy_child.trace_id, '00000000-0000-0000-0000-000000000000',
            "trace_id is not generated without sampling for child")
end)

os.exit(test:check() and 0 or 1)
