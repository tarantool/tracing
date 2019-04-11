package = "zipkin"
version = "scm-0"

source = {
	url = "git+https://github.com/olegrok/zipkin-tarantool.git",
}

description = {
	summary = "This plugin allows to propagate Zipkin headers and report to a Zipkin server",
	homepage = "https://github.com/olegrok/zipkin-tarantool",
}

dependencies = {
	"tarantool",
	"checks >= 3.0.0",
}

build = {
	type = "builtin";
	modules = {
		["zipkin.codec"] = "zipkin/codec.lua";
		["zipkin.handler"] = "zipkin/handler.lua";
		["zipkin.opentracing"] = "zipkin/opentracing.lua";
		["zipkin.random_sampler"] = "zipkin/random_sampler.lua";
		["zipkin.reporter"] = "zipkin/reporter.lua";
		["zipkin.schema"] = "zipkin/schema.lua";
	};
}
