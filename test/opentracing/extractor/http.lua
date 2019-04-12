#!/usr/bin/env tarantool

local test = require('tap').test('HTTP extractor')
local http_extractor = require('opentracing.extractors.http')

test:plan(1)

local empty = http_extractor({})
test:isnil(empty, 'Headers without traceId')
