package = "opentracing"
version = "0.0.2-0"

source = {
	url = "https://gitlab.com/tarantool/enterprise/tracing.git",
}

description = {
	summary = "Lua platform API for OpenTracing",
	homepage = "https://gitlab.com/tarantool/enterprise/tracing",
}

dependencies = {
	"lua >= 5.1",
	"tarantool",
}

build = {
	type = "builtin",
	modules = {
		["opentracing"] = "opentracing/init.lua",
		["opentracing.span"] = "opentracing/span.lua",
		["opentracing.span_context"] = "opentracing/span_context.lua",
		["opentracing.tracer"] = "opentracing/tracer.lua",
	},
}
