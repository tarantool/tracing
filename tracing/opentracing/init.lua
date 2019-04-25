--- OpenTracing API module entrypoint
-- @module opentracing
local checks = require('checks')
local span = require('opentracing.span')
local extractors = require('opentracing.extractors')
local injectors = require('opentracing.injectors')

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
-- @tparam ?table opts table specifying modifications to make to the
--   newly created span. The following parameters are supported: `trace_id`, `references`,
--   a list of referenced spans; `start_time`, the time to mark when the span
--   begins (in microseconds since epoch); `tags`, a table of tags to add to
--   the created span.
-- @tparam ?string opts.trace_id
-- @tparam ?table opts.child_of
-- @tparam ?table opts.references
-- @tparam ?table opts.tags
-- @treturn table span
function opentracing.start_span(name, opts)
    checks('string', '?table')
    return opentracing.tracer:start_span(name, opts)
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
--   This function starts span from global tracer and finishes it after execution
-- @function trace_with_context
-- @tparam string name span name
-- @tparam table ctx context
-- @tparam function fun wrapped function
-- @tparam vararg ... function's arguments
-- @usage
--    -- Process HTTP request
--    local ctx = opentracing.extractors.http(req.headers)
--    local result, err = opentracing.trace_with_context('process_data', ctx, process_data, req.body)
--    -- Wrap functions. In example we create root span that generates two child spans
--    local span = opentracing.start_span()
--    local result, err = opentracing.trace_with_context('format_string', span:context(), format, str)
--    if not result ~= nil then
--        print('Error: ', err)
--    end
--    opentracing.trace_with_context('print_string', span:context(), print, result)
--    span:finish()
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
--   This function starts span from global tracer and finishes it after execution
-- @function trace
-- @tparam string name span name
-- @tparam function fun wrapped function
-- @tparam vararg ... function's arguments
-- @usage
--    local result, err = opentracing.trace_with_context('process_data', process_data, req.body)
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

-- Aliases for useful and available functions
opentracing.http_extract = extractors.http
opentracing.map_extract = extractors.map
opentracing.http_inject = injectors.http
opentracing.map_inject = injectors.map

return opentracing
