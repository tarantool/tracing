local t = require('luatest')

local opentracing = require('tracing.opentracing')
local opentracing_tracer = require('tracing.opentracing.tracer')

local g = t.group()

g.before_all(function()
    g.Reporter = {
        spans = {},
        report = function(_, span)
            table.insert(g.Reporter.spans, span)
        end,
        reset = function() g.Reporter.spans = {} end
    }

    local Sampler = { sample = function() return true end }


    local tracer = opentracing_tracer.new(g.Reporter, Sampler)
    opentracing.set_global_tracer(tracer)
end)

g.test_decorator_positive = function()
    local a, b, c, d = opentracing.trace('positive',
            function(...)
                return ...
            end, 1, 2, 3)
    t.assert_equals(1, a, 'first arg is correct')
    t.assert_equals(2, b, 'second arg is correct')
    t.assert_equals(3, c, 'third arg is correct')
    t.assert_equals(nil, d, 'fourth arg is empty')
    t.assert_equals(1, #g.Reporter.spans, 'One span')
    local span = g.Reporter.spans[1]
    t.assert_equals(nil, span:get_tag('error'))
    g.Reporter.reset()
end

g.test_decorator_negative = function(test)
    local fun_error = 'trace error'
    local a, err, c = opentracing.trace('negative',
            function(...)
                error(fun_error)
                return ...
            end,
            1, 2, 3)
    t.assert_equals(nil, a, 'first arg is nil')
    t.assert_equals(true, err:endswith(fun_error), 'second arg is error')
    t.assert_equals(nil, c, 'third arg is nil')
    t.assert_equals(1, #g.Reporter.spans, 'One span')
    local span = g.Reporter.spans[1]
    t.assert_equals(true, span.tags['error']:endswith(fun_error))
    g.Reporter.reset()
end