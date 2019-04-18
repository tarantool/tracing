# Tarantool Tracing

Tracing module for tarantool includes following parts:
* [OpenTracing](https://Opentracing.io) API
* [Zipkin](https://zipkin.io/) tracer

### How to build
* `git submodule update --init --recursive`
* `make build`

### Run tests
* `make unit`

### Details
To get more information about each module read
[OpenTracing](tracing/opentracing/README.md) and
[Zipkin](tracing/zipkin/README.md) READMEs.

### Documentation
To generate documentation install `ldoc` and run `ldoc .`.

### Examples
See [Zipkin example](example/README.md)
