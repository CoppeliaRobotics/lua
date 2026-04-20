local class = require 'middleclass'

local CustomClass = class 'sim.CustomClass'

function CustomClass:initialize(name, props, opts)
    local Object = require 'sim.Object'

    rawset(self, 'objectType', name)

    if table.find(Object.app.customClasses, name) then
        rawset(self, 'storageLocation', Object.app)
        rawset(self, 'alreadyRegistered', true)
        return
    elseif table.find(Object.scene.customClasses, name) then
        rawset(self, 'storageLocation', Object.scene)
        rawset(self, 'alreadyRegistered', true)
        return
    end

    opts = opts or {}
    opts.scriptPersistent = opts.scriptPersistent == true
    opts.volatile = opts.volatile ~= false
    opts.classMetaInfo = opts.classMetaInfo or '{"superclass": "object"}'
    assert(opts.storageLocation == nil or opts.storageLocation == Object.app or opts.storageLocation == Object.scene, 'invalid value for "storageLocation"')
    rawset(self, 'storageLocation', opts.storageLocation or Object.app)
    local cls = Object(self.storageLocation:createCustomObject(name, opts))
    if type(props) == 'function' then
        -- class setup function:
        props(cls)
    elseif type(props) == 'table' then
        -- setup properties from a table:
        for k, v in pairs(props) do
            cls:setProperty(k, v, {inferType=true})
        end
        -- additional class setup function via call operator:
        local mt = getmetatable(props)
        if mt and mt.__call then
            props(cls)
        end
    end
    rawset(self, 'simClass', cls)
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
    local o = Object(self.storageLocation:createCustomObject(self.objectType))
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
