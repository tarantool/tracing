#!/usr/bin/env tarantool

local test = require('tap').test('Zipkin integration')
local fiber = require('fiber')
local json = require('json')
local log = require('log')
local http_client = require('http.client')
local ZipkinTracer = require('zipkin.tracer')
local ZipkinHandler = require('zipkin.handler')

local Sampler = {
    sample = function() return true end,
}

local base_url ='http://localhost:9411/api/v2/'

local function healthcheck()
    local httpc = http_client.new()
    local result = httpc:get(base_url .. '/traces')
    if result.status ~= 200 then
        log.warn('Zipkin is not active on http://localhost:9411/api/v2/. Skip integration tests')
        os.exit(0)
    end
end

healthcheck()

test:plan(2)

local function check_trace_id(trace_id)
    local httpc = http_client.new()
    local trace_id_hex = string.hex(trace_id)
    local result = httpc:get(base_url .. '/trace/' .. trace_id_hex)
    local result_body = result.body and json.decode(result.body)
    if result_body == nil or result_body[1] == nil then
        return false
    end
    return result_body[1]['traceId'] == trace_id_hex
end

test:test('Background reporter', function(test)
    test:plan(2)
    local tracer = ZipkinTracer.new({
        base_url = base_url .. '/spans',
        api_method = 'POST',
        report_interval = 0.2,
    }, Sampler)

    local span_name = 'test_1'
    local span = tracer:start_span(span_name, {
        tags = {
            ['kind'] = 'client',
        }
    })
    span:log('dummy_reporter', 'log ' .. span_name)
    test:ok(span:finish(), 'Successfully finish span. Background report')
    fiber.sleep(1)
    ZipkinHandler.stop()
    test:ok(check_trace_id(span.context_.trace_id), 'Trace was correctly saved')
end)

test:test('CLI-reporter', function(test)
    test:plan(2)
    local tracer = ZipkinTracer.new({
        base_url = base_url .. '/spans',
        api_method = 'POST',
        report_interval = 0,
    }, Sampler)

    local span_name = 'test_2'
    local span = tracer:start_span(span_name, {
        tags = {
            ['kind'] = 'client',
        }
    })
    test:ok(span:finish(), 'Successfully finish span. Client report')
    test:ok(check_trace_id(span.context_.trace_id), 'Trace was correctly saved')
end)

os.exit(test:check() and 0 or 1)
