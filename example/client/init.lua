#!/usr/bin/env tarantool

local http_client = require('http.client')
local json = require('json')
local fiber = require('fiber')
local zipkin = require('zipkin.tracer')
local opentracing = require('opentracing')
local http_injector = require('opentracing.injectors.http')
local utils = require('tracing.utils')

local app = {}

-- Process all requests
local Sampler = {
    sample = function() return true end,
}

-- Initialize Zipkin tracer
local tracer = zipkin.new({
    base_url = 'localhost:9411/api/v2/spans',
    api_method = 'POST',
    report_interval = 0,
}, Sampler)
-- Register http injector
tracer:register_injector('http', http_injector)

-- Client part to formatter
local formatter_url = 'http://localhost:33302/format'
local function format_string(ctx, str)
    local span = opentracing.start_span_from_context(tracer, ctx, 'format_string')
    local httpc = http_client.new()
    span:set_tag('span.kind', 'client')
    span:set_tag('http.method', 'GET')
    span:set_tag('http.url', formatter_url)

    -- Use http headers as carrier
    local headers = {
        ['content-type'] = 'application/json'
    }
    tracer:inject(span:context(), 'http', headers)

    -- Simulate problems with network
    fiber.sleep(1)
    local resp = httpc:get(formatter_url .. '?helloto=' .. utils.url_encode(str),
            { headers = headers })
    fiber.sleep(1)

    if resp.status ~= 200 then
        error('Format string error: ' .. json.encode(resp))
    end
    local result = resp.body
    -- Log result
    span:log_kv({
        event = 'String format',
        value = result
    })
    span:finish()
    return result
end

-- Client part to publisher
local printer_url = 'http://localhost:33303/print'
local function print_string(ctx, str)
    local span = opentracing.start_span_from_context(tracer, ctx, 'print_string')
    local httpc = http_client.new()
    span:set_tag('span.kind', 'client')
    span:set_tag('http.method', 'GET')
    span:set_tag('http.url', printer_url)

    local headers = {
        ['content-type'] = 'application/json'
    }
    tracer:inject(span:context(), 'http', headers)

    -- Simulate problems with network
    fiber.sleep(1)
    local resp = httpc:get(printer_url .. '?hello=' .. utils.url_encode(str),
            { headers = headers })
    fiber.sleep(1)

    if resp.status ~= 200 then
        error('Print string error: ' .. json.encode(resp))
    end
    span:finish()
end

function app.init()
    -- Initialize main span
    local span = tracer:start_span('Hello-world')

    local hello_to = 'world'
    local greeting = 'my greeting'
    -- Set service type
    span:set_tag('span.kind', 'client')
    -- Set tag with metadata
    span:set_tag('hello-to', hello_to)
    -- Add data to baggage
    span:set_baggage_item('greeting', greeting)

    local ctx = span:context()
    local formatted_string = format_string(ctx, hello_to)
    print_string(ctx, formatted_string)
    span:finish()
end

app.init()

os.exit(0)
