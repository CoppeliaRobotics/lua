local class = require 'middleclass'

local CustomClass = class 'sim.CustomClass'

function CustomClass:initialize(name, props, opts)
    local sim = require 'sim-2'

    rawset(self, 'objectType', name)

    local cont = CustomClass:find(name)
    if cont then
        rawset(self, 'storageLocation', cont)
        rawset(self, 'alreadyRegistered', true)
        return
    end

    opts = opts or {}
    opts.scriptPersistent = opts.scriptPersistent == true
    opts.volatile = opts.volatile ~= false
    opts.classMetaInfo = opts.classMetaInfo or '{"superclass": "object"}'
    assert(opts.storageLocation == nil or opts.storageLocation == sim.app or opts.storageLocation == sim.scene, 'invalid value for "storageLocation"')
    rawset(self, 'storageLocation', opts.storageLocation or sim.app)
    local cls = sim.Object(self.storageLocation:createCustomObject(name, opts))
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
    local sim = require 'sim-2'
    local o = sim.Object(self.storageLocation:createCustomObject(self.objectType))
    if initialProps then
        assert(type(initialProps) == 'table')
        o:setProperties(initialProps)
    end
    if o:getPropertyInfo('init', {noError = true}) == sim.propertytype_method then
        o:getMethodProperty('init')(o)
    end
    return o
end

function CustomClass.static:find(name)
    local sim = require 'sim-2'
    local function eq(c)
        return c.objectType == name
    end
    if table.find(sim.app.customClasses, name, eq) then
        return sim.app
    elseif table.find(sim.scene.customClasses, name, eq) then
        return sim.scene
    end
end

return CustomClass
