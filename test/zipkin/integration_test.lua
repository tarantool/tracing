local t = require('luatest')
local g = t.group()

local fiber = require('fiber')
local json = require('json')
local log = require('log')
local http_client = require('http.client')
local ZipkinTracer = require('tracing.zipkin.tracer')
local ZipkinHandler = require('tracing.zipkin.handler')
local opentracing = require('tracing.opentracing')

local Sampler = {
    sample = function() return true end,
}

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

g.before_all(function()
    healthcheck()
end)

g.test_background_reporter = function(test)
    local tracer = ZipkinTracer.new({
        base_url = base_url .. 'spans',
        api_method = 'POST',
        report_interval = 0.2,
        on_error = log_error,
    }, Sampler)

    local span_name = 'test_1'
    local span = tracer:start_span(span_name, {
        tags = {
            ['kind'] = 'client',
        }
    })
    span:log('dummy_reporter', 'log ' .. span_name)
    t.assert(span:finish(), 'Successfully finish span. Background report')
    fiber.sleep(2)
    ZipkinHandler.stop()
    t.assert(check_trace_id(span:context().trace_id), 'Trace was correctly saved')
end

g.test_cli_reporter = function(test)
    local tracer = ZipkinTracer.new({
        base_url = base_url .. '/spans',
        api_method = 'POST',
        report_interval = 0,
        on_error = log_error,
    }, Sampler)

    local span_name = 'test_2'
    local span = tracer:start_span(span_name, {
        tags = {
            ['kind'] = 'client',
        }
    })
    t.assert(span:finish(), 'Successfully finish span. Client report')
    t.assert(check_trace_id(span:context().trace_id), 'Trace was correctly saved')
end

g.test_several_spans = function(test)
    local child_span_count = 9
    local report_interval = 2
    local tracer = ZipkinTracer.new({
        base_url = base_url .. 'spans',
        api_method = 'POST',
        report_interval = report_interval,
        on_error = log_error,
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

    for _ = 1, child_span_count do
        chan:get()
    end
    span:finish()

    fiber.sleep(report_interval)

    local trace = get_trace(span:context().trace_id)
    t.assert(trace, 'Trace was returned')
    t.assert(#trace == 10, '1 root + 9 child spans')
    table.sort(trace, function(a, b) return a.name < b.name end)
    t.assert(context.span_id, trace[10].id, 'Root span id correct')
    for i = 1, child_span_count do
        t.assert('child_span ' .. tostring(i), trace[i].name,
                ('Child span name %s is ok'):format(i))
        t.assert(context.span_id, trace[i].parentId,
                ('Parent id of %s is ok'):format(i))
    end
end
