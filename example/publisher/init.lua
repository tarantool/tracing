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
local PORT = '33303'

local tracer = zipkin.new({
    base_url = 'localhost:9411/api/v2/spans',
    api_method = 'POST',
    report_interval = 5,
    on_error = function(err) log.error(err.msg) end,
}, Sampler)

local function handler(req)
    local ctx, err = tracer:http_headers_extract(req.headers)

    if ctx == nil then
        local resp = req:render({ text = err })
        resp.status = 400
        return resp
    end

    local hello = req:query_param('hello')
    local span = opentracing.start_span_from_context(tracer, ctx, 'print_string')
    span:set_tag('component', 'publisher')
    span:set_tag('span.kind', 'server')

    -- Simulate long request processing
    fiber.sleep(3)

    io.write(hello, '\n')
    local resp = req:render({text = '' })
    resp.status = 200

    span:finish()
    return resp
end

function app.init()
    local httpd = http_server.new(HOST, PORT)
    httpd:route({ path = '/print', method = 'GET' }, handler)
    httpd:start()
end

app.init()

return app
