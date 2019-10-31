local fiber = require('fiber')

local Handler = {}

local DEFAULT_FLUSH_INTERVAL = 60

local worker
local force_flush_cond = fiber.cond()
local wait_exit_chan = fiber.channel(1)

function Handler.start(tracer)
    Handler.stop()

    local reporter = tracer.reporter
    worker = fiber.create(function()
        while true do
            local traces = reporter:flush()
            if #traces > 0 then
                reporter:send_traces(traces)
            end
            if wait_exit_chan:has_readers() then
                wait_exit_chan:put({})
            end
            local timeout = reporter.report_interval or DEFAULT_FLUSH_INTERVAL
            force_flush_cond:wait(timeout)
        end
    end)
    worker:name('zipkin_handler')
end

local WAIT_FOR_CANCEL_TIMEOUT = 5
function Handler.stop()
    if worker ~= nil and worker:status() ~= 'dead' then
        force_flush_cond:signal()
        wait_exit_chan:get(WAIT_FOR_CANCEL_TIMEOUT)
        worker:cancel()
    end
end

return Handler
