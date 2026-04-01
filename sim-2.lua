local sim = table.clone(_S.internalApi.sim)
sim.version = 2

local locals = {}
local CustomClass = require 'sim.CustomClass'
__2 = {locals = locals} -- sometimes globals are needed (but __2 only for sim-2)

local simEigen = require 'simEigen'
local checkargs = require('checkargs-2')
require('motion-2').extend(sim)

function sim.callMethod(target, name, ...)
    local h = target
    if sim.Object:isobject(h) then
        h = h.handle
    end

    -- handling of custom methods
    if h >= sim.object_customstart and h <= sim.object_customend then
        local t = callMethod(sim.app, 'getCustomObjectType', target)
        if t then
            local m = CustomClass:getMethod(t, name)
            if m then
                return m(...)
            end
        end
        -- custom method not found, continue with searching standard methods below:
    end

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
            target = h
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

function locals.registerClass(target, methodName, ...)
    local objectType, objectMetaInfo = checkargs.checkargsEx({funcName = methodName}, {
        {type = 'string'},
        {union = {{type = 'string'}, {type = 'table'}}},
    }, ...)
    CustomClass:register(objectType, objectMetaInfo)
end

function locals.remove(target, methodName, delayed)
    sim.callMethod(target, '_remove', delayed)
end

function locals.removeObjects(target, methodName, objects, delayed)
    local list = {}
    for i = 1, #objects do
        local obj = objects[i]
        local h = obj
        if sim.Object:isobject(h) then
            h = h.handle
        end
        if h >= sim.object_customstart and h <= sim.object_customend then
            sim.callMethod(h, 'remove')
        else
            list[#list + 1] = obj
        end
    end
    sim.callMethod(target, '_removeObjects', list, delayed)
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
    target = sim.Object:toobject(target)
    local color, materialComponent = checkargs({
        {type = 'color'},
        {type = 'int', default = sim.materialcomponent_diffuse},
    }, ...)
    local colorData = {}
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
    target = sim.Object:toobject(target)
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
    local retVal = objectInit.init(methodName, initialProperties, locals.customClasses)
    if retVal == nil then
        error ("error in '" .. methodName .. "': unsupported object type.")
    end
    return retVal
end

function sim.getSimulationStopping()
    local s = sim.getSimulationState()
    return s == sim.simulation_stopped or s == sim.simulation_advancing_lastbeforestop
end

sim.getThreadExitRequest = sim.getSimulationStopping

function locals.getAppearance(target, methodName)
    target = sim.Object:toobject(target)
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
    target = sim.Object:toobject(target)
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
    function fixTable(v)
        local mt = getmetatable(v)
        if type(v) == 'function' or (mt and not mt.__tocbor) then
            return tostring(v)
        elseif type(v) == 'table' and not mt then
            local t = {}
            for k, v in pairs(v) do
                t[k] = fixTable(v)
            end
            return t
        else
            return v
        end
    end
    return tobuffer(cbor.encode(fixTable(data)))
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
    target = sim.Object:toobject(target)
    opts = opts or {}
    local propertiesInfos = {}
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
    target = sim.Object:toobject(target)
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
    target = sim.Object:toobject(target)
    local retVal
    local noError = opts and opts.noError
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
    target = sim.Object:toobject(target)
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
                local simEigen = require 'simEigen'
                if Buffer:isbuffer(pvalue) then
                    ptype = sim.propertytype_buffer
                elseif Color:iscolor(pvalue) then
                    ptype = sim.propertytype_color
                elseif sim.Object:isobject(pvalue) then
                    ptype = sim.propertytype_handle
                elseif simEigen.Quaternion:isquaternion(pvalue) then
                    ptype = sim.propertytype_quaternion
                elseif simEigen.Matrix:ismatrix(pvalue) then
                    ptype = sim.propertytype_matrix
                elseif simEigen.Pose:ispose(pvalue) then
                    ptype = sim.propertytype_pose
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
        local fn, err = loadstring(
            'local sim = require "sim-2"; ' ..
            'local simEigen = require "simEigen"; ' ..
            'return ' .. value
        )
        if not fn then return nil, err end
        local ok, val = pcall(fn)
        if ok then return val, nil else return nil, val end
    elseif toType == sim.propertytype_string then
        return _S.anyToString(value)
    end
    error 'unsupported type of conversion'
end

function locals.getPropertyInfos(target, methodName, pname, opts)
    target = sim.Object:toobject(target)
    opts = opts or {}
    local infos = {}
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
                retVal = sim.app:unpack(buf)
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
        buf = sim.app:pack(theTable)
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
