--[[
Span contexts should be immutable
--]]

local digest = require('digest')
local checks = require('checks')

-- For zipkin compat, use 128 bit trace ids
local function generate_trace_id()
	return digest.urandom(16)
end

-- For zipkin compat, use 64 bit span ids
local function generate_span_id()
	return digest.urandom(8)
end

local span_context_methods = {}
local span_context_mt = {
	__name = 'opentracing.span_context',
	__index = span_context_methods,
}

local function is(object)
	return getmetatable(object) == span_context_mt
end

local baggage_mt = {
	__name = 'opentracing.span_context.baggage',
	__newindex = function()
		error('attempt to set immutable baggage')
	end,
}

-- Public constructor
local function new(trace_id, span_id, parent_id, should_sample, baggage)
	checks('?string', '?string', '?string', '?', '?table')
	trace_id = trace_id or generate_trace_id()
	span_id = span_id or generate_span_id()

	local baggage_copy = table.deepcopy(baggage) or {}
	baggage = setmetatable(baggage_copy, baggage_mt)

	return setmetatable({
		trace_id = trace_id,
		span_id = span_id,
		parent_id = parent_id,
		should_sample = should_sample,
		baggage = baggage,
	}, span_context_mt)
end

function span_context_methods:child()
	checks('table')
	return setmetatable({
		trace_id = self.trace_id,
		span_id = generate_span_id(),
		parent_id = self.span_id,
		-- If parent was sampled, sample the child
		should_sample = self.should_sample,
		baggage = self.baggage,
	}, span_context_mt)
end

-- New from existing but with an extra baggage item
function span_context_methods:clone_with_baggage_item(key, value)
	checks('table', 'string', 'string')
	local baggage_copy = table.deepcopy(self.baggage) or {}
	rawset(baggage_copy, key, value)

	return setmetatable({
		trace_id = self.trace_id,
		span_id = self.span_id,
		parent_id = self.parent_id,
		should_sample = self.should_sample,
		baggage = setmetatable(baggage_copy, baggage_mt),
	}, span_context_mt)
end

function span_context_methods:get_baggage_item(key)
	checks('table', 'string')
	return self.baggage and self.baggage[key]
end

function span_context_methods:each_baggage_item()
	checks('table')
	local baggage = self.baggage
	if baggage == nil then return function() end end
	return next, baggage
end

return {
	new = new,
	is = is,
}
