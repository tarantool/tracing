--- OpenTracing API module entrypoint
-- @module opentracing
local checks = require('checks')
local span = require('opentracing.span')

local opentracing = {
    tracer = nil,
}

--- Set global tracer
-- @function set_global_tracer
-- @tparam table tracer
function opentracing.set_global_tracer(tracer)
    checks('table')
    opentracing.tracer = tracer
end

--- Get global tracer
-- @function get_global_tracer
-- @treturn table tracer
function opentracing.get_global_tracer()
    return opentracing.tracer
end

--- Start root span
-- @function start_span
-- @tparam string name
-- @treturn table span
function opentracing.start_span(name)
    checks('string')
    return opentracing.tracer:start_span(name)
end

--- Start new child span from context
-- @function start_span_from_context
-- @tparam table context
-- @tparam string name
-- @treturn table span
function opentracing.start_span_from_context(context, name)
    checks('table', 'string')
    local child_context = context:child()
    return span.new(opentracing.tracer, child_context, name)
end

--- Trace function with context by global tracer
-- @function trace_with_context
-- @tparam string name span name
-- @tparam table ctx context
-- @tparam function fun wrapped function
-- @tparam vararg ... function's arguments
-- @treturn[1] vararg result
-- @treturn[2] nil nil
-- @treturn[2] string err error message
function opentracing.trace_with_context(name, ctx, fun, ...)
    checks('string', '?table', 'function')
    local trace_span = opentracing.start_span_from_context(ctx, name)
    local result = { pcall(fun, ...) }
    trace_span:finish()
    if not result[1] then
        local err = result[2]
        trace_span:set_tag('error', err)
        return nil, err
    end
    return unpack(result, 2, table.maxn(result))
end

--- Trace function by global tracer
-- @function trace
-- @tparam string name span name
-- @tparam function fun wrapped function
-- @tparam vararg ... function's arguments
-- @treturn[1] vararg result
-- @treturn[2] nil nil
-- @treturn[2] string err error message
function opentracing.trace(name, fun, ...)
    checks('string', 'function')
    local trace_span = opentracing.start_span(name)
    local result = { pcall(fun, ...) }
    trace_span:finish()
    if not result[1] then
        local err = result[2]
        trace_span:set_tag('error', err)
        return nil, err
    end
    return unpack(result, 2, table.maxn(result))
end

return opentracing
