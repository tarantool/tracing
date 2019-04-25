#!/usr/bin/env tarantool

local tap = require('tap')

local test = tap.test('opentracing.span_context')

test:plan(4)
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

os.exit(test:check() and 0 or 1)
