--[[
The internal data structure is modeled off the ZipKin Span JSON Structure
This makes it cheaper to convert to JSON for submission to the ZipKin HTTP api,
which Jaegar also implements.
You can find it documented in this OpenAPI spec:
https://github.com/openzipkin/zipkin-api/blob/7e33e977/zipkin2-api.yaml#L280
--]]

local checks = require('checks')

local span_methods = {}
local span_mt = {
	__name = 'opentracing.span',
	__index = span_methods,
}

local function is(object)
	return getmetatable(object) == span_mt
end

local function new(tracer, context, name, start_timestamp)
	checks('table', 'table', 'string', 'number|cdata')
	return setmetatable({
		tracer_ = tracer,
		context_ = context,
		name = name,
		timestamp = start_timestamp,
		duration = nil,
		-- Avoid allocations until needed
		baggage = nil,
		tags = nil,
		logs = nil,
		n_logs = 0,
	}, span_mt)
end

function span_methods:context()
	checks('table')
	return self.context_
end

function span_methods:tracer()
	checks('table')
	return self.tracer_
end

function span_methods:set_operation_name(name)
	checks('table', 'string')
	self.name = name
end

function span_methods:start_child_span(name, start_timestamp)
	checks('table', 'string', '?number|cdata')
	return self.tracer_:start_span(name, {
		start_timestamp = start_timestamp,
		child_of = self,
	})
end

function span_methods:finish(finish_timestamp)
	checks('table', '?number|cdata')
	if self.duration ~= nil then
		return false, 'span already finished'
	end
	if finish_timestamp == nil then
		self.duration = self.tracer_:time() - self.timestamp
	else
		local duration = finish_timestamp - self.timestamp
		-- TODO: May be log the fact then duration is negative
		self.duration = duration >= 0 and duration or 0
	end
	if self.context_.should_sample then
		self.tracer_:report(self)
	end
	return true
end

function span_methods:set_tag(key, value)
	checks('table', 'string', '?')
	local tags = self.tags
	if tags then
		tags[key] = value
	elseif value ~= nil then
		tags = {
			[key] = value
		}
		self.tags = tags
	end
	return true
end

function span_methods:get_tag(key)
	checks('table', 'string')
	local tags = self.tags
	if tags then
		return tags[key]
	else
		return nil
	end
end

function span_methods:each_tag()
	checks('table')
	local tags = self.tags
	if tags == nil then return function() end end
	return next, tags
end

function span_methods:log(key, value, timestamp)
	checks('table', 'string', '?', '?number|cdata')
	-- `value` is allowed to be anything.
	if timestamp == nil then
		timestamp = self.tracer_:time()
	end

	local log = {
		key = key,
		value = value,
		timestamp = timestamp,
	}

	local logs = self.logs
	if logs then
		local i = self.n_logs + 1
		logs[i] = log
		self.n_logs = i
	else
		logs = { log }
		self.logs = logs
		self.n_logs = 1
	end
	return true
end

function span_methods:log_kv(key_values, timestamp)
	checks('table', 'table', '?number|cdata')
	if timestamp == nil then
		timestamp = self.tracer_:time()
	end

	local logs = self.logs
	local n_logs
	if logs then
		n_logs = 0
	else
		n_logs = self.n_logs
		logs = { }
		self.logs = logs
	end

	for key, value in pairs(key_values) do
		n_logs = n_logs + 1
		logs[n_logs] = {
			key = key,
			value = value,
			timestamp = timestamp,
		}
	end

	self.n_logs = n_logs
	return true
end

function span_methods:each_log()
	checks('table')
	local i = 0
	return function(logs)
		if i >= self.n_logs then
			return
		end
		i = i + 1
		local log = logs[i]
		return log.key, log.value, log.timestamp
	end, self.logs
end

function span_methods:set_baggage_item(key, value)
	-- Create new context so that baggage is immutably passed around
	local newcontext = self.context_:clone_with_baggage_item(key, value)
	self.context_ = newcontext
	return true
end

function span_methods:get_baggage_item(key)
	checks('table', 'string')
	return self.context_:get_baggage_item(key)
end

function span_methods:each_baggage_item()
	checks('table')
	return self.context_:each_baggage_item()
end

return {
	new = new,
	is = is,
}
