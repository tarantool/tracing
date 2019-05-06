# Opentracing for Tarantool

This library is a Tarantool platform API for OpenTracing

## Required Reading

To fully understand this platform API,
it's helpful to be familiar with the [OpenTracing project](https://opentracing.io) and
[terminology](https://opentracing.io/specification/) more specifically.

## Conventions

  - All timestamps are in microseconds

## Interface

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

## Basic usage
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
