local class = require 'middleclass'

local CustomClass = class 'sim.CustomClass'

function CustomClass:initialize(name, opts)
    local sim = require 'sim-2'
    for i, c in ipairs(sim.app.customClasses) do
        if c.name == name then
            rawset(self, '__class', c)
            return
        end
    end
    rawset(self, '__class', sim.Object(sim.app:createCustomObjectClass(name, opts or '{"superclass": "object"}')))
end

function CustomClass:__index(k)
    local v = self.__class[k]
    if type(v) == 'function' then
        return function(_, ...) return v(self.__class, ...) end
    end
    return v
end

function CustomClass:__newindex(k, v)
    if type(v) == 'function' then
        self.__class:setMethodProperty(k, v)
    end
end

return CustomClass
