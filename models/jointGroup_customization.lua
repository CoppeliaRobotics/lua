sim = require 'sim'

function sysCall_init()
    self = sim.getObject '.'
end

function sysCall_actuation()
    if ruckig and ruckig.run then
        moveToConfigStep()
    end
end

function getJoints()
    return sim.getReferencedHandles(self)
end

function isDynamicallyEnabled()
    return all(sim.isDynamicallyEnabled, getJoints())
end

function getConfig()
    return map(sim.getJointPosition, getJoints())
end

function getTargetConfig()
    return map(sim.setJointTargetPosition, getJoints())
end

function setConfig(cfg)
    foreach(sim.setJointPosition, getJoints(), cfg)
end

function setTargetConfig(cfg)
    foreach(sim.setJointTargetPosition, getJoints(), cfg)
end

function moveToConfig(opts)
    moveToConfigInit(opts)
    ruckig.run = true
end

function moveToConfigInit(opts)
    if ruckig then
        moveToConfigCleanup()
    end
    local joints = getJoints()
    opts = opts or {}
    if opts.targetPos == nil or type(opts.targetPos) ~= 'table' or #joints ~= #opts.targetPos then
        error("missing or invalid 'targetPos' field")
    end
    opts.flags = opts.flags or -1
    opts.maxVel = opts.maxVel or table.rep(1440 * math.pi / 180, #joints)
    opts.maxAccel = opts.maxAccel or table.rep(720 * math.pi / 180, #joints)
    opts.maxJerk = opts.maxJerk or table.rep(360 * math.pi / 180, #joints)
    opts.vel = opts.vel or table.rep(0.0, #joints)
    opts.accel = opts.accel or table.rep(0.0, #joints)
    opts.targetVel = opts.targetVel or table.rep(0.0, #joints)
    ruckig = {
        handle = sim.ruckigPos(
            #joints, 0.0001, -1,
            table.add(getConfig(), opts.vel, opts.accel),
            table.add(opts.maxVel, opts.maxAccel, opts.maxJerk),
            table.rep(1, #joints),
            table.add(opts.targetPos, opts.targetVel)
        ),
    }
end

function moveToConfigCleanup()
    if ruckig then
        sim.ruckigRemove(ruckig.handle)
        ruckig = nil
    end
end

function moveToConfigStep()
    if not ruckig then
        sim.addLog(sim.verbosity_warnings, 'motion not active')
        return
    end
    local joints = getJoints()
    local result, newPosVelAccel = sim.ruckigStep(ruckig.handle, sim.getSimulationTimeStep())
    if result < 0 then
        error('sim.ruckigStep returned error code ' .. result)
    end
    local retVal = {}
    retVal.pos = table.slice(newPosVelAccel, 1, #joints)
    retVal.vel = table.slice(newPosVelAccel, #joints + 1, 2* #joints)
    retVal.accel = table.slice(newPosVelAccel, 2 * #joints + 1, 3 * #joints)
    if isDynamicallyEnabled() then
        setTargetConfig(retVal.pos)
    else
        setConfig(retVal.pos)
    end
    if result == 1 then
        moveToConfigCleanup()
        return
    end
    return retVal
end

function isMoveToConfigRunning()
    if not ruckig then return false end
    return not not ruckig.run
end

function followPath(path, params)
    local code = [[require 'models.followPath_simulation']]
    if params then
        code = code .. 'params = ' .. _S.anyToString(params) .. '\n'
    end
    local script = sim.createScript(sim.scripttype_simulation, code, 0, 'lua')
    sim.setObjectAlias(script, 'followPathScript_tmp')
    sim.setReferencedHandles(script, {path}, 'path')
    sim.initScript(script)
    return script
end
