#!/usr/bin/env tarantool

local test = require('tap').test('Zipkin integration')
local fiber = require('fiber')
local json = require('json')
local log = require('log')
local http_client = require('http.client')
local ZipkinTracer = require('zipkin.tracer')
local ZipkinHandler = require('zipkin.handler')
local opentracing = require('opentracing')

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

test:plan(3)

local function get_trace(trace_id)
    local httpc = http_client.new()
    local trace_id_hex = string.hex(trace_id)
    local result = httpc:get(base_url .. '/trace/' .. trace_id_hex)
    local result_body = result.body and json.decode(result.body)
    if result_body == nil or result_body[1] == nil then
        return nil
    end
    return result_body
end

local function check_trace_id(trace_id)
    local trace = get_trace(trace_id)
    local trace_id_hex = string.hex(trace_id)
    if trace == nil then
        return false
    end
    return trace[1]['traceId'] == trace_id_hex
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
    test:ok(check_trace_id(span:context().trace_id), 'Trace was correctly saved')
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
    test:ok(check_trace_id(span:context().trace_id), 'Trace was correctly saved')
end)

test:test('Several spans', function(test)
    local child_span_count = 9
    test:plan(child_span_count * 2 + 2)
    local report_interval = 2
    local tracer = ZipkinTracer.new({
        base_url = base_url .. '/spans',
        api_method = 'POST',
        report_interval = report_interval,
    }, Sampler)
    opentracing.set_global_tracer(tracer)

    local context = {}

    local span = tracer:start_span('root')
    span:set_client_kind()
    opentracing.map_inject(span:context(), context)

    local chan = fiber.channel(child_span_count)
    for i = 1, child_span_count do
        fiber.create(function()
            local span_context = opentracing.map_extract(context)
            local child_span = opentracing.start_span_from_context(
                    span_context, 'child_span ' .. tostring(i))
            child_span:set_server_kind()
            fiber.sleep(math.random(10) / 10)
            child_span:finish()
            chan:put({})
        end)
    end

    for i = 1, child_span_count do
        chan:get()
    end
    span:finish()

    fiber.sleep(report_interval)

    local trace = get_trace(span:context().trace_id)
    test:ok(#trace == 10, '1 root + 9 child spans')
    table.sort(trace, function(a, b) return a.name < b.name end)
    test:is(context.span_id, trace[10].id, 'Root span id correct')
    for i = 1, child_span_count do
        test:is('child_span ' .. tostring(i), trace[i].name,
                ('Child span name %s is ok'):format(i))
        test:is(context.span_id, trace[i].parentId,
                ('Parent id of %s is ok'):format(i))
    end
end)

os.exit(test:check() and 0 or 1)
