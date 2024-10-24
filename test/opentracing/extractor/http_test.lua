local t = require('luatest')
local g = t.group()
local http_extractor = require('tracing.opentracing.extractors.http')

g.test_http = function()
    local empty_context = http_extractor({ ["x-b3-sampled"] = '1' })
    t.assert(empty_context.trace_id, 'Generate trace_id for new context')
    t.assert(empty_context.span_id, 'Generate span_id for new context')
    t.assert_equals(empty_context.should_sample, true, 'Sampling is enabled')

    local headers = {
        ['x-b3-traceid'] = '80f198ee56343ba864fe8b2a57d3eff7',
        ['x-b3-parentspanid'] = '05e3ac9a4f6e3b90',
        ['x-b3-spanid'] = 'e457b5a2e4d86bd1',
        ['x-b3-sampled'] = '1',
        ['http-header'] = 'useless',
        ['uberctx-item'] = 'baggage item'
    }

    local result = http_extractor(headers)
    t.assert_not_equals(result, nil, 'Headers are decoded')
    t.assert(result.should_sample, 'Sampling is enabled')
    t.assert_equals(result:get_baggage_item('item'), 'baggage item', 'Extract baggage item')
end
