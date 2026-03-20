local sim = table.clone(_S.internalApi.sim)
sim.version = 2

local locals = {}
__2 = {locals = locals} -- sometimes globals are needed (but __2 only for sim-2)

local simEigen = require 'simEigen'
local checkargs = require('checkargs-2')
require('motion-2').extend(sim)

function sim.callMethod(target, name, ...)
    if locals[name] or (string.sub(name, 1, 1) == "@") then
        if string.sub(name, 1, 1) == "@" then
            -- c-side is calling!
            if not sim.Object:isobject(target) then
                function getTargetObj(t) 
                    return sim.Object(t)
                end
                local ok, err = pcall(getTargetObj, target)
                if not ok then
                    function dummyFunc() 
                        error("error in 'sim.callMethod': target does not exist.") 
                    end
                    local ok, err = pcall(dummyFunc)
                    return err -- error msg
                end
            end

            name = name:sub(2)
            if type(locals[name]) == 'function' then
                local res = table.pack(pcall(locals[name], target, name, ...))
                if res[1] then
                    return '', table.unpack(res, 2, res.n)
                else
                    return res[2] -- error msg
                end
            else
                function dummyFunc() 
                    error("error in 'sim.callMethod': method '" .. name .. "' does not exist.") 
                end
                local ok, err = pcall(dummyFunc)
                return err -- error msg
            end
        else
            return locals[name](target, name, ...)
        end
    else
        if sim.Object:isobject(target) then
            target = target.handle
        end
        return sim._callMethod(target, name, ...)
        --[[
        function toSimpleType(arg)
            local t = -1 -- stands for simple types directly supported (e.g. sim.stackitem_double, sim.stackitem_table, etc.)
            if arg == nil then
                t = sim.stackitem_null
                arg = 0
            elseif type(arg) == 'table' then
                if isbuffer(arg) then
                    t = -2 -- stands for buffer
                    arg = tostring(arg)
                elseif sim.Object:isobject(arg) then
                    t = sim.stackitem_handle
                    arg = arg.handle
                elseif simEigen.Matrix:ismatrix(arg) then
                    t = 'm' .. tostring(arg:rows()) .. 'x' .. tostring(arg:cols()) -- "m[rows]x[cols]"
                    arg = arg:data()
                elseif simEigen.Quaternion:isquaternion(arg) then
                    t = sim.stackitem_quaternion
                    arg = arg:data()
                elseif simEigen.Pose:ispose(arg) then
                    t = sim.stackitem_pose
                    arg = arg:data()
                else 
                    local narg = {}
                    t = {}
                    for k, v in pairs(arg) do
                        local arg_, t_ = toSimpleType(v)
                        narg[k] = arg_
                        t[k] = t_
                    end
                    arg = narg
                end
            end
            return arg, t
        end

        function toExtendedType(arg, t)
            if t == -2 then
                arg = tobuffer(arg)
            elseif t == sim.stackitem_null then
                arg = nil
            elseif t == sim.stackitem_handle then
                arg = sim.Object(arg)
            elseif t == sim.stackitem_quaternion then
                arg = simEigen.Quaternion(arg)
            elseif t == sim.stackitem_pose then
                arg = simEigen.Pose(arg)
            elseif type(t) == 'string' then
                local rows, cols = t:match("m(%d+)x(%d+)") -- "m[rows]x[cols]"
                arg = simEigen.Matrix(tonumber(rows), tonumber(cols), arg)
            elseif type(t) == 'table' then
                local narg = {}
                for k, v in pairs(arg) do
                    local arg_ = toExtendedType(v, t[k])
                    narg[k] = arg_
                end
                arg = narg
            end
            return arg
        end

        local args = table.pack(...)
        local types = {}
        for i = 1, args.n do
            local arg, t = toSimpleType(args[i])
            args[i] = arg
            types[i] = t
        end
        args.n = nil -- important!!
        local retVals = {}
        local ret = table.pack(sim._callMethod(target, name, args, types))
        ret.n = nil
        for i = 1, #ret // 2 do
            local arg = toExtendedType(ret[2 * (i - 1) + 1], ret[2 * (i - 1) + 2])
            retVals[i] = arg
        end
        return table.unpack(retVals)
        --]]
    end
end

function locals.registerFunctionHook(target, methodName, funcNm, func, before)
    if before == nil then before = true end
    if type(func) == 'string' then
        registerScriptFuncHook(funcNm, func, before, false)
    else
        local str = tostring(func)
        registerScriptFuncHook(funcNm, '__2.' .. str, before, false)
        __2[str] = func
    end
end

function locals.removeFunctionHook(target, methodName, funcNm, func, before)
    if before == nil then before = true end
    if type(func) == 'string' then
        registerScriptFuncHook(funcNm, func, before, true)
    else
        local str = tostring(func)
        registerScriptFuncHook(funcNm, '__2.' .. str, before, true)
        __2[str] = nil
    end
end

function locals.lock(target, methodName, acquire)
    setYieldAllowed(not acquire)
end

function locals.yield(target, methodName)
    if getYieldAllowed() then
        local thread, yieldForbidden = coroutine.running()
        if not yieldForbidden then coroutine.yield() end
    end
end

function locals.step(target, methodName)
    locals.yield(target, methodName)
end

function locals.getAncestors(target, methodName, ...)
    local objTypes, depth, objTypesMap = checkargs.checkargsEx({funcName = methodName}, {
        {type = 'table', item_type = 'string', size = '0..*', default = {'sceneObject'}},
        {type = 'int', default = 9999},
        {type = 'table', default_nil = true, nullable = true},
    }, ...)
    local types = {}
    if objTypesMap then
        types = objTypesMap
    else
        for i = 1, #objTypes do
            types[objTypes[i]] = true
        end
    end
    local retVal = {}
    while target do
        target = target.parent
        if target then
            if types[target.objectType] or types['sceneObject'] then
                retVal[#retVal + 1] = target
            end
        else
            break
        end
        depth = depth - 1
        if depth == 0 then
            break
        end
    end
    return retVal
end

function locals.getDescendants(target, methodName, ...)
    local objTypes, depth, objTypesMap = ...
    if #methodName > 0 then
        -- Do not verify again with reentrance
        objTypes, depth, objTypesMap = checkargs.checkargsEx({funcName = methodName}, {
            {type = 'table', item_type = 'string', size = '0..*', default = {'sceneObject'}},
            {type = 'int', default = 9999},
            {type = 'table', default_nil = true, nullable = true},
        }, ...)
    end
    local types = {}
    if objTypesMap then
        types = objTypesMap
    else
        for i = 1, #objTypes do
            types[objTypes[i]] = true
        end
    end
    local retVal = {}

    if depth > 0 then
        if target == sim.scene then
            for i = 1, #target.orphans do
                local child = target.orphans[i]
                if types[child.objectType] or types['sceneObject'] then
                    retVal[#retVal + 1] = child
                end
                retVal = table.add(retVal, locals.getDescendants(child, '', {}, depth - 1, types))
            end
        else
            for i = 1, #target.children do
                local child = target.children[i]
                if types[child.objectType] or types['sceneObject'] then
                    retVal[#retVal + 1] = child
                end
                retVal = table.add(retVal, locals.getDescendants(child, '', {}, depth - 1, types))
            end
        end
    end
    return retVal
end

function locals.getFunctions(target, methodName, ...)
    return setmetatable({}, {
        __index = function(self, k)
            return function(self_, ...)
                assert(self_ == self, 'methods must be called with object:method(args...)')
                return target:callFunction(k, ...)
            end
        end,
    })
end

sim.auxiliaryConsoleClose = wrap(sim.auxiliaryConsoleClose, function(origFunc)
    return function(...)
        origFunc(...)
    end
end)

sim.auxiliaryConsolePrint = wrap(sim.auxiliaryConsolePrint, function(origFunc)
    return function(...)
        origFunc(...)
    end
end)

sim.auxiliaryConsoleShow = wrap(sim.auxiliaryConsoleShow, function(origFunc)
    return function(...)
        origFunc(...)
    end
end)

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

--[[
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
--]]

function sim.throttle(t, func, ...)
    locals.lastExecTime = locals.lastExecTime or {}
    locals.throttleSched = locals.throttleSched or {}

    local h = string.dump(func)
    local now = sim.getSystemTime()

    -- cancel any previous scheduled execution: (see sim.scheduleExecution below)
    if locals.throttleSched[h] then
        sim.cancelScheduledExecution(locals.throttleSched[h])
        locals.throttleSched[h] = nil
    end

    if locals.lastExecTime[h] == nil or locals.lastExecTime[h] + t < now then
        func(...)
        locals.lastExecTime[h] = now
    else
        -- if skipping the call (i.e. because it exceeds target rate)
        -- schedule the last call in the future:
        locals.throttleSched[h] = sim.scheduleExecution(function(...)
            func(...)
            locals.lastExecTime[h] = now
        end, {...}, locals.lastExecTime[h] + t)
    end
end

function locals.schedulerCallback()
    local function fn(t, pq)
        local item = pq:peek()
        if item and item.timePoint <= t then
            item.func(table.unpack(item.args or {}))
            pq:pop()
            fn(t, pq)
        end
    end

    fn(sim.getSystemTime(), locals.scheduler.rtpq)
    if sim.getSimulationState() == sim.simulation_advancing_running then
        fn(sim.getSimulationTime(), locals.scheduler.simpq)
    end

    if locals.scheduler.simpq:isempty() and locals.scheduler.rtpq:isempty() then
        sim.registerScriptFuncHook('sysCall_nonSimulation', locals.schedulerCallback, true)
        sim.registerScriptFuncHook('sysCall_sensing', locals.schedulerCallback, true)
        sim.registerScriptFuncHook('sysCall_suspended', locals.schedulerCallback, true)
        locals.scheduler.hook = false
    end
end

function sim.scheduleExecution(func, args, timePoint, simTime)
    if not locals.scheduler then
        local priorityqueue = require 'priorityqueue'
        locals.scheduler = {
            simpq = priorityqueue(),
            rtpq = priorityqueue(),
            simTime = {},
            nextId = 1,
        }
    end

    local id = locals.scheduler.nextId
    locals.scheduler.nextId = id + 1
    local pq
    if simTime then
        pq = locals.scheduler.simpq
        locals.scheduler.simTime[id] = true
    else
        pq = locals.scheduler.rtpq
    end
    pq:push(timePoint, {
        id = id,
        func = func,
        args = args,
        timePoint = timePoint,
        simTime = simTime,
    })
    if not locals.scheduler.hook then
        sim.registerScriptFuncHook('sysCall_nonSimulation', locals.schedulerCallback, true)
        sim.registerScriptFuncHook('sysCall_sensing', locals.schedulerCallback, true)
        sim.registerScriptFuncHook('sysCall_suspended', locals.schedulerCallback, true)
        locals.scheduler.hook = true
    end
    return id
end

function sim.cancelScheduledExecution(id)
    if not locals.scheduler then return end
    local pq = nil
    if locals.scheduler.simTime[id] then
        locals.scheduler.simTime[id] = nil
        pq = locals.scheduler.simpq
    else
        pq = locals.scheduler.rtpq
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
                retVal = locals.linearInterpolate(locals.getConfig(path, dof, li), locals.getConfig(path, dof, hi), t, types)
            else
                if t < 0.5 * w then
                    i0 = li - 1
                    i1 = li
                    i2 = hi
                    if li == 1 then i0 = confCnt - 1 end
                    local a = locals.linearInterpolate(locals.getConfig(path, dof, i0), locals.getConfig(path, dof, i1), 1 - 0.25 * w + t * 0.5, types)
                    local b = locals.linearInterpolate(locals.getConfig(path, dof, i1), locals.getConfig(path, dof, i2), 0.25 * w + t * 0.5, types)
                    retVal = locals.linearInterpolate(a, b, 0.5 + t / w, types)
                else
                    retVal = locals.linearInterpolate(locals.getConfig(path, dof, li), locals.getConfig(path, dof, hi), t, types)
                end
            end
        else
            if hi == confCnt and not closed then
                retVal = locals.linearInterpolate(locals.getConfig(path, dof, li), locals.getConfig(path, dof, hi), t, types)
            else
                if t > (1 - 0.5 * w) then
                    i0 = li
                    i1 = hi
                    i2 = hi + 1
                    if hi == confCnt then i2 = 2 end
                    t = t - (1 - 0.5 * w)
                    local a = locals.linearInterpolate(locals.getConfig(path, dof, i0), locals.getConfig(path, dof, i1), 1 - 0.5 * w + t * 0.5, types)
                    local b = locals.linearInterpolate(locals.getConfig(path, dof, i1), locals.getConfig(path, dof, i2), t * 0.5, types)
                    retVal = locals.linearInterpolate(a, b, t / w, types)
                else
                    retVal = locals.linearInterpolate(locals.getConfig(path, dof, li), locals.getConfig(path, dof, hi), t, types)
                end
            end
        end
    elseif pathType == 'linear' then
        retVal = locals.linearInterpolate(locals.getConfig(path, dof, li), locals.getConfig(path, dof, hi), t, types)
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
    return locals.getConfigDistance(confA, confB, metric, types)
end

function locals.getConfigDistance(confA, confB, metric, types)
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
                local q1 = simEigen.Quaternion({confA[j - 3], confA[j - 2], confA[j - 1], confA[j - 0]})
                local q2 = simEigen.Quaternion({confB[j - 3], confB[j - 2], confB[j - 1], confB[j - 0]})
                local a, angle = q1:axisangle(q2)
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
        retVal = sim.getPropertyGetter(ptype)(target, pname)
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
                local Color = require 'Color'
                local simEigen = require 'simEigen'
                if Color:iscolor(pvalue) then
                    ptype = sim.propertytype_color
                elseif sim.Object:isobject(pvalue) then
                    ptype = sim.propertytype_handle
                elseif simEigen.Vector:isvector(pvalue, 2) then
                    ptype = sim.propertytype_vector2
                elseif simEigen.Vector:isvector(pvalue, 3) then
                    ptype = sim.propertytype_vector3
                elseif simEigen.Quaternion:isquaternion(pvalue) then
                    ptype = sim.propertytype_quaternion
                elseif simEigen.Pose:ispose(pvalue) then
                    ptype = sim.propertytype_pose
                elseif simEigen.Matrix:ismatrix(pvalue, 3, 3) then
                    ptype = sim.propertytype_matrix3x3
                elseif simEigen.Matrix:ismatrix(pvalue, 4, 4) then
                    ptype = sim.propertytype_matrix4x4
                elseif simEigen.Matrix:ismatrix(pvalue) then
                    ptype = sim.propertytype_matrix
                else
                    ptype = sim.propertytype_table
                end
            else
                error('unsupported property type: ' .. ltype)
            end
        end
    else
        assert(ptype == nil, 'cannot specify type for static properties')
        ptype = sim.getPropertyInfo(target, pname)
        assert(ptype ~= nil, 'no such property: ' .. pname)
    end
    return sim.getPropertySetter(ptype)(target, pname, pvalue)
end

function sim.getPropertyTypeString(ptype)
    if not locals.propertytypeToStringMap then
        locals.propertytypeToStringMap = table.invert(table.filter(sim, {matchKeyPrefix = 'propertytype_', stripKeyPrefix = true}))
    end
    return locals.propertytypeToStringMap[ptype]
end

function sim.getPropertyGetter(ptype, onlyFuncName)
    if ptype == sim.propertytype_method then return function() end end
    local ptypeStr = sim.getPropertyTypeString(ptype)
    ptypeStr = string.capitalize(string.gsub(ptypeStr, 'array', 'Array'))
    local n = 'get' .. ptypeStr .. 'Property'
    if onlyFuncName then return n end
    local func = sim[n]
    assert(func, 'no such function: sim.' .. n)
    return func
end

function sim.getPropertySetter(ptype, onlyFuncName)
    if ptype == sim.propertytype_method then return function() end end
    local ptypeStr = sim.getPropertyTypeString(ptype)
    ptypeStr = string.capitalize(string.gsub(ptypeStr, 'array', 'Array'))
    local n = 'set' .. ptypeStr .. 'Property'
    if onlyFuncName then return n end
    local func = sim[n]
    assert(func, 'no such function: sim.' .. n)
    return func
end

function sim.convertPropertyValue(value, fromType, toType)
    if fromType == toType then
        return value
    elseif fromType == sim.propertytype_string then
        local loadModules = {'Color', 'simEigen'}
        local preamble = table.concat(map(function(m) return string.format('local %s = require "%s"; ', m, m) end, loadModules))
        local fn, err = loadstring(preamble .. 'return ' .. value)
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

function sim.getPropertyInfos(target, pname, opts)
    opts = opts or {}
    local infos = {}
    local ptype, pflags, metaInfo = sim.getPropertyInfo(target, pname, {bitCoded = 1})
    if not ptype then return end
    infos.type = ptype
    infos.flags = {
        value = pflags,
        readable = pflags & sim.propertyinfo_notreadable == 0,
        writable = pflags & sim.propertyinfo_notwritable == 0,
        removable = pflags & sim.propertyinfo_removable > 0,
        silent = pflags & sim.propertyinfo_silent > 0,
        large = pflags & sim.propertyinfo_largedata > 0,
        deprecated = pflags & sim.propertyinfo_deprecated > 0,
        constant = pflags & sim.propertyinfo_constant > 0,
    }
    if opts.decodeMetaInfo ~= false then
        if metaInfo ~= '' then
            local json = require 'dkjson'
            local decodedMetaInfo = json.decode(metaInfo)
            assert(decodedMetaInfo ~= nil, 'invalid meta info: ' .. metaInfo)
            for k, v in pairs(decodedMetaInfo) do
                assert(infos[k] == nil)
                infos[k] = v
            end
        end
    else
        infos.metaInfo = metaInfo
    end
    return infos
end

function sim.getPropertiesInfos(target, opts)
    opts = opts or {}
    local propertiesInfos = {}
    for i = 0, 1e100 do
        local pname, pclass = sim.getPropertyName(target, i, {excludeFlags = opts.excludeFlags})
        if not pname then break end
        local ok, err = pcall(function()
            propertiesInfos[pname] = sim.getPropertyInfos(target, pname, {decodeMetaInfo = opts.decodeMetaInfo})
        end)
        if not ok then
            error(string.format('property "%s": %s', pname, err))
        end
        propertiesInfos[pname].class = pclass
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
            local table = {}
            if #buf > 0 then
                if string.byte(buf, 1) == 0 or string.byte(buf, 1) == 5 then
                    table = sim.app:unpackTable(buf)
                else
                    table = sim.app:deserialize(buf)
                end
            end
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
            buf = sim.app:serialize(theTable)
        else
            buf = sim.app:packTable(theTable)
        end
        return origFunc(handle, tagName, buf, options)
    end
end)

function locals.visitTree(target, methodName, ...)
    local visitorFunc, objTypes, objTypesMap = ...
    if #methodName > 0 then
        -- Do not verify again with reentrance
        visitorFunc, objTypes, objTypesMap = checkargs({
            {type = 'func'},
            {type = 'table', item_type = 'string', size = '0..*', default = {'sceneObject'}},
            {type = 'table', default_nil = true, nullable = true},
        }, ...)
    end

    local types = {}
    if objTypesMap then
        types = objTypesMap
    else
        for i = 1, #objTypes do
            types[objTypes[i]] = true
        end
    end
    
    if types[target.objectType] or types['sceneObject'] then
        if visitorFunc(target) == false then
            return
        end
    end
    
    for i = 1, #target.children do
        locals.visitTree(target.children[i], '', visitorFunc, {}, types)
    end
end

function locals.createObject(target, methodName, initialProperties)
    local Color = require 'Color'
    local p = table.clone(initialProperties or {})
    local h
    local function extractValueOrDefault(key, default, map)
        map = map or p
        local v = default
        if map[key] ~= nil then
            v = map[key]
            map[key] = nil
        end
        return v
    end
    local function v(intValue, booleanValue)
        if booleanValue then return intValue else return 0 end
    end
    checkargs.checkfields({funcName = methodName}, {
        {name = 'objectType', type = 'string'},
    }, p)
    local objectType = extractValueOrDefault('objectType')
    if false then
    elseif objectType == 'collection' then
        checkargs.checkfields({funcName = methodName}, {
            {name = 'override', type = 'bool', default = false},
        }, p)
        local opts = 0
        if extractValueOrDefault('override') then
            opts = 1
        end
        h = sim.Object(sim.createCollection(opts))
    elseif objectType == 'detachedScript' then
        checkargs.checkfields({funcName = methodName}, {
            {name = 'scriptType', type = 'int', default = sim.scripttype_addon},
            {name = 'code', type = 'string', default = "local sim = require 'sim-2' function sysCall_init() print('Hello from sysCall_init') end"},
            {name = 'lang', type = 'string', default = 'lua'},
        }, p)
        local tp = extractValueOrDefault('scriptType')
        local code = extractValueOrDefault('code')
        local lang = extractValueOrDefault('lang')
        h = sim.Object(sim.createDetachedScript(tp, code, lang))
    elseif objectType == 'drawingObject' then
        checkargs.checkfields({funcName = methodName}, {
            {name = 'itemType', type = 'int', default = sim.drawing_spherepts},
            {name = 'cyclic', type = 'bool', nullable = true},
            {name = 'local', type = 'bool', nullable = true},
            {name = 'paint', type = 'bool', nullable = true},
            {name = 'overlay', type = 'bool', nullable = true},
            {name = 'itemSize', type = 'float', default = 0.005},
            {name = 'duplicateTolerance', type = 'float', default = 0.0},
            {name = 'parentObject', type = 'handle', nullable = true},
            {name = 'itemCnt', type = 'int', default = 0},
            {name = 'color', type = 'color', default = Color:rgb(1.0, 1.0, 0.0)},
        }, p)
        local itemType = extractValueOrDefault('itemType')
        if extractValueOrDefault('cyclic') then
            itemType = itemType | sim.drawing_cyclic
        end
        if extractValueOrDefault('local') then
            itemType = itemType | sim.drawing_local
        end
        if extractValueOrDefault('paint') then
            itemType = itemType | sim.drawing_painttag
        end
        if extractValueOrDefault('overlay') then
            itemType = itemType | sim.drawing_overlay
        end
        local size = extractValueOrDefault('itemSize')
        local duplicateTol = extractValueOrDefault('duplicateTolerance')
        local parentObject = extractValueOrDefault('parentObject', -1)
        if parentObject ~= -1 then
            parentObject = parentObject.handle
        end
        local cnt = extractValueOrDefault('itemCnt')
        local col = extractValueOrDefault('color')
        h = sim.Object(sim.createDrawingObject(itemType, size, duplicateTol, parentObject, cnt, col:data()))
    elseif objectType == 'marker' then
        checkargs.checkfields({funcName = methodName}, {
            {name = 'itemType', type = 'int', default = sim.markertype_spheres},
            {name = 'cyclic', type = 'bool', nullable = true},
            {name = 'local', type = 'bool', nullable = true},
            {name = 'overlay', type = 'bool', nullable = true},
            {name = 'itemSize', type = 'vector3', default = simEigen.Vector({0.005, 0.005, 0.005})},
            {name = 'itemColor', type = 'color', default = Color:rgb(1.0, 1.0, 0.0)},
            {name = 'duplicateTolerance', type = 'float', default = 0.0},
            {name = 'itemCnt', type = 'int', default = 0},
        }, p)
        
         
        
        local itemType = extractValueOrDefault('itemType')
        local options = 0
        if extractValueOrDefault('cyclic') then
            options = options | sim.markeropts_cyclic
        end
        if extractValueOrDefault('local') then
            options = options | sim.markeropts_local
        end
        if extractValueOrDefault('overlay') then
            options = options | sim.markeropts_overlay
        end
        local size = extractValueOrDefault('itemSize')
        local col = extractValueOrDefault('itemColor')
        local duplicateTol = extractValueOrDefault('duplicateTolerance')
        local cnt = extractValueOrDefault('itemCnt')
        local vertices, indices, normals
        if itemType == sim.markertype_custom then
            local mesh = extractValueOrDefault('mesh')
            if type(mesh) ~= 'table' then
                mesh = {}
            end
            if simEigen.Matrix:ismatrix(mesh.vertices) and mesh.vertices:rows() == 3 then
                mesh.vertices = mesh.vertices.T:data()
            end
            if type(mesh.vertices) ~= 'table' or type(mesh.indices) ~= 'table' then
                mesh.vertices = nil
                mesh.indices = nil
                mesh.normals = nil
            else
                if simEigen.Matrix:ismatrix(mesh.normals) and mesh.normals:rows() == 3 then
                    mesh.normals = mesh.normals.T:data()
                end
                if type(mesh.normals) ~= 'table' then
                    mesh.normals = nil
                end
            end
            vertices = mesh.vertices
            indices = mesh.indices
            normals = mesh.normals
        end
        p.mesh = nil
        h = sim.Object(sim.createMarker(itemType, col:data(), size:data(), cnt, options, duplicateTol, vertices, indices, normals))
    elseif objectType == 'dummy' then
        checkargs.checkfields({funcName = methodName}, {
            {name = 'dummySize', type = 'float', default = 0.01},
        }, p)
        h = sim.Object(sim.createDummy(extractValueOrDefault('dummySize')))
    elseif objectType == 'forceSensor' then
        checkargs.checkfields({funcName = methodName}, {
            {name = 'filterType', type = 'int', default = 0},
            {name = 'filterSampleSize', type = 'int', default = 1},
            {name = 'consecutiveViolationsToTrigger', type = 'int', default = 1},
            {name = 'sensorSize', type = 'float', default = 0.01},
            {name = 'forceThreshold', type = 'float', default = 5.0},
            {name = 'torqueThreshold', type = 'float', default = 5.0},
        }, p)
        local options = 0
        if p.forceThreshold then options = options + 1 end
        if p.torqueThreshold then options = options + 2 end
        local intParams = table.rep(0, 5)
        intParams[1] = extractValueOrDefault('filterType')
        intParams[2] = extractValueOrDefault('filterSampleSize')
        intParams[3] = extractValueOrDefault('consecutiveViolationsToTrigger')
        local floatParams = table.rep(0., 5)
        floatParams[1] = extractValueOrDefault('sensorSize')
        floatParams[2] = extractValueOrDefault('forceThreshold')
        floatParams[3] = extractValueOrDefault('torqueThreshold')
        h = sim.Object(sim.createForceSensor(options, intParams, floatParams))
    elseif objectType == 'joint' then
        checkargs.checkfields({funcName = methodName}, {
            {name = 'jointType', type = 'int', default = sim.joint_revolute},
            {name = 'jointMode', type = 'int', default = sim.jointmode_dynamic},
            {name = 'jointLength', type = 'float', default = 0.15},
            {name = 'jointDiameter', type = 'float', default = 0.02},
            {name = 'interval', type = 'table', item_type = 'float', size = 2, nullable = true},
            {name = 'cyclic', type = 'bool', nullable = true},
            {name = 'screwLead', type = 'float', nullable = true},
            {name = 'dynCtrlMode', type = 'int', nullable = true},
        }, p)
        local jointType = extractValueOrDefault('jointType')
        local jointMode = extractValueOrDefault('jointMode')
        local jointSize = {
            extractValueOrDefault('jointLength'),
            extractValueOrDefault('jointDiameter'),
        }
        h = sim.Object(sim.createJoint(jointType, jointMode, 0, jointSize))
        local interval = extractValueOrDefault('interval')
        if interval then
            h.interval = interval
        end
        local cyclic = extractValueOrDefault('cyclic')
        if cyclic ~= nil then
            h.cyclic = cyclic
        end
        local screwLead = extractValueOrDefault('screwLead')
        if screwLead then
            h.screwLead = screwLead
        end
        local dynCtrlMode = extractValueOrDefault('dynCtrlMode')
        if dynCtrlMode then
            h.dynCtrlMode = dynCtrlMode
        end
    elseif objectType == 'ocTree' then
        checkargs.checkfields({funcName = methodName}, {
            {name = 'voxelSize', type = 'float', default = 0.01},
            {name = 'pointSize', type = 'int', default = 1},
            {name = 'showPoints', type = 'bool', default = false},
        }, p)
        local voxelSize = extractValueOrDefault('voxelSize')
        local pointSize = extractValueOrDefault('pointSize')
        local options = 0
            + v(1, extractValueOrDefault('showPoints'))
        h = sim.Object(sim.createOctree(voxelSize, options, pointSize))
    elseif objectType == 'path' then
        checkargs.checkfields({funcName = methodName}, {
            {name = 'ctrlPts', type = 'matrix', cols = 7, default = simEigen.Matrix(2, 7, {-0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0})},
            {name = 'hiddenDuringSim', type = 'bool', default = false},
            {name = 'closed', type = 'bool', default = false},
            {name = 'subdiv', type = 'int', default = 100},
            {name = 'smoothness', type = 'float', default = 1.0},
            {name = 'orientationMode', type = 'int', nullable = true},
            {name = 'upVector', type = 'vector3', default = simEigen.Vector({0.0, 0.0, 1.0})},
        }, p)
        local ctrlPts = extractValueOrDefault('ctrlPts')
        local options = 0
            + v(1, extractValueOrDefault('hiddenDuringSim'))
            + v(2, extractValueOrDefault('closed'))
        local subdiv = extractValueOrDefault('subdiv')
        local smoothness = extractValueOrDefault('smoothness')
        local orientationMode = extractValueOrDefault('orientationMode')
        local upVector = extractValueOrDefault('upVector')
        if orientationMode then
            options = options | 16
        else
            orientationMode = 0
        end
        --h = sim.Object(sim.createPath(ctrlPts:data(), options, subdiv, smoothness, orientationMode, upVector:data()))
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
        code = "path = require('models.path_customization-2')\n\n" .. code

        h = locals.createObject(sim.scene, 'createObject', {objectType = 'dummy', dummySize = 0.04, ['color.diffuse'] = {0.0, 0.68, 0.47}})
        h.name = 'Path'
        local script = locals.createObject(sim.scene, 'createObject', {objectType = 'script', scriptType = sim.scripttype_customization, code = code})
        script:setParent(h)
        local prop = sim.getIntProperty(h, 'model.propertyFlags')
        sim.setIntProperty(h, 'model.propertyFlags', (prop | sim.modelproperty_not_model) - sim.modelproperty_not_model)
        prop = sim.getIntProperty(h, 'objectPropertyFlags')
        sim.setIntProperty(h, 'objectPropertyFlags', prop | sim.objectproperty_collapsed)
        local data = sim.app:packTable({ctrlPts:data(), options, subdiv, smoothness, orientationMode, upVector})
        sim.setBufferProperty(h, "customData.ABC_PATH_CREATION", data)
        script.detachedScript:init()
        setYieldAllowed(fl)
    elseif objectType == 'pointCloud' then
        checkargs.checkfields({funcName = methodName}, {
            {name = 'cellSize', type = 'float', default = 0.02},
            {name = 'maxPointsInCell', type = 'int', default = 20},
            {name = 'pointSize', type = 'int', default = 2},
        }, p)
        local maxVoxelSize = extractValueOrDefault('cellSize')
        local maxPtCntPerVoxel = extractValueOrDefault('maxPointsInCell')
        local options = 0
        local pointSize = extractValueOrDefault('pointSize')
        h = sim.Object(sim.createPointCloud(maxVoxelSize, maxPtCntPerVoxel, options, pointSize))
    elseif objectType == 'proximitySensor' then
        checkargs.checkfields({funcName = methodName}, {
            {name = 'sensorType', type = 'int', default = sim.proximitysensor_cone},
            {name = 'explicitHandling', type = 'bool', default = false},
            {name = 'showVolume', type = 'bool', default = true},
            {name = 'frontFaceDetection', type = 'bool', default = true},
            {name = 'backFaceDetection', type = 'bool', default = true},
            {name = 'exactMode', type = 'bool', default = true},
            {name = 'randomizedDetection', type = 'bool', default = false},
            {name = 'volume_faces', type = 'table', item_type = 'int', size = 2, default = {32, 1}},
            {name = 'volume_subdivisions', type = 'table', item_type = 'int', size = 2, default = {1, 16}},
            {name = 'volume_offset', type = 'float', default = 0.0},
            {name = 'volume_range', type = 'float', default = 0.2},
            {name = 'volume_angle', type = 'float', default = 90.0 * math.pi / 180.0},
            {name = 'sensorPointSize', type = 'float', default = 0.005},
            {name = 'angleThreshold', type = 'float', nullable = true},
            {name = 'closeThreshold', type = 'float', nullable = true},
            {name = 'volume_xSize', type = 'table', item_type = 'float', size = 2, default = {0.2, 0.4}},
            {name = 'volume_ySize', type = 'table', item_type = 'float', size = 2, default = {0.1, 0.2}},
            {name = 'volume_radius', type = 'table', item_type = 'float', size = 2, default = {0.1, 0.2}},
        }, p)
        local sensorType = extractValueOrDefault('sensorType')
        local options = 0
            + v(1, extractValueOrDefault('explicitHandling'))
            + v(2, false) -- deprecated, set to 0
            + v(4, not extractValueOrDefault('showVolume'))
            + v(8, not extractValueOrDefault('frontFaceDetection'))
            + v(16, not extractValueOrDefault('backFaceDetection'))
            + v(32, not extractValueOrDefault('exactMode'))
            + v(512, extractValueOrDefault('randomizedDetection'))
        local intParams = table.rep(0, 8)
        local volume_faces = extractValueOrDefault('volume_faces')
        intParams[1] = volume_faces[1]
        intParams[2] = volume_faces[2]
        local volume_subdivisions = extractValueOrDefault('volume_subdivisions')
        intParams[3] = volume_subdivisions[1]
        intParams[4] = volume_subdivisions[2]
        intParams[5] = 1
        intParams[6] = 1
        local floatParams = table.rep(0., 15)
        floatParams[1] = extractValueOrDefault('volume_offset')
        floatParams[2] = extractValueOrDefault('volume_range')
        local xSize = extractValueOrDefault('volume_xSize')
        local ySize = extractValueOrDefault('volume_ySize')
        floatParams[3] =  xSize[1]
        floatParams[4] =  ySize[1]
        floatParams[5] =  xSize[2]
        floatParams[6] =  ySize[2]
        local radius = extractValueOrDefault('volume_radius')
        floatParams[8] = radius[1]
        floatParams[9] = radius[2]
        floatParams[10] = extractValueOrDefault('volume_angle')
        floatParams[11] = extractValueOrDefault('angleThreshold', nil)
        if floatParams[11] then
            options = options + 64
        else
            floatParams[11] = 0.0
        end
        floatParams[12] = extractValueOrDefault('closeThreshold', nil)
        if floatParams[12] then
            options = options + 256
        else
            floatParams[12] = 0.0
        end
        floatParams[13] = extractValueOrDefault('sensorPointSize')
        h = sim.Object(sim.createProximitySensor(sensorType, 16, options, intParams, floatParams))
    elseif objectType == 'script' then
        checkargs.checkfields({funcName = methodName}, {
            {name = 'scriptType', type = 'int', default = sim.scripttype_simulation},
            {name = 'code', type = 'string', default = ''},
            {name = 'language', type = 'string', default = 'lua'},
            {name = 'scriptDisabled', type = 'bool', default = false},
        }, p)
        local scriptType = extractValueOrDefault('scriptType')
        local scriptText = extractValueOrDefault('code')
        local options = 0
            + v(1, extractValueOrDefault('scriptDisabled'))
        local lang = extractValueOrDefault('language')
        h = sim.Object(sim.createScript(scriptType, scriptText, options, lang))
    elseif objectType == 'shape' then
        checkargs.checkfields({funcName = methodName}, {
            {name = 'mesh', type = 'table', nullable = true},
            {name = 'heightField', type = 'table', nullable = true},
            {name = 'plane', type = 'table', nullable = true},
            {name = 'disc', type = 'table', nullable = true},
            {name = 'cuboid', type = 'table', nullable = true},
            {name = 'spheroid', type = 'table', nullable = true},
            {name = 'cylinder', type = 'table', nullable = true},
            {name = 'cone', type = 'table', nullable = true},
            {name = 'capsule', type = 'table', nullable = true},
            {name = 'shadingAngle', type = 'float', default = 0.0},
            {name = 'culling', type = 'bool', default = false},
--            {name = 'rawMesh', type = 'bool', default = false},
            {name = 'dynamic', type = 'bool', default = false},
            {name = 'showEdges', type = 'bool', default = false},
            {name = 'color.diffuse', type = 'color', default = Color:rgb(1.0, 1.0, 1.0)},
            {name = 'color.specular', type = 'color', default = Color:rgb(0.2, 0.2, 0.2)},
            {name = 'color.emission', type = 'color', default = Color:rgb(0.0, 0.0, 0.0)},
        }, p)
        if p.mesh then
            checkargs.checkfields({funcName = methodName .. ' (mesh field)'}, {
                {name = 'vertices', type = 'matrix', rows = 3, default = simEigen.Matrix(3, 3, {0.0, 0.0, 0.005, 0.1, 0.0, 0.005, 0.2, 0.1, 0.005}).T},
                {name = 'indices', type = 'table', item_type = 'int', size = '3..*', default = {0, 1, 2}},
                {name = 'boundingBoxQuaternion', type = 'quaternion', nullable = true},
                {name = 'frameOrigin', type = 'pose', nullable = true},
            }, p.mesh)
            checkargs.checkfields({funcName = methodName .. ' (mesh field)'}, {
                {name = 'normals', type = 'matrix', cols = #p.mesh.indices, rows = 3, nullable = true},
            }, p.mesh)
            local texture_interpolate = true
            local texture_decal = false
            local texture_rgba = false
            local texture_horizFlip = false
            local texture_vertFlip = false
            local texture_res = nil
            local texture_coord = nil
            local texture_img = nil
            if type(p.mesh.texture) == 'table' then
                checkargs.checkfields({funcName = methodName .. ' (mesh.texture field)'}, {
                    {name = 'interpolate', type = 'bool', default = true},
                    {name = 'decal', type = 'bool', default = false},
                    {name = 'rgba', type = 'bool', default = false},
                    {name = 'horizFlip', type = 'bool', default = false},
                    {name = 'vertFlip', type = 'bool', default = false},
                }, p.mesh.texture)
                local vals = 3
                if p.mesh.texture.rgba then
                    vals = 4
                end
                checkargs.checkfields({funcName = methodName .. ' (mesh.texture field)'}, {
                    {name = 'resolution', type = 'table', item_type = 'int', size = 2},
                    {name = 'image', type = 'buffer', size = vals * p.mesh.texture.resolution[1] * p.mesh.texture.resolution[2]},
                    {name = 'coordinates', type = 'matrix', cols = #p.mesh.indices, rows = 2, nullable = true},
                }, p.mesh.texture)

                texture_interpolate = extractValueOrDefault('interpolate', true, p.mesh.texture)
                texture_decal = extractValueOrDefault('decal', false, p.mesh.texture)
                texture_rgba = extractValueOrDefault('rgba', false, p.mesh.texture)
                texture_horizFlip = extractValueOrDefault('horizFlip', false, p.mesh.texture)
                texture_vertFlip = extractValueOrDefault('vertFlip', false, p.mesh.texture)
                texture_res = extractValueOrDefault('resolution', nil, p.mesh.texture)
                texture_coord = extractValueOrDefault('coordinates', nil, p.mesh.texture)
                texture_img = extractValueOrDefault('image', nil, p.mesh.texture)
            end
            local options = 0
                + v(1, extractValueOrDefault('culling'))
                + v(2, extractValueOrDefault('showEdges'))
                + v(4, not texture_interpolate)
                + v(8, texture_decal)
                + v(16, texture_rgba)
                + v(32, texture_horizFlip)
                + v(64, texture_vertFlip)
            local shadingAngle = extractValueOrDefault('shadingAngle')
            local vertices = extractValueOrDefault('vertices', nil, p.mesh)
            local indices = extractValueOrDefault('indices', nil, p.mesh)
            local normals = extractValueOrDefault('normals', nil, p.mesh)
            if normals then
                normals = normals.T:data()
            end
            h = sim.Object(sim.createShape(options, shadingAngle, vertices.T:data(), indices, normals, texture_coord, texture_img, texture_res))
            local bbQuat = extractValueOrDefault('boundingBoxQuaternion', nil, p.mesh)
            if bbQuat then
                h:alignBoundingBox(bbQuat)
            else
                h:alignBoundingBox({0.0, 0.0, 0.0, 0.0}) -- to encompass shape closest
            end
            local frameOrigin = extractValueOrDefault('frameOrigin', nil, p.mesh)
            if frameOrigin then
                h:relocateFrame(frameOrigin)
            else
                h:relocateFrame({0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0}) -- to center of shape's BB
            end
            p.mesh = nil
        elseif p.heightField then
            checkargs.checkfields({funcName = methodName .. ' (heightField field)'}, {
                {name = 'heights', type = 'matrix', default = simEigen.Matrix(3, 3, {0.0, 0.05, 0.025, 0.03, 0.06, 0.08, 0.01, 0.01, 0.01})},
                {name = 'cellSize', type = 'float', default = 0.5},
                {name = 'rawMesh', type = 'bool', default = false},
            }, p.heightField)
            local options = 0
                + v(1, extractValueOrDefault('culling'))
                + v(2, extractValueOrDefault('showEdges'))
                + v(4, extractValueOrDefault('rawMesh', false, p.heightField))
            local shadingAngle = extractValueOrDefault('shadingAngle')
            local heights = extractValueOrDefault('heights', nil, p.heightField)
            local cellSize = extractValueOrDefault('cellSize', nil, p.heightField)
            h = sim.Object(sim.createHeightfieldShape(options, shadingAngle, heights:cols(), heights:rows(), cellSize * (heights:cols() - 1), heights:data()))
            p.heightField = nil
        else
            local pt, size, open
            local ff
            if p.plane then
                ff = p.plane
                p.plane = nil
                checkargs.checkfields({funcName = methodName .. ' (plane field)'}, {
                    {name = 'size', type = 'table', item_type = 'float', size = 2, default = {0.1, 0.1}},
                }, ff)
                pt = sim.primitiveshape_plane
                local s = extractValueOrDefault('size', nil, ff)
                size = {s[1], s[2], 0.0}
            elseif p.disc then
                ff = p.disc
                p.disc = nil
                checkargs.checkfields({funcName = methodName .. ' (disc field)'}, {
                    {name = 'radius', type = 'float', default = 0.1},
                }, ff)
                pt = sim.primitiveshape_disc
                local r = extractValueOrDefault('radius', nil, ff)
                size = {r * 2.0, r * 2.0, 0.0}
            elseif p.sphere then
                ff = p.sphere
                p.sphere = nil
                checkargs.checkfields({funcName = methodName .. ' (sphere field)'}, {
                    {name = 'radius', type = 'float', default = 0.1},
                }, ff)
                pt = sim.primitiveshape_spheroid
                local r = extractValueOrDefault('radius', nil, ff)
                size = {r * 2.0, r * 2.0, r * 2.0}
            elseif p.cylinder then
                ff = p.cylinder
                p.cylinder = nil
                checkargs.checkfields({funcName = methodName .. ' (cylinder field)'}, {
                    {name = 'radius', type = 'float', default = 0.1},
                    {name = 'length', type = 'float', default = 0.1},
                    {name = 'open', type = 'bool', default = false},
                }, ff)
                pt = sim.primitiveshape_cylinder
                local r = extractValueOrDefault('radius', nil, ff)
                local l = extractValueOrDefault('length', nil, ff)
                size = {r * 2.0, r * 2.0, l}
                open = extractValueOrDefault('open', nil, ff)
            elseif p.cone then
                ff = p.cone
                p.cone = nil
                checkargs.checkfields({funcName = methodName .. ' (cone field)'}, {
                    {name = 'radius', type = 'float', default = 0.1},
                    {name = 'height', type = 'float', default = 0.1},
                    {name = 'open', type = 'bool', default = false},
                }, ff)
                pt = sim.primitiveshape_cone
                local r = extractValueOrDefault('radius', nil, ff)
                local l = extractValueOrDefault('height', nil, ff)
                size = {r * 2.0, r * 2.0, l}
                open = extractValueOrDefault('open', nil, ff)
            elseif p.capsule then
                ff = p.capsule
                p.capsule = nil
                checkargs.checkfields({funcName = methodName .. ' (capsule field)'}, {
                    {name = 'radius', type = 'float', default = 0.025},
                    {name = 'length', type = 'float', default = 0.1},
                }, ff)
                pt = sim.primitiveshape_capsule
                local r = extractValueOrDefault('radius', nil, ff)
                local l = extractValueOrDefault('length', nil, ff)
                size = {r * 2.0, r * 2.0, math.max(l, r * 2.0)}
            else
                if p.cube == nil then
                    p.cube = {}
                end
                ff = p.cube
                p.cube = nil
                checkargs.checkfields({funcName = methodName .. ' (cube field)'}, {
                    {name = 'size', type = 'table', item_type = 'float', size = 3, default = {0.1, 0.1, 0.1}},
                }, ff)
                pt = sim.primitiveshape_cuboid
                size = extractValueOrDefault('size', nil, ff)
            end
            local options = 2
                + v(1, extractValueOrDefault('culling'))
                + v(4, open)
                + v(8, extractValueOrDefault('rawMesh', ff))
            h = sim.Object(sim.createPrimitiveShape(pt, size, options))
            local shadingAngle = extractValueOrDefault('shadingAngle')
            sim.setFloatProperty(h, 'applyShadingAngle', shadingAngle)
        end
        h.dynamic = extractValueOrDefault('dynamic', false)
        if extractValueOrDefault('showEdges') then
            h:applyShowEdges(true)
        end
        h.applyColor.diffuse = extractValueOrDefault('color.diffuse')
        h.applyColor.specular = extractValueOrDefault('color.specular')
        h.applyColor.emission = extractValueOrDefault('color.emission')
    elseif objectType == 'texture' then
        error '"texture" type not supported'
        h = sim.createTexture()
    elseif objectType == 'visionSensor' then
        checkargs.checkfields({funcName = methodName}, {
            {name = 'explicitHandling', type = 'bool', default = false},
            {name = 'showFrustum', type = 'bool', default = false},
            {name = 'useExtImage', type = 'bool', default = false},
            {name = 'resolution', type = 'table', item_type = 'int', size = 2, default = {256, 256}},
            {name = 'clippingPlanes', type = 'table', item_type = 'float', size = 2, default = {0.01, 10.0}},
            {name = 'sensorSize', type = 'float', default = 0.01},
            {name = 'viewAngle', type = 'float', nullable = true},
            {name = 'viewSize', type = 'float', nullable = true},
            {name = 'backgroundColor', type = 'color', nullable = true},
        }, p)
        local viewAngle = extractValueOrDefault('viewAngle')
        local viewSize = extractValueOrDefault('viewSize')
        local perspective = true
        if viewAngle or viewSize == nil then
            if viewAngle == nil then
                viewAngle = 60.0 * math.pi / 180.0
            end
        else
            perspective = false;
        end
        local bgCol = extractValueOrDefault('backgroundColor')
        local options = 0
            + v(1, extractValueOrDefault('explicitHandling'))
            + v(2, perspective)
            + v(4, extractValueOrDefault('showFrustum'))
            -- bit 3 set (8): reserved. Set to 0
            + v(16, extractValueOrDefault('useExtImage'))
            + v(128, bgCol)
        local intParams = table.rep(0, 4)
        local res = extractValueOrDefault('resolution')
        intParams[1] = res[1]
        intParams[2] = res[2]
        local clipPlanes = extractValueOrDefault('clippingPlanes')
        local floatParams = table.rep(0., 11)
        floatParams[1] = clipPlanes[1]
        floatParams[2] = clipPlanes[2]
        if (options & 2) > 0 then
            floatParams[3] = viewAngle
        else
            floatParams[3] = viewSize
        end
        floatParams[4] = extractValueOrDefault('sensorSize')
        if bgCol then
            bgCol = bgCol:data()
            floatParams[7] = bgCol[1]
            floatParams[8] = bgCol[2]
            floatParams[9] = bgCol[3]
        end
        h = sim.Object(sim.createVisionSensor(options, intParams, floatParams))
    elseif objectType == 'camera' then
        h = sim.callMethod(target, '_createCamera', p)
        p.clippingPlanes = nil
        p.viewAngle = nil
        p.viewSize = nil
    elseif objectType == 'light' then
        h = sim.callMethod(target, '_createLight', p)
        p.lightType = nil
    elseif objectType == 'graph' then
        h = sim.callMethod(target, '_createGraph', p)
        p.backgroundColor = nil
        p.foregroundColor = nil
    else
        error ("error in '" .. methodName .. "': unsupported object type.")
    end
    sim.setProperties(h, p)
    return h
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
    locals.systemSettings = locals.systemSettings or locals.readSystemSettings() or {}
    locals.userSettings = locals.userSettings or locals.readUserSettings() or {}
    return locals.userSettings[key] or locals.systemSettings[key]
end

function sim.getSettingBool(...)
    local key = checkargs({{type = 'string'}}, ...)
    return locals.parseBool(sim.getSettingString(key))
end

function sim.getSettingFloat(...)
    local key = checkargs({{type = 'string'}}, ...)
    return locals.parseFloat(sim.getSettingString(key))
end

function sim.getSettingInt32(...)
    local key = checkargs({{type = 'string'}}, ...)
    return locals.parseInt(sim.getSettingString(key))
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

function sim.openFile(f)
    local platform = sim.getIntProperty(sim.handle_app, 'platform')
    local simSubprocess = require 'simSubprocess'
    if platform == 0 then
        -- windows
        simSubprocess.exec('cmd', {'/c', 'start', '', f})
    elseif platform == 1 then
        -- mac
        simSubprocess.exec('open', {f})
    elseif platform == 2 then
        -- linux
        simSubprocess.exec('xdg-open', {f})
    else
        error('unknown platform: ' .. platform)
    end
end

apropos = apropos or function(what) -- other sim-versions also have a global apropos function...
    utils.apropos(what)
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

require('sim-2-typewrappers').extend(sim)

function wrapTypes(sim, func, argType, retType)
    return wrap(func, function(origFunc)
        return function(...)
            local Color = require 'Color'
            local simEigen = require 'simEigen'
            local args = table.pack(...)
            for i = 1, args.n do
                local t = argType and argType[i]
                if t == 'handle' then
                    if args[i] == nil then args[i] = -1 end
                    if sim.Object:isobject(args[i]) then args[i] = args[i].handle end
                elseif t == 'handles' then
                    args[i] = map(function(x)
                                    if sim.Object:isobject(x) then x = x.handle end
                                    return x
                                end, args[i])
                elseif t == 'color' then
                    if Color:iscolor(args[i]) then args[i] = args[i]:data() end
                elseif t == 'pose' then
                    if simEigen.Pose:ispose(args[i]) then args[i] = args[i]:data() end
                elseif t == 'quaternion' then
                    if simEigen.Quaternion:isquaternion(args[i]) then args[i] = args[i]:data() end
                elseif t == 'vector3' then
                    if simEigen.Matrix:ismatrix(args[i]) then assert(args[i]:isvector(3)); args[i] = args[i]:data() end
                elseif t == 'vector' then
                    if simEigen.Matrix:ismatrix(args[i]) then assert(args[i]:isvector()); args[i] = args[i]:data() end
                elseif t == 'matrix' then
                    if simEigen.Matrix:ismatrix(args[i]) then args[i] = args[i]:data() end
                end
            end
            local ret = {origFunc(table.unpack(args))}
            for i = 1, #ret do
                local t = retType and retType[i]
                if t then
                    local cls = ({
                        handle = function(data)
                            if data == -1 then
                                return nil
                            else
                                return sim.Object(data)
                            end
                        end,
                        handles = function(data)
                            return sim.ObjectArray(data)
                        end,
                        vector2 = function(data)
                            if not simEigen.Matrix:ismatrix(data) then data = simEigen.Vector(data) end
                            return data
                        end,
                        vector3 = function(data)
                            if not simEigen.Matrix:ismatrix(data) then data = simEigen.Vector(data) end
                            return data
                        end,
                        matrix3x3 = function(data)
                            if not simEigen.Matrix:ismatrix(data) then data = simEigen.Matrix(3, 3, data) end
                            return data
                        end,
                        matrix4x4 = function(data)
                            if not simEigen.Matrix:ismatrix(data) then data = simEigen.Matrix(4, 4, data) end
                            return data
                        end,
                        quaternion = function(data)
                            if not simEigen.Quaternion:isquaternion(data) then data = simEigen.Quaternion(data) end
                            return data
                        end,
                        pose = function(data)
                            if not simEigen.Pose:ispose(data) then data = simEigen.Pose(data) end
                            return data
                        end,
                        color = function(data)
                            if not Color:iscolor(data) then data = Color(data) end
                            return data
                        end,
                    })[t]
                    if cls then
                        ret[i] = cls(ret[i])
                    end
                end
            end
            return table.unpack(ret)
        end
    end)
end

sim.setTableProperty = wrapTypes(sim, sim.setTableProperty, {'handle'}, {})
sim.getTableProperty = wrapTypes(sim, sim.getTableProperty, {'handle'}, {})
sim.removeProperty = wrapTypes(sim, sim.removeProperty, {'handle'}, {})
sim.getPropertyInfo = wrapTypes(sim, sim.getPropertyInfo, {'handle'}, {})
sim.getPropertyName = wrapTypes(sim, sim.getPropertyName, {'handle'}, {})
sim.setProperty = wrapTypes(sim, sim.setProperty, {'handle'}, {})
sim.getProperty = wrapTypes(sim, sim.getProperty, {'handle'}, {})
sim.setProperties = wrapTypes(sim, sim.setProperties, {'handle'}, {})
sim.getProperties = wrapTypes(sim, sim.getProperties, {'handle'}, {})
sim.getPropertiesInfos = wrapTypes(sim, sim.getPropertiesInfos, {'handle'}, {})
sim.getPropertyTypeString = wrapTypes(sim, sim.getPropertyTypeString, {'handle'}, {})

function sim.getBoolProperty(t, ...)
    return sim.callMethod(t, 'getBoolProperty', ...)
end

function sim.setBoolProperty(t, ...)
    sim.callMethod(t, 'setBoolProperty', ...)
end

function sim.getIntProperty(t, ...)
    return sim.callMethod(t, 'getIntProperty', ...)
end

function sim.setIntProperty(t, ...)
    sim.callMethod(t, 'setIntProperty', ...)
end

function sim.getLongProperty(t, ...)
    return sim.callMethod(t, 'getLongProperty', ...)
end

function sim.setLongProperty(t, ...)
    sim.callMethod(t, 'setLongProperty', ...)
end

function sim.getFloatProperty(t, ...)
    return sim.callMethod(t, 'getFloatProperty', ...)
end

function sim.setFloatProperty(t, ...)
    sim.callMethod(t, 'setFloatProperty', ...)
end

function sim.getStringProperty(t, ...)
    return sim.callMethod(t, 'getStringProperty', ...)
end

function sim.setStringProperty(t, ...)
    sim.callMethod(t, 'setStringProperty', ...)
end

function sim.getBufferProperty(t, ...)
    return sim.callMethod(t, 'getBufferProperty', ...)
end

function sim.setBufferProperty(t, ...)
    sim.callMethod(t, 'setBufferProperty', ...)
end

function sim.getIntArray2Property(t, ...)
    return sim.callMethod(t, 'getIntArray2Property', ...)
end

function sim.setIntArray2Property(t, ...)
    sim.callMethod(t, 'setIntArray2Property', ...)
end

function sim.getIntArrayProperty(t, ...)
    return sim.callMethod(t, 'getIntArrayProperty', ...)
end

function sim.setIntArrayProperty(t, ...)
    sim.callMethod(t, 'setIntArrayProperty', ...)
end

function sim.getFloatArrayProperty(t, ...)
    return sim.callMethod(t, 'getFloatArrayProperty', ...)
end

function sim.setFloatArrayProperty(t, ...)
    sim.callMethod(t, 'setFloatArrayProperty', ...)
end

function sim.getStringArrayProperty(t, ...)
    return sim.callMethod(t, 'getStringArrayProperty', ...)
end

function sim.setStringArrayProperty(t, ...)
    sim.callMethod(t, 'setStringArrayProperty', ...)
end

function sim.getVector2Property(t, ...)
    return sim.callMethod(t, 'getVector2Property', ...)
end

function sim.setVector2Property(t, ...)
    sim.callMethod(t, 'setVector2Property', ...)
end

function sim.getVector3Property(t, ...)
    return sim.callMethod(t, 'getVector3Property', ...)
end

function sim.setVector3Property(t, ...)
    sim.callMethod(t, 'setVector3Property', ...)
end

function sim.getColorProperty(t, ...)
    return sim.callMethod(t, 'getColorProperty', ...)
end

function sim.setColorProperty(t, ...)
    sim.callMethod(t, 'setColorProperty', ...)
end

function sim.getPoseProperty(t, ...)
    return sim.callMethod(t, 'getPoseProperty', ...)
end

function sim.setPoseProperty(t, ...)
    sim.callMethod(t, 'setPoseProperty', ...)
end

function sim.getQuaternionProperty(t, ...)
    return sim.callMethod(t, 'getQuaternionProperty', ...)
end

function sim.setQuaternionProperty(t, ...)
    sim.callMethod(t, 'setQuaternionProperty', ...)
end

function sim.getHandleProperty(t, ...)
    return sim.callMethod(t, 'getHandleProperty', ...)
end

function sim.setHandleProperty(t, ...)
    sim.callMethod(t, 'setHandleProperty', ...)
end

function sim.getHandleArrayProperty(t, ...)
    return sim.ObjectArray(sim.callMethod(t, 'getHandleArrayProperty', ...))
end

function sim.setHandleArrayProperty(t, ...)
    sim.callMethod(t, 'setHandleArrayProperty', ...)
end

function locals.setTableProperty(target, methodName, ...)
    __proxyFuncName__ = 'sim.setTableProperty,' .. methodName .. '@method'
    sim.setTableProperty(target, ...)
end

function locals.getTableProperty(target, methodName, ...)
    __proxyFuncName__ = 'sim.getTableProperty,' .. methodName .. '@method'
    return sim.getTableProperty(target, ...)
end

function locals.removeProperty(target, methodName, ...)
    __proxyFuncName__ = 'sim.removeProperty,' .. methodName .. '@method'
    sim.removeProperty(target, ...)
end

function locals.getPropertyInfo(target, methodName, ...)
    __proxyFuncName__ = 'sim.getPropertyInfo,' .. methodName .. '@method'
    return sim.getPropertyInfo(target, ...)
end

function locals.getPropertyName(target, methodName, ...)
    __proxyFuncName__ = 'sim.getPropertyName,' .. methodName .. '@method'
    return sim.getPropertyName(target, ...)
end

function locals.getProperties(target, methodName, ...)
    return sim.getProperties(target, ...)
end

function locals.setProperties(target, methodName, ...)
    sim.setProperties(target, ...)
end

function locals.getProperty(target, methodName, ...)
    return sim.getProperty(target, ...)
end

function locals.setProperty(target, methodName, ...)
    sim.setProperty(target, ...)
end

function locals.getPropertiesInfos(target, methodName, ...)
    return sim.getPropertiesInfos(target, ...)
end

function locals.getPropertyTypeString(target, methodName, ...)
    return sim.getPropertyTypeString(target, ...)
end

-- Hidden, internal functions:
----------------------------------------------------------

function locals.readSettings(path)
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

function locals.readSystemSettings()
    local sysDir = sim.getStringProperty(sim.handle_app, 'systemPath')
    local psep = package.config:sub(1, 1)
    local usrSet = sysDir .. psep .. 'usrset.txt'
    return locals.readSettings(usrSet)
end

function locals.readUserSettings()
    local usrDir = sim.getStringProperty(sim.handle_app, 'settingsPath')
    local psep = package.config:sub(1, 1)
    local usrSet = usrDir .. psep .. 'usrset.txt'
    return locals.readSettings(usrSet)
end

function locals.parseBool(v)
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

function locals.parseFloat(v)
    if v == nil then return nil end
    return tonumber(v)
end

function locals.parseInt(v)
    if v == nil then return nil end
    v = tonumber(v)
    if math.type(v) == 'integer' then return v end
    error('integer value expected')
end

function locals.paramValueToString(v)
    if v == nil then return '' end
    return tostring(v)
end

function locals.linearInterpolate(conf1, conf2, t, types)
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
                local q1 = simEigen.Quaternion({conf1[i - 3], conf1[i - 2], conf1[i - 1], conf1[i - 0]})
                local q2 = simEigen.Quaternion({conf2[i - 3], conf2[i - 2], conf2[i - 1], conf2[i - 0]})
                local q = q1:interp(t, q2)
                retVal[i - 3] = q[1]
                retVal[i - 2] = q[2]
                retVal[i - 1] = q[3]
                retVal[i - 0] = q[4]
            end
        end
    end
    return retVal
end

function locals.getConfig(path, dof, index)
    local retVal = {}
    for i = 1, dof, 1 do retVal[#retVal + 1] = path[(index - 1) * dof + i] end
    return retVal
end

function locals.comparableTables(t1, t2)
    return (isArray(t1) == isArray(t2)) or (isArray(t1) and #t1 == 0) or (isArray(t2) and #t2 == 0)
end

function __2.sysCallEx_init()
    -- Hook function, registered further down
    if sysCall_selChange then sysCall_selChange({sel = sim.getObjectSel()}) end
end

function locals.serialize(target, methodName, data)
    local cbor = require 'simCBOR'
    return tobuffer(cbor.encode(data))
end

function locals.deserialize(target, methodName, data)
    local cbor = require 'simCBOR'
    return cbor.decode(data)
end

--[[
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
            elseif ( (string.byte(data, 1) >= 128) and (string.byte(data, 1) <= 155)) or -- 128 & 159: array open (without and with break char)
                     ((string.byte(data, 1) >= 159) and (string.byte(data, 1) <= 187)) or (string.byte(data, 1) == 191) or -- 160 & 191: map open (without and with break char)
                     ((string.byte(data, 1) == 216) and ( -- Tag header, followed by array type
                     (string.byte(data, 2) == 64) or (string.byte(data, 2) == 78) or (string.byte(data, 2) == 79) or (string.byte(data, 2) == 85) or (string.byte(data, 2) == 86)) ) then
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
--]]

require('sim.Object').extend(sim)

sim.self:registerFunctionHook('sysCall_init', '__2.sysCallEx_init', false) -- hook on *before* init is incompatible with implicit module load...

return sim
