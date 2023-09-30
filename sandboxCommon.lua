sim = require('sim')
if sim.getNamedBoolParam('simLuaCmd.autoLoad') ~= false then
    require('simLuaCmd')
end
if not sim.getBoolParam(sim.boolparam_headless) then
    require('simURLDrop')
end
base16 = require('base16')
base64 = require('base64')
require('base-ce')
local l = auxFunc('getfiles', sim.getStringParam(sim.stringparam_luadir), 'sim*-ce', 'lua')
for i = 1, #l, 1 do
    require(string.gsub(l[i], "%.lua$", ""))
end
setupLazyLoaders() -- because those were cleared out by our explicit requires
