#!/usr/bin/env tarantool

local tap = require('tap')
local test = tap.test('opentracing.tracer')

test:plan(15)
local opentracing_span_context = require("opentracing.span_context")
local opentracing_tracer = require("opentracing.tracer")
local new_tracer = opentracing_tracer.new

test:test("has working .is function", function(test)
	test:plan(3)
	test:ok(not opentracing_tracer.is(nil))
	test:ok(not opentracing_tracer.is({}))
	local tracer = new_tracer()
	test:ok(opentracing_tracer.is(tracer))
end)

test:test("doesn't allow constructing span without a name", function(test)
	test:plan(1)
	local tracer = new_tracer()
	local ok, _ = pcall(function()
		tracer:start_span(nil)
	end)
	test:ok(not ok)
end)

test:test("calls sampler for root traces", function(test)
	test:plan(1)
	local sampler_arg
	local mock_sampler = {
		sample = function(_, arg)
			sampler_arg = arg
			return false
		end,
	}
	local tracer = new_tracer(nil, mock_sampler)
	tracer:start_span("foo")
	test:is(sampler_arg, "foo")
end)

test:test("takes returned sampler tags into account", function(test)
	test:plan(2)
	local sampler_arg
	local mock_sampler = {
		sample = function(_, arg)
			sampler_arg = arg
			return true, {
				["sampler.type"] = "mock",
			}
		end,
	}
	local tracer = new_tracer(nil, mock_sampler)
	local span = tracer:start_span("foo")
	test:is(sampler_arg, "foo")
	local tags = {}
	for k, v in span:each_tag() do
		tags[k] = v
	end
	test:is_deeply({["sampler.type"] = "mock"}, tags)
end)

test:test("calls reporter at end of span", function(test)
	test:plan(2)
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
	local tracer = new_tracer(mock_reporter, mock_sampler)
	local span = tracer:start_span("foo")
	test:is(sampler_arg, 'foo')
	span:finish()
	test:is_deeply(reporter_arg, span)
end)

test:test("allows passing in tags", function(test)
	test:plan(1)
	local tracer = new_tracer()
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
	test:is_deeply(tags, seen)
end)

test:test("allows passing span as a child_of", function(test)
	local tracer = new_tracer()
	local span1 = tracer:start_span("foo")
	tracer:start_span("bar", {
		child_of = span1
	})
end)

test:test("allows passing span context as a child_of", function(test)
	local tracer = new_tracer()
	local span1 = tracer:start_span("foo")
	tracer:start_span("bar", {
		child_of = span1:context()
	})
end)

test:test("doesn't allow invalid child_of", function(test)
	test:plan(1)
	local tracer = new_tracer()
	local ok, _ = pcall(function()
		tracer:start_span("foo", { child_of = {} })
	end)
	test:ok(not ok)
end)

test:test("doesn't allow invalid references", function(test)
	test:plan(1)
	local tracer = new_tracer()
	local ok, _ = pcall(function()
		tracer:start_span("foo", { references = true })
	end)
	test:ok(not ok)
end)

test:test("works with custom extractor", function(test)
	test:plan(1)
	local tracer = new_tracer()
	local extractor_arg
	local mock_extractor = function(arg)
		extractor_arg = arg
		local context = opentracing_span_context.new()
		return context
	end
	tracer:register_extractor("my_type", mock_extractor)
	local carrier = {}
	tracer:extract("my_type", carrier)
	test:is_deeply(carrier, extractor_arg)
end)

test:test("checks for known extractor", function(test)
	test:plan(2)
	local tracer = new_tracer()
	local data, err = tracer:extract("my_unknown_type", {})
	test:isnil(data)
	test:is('Unknown format: my_unknown_type', err)
end)

test:test("works with custom injector", function(test)
	test:plan(2)
	local tracer = new_tracer()
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
	test:is_deeply(context, injector_arg_ctx)
	test:is_deeply(carrier, injector_arg_carrier)
end)

test:test(":inject takes span", function(test)
	test:plan(2)
	local tracer = new_tracer()
	local injector_arg_ctx, injector_arg_carrier
	local mock_injector = function(context, carrier)
		injector_arg_ctx = context
		injector_arg_carrier = carrier
	end
	tracer:register_injector("my_type", mock_injector)
	local span = tracer:start_span("foo")
	local context = span:context()
	local carrier = {}
	tracer:inject(span, "my_type", carrier)
	test:is_deeply(context, injector_arg_ctx)
	test:is_deeply(carrier, injector_arg_carrier)
end)

test:test("checks for known injector", function(test)
	test:plan(2)
	local tracer = new_tracer()
	local span = tracer:start_span("foo")
	local context = span:context()
	local data, err = tracer:inject(context, "my_unknown_type", {})
	test:isnil(data)
	test:is('Unknown format: my_unknown_type', err)
end)

os.exit(test:check() and 0 or 1)
