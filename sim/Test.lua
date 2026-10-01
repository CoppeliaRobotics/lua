local CustomClass = require 'sim.CustomClass'

local Test = CustomClass 'test'

Test:setBoolProperty('foo', true)

function Test:init()
end

function Test:bar(cb)
    return cb() .. '-bar'
end

function Test:cleanup()
end

return Test
