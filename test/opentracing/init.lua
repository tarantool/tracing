#!/usr/bin/env tarantool

local opentracing = require('opentracing')
local opentracing_tracer = require('opentracing.tracer')
local test = require('tap').test('opentracing tests')

test:plan(2)

local Reporter
Reporter = {
    spans = {},
    report = function(_, span)
        table.insert(Reporter.spans, span)
    end,
    reset = function() Reporter.spans = {} end
}

local Sampler = { sample = function() return true end }


local tracer = opentracing_tracer.new(Reporter, Sampler)
opentracing.set_global_tracer(tracer)

test:test('decorator positive', function(test)
    test:plan(6)
    local a, b, c, d = opentracing.trace('positive',
            function(...)
                return ...
            end, 1, 2, 3)
    test:is(1, a, 'first arg is correct')
    test:is(2, b, 'second arg is correct')
    test:is(3, c, 'third arg is correct')
    test:is(nil, d, 'fourth arg is empty')
    test:is(1, #Reporter.spans, 'One span')
    local span = Reporter.spans[1]
    test:is(nil, span.tags['error'])
    Reporter.reset()
end)

test:test('decorator negative', function(test)
    test:plan(5)
    local fun_error = 'trace error'
    local a, err, c = opentracing.trace('negative',
            function(...)
                error(fun_error)
                return ...
            end,
            1, 2, 3)
    test:is(nil, a, 'first arg is nil')
    test:is(true, err:endswith(fun_error), 'second arg is error')
    test:is(nil, c, 'third arg is nil')
    test:is(1, #Reporter.spans, 'One span')
    local span = Reporter.spans[1]
    test:is(true, span.tags['error']:endswith(fun_error))
    Reporter.reset()
end)

os.exit(test:check() and 0 or 1)
