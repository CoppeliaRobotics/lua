local class = require 'middleclass'

local CustomClass = class 'sim.CustomClass'

function CustomClass:initialize(name, props, opts)
    local sim = require 'sim-2'

    rawset(self, 'objectType', name)

    local cls = nil
    for i, c in ipairs(sim.app.customClasses) do
        if c.objectType == name then
            cls = c
            break
        end
    end
    if not cls then
        opts = opts or {}
        opts.scriptPersistent = opts.scriptPersistent == true
        opts.volatile = opts.volatile ~= false
        opts.classMetaInfo = opts.classMetaInfo or '{"superclass": "object"}'
        cls = sim.Object(sim.app:createCustomObject(name, opts))
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
    end
    rawset(self, 'simClass', cls)
end

function CustomClass:__newindex(k, v)
    assert(type(k) == 'string', 'bad key type')
    assert(type(v) == 'function', 'expecting a method declaration only')
    self.simClass:setMethodProperty(k, v)
end

return CustomClass
