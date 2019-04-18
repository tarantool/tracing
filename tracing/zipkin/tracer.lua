--- Client for Zipkin
-- @module zipkin.tracer
local checks = require('checks')

local Reporter = require('zipkin.reporter')
local Handler = require('zipkin.handler')
local OpenTracingTracer = require('opentracing.tracer')

local Tracer = {}

--- Init new Zipkin Tracer
-- @function new
-- @tparam table config Table with Zipkin configuration
-- @tparam table config.base_url Zipkin API base url
-- @tparam table config.api_method API method to send spans to zipkin
-- @tparam table config.report_interval Interval of reports to zipkin
-- @tparam table sampler Table that contains function sample
--   that is apply span name and mark this span for further report
-- @tparam function config.on_error On error callback that apply error in string format
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
