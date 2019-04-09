#!/usr/bin/env tarantool

local tap = require('tap')

local test = tap.test('opentracing.span_context')

test:plan(5)
local opentracing_span_context = require("opentracing.span_context")
local new_context = opentracing_span_context.new

test:test("has working .is function", function(test)
	test:plan(3)
	test:ok(not opentracing_span_context.is(nil))
	test:ok(not opentracing_span_context.is({}))
	local context = new_context()
	test:ok(opentracing_span_context.is(context))
end)

test:test("doesn't allow constructing with invalid trace id", function(test)
	test:plan(2)
	local ok, err = pcall(function()
		new_context({})
	end)
	test:ok(not ok)
	test:ok(err:endswith('invalid trace id'))
end)

test:test("doesn't allow constructing with invalid span id", function(test)
	test:plan(2)
	local ok, err = pcall(function()
		new_context(nil, {})
	end)
	test:ok(not ok)
	test:ok(err:endswith('invalid span id'))
end)

test:test("doesn't allow constructing with invalid parent id", function(test)
	test:plan(2)
	local ok, err = pcall(function()
		new_context(nil, nil, {})
	end)
	test:ok(not ok)
	test:ok(err:endswith('invalid parent id'))
end)

test:test("allows constructing with baggage items", function(test)
	test:plan(3)
	local baggage_arg = {
		foo = "bar",
		somekey = "some value",
	}
	local context = new_context(nil, nil, nil, nil, baggage_arg)
	test:is("bar", context:get_baggage_item("foo"))
	test:is("some value", context:get_baggage_item("somekey"))
	baggage_arg.modified = "other"
	test:is(nil, context:get_baggage_item("modified"))
end)

os.exit(test:check() and 0 or 1)
