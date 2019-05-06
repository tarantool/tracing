#!/usr/bin/env tarantool

local test = require('tap').test('carrier validator')
local digest = require('digest')
local validate = require('opentracing.extractors.validate')

test:plan(22)
local ok, err = validate({})
test:is(true, ok, 'empty carrier validation')
test:isnil(err, 'empty carrier validation - err')

ok, err = validate({ trace_id = '123123123' })
test:is(false, ok, 'invalid trace id length')
test:is('Invalid trace id', err, 'invalid trace id length - err')

ok, err = validate({ trace_id = string.rep('.', 16) })
test:is(false, ok, 'invalid trace id format')
test:is('Invalid trace id', err, 'invalid trace id format - err')

ok, err = validate({ trace_id = string.hex(digest.urandom(16)) })
test:is(true, ok, 'valid trace id in hex format')
test:is(nil, err, 'valid trace id in hex format - err')

ok, err = validate({ trace_id = string.hex(digest.urandom(16)), span_id = '' })
test:is(false, ok, 'invalid span id')
test:is('Invalid span id', err, 'invalid span id - err')

ok, err = validate({ trace_id = string.hex(digest.urandom(16)), span_id = string.rep('.', 16) })
test:is(false, ok, 'invalid span id')
test:is('Invalid span id', err, 'invalid span id - err')

ok, err = validate({ trace_id = string.hex(digest.urandom(16)), span_id = string.hex(digest.urandom(8)) })
test:is(true, ok, 'valid span id in hex format')
test:is(nil, err, 'valid span id in hex format - err')

ok, err = validate({ trace_id = string.hex(digest.urandom(16)), parent_span_id = '' })
test:is(false, ok, 'invalid parent_span id')
test:is('Invalid parent span id', err, 'invalid parent_span id - err')

ok, err = validate({ trace_id = string.hex(digest.urandom(16)), parent_span_id = string.rep('.', 16) })
test:is(false, ok, 'invalid parent_span id')
test:is('Invalid parent span id', err, 'invalid parent_span id - err')

ok, err = validate({ trace_id = string.hex(digest.urandom(16)), parent_span_id = string.hex(digest.urandom(8)) })
test:is(true, ok, 'valid parent span id in hex format')
test:is(nil, err, 'valid parent span id in hex format - err')

ok, err = validate({ trace_id = string.hex(digest.urandom(16)),
                     parent_span_id = string.hex(digest.urandom(8)),
                     span_id = string.hex(digest.urandom(8))
})
test:is(true, ok, 'valid parent span id and span id in hex format')
test:is(nil, err, 'valid parent span id in hex format - err')

os.exit(test:check() and 0 or 1)
