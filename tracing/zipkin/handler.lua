local fiber = require('fiber')

local Handler = {}

local DEFAULT_FLUSH_INTERVAL = 60

local worker

function Handler.start(tracer)
    local reporter = tracer.reporter

    worker = fiber.create(function()
        while true do
            local traces = reporter:flush()
            if #traces > 0 then
                reporter:send_traces(traces)
            end
            fiber.testcancel()
            fiber.sleep(reporter.report_interval or DEFAULT_FLUSH_INTERVAL)
        end
    end)
    worker:name('zipkin_handler')
end

function Handler.stop()
    if worker ~= nil then
        worker:cancel()
    end
end

return Handler
