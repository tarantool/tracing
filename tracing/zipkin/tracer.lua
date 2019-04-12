local checks = require('checks')

local Reporter = require('zipkin.reporter')
local Handler = require('zipkin.handler')
local OpenTracingTracer = require('opentracing.tracer')

local Tracer = {}

function Tracer.new(config, sampler)
    checks({ base_url = 'string',
             api_method = 'string',
             report_interval = 'number' }, '?table')
    local reporter = Reporter.new(config)
    local self = OpenTracingTracer.new(reporter, sampler)
    Handler.start(self)
    return self
end

return Tracer
