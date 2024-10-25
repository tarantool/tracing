local t = require('luatest')

local g = t.group()
local opentracing_span_context = require("tracing.opentracing.span_context")
local opentracing_span = require("tracing.opentracing.span")

g.before_all(function ()
    g.tracer = require("opentracing.tracer").new()
    g.new_span = opentracing_span.new
    g.context = opentracing_span_context.new({should_sample = true})
end)

g.test_fail_constructing_without_tracer = function()
    t.assert_error(function()
        g.new_span(nil, g.context, "foo")
    end, "can't create span without a tracer")
end

g.test_fail_constructing_without_context = function()
    t.assert_error(function()
        g.new_span(g.tracer, nil, "foo")
    end, "can't create span without a context")
end

g.test_fail_constructing_without_name = function()
    t.assert_error(function()
        g.new_span(g.tracer, g.context, nil)
    end)
end

g.test_asks_for_time_from_tracer_when_not_passed = function()
    local was_called = 0
    local tracer_mock = {
        time = function()
            was_called = was_called + 1
            return 42
        end,
        report = function() end,
    }
    local span = g.new_span(tracer_mock, g.context, "foo", 0)
    span:log("key", "value")
    t.assert_equals(was_called, 1, "tracing call a custom timer 1")
    span:log_kv({key = "value"})
    t.assert_equals(was_called, 2, "tracing call a custom timer 2")
    span:finish()
    t.assert_equals(was_called, 3, "tracing call a custom timer 3")
end

g.test_fail_constructing_with_invalid_timestamp = function()
    t.assert_error(function()
        g.new_span(g.tracer, g.context, "foo", {})
    end)
end

g.test_context_method  = function()
    local span = g.new_span(g.tracer, g.context, "foo", 0)
    t.assert_equals(g.context, span:context(), "span returns expected context")
end

g.test_get_tracer = function()
    local span = g.new_span(g.tracer, g.context, "foo", 0)
    t.assert_equals(g.tracer, span:get_tracer(), "span returns expected tracer")
end

g.test_set_operation_name = function()
    local span = g.new_span(g.tracer, g.context, "foo", 0)
    span:set_operation_name("bar")
    t.assert_equals("bar", span.name, "span has expected name")
end

g.test_start_child_span = function()
    local span1 = g.new_span(g.tracer, g.context, "foo", 0)
    local span2 = span1:start_child_span("bar", 1)
    t.assert_equals("foo", span1.name, "parent span has expected name")
    t.assert_equals(0, span1.timestamp)
    t.assert_equals("bar", span2.name, "child span has expected name")
    t.assert_equals(1, span2.timestamp)
end

g.test_fail_finish_with_invalid_timestamp = function()
    local span = g.new_span(g.tracer, g.context, "foo", 0)
    t.assert_error(function()
        span:finish({timestamp = 'hello'})
    end)
end

g.test_fail_twice_finish = function()
    local span = g.new_span(g.tracer, g.context, "foo", 0)
    span:finish({timestamp = 10})
    local ok, err = span:finish({timestamp = 11})
    t.assert_not(ok)
    t.assert_equals(err, 'span already finished')
end

g.test_fail_iterate_over_empty_set_of_tags = function()
    local span = g.new_span(g.tracer, g.context, "foo", 0)
    for _ in span:each_tag() do
        t.fail("unreachable")
    end
end

g.test_get_tag = function()
    local span = g.new_span(g.tracer, g.context, "foo", 0)
    t.assert_equals(span:get_tag("http.method"), nil)
    span:set_tag("http.method", "GET")
    t.assert_equals(span:get_tag("http.method"), "GET")
end

g.test_set_tag = function()
    local span = g.new_span(g.tracer, g.context, "foo", 0)
    t.assert_equals(span:get_tag("http.method"), nil)
    span:set_tag("http.method", "GET")
    t.assert_equals(span:get_tag("http.method"), "GET")
    span:set_tag("http.method", nil)
    t.assert_equals(span:get_tag("http.method"), nil)
end

g.test_iterate_over_tags = function()
    local span = g.new_span(g.tracer, g.context, "foo", 0)
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
    t.assert_equals(tags, seen)
end

g.test_fail_iterate_over_empty_logs_collection = function()
    local span = g.new_span(g.tracer, g.context, "foo", 0)
    for _ in span:each_log() do
        t.fail("unreachable")
    end
end

g.test_iterate_over_logs = function()
    local span = g.new_span(g.tracer, g.context, "foo", 0)
    local logs = {
        ["thing1"] = 1000, -- valid value **and** valid timestamp
        ["thing2"] = 1001,
    }
    for k, v in pairs(logs) do
        local m = v*10
        span:log(k, v, m)
    end
    local seen = {}
    for k, v, m in span:each_log() do
        t.assert_equals(v * 10, m)
        seen[k] = v
    end
    t.assert_equals(logs, seen)
end

g.test_logs_are_created_with_log_kv = function()
    local span = g.new_span(g.tracer, g.context, "foo", 0)
    local logs = {
        ["thing1"] = 1000,
        ["thing2"] = 1001,
    }
    span:log_kv(logs, 1234)
    local seen = {}
    for k, v, m in span:each_log() do
        t.assert_equals(1234, m)
        seen[k] = v
    end
    t.assert_equals(logs, seen)
end

g.test_tracks_baggage = function()
    local span = g.new_span(g.tracer, g.context, "name", 0)
    -- New span shouldn't have any baggage
    t.assert_equals(nil, span:get_baggage_item("foo"))
    -- Check normal case
    span:set_baggage_item("foo", "bar")
    t.assert_equals("bar", span:get_baggage_item("foo"))
    -- Make sure adding a new key doesn't remove old ones
    span:set_baggage_item("mykey", "myvalue")
    t.assert_equals("bar", span:get_baggage_item("foo"))
    t.assert_equals("myvalue", span:get_baggage_item("mykey"))
    -- Set same key again and make sure it has changed
    span:set_baggage_item("foo", "other")
    t.assert_equals("other", span:get_baggage_item("foo"))
end

g.test_iterate_over_baggage = function()
    local span = g.new_span(g.tracer, g.context, "foo", 0)
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
    t.assert_equals(baggage, seen)
end

g.test_dummy_span = function()
    local dummy_context = opentracing_span_context.new({should_sample = false})
    local span = g.new_span(g.tracer, dummy_context, "foo", 0)
    span:context()
    span:get_tracer()
    span:set_operation_name('test')
    span:start_child_span('test')
    span:finish()
    span:set_tag('tag', 123)
    span:get_tag('tag')
    span:each_tag()
    span:log('key', 'value')
end

g.test_new_empty_span_tags = function()
    local ctx = opentracing_span_context.new({should_sample = true})
    local empty_span = g.new_span(g.tracer, ctx, "empty")
    t.assert_equals(empty_span:get_tag('tag'), nil, "There isn't such tag")
    t.assert_equals(empty_span:get_tags(), {}, "There aren't tags")
    local tags_count = 0
    for _ in empty_span:each_tag() do
        tags_count = tags_count + 1
    end
    t.assert_equals(tags_count, 0, "There aren't tags: count == 0")
    empty_span:set_tag('my_tag', 'thisistag')
    t.assert_equals(empty_span:get_tag('my_tag'), 'thisistag', "tag was saved")
end

g.test_new_empty_span_logs = function()
    local ctx = opentracing_span_context.new({should_sample = true})
    local empty_span = g.new_span(g.tracer, ctx, "empty")

    local logs_count = 0
    for _ in empty_span:each_log() do
        logs_count = logs_count + 1
    end
    t.assert_equals(logs_count, 0, "There aren't tags: count == 0")

    empty_span:log('my_tag', 'thisistag', 0)
    logs_count = 0
    for _ in empty_span:each_log() do
        logs_count = logs_count + 1
    end
    t.assert_equals(logs_count, 1, "One record saved in log")
end