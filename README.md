# Tarantool Tracing

Tracing module for tarantool includes following parts:
* [OpenTracing](https://Opentracing.io) API
* [Zipkin](https://zipkin.io/) tracer

### How to install
* `git submodule update --init --recursive`
* `make build`

### Run tests
* `make unit`

### Details
For details about each module open README.md in a directory of needed module  
(`/tracing/opentracing` or `/tracing/zipkin`)
