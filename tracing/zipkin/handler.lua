local log = require('log')
local background = require('background.looper')

local Handler = {}

local DEFAULT_FLUSH_INTERVAL = 60

function Handler.start(tracer)
    local reporter = tracer.reporter
    log.info('Start Zipkin handler')
    background.start(function()
        local traces = reporter:flush()
        if #traces == 0 then
            return
        end
        reporter:send_traces(traces)
    end, { tag = 'zipkin_handler',
           task_interval = reporter.report_interval or DEFAULT_FLUSH_INTERVAL })
end

function Handler.stop()
    background.stop('zipkin_handler')
end

return Handler
