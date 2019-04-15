local checks = require('checks')
local span = require('opentracing.span')

local opentracing = {
	_VERSION = nil,
}

local global_tracer

function opentracing.set_global_tracer(tracer)
	checks('table')
	global_tracer = tracer
end

function opentracing.get_global_tracer()
	return global_tracer
end

function opentracing.start_span_from_context(tracer, context, name)
	checks('?table', 'table', 'string')
	local child_context = context:child()
	return span.new(tracer or global_tracer, child_context, name)
end

return opentracing
