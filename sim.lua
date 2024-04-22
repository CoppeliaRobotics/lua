-- The is the first versioned sim-namespace
-- The very first API without namespace (e.g. simGetObjectHandle) is only
-- included if 'supportOldApiNotation' is true in 'usrset.txt'
local sim = _S.sim
_S.sim = nil

sim.addLog = addLog
sim.quitSimulator = quitSimulator
sim.registerScriptFuncHook = registerScriptFuncHook

function sim.setStepping(enable)
    -- Convenience function, so that we have the same, more intuitive name also with external clients
    -- Needs to be overridden by Python wrapper and remote API server code
    if type(enable) ~= 'number' then enable = not enable end
    return setAutoYield(enable)
end

function sim.acquireLock()
    -- needs to be overridden by remote API components
    setYieldAllowed(false)
end

function sim.releaseLock()
    -- needs to be overridden by remote API components
    setYieldAllowed(true)
end

function sim.yield()
    if getYieldAllowed() then
        if sim.isScriptRunningInThread() == 1 then
            sim._switchThread() -- old, deprecated threads
        else
            local thread, yieldForbidden = coroutine.running()
            if not yieldForbidden then coroutine.yield() end
        end
    end
end

function sim.step(wait)
    -- Convenience function, for a more intuitive name, depending on the context
    -- Needs to be overridden by Python wrapper and remote API server code
    sim.yield()
end

-- Backw. compat.:
---------------------------------
sim.switchThread = sim.yield
sim.getModuleName = sim.getPluginName
sim.getModuleInfo = sim.getPluginInfo
sim.setModuleInfo = sim.setPluginInfo
sim.moduleinfo_extversionstr = sim.plugininfo_extversionstr
sim.moduleinfo_builddatestr = sim.plugininfo_builddatestr
sim.moduleinfo_extversionint = sim.plugininfo_extversionint
sim.moduleinfo_verbosity = sim.plugininfo_verbosity
sim.moduleinfo_statusbarverbosity = sim.plugininfo_statusbarverbosity
sim.setThreadSwitchAllowed = setYieldAllowed
sim.getThreadSwitchAllowed = getYieldAllowed
sim.setThreadAutomaticSwitch = setAutoYield
sim.getThreadAutomaticSwitch = getAutoYield
function sim.setThreadSwitchTiming(dtInMs)
    sim.setAutoYieldDelay(dtInMs / 1000.0)
end
function sim.getThreadSwitchTiming()
    return sim.getAutoYieldDelay() * 1000.0
end
function sim.getIsRealTimeSimulation()
    local ret = 0
    if sim.getRealTimeSimulation() then
        ret = 1
    end
    return ret
end
---------------------------------

require('stringx')
require('tablex')
require('checkargs')
require('matrix')
require('grid')
require('functional')
require('var')

sim.stopSimulation = wrap(sim.stopSimulation, function(origFunc)
    return function(wait)
        origFunc()
        local t = sim.getScriptInt32Param(sim.handle_self, sim.scriptintparam_type)
        if wait and t ~= sim.scripttype_mainscript and t ~= sim.scripttype_childscript and getYieldAllowed() then
            local cnt = 0
            while sim.getSimulationState() ~= sim.simulation_stopped and cnt < 20 do -- even if we run in a thread, we might not be able to yield (e.g. across a c-boundary)
                cnt = cnt + 1
                sim.step()
            end
        end
    end
end)

-- Make sim.registerScriptFuncHook work also with a function as arg 2:
function _S.registerScriptFuncHook(funcNm, func, before)
    local retVal
    if type(func) == 'string' then
        retVal = _S.registerScriptFuncHookOrig(funcNm, func, before)
    else
        local str = tostring(func)
        retVal = _S.registerScriptFuncHookOrig(funcNm, '_S.' .. str, before)
        _S[str] = func
    end
    return retVal
end
_S.registerScriptFuncHookOrig = sim.registerScriptFuncHook
sim.registerScriptFuncHook = _S.registerScriptFuncHook

function math.random2(lower, upper)
    -- same as math.random, but each script has its own generator
    local r = sim.getRandom()
    if lower then
        local b = 1
        local d
        if upper then
            b = lower
            d = upper - b
        else
            d = lower - b
        end
        local e = d / (d + 1)
        r = b + math.floor(r * d / e)
    end
    return r
end

function math.randomseed2(seed)
    -- same as math.randomseed, but each script has its own generator
    sim.getRandom(seed)
end

function sim.yawPitchRollToAlphaBetaGamma(...)
    local yawAngle, pitchAngle, rollAngle = checkargs({
        {type = 'float'}, {type = 'float'}, {type = 'float'},
    }, ...)

    local lb = sim.setStepping(true)
    local Rx = sim.buildMatrix({0, 0, 0}, {rollAngle, 0, 0})
    local Ry = sim.buildMatrix({0, 0, 0}, {0, pitchAngle, 0})
    local Rz = sim.buildMatrix({0, 0, 0}, {0, 0, yawAngle})
    local m = sim.multiplyMatrices(Ry, Rx)
    m = sim.multiplyMatrices(Rz, m)
    local alphaBetaGamma = sim.getEulerAnglesFromMatrix(m)
    local alpha = alphaBetaGamma[1]
    local beta = alphaBetaGamma[2]
    local gamma = alphaBetaGamma[3]
    sim.setStepping(lb)
    return alpha, beta, gamma
end

function sim.alphaBetaGammaToYawPitchRoll(...)
    local alpha, beta, gamma = checkargs({
        {type = 'float'}, {type = 'float'}, {type = 'float'}
    }, ...)

    local lb = sim.setStepping(true)
    local m = sim.buildMatrix({0, 0, 0}, {alpha, beta, gamma})
    local v = m[9]
    if v > 1 then v = 1 end
    if v < -1 then v = -1 end
    local pitchAngle = math.asin(-v)
    local yawAngle, rollAngle
    if math.abs(v) < 0.999999 then
        rollAngle = math.atan2(m[10], m[11])
        yawAngle = math.atan2(m[5], m[1])
    else
        -- Gimbal lock
        rollAngle = math.atan2(-m[7], m[6])
        yawAngle = 0
    end
    sim.setStepping(lb)
    return yawAngle, pitchAngle, rollAngle
end

function sim.getObjectsWithTag(tagName, justModels)
    local retObjs = {}
    local objs = sim.getObjectsInTree(sim.handle_scene)
    for i = 1, #objs, 1 do
        if (not justModels) or ((sim.getModelProperty(objs[i]) & sim.modelproperty_not_model) == 0) then
            local dat = sim.readCustomDataBlockTags(objs[i])
            if dat and #dat > 0 then
                for j = 1, #dat, 1 do
                    if dat[j] == tagName then
                        retObjs[#retObjs + 1] = objs[i]
                        break
                    end
                end
            end
        end
    end
    return retObjs
end

function sim.executeLuaCode(theCode)
    local f = loadstring(theCode)
    if f then
        local a, b = pcall(f)
        return a, b
    else
        return false, 'compilation error'
    end
end

function sim.fastIdleLoop(enable)
    local data = sim.readCustomDataBlock(sim.handle_app, '__IDLEFPSSTACKSIZE__')
    local stage = 0
    local defaultIdleFps
    if data and #data > 0 then
        data = sim.unpackInt32Table(data)
        stage = data[1]
        defaultIdleFps = data[2]
    else
        defaultIdleFps = sim.getInt32Param(sim.intparam_idle_fps)
    end
    if enable then
        stage = stage + 1
    else
        if stage > 0 then stage = stage - 1 end
    end
    if stage > 0 then
        sim.setInt32Param(sim.intparam_idle_fps, 0)
    else
        sim.setInt32Param(sim.intparam_idle_fps, defaultIdleFps)
    end
    sim.writeCustomDataBlock(
        sim.handle_app, '__IDLEFPSSTACKSIZE__', sim.packInt32Table({stage, defaultIdleFps})
    )
end

function sim.getLoadedPlugins()
    local ret = {}
    local index = 0
    while true do
        local moduleName = sim.getModuleName(index)
        if moduleName then
            table.insert(ret, moduleName)
        else
            break
        end
        index = index + 1
    end
    return ret
end

function sim.isPluginLoaded(pluginName)
    local index = 0
    local moduleName = ''
    while moduleName do
        moduleName = sim.getModuleName(index)
        if moduleName == pluginName then return (true) end
        index = index + 1
    end
    return false
end

function sim.loadPlugin(name)
    -- legacy plugins
    local path = sim.getStringParam(sim.stringparam_application_path)
    local plat = sim.getInt32Param(sim.intparam_platform)
    local windows, mac, linux = 0, 1, 2
    if plat == windows then
        path = path .. '\\simExt' .. name .. '.dll'
    elseif plat == mac then
        path = path .. '/libsimExt' .. name .. '.dylib'
    elseif plat == linux then
        path = path .. '/libsimExt' .. name .. '.so'
    else
        error('unknown platform: ' .. plat)
    end
    return sim.loadModule(path, name)
end

function sim.getUserVariables()
    local ng = {}
    if _S.initGlobals then
        for key, val in pairs(_G) do if not _S.initGlobals[key] then ng[key] = val end end
    else
        ng = _G
    end
    -- hide a few additional system variables:
    ng.sim_call_type = nil
    ng.sim_code_function_to_run = nil
    ng.__notFirst__ = nil
    ng.__scriptCodeToRun__ = nil
    ng._S = nil
    ng.H = nil
    ng.restart = nil
    return ng
end

function sim.getMatchingPersistentDataTags(...)
    local pattern = checkargs({{type = 'string'}}, ...)
    local result = {}
    for index, value in ipairs(sim.getPersistentDataTags()) do
        if value:match(pattern) then result[#result + 1] = value end
    end
    return result
end

function sim.throttle(t, func, ...)
    if _S.lastExecTime == nil then _S.lastExecTime = {} end
    local h = string.dump(func)
    local now = sim.getSystemTime()
    if _S.lastExecTime[h] == nil or _S.lastExecTime[h] + t < now then
        func(...)
        _S.lastExecTime[h] = now
    end
end

function sim.getAlternateConfigs(...)
    local jointHandles, inputConfig, tipHandle, lowLimits, ranges = checkargs({
        {type = 'table', item_type = 'int'},
        {type = 'table', item_type = 'float'},
        {type = 'int', default = -1},
        {type = 'table', item_type = 'float', default = NIL, nullable = true},
        {type = 'table', item_type = 'float', default = NIL, nullable = true},
    }, ...)

    if #jointHandles < 1 or #jointHandles ~= #inputConfig or
        (lowLimits and #jointHandles ~= #lowLimits) or (ranges and #jointHandles ~= #ranges) then
        error("Bad table size.")
    end

    local lb = sim.setStepping(true)
    local initConfig = {}
    local x = {}
    local confS = {}
    local err = false
    for i = 1, #jointHandles, 1 do
        initConfig[i] = sim.getJointPosition(jointHandles[i])
        local c, interv = sim.getJointInterval(jointHandles[i])
        local t = sim.getJointType(jointHandles[i])
        local sp = sim.getObjectFloatParam(jointHandles[i], sim.jointfloatparam_screw_pitch)
        if t == sim.joint_revolute_subtype and not c then
            if sp == 0 then
                if inputConfig[i] - math.pi * 2 >= interv[1] or inputConfig[i] + math.pi * 2 <=
                    interv[1] + interv[2] then
                    -- We use the low and range values from the joint's settings
                    local y = inputConfig[i]
                    while y - math.pi * 2 >= interv[1] do y = y - math.pi * 2 end
                    x[i] = {y, interv[1] + interv[2]}
                end
            end
        end
        if x[i] then
            if lowLimits and ranges then
                -- the user specified low and range values. Use those instead:
                local l = lowLimits[i]
                local r = ranges[i]
                if r ~= 0 then
                    if r > 0 then
                        if l < interv[1] then
                            -- correct for user bad input
                            r = r - (interv[1] - l)
                            l = interv[1]
                        end
                        if l > interv[1] + interv[2] then
                            -- bad user input. No alternative position for this joint
                            x[i] = {inputConfig[i], inputConfig[i]}
                            err = true
                        else
                            if l + r > interv[1] + interv[2] then
                                -- correct for user bad input
                                r = interv[1] + interv[2] - l
                            end
                            if inputConfig[i] - math.pi * 2 >= l or inputConfig[i] + math.pi * 2 <=
                                l + r then
                                local y = inputConfig[i]
                                while y < l do y = y + math.pi * 2 end
                                while y - math.pi * 2 >= l do
                                    y = y - math.pi * 2
                                end
                                x[i] = {y, l + r}
                            else
                                -- no alternative position for this joint
                                x[i] = {inputConfig[i], inputConfig[i]}
                                err = (inputConfig[i] < l) or (inputConfig[i] > l + r)
                            end
                        end
                    else
                        r = -r
                        l = inputConfig[i] - r * 0.5
                        if l < x[i][1] then l = x[i][1] end
                        local u = inputConfig[i] + r * 0.5
                        if u > x[i][2] then u = x[i][2] end
                        x[i] = {l, u}
                    end
                end
            end
        else
            -- there's no alternative position for this joint
            x[i] = {inputConfig[i], inputConfig[i]}
        end
        confS[i] = x[i][1]
    end
    local configs = {}
    if not err then
        for i = 1, #jointHandles, 1 do sim.setJointPosition(jointHandles[i], inputConfig[i]) end
        local desiredPose = 0
        if tipHandle ~= -1 then desiredPose = sim.getObjectMatrix(tipHandle) end
        configs =
            _S.loopThroughAltConfigSolutions(jointHandles, desiredPose, confS, x, 1, tipHandle)
    end

    for i = 1, #jointHandles, 1 do sim.setJointPosition(jointHandles[i], initConfig[i]) end
    if next(configs) ~= nil then
        configs = Matrix:fromtable(configs)
        configs = configs:data()
    end
    sim.setStepping(lb)
    return configs
end

function sim.moveToConfig_init(params)
    params = params or {}
    if params.pos == nil or type(params.pos) ~= 'table' or #params.pos == 0 then
        error("missing or invalid 'pos' field.")
    end
    if params.targetPos == nil or type(params.targetPos) ~= 'table' or #params.targetPos ~= #params.pos then
        error("missing or invalid 'targetPos' field.")
    end
    params.flags = params.flags or -1
    if params.flags == -1 then params.flags = sim.ruckig_phasesync end
    params.flags = params.flags | sim.ruckig_minvel | sim.ruckig_minaccel
    params.vel = params.vel or table.rep(0.0, #params.pos)
    params.accel = params.accel or table.rep(0.0, #params.pos)
    params.maxVel = params.maxVel or table.rep(0.5, #params.pos)
    params.minVel = params.minVel or map(function(h) return (-h) end, params.maxVel)
    params.maxAccel = params.maxAccel or table.rep(0.1, #params.pos)
    params.minAccel = params.minAccel or map(function(h) return (-h) end, params.maxAccel)
    params.maxJerk = params.maxJerk or table.rep(0.2, #params.pos)
    params.targetVel = params.targetVel or table.rep(0.0, #params.pos)
    params.timeStep = params.timeStep or 0
    table.slice(params.vel, 1, #params.pos)
    table.slice(params.accel, 1, #params.pos)
    table.slice(params.maxVel, 1, #params.pos)
    table.slice(params.minVel, 1, #params.pos)
    table.slice(params.maxAccel, 1, #params.pos)
    table.slice(params.minAccel, 1, #params.pos)
    table.slice(params.maxJerk, 1, #params.pos)
    table.slice(params.targetVel, 1, #params.pos)

    for i = 1, #params.pos do
        local v = params.pos[i]
        local w = params.targetPos[i]
        if params.cyclicJoints and params.cyclicJoints[i] then
            while w - v >= math.pi * 2 do w = w - math.pi * 2 end
            while w - v < 0 do w = w + math.pi * 2 end
            if w - v > math.pi then w = w - math.pi * 2 end
        end
        params.targetPos[i] = w
    end
    local currentPosVelAccel = table.add(params.pos, params.vel, params.accel)
    local maxVelAccelJerk = table.add(params.maxVel, params.maxAccel, params.maxJerk, params.minVel, params.minAccel)
    local targetPosVel = table.add(params.targetPos, params.targetVel)
    local sel = table.rep(1, #params.pos)
    
    local data = {}
    data.ruckigObj = sim.ruckigPos(#params.pos, 0.0001, params.flags, currentPosVelAccel, maxVelAccelJerk, sel, targetPosVel)
    data.pos = table.clone(params.pos)
    data.vel = table.clone(params.vel)
    data.accel = table.clone(params.accel)
    data.callback = params.callback
    if type(data.callback) == 'string' then
        data.callback = _G[data.callback]
    end
    data.auxData = params.auxData
    data.timeStep = params.timeStep
    data.timeLeft = 0
    
    return data
end

function sim.moveToConfig_step(data)
    local dt = data.timeStep
    if dt == 0 then
        dt = sim.getSimulationTimeStep()
    end
    local res, newPosVelAccel, syncTime = sim.ruckigStep(data.ruckigObj, dt)
    if res >= 0 then
        if res == 0 then
            data.timeLeft = dt - syncTime
        end
        for i = 1, #data.pos do
            data.pos[i] = newPosVelAccel[i]
            data.vel[i] = newPosVelAccel[#data.pos + i]
            data.accel[i] = newPosVelAccel[#data.pos * 2 + i]
        end
        if data.callback(data.pos, data.vel, data.accel, data.auxData) then
            res = 2 -- aborted
        end
    end

    return res, data
end

function sim.moveToConfig_cleanup(data)
    sim.ruckigRemove(data.ruckigObj)
end

function sim.moveToConfig(...)
    local params = ...
    
    -- backw. compatibility part:
    -----------------------------
    if type(params) == 'number' then
        params = {}
        local flags, currentPos, currentVel, currentAccel, maxVel, maxAccel, maxJerk, targetPos,
              targetVel, callback, auxData, cyclicJoints, timeStep = checkargs({
            {type = 'int'},
            {type = 'table', item_type = 'float'},
            {type = 'table', item_type = 'float', nullable = true},
            {type = 'table', item_type = 'float', nullable = true},
            {type = 'table', item_type = 'float'},
            {type = 'table', item_type = 'float'},
            {type = 'table', item_type = 'float'},
            {type = 'table', item_type = 'float'},
            {type = 'table', item_type = 'float', nullable = true},
            {type = 'any'},
            {type = 'any', default = NIL, nullable = true},
            {type = 'table', item_type = 'bool', default = NIL, nullable = true},
            {type = 'float', default = 0},
        }, ...)
        params.flags = flags
        params.pos = currentPos
        params.vel = currentVel
        params.accel = currentAccel
        params.maxVel = table.slice(maxVel, 1, #params.pos)
        params.minVel = map(function(h) return (-h) end, params.maxVel)
        params.maxAccel = table.slice(maxAccel, 1, #params.pos)
        params.minAccel = map(function(h) return (-h) end, params.maxAccel)
        params.maxJerk = maxJerk
        params.targetPos = targetPos
        params.targetVel = targetVel
        params.callback = callback
        params.auxData = auxData
        params.cyclicJoints = cyclicJoints
        params.timeStep = timeStep
        if params.flags >= 0 and (params.flags & sim.ruckig_minvel) ~= 0 then
            params.minVel = table.slice(maxVel, #params.pos + 1)
            params.flags = params.flags - sim.ruckig_minvel
        end
        if params.flags >= 0 and (params.flags & sim.ruckig_minaccel) ~= 0 then
            params.minAccel = table.slice(maxAccel, #params.pos + 1)
            params.flags = params.flags - sim.ruckig_minaccel
        end
    end
    -----------------------------

    local lb = sim.setStepping(true)
    local data = sim.moveToConfig_init(params)
    local outParams = {}
    while true do
        local res, outParams = sim.moveToConfig_step(data)
        if res ~= 0 then
            if res < 0 then
                error('sim.moveToConfig_step returned error code ' .. res)
            end
            break
        end
        sim.step()
    end
    sim.moveToConfig_cleanup(data)
    sim.setStepping(lb)
    return outParams.pos, outParams.vel, outParams.accel, outParams.timeLeft, outParams -- ret args for backw. comp.
end

function sim.moveToPose_init(params)
    params = params or {}
    if params.pose == nil or type(params.pose) ~= 'table' or #params.pose ~= 7 then
        error("missing or invalid 'pose' field.")
    end
    if params.targetPose == nil or type(params.targetPose) ~= 'table' or #params.targetPose ~= 7 then
        error("missing or invalid 'targetPose' field.")
    end
    params.flags = params.flags or -1
    if params.flags == -1 then params.flags = sim.ruckig_phasesync end
    params.flags = params.flags | sim.ruckig_minvel | sim.ruckig_minaccel
    local dim = 4
    if params.metric then
        dim = 1
        params.maxVel = params.maxVel or table.rep(0.2, dim)
        params.minVel = params.minVel or map(function(h) return (-h) end, params.maxVel)
        params.maxAccel = params.maxAccel or table.rep(0.1, dim)
        params.minAccel = params.minAccel or map(function(h) return (-h) end, params.maxAccel)
        params.maxJerk = params.maxJerk or table.rep(0.1, dim)
    else
        params.maxVel = params.maxVel or {0.2, 0.2, 0.2, 1.0 * math.pi}
        params.minVel = params.minVel or map(function(h) return (-h) end, params.maxVel)
        params.maxAccel = params.maxAccel or {0.1, 0.1, 0.1, 0.5 * math.pi}
        params.minAccel = params.minAccel or map(function(h) return (-h) end, params.maxAccel)
        params.maxJerk = params.maxJerk or {0.1, 0.1, 0.1, 0.5 * math.pi}
    end
    params.timeStep = params.timeStep or 0
    table.slice(params.maxVel, 1, dim)
    table.slice(params.minVel, 1, dim)
    table.slice(params.maxAccel, 1, dim)
    table.slice(params.minAccel, 1, dim)
    table.slice(params.maxJerk, 1, dim)

    local data = {}
    data.startMatrix = sim.poseToMatrix(params.pose)
    data.targetMatrix = sim.poseToMatrix(params.targetPose)
    data.useMatrices = params.useMatrices
    data.pose = table.clone(params.pose)
    data.matrix = table.clone(data.startMatrix)
    data.callback = params.callback
    if type(data.callback) == 'string' then
        data.callback = _G[data.callback]
    end
    data.auxData = params.auxData
    data.timeStep = params.timeStep
    data.metric = params.metric
    data.timeLeft = 0
    data.dist = 1.0
    
    local axis, angle = sim.getRotationAxis(data.startMatrix, data.targetMatrix)
    data.angle = angle
    if data.metric then
        -- Here we treat the movement as a 1 DoF movement, where we simply interpolate via t between
        -- the start and goal pose. This always results in straight line movement paths
        local dx = {
            (data.targetMatrix[4] - data.startMatrix[4]) * data.metric[1],
            (data.targetMatrix[8] - data.startMatrix[8]) * data.metric[2],
            (data.targetMatrix[12] - data.startMatrix[12]) * data.metric[3], data.angle * data.metric[4],
        }
        data.dist = math.sqrt(dx[1] * dx[1] + dx[2] * dx[2] + dx[3] * dx[3] + dx[4] * dx[4])
        if data.dist > 0.000001 then
            local currentPosVelAccel = {0, 0, 0}
            local maxVelAccelJerk = {params.maxVel[1], params.maxAccel[1], params.maxJerk[1], params.minVel[1], params.minAccel[1]}
            data.ruckigObj = sim.ruckigPos(1, 0.0001, params.flags, currentPosVelAccel, maxVelAccelJerk, {1}, {data.dist, 0} )
        end
    else
        -- Here we treat the movement as a 4 DoF movement, where each of X, Y, Z and rotation
        -- is handled and controlled individually. This can result in non-straight line movement paths,
        -- due to how the Ruckig functions operate depending on 'flags'
        local dx = {
            data.targetMatrix[4] - data.startMatrix[4], data.targetMatrix[8] - data.startMatrix[8],
            data.targetMatrix[12] - data.startMatrix[12], data.angle,
        }
        local currentPosVelAccel = table.rep(0.0, 3 * dim)
        local maxVelAccelJerk = table.add(params.maxVel, params.maxAccel, params.maxJerk, params.minVel, params.minAccel)
        local targetPosVel = table.add(dx, {0.0, 0.0, 0.0, 0.0})
        data.ruckigObj = sim.ruckigPos(dim, 0.0001, params.flags, currentPosVelAccel, maxVelAccelJerk, table.rep(1, dim), targetPosVel)
    end

    data.vel  = table.rep(0.0, dim)
    data.accel  = table.rep(0.0, dim)
    
    return data
end
            
function sim.moveToPose_step(data)
    local res
    local dt = data.timeStep
    if dt == 0 then
        dt = sim.getSimulationTimeStep()
    end
    if data.metric then
        -- Here we treat the movement as a 1 DoF movement, where we simply interpolate via t between
        -- the start and goal pose. This always results in straight line movement paths
        if data.dist > 0.000001 then
            local newPosVelAccel, syncTime
            res, newPosVelAccel, syncTime = sim.ruckigStep(data.ruckigObj, dt)
            if res >= 0 then
                if res == 0 then
                    data.timeLeft = dt - syncTime
                end
                local t = newPosVelAccel[1] / data.dist
                data.matrix = sim.interpolateMatrices(data.startMatrix, data.targetMatrix, t)
                data.pose = sim.matrixToPose(data.matrix)
                data.vel = {newPosVelAccel[2]}
                data.accel = {newPosVelAccel[3]}
                if data.callback then
                    local arg = data.pose
                    if data.useMatrices then
                        arg = data.matrix
                    end
                    if data.callback(arg, data.vel, data.accel, data.auxData) then
                        res = 2 -- aborted
                    end
                end
            end
        else
            res = 1 -- i.e. there is no motion to be executed
        end
    else
        -- Here we treat the movement as a 4 DoF movement, where each of X, Y, Z and rotation
        -- is handled and controlled individually. This can result in non-straight line movement paths,
        -- due to how the Ruckig functions operate depending on 'flags'
        local newPosVelAccel, syncTime
        res, newPosVelAccel, syncTime = sim.ruckigStep(data.ruckigObj, dt)
        if res >= 0 then
            if res == 0 then
                data.timeLeft = dt - syncTime
            end
            local t = 0
            if math.abs(data.angle) > math.pi * 0.00001 then
                t = newPosVelAccel[4] / data.angle
            end
            data.matrix = sim.interpolateMatrices(data.startMatrix, data.targetMatrix, t)
            data.matrix[4] = data.startMatrix[4] + newPosVelAccel[1]
            data.matrix[8] = data.startMatrix[8] + newPosVelAccel[2]
            data.matrix[12] = data.startMatrix[12] + newPosVelAccel[3]
            data.pose = sim.matrixToPose(data.matrix)
            data.vel  = table.slice(newPosVelAccel, 5, 8)
            data.accel = table.slice(newPosVelAccel, 9, 12)
            if data.callback then
                local arg = data.pose
                if data.useMatrices then
                    arg = data.matrix
                end
                if data.callback(arg, data.vel, data.accel, data.auxData) then
                    res = 2 -- aborted
                end
            end
        end
    end

    return res, data
end

function sim.moveToPose_cleanup(data)
    sim.ruckigRemove(data.ruckigObj)
end

function sim.moveToPose(...)
    local params = ...
    
    -- backw. compatibility part:
    -----------------------------
    if type(params) == 'number' then
        params = {}
        local flags, currentPoseOrMatrix, maxVel, maxAccel, maxJerk, targetPoseOrMatrix, callback,
              auxData, metric, timeStep = checkargs({
            {type = 'int'},
            {type = 'table', size = '7..12'},
            {type = 'table', item_type = 'float'},
            {type = 'table', item_type = 'float'},
            {type = 'table', item_type = 'float'},
            {type = 'table', size = '7..12'},
            {type = 'any'},
            {type = 'any', default = NIL, nullable = true},
            {type = 'table', size = 4, default = NIL, nullable = true},
            {type = 'float', default = 0},
        }, ...)
        params.flags = flags
        if #currentPoseOrMatrix == 7 then
            params.pose = currentPoseOrMatrix
        else
            params.pose = sim.matrixToPose(currentPoseOrMatrix)
            params.useMatrices = true
        end
        params.metric = metric
        local dim = 4
        if params.metric then
            dim = 1
        end
        params.maxVel = table.slice(maxVel, 1, dim)
        params.minVel = map(function(h) return (-h) end, params.maxVel)
        params.maxAccel = table.slice(maxAccel, 1, dim)
        params.minAccel = map(function(h) return (-h) end, params.maxAccel)
        params.maxJerk = maxJerk
        if #targetPoseOrMatrix == 7 then
            params.targetPose = targetPoseOrMatrix
        else
            params.targetPose = sim.matrixToPose(targetPoseOrMatrix)
        end
        params.callback = callback
        params.auxData = auxData
        params.timeStep = timeStep

        if params.flags >= 0 and (params.flags & sim.ruckig_minvel) ~= 0 then
            params.minVel = table.slice(maxVel, dim + 1)
            params.flags = params.flags - sim.ruckig_minvel
        end
        if params.flags >= 0 and (params.flags & sim.ruckig_minaccel) ~= 0 then
            params.minAccel = table.slice(maxAccel, dim + 1)
            params.flags = params.flags - sim.ruckig_minaccel
        end
    end
    -----------------------------
    
    local lb = sim.setStepping(true)
    local data = sim.moveToPose_init(params)
    local outParams = {}
    while true do
        local res, outParams = sim.moveToPose_step(data)
        if res ~= 0 then
            if res < 0 then
                error('sim.moveToPose_step returned error code ' .. res)
            end
            break
        end
        sim.step()
    end
    sim.moveToPose_cleanup(data)
    sim.setStepping(lb)
    return outParams.matrix, outParams.timeLeft, outParams -- ret args for backw. comp.
end

function sim.generateTimeOptimalTrajectory(...)
    simZMQ = require 'simZMQ'
    local path, pathLengths, minMaxVel, minMaxAccel, trajPtSamples, boundaryCondition, timeout =
        checkargs({
            {type = 'table', item_type = 'float', size = '2..*'},
            {type = 'table', item_type = 'float', size = '2..*'},
            {type = 'table', item_type = 'float', size = '2..*'},
            {type = 'table', item_type = 'float', size = '2..*'},
            {type = 'int', default = 1000},
            {type = 'string', default = 'not-a-knot'},
            {type = 'float', default = 5},
    }, ...)

    local confCnt = #pathLengths
    local dof = math.floor(#path / confCnt)

    if (dof * confCnt ~= #path) or dof < 1 or confCnt < 2 or dof ~= #minMaxVel / 2 or
        dof ~= #minMaxAccel / 2 then error("Bad table size.") end
    local lb = sim.setStepping(true)

    local pM = Matrix(confCnt, dof, path)
    local mmvM = Matrix(2, dof, minMaxVel)
    local mmaM = Matrix(2, dof, minMaxAccel)

    sim.addLog(sim.verbosity_scriptinfos,
        "Trying to connect via ZeroMQ to the 'toppra' service... " ..
        "make sure the 'docker-image-zmq-toppra' container is running. " ..
        "Details can be found at https://github.com/CoppeliaRobotics/docker-image-zmq-toppra"
    )
    local context = simZMQ.ctx_new()
    local socket = simZMQ.socket(context, simZMQ.REQ)
    simZMQ.setsockopt(socket, simZMQ.RCVTIMEO, sim.packInt32Table {1000 * timeout})
    simZMQ.setsockopt(socket, simZMQ.LINGER, sim.packInt32Table {500})
    local result = simZMQ.connect(socket, 'tcp://localhost:22505')
    if result == -1 then
        local err = simZMQ.errnum()
        error('connect failed: ' .. err .. ': ' .. simZMQ.strerror(err))
    end
    local json = require 'dkjson'
    local result = simZMQ.send(socket, json.encode {
        samples = trajPtSamples,
        ss_waypoints = pathLengths,
        waypoints = pM:totable(),
        velocity_limits = mmvM:totable(),
        acceleration_limits = mmaM:totable(),
        bc_type = boundaryCondition,
    }, 0)
    if result == -1 then
        local err = simZMQ.errnum()
        error('send failed: ' .. err .. ': ' .. simZMQ.strerror(err))
    end
    local msg = simZMQ.msg_new()
    simZMQ.msg_init(msg)

    local st = sim.getSystemTime()
    result = -1
    while sim.getSystemTime() - st < 2 do
        local rc, revents = simZMQ.poll({socket}, {simZMQ.POLLIN}, 0)
        if rc > 0 then
            result = simZMQ.msg_recv(msg, socket, 0)
            break
        end
    end
    if result == -1 then
        local err = simZMQ.errnum()
        error('recv failed: ' .. err .. ': ' .. simZMQ.strerror(err))
    end
    local data = simZMQ.msg_data(msg)
    simZMQ.msg_close(msg)
    simZMQ.msg_destroy(msg)

    if isbuffer(data) then
        data = data.__buff__
    end
    local r = json.decode(data)
    simZMQ.close(socket)
    simZMQ.ctx_term(context)

    sim.setStepping(lb)
    return Matrix:fromtable(r.qs[1]):data(), r.ts
end

function sim.copyTable(t)
    return table.deepcopy(t)
end

function sim.getPathInterpolatedConfig(...)
    local path, times, t, method, types = checkargs({
        {type = 'table', item_type = 'float', size = '2..*'},
        {type = 'table', item_type = 'float', size = '2..*'},
        {type = 'float'},
        {type = 'table', default = {type = 'linear', strength = 1.0, forceOpen = false}, nullable = true},
        {type = 'table', item_type = 'int', size = '1..*', default = NIL, nullable = true},
    }, ...)

    local confCnt = #times
    local dof = math.floor(#path / confCnt)

    if (dof * confCnt ~= #path) or (types and dof ~= #types) then error("Bad table size.") end

    if types == nil then
        types = {}
        for i = 1, dof, 1 do types[i] = 0 end
    end
    local retVal = {}
    local li = 1
    local hi = 2
    if t < 0 then t = 0 end
    --    if confCnt>2 then
    if t >= times[#times] then t = times[#times] - 0.00000001 end
    local ll, hl
    for i = 2, #times, 1 do
        li = i - 1
        hi = i
        ll = times[li]
        hl = times[hi]
        if hl > t then -- >= gives problems with overlapping points
            break
        end
    end
    t = (t - ll) / (hl - ll)
    --    else
    --        if t>1 then t=1 end
    --    end
    if method and method.type == 'quadraticBezier' then
        local w = 1
        if method.strength then w = method.strength end
        if w < 0.05 then w = 0.05 end
        local closed = true
        for i = 1, dof, 1 do
            if (path[i] ~= path[(confCnt - 1) * dof + i]) then
                closed = false
                break
            end
        end
        if method.forceOpen then closed = false end
        local i0, i1, i2
        if t < 0.5 then
            if li == 1 and not closed then
                retVal = _S.linearInterpolate(_S.getConfig(path, dof, li), _S.getConfig(path, dof, hi), t, types)
            else
                if t < 0.5 * w then
                    i0 = li - 1
                    i1 = li
                    i2 = hi
                    if li == 1 then i0 = confCnt - 1 end
                    local a = _S.linearInterpolate(_S.getConfig(path, dof, i0), _S.getConfig(path, dof, i1), 1 - 0.25 * w + t * 0.5, types)
                    local b = _S.linearInterpolate(_S.getConfig(path, dof, i1), _S.getConfig(path, dof, i2), 0.25 * w + t * 0.5, types)
                    retVal = _S.linearInterpolate(a, b, 0.5 + t / w, types)
                else
                    retVal = _S.linearInterpolate(_S.getConfig(path, dof, li), _S.getConfig(path, dof, hi), t, types)
                end
            end
        else
            if hi == confCnt and not closed then
                retVal = _S.linearInterpolate(_S.getConfig(path, dof, li), _S.getConfig(path, dof, hi), t, types)
            else
                if t > (1 - 0.5 * w) then
                    i0 = li
                    i1 = hi
                    i2 = hi + 1
                    if hi == confCnt then i2 = 2 end
                    t = t - (1 - 0.5 * w)
                    local a = _S.linearInterpolate(_S.getConfig(path, dof, i0), _S.getConfig(path, dof, i1), 1 - 0.5 * w + t * 0.5, types)
                    local b = _S.linearInterpolate(_S.getConfig(path, dof, i1), _S.getConfig(path, dof, i2), t * 0.5, types)
                    retVal = _S.linearInterpolate(a, b, t / w, types)
                else
                    retVal = _S.linearInterpolate(_S.getConfig(path, dof, li), _S.getConfig(path, dof, hi), t, types)
                end
            end
        end
    end
    if not method or method.type == 'linear' then
        retVal = _S.linearInterpolate(_S.getConfig(path, dof, li), _S.getConfig(path, dof, hi), t, types)
    end
    return retVal
end

function sim.createPath(...)
    local retVal
    local attrib, intParams, floatParams, col = ...
    if type(attrib) == 'number' then
        retVal = sim._createPath(attrib, intParams, floatParams, col) -- for backward compatibility
    else
        local ctrlPts, options, subdiv, smoothness, orientationMode, upVector = checkargs({
            {type = 'table', item_type = 'float', size = '14..*'},
            {type = 'int', default = 0},
            {type = 'int', default = 100},
            {type = 'float', default = 1.0},
            {type = 'int', default = 0},
            {type = 'table', item_type = 'float', size = '3', default = {0, 0, 1}},
        }, ...)
        local fl = setYieldAllowed(false)
        retVal = sim.createDummy(0.04, {0, 0.68, 0.47, 0, 0, 0, 0, 0, 0, 0, 0, 0})
        sim.setObjectAlias(retVal, "Path")
        local scriptHandle = sim.addScript(sim.scripttype_customizationscript)
        local code = [[path=require('path_customization')

function path.shaping(path,pathIsClosed,upVector)
    local section={0.02,-0.02,0.02,0.02,-0.02,0.02,-0.02,-0.02,0.02,-0.02}
    local color={0.7,0.9,0.9}
    local options=0
    if pathIsClosed then
        options=options|4
    end
    local shape=sim.generateShapeFromPath(path,section,options,upVector)
    sim.setShapeColor(shape,nil,sim.colorcomponent_ambient_diffuse,color)
    return shape
end]]
        sim.setScriptText(scriptHandle, code)
        sim.associateScriptWithObject(scriptHandle, retVal)
        local prop = sim.getModelProperty(retVal)
        sim.setModelProperty(retVal, (prop | sim.modelproperty_not_model) - sim.modelproperty_not_model) -- model
        prop = sim.getObjectProperty(retVal)
        sim.setObjectProperty(retVal, prop | sim.objectproperty_canupdatedna | sim.objectproperty_collapsed)
        local data = sim.packTable({ctrlPts, options, subdiv, smoothness, orientationMode, upVector})
        sim.writeCustomDataBlock(retVal, "ABC_PATH_CREATION", data)
        sim.initScript(scriptHandle)
        setYieldAllowed(fl)
    end
    return retVal
end

function sim.createCollection(arg1, arg2)
    local retVal
    if type(arg1) == 'string' then
        retVal = sim._createCollection(arg1, arg2) -- for backward compatibility
    else
        if arg1 == nil then arg1 = 0 end
        retVal = sim.createCollectionEx(arg1)
    end
    return retVal
end

function sim.resamplePath(...)
    local path, pathLengths, finalConfigCnt, method, types = checkargs({
        {type = 'table', item_type = 'float', size = '2..*'},
        {type = 'table', item_type = 'float', size = '2..*'},
        {type = 'int'},
        {type = 'table', default = {type = 'linear', strength = 1.0, forceOpen = false}},
        {type = 'table', item_type = 'int', size = '1..*', default = NIL, nullable = true},
    }, ...)

    local confCnt = #pathLengths
    local dof = math.floor(#path / confCnt)

    if dof * confCnt ~= #path or (confCnt < 2) or (types and dof ~= #types) then
        error("Bad table size.")
    end

    local retVal = {}
    for i = 1, finalConfigCnt, 1 do
        local c = sim.getPathInterpolatedConfig(
                      path, pathLengths, pathLengths[#pathLengths] * (i - 1) / (finalConfigCnt - 1),
                      method, types
                  )
        for j = 1, dof, 1 do retVal[(i - 1) * dof + j] = c[j] end
    end
    return retVal
end

function sim.getConfigDistance(...)
    local confA, confB, metric, types = checkargs({
        {type = 'table', item_type = 'float', size = '1..*'},
        {type = 'table', item_type = 'float', size = '1..*'},
        {type = 'table', item_type = 'float', default = NIL, nullable = true},
        {type = 'table', item_type = 'int', default = NIL, nullable = true},
    }, ...)

    if (#confA ~= #confB) or (metric and #confA ~= #metric) or (types and #confA ~= #types) then
        error("Bad table size.")
    end
    return _S.getConfigDistance(confA, confB, metric, types)
end

function _S.getConfigDistance(confA, confB, metric, types)
    if metric == nil then
        metric = {}
        for i = 1, #confA, 1 do metric[i] = 1 end
    end
    if types == nil then
        types = {}
        for i = 1, #confA, 1 do types[i] = 0 end
    end

    local d = 0
    local qcnt = 0
    for j = 1, #confA, 1 do
        local dd = 0
        if types[j] == 0 then
            dd = (confB[j] - confA[j]) * metric[j] -- e.g. joint with limits
        end
        if types[j] == 1 then
            local dx = math.atan2(math.sin(confB[j] - confA[j]), math.cos(confB[j] - confA[j]))
            local v = confA[j] + dx
            dd = math.atan2(math.sin(v), math.cos(v)) * metric[j] -- cyclic rev. joint (-pi;pi)
        end
        if types[j] == 2 then
            qcnt = qcnt + 1
            if qcnt == 4 then
                qcnt = 0
                local m1 = sim.buildMatrixQ({0, 0, 0}, {confA[j - 3], confA[j - 2], confA[j - 1], confA[j - 0]})
                local m2 = sim.buildMatrixQ({0, 0, 0}, {confB[j - 3], confB[j - 2], confB[j - 1], confB[j - 0]})
                local a, angle = sim.getRotationAxis(m1, m2)
                dd = angle * metric[j - 3]
            end
        end
        d = d + dd * dd
    end
    return math.sqrt(d)
end

function sim.getPathLengths(...)
    local path, dof, cb = checkargs({
        {type = 'table', item_type = 'float', size = '2..*'}, {type = 'int'},
        {type = 'any', default = NIL, nullable = true},
    }, ...)
    local confCnt = math.floor(#path / dof)
    if dof < 1 or (confCnt < 2) then error("Bad table size.") end
    local distancesAlongPath = {0}
    local totDist = 0
    local pM = Matrix(confCnt, dof, path)
    local metric = {}
    local tt = {}
    for i = 1, dof, 1 do
        if i > 3 then
            metric[#metric + 1] = 0.0
        else
            metric[#metric + 1] = 1.0
        end
        tt[#tt + 1] = 0
    end
    for i = 1, pM:rows() - 1, 1 do
        local d
        if cb then
            if type(cb) == 'string' then
                d = _G[cb](pM[i]:data(), pM[i + 1]:data(), dof)
            else
                d = cb(pM[i]:data(), pM[i + 1]:data(), dof)
            end
        else
            d = sim.getConfigDistance(pM[i]:data(), pM[i + 1]:data(), metric, tt)
        end
        totDist = totDist + d
        distancesAlongPath[i + 1] = totDist
    end
    return distancesAlongPath, totDist
end

function sim.changeEntityColor(...)
    local entityHandle, color, colorComponent = checkargs({
        {type = 'int'},
        {type = 'table', size = 3, item_type = 'float'},
        {type = 'int', default = sim.colorcomponent_ambient_diffuse},
    }, ...)
    local colorData = {}
    local objs = {entityHandle}
    if sim.isHandle(entityHandle, sim.appobj_collection_type) then
        objs = sim.getCollectionObjects(entityHandle)
    end
    for i = 1, #objs, 1 do
        if sim.getObjectType(objs[i]) == sim.object_shape_type then
            local visible = sim.getObjectInt32Param(objs[i], sim.objintparam_visible)
            if visible == 1 then
                local res, col = sim.getShapeColor(objs[i], '@compound', colorComponent)
                colorData[#colorData + 1] = {handle = objs[i], data = col, comp = colorComponent}
                sim.setShapeColor(objs[i], nil, colorComponent, color)
            end
        end
    end
    return colorData
end

function sim.restoreEntityColor(...)
    local colorData = checkargs({{type = 'table'}, size = '1..*'}, ...)
    for i = 1, #colorData, 1 do
        if sim.isHandle(colorData[i].handle, sim.appobj_object_type) then
            sim.setShapeColor(colorData[i].handle, '@compound', colorData[i].comp, colorData[i].data)
        end
    end
end

function sim.wait(...)
    local dt, simTime = checkargs({{type = 'float'}, {type = 'bool', default = true}}, ...)

    local retVal = 0
    if simTime then
        local st = sim.getSimulationTime()
        while sim.getSimulationTime() - st < dt do sim.step() end
        retVal = sim.getSimulationTime() - st - dt
    else
        local st = sim.getSystemTime()
        while sim.getSystemTime() - st < dt do sim.step() end
    end
    return retVal
end

function sim.waitForSignal(...)
    local sigName = checkargs({{type = 'string'}}, ...)
    local retVal
    while true do
        retVal = sim.getInt32Signal(sigName) or sim.getFloatSignal(sigName) or
                     sim.getDoubleSignal(sigName) or sim.getStringSignal(sigName)
        if retVal then break end
        sim.step()
    end
    return retVal
end

function sim.serialRead(...)
    local portHandle, length, blocking, closingStr, timeout = checkargs({
        {type = 'int'},
        {type = 'int'},
        {type = 'bool', default = false},
        {type = 'string', default = ''},
        {type = 'float', default = 0},
    }, ...)

    local retVal
    if blocking then
        local st = sim.getSystemTime()
        while true do
            local data = _S.serialPortData[portHandle]
            _S.serialPortData[portHandle] = ''
            if #data < length then
                local d = sim._serialRead(portHandle, length - #data)
                if d then data = data .. d end
            end
            if #data >= length then
                retVal = string.sub(data, 1, length)
                if #data > length then
                    data = string.sub(data, length + 1)
                    _S.serialPortData[portHandle] = data
                end
                break
            end
            if closingStr ~= '' then
                local s, e = string.find(data, closingStr, 1, true)
                if e then
                    retVal = string.sub(data, 1, e)
                    if #data > e then
                        data = string.sub(data, e + 1)
                        _S.serialPortData[portHandle] = data
                    end
                    break
                end
            end
            if sim.getSystemTime() - st >= timeout and timeout ~= 0 then
                retVal = data
                break
            end
            sim.step()
            _S.serialPortData[portHandle] = data
        end
    else
        local data = _S.serialPortData[portHandle]
        _S.serialPortData[portHandle] = ''
        if #data < length then
            local d = sim._serialRead(portHandle, length - #data)
            if d then data = data .. d end
        end
        if #data > length then
            retVal = string.sub(data, 1, length)
            data = string.sub(data, length + 1)
            _S.serialPortData[portHandle] = data
        else
            retVal = data
        end
    end
    return retVal
end

function sim.serialOpen(...)
    local portString, baudRate = checkargs({{type = 'string'}, {type = 'int'}}, ...)

    local retVal = sim._serialOpen(portString, baudRate)
    if not _S.serialPortData then _S.serialPortData = {} end
    _S.serialPortData[retVal] = ''
    return retVal
end

function sim.serialClose(...)
    local portHandle = checkargs({{type = 'int'}}, ...)

    sim._serialClose(portHandle)
    if _S.serialPortData then _S.serialPortData[portHandle] = nil end
end

function sim.getShapeBB(handle)
    local s = {}
    local m = sim.getObjectFloatParam(handle, sim.objfloatparam_objbbox_max_x)
    local n = sim.getObjectFloatParam(handle, sim.objfloatparam_objbbox_min_x)
    s[1] = m - n
    local m = sim.getObjectFloatParam(handle, sim.objfloatparam_objbbox_max_y)
    local n = sim.getObjectFloatParam(handle, sim.objfloatparam_objbbox_min_y)
    s[2] = m - n
    local m = sim.getObjectFloatParam(handle, sim.objfloatparam_objbbox_max_z)
    local n = sim.getObjectFloatParam(handle, sim.objfloatparam_objbbox_min_z)
    s[3] = m - n
    return s
end

function sim.setShapeBB(handle, size)
    local s = sim.getShapeBB(handle)
    for i = 1, 3, 1 do if math.abs(s[i]) > 0.00001 then s[i] = size[i] / s[i] end end
    sim.scaleObject(handle, s[1], s[2], s[3], 0)
end

function sim.getModelBB(handle)
    -- Undocumented function (for now)
    local s = {}
    local m = sim.getObjectFloatParam(handle, sim.objfloatparam_modelbbox_max_x)
    local n = sim.getObjectFloatParam(handle, sim.objfloatparam_modelbbox_min_x)
    s[1] = m - n
    local m = sim.getObjectFloatParam(handle, sim.objfloatparam_modelbbox_max_y)
    local n = sim.getObjectFloatParam(handle, sim.objfloatparam_modelbbox_min_y)
    s[2] = m - n
    local m = sim.getObjectFloatParam(handle, sim.objfloatparam_modelbbox_max_z)
    local n = sim.getObjectFloatParam(handle, sim.objfloatparam_modelbbox_min_z)
    s[3] = m - n
    return s
end

function sim.readCustomDataBlockEx(handle, tag, options)
    -- Undocumented function (for now)
    options = options or {}
    local data = sim.readCustomDataBlock(handle, tag)
    if tag == '__info__' then
        return data, 'cbor'
    else
        local info = sim.readCustomTableData(handle, '__info__')
        local tagInfo = info.blocks and info.blocks[tag] or {}
        local dataType = tagInfo.type or options.dataType
        return data, dataType
    end
end

function sim.writeCustomDataBlockEx(handle, tag, data, options)
    -- Undocumented function (for now)
    options = options or {}
    sim.writeCustomDataBlock(handle, tag, data)
    if tag ~= '__info__' and options.dataType then
        local info = sim.readCustomTableData(handle, '__info__')
        info.blocks = info.blocks or {}
        info.blocks[tag] = info.blocks[tag] or {}
        info.blocks[tag].type = options.dataType
        sim.writeCustomTableData(handle, '__info__', info, {dataType = 'cbor'})
    end
end

function sim.readCustomTableData(...)
    local handle, tagName, options = checkargs({
        {type = 'int'},
        {type = 'string'},
        {type = 'table', default = {}},
    }, ...)
    local data, dataType = sim.readCustomDataBlockEx(handle, tagName)
    if data == nil or #data == 0 then
        data = {}
    else
        if isbuffer(data) then
            data = data.__buff__
        end
        if dataType == 'cbor' then
            local cbor = require 'org.conman.cbor'
            local data0 = data
            data = cbor.decode(data0)
            if type(data) ~= 'table' and tagName == '__info__' then
                -- backward compat: old __info__ blocks were encoded with sim.packTable
                data = sim.unpackTable(data0)
            end
        else
            data = sim.unpackTable(data)
        end
    end
    return data
end

function sim.writeCustomTableData(...)
    local handle, tagName, theTable, options = checkargs({
        {type = 'int'},
        {type = 'string'},
        {type = 'table'},
        {type = 'table', default = {}},
    }, ...)
    if next(theTable) == nil then
        sim.writeCustomDataBlockEx(handle, tagName, '', options)
    else
        if options.dataType == 'cbor' then
            local cbor = require 'org.conman.cbor'
            theTable = cbor.encode(theTable)
        else
            options.dataType = options.dataType or 'table'
            theTable = sim.packTable(theTable)
        end
        sim.writeCustomDataBlockEx(handle, tagName, theTable, options)
    end
end

function sim.getObject(path, options)
    options = options or {}
    local proxy = -1
    local index = -1
    local option = 0
    if options.proxy then proxy = options.proxy end
    if options.index then index = options.index end
    if options.noError then option = 1 end
    return sim._getObject(path, index, proxy, option)
end

function sim.getObjectFromUid(path, options)
    options = options or {}
    local option = 0
    if options.noError then option = 1 end
    return sim._getObjectFromUid(path, option)
end

function sim.getObjectHandle(path, options)
    options = options or {}
    local proxy = -1
    local index = -1
    local option = 0
    if options.proxy then proxy = options.proxy end
    if options.index then index = options.index end
    if options.noError then option = 1 end
    local h = sim._getObjectHandle(path, index, proxy, option)
    local c = string.sub(path, 1, 1)
    if c ~= '.' and c ~= ':' and c ~= '/' and _S.getObjectHandleWarning == nil then
        _S.getObjectHandleWarning = true
        sim.addLog(sim.verbosity_scriptwarnings, "sim.getObjectHandle is deprecated. Use sim.getObject instead.")
    end
    return h
end

function sim.getObjectAliasRelative(handle, baseHandle, aliasOptions, options)
    if handle == baseHandle then return '.' end

    aliasOptions = aliasOptions or -1
    options = options or {}

    local function getPath(h, parent)
        parent = parent or -1
        local tmp = h
        local path = {}
        while tmp ~= parent do
            if tmp == -1 then return end
            table.insert(path, 1, tmp)
            tmp = sim.getObjectParent(tmp)
        end
        return path
    end

    local path = getPath(handle)
    local basePath = getPath(baseHandle)

    local commonAncestor = -1
    local commonAncestorModel = -1
    for i = 1, math.min(#path, #basePath) do
        if path[i] == basePath[i] then
            commonAncestor = path[i]
            if sim.getModelProperty(path[i]) & sim.modelproperty_not_model == 0 then
                commonAncestorModel = path[i]
            end
        else
            break
        end
    end

    local function isAncestor(a, h)
        -- true iff. h is a (grand-)child of a
        if a == h then return true end
        local tmp = h
        while tmp ~= -1 do
            tmp = sim.getObjectParent(tmp)
            if tmp == a then return true end
        end
        return false
    end

    if commonAncestor == -1 then
        return sim.getObjectAlias(handle, aliasOptions)
    elseif commonAncestor == baseHandle then
        -- simple case: handle is a (grand-)child of baseHandle
        local p = getPath(handle, baseHandle)
        p = filter(
                function(h)
                return sim.getModelProperty(h) & sim.modelproperty_not_model == 0 or h == p[#p]
            end, p
            )
        return (options.noDot and '' or './') .. table.join(map(sim.getObjectAlias, p), '/')
    elseif commonAncestor == handle then
        -- reverse case: go upwards in the hierarchy
        for col = 1, 0, -1 do
            for up = 0, 30 do
                for colcol = 0, 30 do
                    local p = {}
                    for _ = 1, col do table.insert(p, ':') end
                    for _ = 1, colcol do table.insert(p, '::') end
                    for _ = 1, up do table.insert(p, '..') end
                    p = table.join(p, '/')
                    if sim.getObject(p, {proxy = baseHandle, noError = true}) == handle then
                        return p
                    end
                end
            end
        end
    else
        local p_bh_cam = sim.getObjectAliasRelative(commonAncestorModel, baseHandle, aliasOptions)
        local p_cam_h = sim.getObjectAliasRelative(
                            handle, commonAncestorModel, aliasOptions, {noDot = true}
                        )
        if commonAncestorModel ~= -1 and p_bh_cam and p_cam_h then
            return p_bh_cam .. '/' .. p_cam_h
        end
        local p_bh_ca = sim.getObjectAliasRelative(commonAncestor, baseHandle, aliasOptions)
        local p_ca_h = sim.getObjectAliasRelative(
                           handle, commonAncestor, aliasOptions, {noDot = true}
                       )
        if p_bh_ca and p_ca_h then return p_bh_ca .. '/' .. p_ca_h end
    end
end

function sim.generateTextShape(...)
    local txt, color, height, centered, alphabetModel = checkargs({
        {type = 'string'},
        {type = 'table', item_type = 'float', size = 3, default = NIL, nullable = true},
        {type = 'float', default = NIL, nullable = true},
        {type = 'bool', default = NIL, nullable = true},
        {type = 'string', default = NIL, nullable = true},
    }, ...)
    local textUtils = require('textUtils')
    return textUtils.generateTextShape(txt, color, height, centered, alphabetModel)
end

function sim.getSimulationStopping()
    local s = sim.getSimulationState()
    return s == sim.simulation_stopped or s == sim.simulation_advancing_abouttostop or s ==
               sim.simulation_advancing_lastbeforestop
end

sim.getThreadExistRequest = sim.getSimulationStopping

function sim.getNamedBoolParam(...)
    local name = checkargs({{type = 'string'}}, ...)
    local r, v = pcall(_S.parseBool, sim.getNamedStringParam(name))
    if r then return v end
end

function sim.getNamedFloatParam(...)
    local name = checkargs({{type = 'string'}}, ...)
    local r, v = pcall(_S.parseFloat, sim.getNamedStringParam(name))
    if r then return v end
end

function sim.getNamedInt32Param(...)
    local name = checkargs({{type = 'string'}}, ...)
    local r, v = pcall(_S.parseInt, sim.getNamedStringParam(name))
    if r then return v end
end

function sim.setNamedBoolParam(...)
    local name, value = checkargs({{type = 'string'}, {type = 'bool'}}, ...)
    return sim.setNamedStringParam(name, _S.paramValueToString(value))
end

function sim.setNamedFloatParam(...)
    local name, value = checkargs({{type = 'string'}, {type = 'float'}}, ...)
    return sim.setNamedStringParam(name, _S.paramValueToString(value))
end

function sim.setNamedInt32Param(...)
    local name, value = checkargs({{type = 'string'}, {type = 'int'}}, ...)
    return sim.setNamedStringParam(name, _S.paramValueToString(value))
end

sim.getStringNamedParam = sim.getNamedStringParam
sim.setStringNamedParam = sim.setNamedStringParam

function sim.getSettingString(...)
    local key = checkargs({{type = 'string'}}, ...)
    local r = sim.getNamedStringParam(key)
    if r then return r end
    _S.systemSettings = _S.systemSettings or _S.readSystemSettings() or {}
    _S.userSettings = _S.userSettings or _S.readUserSettings() or {}
    return _S.userSettings[key] or _S.systemSettings[key]
end

function sim.getSettingBool(...)
    local key = checkargs({{type = 'string'}}, ...)
    return _S.parseBool(sim.getSettingString(key))
end

function sim.getSettingFloat(...)
    local key = checkargs({{type = 'string'}}, ...)
    return _S.parseFloat(sim.getSettingString(key))
end

function sim.getSettingInt32(...)
    local key = checkargs({{type = 'string'}}, ...)
    return _S.parseInt(sim.getSettingString(key))
end

function sim.getScriptFunctions(...)
    local args = {...}
    if type(args[1]) == 'string' then
        assert(#args <= 2, 'too many args')
        args[1] = sim.getObject(args[1])
    end
    if pcall(sim.getObjectType, args[1]) then
        assert(#args <= 2, 'too many args')
        args[1] = sim.getScript(args[2] or sim.scripttype_customizationscript, args[1])
        args[2] = nil
    end
    local scriptHandle = args[1]
    assert(#args >= 1, 'not enough args')
    assert(#args <= 1, 'too many args')
    assert(scriptHandle and pcall(sim.getScriptName, scriptHandle), 'invalid script handle')
    return setmetatable({}, {
        __index = function(self, k)
            return function(self_, ...)
                assert(self_ == self, 'methods must be called with object:method(args...)')
                return sim.callScriptFunction(k, scriptHandle, ...)
            end
        end,
    })
end

function sim.addReferencedHandle(objectHandle, referencedHandle, options)
    options = options or {}
    local refHandles = sim.getReferencedHandles(objectHandle)
    local handlesToAdd = {referencedHandle}
    if options.wholeTree then
        handlesToAdd = sim.getObjectsInTree(referencedHandle)
    end
    for _, handle in ipairs(handlesToAdd) do
        table.insert(refHandles, handle)
    end
    sim.setReferencedHandles(objectHandle, refHandles)
end

function sim.removeReferencedObjects(objectHandle)
    local refHandles = sim.getReferencedHandles(objectHandle)
    -- remove models with sim.removeModel, the rest with sim.removeObjects:
    for _, h in ipairs(refHandles) do
        if sim.isHandle(h) then
            if sim.getModelProperty(h) & sim.modelproperty_not_model == 0 then
                sim.removeModel(h)
            end
        end
    end
    sim.removeObjects(refHandles)
    sim.setReferencedHandles(objectHandle, {})
end

function sim.visitTree(...)
    -- deprecated.
    local rootHandle, visitorFunc, options = checkargs({
        {type = 'int'},
        {type = 'func'},
        {type = 'table', default = {}},
    }, ...)

    if visitorFunc(rootHandle) == false then return end
    local i = 0
    while true do
        local childHandle = sim.getObjectChild(rootHandle, i)
        if childHandle == -1 then return end
        sim.visitTree(childHandle, visitorFunc)
        i = i + 1
    end
end

function apropos(what)
    local modNames = {'sim'}
    for i, n in ipairs(sim.getLoadedPlugins()) do
        n = 'sim' .. n
        if type(_G[n]) == 'table' then table.insert(modNames, n) end
    end
    local results = {}
    for i, n in ipairs(modNames) do
        for k, v in pairs(_G[n]) do
            if k:lower():match(what) then
                local s = n .. '.' .. k
                local info = s
                if type(v) == 'function' then
                    info = s .. '(...)'
                    local i = sim.getApiInfo(-1, s)
                    if i and i ~= '' then info = (string.split(i, '\n'))[1] end
                end
                table.insert(results, {s, info})
            end
        end
    end
    table.sort(
        results, function(a, b)
            return a[1] < b[1]
        end
    )
    local s = ''
    for i, result in ipairs(results) do s = s .. (s == '' and '' or '\n') .. result[2] end
    print(s)
end

-- Hidden, internal functions:
----------------------------------------------------------

function _S.readSettings(path)
    local f = io.open(path, 'r')
    if f == nil then return nil end
    local cfg = {}
    for line in f:lines() do
        line = line:gsub('//.*$', '')
        key, value = line:match('^(%S+)%s*=%s*(.*%S)%s*$')
        if key then cfg[key] = value end
    end
    return cfg
end

function _S.readSystemSettings()
    local sysDir = sim.getStringParam(sim.stringparam_systemdir)
    local psep = package.config:sub(1, 1)
    local usrSet = sysDir .. psep .. 'usrset.txt'
    return _S.readSettings(usrSet)
end

function _S.readUserSettings()
    local plat = sim.getInt32Param(sim.intparam_platform)
    local psep = package.config:sub(1, 1)
    local usrSet = 'CoppeliaSim' .. psep .. 'usrset.txt'
    local home = os.getenv('HOME')
    if plat == 0 then -- windows
        local appdata = os.getenv('appdata')
        return _S.readSettings(appdata .. psep .. usrSet)
    elseif plat == 1 then -- macos
        return _S.readSettings(home .. psep .. '.' .. usrSet) or
                   _S.readSettings(
                       home .. psep .. 'Library' .. psep .. 'Preferences' .. psep .. usrSet
                   )
    elseif plat == 2 then -- linux
        local xdghome = os.getenv('XDG_CONFIG_HOME') or home
        return _S.readSettings(xdghome .. psep .. usrSet) or
                   _S.readSettings(home .. psep .. '.' .. usrSet)
    else
        error('unsupported platform: ' .. plat)
    end
end

function _S.parseBool(v)
    if v == nil then return nil end
    if isbuffer(v) then
        v = v.__buff__
    end
    if v == 'true' then return true end
    if v == 'false' then return false end
    if v == 'on' then return true end
    if v == 'off' then return false end
    if v == '1' then return true end
    if v == '0' then return false end
    error('bool value expected')
end

function _S.parseFloat(v)
    if v == nil then return nil end
    return tonumber(v)
end

function _S.parseInt(v)
    if v == nil then return nil end
    v = tonumber(v)
    if math.type(v) == 'integer' then return v end
    error('integer value expected')
end

function _S.paramValueToString(v)
    if v == nil then return '' end
    return tostring(v)
end

function _S.linearInterpolate(conf1, conf2, t, types)
    local retVal = {}
    local qcnt = 0
    for i = 1, #conf1, 1 do
        if types[i] == 0 then
            retVal[i] = conf1[i] * (1 - t) + conf2[i] * t -- e.g. joint with limits
        end
        if types[i] == 1 then
            local dx = math.atan2(math.sin(conf2[i] - conf1[i]), math.cos(conf2[i] - conf1[i]))
            local v = conf1[i] + dx * t
            retVal[i] = math.atan2(math.sin(v), math.cos(v)) -- cyclic rev. joint (-pi;pi)
        end
        if types[i] == 2 then
            qcnt = qcnt + 1
            if qcnt == 4 then
                qcnt = 0
                local m1 = sim.buildMatrixQ(
                               {0, 0, 0}, {conf1[i - 3], conf1[i - 2], conf1[i - 1], conf1[i - 0]}
                           )
                local m2 = sim.buildMatrixQ(
                               {0, 0, 0}, {conf2[i - 3], conf2[i - 2], conf2[i - 1], conf2[i - 0]}
                           )
                local m = sim.interpolateMatrices(m1, m2, t)
                local q = sim.getQuaternionFromMatrix(m)
                retVal[i - 3] = q[1]
                retVal[i - 2] = q[2]
                retVal[i - 1] = q[3]
                retVal[i - 0] = q[4]
            end
        end
    end
    return retVal
end

function _S.getConfig(path, dof, index)
    local retVal = {}
    for i = 1, dof, 1 do retVal[#retVal + 1] = path[(index - 1) * dof + i] end
    return retVal
end

function _S.loopThroughAltConfigSolutions(jointHandles, desiredPose, confS, x, index, tipHandle)
    if index > #jointHandles then
        if tipHandle == -1 then
            return {table.deepcopy(confS)}
        else
            for i = 1, #jointHandles, 1 do
                sim.setJointPosition(jointHandles[i], confS[i])
            end
            local p = sim.getObjectMatrix(tipHandle)
            local axis, angle = sim.getRotationAxis(desiredPose, p)
            if math.abs(angle) < 0.1 * 180 / math.pi then -- checking is needed in case some joints are dependent on others
                return {table.deepcopy(confS)}
            else
                return {}
            end
        end
    else
        local c = {}
        for i = 1, #jointHandles, 1 do c[i] = confS[i] end
        local solutions = {}
        while c[index] <= x[index][2] do
            local s = _S.loopThroughAltConfigSolutions(
                          jointHandles, desiredPose, c, x, index + 1, tipHandle
                      )
            for i = 1, #s, 1 do solutions[#solutions + 1] = s[i] end
            c[index] = c[index] + math.pi * 2
        end
        return solutions
    end
end

function _S.comparableTables(t1, t2)
    return (isArray(t1) == isArray(t2)) or (isArray(t1) and #t1 == 0) or (isArray(t2) and #t2 == 0)
end

function _S.sysCallEx_init()
    -- Hook function, registered further down
    _S.initGlobals = {}
    for key, val in pairs(_G) do _S.initGlobals[key] = true end
    _S.initGlobals._S = nil

    if sysCall_selChange then sysCall_selChange({sel = sim.getObjectSel()}) end
end

----------------------------------------------------------

-- Old stuff, mainly for backward compatibility:
----------------------------------------------------------
function simRMLMoveToJointPositions(...)
    require("sim_old")
    return simRMLMoveToJointPositions(...)
end
function sim.rmlMoveToJointPositions(...)
    require("sim_old")
    return sim.rmlMoveToJointPositions(...)
end
function simRMLMoveToPosition(...)
    require("sim_old")
    return simRMLMoveToPosition(...)
end
function sim.rmlMoveToPosition(...)
    require("sim_old")
    return sim.rmlMoveToPosition(...)
end
function sim.boolOr32(...)
    require("sim_old")
    return sim.boolOr32(...)
end
function sim.boolAnd32(...)
    require("sim_old")
    return sim.boolAnd32(...)
end
function sim.boolXor32(...)
    require("sim_old")
    return sim.boolXor32(...)
end
function sim.boolOr16(...)
    require("sim_old")
    return sim.boolOr16(...)
end
function sim.boolAnd16(...)
    require("sim_old")
    return sim.boolAnd16(...)
end
function sim.boolXor16(...)
    require("sim_old")
    return sim.boolXor16(...)
end
function sim.setSimilarName(...)
    require("sim_old")
    return sim.setSimilarName(...)
end
function sim.tubeRead(...)
    require("sim_old")
    return sim.tubeRead(...)
end
function sim.getObjectHandle_noErrorNoSuffixAdjustment(...)
    require("sim_old")
    return sim.getObjectHandle_noErrorNoSuffixAdjustment(...)
end
function sim.moveToPosition(...)
    require("sim_old")
    return sim.moveToPosition(...)
end
function sim.moveToJointPositions(...)
    require("sim_old")
    return sim.moveToJointPositions(...)
end
function sim.moveToObject(...)
    require("sim_old")
    return sim.moveToObject(...)
end
function sim.followPath(...)
    require("sim_old")
    return sim.followPath(...)
end
function sim.include(...)
    require("sim_old")
    return sim.include(...)
end
function sim.includeRel(...)
    require("sim_old")
    return sim.includeRel(...)
end
function sim.includeAbs(...)
    require("sim_old")
    return sim.includeAbs(...)
end
function sim.canScaleObjectNonIsometrically(...)
    require("sim_old")
    return sim.canScaleObjectNonIsometrically(...)
end
function sim.canScaleModelNonIsometrically(...)
    require("sim_old")
    return sim.canScaleModelNonIsometrically(...)
end
function sim.scaleModelNonIsometrically(...)
    require("sim_old")
    return sim.scaleModelNonIsometrically(...)
end
function sim.UI_populateCombobox(...)
    require("sim_old")
    return sim.UI_populateCombobox(...)
end
function sim.displayDialog(...)
    require("sim_old")
    return sim.displayDialog(...)
end
function sim.endDialog(...)
    require("sim_old")
    return sim.endDialog(...)
end
function sim.getDialogInput(...)
    require("sim_old")
    return sim.getDialogInput(...)
end
function sim.getDialogResult(...)
    require("sim_old")
    return sim.getDialogResult(...)
end
_S.dlg = {}
function _S.dlg.ok_callback(ui)
    local simUI = require 'simUI'
    local h = _S.dlg.openDlgsUi[ui]
    _S.dlg.allDlgResults[h].state = sim.dlgret_ok
    if _S.dlg.allDlgResults[h].style == sim.dlgstyle_input then
        _S.dlg.allDlgResults[h].input = simUI.getEditValue(ui, 1)
    end
    _S.dlg.removeUi(h)
end
function _S.dlg.cancel_callback(ui)
    local h = _S.dlg.openDlgsUi[ui]
    _S.dlg.allDlgResults[h].state = sim.dlgret_cancel
    _S.dlg.removeUi(h)
end
function _S.dlg.input_callback(ui, id, val)
    local h = _S.dlg.openDlgsUi[ui]
    _S.dlg.allDlgResults[h].input = val
end
function _S.dlg.yes_callback(ui)
    local simUI = require 'simUI'
    local h = _S.dlg.openDlgsUi[ui]
    _S.dlg.allDlgResults[h].state = sim.dlgret_yes
    if _S.dlg.allDlgResults[h].style == sim.dlgstyle_input then
        _S.dlg.allDlgResults[h].input = simUI.getEditValue(ui, 1)
    end
    _S.dlg.removeUi(h)
end
function _S.dlg.no_callback(ui)
    local simUI = require 'simUI'
    local h = _S.dlg.openDlgsUi[ui]
    _S.dlg.allDlgResults[h].state = sim.dlgret_no
    if _S.dlg.allDlgResults[h].style == sim.dlgstyle_input then
        _S.dlg.allDlgResults[h].input = simUI.getEditValue(ui, 1)
    end
    _S.dlg.removeUi(h)
end
function _S.dlg.removeUi(handle)
    local simUI = require 'simUI'
    local ui = _S.dlg.openDlgs[handle]
    simUI.destroy(ui)
    _S.dlg.openDlgsUi[ui] = nil
    _S.dlg.openDlgs[handle] = nil
    if _S.dlg.allDlgResults[handle].state == sim.dlgret_still_open then
        _S.dlg.allDlgResults[handle].state = sim.dlgret_cancel
    end
end
function _S.dlg.switch()
    -- remove all
    if _S.dlg.openDlgsUi then
        local toRem = {}
        for key, val in pairs(_S.dlg.openDlgsUi) do toRem[#toRem + 1] = val end
        for i = 1, #toRem, 1 do _S.dlg.removeUi(toRem[i]) end
        _S.dlg.openDlgsUi = nil
        _S.dlg.openDlgs = nil
    end
end
function _S.sysCallEx_beforeInstanceSwitch()
    -- Hook function, registered further down
    _S.dlg.switch() -- remove all
end
function _S.sysCallEx_addOnScriptSuspend()
    -- Hook function, registered further down
    _S.dlg.switch() -- remove all
end
function _S.sysCallEx_cleanup()
    -- Hook function, registered further down
    _S.dlg.switch() -- remove all
end

sim.unpackTable = wrap(sim.unpackTable, function(origFunc)
    return function(data, scheme)
        if scheme == nil then
            if isbuffer(data) then
                data = data.__buff__
            end
            if #data == 0 then
                return {} -- since 20.03.2024: empty buffer results in an empty table
            else
                if string.byte(data, 1) == 0 or string.byte(data, 1) == 5 then
                    return origFunc(data)
                else
                    local cbor = require 'org.conman.cbor'
                    return cbor.decode(data)
                end
            end
        end
    end
end)

sim.registerScriptFuncHook('sysCall_init', '_S.sysCallEx_init', false) -- hook on *before* init is incompatible with implicit module load...
sim.registerScriptFuncHook('sysCall_cleanup', '_S.sysCallEx_cleanup', false)
sim.registerScriptFuncHook(
    'sysCall_beforeInstanceSwitch', '_S.sysCallEx_beforeInstanceSwitch', false
)
sim.registerScriptFuncHook('sysCall_addOnScriptSuspend', '_S.sysCallEx_addOnScriptSuspend', false)
----------------------------------------------------------

return sim
