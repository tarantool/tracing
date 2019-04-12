local clock = require("clock")
local checks = require("checks")
local opentracing_span = require("opentracing.span")
local opentracing_span_context = require("opentracing.span_context")

local tracer_methods = {}
local tracer_mt = {
	__name = "opentracing.tracer",
	__index = tracer_methods,
}

local function is(object)
	return getmetatable(object) == tracer_mt
end

local no_op_reporter = {
	report = function() end,
}
local no_op_sampler = {
	sample = function() return false end,
}

-- Make injectors and extractors weakly keyed so that unreferenced formats get dropped
local injectors_metatable = {
	__name = "opentracing.tracer.injectors",
	__mode = "k",
}
local extractors_metatable = {
	__name = "opentracing.tracer.extractors",
	__mode = "k",
}

local function new(reporter, sampler)
	checks('?table', '?table')
	reporter = reporter or no_op_reporter
	sampler = sampler or no_op_sampler

	return setmetatable({
		injectors = setmetatable({}, injectors_metatable),
		extractors = setmetatable({}, extractors_metatable),
		reporter = reporter,
		sampler = sampler,
	}, tracer_mt)
end

function tracer_methods:start_span(name, opts)
	opts = opts or {}
	checks('table', 'string', {
		child_of = '?table',
		references = '?table',
		tags = '?table',
		start_timestamp = '?number|cdata',
	})

	local child_of = opts.child_of
	local references = opts.references

	if child_of ~= nil then
		assert(references == nil, "cannot specify both references and child_of")
		if opentracing_span.is(child_of) then
			child_of = child_of:context()
		else
			assert(opentracing_span_context.is(child_of), "child_of should be a span or span context")
		end
	end
	if references ~= nil then
		error("references NYI")
	end

	local tags = opts.tags
	local start_timestamp = opts.start_timestamp or self:time()
	-- Allow opentracing_span.new to validate

    local context, extra_tags
	if child_of ~= nil then
		context = child_of:child()
	else
		local should_sample
		should_sample, extra_tags = self.sampler:sample(name)
		context = opentracing_span_context.new(nil, nil, nil, should_sample)
	end

    local span = opentracing_span.new(self, context, name, start_timestamp)

    if extra_tags ~= nil then
		for k, v in pairs(extra_tags) do
			span:set_tag(k, v)
		end
	end

    if tags ~= nil then
		for k, v in pairs(tags) do
			span:set_tag(k, v)
		end
	end

	return span
end

-- Spans belonging to this tracer will get timestamps in microseconds via this method
-- Can be overridden for e.g. testing
function tracer_methods:time() -- luacheck: ignore 212
	checks('table')
	return clock.realtime64() / 1000
end

function tracer_methods:report(span)
	checks('table', 'table')
	return self.reporter:report(span)
end

function tracer_methods:register_injector(format, injector)
	checks('table', 'string', '?')
	self.injectors[format] = injector
	return true
end

function tracer_methods:register_extractor(format, extractor)
	checks('table', 'string', '?')
	self.extractors[format] = extractor
	return true
end

function tracer_methods:inject(context, format, carrier)
	checks('table', 'table', 'string', '?')
	if opentracing_span.is(context) then
		context = context:context()
	else
		assert(opentracing_span_context.is(context), "context should be a span or span context")
	end
	local injector = self.injectors[format]
	if injector == nil then
		return nil, "Unknown format: " .. format
	end
	return injector(context, carrier)
end

function tracer_methods:extract(format, carrier)
	checks('table', 'string', '?')
	local extractor = self.extractors[format]
	if extractor == nil then
		return nil, "Unknown format: " .. format
	end
	return extractor(carrier)
end

return {
	new = new,
	is = is,
}
