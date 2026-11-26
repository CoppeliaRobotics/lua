local sim = require('sim-2')
local class = require('middleclass')

-- Abstract base class for motions that can be stepped or run in a thread.
local Motion = class('Motion')

function Motion:initialize()
    self._callback = nil
    self._data = nil
end


function Motion:step()
    error('step() must be implemented by a subclass.')
end


function Motion:remove()
    error('remove() must be implemented by a subclass.')
end


function Motion:data()
    return self._data
end


function Motion:run()
    sim.self:setStepping(true)

    local res

    while true do
        res = self:step()
        sim.self:step()

        if res ~= 0 then
            break
        end
    end

    local outData = self._data

    self:remove()
    sim.self:setStepping(false)

    return outData
end


return Motion
