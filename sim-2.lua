local sim = setmetatable(table.update({}, require 'sim'), {__version = 2})

sim.getPropertyInfo = wrap(sim.getPropertyInfo, function(origFunc)
    return function(...)
        print('[sim-2] test: sim.getPropertyInfo', ...)
        return origFunc(...)
    end
end)

require('sim.Object').extend(sim)

return sim
