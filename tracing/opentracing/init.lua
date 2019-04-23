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

return opentracing
