-- The is the first versioned sim-namespace
-- The very first API without namespace (e.g. simGetObjectHandle) is only
-- included if 'supportOldApiNotation' is true in 'usrset.txt'

local sim = _S.sim
_S.sim = nil

sim.addLog = addLog
sim.quitSimulator = quitSimulator
sim.registerScriptFuncHook = registerScriptFuncHook

function sim.readCustomBufferData(obj, tag)
    local retVal = sim.readCustomStringData(obj, tag)
    if retVal then
        retVal = tobuffer(retVal)
    end
    return retVal
end

function sim.writeCustomBufferData(obj, tag, data)
    return sim.writeCustomStringData(obj, tag, data)
end

function sim.getBufferSignal(sigName)
    local retVal = sim.getStringSignal(sigName)
    if retVal then
        retVal = tobuffer(retVal)
    end
    return retVal
end

function sim.setBufferSignal(sigName, data)
    sim.setStringSignal(sigName, tostring(data))
end

function sim.clearBufferSignal(sigName)
    sim.clearStringSignal(sigName)
end

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

require('checkargs')
require('motion').extend(sim)
require('deprecated.old').extend(sim)
require('sim-deprecated').extend(sim)

--require('matrix')
--require('grid')
for _, cls in ipairs{'Matrix', 'Vector', 'Vector3', 'Vector4', 'Vector7', 'Matrix3x3', 'Matrix4x4'} do
    _G[cls] = setmetatable({__lazyLoader = true}, {
        __call = function(self, ...)
            sim.addLog(sim.verbosity_warnings, 'module \'matrix\' was implicitly loaded.')
            require('matrix')
            return _G[cls](...)
        end
    })
end

sim.stopSimulation = wrap(sim.stopSimulation, function(origFunc)
    return function(wait)
        origFunc()
        local t = sim.getObjectInt32Param(sim.getScript(sim.handle_self), sim.scriptintparam_type)
        if wait and t ~= sim.scripttype_main and t ~= sim.scripttype_simulation and getYieldAllowed() then
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

function sim.getQuaternionInverse(q)
    return {-q[1], -q[2], -q[3], q[4]}
end

function sim.getObjectsWithTag(tagName, justModels)
    local retObjs = {}
    local objs = sim.getObjectsInTree(sim.handle_scene)
    for i = 1, #objs, 1 do
        if (not justModels) or ((sim.getModelProperty(objs[i]) & sim.modelproperty_not_model) == 0) then
            local dat = sim.readCustomDataTags(objs[i])
            for j = 1, #dat, 1 do
                if dat[j] == tagName then
                    retObjs[#retObjs + 1] = objs[i]
                    break
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
    local data = sim.readCustomStringData(sim.handle_app, '__IDLEFPSSTACKSIZE__')
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
    sim.writeCustomStringData(
        sim.handle_app, '__IDLEFPSSTACKSIZE__', sim.packInt32Table({stage, defaultIdleFps})
    )
end

function sim.getLoadedPlugins()
    local ret = {}
    local index = 0
    while true do
        local moduleName = sim.getPluginName(index)
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
        moduleName = sim.getPluginName(index)
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
    _S.lastExecTime = _S.lastExecTime or {}
    _S.throttleSched = _S.throttleSched or {}

    local h = string.dump(func)
    local now = sim.getSystemTime()

    -- cancel any previous scheduled execution: (see sim.scheduleExecution below)
    if _S.throttleSched[h] then
        sim.cancelScheduledExecution(_S.throttleSched[h])
        _S.throttleSched[h] = nil
    end

    if _S.lastExecTime[h] == nil or _S.lastExecTime[h] + t < now then
        func(...)
        _S.lastExecTime[h] = now
    else
        -- if skipping the call (i.e. because it exceeds target rate)
        -- schedule the last call in the future:
        _S.throttleSched[h] = sim.scheduleExecution(function(...)
            func(...)
            _S.lastExecTime[h] = now
        end, {...}, _S.lastExecTime[h] + t)
    end
end

function _S.schedulerCallback()
    local function fn(t, pq)
        local item = pq:peek()
        if item and item.timePoint <= t then
            item.func(table.unpack(item.args or {}))
            pq:pop()
            fn(t, pq)
        end
    end

    fn(sim.getSystemTime(), _S.scheduler.rtpq)
    if sim.getSimulationState() == sim.simulation_advancing_running then
        fn(sim.getSimulationTime(), _S.scheduler.simpq)
    end

    if _S.scheduler.simpq:isempty() and _S.scheduler.rtpq:isempty() then
        sim.registerScriptFuncHook('sysCall_nonSimulation', _S.schedulerCallback, true)
        sim.registerScriptFuncHook('sysCall_sensing', _S.schedulerCallback, true)
        sim.registerScriptFuncHook('sysCall_suspended', _S.schedulerCallback, true)
        _S.scheduler.hook = false
    end
end

function sim.scheduleExecution(func, args, timePoint, simTime)
    if not _S.scheduler then
        local priorityqueue = require 'priorityqueue'
        _S.scheduler = {
            simpq = priorityqueue(),
            rtpq = priorityqueue(),
            simTime = {},
            nextId = 1,
        }
    end

    local id = _S.scheduler.nextId
    _S.scheduler.nextId = id + 1
    local pq
    if simTime then
        pq = _S.scheduler.simpq
        _S.scheduler.simTime[id] = true
    else
        pq = _S.scheduler.rtpq
    end
    pq:push(timePoint, {
        id = id,
        func = func,
        args = args,
        timePoint = timePoint,
        simTime = simTime,
    })
    if not _S.scheduler.hook then
        sim.registerScriptFuncHook('sysCall_nonSimulation', _S.schedulerCallback, true)
        sim.registerScriptFuncHook('sysCall_sensing', _S.schedulerCallback, true)
        sim.registerScriptFuncHook('sysCall_suspended', _S.schedulerCallback, true)
        _S.scheduler.hook = true
    end
    return id
end

function sim.cancelScheduledExecution(id)
    if not _S.scheduler then return end
    local pq = nil
    if _S.scheduler.simTime[id] then
        _S.scheduler.simTime[id] = nil
        pq = _S.scheduler.simpq
    else
        pq = _S.scheduler.rtpq
    end
    return pq:cancel(function(item) return item.id == id end)
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
        if t == sim.joint_revolute and not c then
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

function sim.copyTable(t)
    return table.deepcopy(t)
end

function sim.closePath(...)
    local path, times = checkargs({
        {type = 'table', item_type = 'float', size = '2..*'},
        {type = 'table', item_type = 'float', size = '2..*'},
    }, ...)

    local confCnt = #times
    local dof = #path // confCnt

    local firstCp = table.slice(path, 1, dof)
    local lastCp = table.slice(path, #path - dof + 1, #path)
    path = table.add(path, firstCp)
    local nl = sim.getPathLengths(table.add(lastCp, firstCp), dof)
    times = table.add(times, {times[#times] + nl[2]})
    confCnt = confCnt + 1
    return path, times
end

function sim.getPathInterpolatedConfig(...)
    local path, times, t, method, types = checkargs({
        {type = 'table', item_type = 'float', size = '2..*'},
        {type = 'table', item_type = 'float', size = '2..*'},
        {type = 'float'},
        {type = 'table', default = {type = 'linear', strength = 1.0, forceOpen = false}, nullable = true},
        {type = 'table', item_type = 'int', size = '1..*', default = NIL, nullable = true},
    }, ...)

    method = method or {}
    local pathType = method.type or 'linear'
    local forceOpen = method.forceOpen == true
    local closed = method.closed == true
    local strength = method.strength or 1.

    -- "forceOpen" can be set if not passing "closed", otherwise it's opposite value
    if method.closed ~= nil then
        forceOpen = not closed
    end

    if closed then
        path, times = sim.closePath(path, times)
    end

    local confCnt = #times
    local dof = #path // confCnt

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
    closed = true -- if path is closed is determined a few lines below
    if pathType == 'quadraticBezier' then
        local w = math.max(0.05, strength)
        for i = 1, dof, 1 do
            if (path[i] ~= path[(confCnt - 1) * dof + i]) then
                closed = false
                break
            end
        end
        if forceOpen then closed = false end
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
    elseif pathType == 'linear' then
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
        local code = [[function path.shaping(path,pathIsClosed,upVector)
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
        
        retVal = sim.createDummy(0.04, {0, 0.68, 0.47, 0, 0, 0, 0, 0, 0, 0, 0, 0})
        sim.setObjectAlias(retVal, "Path")
        local scriptHandle
        if sim.getBoolParam(sim.boolparam_usingscriptobjects) then
            code = "path = require('models.path_customization-2')\n\n" .. code
            scriptHandle = sim.createScript(sim.scripttype_customization, code)
            sim.setObjectParent(scriptHandle, retVal)
        else
            scriptHandle = sim.addScript(sim.scripttype_customization)
            code = "path = require('models.deprecated.path_customization')\n\n" .. code
            sim.setScriptText(scriptHandle, code)
            sim.associateScriptWithObject(scriptHandle, retVal)
        end
        local prop = sim.getModelProperty(retVal)
        sim.setModelProperty(retVal, (prop | sim.modelproperty_not_model) - sim.modelproperty_not_model) -- model
        prop = sim.getObjectProperty(retVal)
        sim.setObjectProperty(retVal, prop | sim.objectproperty_canupdatedna | sim.objectproperty_collapsed)
        local data = sim.packTable({ctrlPts, options, subdiv, smoothness, orientationMode, upVector})
        sim.writeCustomStringData(retVal, "ABC_PATH_CREATION", data)
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

    method = table.deepcopy(method) or {}
    local closed = method.closed == true

    local confCnt = #pathLengths
    local dof = math.floor(#path / confCnt)

    if dof * confCnt ~= #path or (confCnt < 2) or (types and dof ~= #types) then
        error("Bad table size.")
    end

    if closed then
        confCnt = confCnt + 1
        path, pathLengths = sim.closePath(path, pathLengths)
        method.closed = nil
        method.forceOpen = false
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
                local m1 = sim.poseToMatrix({0, 0, 0, confA[j - 3], confA[j - 2], confA[j - 1], confA[j - 0]})
                local m2 = sim.poseToMatrix({0, 0, 0, confB[j - 3], confB[j - 2], confB[j - 1], confB[j - 0]})
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
                d = _G[cb](pM:row(i):data(), pM:row(i + 1):data(), dof)
            else
                d = cb(pM:row(i):data(), pM:row(i + 1):data(), dof)
            end
        else
            d = sim.getConfigDistance(pM:row(i):data(), pM:row(i + 1):data(), metric, tt)
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
    if sim.isHandle(entityHandle, sim.objecttype_collection) then
        objs = sim.getCollectionObjects(entityHandle)
    end
    for i = 1, #objs, 1 do
        if sim.getObjectType(objs[i]) == sim.sceneobject_shape then
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
        if sim.isHandle(colorData[i].handle, sim.objecttype_sceneobject) then
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

function sim.waitForSignal(target, sigName)
    local retVal
    if type(target) == 'number' then
        -- Signals via properties
        while true do
            retVal = sim.getProperty(target, 'signal.' .. sigName, {noError = true})
            if retVal then break end
            sim.step()
        end
    else
        -- Legacy signals
        sigName = target
        while true do
            retVal = sim.getInt32Signal(sigName) or sim.getFloatSignal(sigName) or sim.getStringSignal(sigName)
            if retVal then break end
            sim.step()
        end
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
    local data = sim.readCustomStringData(handle, tag)
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
    sim.writeCustomStringData(handle, tag, data)
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
            data = tostring(data)
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

function sim.getProperty(target, pname, opts)
    local retVal
    local noError = opts and opts.noError
    local ptype, pflags, descr = sim.getPropertyInfo(target, pname, opts)
    if not noError then
        assert(ptype, 'no such property: ' .. pname)
    end
    if ptype then
        local getPropertyFunc = 'get' .. sim.getPropertyTypeString(ptype, true) .. 'Property'
        if not noError then
            assert(sim[getPropertyFunc], 'no such function: sim.' .. getPropertyFunc)
        end
        retVal = sim[getPropertyFunc](target, pname)
    end
    return retVal
end

function sim.setProperty(target, pname, pvalue, ptype)
    if string.startswith(pname, 'customData.') then
        -- custom data properties need type (param `ptype`, can be string
        -- e.g.: 'intvector', or can be int, e.g.: sim.propertytype_intvector)
        -- if not specified, it will be inferred from lua's variable type
        if type(ptype) == 'string' then
            ptype = sim['propertytype_' .. ptype]
            assert(ptype, 'invalid property type string')
        end
        if ptype == nil then
            -- ptype not provided -> guess it
            local ltype = type(pvalue)
            if ltype == 'number' then
                if math.type(pvalue) == 'integer' then
                    ptype = sim.propertytype_int
                else
                    ptype = sim.propertytype_float
                end
            elseif ltype == 'string' then
                ptype = sim.propertytype_string
            elseif ltype == 'boolean' then
                ptype = sim.propertytype_bool
            elseif ltype == 'table' then
                ptype = sim.propertytype_table
            else
                error('unsupported property type: ' .. ltype)
            end
        end
    else
        assert(ptype == nil, 'cannot specify type for static properties')
        ptype = sim.getPropertyInfo(target, pname)
        assert(ptype ~= nil, 'no such property: ' .. pname)
    end
    local setPropertyFunc = 'set' .. sim.getPropertyTypeString(ptype, true) .. 'Property'
    assert(sim[setPropertyFunc], 'no such function: sim.' .. setPropertyFunc)
    return sim[setPropertyFunc](target, pname, pvalue)
end

function sim.getPropertyTypeString(ptype, forGetterSetter)
    if not _S.propertytypeToStringMap then
        _S.propertytypeToStringMap = {}
        for k, v in pairs(sim) do
            local m = string.match(k, 'propertytype_(.*)')
            if m then _S.propertytypeToStringMap[v] = m end
        end
    end
    local ret = _S.propertytypeToStringMap[ptype]
    if forGetterSetter then
        if ret == 'floatarray' then ret = 'floatArray' end
        if ret == 'floatarray2' then ret = 'floatArray2' end
        if ret == 'floatarray3' then ret = 'floatArray3' end
        if ret == 'intarray' then ret = 'intArray' end
        if ret == 'intarray2' then ret = 'intArray2' end
        ret = string.capitalize(ret)
    end
    return ret
end

function sim.convertPropertyValue(value, fromType, toType)
    if fromType == toType then
        return value
    elseif fromType == sim.propertytype_string then
        local fn, err = loadstring('return ' .. value)
        if not fn then return nil, err end
        local ok, val = pcall(fn)
        if ok then return val, nil else return nil, val end
    elseif toType == sim.propertytype_string then
        return _S.anyToString(value)
    end
    error 'unsupported type of conversion'
end

function sim.getProperties(target, opts)
    opts = opts or {}

    local propertiesValues = {}
    for pname, pinfos in pairs(sim.getPropertiesInfos(target, opts)) do
        if pinfos.flags.readable then
            if not opts.skipLarge or not pinfos.flags.large then
                propertiesValues[pname] = sim.getProperty(target, pname)
            end
        end
    end

    return propertiesValues
end

function sim.setProperties(target, props)
    for k, v in pairs(props) do
        sim.setProperty(target, k, v)
    end
end

function sim.getPropertiesInfos(target, opts)
    opts = opts or {}

    local propertiesInfos = {}
    for i = 0, 1e100 do
        local pname, pclass = sim.getPropertyName(target, i)
        if not pname then break end
        local ptype, pflags, descr = sim.getPropertyInfo(target, pname)
        local label = ({sim.getPropertyInfo(target, pname, {shortInfoTxt=true})})[3]
        pflags = {
            value = pflags,
            readable = pflags & 2 == 0,
            writable = pflags & 1 == 0,
            removable = pflags & 4 > 0,
            large = pflags & 256 > 0,
        }
        propertiesInfos[pname] = {
            type = ptype,
            flags = pflags,
            label = label,
            descr = descr,
            class = pclass,
        }
    end

    return propertiesInfos
end

sim.getTableProperty = wrap(sim.getTableProperty, function(origFunc)
    return function(...)
        local handle, tagName, options = checkargs({
            {type = 'int'},
            {type = 'string'},
            {type = 'table', default = {}},
        }, ...)
        local buf = origFunc(handle, tagName, options)
        if buf then
            local table = sim.unpackTable(buf)
            return table
        end
    end
end)

sim.setTableProperty = wrap(sim.setTableProperty, function(origFunc)
    return function(...)
        local handle, tagName, theTable, options = checkargs({
            {type = 'int'},
            {type = 'string'},
            {type = 'table'},
            {type = 'table', default = {}},
        }, ...)
        options.dataType = options.dataType or 'cbor'
        local buf
        if options.dataType == 'cbor' then
            local cbor = require 'org.conman.cbor'
            buf = cbor.encode(theTable)
        else
            buf = sim.packTable(theTable)
        end
        return origFunc(handle, tagName, buf, options)
    end
end)

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
    if c ~= '.' and c ~= ':' and c ~= '/' then
        sim.addLog(sim.verbosity_scriptwarnings | sim.verbosity_once, "sim.getObjectHandle is deprecated. Use sim.getObject instead.")
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

    -- shorthand: first arg can be an object path:
    if type(args[1]) == 'string' then
        assert(#args <= 2, 'too many args')
        args[1] = sim.getObject(args[1])
    end

    -- shorthand: first arg can be any object handle
    -- script will be fetched via sim.getScript, second arg specifies script type
    local scriptHandle
    local ok, objType = pcall(sim.getObjectType, args[1])
    if ok then
        -- args[1] is a object handle (either new script, or other object)
        assert(#args <= 2, 'too many args')
        if objType ~= sim.sceneobject_script then
            scriptHandle = sim.getScript(args[2] or sim.scripttype_customization, args[1])
        else
            scriptHandle = args[1]
        end
        args[2] = nil
    else
        -- args[1] is a old script handle
        scriptHandle = args[1]
        assert(scriptHandle and pcall(sim.getScriptName, scriptHandle), 'invalid script handle')
    end

    -- at this point we have the script handle from every possible overload (scriptHandle)
    return setmetatable({}, {
        __index = function(self, k)
            return function(self_, ...)
                assert(self_ == self, 'methods must be called with object:method(args...)')
                return sim.callScriptFunction(k, scriptHandle, ...)
            end
        end,
    })
end

function sim.getReferencedHandle(...)
    local handles = sim.getReferencedHandles(...)
    assert(#handles > 0, 'no handle found')
    assert(#handles == 1, 'more than one handle found')
    return handles[1]
end

function sim.addReferencedHandle(objectHandle, referencedHandle, tag, options)
    -- backwards compatibility: arg 'tag' was added at a later point
    if type(tag) == 'table' and options == nil then
        options = tag
        tag = ''
    end
    -- .

    tag = tag or ''
    options = options or {}
    local refHandles = sim.getReferencedHandles(objectHandle, tag)
    local handlesToAdd = {referencedHandle}
    if options.wholeTree then
        handlesToAdd = sim.getObjectsInTree(referencedHandle)
    end
    for _, handle in ipairs(handlesToAdd) do
        table.insert(refHandles, handle)
    end
    sim.setReferencedHandles(objectHandle, refHandles, tag)
end

function sim.removeReferencedObjects(objectHandle, tag, delayedRemoval)
    tag = tag or ''
    local refHandles = sim.getReferencedHandles(objectHandle, tag)
    local toRemove = {}
    -- remove models with sim.removeModel, the rest with sim.removeObjects:
    for _, h in ipairs(refHandles) do
        if sim.isHandle(h) then
            if sim.getModelProperty(h) & sim.modelproperty_not_model == 0 then
                sim.removeModel(h, delayedRemoval)
            else
                table.insert(toRemove, h)
            end
        end
    end
    if #toRemove > 0 then
        sim.removeObjects(toRemove, delayedRemoval)
    end
    sim.setReferencedHandles(objectHandle, {}, tag)
end

function sim.visitTree(...)
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

function sim.getShapeAppearance(handle, opts)
    assert(sim.getObjectType(handle) == sim.sceneobject_shape, 'not a shape')
    opts = opts or {}
    local r = {}
    if sim.getObjectInt32Param(handle, sim.shapeintparam_compound) > 0 then
        r.subShapes = {}
        local subShapesCopy = sim.ungroupShape((sim.copyPasteObjects{handle})[1])
        for i, subShape in ipairs(subShapesCopy) do
            r.subShapes[i] = sim.getShapeAppearance(subShape, opts)
        end
        sim.removeObjects(subShapesCopy)
    else
        r.edges = sim.getObjectInt32Param(handle, sim.shapeintparam_edge_visibility)
        r.wireframe = sim.getObjectInt32Param(handle, sim.shapeintparam_wireframe)
        r.visibilityLayer = sim.getObjectInt32Param(handle, sim.objintparam_visibility_layer)
        r.culling = sim.getObjectInt32Param(handle, sim.shapeintparam_culling)
        r.shadingAngle = sim.getObjectFloatParam(handle, sim.shapefloatparam_shading_angle)
        r.color = {}
        _, r.color.ambientDiffuse = sim.getShapeColor(handle, nil, sim.colorcomponent_ambient_diffuse)
        _, r.color.specular = sim.getShapeColor(handle, nil, sim.colorcomponent_specular)
        _, r.color.emission = sim.getShapeColor(handle, nil, sim.colorcomponent_emission)
        _, r.color.transparency = sim.getShapeColor(handle, nil, sim.colorcomponent_transparency)
    end
    return r
end

function sim.setShapeAppearance(handle, savedData, opts)
    assert(sim.getObjectType(handle) == sim.sceneobject_shape, 'not a shape')
    opts = opts or {}
    if sim.getObjectInt32Param(handle, sim.shapeintparam_compound) > 0 then
        -- we need to temporarily detach all its children, then attach them again
        -- otherwise it will mess up poses of dynamic objects
        local tmp = sim.createDummy(0)
        local i = 0
        while true do
            local h = sim.getObjectChild(handle, i)
            if h == -1 then break end
            i = i + 1
            sim.setObjectParent(h, tmp, true)
        end

        local subShapes = sim.ungroupShape(handle)
        for i, subShape in ipairs(subShapes) do
            sim.setShapeAppearance(subShape, (savedData.subShapes or {})[i] or (savedData.subShapes or {})[1] or savedData, opts)
        end
        local newHandle = sim.groupShapes(subShapes)

        -- reattach children
        i = 0
        while true do
            local h = sim.getObjectChild(tmp, i)
            if h == -1 then break end
            i = i + 1
            sim.setObjectParent(h, newHandle, true)
        end
        sim.removeObjects{tmp}

        return newHandle
    else
        savedData = (savedData.subShapes or {})[1] or savedData
        sim.setObjectInt32Param(handle, sim.shapeintparam_edge_visibility, savedData.edges)
        sim.setObjectInt32Param(handle, sim.shapeintparam_wireframe, savedData.wireframe)
        sim.setObjectInt32Param(handle, sim.objintparam_visibility_layer, savedData.visibilityLayer)
        sim.setObjectInt32Param(handle, sim.shapeintparam_culling, savedData.culling)
        sim.setObjectFloatParam(handle, sim.shapefloatparam_shading_angle, savedData.shadingAngle)
        sim.setShapeColor(handle, nil, sim.colorcomponent_ambient_diffuse, savedData.color.ambientDiffuse)
        sim.setShapeColor(handle, nil, sim.colorcomponent_specular, savedData.color.specular)
        sim.setShapeColor(handle, nil, sim.colorcomponent_emission, savedData.color.emission)
        sim.setShapeColor(handle, nil, sim.colorcomponent_transparency, savedData.color.transparency)
        return handle
    end
end

function apropos(what)
    what = what:lower()
    local mods = {sim = sim}
    for i, n in ipairs(sim.getLoadedPlugins()) do
        pcall(function() mods[n] = require(n) end)
    end
    local results = {}
    for n, m in pairs(mods) do
        for k, v in pairs(m) do
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
    table.sort(results, function(a, b) return a[1] < b[1] end)
    local s = ''
    for i, result in ipairs(results) do s = s .. (s == '' and '' or '\n') .. result[2] end
    print(s)
end

-- wrap require() to load embedded scripts' code when called with a script handle, e.g. require(sim.getObject '/foo')
require = wrap(require, function(origRequire)
    return function (...)
        local arg = ({...})[1]
        if math.type(arg) == 'integer' and sim.isHandle(arg) and sim.getObjectType(arg) == sim.sceneobject_script then
            local txt = sim.getObjectStringParam(arg, sim.scriptstringparam_text)
            return loadstring(tostring(txt))()
        end
        return origRequire(...)
    end
end)

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
        v = tostring(v)
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
                local m1 = sim.poseToMatrix({0, 0, 0, conf1[i - 3], conf1[i - 2], conf1[i - 1], conf1[i - 0]})
                local m2 = sim.poseToMatrix({0, 0, 0, conf2[i - 3], conf2[i - 2], conf2[i - 1], conf2[i - 0]})
                local m = sim.interpolateMatrices(m1, m2, t)
                local p = sim.matrixToPose(m)
                retVal[i - 3] = p[4]
                retVal[i - 2] = p[5]
                retVal[i - 1] = p[6]
                retVal[i - 0] = p[7]
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
                data = tostring(data)
            end
            if #data == 0 then
                return {} -- since 20.03.2024: empty buffer results in an empty table
            else
                if string.byte(data, 1) == 0 or string.byte(data, 1) == 5 then
                    return origFunc(data) -- CoppeliaSim's pack format
                elseif ((string.byte(data, 1) >= 128) and (string.byte(data, 1) <= 155)) or ((string.byte(data, 1) >= 159) and (string.byte(data, 1) <= 187)) or (string.byte(data, 1) == 191) then
                    local cbor = require 'org.conman.cbor'
                    local table = cbor.decode(data)
                    return table
                else
                    error('invalid input data.')
                end
            end
        end
    end
end)


sim.registerScriptFuncHook('sysCall_init', '_S.sysCallEx_init', false) -- hook on *before* init is incompatible with implicit module load...
sim.registerScriptFuncHook('sysCall_cleanup', '_S.sysCallEx_cleanup', false)
sim.registerScriptFuncHook('sysCall_beforeInstanceSwitch', '_S.sysCallEx_beforeInstanceSwitch', false)
sim.registerScriptFuncHook('sysCall_addOnScriptSuspend', '_S.sysCallEx_addOnScriptSuspend', false)
----------------------------------------------------------

return sim
