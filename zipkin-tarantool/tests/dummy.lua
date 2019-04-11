#!/usr/bin/env tarantool

local fiber = require('fiber')
local log = require('log')
local ZipkinTracer = require('zipkin.tracer')

local Sampler = {
    sample = function() return true end,
}

local tracer = ZipkinTracer.new({
    base_url = 'localhost:9411/api/v2/spans',
    api_method = 'POST',
    report_interval = 1,
}, Sampler)

local i = 0
local function dummy_span_reporter()
    local span_name = 'dummy_span_' .. tostring(i)
    local span = tracer:start_span(span_name, {
        tags = {
            ['kind'] = 'client',
        }
    })
    fiber.sleep(1)
    span:log('dummy_reporter', 'log ' .. span_name)
    span:finish()
    log.info('Report span: %s', span_name)
end

dummy_span_reporter()
