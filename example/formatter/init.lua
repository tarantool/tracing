#!/usr/bin/env tarantool

local http_server = require('http.server')
local fiber = require('fiber')
local log = require('log')
local zipkin = require('zipkin.tracer')
local opentracing = require('opentracing')

local app = {}

local Sampler = {
    sample = function() return true end,
}

local HOST = '0.0.0.0'
local PORT = '33302'

local function handler(req)
    -- Extract content from request's http headers
    local ctx, err = opentracing.tracer:http_headers_extract(req.headers)
    if ctx == nil then
        local resp = req:render({ text = err })
        resp.status = 400
        return resp
    end

    local hello_to = req:query_param('helloto')
    -- Start new child span
    local span = opentracing.start_span_from_context(ctx, 'format_string')
    -- Set service type
    span:set_tag('component', 'formatter')
    span:set_tag('span.kind', 'server')
    local greeting = span:get_baggage_item('greeting')
    local result = ('%s, %s!'):format(greeting, hello_to)
    local resp = req:render({ text = result })

    -- Simulate long request processing
    fiber.sleep(2)
    span:log_kv({
        event = 'String format',
        value = result,
    })
    resp.status = 200
    span:finish()
    return resp
end

function app.init()
    -- Initialize zipkin client that will be send spans every 5 seconds
    local tracer = zipkin.new({
        base_url = 'localhost:9411/api/v2/spans',
        api_method = 'POST',
        report_interval = 5,
        on_error = function(err) log.error(err) end,
    }, Sampler)
    opentracing.set_global_tracer(tracer)

    local httpd = http_server.new(HOST, PORT)
    httpd:route({ path = '/format', method = 'GET' }, handler)
    httpd:start()
end

app.init()

return app
