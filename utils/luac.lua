return function(f, verbose)
    assert(type(f) == 'function', 'not a function')
    local sim = require 'sim-2'
    local simSubprocess = require 'simSubprocess'
    local luac = sim.app.customData.luac or 'luac'
    local ok, ec, out, err = pcall(simSubprocess.exec, luac, {'-v'})
    if not ok then
        sim.app:logError(ec)
        sim.app:logError('"luac" not found. provide its location with app.customData.luac = "..."')
        return
    end
    if not string.startswith(out, _VERSION) then
        sim.app:logError('"luac" version does not match "' .. _VERSION .. '" used by coppeliaSim. provide correct "luac" location with app.customData.luac = "..."')
        return
    end
    local ok, ec, out, err = pcall(simSubprocess.exec, luac, verbose and {'-l', '-l', '-'} or {'-l', '-'}, string.dump(f))
    if ec ~= 0 then
        sim.app:logError('"luac" failed: exit code ' .. ec .. ': ' .. tostring(err))
    else
        print(tostring(out))
    end
end
