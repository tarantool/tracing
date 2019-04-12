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
}

build = {
	type = "builtin",
	modules = {
		["opentracing"] = "tracing/opentracing/init.lua",
		["opentracing.span"] = "tracing/opentracing/span.lua",
		["opentracing.span_context"] = "tracing/opentracing/span_context.lua",
		["opentracing.tracer"] = "tracing/opentracing/tracer.lua",

		["zipkin.handler"] = "tracing/zipkin/handler.lua",
		["zipkin.report"] = "tracing/zipkin/report.lua",
		["zipkin.tracer"] = "tracing/zipkin/tracer.lua",
	},
}
