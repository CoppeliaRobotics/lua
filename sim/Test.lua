local CustomClass = require 'sim.CustomClass'

local Test = CustomClass 'test'

--Test:setBoolProperty('foo', true)

function Test:init()
end

function Test:testCallback(cb)
    return 'testCallback-' .. cb()
end

function Test:testReentrantCallback(cb2)
    local function testFunc(cb3)
        return 'testFunc-' .. cb3()
    end
    return 'testReentrantCallback-' .. cb2(testFunc)
end

function Test:cleanup()
end

return Test
