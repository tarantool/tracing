--- Span represents a unit of work executed on behalf of a trace. Examples of
-- spans include a remote procedure call, or a in-process method call to a
-- sub-component. Every span in a trace may have zero or more causal parents,
-- and these relationships transitively form a DAG. It is common for spans to
-- have at most one parent, and thus most traces are merely tree structures.
--
-- The internal data structure is modeled off the ZipKin Span JSON Structure
-- This makes it cheaper to convert to JSON for submission to the ZipKin HTTP api,
-- which Jaegar also implements.
-- You can find it documented in this OpenAPI spec:
-- https://github.com/openzipkin/zipkin-api/blob/7e33e977/zipkin2-api.yaml#L280
-- @module opentracing.span

local checks = require('checks')

local span_methods = {}
local span_mt = {
    __name = 'opentracing.span',
    __index = span_methods,
}

--- Create new span
-- @function new
-- @tparam table tracer
-- @tparam table context
-- @tparam string name
-- @tparam ?number start_timestamp
-- @treturn table span
local function new(tracer, context, name, start_timestamp)
    checks('table', 'table', 'string', '?number|cdata')
    return setmetatable({
        tracer = tracer,
        ctx = context,
        name = name,
        timestamp = start_timestamp or tracer:time(),
        duration = nil,
        -- Avoid allocations until needed
        baggage = {},
        tags = {},
        logs = {},
    }, span_mt)
end

--- Provides access to the `SpanContext` associated with this `Span`
-- The `SpanContext` contains state that propagates from `Span`
-- to `Span` in a larger tracer.
--
-- @function context
-- @tparam table self
-- @treturn table context
function span_methods:context()
    checks('table')
    return self.ctx
end

--- Provides access to the `Tracer` that created this span.
-- @function tracer
-- @tparam table self
-- @treturn table tracer the `Tracer` that created this span.
function span_methods:get_tracer()
    checks('table')
    return self.tracer
end

--- Changes the operation name
-- @function set_operation_name
-- @tparam table self
-- @tparam string name
-- @treturn table tracer
function span_methods:set_operation_name(name)
    checks('table', 'string')
    self.name = name
end

--- Start child span
-- @function start_child_span
-- @tparam table self
-- @tparam string name
-- @tparam ?number start_timestamp
-- @treturn table child span
function span_methods:start_child_span(name, start_timestamp)
    checks('table', 'string', '?number|cdata')
    return self.tracer:start_span(name, {
        start_timestamp = start_timestamp,
        child_of = self,
    })
end

--- Indicates the work represented by this `Span` has completed or
-- terminated.
--
-- If `finish` is called a second time, it is guaranteed to do nothing.
-- @function finish
-- @tparam table self
-- @tparam ?number finish_timestamp a timestamp represented by microseconds
--   since the epoch to mark when the span ended. If unspecified, the current
--   time will be used.
-- @treturn[1] boolean `true`
-- @treturn[2] boolean `false`
-- @treturn[2] string error
function span_methods:finish(finish_timestamp)
    checks('table', '?number|cdata')
    if self.duration ~= nil then
        return false, 'span already finished'
    end
    if finish_timestamp == nil then
        self.duration = self.tracer:time() - self.timestamp
    else
        self.duration = finish_timestamp - self.timestamp
        if self.duration < 0 then
            return nil, 'Span duration can not be negative'
        end
    end
    if self.ctx.should_sample then
        self.tracer:report(self)
    end
    return true
end

--- Attaches a key/value pair to the `Span`.
--
-- The value must be a string, bool, numeric type, or table of such values.
-- @function set_tag
-- @tparam table self
-- @tparam string key key or name of the tag. Must be a string.
-- @tparam any value value of the tag
-- @treturn boolean `true`
function span_methods:set_tag(key, value)
    checks('table', 'string', '?')
    self.tags[key] = value
    return true
end

--- Get span's tag
-- @function get_tag
-- @tparam table self
-- @tparam string key
-- @treturn any tag value
function span_methods:get_tag(key)
    checks('table', 'string')
    local tags = self.tags
    if tags then
        return tags[key]
    else
        return nil
    end
end

--- Get tags iterator
-- @function each_tag
-- @tparam table self
-- @treturn function iterator
-- @treturn table tags
function span_methods:each_tag()
    checks('table')
    local tags = self.tags
    if tags == nil then
        return function() end
    end
    return next, tags
end

--- Get copy of span's tags
-- @function tags
-- @tparam table self
-- @treturn table tags
function span_methods:tags()
    checks('table')
    return table.deepcopy(self.tags)
end

--- Log some action
-- @function log
-- @tparam table self
-- @tparam table key
-- @tparam table value
-- @tparam ?number timestamp
-- @treturn boolean `true`
function span_methods:log(key, value, timestamp)
    -- `value` is allowed to be anything.
    checks('table', 'string', '?', '?number|cdata')
    timestamp = timestamp or self.tracer:time()
    table.insert(self.logs, {
        key = key,
        value = value,
        timestamp = timestamp,
    })
    return true
end

--- Attaches a log record to the `Span`.
--
-- @usage
--    span:log_kv({
--      ["event"] = "time to first byte",
--      ["packet.size"] = packet:size()})
--
-- @function log_kv
-- @tparam table self
-- @tparam table key_values a table of string keys and values of string, bool, or
--   numeric types
-- @tparam ?number timestamp an optional timestamp as a unix timestamp.
--   defaults to the current time
-- @treturn boolean `true`
function span_methods:log_kv(key_values, timestamp)
    checks('table', 'table', '?number|cdata')
    timestamp = timestamp or self.tracer:time()

    for key, value in pairs(key_values) do
        table.insert(self.logs, {
            key = key,
            value = value,
            timestamp = timestamp,
        })
    end

    return true
end

--- Get span's logs iterator
-- @function each_log
-- @tparam table self
-- @treturn function log iterator
-- @treturn table logs
function span_methods:each_log()
    checks('table')
    local i = 0
    return function(logs)
        if i >= #self.logs then
            return
        end
        i = i + 1
        local log = logs[i]
        return log.key, log.value, log.timestamp
    end, self.logs
end

--- Stores a Baggage item in the `Span` as a key/value pair.
--
-- Enables powerful distributed context propagation functionality where
-- arbitrary application data can be carried along the full path of request
-- execution throughout the system.
--
-- Note 1: Baggage is only propagated to the future (recursive) children of this
-- `Span`.
--
-- Note 2: Baggage is sent in-band with every subsequent local and remote calls,
-- so this feature must be used with care.
-- @function set_baggage_item
-- @tparam table self
-- @tparam string key Baggage item key
-- @tparam string value Baggage item value
-- @treturn boolean `true`
function span_methods:set_baggage_item(key, value)
    checks('table', 'string', 'string')
    -- Create new context so that baggage is immutably passed around
    self.ctx = self.ctx:clone_with_baggage_item(key, value)
    return true
end

--- Retrieves value of the baggage item with the given key.
-- @function get_baggage_item
-- @tparam table self
-- @tparam string key
-- @treturn string value
function span_methods:get_baggage_item(key)
    checks('table', 'string')
    return self.ctx:get_baggage_item(key)
end

--- Returns an iterator over each attached baggage item
-- @function each_baggage_item
-- @tparam table self
-- @treturn function iterator
-- @treturn table baggage
function span_methods:each_baggage_item()
    checks('table')
    return self.ctx:each_baggage_item()
end

return {
    new = new,
}
