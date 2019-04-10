#!/usr/bin/env tarantool

local tap = require('tap')
local test = tap.test('opentracing.span')

test:plan(21)
local tracer = require("opentracing.tracer").new()
local context = require("opentracing.span_context").new()
local opentracing_span = require("opentracing.span")
local new_span = opentracing_span.new

test:test("has working .is function", function(test)
	test:plan(5)
	test:ok(not opentracing_span.is(nil))
	test:ok(not opentracing_span.is({}))
	local span = new_span(tracer, context, "foo", 0)
	test:ok(opentracing_span.is(span))
	test:ok(not opentracing_span.is(tracer))
	test:ok(not opentracing_span.is(context))
end)

test:test("doesn't allow constructing without a tracer", function(test)
	test:plan(1)
	local ok, _ = pcall(function()
		new_span(nil, context, "foo")
	end)
	test:ok(not ok)
end)

test:test("doesn't allow constructing without a context", function(test)
	test:plan(1)
	local ok, _ = pcall(function()
		new_span(tracer, nil, "foo")
	end)
	test:ok(not ok)
end)

test:test("doesn't allow constructing without a name", function(test)
	test:plan(1)
	local ok, _ = pcall(function()
		new_span(tracer, context, nil)
	end)
	test:ok(not ok)
end)

test:test("asks for time from tracer when not passed", function(test)
	test:plan(3)
	local was_called = 0
	local tracer_mock = {
		time = function()
			was_called = was_called + 1
			return 42
		end
	}
	local span = new_span(tracer_mock, context, "foo", 0)
	span:log("key", "value")
	test:is(was_called, 1)
	span:log_kv{key = "value"}
	test:is(was_called, 2)
	span:finish()
	test:is(was_called, 3)
end)

test:test("doesn't allow constructing with invalid timestamp", function(test)
	test:plan(1)
	local ok, _ = pcall(function()
		new_span(tracer, context, "foo", {})
	end)
	test:ok(not ok)
end)

test:test("can retreive context with :context()", function(test)
	test:plan(1)
	local span = new_span(tracer, context, "foo", 0)
	test:is_deeply(context, span:context())
end)

test:test("can retreive tracer with :tracer()", function(test)
	test:plan(1)
	local span = new_span(tracer, context, "foo", 0)
	test:is_deeply(tracer, span:tracer())
end)

test:test("can change name with :set_operation_name", function(test)
	test:plan(1)
	local span = new_span(tracer, context, "foo", 0)
	span:set_operation_name("bar")
	test:is("bar", span.name)
end)

test:test("can construct with :start_child_span", function(test)
	test:plan(4)
	local span1 = new_span(tracer, context, "foo", 0)
	local span2 = span1:start_child_span("bar", 1)
	test:is("foo", span1.name)
	test:is(0, span1.timestamp)
	test:is("bar", span2.name)
	test:is(1, span2.timestamp)
end)

test:test("doesn't allow :finish with invalid timestamp", function(test)
	local span = new_span(tracer, context, "foo", 0)
	test:plan(1)
	local ok, _ = pcall(function()
		span:finish({})
	end)
	test:ok(not ok)
end)

test:test("doesn't allow :finish-ing twice", function(test)
	test:plan(2)
	local span = new_span(tracer, context, "foo", 0)
	span:finish(10)
	local ok, err = span:finish(11)
	test:ok(not ok)
	test:is('span already finished', err)
end)

test:test("can iterate over empty set of tags", function(test)
	local span = new_span(tracer, context, "foo", 0)
	for _ in span:each_tag() do
		test:fail("unreachable")
	end
end)

test:test("can :get_tag", function(test)
	test:plan(2)
	local span = new_span(tracer, context, "foo", 0)
	test:is(nil, span:get_tag("http.method"))
	span:set_tag("http.method", "GET")
	test:is("GET", span:get_tag("http.method"))
end)

test:test("can :set_tag(k, nil) to clear a tags", function(test)
	test:plan(3)
	local span = new_span(tracer, context, "foo", 0)
	test:is(nil, span:get_tag("http.method"))
	span:set_tag("http.method", "GET")
	test:is("GET", span:get_tag("http.method"))
	span:set_tag("http.method", nil)
	test:is(nil, span:get_tag("http.method"))
end)

test:test("can iterate over tags", function(test)
	test:plan(1)
	local span = new_span(tracer, context, "foo", 0)
	local tags = {
		["http.method"] = "GET",
		["http.url"] = "https://example.com/",
	}
	for k, v in pairs(tags) do
		span:set_tag(k, v)
	end
	local seen = {}
	for k, v in span:each_tag() do
		seen[k] = v
	end
	test:is_deeply(tags, seen)
end)

test:test("can iterate over empty logs collection", function(test)
	local span = new_span(tracer, context, "foo", 0)
	for _ in span:each_log() do
		test:fail("unreachable")
	end
end)

test:test("can iterate over logs", function(test)
	test:plan(3)
	local span = new_span(tracer, context, "foo", 0)
	local logs = {
		["thing1"] = 1000, -- valid value **and** valid timestamp
		["thing2"] = 1001,
	}
	for k, v in pairs(logs) do
		local t = v*10
		span:log(k, v, t)
	end
	local seen = {}
	for k, v, t in span:each_log() do
		test:is(v * 10, t)
		seen[k] = v
	end
	test:is_deeply(logs, seen)
end)

test:test("logs are created with :log_kv", function(test)
	test:plan(3)
	local span = new_span(tracer, context, "foo", 0)
	local logs = {
		["thing1"] = 1000,
		["thing2"] = 1001,
	}
	span:log_kv(logs, 1234)
	local seen = {}
	for k, v, t in span:each_log() do
		test:is(1234, t)
		seen[k] = v
	end
	test:is_deeply(logs, seen)
end)

test:test("tracks baggage", function(test)
	test:plan(5)
	local span = new_span(tracer, context, "name", 0)
	-- New span shouldn't have any baggage
	test:is(nil, span:get_baggage_item("foo"))
	-- Check normal case
	span:set_baggage_item("foo", "bar")
	test:is("bar", span:get_baggage_item("foo"))
	-- Make sure adding a new key doesn't remove old ones
	span:set_baggage_item("mykey", "myvalue")
	test:is("bar", span:get_baggage_item("foo"))
	test:is("myvalue", span:get_baggage_item("mykey"))
	-- Set same key again and make sure it has changed
	span:set_baggage_item("foo", "other")
	test:is("other", span:get_baggage_item("foo"))
end)

test:test("can iterate over baggage", function(test)
	test:plan(1)
	local span = new_span(tracer, context, "foo", 0)
	local baggage = {
		["baggage1"] = "value1",
		["baggage2"] = "value2",
	}
	for k, v in pairs(baggage) do
		span:set_baggage_item(k, v)
	end
	local seen = {}
	for k, v in span:each_baggage_item() do
		seen[k] = v
	end
	test:is_deeply(baggage, seen)
end)

os.exit(test:check() and 0 or 1)
