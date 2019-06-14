#!/usr/bin/env tarantool

local queue = require('zipkin.bounded_queue')

local test = require('tap').test('circullar-queue tests')

test:plan(3)

test:test('size 1', function(test)
    test:plan(7)

    local q = queue.new(1)

    test:ok(#q.buffer == 0)

    q:push(1)
    test:ok(#q.buffer == 1)

    q:push(2)
    test:ok(#q.buffer == 1)
    test:ok(q.buffer[1] == 2)

    q:push(3)
    test:ok(#q.buffer == 1)
    test:ok(q.buffer[1] == 3)

    q:clear()
    test:ok(#q.buffer == 0)
end)

test:test('size 3', function(test)
    test:plan(5)

    local q = queue.new(3)

    test:ok(#q.buffer == 0)

    q:push(1)
    test:is_deeply(q.buffer, {1})

    q:push(2)
    test:is_deeply(q.buffer, {1, 2})

    q:push(3)
    test:is_deeply(q.buffer, {1, 2, 3})

    q:push(4)
    test:is_deeply(q.buffer, {4, 2, 3})
end)

test:test('clear', function(test)
    test:plan(5)

    local q = queue.new(3)

    test:ok(#q.buffer == 0)

    q:push(1)
    test:ok(#q.buffer == 1)

    q:clear()
    test:ok(#q.buffer == 0)

    q:push(1)
    test:ok(#q.buffer == 1)

    q:clear()
    test:ok(#q.buffer == 0)
end)

os.exit(test:check() and 0 or 1)
