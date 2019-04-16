-- @module opentracing.tracer
-- @release
-- Tracer is the entry point API between instrumentation code and the
-- tracing implementation.
--
-- This implementation both defines the public Tracer API, and provides
-- a default no-op behavior.

local clock = require("clock")
local checks = require("checks")
local opentracing_span = require("opentracing.span")
local opentracing_span_context = require("opentracing.span_context")

local tracer_methods = {}
local tracer_mt = {
    __name = "opentracing.tracer",
    __index = tracer_methods,
}

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

--- Init new tracer
--- @function new
--- @tparam table reporter
--- @tparam function reporter.report
--- @tparam table sampler
--- @tparam function sampler.sample
--- @treturn table tracer
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

--- Starts and returns a new @class `Span` representing a unit of work.
--
-- Example usage:
--
-- Create a root @class `Span` (a @class `Span` with no causal references):
--
--      tracer:start_span("op-name")
--
-- Create a child @class `Span`:
--
--      tracer:start_span(
--              "op-name",
--              {["references"] = {{"child_of", parent_span:context()}}})
--
--- @function start_span
--- @tparam table self
--- @tparam string name operation_name name of the operation represented by the new
----    @class `Span` from the perspective of the current service.
--- @tparam ?table opts table specifying modifications to make to the
----    newly created span. The following parameters are supported: `references`,
----    a list of referenced spans; `start_time`, the time to mark when the span
----    begins (in microseconds since epoch); `tags`, a table of tags to add to
----    the created span.
--- @tparam table opts.child_of
--- @tparam table opts.references
--- @tparam table opts.tags
--- @tparam ?number opts.start_timestamp
--- @treturn table span a @class `Span` instance
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
        child_of = child_of:context()
    end
    if references ~= nil then
        error("It seems references is used, but it is not supported. Use child_of instead")
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
    return clock.monotonic64() / 1000
end

function tracer_methods:report(span)
    checks('table', 'table')
    return self.reporter:report(span)
end

--- Register injector for tracer
--- @function register_injector
--- @tparam table self
--- @tparam string format
--- @tparam function injector
--- @treturn boolean `true`
function tracer_methods:register_injector(format, injector)
    checks('table', 'string', 'function|table')
    self.injectors[format] = injector
    return true
end

--- Register extractor for tracer
--- @function register_extractor
--- @tparam table self
--- @tparam string format
--- @tparam function extractor
--- @treturn boolean `true`
function tracer_methods:register_extractor(format, extractor)
    checks('table', 'string', 'function|table')
    self.extractors[format] = extractor
    return true
end

--- Inject context into carrier with specified format
--- See https://opentracing.io/docs/overview/inject-extract/
--- @function inject
--- @tparam table self
--- @tparam table context
--- @tparam string format
--- @tparam table carrier
--- @treturn[1] table carrier
--- @treturn[2] nil
--- @treturn[2] string error
function tracer_methods:inject(context, format, carrier)
    checks('table', 'table', 'string', '?')
    local injector = self.injectors[format]
    if injector == nil then
        return nil, "Unknown format: " .. format
    end
    return injector(context, carrier)
end

--- Extract context from carrier with specified format
--- See https://opentracing.io/docs/overview/inject-extract/
--- @function extract
--- @tparam table self
--- @tparam string format
--- @tparam table carrier
--- @treturn[1] table context
--- @treturn[2] nil
--- @treturn[2] string error
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
}
