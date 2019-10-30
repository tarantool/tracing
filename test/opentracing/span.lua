#!/usr/bin/env tarantool

local tap = require('tap')
local test = tap.test('opentracing.span')

test:plan(23)
local tracer = require("opentracing.tracer").new()
local opentracing_span_context = require("opentracing.span_context")
local context = opentracing_span_context.new({should_sample = true})
local opentracing_span = require("opentracing.span")
local new_span = opentracing_span.new

test:test("doesn't allow constructing without a tracer", function(test)
    test:plan(1)
    local ok, _ = pcall(function()
        new_span(nil, context, "foo")
    end)
    test:ok(not ok, "can't create span without a tracer")
end)

test:test("doesn't allow constructing without a context", function(test)
    test:plan(1)
    local ok, _ = pcall(function()
        new_span(tracer, nil, "foo")
    end)
    test:ok(not ok, "can't create span without a context")
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
        end,
        report = function() end,
    }
    local span = new_span(tracer_mock, context, "foo", 0)
    span:log("key", "value")
    test:is(was_called, 1, "tracing call a custom timer 1")
    span:log_kv({key = "value"})
    test:is(was_called, 2, "tracing call a custom timer 2")
    span:finish()
    test:is(was_called, 3, "tracing call a custom timer 3")
end)

test:test("doesn't allow constructing with invalid timestamp", function(test)
    test:plan(1)
    local ok, _ = pcall(function()
        new_span(tracer, context, "foo", {})
    end)
    test:ok(not ok, "unsuccessful span creation with invalid timestamp")
end)

test:test("can retreive context with :context()", function(test)
    test:plan(1)
    local span = new_span(tracer, context, "foo", 0)
    test:is_deeply(context, span:context(), "span returns expected context")
end)

test:test("can retreive tracer with :get_tracer()", function(test)
    test:plan(1)
    local span = new_span(tracer, context, "foo", 0)
    test:is_deeply(tracer, span:get_tracer(), "span returns expected tracer")
end)

test:test("can change name with :set_operation_name", function(test)
    test:plan(1)
    local span = new_span(tracer, context, "foo", 0)
    span:set_operation_name("bar")
    test:is("bar", span.name, "span has expected name")
end)

test:test("can construct with :start_child_span", function(test)
    test:plan(4)
    local span1 = new_span(tracer, context, "foo", 0)
    local span2 = span1:start_child_span("bar", 1)
    test:is("foo", span1.name, "parent span has expected name")
    test:is(0, span1.timestamp)
    test:is("bar", span2.name, "child span has expected name")
    test:is(1, span2.timestamp)
end)

test:test("doesn't allow :finish with invalid timestamp", function(test)
    local span = new_span(tracer, context, "foo", 0)
    test:plan(1)
    local ok, _ = pcall(function()
        span:finish({timestamp = 'hello'})
    end)
    test:ok(not ok)
end)

test:test("doesn't allow :finish-ing twice", function(test)
    test:plan(2)
    local span = new_span(tracer, context, "foo", 0)
    span:finish({timestamp = 10})
    local ok, err = span:finish({timestamp = 11})
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

test:test("dummy span", function(test)
    test:plan(1)
    local dummy_context = opentracing_span_context.new({should_sample = false})
    local span = new_span(tracer, dummy_context, "foo", 0)
    span:context()
    span:get_tracer()
    span:set_operation_name('test')
    span:start_child_span('test')
    span:finish()
    span:set_tag('tag', 123)
    span:get_tag('tag')
    span:each_tag()
    span:log('key', 'value')
    test:ok(true)
end)

test:test("new empty span tags", function(test)
    test:plan(4)
    local ctx = opentracing_span_context.new({should_sample = true})
    local empty_span = new_span(tracer, ctx, "empty")
    test:isnil(empty_span:get_tag('tag'), "There isn't such tag")
    test:is_deeply(empty_span:get_tags(), {}, "There aren't tags")
    local tags_count = 0
    for _ in empty_span:each_tag() do
        tags_count = tags_count + 1
    end
    test:is(tags_count, 0, "There aren't tags: count == 0")
    empty_span:set_tag('my_tag', 'thisistag')
    test:is(empty_span:get_tag('my_tag'), 'thisistag', "tag was saved")
end)

test:test("new empty span logs", function(test)
    test:plan(2)
    local ctx = opentracing_span_context.new({should_sample = true})
    local empty_span = new_span(tracer, ctx, "empty")

    local logs_count = 0
    for _ in empty_span:each_log() do
        logs_count = logs_count + 1
    end
    test:is(logs_count, 0, "There aren't tags: count == 0")

    empty_span:log('my_tag', 'thisistag', 0)
    logs_count = 0
    for _ in empty_span:each_log() do
        logs_count = logs_count + 1
    end
    test:is(logs_count, 1, "One record saved in log")
end)

os.exit(test:check() and 0 or 1)
