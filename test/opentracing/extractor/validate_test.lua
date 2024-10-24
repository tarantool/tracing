local t = require('luatest')
local g = t.group('carrier_validator_test')
local digest = require('digest')
local validate = require('tracing.opentracing.extractors.validate')

g.test_carrier_validator = function()
    local ok, err = validate({})
    t.assert_equals(ok, true, 'empty carrier validation')
    t.assert_equals(err, nil, 'empty carrier validation - err')

    ok, err = validate({ trace_id = '123123123' })
    t.assert_equals(ok, false, 'invalid trace id length')
    t.assert_equals(err, 'Invalid trace id', 'invalid trace id length - err')

    ok, err = validate({ trace_id = string.rep('.', 16) })
    t.assert_equals(ok, false, 'invalid trace id format')
    t.assert_equals(err, 'Invalid trace id', 'invalid trace id format - err')

    ok, err = validate({ trace_id = string.hex(digest.urandom(16)) })
    t.assert_equals(ok, true, 'valid trace id in hex format')
    t.assert_equals(err, nil, 'valid trace id in hex format - err')

    ok, err = validate({ trace_id = string.hex(digest.urandom(16)), span_id = '' })
    t.assert_equals(ok, false, 'invalid span id')
    t.assert_equals(err, 'Invalid span id', 'invalid span id - err')

    ok, err = validate({ trace_id = string.hex(digest.urandom(16)), span_id = string.rep('.', 16) })
    t.assert_equals(ok, false, 'invalid span id')
    t.assert_equals(err, 'Invalid span id', 'invalid span id - err')

    ok, err = validate({ trace_id = string.hex(digest.urandom(16)), span_id = string.hex(digest.urandom(8)) })
    t.assert_equals(ok, true, 'valid span id in hex format')
    t.assert_equals(err, nil, 'valid span id in hex format - err')

    ok, err = validate({ trace_id = string.hex(digest.urandom(16)), parent_span_id = '' })
    t.assert_equals(ok, false, 'invalid parent_span id')
    t.assert_equals(err, 'Invalid parent span id', 'invalid parent_span id - err')

    ok, err = validate({ trace_id = string.hex(digest.urandom(16)), parent_span_id = string.rep('.', 16) })
    t.assert_equals(ok, false, 'invalid parent_span id')
    t.assert_equals(err, 'Invalid parent span id', 'invalid parent_span id - err')

    ok, err = validate({ trace_id = string.hex(digest.urandom(16)), parent_span_id = string.hex(digest.urandom(8)) })
    t.assert_equals(ok, true, 'valid parent span id in hex format')
    t.assert_equals(err, nil, 'valid parent span id in hex format - err')

    ok, err = validate({
        trace_id = string.hex(digest.urandom(16)),
        parent_span_id = string.hex(digest.urandom(8)),
        span_id = string.hex(digest.urandom(8))
    })
    t.assert_equals(ok, true, 'valid parent span id and span id in hex format')
    t.assert_equals(err, nil, 'valid parent span id in hex format - err')
end
