--- OpenTracing API module entrypoint
-- @module opentracing
local checks = require('checks')
local span = require('opentracing.span')

local opentracing = {}

local global_tracer

--- Set global tracer
-- @function set_global_tracer
-- @tparam table tracer
function opentracing.set_global_tracer(tracer)
    checks('table')
    global_tracer = tracer
end

--- Get global tracer
-- @function get_global_tracer
-- @treturn table tracer
function opentracing.get_global_tracer()
    return global_tracer
end

--- Start new child span from context
-- @function start_span_from_context
-- @tparam ?table tracer
-- @tparam table context
-- @tparam string name
-- @treturn table span
function opentracing.start_span_from_context(tracer, context, name)
    checks('?table', 'table', 'string')
    local child_context = context:child()
    return span.new(tracer or global_tracer, child_context, name)
end

return opentracing
