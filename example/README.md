# Zipkin example

This example is a Lua port of
[Go OpenTracing tutorial](https://github.com/yurishkuro/opentracing-tutorial/tree/master/go).

## Description

The example demonstrates trace propagation through two services:
`formatter` that formats the source string to "Hello, world"
and `publisher` that prints it in the console.

Add data to these services via HTTP; initially it sends `client`.

### How to run
From root package directory:

* Start Zipkin `docker-compose -f docker-compose.zipkin.yml up`

* `git submodule update --init --recursive`

* `make build`

* Run formatter HTTP server `./example/formatter/init.lua`
* Run publisher HTTP server `./example/publisher/init.lua`
* Run client `./example/client/init.lua`

* Check results on [http://localhost:9411/zipkin](http://localhost:9411/zipkin)
