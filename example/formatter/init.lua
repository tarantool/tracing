#!/usr/bin/env tarantool

local ok, http_server = pcall(require,'http.server')

if not ok then
    print('Example requires http module (version >= 2.0.1)')
    print('Install using "tarantoolctl rocks install http 2.0.1"')
    os.exit(1)
end

local http_router = require('http.router')
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
    local ctx, err = opentracing.http_extract(req:headers())
    if ctx == nil then
        local resp = req:render({ text = err })
        resp.status = 400
        return resp
    end

    local hello_to = req:query_param('helloto')
    -- Start new child span
    local span = opentracing.start_span_from_context(ctx, 'format_string')
    -- Set service type
    span:set_component('formatter')
    span:set_server_kind()
    span:set_http_method(req.method)
    span:set_http_path(req.path)
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
    span:set_http_status_code(resp.status)
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
    local router = http_router.new():route({ path = '/format', method = 'GET' }, handler)
    httpd:set_router(router)
    httpd:start()
end

app.init()

return app
