local t = require('luatest')
local g = t.group()
local queue = require('tracing.zipkin.bounded_queue')

g.test_size_1 = function()
    local q = queue.new(1)
    
    t.assert_equals(#q.buffer, 0, "Initial queue size should be 0")

    q:push(1)
    t.assert_equals(#q.buffer, 1, "Queue size after pushing 1 element should be 1")

    q:push(2)
    t.assert_equals(#q.buffer, 1, "Queue size after pushing 2nd element should still be 1")
    t.assert_equals(q.buffer[1], 2, "Queue should only keep the last pushed element (2)")

    q:push(3)
    t.assert_equals(#q.buffer, 1, "Queue size after pushing 3rd element should still be 1")
    t.assert_equals(q.buffer[1], 3, "Queue should only keep the last pushed element (3)")

    q:clear()
    t.assert_equals(#q.buffer, 0, "Queue should be cleared")
end

g.test_size_3 = function()
    local q = queue.new(3)
    
    t.assert_equals(#q.buffer, 0, "Initial queue size should be 0")

    q:push(1)
    t.assert_equals(q.buffer, {1}, "Queue should contain {1} after pushing 1 element")

    q:push(2)
    t.assert_equals(q.buffer, {1, 2}, "Queue should contain {1, 2} after pushing 2 elements")

    q:push(3)
    t.assert_equals(q.buffer, {1, 2, 3}, "Queue should contain {1, 2, 3} after pushing 3 elements")

    q:push(4)
    t.assert_equals(q.buffer, {4, 2, 3}, "Queue should contain {4, 2, 3} after pushing 4th element")
end

g.test_clear = function()
    local q = queue.new(3)
    
    t.assert_equals(#q.buffer, 0, "Initial queue size should be 0")

    q:push(1)
    t.assert_equals(#q.buffer, 1, "Queue size after pushing 1 element should be 1")

    q:clear()
    t.assert_equals(#q.buffer, 0, "Queue should be cleared after clear() call")

    q:push(1)
    t.assert_equals(#q.buffer, 1, "Queue size should be 1 after pushing 1 element again")

    q:clear()
    t.assert_equals(#q.buffer, 0, "Queue should be cleared again after clear() call")
end
