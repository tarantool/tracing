local t = require('luatest')

local g = t.group()

local opentracing_span_context = require("tracing.opentracing.span_context")
local opentracing_tracer = require("tracing.opentracing.tracer")

g.before_all(function ()
    g.new_tracer = opentracing_tracer.new
end)

g.test_fail_constructing_span_without_name = function()
    local tracer = g.new_tracer()
    t.assert_error(tracer.start_span, tracer)
end

g.test_call_sampler_for_root_traces = function()
    local sampler_arg
    local mock_sampler = {
        sample = function(_, arg)
            sampler_arg = arg
            return false
        end,
    }
    local tracer = g.new_tracer(nil, mock_sampler)
    tracer:start_span("foo")
    t.assert_equals(sampler_arg, "foo")
end

g.test_take_returned_sampler_tags_into_account = function()
    local sampler_arg
    local mock_sampler = {
        sample = function(_, arg)
            sampler_arg = arg
            return true, {
                ["sampler.type"] = "mock",
            }
        end,
    }
    local tracer = g.new_tracer(nil, mock_sampler)
    local span = tracer:start_span("foo")
    t.assert_equals(sampler_arg, "foo")
    local tags = {}
    for k, v in span:each_tag() do
        tags[k] = v
    end

    t.assert_equals({["sampler.type"] = "mock"}, tags)
end

g.test_call_reporter_at_end_of_span = function()
    local sampler_arg
    local mock_sampler = {
        sample = function(_, arg)
            sampler_arg = arg
            return true
        end
    }
    local reporter_arg
    local mock_reporter = {
        report = function(_, arg) reporter_arg = arg end
    }
    local tracer = g.new_tracer(mock_reporter, mock_sampler)
    local span = tracer:start_span("foo")
    t.assert_equals(sampler_arg, 'foo')
    span:finish()
    t.assert_equals(reporter_arg, span)
end

g.test_allows_passing_in_tags = function()
    local tracer = g.new_tracer()
    local tags = {
        ["http.method"] = "GET",
        ["http.url"] = "https://example.com/",
    }
    local span = tracer:start_span("foo", {
        tags = tags
    })
    local seen = {}
    for k, v in span:each_tag() do
        seen[k] = v
    end
    t.assert_equals(tags, seen)
end

g.test_allows_passing_span_as_child_of = function()
    local tracer = g.new_tracer()
    local span1 = tracer:start_span("foo")
    tracer:start_span("bar", {
        child_of = span1
    })
end

g.test_fail_allow_invalid_chil_of = function()
    local tracer = g.new_tracer()
    t.assert_error(function()
        tracer:start_span("foo", { child_of = {} })
    end)
end

g.test_fail_invalid_references = function()
    local tracer = g.new_tracer()
    t.assert_error(function()
        tracer:start_span("foo", { references = true })
    end)
end

g.test_works_with_custom_extracor = function()
    local tracer = g.new_tracer()
    local extractor_arg
    local mock_extractor = function(arg)
        extractor_arg = arg
        local context = opentracing_span_context.new()
        return context
    end
    tracer:register_extractor("my_type", mock_extractor)
    local carrier = {}
    tracer:extract("my_type", carrier)
    t.assert_equals(carrier, extractor_arg)
end

g.test_checks_for_known_extracor = function()
    local tracer = g.new_tracer()
    local data, err = tracer:extract("my_unknown_type", {})
    t.assert_equals(data, nil)
    t.assert_equals(err, 'Unknown format: my_unknown_type')
end

g.test_works_with_custom_injector = function()
    local tracer = g.new_tracer()
    local injector_arg_ctx, injector_arg_carrier
    local mock_injector = function(context, carrier)
        injector_arg_ctx = context
        injector_arg_carrier = carrier
    end
    tracer:register_injector("my_type", mock_injector)

    local span = tracer:start_span("foo")
    local context = span:context()
    local carrier = {}
    tracer:inject(context, "my_type", carrier)
    t.assert_equals(context, injector_arg_ctx)
    t.assert_equals(carrier, injector_arg_carrier)
end

g.test_inject_takes_context = function()
    local tracer = g.new_tracer()
    local injector_arg_ctx, injector_arg_carrier
    local mock_injector = function(context, carrier)
        injector_arg_ctx = context
        injector_arg_carrier = carrier
    end
    tracer:register_injector("my_type", mock_injector)
    local span = tracer:start_span("foo")
    local context = span:context()
    local carrier = {}
    tracer:inject(span:context(), "my_type", carrier)
    t.assert_equals(context, injector_arg_ctx)
    t.assert_equals(carrier, injector_arg_carrier)
end

g.test_checks_for_known_injector = function()
    local tracer = g.new_tracer()
    local span = tracer:start_span("foo")
    local context = span:context()
    local data, err = tracer:inject(context, "my_unknown_type", {})
    t.assert_equals(data, nil)
    t.assert_equals('Unknown format: my_unknown_type', err)
end