local bounded_queue = {}

function bounded_queue:push(value)
    self.last = self.last + 1
    if self.last > self.max_length then
        self.last = 1
    end

    self.buffer[self.last] = value

    if self.first == self.last then
        self.first = self.first + 1
        if self.first > self.max_length then
            self.first = 1
        end
    elseif self.first == 0 then
        self.first = 1
    end
end

function bounded_queue:dump()
    return self.buffer
end

function bounded_queue:clear()
    self.buffer = table.new(self.max_length, 0)
    self.first = 0
    self.last = 0
end

function bounded_queue.new(max_length)
    assert(type(max_length) == 'number' and max_length > 0,
        "bounded_queue.new(): Max length of buffer must be a positive integer")

    local instance = {
        buffer = table.new(max_length, 0),
        first = 0,
        last = 0,
        max_length = max_length,
        push = bounded_queue.push,
        dump = bounded_queue.dump,
        clear = bounded_queue.clear
    }

    return instance
end

return bounded_queue
