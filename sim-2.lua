local sim = table.clone(_S.internalApi.sim)
sim.version = '2.0'

sim.__ = {}
__2 = {} -- sometimes globals are needed (but __2 only for sim-2)

local simEigen = require'simEigen'

sim.addLog = addLog
sim.quitSimulator = quitSimulator
sim.registerScriptFuncHook = registerScriptFuncHook

sim.callScriptFunction = wrap(sim.callScriptFunction, function(origFunc)
    return function(a, b, ...)
        if type(a) ~= 'number' then
            local tmp = a
            a = b
            b = tmp
        end
        return origFunc(a, b, ...)
    end
end)

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
        local thread, yieldForbidden = coroutine.running()
        if not yieldForbidden then coroutine.yield() end
    end
end

function sim.step(wait)
    -- Convenience function, for a more intuitive name, depending on the context
    -- Needs to be overridden by Python wrapper and remote API server code
    sim.yield()
end

local checkargs = require('checkargs')
require('motion-2').extend(sim)

sim.stopSimulation = wrap(sim.stopSimulation, function(origFunc)
    return function(wait)
        origFunc()
        local t = sim.getIntProperty(sim.getScript(sim.handle_self), 'scriptType')
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
function sim.__.registerScriptFuncHook(funcNm, func, before)
    local retVal
    if type(func) == 'string' then
        retVal = sim.__.registerScriptFuncHookOrig(funcNm, func, before)
    else
        local str = tostring(func)
        retVal = sim.__.registerScriptFuncHookOrig(funcNm, '__2.' .. str, before)
        __2[str] = func
    end
    return retVal
end
sim.__.registerScriptFuncHookOrig = sim.registerScriptFuncHook
sim.registerScriptFuncHook = sim.__.registerScriptFuncHook

function sim.yprToAbg(...)
    local anglesIn = checkargs({
        {type = 'table', item_type = 'float', size = '3'}
    }, ...)

    local lb = sim.setStepping(true)
    local Rx = sim.buildMatrix({0, 0, 0}, {anglesIn[3], 0, 0})
    local Ry = sim.buildMatrix({0, 0, 0}, {0, anglesIn[2], 0})
    local Rz = sim.buildMatrix({0, 0, 0}, {0, 0, anglesIn[1]})
    local m = sim.multiplyMatrices(Ry, Rx)
    m = sim.multiplyMatrices(Rz, m)
    local alphaBetaGamma = sim.getEulerAnglesFromMatrix(m)
    local alpha = alphaBetaGamma[1]
    local beta = alphaBetaGamma[2]
    local gamma = alphaBetaGamma[3]
    sim.setStepping(lb)
    return {alpha, beta, gamma}
end

function sim.abgToYpr(...)
    local anglesIn = checkargs({
        {type = 'table', item_type = 'float', size = '3'}
    }, ...)

    local lb = sim.setStepping(true)
    local m = sim.buildMatrix({0, 0, 0}, {anglesIn[1], anglesIn[2], anglesIn[3]})
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
    return {yawAngle, pitchAngle, rollAngle}
end

function sim.getQuaternionInverse(q)
    return {-q[1], -q[2], -q[3], q[4]}
end

function sim.fastIdleLoop(enable)
    local data = sim.getBufferProperty(sim.handle_app, 'signal.__IDLEFPSSTACKSIZE__', {noError = true}) -- sim-1 uses buffers too, stay compatible!
    local stage = 0
    local defaultIdleFps
    if data and #data > 0 then
        data = sim.unpackInt32Table(data)
        stage = data[1]
        defaultIdleFps = data[2]
    else
        defaultIdleFps = sim.getIntProperty(sim.handle_app, 'idleFps')
    end
    if enable then
        stage = stage + 1
    else
        if stage > 0 then stage = stage - 1 end
    end
    if stage > 0 then
        sim.setIntProperty(sim.handle_app, 'idleFps', 0)
    else
        sim.setIntProperty(sim.handle_app, 'idleFps', defaultIdleFps)
    end
    sim.setBufferProperty(sim.handle_app, 'signal.__IDLEFPSSTACKSIZE__', sim.packInt32Table({stage, defaultIdleFps}))
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
        if moduleName == pluginName then return true end
        index = index + 1
    end
    return false
end

function sim.throttle(t, func, ...)
    sim.__.lastExecTime = sim.__.lastExecTime or {}
    sim.__.throttleSched = sim.__.throttleSched or {}

    local h = string.dump(func)
    local now = sim.getSystemTime()

    -- cancel any previous scheduled execution: (see sim.scheduleExecution below)
    if sim.__.throttleSched[h] then
        sim.cancelScheduledExecution(sim.__.throttleSched[h])
        sim.__.throttleSched[h] = nil
    end

    if sim.__.lastExecTime[h] == nil or sim.__.lastExecTime[h] + t < now then
        func(...)
        sim.__.lastExecTime[h] = now
    else
        -- if skipping the call (i.e. because it exceeds target rate)
        -- schedule the last call in the future:
        sim.__.throttleSched[h] = sim.scheduleExecution(function(...)
            func(...)
            sim.__.lastExecTime[h] = now
        end, {...}, sim.__.lastExecTime[h] + t)
    end
end

function sim.__.schedulerCallback()
    local function fn(t, pq)
        local item = pq:peek()
        if item and item.timePoint <= t then
            item.func(table.unpack(item.args or {}))
            pq:pop()
            fn(t, pq)
        end
    end

    fn(sim.getSystemTime(), sim.__.scheduler.rtpq)
    if sim.getSimulationState() == sim.simulation_advancing_running then
        fn(sim.getSimulationTime(), sim.__.scheduler.simpq)
    end

    if sim.__.scheduler.simpq:isempty() and sim.__.scheduler.rtpq:isempty() then
        sim.registerScriptFuncHook('sysCall_nonSimulation', sim.__.schedulerCallback, true)
        sim.registerScriptFuncHook('sysCall_sensing', sim.__.schedulerCallback, true)
        sim.registerScriptFuncHook('sysCall_suspended', sim.__.schedulerCallback, true)
        sim.__.scheduler.hook = false
    end
end

function sim.scheduleExecution(func, args, timePoint, simTime)
    if not sim.__.scheduler then
        local priorityqueue = require 'priorityqueue'
        sim.__.scheduler = {
            simpq = priorityqueue(),
            rtpq = priorityqueue(),
            simTime = {},
            nextId = 1,
        }
    end

    local id = sim.__.scheduler.nextId
    sim.__.scheduler.nextId = id + 1
    local pq
    if simTime then
        pq = sim.__.scheduler.simpq
        sim.__.scheduler.simTime[id] = true
    else
        pq = sim.__.scheduler.rtpq
    end
    pq:push(timePoint, {
        id = id,
        func = func,
        args = args,
        timePoint = timePoint,
        simTime = simTime,
    })
    if not sim.__.scheduler.hook then
        sim.registerScriptFuncHook('sysCall_nonSimulation', sim.__.schedulerCallback, true)
        sim.registerScriptFuncHook('sysCall_sensing', sim.__.schedulerCallback, true)
        sim.registerScriptFuncHook('sysCall_suspended', sim.__.schedulerCallback, true)
        sim.__.scheduler.hook = true
    end
    return id
end

function sim.cancelScheduledExecution(id)
    if not sim.__.scheduler then return end
    local pq = nil
    if sim.__.scheduler.simTime[id] then
        sim.__.scheduler.simTime[id] = nil
        pq = sim.__.scheduler.simpq
    else
        pq = sim.__.scheduler.rtpq
    end
    return pq:cancel(function(item) return item.id == id end)
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
        {type = 'table', item_type = 'int', size = '1..*', default_nil = true, nullable = true},
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
                retVal = sim.__.linearInterpolate(sim.__.getConfig(path, dof, li), sim.__.getConfig(path, dof, hi), t, types)
            else
                if t < 0.5 * w then
                    i0 = li - 1
                    i1 = li
                    i2 = hi
                    if li == 1 then i0 = confCnt - 1 end
                    local a = sim.__.linearInterpolate(sim.__.getConfig(path, dof, i0), sim.__.getConfig(path, dof, i1), 1 - 0.25 * w + t * 0.5, types)
                    local b = sim.__.linearInterpolate(sim.__.getConfig(path, dof, i1), sim.__.getConfig(path, dof, i2), 0.25 * w + t * 0.5, types)
                    retVal = sim.__.linearInterpolate(a, b, 0.5 + t / w, types)
                else
                    retVal = sim.__.linearInterpolate(sim.__.getConfig(path, dof, li), sim.__.getConfig(path, dof, hi), t, types)
                end
            end
        else
            if hi == confCnt and not closed then
                retVal = sim.__.linearInterpolate(sim.__.getConfig(path, dof, li), sim.__.getConfig(path, dof, hi), t, types)
            else
                if t > (1 - 0.5 * w) then
                    i0 = li
                    i1 = hi
                    i2 = hi + 1
                    if hi == confCnt then i2 = 2 end
                    t = t - (1 - 0.5 * w)
                    local a = sim.__.linearInterpolate(sim.__.getConfig(path, dof, i0), sim.__.getConfig(path, dof, i1), 1 - 0.5 * w + t * 0.5, types)
                    local b = sim.__.linearInterpolate(sim.__.getConfig(path, dof, i1), sim.__.getConfig(path, dof, i2), t * 0.5, types)
                    retVal = sim.__.linearInterpolate(a, b, t / w, types)
                else
                    retVal = sim.__.linearInterpolate(sim.__.getConfig(path, dof, li), sim.__.getConfig(path, dof, hi), t, types)
                end
            end
        end
    elseif pathType == 'linear' then
        retVal = sim.__.linearInterpolate(sim.__.getConfig(path, dof, li), sim.__.getConfig(path, dof, hi), t, types)
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
        code = "path = require('models.path_customization-2')\n\n" .. code
        local scriptHandle = sim.createScript(sim.scripttype_customization, code)
        sim.setObjectParent(scriptHandle, retVal)
        local prop = sim.getIntProperty(retVal, 'model.propertyFlags')
        sim.setIntProperty(retVal, 'model.propertyFlags', (prop | sim.modelproperty_not_model) - sim.modelproperty_not_model)
        prop = sim.getIntProperty(retVal, 'objectPropertyFlags')
        sim.setIntProperty(retVal, 'objectPropertyFlags', prop | sim.objectproperty_collapsed)
        local data = sim.packTable({ctrlPts, options, subdiv, smoothness, orientationMode, upVector})
        sim.setBufferProperty(retVal, "customData.ABC_PATH_CREATION", data)
        sim.initScript(scriptHandle)
        setYieldAllowed(fl)
    end
    return retVal
end

function sim.createCollection(arg)
    return sim.createCollectionEx(arg or 0)
end

function sim.resamplePath(...)
    local path, pathLengths, finalConfigCnt, method, types = checkargs({
        {type = 'table', item_type = 'float', size = '2..*'},
        {type = 'table', item_type = 'float', size = '2..*'},
        {type = 'int'},
        {type = 'table', default = {type = 'linear', strength = 1.0, forceOpen = false}},
        {type = 'table', item_type = 'int', size = '1..*', default_nil = true, nullable = true},
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
        {type = 'table', item_type = 'float', default_nil = true, nullable = true},
        {type = 'table', item_type = 'int', default_nil = true, nullable = true},
    }, ...)

    if (#confA ~= #confB) or (metric and #confA ~= #metric) or (types and #confA ~= #types) then
        error("Bad table size.")
    end
    return sim.__.getConfigDistance(confA, confB, metric, types)
end

function sim.__.getConfigDistance(confA, confB, metric, types)
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
    local simEigen = require('simEigen')
    local path, dof, cb = checkargs({
        {type = 'table', item_type = 'float', size = '2..*'}, {type = 'int'},
        {type = 'any', default_nil = true, nullable = true},
    }, ...)
    local confCnt = math.floor(#path / dof)
    if dof < 1 or (confCnt < 2) then error("Bad table size.") end
    local distancesAlongPath = {0}
    local totDist = 0
    local pM = simEigen.Matrix(confCnt, dof, path)
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
            local visible = sim.getBoolProperty(objs[i], 'visible')
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
    if not sim.__.propertytypeToStringMap then
        sim.__.propertytypeToStringMap = {}
        for k, v in pairs(sim) do
            local m = string.match(k, 'propertytype_(.*)')
            if m then sim.__.propertytypeToStringMap[v] = m end
        end
    end
    local ret = sim.__.propertytypeToStringMap[ptype]
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
            local cbor = require 'simCBOR'
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
            if sim.getBoolProperty(path[i], 'modelBase') then
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
                return sim.getBoolProperty(h, 'modelBase') or h == p[#p]
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
        local p_cam_h = sim.getObjectAliasRelative(handle, commonAncestorModel, aliasOptions, {noDot = true} )
        if commonAncestorModel ~= -1 and p_bh_cam and p_cam_h then
            return p_bh_cam .. '/' .. p_cam_h
        end
        local p_bh_ca = sim.getObjectAliasRelative(commonAncestor, baseHandle, aliasOptions)
        local p_ca_h = sim.getObjectAliasRelative(handle, commonAncestor, aliasOptions, {noDot = true} )
        if p_bh_ca and p_ca_h then return p_bh_ca .. '/' .. p_ca_h end
    end
end

function sim.generateTextShape(...)
    local txt, color, height, centered, alphabetModel = checkargs({
        {type = 'string'},
        {type = 'table', item_type = 'float', size = 3, default_nil = true, nullable = true},
        {type = 'float', default_nil = true, nullable = true},
        {type = 'bool', default_nil = true, nullable = true},
        {type = 'string', default_nil = true, nullable = true},
    }, ...)
    local textUtils = require('textUtils')
    return textUtils.generateTextShape(txt, color, height, centered, alphabetModel)
end

function sim.getSimulationStopping()
    local s = sim.getSimulationState()
    return s == sim.simulation_stopped or s == sim.simulation_advancing_lastbeforestop
end

sim.getThreadExitRequest = sim.getSimulationStopping

function sim.getSettingString(...)
    local key = checkargs({{type = 'string'}}, ...)
    local r = sim.getStringProperty(sim.handle_app, 'namedParam.settings.' .. key, {noError = true}) --sim.getNamedStringParam(key)
    if r then return r end
    sim.__.systemSettings = sim.__.systemSettings or sim.__.readSystemSettings() or {}
    sim.__.userSettings = sim.__.userSettings or sim.__.readUserSettings() or {}
    return sim.__.userSettings[key] or sim.__.systemSettings[key]
end

function sim.getSettingBool(...)
    local key = checkargs({{type = 'string'}}, ...)
    return sim.__.parseBool(sim.getSettingString(key))
end

function sim.getSettingFloat(...)
    local key = checkargs({{type = 'string'}}, ...)
    return sim.__.parseFloat(sim.getSettingString(key))
end

function sim.getSettingInt32(...)
    local key = checkargs({{type = 'string'}}, ...)
    return sim.__.parseInt(sim.getSettingString(key))
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
            if sim.getBoolProperty(h, 'modelBase') then
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
    if sim.getBoolProperty(handle, 'compound') then
        r.subShapes = {}
        local subShapesCopy = sim.ungroupShape((sim.copyPasteObjects{handle})[1])
        for i, subShape in ipairs(subShapesCopy) do
            r.subShapes[i] = sim.getShapeAppearance(subShape, opts)
        end
        sim.removeObjects(subShapesCopy)
    else
        local mesh = sim.getIntArrayProperty(handle, 'meshes')[1]
        r.edges = sim.getBoolProperty(mesh, 'showEdges')
        r.wireframe = false
        r.visibilityLayer = sim.getIntProperty(handle, 'layer')
        r.culling = sim.getBoolProperty(mesh, 'culling')
        r.shadingAngle = sim.getFloatProperty(mesh, 'shadingAngle')
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
    if sim.getBoolProperty(handle, 'compound') then
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
        local mesh = sim.getIntArrayProperty(handle, 'meshes')[1]
        savedData = (savedData.subShapes or {})[1] or savedData
        sim.setBoolProperty(mesh, 'showEdges', savedData.edges)
        sim.setIntProperty(handle, 'layer', savedData.visibilityLayer)
        sim.setBoolProperty(mesh, 'culling', savedData.culling)
        sim.setFloatProperty(mesh, 'shadingAngle', savedData.shadingAngle)
        sim.setShapeColor(handle, nil, sim.colorcomponent_ambient_diffuse, savedData.color.ambientDiffuse)
        sim.setShapeColor(handle, nil, sim.colorcomponent_specular, savedData.color.specular)
        sim.setShapeColor(handle, nil, sim.colorcomponent_emission, savedData.color.emission)
        sim.setShapeColor(handle, nil, sim.colorcomponent_transparency, savedData.color.transparency)
        return handle
    end
end

apropos = apropos or function(what) -- other sim-versions also have a global apropos function...
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
if not _S.requireWrapped then
    _S.requireWrapped = true -- other sim-versions might already have wrapped it
    require = wrap(require, function(origRequire)
        return function (...)
            local arg = ({...})[1]
            if math.type(arg) == 'integer' and sim.isHandle(arg) and sim.getObjectType(arg) == sim.sceneobject_script then
                local txt = sim.getStringProperty(arg, 'code')
                return loadstring(tostring(txt))()
            end
            return origRequire(...)
        end
    end)
end

sim.checkForceSensor = wrap(sim.readForceSensor, function(orig)
    return function (...)
        local r, force, torque = orig(...)
        return force, torque
    end
end)

sim.getRotationAxis = wrap(sim.getRotationAxis, function(orig)
    return function (mStart, mGoal)
        local axis, angle = orig(mStart:data(), mGoal:data())
        return simEigen.Vector(axis), angle
    end
end)

sim.interpolateMatrices = wrap(sim.interpolateMatrices, function(orig)
    return function (m1, m2, t)
        local m = orig(m1:data(), m2:data(), t)
        return simEigen.Matrix(3, 4, m):vertcat(simEigen.Matrix(1, 4, {0.0, 0.0, 0.0, 1.0}))
    end
end)

-- wrapTypes = function(x, ...) return x end -- (disable wrapTypes)

sim.addItemToCollection = wrapTypes(sim, sim.addItemToCollection, {nil, nil, 'handle'}, {})
sim.addForce = wrapTypes(sim, sim.addForce, {'handle', 'vector3', 'vector3'}, {})
sim.addForceAndTorque = wrapTypes(sim, sim.addForceAndTorque, {'handle', 'vector3', 'vector3'}, {})
sim.addReferencedHandle = wrapTypes(sim, sim.addReferencedHandle, {'handle', 'handle'}, {})
sim.alignShapeBB = wrapTypes(sim, sim.alignShapeBB, {'handle', 'pose'}, {})
sim.callScriptFunction = wrapTypes(sim, sim.callScriptFunction, {'handle'}, {})
sim.checkCollision = wrapTypes(sim, sim.checkCollision, {'handle', 'handle'}, {})
sim.checkOctreePointOccupancy = wrapTypes(sim, sim.checkOctreePointOccupancy, {'handle'}, {})
sim.checkProximitySensor = wrapTypes(sim, sim.checkProximitySensor, {'handle', 'handle'}, {})
sim.checkVisionSensor = wrapTypes(sim, sim.checkVisionSensor, {'handle', 'handle'}, {})
sim.checkVisionSensorEx = wrapTypes(sim, sim.checkVisionSensorEx, {'handle', 'handle'}, {})
sim.checkForceSensor = wrapTypes(sim, sim.checkForceSensor, {'handle'}, {'vector3', 'vector3'})
sim.computeMassAndInertia = wrapTypes(sim, sim.computeMassAndInertia, {'handle'}, {})
sim.executeScriptString = wrapTypes(sim, sim.executeScriptString, {'handle'}, {})
sim.getApiFunc = wrapTypes(sim, sim.getApiFunc, {'handle'}, {})
sim.getApiInfo = wrapTypes(sim, sim.getApiInfo, {'handle'}, {})
sim.getExtensionString = wrapTypes(sim, sim.getExtensionString, {'handle'}, {})
sim.getObjectMatrix = wrapTypes(sim, sim.getObjectMatrix, {'handle', 'handle'}, {'matrix4x4'})
sim.getObjectOrientation = wrapTypes(sim, sim.getObjectOrientation, {'handle', 'handle'}, {'vector3'})
sim.getObjectParent = wrapTypes(sim, sim.getObjectParent, {'handle'}, {'handle'})
sim.getObjectPose = wrapTypes(sim, sim.getObjectPose, {'handle', 'handle'}, {'pose'})
sim.getObjectPosition = wrapTypes(sim, sim.getObjectPosition, {'handle', 'handle'}, {'vector3'})
sim.getObjectQuaternion = wrapTypes(sim, sim.getObjectQuaternion, {'handle', 'handle'}, {'quaternion'})
sim.getObjectVelocity = wrapTypes(sim, sim.getObjectVelocity, {'handle'}, {'vector3', 'vector3'})
sim.getShapeVelocity = wrapTypes(sim, sim.getVelocity, {'handle'}, {'vector3', 'vector3'})
sim.getObjectsInTree = wrapTypes(sim, sim.getObjectsInTree, {'handle'}, {})
sim.getReferencedHandles = wrapTypes(sim, sim.getReferencedHandles, {'handle'}, {})
sim.getReferencedHandle = wrapTypes(sim, sim.getReferencedHandle, {'handle'}, {'handle'})
sim.getReferencedHandlesTags = wrapTypes(sim, sim.getReferencedHandlesTags, {'handle'}, {})
sim.getStackTraceback = wrapTypes(sim, sim.getStackTraceback, {'handle'}, {})
sim.initScript = wrapTypes(sim, sim.initScript, {'handle'}, {})
sim.insertObjectIntoOctree = wrapTypes(sim, sim.insertObjectIntoOctree, {'handle', 'handle', nil, 'color', nil}, {})
sim.insertObjectIntoPointCloud = wrapTypes(sim, sim.insertObjectIntoPointCloud, {'handle'}, {})
sim.insertPointsIntoPointCloud = wrapTypes(sim, sim.insertPointsIntoPointCloud, {'handle', 'handle', nil, nil, 'color'}, {})
sim.insertVoxelsIntoOctree = wrapTypes(sim, sim.insertVoxelsIntoOctree, {'handle', nil, nil, 'color'}, {})
sim.intersectPointsWithPointCloud = wrapTypes(sim, sim.intersectPointsWithPointCloud, {'handle'}, {})
sim.loadScene = wrapTypes(sim, sim.loadScene, {'handle'}, {})
sim.readVisionSensor = wrapTypes(sim, sim.readVisionSensor, {'handle'}, {})
sim.relocateShapeFrame = wrapTypes(sim, sim.relocateShapeFrame, {'handle', 'pose'}, {})
sim.removeModel = wrapTypes(sim, sim.removeModel, {'handle'}, {})
sim.removePointsFromPointCloud = wrapTypes(sim, sim.removePointsFromPointCloud, {'handle'}, {})
sim.removeReferencedObjects = wrapTypes(sim, sim.removeReferencedObjects, {'handle'}, {})
sim.removeVoxelsFromOctree = wrapTypes(sim, sim.removeVoxelsFromOctree, {'handle'}, {})
sim.resetDynamicObject = wrapTypes(sim, sim.resetDynamicObject, {'handle'}, {})
sim.resetGraph = wrapTypes(sim, sim.resetGraph, {'handle'}, {})
sim.resetProximitySensor = wrapTypes(sim, sim.resetProximitySensor, {'handle'}, {})
sim.resetVisionSensor = wrapTypes(sim, sim.resetVisionSensor, {'handle'}, {})
sim.saveModel = wrapTypes(sim, sim.saveModel, {'handle'}, {})
sim.saveScene = wrapTypes(sim, sim.saveScene, {'handle'}, {})
sim.scaleObject = wrapTypes(sim, sim.scaleObject, {'handle'}, {})
sim.setObjectMatrix = wrapTypes(sim, sim.setObjectMatrix, {'handle', 'matrix4x4', 'handle'}, {})
sim.setObjectOrientation = wrapTypes(sim, sim.setObjectOrientation, {'handle', 'vector3', 'handle'}, {})
sim.setObjectParent = wrapTypes(sim, sim.setObjectParent, {'handle', 'handle'}, {})
sim.setObjectPose = wrapTypes(sim, sim.setObjectPose, {'handle', 'pose', 'handle'}, {})
sim.setObjectPosition = wrapTypes(sim, sim.setObjectPosition, {'handle', 'vector3', 'handle'}, {})
sim.setObjectQuaternion = wrapTypes(sim, sim.setObjectQuaternion, {'handle', 'quaternion', 'handle'}, {})
sim.setReferencedHandles = wrapTypes(sim, sim.setReferencedHandles, {'handle'}, {})
sim.setShapeBB = wrapTypes(sim, sim.setShapeBB, {'handle', 'vector3'}, {})
sim.subtractObjectFromOctree = wrapTypes(sim, sim.subtractObjectFromOctree, {'handle', 'handle'}, {})
sim.subtractObjectFromPointCloud = wrapTypes(sim, sim.subtractObjectFromPointCloud, {'handle', 'handle'}, {})
sim.ungroupShape = wrapTypes(sim, sim.ungroupShape, {'handle'}, {})
sim.visitTree = wrapTypes(sim, sim.visitTree, {'handle'}, {})
sim.getShapeAppearance = wrapTypes(sim, sim.getShapeAppearance, {'handle'}, {})
sim.setShapeAppearance = wrapTypes(sim, sim.setShapeAppearance, {'handle'}, {})
sim.setBoolProperty = wrapTypes(sim, sim.setBoolProperty, {'handle'}, {})
sim.getBoolProperty = wrapTypes(sim, sim.getBoolProperty, {'handle'}, {})
sim.setIntProperty = wrapTypes(sim, sim.setIntProperty, {'handle'}, {})
sim.getIntProperty = wrapTypes(sim, sim.getIntProperty, {'handle'}, {})
sim.setLongProperty = wrapTypes(sim, sim.setLongProperty, {'handle'}, {})
sim.getLongProperty = wrapTypes(sim, sim.getLongProperty, {'handle'}, {})
sim.setFloatProperty = wrapTypes(sim, sim.setFloatProperty, {'handle'}, {})
sim.getFloatProperty = wrapTypes(sim, sim.getFloatProperty, {'handle'}, {})
sim.setStringProperty = wrapTypes(sim, sim.setStringProperty, {'handle'}, {})
sim.getStringProperty = wrapTypes(sim, sim.getStringProperty, {'handle'}, {})
sim.setBufferProperty = wrapTypes(sim, sim.setBufferProperty, {'handle'}, {})
sim.getBufferProperty = wrapTypes(sim, sim.getBufferProperty, {'handle'}, {})
sim.setTableProperty = wrapTypes(sim, sim.setTableProperty, {'handle'}, {})
sim.getTableProperty = wrapTypes(sim, sim.getTableProperty, {'handle'}, {})
sim.setIntArray2Property = wrapTypes(sim, sim.setIntArray2Property, {'handle'}, {})
sim.getIntArray2Property = wrapTypes(sim, sim.getIntArray2Property, {'handle'}, {})
sim.setVector2Property = wrapTypes(sim, sim.setVector2Property, {'handle', nil, 'vector2'}, {})
sim.getVector2Property = wrapTypes(sim, sim.getVector2Property, {'handle'}, {'vector2'})
sim.setVector3Property = wrapTypes(sim, sim.setVector3Property, {'handle', nil, 'vector3'}, {})
sim.getVector3Property = wrapTypes(sim, sim.getVector3Property, {'handle'}, {'vector3'})
sim.setQuaternionProperty = wrapTypes(sim, sim.setQuaternionProperty, {'handle', nil, 'quaternion'}, {})
sim.getQuaternionProperty = wrapTypes(sim, sim.getQuaternionProperty, {'handle'}, {'quaternion'})
sim.setPoseProperty = wrapTypes(sim, sim.setPoseProperty, {'handle', nil, 'pose'}, {})
sim.getPoseProperty = wrapTypes(sim, sim.getPoseProperty, {'handle'}, {'pose'})
sim.setColorProperty = wrapTypes(sim, sim.setColorProperty, {'handle', nil, 'color'}, {})
sim.getColorProperty = wrapTypes(sim, sim.getColorProperty, {'handle'}, {'color'})
sim.setFloatArrayProperty = wrapTypes(sim, sim.setFloatArrayProperty, {'handle'}, {})
sim.getFloatArrayProperty = wrapTypes(sim, sim.getFloatArrayProperty, {'handle'}, {})
sim.setIntArrayProperty = wrapTypes(sim, sim.setIntArrayProperty, {'handle'}, {})
sim.getIntArrayProperty = wrapTypes(sim, sim.getIntArrayProperty, {'handle'}, {})
sim.removeProperty = wrapTypes(sim, sim.removeProperty, {'handle'}, {})
sim.getPropertyName = wrapTypes(sim, sim.getPropertyName, {'handle'}, {})
sim.getPropertyInfo = wrapTypes(sim, sim.getPropertyInfo, {'handle'}, {})
sim.setEventFilters = wrapTypes(sim, sim.setEventFilters, {'handle'}, {})
sim.getProperty = wrapTypes(sim, sim.getProperty, {'handle'}, {})
sim.setProperty = wrapTypes(sim, sim.setProperty, {'handle'}, {})
sim.getPropertyTypeString = wrapTypes(sim, sim.getPropertyTypeString, {'handle'}, {})
sim.getProperties = wrapTypes(sim, sim.getProperties, {'handle'}, {})
sim.setProperties = wrapTypes(sim, sim.setProperties, {'handle'}, {})
sim.getPropertiesInfos = wrapTypes(sim, sim.getPropertiesInfos, {'handle'}, {})

-- Hidden, internal functions:
----------------------------------------------------------

function sim.__.readSettings(path)
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

function sim.__.readSystemSettings()
    local sysDir = sim.getStringProperty(sim.handle_app, 'systemPath')
    local psep = package.config:sub(1, 1)
    local usrSet = sysDir .. psep .. 'usrset.txt'
    return sim.__.readSettings(usrSet)
end

function sim.__.readUserSettings()
    local usrDir = sim.getStringProperty(sim.handle_app, 'settingsPath')
    local psep = package.config:sub(1, 1)
    local usrSet = usrDir .. psep .. 'usrset.txt'
    return sim.__.readSettings(usrSet)
end

function sim.__.parseBool(v)
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

function sim.__.parseFloat(v)
    if v == nil then return nil end
    return tonumber(v)
end

function sim.__.parseInt(v)
    if v == nil then return nil end
    v = tonumber(v)
    if math.type(v) == 'integer' then return v end
    error('integer value expected')
end

function sim.__.paramValueToString(v)
    if v == nil then return '' end
    return tostring(v)
end

function sim.__.linearInterpolate(conf1, conf2, t, types)
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

function sim.__.getConfig(path, dof, index)
    local retVal = {}
    for i = 1, dof, 1 do retVal[#retVal + 1] = path[(index - 1) * dof + i] end
    return retVal
end

function sim.__.comparableTables(t1, t2)
    return (isArray(t1) == isArray(t2)) or (isArray(t1) and #t1 == 0) or (isArray(t2) and #t2 == 0)
end

function __2.sysCallEx_init()
    -- Hook function, registered further down
    if sysCall_selChange then sysCall_selChange({sel = sim.getObjectSel()}) end
end

----------------------------------------------------------

sim.packTable = wrap(sim.packTable, function(origFunc)
    return function(data, scheme)
        if type(data) == 'table' then
            scheme = scheme or 0
            if scheme == 0 then
                return origFunc(data, scheme) -- CoppeliaSim's pack format
            elseif scheme == 1 or scheme == 2 then
                local cbor = require 'simCBOR'
                local buff = tobuffer(cbor.encode(data))
                return buff
            else
                error('invalid packing scheme.')
            end
        else
            return tobuffer('')
        end
    end
end)

sim.unpackTable = wrap(sim.unpackTable, function(origFunc)
    return function(data, scheme)
        if isbuffer(data) then
            data = tostring(data)
        end
        if #data == 0 then
            return {} -- since 20.03.2024: empty buffer results in an empty table
        else
            if string.byte(data, 1) == 0 or string.byte(data, 1) == 5 then
                if scheme and scheme ~= 0 then
                    error('decoding scheme mismatch.')
                end
                return origFunc(data) -- CoppeliaSim's pack format
            elseif ((string.byte(data, 1) >= 128) and (string.byte(data, 1) <= 155)) or ((string.byte(data, 1) >= 159) and (string.byte(data, 1) <= 187)) or (string.byte(data, 1) == 191) then
                if scheme and scheme ~= 1 and scheme ~= 2 then
                    error('decoding scheme mismatch.')
                end
                local cbor = require 'simCBOR'
                local tbl = cbor.decode(data)
                return tbl
            else
                error('invalid input data.')
            end
        end
    end
end)


sim.registerScriptFuncHook('sysCall_init', '__2.sysCallEx_init', false) -- hook on *before* init is incompatible with implicit module load...
----------------------------------------------------------

require('sim.Object').extend(sim)

return sim
