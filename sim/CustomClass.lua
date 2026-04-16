local class = require 'middleclass'

local CustomClass = class 'sim.CustomClass'

function CustomClass:initialize(name, props, opts)
    rawset(self, 'objectType', name)
    local sim = require 'sim-2'
    if table.find(sim.app.customClasses, name) then
        rawset(self, 'alreadyRegistered', true)
    else
        opts = opts or {}
        opts.classMetaInfo = '{"superclass": "object"}'
        local Object = require 'sim.Object'
        local cls = Object(Object.app:createCustomObject(name, opts))
        for k, v in pairs(props) do
            cls:setProperty(k, v, {inferType=true})
        end
        rawset(self, 'simClass', cls)
    end
end

function CustomClass:__newindex(k, v)
    assert(type(k) == 'string', 'bad key type')
    assert(type(v) == 'function', 'expecting a method declaration only')
    if self.alreadyRegistered then return end
    self.simClass:setMethodProperty(k, v)
end

function CustomClass:__call(initialProps)
    if self.simClass then
        self.simClass.__configDone__ = true
        self.simClass = nil
    end
    local Object = require 'sim.Object'
    local o = Object(Object.app:createCustomObject(self.objectType))
    if initialProps then
        assert(type(initialProps) == 'table')
        o:setProperties(initialProps)
    end
    local sim = {propertytype_method = 240}
    if o:getPropertyInfo('init', {noError = true}) == sim.propertytype_method then
        o:getMethodProperty('init')(o)
    end
    return o
end

return CustomClass
