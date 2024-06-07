require 'tablex'

local deque = {}

function deque:pushleft(x)
    local first = self.first - 1
    self.first = first
    self.values[first] = x
end

function deque:pushright(x)
    local last = self.last + 1
    self.last = last
    self.values[last] = x
end

function deque:push(x)
    return self:pushright(x)
end

function deque:append(x)
    return self:pushright(x)
end

function deque:appendleft(x)
    return self:pushleft(x)
end

function deque:popleft()
    local first = self.first
    assert(first <= self.last, 'empty')
    local x = self.values[first]
    self.values[first] = nil
    self.first = first + 1
    return x
end

function deque:popright()
    local last = self.last
    assert(self.first <= last, 'empty')
    local x = self.values[last]
    self.values[last] = nil
    self.last = last - 1
    return x
end

function deque:pop()
    return self:popright()
end

function deque:__len()
    return self.last - self.first + 1
end

function deque:__index(k)
    if type(k) == 'number' then
        return self.values[self.first + k - 1]
    else
        return deque[k]
    end
end

function deque:__newindex(k, v)
    if type(k) == 'number' then
        error 'direct indexing not allowed'
    else
        return deque[k]
    end
end

function deque:__ipairs()
    local j, a, b = 0, self.first, self.last
    return function()
        if j <= b then
            local i, v = j, self.values[j]
            j = j + 1
            return i, v
        end
    end
end

setmetatable(deque, {
    __call = function(self, values)
        values = values or {}
        return setmetatable({
            first = 1,
            last = #values,
            values = table.clone(values),
        }, self)
    end,
})

if arg and #arg == 1 and arg[1] == 'test' then
    local q = deque()
    q:append(40)
    q:append(80)
    q:appendleft(20)
    assert(q:pop() == 80)
    assert(q:popleft() == 20)
    assert(q:pop() == 40)
    assert(not pcall(q.pop, q))
    print(debug.getinfo(1, 'S').source, 'tests passed')
end

return deque
