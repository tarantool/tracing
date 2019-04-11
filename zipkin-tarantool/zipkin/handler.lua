local httpc = require('http.client')
local log = require('log')
local json = require('json')
local background = require('background.looper')

local Handler = {}

local DEFAULT_FLUSH_INTERVAL = 60

function Handler.start(tracer)
    local reporter = tracer.reporter
    log.info('Start Zipkin handler')
    background.start(function()
        local client = httpc.new()
        local traces = reporter:flush()
        if #traces == 0 then
            return
        end
        local ok, data = pcall(json.encode, traces)
        if not ok then
            log.error('Handler error %s', data)
            return
        end
        print(data)
        local result = client:request(reporter.api_method, reporter.base_url, data)
        if 200 > result.status or result.status >= 300 then
            log.error('Handler http request error: %s [%s] (%s)',
                    result.reason, result.status, result.body)
        else
            log.info('Report %d spans to zipkin [%s]', #traces, result.status)
        end
    end, { tag = 'zipkin_handler',
           task_interval = reporter.report_interval or DEFAULT_FLUSH_INTERVAL })
end

function Handler.stop()
    background.stop('zipkin_handler')
end

return Handler
