--- SpanContext represents `Span` state that must propagate to
-- descendant `Span`\ s and across process boundaries.
--
-- SpanContext is logically divided into two pieces: the user-level "Baggage"
--  (see `Span.set_baggage_item` and `Span.get_baggage_item`) that
--  propagates across `Span` boundaries and any
--  tracer-implementation-specific fields that are needed to identify or
--  otherwise contextualize the associated `Span` (e.g., a (trace\_id,
--  span\_id, sampled) tuple).
-- @module opentracing.span_context

local digest = require('digest')
local uuid = require('uuid')
local checks = require('checks')

-- TODO: choose length of trace_id and span_id depends on options if we plan to support another tracing systems
-- For zipkin compat, use 128 bit trace ids
local function generate_trace_id()
    return uuid.bin()
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

local baggage_mt = {
    __name = 'opentracing.span_context.baggage',
    __newindex = function()
        error('attempt to set immutable baggage')
    end,
}

--- Create new span context
-- @function new
-- @tparam ?string trace_id
-- @tparam ?string span_id
-- @tparam ?string parent_id
-- @tparam ?boolean should_sample
-- @tparam ?table baggage
-- @treturn table span context
local function new(trace_id, span_id, parent_id, should_sample, baggage)
    checks('?string', '?string', '?string', '?boolean', '?table')
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

--- Create span child span context
-- @function child
-- @treturn table child span context
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

--- New from existing but with an extra baggage item
-- Clone context and add item to its baggage
-- @function clone_with_baggage_item
-- @tparam table self
-- @tparam string key
-- @tparam string value
-- @treturn table context
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

--- Get item from baggage
-- @function get_baggage_item
-- @tparam table self
-- @tparam string key
-- @treturn string value
function span_context_methods:get_baggage_item(key)
    checks('table', 'string')
    return self.baggage and self.baggage[key]
end

--- Get baggage item iterator
-- @function each_baggage_item
-- @tparam table self
-- @treturn function iterator
-- @treturn table baggage
function span_context_methods:each_baggage_item()
    checks('table')
    local baggage = self.baggage
    if baggage == nil then return function() end end
    return next, baggage
end

return {
    new = new,
}
