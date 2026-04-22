return function(name, opts)
    local sim = require 'sim-2'
    for i, c in ipairs(sim.app.customClasses) do
        if c.objectType == name then
            return c
        end
    end
    return sim.Object(sim.app:createCustomObject(name, opts or {classMetaInfo = '{"superclass": "object"}'}))
end
