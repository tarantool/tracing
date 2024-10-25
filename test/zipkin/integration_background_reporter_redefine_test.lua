local t = require('luatest')
local g = t.group()

local fiber = require('fiber')
local json = require('json')
local log = require('log')
local http_client = require('http.client')
local ZipkinTracer = require('tracing.zipkin.tracer')
local ZipkinHandler = require('tracing.zipkin.handler')


local base_url ='http://localhost:9411/api/v2/'

local httpc = http_client.new()
local function healthcheck()
    local result = httpc:get(base_url .. '/traces')
    if result.status ~= 200 then
        error('Zipkin is not active on http://localhost:9411/api/v2/. Skip integration tests')
    end
end

local function log_error(err)
    log.error('Zipkin reporter error: %s', err)
end

local function get_trace(trace_id)
    local url = base_url .. 'trace/' .. trace_id
    log.info('Get trace from %s', url)
    local result = httpc:get(url)
    local result_body = result.body and json.decode(result.body)
    if result_body == nil or result_body[1] == nil then
        return nil
    end
    return result_body
end

local function check_trace_id(trace_id)
    local trace = get_trace(trace_id)
    if trace == nil then
        return false
    end
    return trace[1]['traceId'] == trace_id
end

g.test_background_reporter_redefinition = function(test)
    healthcheck()

    local Sampler = {
        sample = function() return true end,
    }


    local tracer = ZipkinTracer.new({
        base_url = base_url .. 'spans',
        api_method = 'POST',
        report_interval = 100,
        on_error = log_error,
    }, Sampler)

    local test_spans_count = 5
    local span = tracer:start_span('root')
    for i = 1, test_spans_count do
        local span_name = 'test_' .. i
        local child_span = span:start_child_span(span_name)
        child_span:log('dummy_reporter_' .. i, 'log ' .. span_name)
        child_span:finish()
    end
    span:finish()

    -- Redefine tracer
    tracer = ZipkinTracer.new({
        base_url = base_url .. 'spans',
        api_method = 'POST',
        report_interval = 0.1,
        on_error = log_error,
    }, Sampler)

    fiber.sleep(1) -- Wait for zipkin internal processes

    local trace = get_trace(span:context().trace_id)
    t.assert_not_equals(trace, nil, 'Trace was successfully saved')
    t.assert_equals(#trace, test_spans_count + 1, "Spans were not lost")

    span = tracer:start_span('new_tracer')
    span:finish()
    fiber.sleep(1)
    t.assert(check_trace_id(span:context().trace_id), 'Trace was correctly saved')

    ZipkinHandler.stop()
end
