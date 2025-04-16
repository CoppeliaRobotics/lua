local autoStart = {}

local sim = require 'sim'

function autoStart.get(opts)
    if opts.readNamedParam then
        local v = sim.getNamedBoolParam(opts.ns .. '.autoStart')
        if v ~= nil then
            return v
        end
    end

    v = sim.getBoolProperty(sim.handle_app, 'customData.' .. opts.ns .. '.autoStart', {noError = true})
    if v == nil then
        v = opts.default
    end
    return v
end

function autoStart.set(opts, v)
    sim.setBoolProperty(sim.handle_app, 'customData.' .. opts.ns .. '.autoStart', v)
end

function autoStart.setup(opts)
    opts = opts or {}
    opts.readNamedParam = opts.readNamedParam ~= false
    opts.default = opts.default == true
    assert(type(opts.ns) == 'string', 'option "ns" is required')

    if sysCall_init then
        sysCall_init = wrap(sysCall_init, function(origFunc)
            return function(...)
                autoStart.set(opts, true)
                return origFunc(...)
            end
        end)
    else
        sysCall_init = function()
            autoStart.set(opts, true)
        end
    end

    if sysCall_addOnScriptSuspend then
        sysCall_addOnScriptSuspend = wrap(sysCall_addOnScriptSuspend, function(origFunc)
            return function(...)
                autoStart.set(opts, false)
                return origFunc(...)
            end
        end)
    else
        sysCall_addOnScriptSuspend = function()
            autoStart.set(opts, false)
        end
    end

    if sysCall_info then
        sysCall_info = wrap(sysCall_info, function(origFunc)
            return function(...)
                local info = origFunc(...)
                info.autoStart = autoStart.get(opts)
                return info
            end
        end)
    else
        sysCall_info = function()
            return {autoStart = autoStart.get(opts)}
        end
    end
end

return autoStart
