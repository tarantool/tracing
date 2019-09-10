# Tracing for Tarantool Enterprise

`Tracing` module for Tarantool includes the following parts:

* OpenTracing API
* Zipkin tracer

## Opentracing

This library is a Tarantool platform API for OpenTracing

### Required Reading

To fully understand this platform API,
it's helpful to be familiar with the [OpenTracing project](https://opentracing.io) and
[terminology](https://opentracing.io/specification/) more specifically.

### Conventions

  - All timestamps are in microseconds

### Span
```lua
local opentracing_span = require('opentracing.span')
-- tracer - External tracer
-- context - Span context
-- name - Name of span
-- start_timestamp (optional) - Time of span's start in microseconds (by default current time)
local span = opentracing_span.new(tracer, context, name, start_timestamp)
```

### SpanContext
```lua
local opentracing_span_context = require('opentracing.span_context')
-- trace_id (optional) - Trace ID (by default generates automatically)
-- span_id (optional) - Span ID (by default generates automatically)
-- parent_id (optional) - Span ID of parent span (by default is empty)
-- should_sample (optional) - Flag is enable collecting data of this span (by default false)
-- baggage (optional) - Table with trace baggage (by default is empty table)
local context = opentracing_span_context.new({
                    tracer_id = trace_id,
                    span_id = span_id,
                    parent_id = parent_id,
                    should_sample = should_sample,
                    baggage = baggage,
                })
```

### Tracer
An interface for custom tracers
```lua
local opentracing_tracer = require('opentracing.tracer')
-- reporter (optional) - Table with `report` method to process finished spans (by default no-op table)
-- sampler (optional) - Table with `sample` method to select traces to send to distributing tracing system (by default random selection)
-- But you can implement your own sampler with appropriate sampling strategy
-- For more information see: https://www.jaegertracing.io/docs/1.11/sampling/
local tracer = opentracing_tracer.new(reporter, sampler)
```

### Basic usage
```lua
local zipkin = require('zipkin.tracer')
local opentracing = require('opentracing')

local tracer = zipkin.new(config)
opentracing.set_global_tracer(tracer)

local span = opentracing.start_span('root span')
opentracing.trace_with_context('child span 1', span:context(), fun1, arg1)
opentracing.trace_with_context('child span 2', span:context(), fun2, arg2)
span:finish()
```

## Zipkin

[Zipkin](https://zipkin.io/) is a distributed tracing system.

It helps gather timing data needed to troubleshoot latency problems in microservice architectures.
It manages both the collection and lookup of this data.

This module allows you to instance Zipkin Tracer that can start spans and
will report collected spans to Zipkin Server.

### Basic usage

```lua
local zipkin = require('zipkin.tracer')
-- First argument is config that contains url of Zipkin API,
--  method to send collected traces and interval of reports in seconds
-- Second optional argument is Sampler (see OpenTracing API description), by default random sampler
local tracer = zipkin.new({
    base_url = 'localhost:9411/api/v2/spans',
    api_method = 'POST',
    report_interval = 0,
}, Sampler)

local span = tracer:start_span('example')
-- ...
span:finish()
```

## Example

This example is a Lua port of
[Go OpenTracing tutorial](https://github.com/yurishkuro/opentracing-tutorial/tree/master/go).

### Description

The example demonstrates trace propagation through two services:
`formatter` that formats the source string to "Hello, world"
and `publisher` that prints it in the console.

Add data to these services via HTTP; initially it sends `client`.

### How to run

* Create `docker-compose.zipkin.yml`

```yaml
---
version: '3.5'

# Initially got from https://github.com/openzipkin/docker-zipkin/blob/master/docker-compose.yml

services:
  storage:
    image: openzipkin/zipkin-mysql
    container_name: mysql
    networks:
      - zipkin
    ports:
      - 3306:3306

  # The zipkin process services the UI, and also exposes a POST endpoint that
  # instrumentation can send trace data to. Scribe is disabled by default.
  zipkin:
    image: openzipkin/zipkin
    container_name: zipkin
    networks:
      - zipkin
    # Environment settings are defined here https://github.com/openzipkin/zipkin/tree/1.19.0/zipkin-server#environment-variables
    environment:
      - STORAGE_TYPE=mysql
      # Point the zipkin at the storage backend
      - MYSQL_HOST=mysql
      # Enable debug logging
      - JAVA_OPTS=-Dlogging.level.zipkin=DEBUG -Dlogging.level.zipkin2=DEBUG
    ports:
      # Port used for the Zipkin UI and HTTP Api
      - 9411:9411
    depends_on:
      - storage

  # Adds a cron to process spans since midnight every hour, and all spans each day
  # This data is served by http://192.168.99.100:8080/dependency
  #
  # For more details, see https://github.com/openzipkin/docker-zipkin-dependencies
  dependencies:
    image: openzipkin/zipkin-dependencies
    container_name: dependencies
    entrypoint: crond -f
    networks:
      - zipkin
    environment:
      - STORAGE_TYPE=mysql
      - MYSQL_HOST=mysql
      # Add the baked-in username and password for the zipkin-mysql image
      - MYSQL_USER=zipkin
      - MYSQL_PASS=zipkin
      # Dependency processing logs
      - ZIPKIN_LOG_LEVEL=DEBUG
    depends_on:
      - storage

networks:
  zipkin:
```

* Start Zipkin `docker-compose -f docker-compose.zipkin.yml up`

* Run mock applications from separate consoles: consumer, formatter and client

Formatter HTTP server
```lua
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
    local ctx, err = opentracing.http_extract(req.headers)
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
    httpd:route({ path = '/format', method = 'GET' }, handler)
    httpd:start()
end

app.init()

return app
```

Publisher HTTP server
```lua
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

local function handler(req)
    local ctx, err = opentracing.http_extract(req.headers)

    if ctx == nil then
        local resp = req:render({ text = err })
        resp.status = 400
        return resp
    end

    local hello = req:query_param('hello')
    local span = opentracing.start_span_from_context(ctx, 'print_string')
    span:set_component('publisher')
    span:set_server_kind()
    span:set_http_method(req.method)
    span:set_http_path(req.path)

    -- Simulate long request processing
    fiber.sleep(3)

    io.write(hello, '\n')
    local resp = req:render({text = '' })
    resp.status = 200
    span:set_http_status_code(resp.status)
    span:finish()
    return resp
end

function app.init()
    local tracer = zipkin.new({
        base_url = 'localhost:9411/api/v2/spans',
        api_method = 'POST',
        report_interval = 5,
        on_error = function(err) log.error(err) end,
    }, Sampler)
    opentracing.set_global_tracer(tracer)

    local httpd = http_server.new(HOST, PORT)
    httpd:route({ path = '/print', method = 'GET' }, handler)
    httpd:start()
end

app.init()

return app

```

Client
```lua
#!/usr/bin/env tarantool

local http_client = require('http.client')
local json = require('json')
local log = require('log')
local fiber = require('fiber')
local zipkin = require('zipkin.tracer')
local opentracing = require('opentracing')

local app = {}

-- Process all requests
local Sampler = {
    sample = function() return true end,
}

local function url_encode(str)
    local res = string.gsub(str, '[^a-zA-Z0-9_]',
        function(c)
            return string.format('%%%02X', string.byte(c))
        end
    )
    return res
end

-- Client part to formatter
local formatter_url = 'http://localhost:33302/format'
local function format_string(ctx, str)
    local span = opentracing.start_span_from_context(ctx, 'format_string')
    local httpc = http_client.new()
    span:set_component('client')
    span:set_client_kind()
    span:set_http_method('GET')
    span:set_http_url(formatter_url)

    -- Use http headers as carrier
    local headers = {
        ['content-type'] = 'application/json'
    }
    opentracing.http_inject(span:context(), headers)

    -- Simulate problems with network
    fiber.sleep(1)
    local resp = httpc:get(formatter_url .. '?helloto=' .. url_encode(str),
            { headers = headers })
    fiber.sleep(1)

    span:set_http_status_code(resp.status)
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
    local span = opentracing.start_span_from_context(ctx, 'print_string')
    local httpc = http_client.new()
    span:set_component('client')
    span:set_client_kind()
    span:set_http_method('GET')
    span:set_http_url(printer_url)

    local headers = {
        ['content-type'] = 'application/json'
    }
    opentracing.http_inject(span:context(), headers)

    -- Simulate problems with network
    fiber.sleep(1)
    local resp = httpc:get(printer_url .. '?hello=' .. url_encode(str),
            { headers = headers })
    fiber.sleep(1)

    span:set_http_status_code(resp.status)
    if resp.status ~= 200 then
        error('Print string error: ' .. json.encode(resp))
    end
    span:finish()
end

function app.init()
    -- Initialize Zipkin tracer
    local tracer = zipkin.new({
        base_url = 'localhost:9411/api/v2/spans',
        api_method = 'POST',
        report_interval = 0,
        on_error = function(err) log.error(err) end,
    }, Sampler)
    opentracing.set_global_tracer(tracer)

    -- Initialize root span
    local span = opentracing.start_span('Hello-world')

    local hello_to = 'world'
    local greeting = 'my greeting'
    span:set_component('client')
    -- Set service type
    span:set_client_kind()
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

```

* Check results on [http://localhost:9411/zipkin](http://localhost:9411/zipkin)


