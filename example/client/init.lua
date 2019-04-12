#!/usr/bin/env tarantool

local http_client = require('http.client')
local json = require('json')
local zipkin = require('zipkin.tracer')
local opentracing_span = require('opentracing.span')
local http_injector = require('opentracing.injectors.http')

local app = {}

local Sampler = {
    sample = function() return true end,
}

local tracer = zipkin.new({
    base_url = 'localhost:9411/api/v2/spans',
    api_method = 'POST',
    report_interval = 1,
}, Sampler)
tracer:register_injector('http', http_injector)

local formatter_url = 'http://localhost:33302/format'
local function format_string(ctx, str)
    local span = opentracing_span.new(tracer, ctx, 'format_string')
    local httpc = http_client.new()
    span:set_tag('span.kind', 'client')
    span:set_tag('http.method', 'GET')
    span:set_tag('http.url', formatter_url)

    local headers = {
        ['content-type'] = 'application/json'
    }
    tracer:inject(span:context(), 'http', headers)
    local resp = httpc:get(formatter_url .. '?helloto=' .. tostring(str), { headers = headers })

    if resp.status ~= 200 then
        error('Format string error: ' .. json.encode(resp))
    end
    local result = resp.body
    span:log_kv({
        event = 'String format',
        value = result
    })
    span:finish()
    return result
end

local printer_url = 'http://localhost:33303/print'
local function print_string(ctx, str)
    local span = opentracing_span.new(tracer, ctx, 'print_string')
    local httpc = http_client.new()
    span:set_tag('span.kind', 'client')
    span:set_tag('http.method', 'GET')
    span:set_tag('http.url', printer_url)

    local headers = {
        ['content-type'] = 'application/json'
    }
    tracer:inject(span:context(), 'http', headers)
    local resp = httpc:get(printer_url .. '?hello=123', { headers = headers })

    if resp.status ~= 200 then
        error('Print string error: ' .. json.encode(resp))
    end
    span:finish()
end

function app.init()
    local span = tracer:start_span('Hello-world')

    local hello_to = 'world'
    local greeting = 'my greeting'
    span:set_tag('hello-to', hello_to)
    span:set_baggage_item('greeting', greeting)

    local ctx = span:context()
    local formatted_string = format_string(ctx, hello_to)
    print_string(ctx, formatted_string)
    span:finish()
    -- TODO: dump data when time = 0
    require('fiber').sleep(5)
end

app.init()

os.exit(0)
