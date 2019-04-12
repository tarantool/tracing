#!/usr/bin/env tarantool

local http_server = require('http.server')
local zipkin = require('zipkin.tracer')
local http_extractor = require('opentracing.extractors.http')
local opentracing_span = require('opentracing.span')

local app = {}

local Sampler = {
    sample = function() return true end,
}

local HOST = '0.0.0.0'
local PORT = '33302'

local tracer = zipkin.new({
    base_url = 'localhost:9411/api/v2/spans',
    api_method = 'POST',
    report_interval = 5,
}, Sampler)

local function handler(req)
    local ctx, err = http_extractor(req.headers)

    if ctx == nil then
        local resp = req:render({ text = err })
        resp.status = 400
        return resp
    end

    local hello_to = req:query_param('helloto')
    local span = opentracing_span.new(tracer, ctx, 'format_string')
    span:set_tag('span.kind', 'server')
    local greeting = span:get_baggage_item('greeting')
    local result = ('%s, %s!'):format(greeting, hello_to)
    local resp = req:render({ text = result })
    span:log_kv({
        event = 'String format',
        value = result,
    })
    span:finish()
    resp.status = 200
    return resp
end

function app.init()
    local httpd = http_server.new(HOST, PORT)
    httpd:route({ path = '/format', method = 'GET' }, handler)
    httpd:start()
end

app.init()

return app
