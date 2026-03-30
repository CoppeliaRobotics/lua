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
        return callMethod(target, name, ...)
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
        local ret = table.pack(callMethod(target, name, args, types))
        ret.n = nil
        for i = 1, #ret // 2 do
            local arg = toExtendedType(ret[2 * (i - 1) + 1], ret[2 * (i - 1) + 2])
            retVals[i] = arg
        end
        return table.unpack(retVals)
        --]]
    end
end

function locals.remove(target, methodName, delayed)
    return sim.callMethod(target, '_remove', delayed)
end

function locals.removeObjects(target, methodName, objects, delayed)
    return sim.callMethod(target, '_removeObjects', objects, delayed)
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

function locals.fastIdleLoop(target, methodName, enable)
    local data = sim.app:getBufferProperty('signal.__IDLEFPSSTACKSIZE__', {noError = true}) -- sim-1 uses buffers too, stay compatible!
    local stage = 0
    local defaultIdleFps
    if data and #data > 0 then
        data = sim.app:unpackInt32Table(data)
        stage = data[1]
        defaultIdleFps = data[2]
    else
        defaultIdleFps = sim.app:getIntProperty('idleFps')
    end
    if enable then
        stage = stage + 1
    else
        if stage > 0 then stage = stage - 1 end
    end
    if stage > 0 then
        sim.app:setIntProperty('idleFps', 0)
    else
        sim.app:setIntProperty('idleFps', defaultIdleFps)
    end
    sim.app:setBufferProperty('signal.__IDLEFPSSTACKSIZE__', sim.packInt32Table({stage, defaultIdleFps}))
end

function locals.throttle(target, methodName, t, func, ...)
    locals.lastExecTime = locals.lastExecTime or {}
    locals.throttleSched = locals.throttleSched or {}

    local h = string.dump(func)
    local now = sim.app.systemTime

    -- cancel any previous scheduled execution: (see locals.scheduleExecution below)
    if locals.throttleSched[h] then
        locals.cancelScheduledExecution(-1, '', locals.throttleSched[h])
        locals.throttleSched[h] = nil
    end

    if locals.lastExecTime[h] == nil or locals.lastExecTime[h] + t < now then
        func(...)
        locals.lastExecTime[h] = now
    else
        -- if skipping the call (i.e. because it exceeds target rate)
        -- schedule the last call in the future:
        locals.throttleSched[h] = locals.scheduleExecution(-1, '', locals.lastExecTime[h] + t, false, function(...)
            func(...)
            locals.lastExecTime[h] = now
        end, {...})
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

    fn(sim.app.systemTime, locals.scheduler.rtpq)
    if sim.getSimulationState() == sim.simulation_advancing_running then
        fn(sim.scene.simulationTime, locals.scheduler.simpq)
    end

    if locals.scheduler.simpq:isempty() and locals.scheduler.rtpq:isempty() then
        sim.self:registerFunctionHook('sysCall_nonSimulation', locals.schedulerCallback, true)
        sim.self:registerFunctionHook('sysCall_sensing', locals.schedulerCallback, true)
        sim.self:registerFunctionHook('sysCall_suspended', locals.schedulerCallback, true)
        locals.scheduler.hook = false
    end
end

function locals.scheduleExecution(target, methodName, delay, simTime, func, ...)
    local timePoint
    if simTime then
        timePoint = delay + sim.scene.simulationTime
    else
        timePoint = delay + sim.app.systemTime
    end
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
        args = table.pack(...),
        timePoint = timePoint,
        simTime = simTime,
    })
    if not locals.scheduler.hook then
        sim.self:registerFunctionHook('sysCall_nonSimulation', locals.schedulerCallback, true)
        sim.self:registerFunctionHook('sysCall_sensing', locals.schedulerCallback, true)
        sim.self:registerFunctionHook('sysCall_suspended', locals.schedulerCallback, true)
        locals.scheduler.hook = true
    end
    return id
end

function locals.cancelScheduledExecution(target, methodName, id)
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

function locals.changeColor(target, methodName, ...)
    local color, materialComponent = checkargs({
        {type = 'color'},
        {type = 'int', default = sim.materialcomponent_diffuse},
    }, ...)
    local colorData = {}
    if not sim.Object:isobject(target) then
        target = sim.Object(target)
    end
    local objs = {target}
    if target.objectType == 'collection' then
        objs = collection.objects
    end
    for i = 1, #objs, 1 do
        local obj = objs[i]
        if obj.objectType == 'shape' then -- and obj.visible then
            local colComp = 'diffuse'
            if materialComponent == sim.materialcomponent_specular then
                colComp = 'specular'
            elseif materialComponent == sim.materialcomponent_emission then
                colComp = 'emission'
            end
            colorData[#colorData + 1] = {puid = obj.persistentUid, data = obj.compoundColors[colComp], comp = colComp}
            obj.applyColor[colComp] = color
        end
    end
    return colorData
end

function locals.restoreColor(target, methodName, ...)
    local colorData = checkargs({{type = 'table'}, size = '0..*'}, ...)
    for i = 1, #colorData, 1 do
        local obj = sim.scene:getObject(colorData[i].puid, {noError = true})
        if obj then
            obj.compoundColors[colorData[i].comp] = colorData[i].data
        end
    end
end

function locals.wait(target, methodName, ...)
    local dt, simTime = checkargs({{type = 'float'}, {type = 'bool', default = true}}, ...)

    if simTime then
        local st = sim.app.simulationTime
        while sim.app.simulationTime - st < dt do sim.self:step() end
    else
        local st = sim.app.systemTime
        while sim.app.systemTime - st < dt do sim.self:step() end
    end
end

function locals.waitForSignal(target, methodName, sigName, item)
    item = item or sim.app
    if (type(item) == 'number') or sim.Object:isobject(item) then
        if not sim.Object:isobject(item) then
            item = sim.Object(item)
        end
        -- Signals via properties
        while true do
            item:getProperty('signal.' .. sigName, {noError = true})
            if retVal then break end
            sim.self:step()
        end
    end
end

function locals.visitTree(target, methodName, ...)
    if not sim.Object:isobject(target) then
        target = sim.Object(target)
    end
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
    local objectInit = require 'objectInit'
    return objectInit.init(methodName, initialProperties)
--[=[    
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
        return objectInit[objectType](methodName, p)
        --[[
        checkargs.checkfields({funcName = methodName}, {
            {name = 'override', type = 'bool', default = false},
        }, p)
        local opts = 0
        if extractValueOrDefault('override') then
            opts = 1
        end
        h = sim.Object(sim.createCollectionEx(opts))
        --]]
    elseif objectType == 'console' then
        checkargs.checkfields({funcName = methodName}, {
            {name = 'title', type = 'string', default = "Console"},
            {name = 'size', type = 'table', item_type = 'int', size = 2, default = {800, 600}},
            {name = 'position', type = 'table', item_type = 'int', size = 2, default = {50, 50}},
            {name = 'fontSize', type = 'int', default = 12},
            {name = 'closeable', type = 'bool', default = true},
            {name = 'hiddenInSimulation', type = 'bool', default = false},
            {name = 'resizable', type = 'bool', default = true},
            {name = 'style', type = 'string', nullable = true},
            {name = 'color', type = 'color', default = Color:rgb(0.0, 0.0, 0.0)},
            {name = 'background', type = 'color', default = Color:rgb(1.0, 1.0, 1.0)},
        }, p)
        local Console = require'Console'
        h = Console(p)
        p = {}
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
            {name = 'text', type = 'table', nullable = true},
            {name = 'shadingAngle', type = 'float', default = 0.0},
            {name = 'culling', type = 'bool', default = false},
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
        elseif p.string then
            checkargs.checkfields({funcName = methodName .. ' (text field)'}, {
                {name = 'text', type = 'string', default = 'Hello'},
                {name = 'height', type = 'float', default = 0.5},
                {name = 'center', type = 'bool', default = true},
            }, p.string)
            local text = extractValueOrDefault('text', nil, p.string)
            local height = extractValueOrDefault('height', nil, p.string)
            local center = extractValueOrDefault('center', nil, p.string)
            local culling = extractValueOrDefault('culling')
            extractValueOrDefault('shadingAngle')
            local textUtils = require('textUtils')
            h = sim.Object(textUtils.generateTextShape(text, nil, height, center, nil, nil, true))
            h.applyCulling = culling
            p.string = nil
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
    --]=]
end

function sim.getSimulationStopping()
    local s = sim.getSimulationState()
    return s == sim.simulation_stopped or s == sim.simulation_advancing_lastbeforestop
end

sim.getThreadExitRequest = sim.getSimulationStopping

function locals.getAppearance(target, methodName)
    if not sim.Object:isobject(target) then
        target = sim.Object(target)
    end
    assert(target.objectType == 'shape', 'not a shape')
    local r = {}
    r.edges = target.compoundEdges
    r.wireframe = target.compoundWireframe
    r.visibilityLayer = target.layer
    r.culling = target.compoundCullings
    r.shadingAngle = target.compoundShadingAngles
    r.color = {}
    r.color.diffuse = target.compoundColors.diffuse
    r.color.specular = target.compoundColors.specular
    r.color.emission = target.compoundColors.emission
    r.color.transparency = target.compoundColors.transparency
    return r
end

function locals.setAppearance(target, methodName, savedData)
    if not sim.Object:isobject(target) then
        target = sim.Object(target)
    end
    assert(target.objectType == 'shape', 'not a shape')
    target.compoundEdges = savedData.edges
    target.compoundWireframe = savedData.wireframe
    target.compoundCullings = savedData.culling
    target.compoundShadingAngles = savedData.shadingAngle
    target.layer = savedData.visibilityLayer
    target.compoundColors.diffuse = savedData.color.diffuse
    target.compoundColors.specular = savedData.color.specular
    target.compoundColors.emission = savedData.color.emission
    target.compoundColors.transparency = savedData.color.transparency
end

function locals.openFile(target, methodName, file)
    local simSubprocess = require 'simSubprocess'
    if sim.app.platform == 0 then
        -- windows
        simSubprocess.exec('cmd', {'/c', 'start', '', file})
    elseif sim.app.platform == 1 then
        -- mac
        simSubprocess.exec('open', {file})
    elseif sim.app.platform == 2 then
        -- linux
        simSubprocess.exec('xdg-open', {file})
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

function locals.serialize(target, methodName, data)
    local cbor = require 'simCBOR'
    return tobuffer(cbor.encode(data))
end

function locals.deserialize(target, methodName, data)
    local cbor = require 'simCBOR'
    return cbor.decode(data)
end

function locals.getPropertyTypeString(target, methodName, ptype)
    if not locals.propertytypeToStringMap then
        locals.propertytypeToStringMap = table.invert(table.filter(sim, {matchKeyPrefix = 'propertytype_', stripKeyPrefix = true}))
    end
    return locals.propertytypeToStringMap[ptype]
end

function locals.getPropertiesInfos(target, methodName, opts)
    opts = opts or {}
    local propertiesInfos = {}
    if not sim.Object:isobject(target) then
        target = sim.Object(target)
    end
    for i = 0, 1e100 do
        local pname, pclass = target:getPropertyName(i, {excludeFlags = opts.excludeFlags})
        if not pname then break end
        local ok, err = pcall(function()
            propertiesInfos[pname] = locals.getPropertyInfos(target, '', pname, {decodeMetaInfo = opts.decodeMetaInfo})
        end)
        if not ok then
            error(string.format('property "%s": %s', pname, err))
        end
        propertiesInfos[pname].class = pclass
    end
    return propertiesInfos
end

function locals.getProperties(target, methodName, opts)
    opts = opts or {}
    local propertiesValues = {}
    for pname, pinfos in pairs(target:getPropertiesInfos(opts)) do
        if pinfos.flags.readable then
            if not opts.skipLarge or not pinfos.flags.large then
                propertiesValues[pname] = target:getProperty(pname)
            end
        end
    end
    return propertiesValues
end

function locals.setProperties(target, methodName, props)
    target = sim.Object:toobject(target)
    for k, v in pairs(props) do
        target:setProperty(k, v)
    end
end

function locals.getProperty(target, methodName, pname, opts)
    local retVal
    local noError = opts and opts.noError
    if not sim.Object:isobject(target) then
        target = sim.Object(target)
    end
    local ptype, pflags, descr = target:getPropertyInfo(pname, opts)
    if not noError then
        assert(ptype, 'no such property: ' .. pname)
    end
    if ptype then
        assert(ptype ~= sim.propertytype_method, 'cannot read property of type "method"')
        local ptypeStr = locals.getPropertyTypeString(-1, '', ptype)
        ptypeStr = string.capitalize(string.gsub(ptypeStr, 'array', 'Array'))
        local getterMethod = 'get' .. ptypeStr .. 'Property'
        retVal = sim.callMethod(target, getterMethod, pname, opts)
    end
    return retVal
end

function locals.setProperty(target, methodName, pname, pvalue, opts)
    if type(opts) == 'number' or type(opts) == 'string' then
        sim.app:logWarn('passing a ' .. type(opts) .. ' as the last argument of setProperty: assuming {type = ...}')
        -- backward compatibility fix: last arg was ptype
        opts = {type = opts}
    end
    local noError = opts and opts.noError
    local ptype = opts and opts.type
    if type(ptype) == 'string' then
        -- if ptype is a string, e.g.: 'intvector', it will be resolved to int, e.g.: sim.propertytype_intvector
        ptype = sim['propertytype_' .. ptype]
        assert(ptype, 'invalid property type string')
    end
    assert(ptype == nil or math.type(ptype) == 'integer', 'invalid type for option "type"')

    if not sim.Object:isobject(target) then
        target = sim.Object(target)
    end

    if string.startswith(pname, 'customData.') or string.startswith(pname, 'signal.') then
        -- custom data properties need type
        -- if not specified, it will be inferred from lua's variable type
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
                local Buffer = require 'buffer'
                local simEigen = require 'simEigen'
                if Buffer:isbuffer(pvalue) then
                    ptype = sim.propertytype_buffer
                elseif Color:iscolor(pvalue) then
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
    elseif ptype == nil then
        ptype = target:getPropertyInfo(pname)
        if ptype == nil then
            if noError then return else error('no such property: ' .. pname) end
        end
    end
    assert(ptype ~= sim.propertytype_method, 'cannot write property of type "method"')
    local ptypeStr = locals.getPropertyTypeString(-1, '', ptype)
    ptypeStr = string.capitalize(string.gsub(ptypeStr, 'array', 'Array'))
    local setterMethod = 'set' .. ptypeStr .. 'Property'
    return sim.callMethod(target, setterMethod, pname, pvalue, opts)
end

function locals.convertPropertyValue(target, methodName, value, fromType, toType)
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

function locals.getPropertyInfos(target, methodName, pname, opts)
    opts = opts or {}
    local infos = {}
    if not sim.Object:isobject(target) then
        target = sim.Object(target)
    end
    local ptype, pflags, metaInfo = target:getPropertyInfo(pname, {bitCoded = 1})
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

function locals.getTableProperty(target, methodName, ...)
    local tagName, options = checkargs.checkargsEx({nilGetsDefault=true}, {
        {type = 'string'},
        {type = 'table', default = {}},
    }, ...)
    local buf = callMethod(target, '_getTableProperty', tagName, options)
    if buf then
        local retVal = {}
        if #buf > 0 then
            if string.byte(buf, 1) == 0 or string.byte(buf, 1) == 5 then
                retVal = sim.app:unpackTable(buf)
            else
                retVal = sim.app:deserialize(buf)
            end
        end
        return retVal
    end
end

function locals.setTableProperty(target, methodName, ...)
    local tagName, theTable, options = checkargs.checkargsEx({nilGetsDefault=true}, {
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
    return callMethod(target, '_setTableProperty', tagName, buf, options)
end

function __2.sysCallEx_init()
    -- Hook function, registered further down
    if sysCall_selChange then sysCall_selChange({sel = sim.getObjectSel()}) end
end

sim.Object = require 'sim.Object'
sim.Object.callMethod = function(self, method, ...)
    local handle = rawget(self, '__handle')
    return sim.callMethod(handle, method, ...)
end
sim.ObjectArray = require 'sim.ObjectArray'
sim.PropertyGroup = require 'sim.PropertyGroup'

sim.app = sim.Object.app
sim.scene = sim.Object.scene
sim.self = sim.Object.self

sim.self:registerFunctionHook('sysCall_init', '__2.sysCallEx_init', false) -- hook on *before* init is incompatible with implicit module load...

-- Backward compatibility functions, to be eventually removed:
--------------------------------------------------------------
function sim.getReferencedHandle(...)
    local sim1 = require('sim-1')
    return sim1.getReferencedHandle(...)
end

function sim.addReferencedHandle(...)
    local sim1 = require('sim-1')
    return sim1.addReferencedHandle(...)
end

function sim.removeReferencedObjects(...)
    local sim1 = require('sim-1')
    return sim1.removeReferencedObjects(...)
end

function sim.getObjectAliasRelative(...)
    local sim1 = require('sim-1')
    return sim1.getObjectAliasRelative(...)
end

function sim.fastIdleLoop(enable)
    locals.fastIdleLoop(-1, '', enable)
end

function sim.throttle(t, func, ...)
    locals.throttle(-1, '', t, func, ...)
end

function sim.scheduleExecution(func, args, timePoint, simTime)
    if simTime then
        timePoint = timePoint - sim.scene.simulationTime
    else
        timePoint = timePoint - sim.app.systemTime
    end
    return locals.scheduleExecution(-1, '', timePoint, simTime, func, table.unpack(args))
end

function sim.cancelScheduledExecution(id)
    return locals.cancelScheduledExecution(-1, '', id)
end

function sim.closePath(...)
    local sim1 = require('sim-1')
    return sim1.closePath(...)
end

function sim.getPathInterpolatedConfig(...)
    local sim1 = require('sim-1')
    return sim1.getPathInterpolatedConfig(...)
end

function sim.resamplePath(...)
    local sim1 = require('sim-1')
    return sim1.resamplePath(...)
end

function sim.getConfigDistance(...)
    local sim1 = require('sim-1')
    return sim1.getConfigDistance(...)
end

function sim.getPathLengths(...)
    local sim1 = require('sim-1')
    return sim1.getPathLengths(...)
end

function sim.changeEntityColor(target, color, comp)
    return locals.changeColor(target, '', color, comp)
end

function sim.restoreEntityColor(data)
    locals.restoreColor(-1, '', data)
end

function sim.wait(...)
    locals.wait(-1, '', ...)
end

function sim.waitForSignal(item, sigName)
    locals.waitForSignal(-1, '', sigName, item)
end

function sim.getSettingString(...)
    local sim1 = require('sim-1')
    return sim1.getSettingString(...)
end

function sim.getSettingBool(...)
    local sim1 = require('sim-1')
    return sim1.getSettingBool(...)
end

function sim.getSettingFloat(...)
    local sim1 = require('sim-1')
    return sim1.getSettingFloat(...)
end

function sim.getSettingInt32(...)
    local sim1 = require('sim-1')
    return sim1.getSettingInt32(...)
end

function sim.setShapeAppearance(target, savedData)
    locals.setAppearance(target, '', savedData)
end

function sim.openFile(file)
    locals.openFile(-1, '', file)
end

function sim.getShapeAppearance(target)
    return locals.getAppearance(target, '') 
end

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
    return sim.callMethod(t, 'getHandleArrayProperty', ...)
end

function sim.setHandleArrayProperty(t, ...)
    sim.callMethod(t, 'setHandleArrayProperty', ...)
end

function sim.getTableProperty(t, ...)
    return sim.callMethod(t, 'getTableProperty', ...)
end

function sim.setTableProperty(t, ...)
    sim.callMethod(t, 'setTableProperty', ...)
end

function sim.removeProperty(t, ...)
    sim.callMethod(t, 'removeProperty', ...)
end

function sim.getPropertyName(t, ...)
    return sim.callMethod(t, 'getPropertyName', ...)
end

function sim.getPropertyInfo(t, ...)
    return sim.callMethod(t, 'getPropertyInfo', ...)
end

function sim.getPropertyTypeString(...)
    return locals.getPropertyTypeString(-1, '', ...)
end

function sim.getPropertiesInfos(t, ...)
    return locals.getPropertiesInfos(t, '', ...)
end

function sim.getProperties(t, ...)
    return locals.getProperties(t, '', ...)
end

function sim.setProperties(t, ...)
    locals.setProperties(t, '', ...)
end

function sim.getProperty(t, ...)
    return locals.getProperty(t, '', ...)
end

function sim.setProperty(t, ...)
    return locals.setProperty(t, '', ...)
end

function sim.convertPropertyValue(...)
    return locals.convertPropertyValue(-1, '', ...)
end

function sim.getPropertyInfos(t, ...)
    return locals.getPropertyInfos(t, '', ...)
end
--------------------------------------------------------------

return sim
