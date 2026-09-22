return function(arg)
    local sim = require 'sim-2'
    local i = table.find(sim.app.addOns.scriptName, 'Property explorer')
    if not i then return end
    local pe = sim.app.addOns[i]
    if not pe then return end
    if pe.state ~= sim.scriptstate_initialized then
        pe:init()
    end
    if arg then
        sim.app.current = arg
    end
end
