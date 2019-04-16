# Zipkin

> [Zipkin](https://zipkin.io/) is a distributed tracing system.
It helps gather timing data needed to troubleshoot latency problems in microservice architectures.
It manages both the collection and lookup of this data.

This module allows you to instance Zipkin Tracer that can start spans and
will report collected spans to Zipkin Server.

### Example

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
