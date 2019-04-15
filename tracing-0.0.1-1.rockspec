package = "tracing"
version = "0.0.1-1"

source = {
	url = "https://gitlab.com/tarantool/enterprise/tracing.git",
}

description = {
	summary = "Lua platform API for OpenTracing",
	homepage = "https://gitlab.com/tarantool/enterprise/tracing",
}

dependencies = {
	"lua >= 5.1",
	"checks >= 3.0.0",
	"http",
}

build = {
	type = "builtin",
	modules = {
		["opentracing"] = "tracing/opentracing/init.lua",
		["opentracing.span"] = "tracing/opentracing/span.lua",
		["opentracing.span_context"] = "tracing/opentracing/span_context.lua",
		["opentracing.tracer"] = "tracing/opentracing/tracer.lua",
		["opentracing.extractors.http"] = "tracing/opentracing/extractors/http.lua",
		["opentracing.injectors.http"] = "tracing/opentracing/injectors/http.lua",

		["zipkin.handler"] = "tracing/zipkin/handler.lua",
		["zipkin.reporter"] = "tracing/zipkin/reporter.lua",
		["zipkin.tracer"] = "tracing/zipkin/tracer.lua",
	},
}
