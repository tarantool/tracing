--- Client for Zipkin
-- @module zipkin.tracer
local checks = require('checks')

local Reporter = require('zipkin.reporter')
local Handler = require('zipkin.handler')
local OpenTracingTracer = require('opentracing.tracer')

local Tracer = {}

--- Init new Zipkin Tracer
-- @function new
-- @tparam table config
-- @tparam table config.base_url
-- @tparam table config.api_method
-- @tparam table config.report_interval
-- @tparam table sampler
-- @treturn table context
function Tracer.new(config, sampler)
    checks({ base_url = 'string',
             api_method = 'string',
             report_interval = 'number',
             on_error = '?function' }, '?table')

    local reporter = Reporter.new(config)
    local self = OpenTracingTracer.new(reporter, sampler)

    if config.report_interval > 0 then
        Handler.start(self)
    end

    return self
end

return Tracer
