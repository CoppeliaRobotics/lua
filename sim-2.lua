local sim = table.clone(_S.internalApi.sim)
sim.version = 2
sim.__all = {'app', 'scene', 'self'}

local locals = {}
__2 = {locals = locals, sim = sim} -- sometimes globals are needed (but __2 only for sim-2)

local simEigen = require 'simEigen'
local checkargs = require('checkargs-2')

function sim.callMethod(target, name, ...)
    if callMethod(target, 'getMethodProperty', name, {noError = true}) then
        -- Lua calling custom property Lua method:
        return locals.getMethodProperty(target, 'getMethodProperty', name)(target, ...)
    elseif locals[name] then
        -- Lua calling built-in Lua method:
        return locals[name](target, name, ...)
    elseif (string.sub(name, 1, 1) == "@") then
        -- C-side calling:
        local res = table.pack(pcall(sim.callMethod, target, name:sub(2), ...)) -- sim.callMethod and not callMethod here!
        if res[1] then
            return '', table.unpack(res, 2, res.n)
        else
            return res[2] -- error msg
        end
    else
        -- Lua calling C method:
        return callMethod(target, name, ...)
    end
end

function locals.setMethodProperty(target, methodName, mName, func)
    assert((type(func) == "function") or (func == nil), "expected a function or nil")
    if func ~= nil then
        func = string.dump(func)
    end
    return callMethod(target, methodName, mName, func)
end

function locals.getMethodProperty(target, methodName, mName)
    local bytecode = callMethod(target, methodName, mName)
    if #bytecode == 0 then
        bytecode = nil
    else
        bytecode = load(tostring(bytecode))
    end
    return bytecode
end

function locals.remove(target, methodName, delayed)
    if target:getPropertyInfo('cleanup', {noError = true}) == sim.propertytype_method then
        target:getMethodProperty('cleanup')(target)
    end
    return callMethod(target, methodName, delayed)
end

function locals.removeObjects(target, methodName, objects, delayed)
    local list = {}
    for i = 1, #objects do
        local obj = objects[i]
        if obj:isValid() then
            if obj.isCustomObject then
                sim.callMethod(obj, 'remove')
            else
                list[#list + 1] = obj
            end
        end
    end
    callMethod(target, methodName, list, delayed)
end

function locals.registerFunctionHook(target, methodName, funcNm, func, before)
    if before == nil then before = true end
    if type(func) == 'string' then
        registerScriptFuncHook(funcNm, func, before, false)
    else
        local str = tostring(func):gsub("[%s:]", "_") -- typical tostring(func) typically produces: "function: xxxxxxx", and : is reserved
        registerScriptFuncHook(funcNm, '__2.' .. str, before, false)
        __2[str] = func
    end
end

function locals.removeFunctionHook(target, methodName, funcNm, func, before)
    if before == nil then before = true end
    if type(func) == 'string' then
        registerScriptFuncHook(funcNm, func, before, true)
    else
        local str = tostring(func):gsub("[%s:]", "_") -- typical tostring(func) typically produces: "function: xxxxxxx", and : is reserved
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

function locals.getAncestors(target, methodName, options, objTypesMap)
    local types = {}
    options = options or {}
    options.types = options.types or {'sceneObject'}
    options.count = options.count or 9999
    if objTypesMap then
        types = objTypesMap
    else
        for i = 1, #options.types do
            types[options.types[i]] = true
        end
    end
    local retVal = {}
    if options.count > 0 then
        while target do
            target = target.parent
            if target then
                if types[target.objectType] or types['sceneObject'] then
                    retVal[#retVal + 1] = target
                end
            else
                break
            end
            options.count = options.count - 1
            if options.count == 0 then
                break
            end
        end
    end
    return retVal
end

function locals.getDescendants(target, methodName, options, types, depth)
    if #methodName > 0 then
        options = options or {}
        options.types = options.types or {'sceneObject'}
        options.depth = options.depth or 9999
        types = {}
        for i = 1, #options.types do
            types[options.types[i]] = true
        end
        depth = options.depth
    end
    local retVal = {}

    if depth > 0 then
        if target == sim.scene then
            for i = 1, #target.orphans do
                local child = target.orphans[i]
                if types[child.objectType] or types['sceneObject'] then
                    retVal[#retVal + 1] = child
                end
                retVal = table.add(retVal, locals.getDescendants(child, '', {}, types, depth - 1))
            end
        else
            for i = 1, #target.children do
                local child = target.children[i]
                if types[child.objectType] or types['sceneObject'] then
                    retVal[#retVal + 1] = child
                end
                retVal = table.add(retVal, locals.getDescendants(child, '', {}, types, depth - 1))
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

function locals.throttle(target, methodName, func, interval, options)
    options = options or {}
    options.args = options.args or {}
    locals.lastExecTime = locals.lastExecTime or {}
    locals.throttleSched = locals.throttleSched or {}

    local h = string.dump(func)
    local now = sim.app.systemTime

    -- cancel any previous scheduled execution: (see locals.scheduleExecution below)
    if locals.throttleSched[h] then
        locals.cancelScheduledExecution(-1, '', locals.throttleSched[h])
        locals.throttleSched[h] = nil
    end

    if locals.lastExecTime[h] == nil or locals.lastExecTime[h] + interval < now then
        func(table.unpack(options.args))
        locals.lastExecTime[h] = now
    else
        -- if skipping the call (i.e. because it exceeds target rate)
        -- schedule the last call in the future:
        locals.throttleSched[h] = locals.scheduleExecution(-1, '', function()
            func(table.unpack(options.args))
            locals.lastExecTime[h] = sim.app.systemTime
        end, interval - now + locals.lastExecTime[h], {simulationTime = false, args = options.args})
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

function locals.scheduleExecution(target, methodName, func, delay, options)
    options = options or {}
    options.simulationTime = options.simulationTime or false
    options.args = options.args or {}
    local timePoint
    if options.simulationTime then
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
    if options.simulationTime then
        pq = locals.scheduler.simpq
        locals.scheduler.simTime[id] = true
    else
        pq = locals.scheduler.rtpq
    end
    pq:push(timePoint, {
        id = id,
        func = func,
        args = options.args,
        timePoint = timePoint,
        simTime = options.simulationTime,
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
    local color, options = checkargs({
        {type = 'color'},
        {type = 'table', default = {component = 'diffuse'}},
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
            if options.component == 'specular' then
                colComp = options.component
            elseif options.component == 'emission' then
                colComp = options.component
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

function locals.visitTree(target, methodName, ...)
    target = sim.Object:toobject(target)
    local visitorFunc, objTypes, objTypesMap = ...
    if #methodName > 0 then
        -- Do not verify again with reentrance
        visitorFunc, options, objTypesMap = checkargs({
            {type = 'func'},
            {type = 'table', default = {types = {'sceneObject'}}},
            {type = 'table', default_nil = true, nullable = true},
        }, ...)
    end

    local types = {}
    if objTypesMap then
        types = objTypesMap
    else
        for i = 1, #options.types do
            types[options.types[i]] = true
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
    local retVal = objectInit.init(target, methodName, initialProperties)
    if retVal == nil then
        error ("error in '" .. methodName .. "': unsupported object type.")
    end
    return retVal
end

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
    opts = opts or {}
    local propertiesInfos = {}
    for i = 0, 1e100 do
        local pname, pclass = sim.callMethod(target, 'getPropertyName', i, {excludeFlags = opts.excludeFlags})
        if not pname then break end
        local ok, err = pcall(function()
            propertiesInfos[pname] = locals.getPropertyInfos(target, '', pname, {decodeMetaInfo = opts.decodeMetaInfo})
        end)
        if not ok then
            error(string.format('property "%s": %s', pname, err))
        end
        propertiesInfos[pname].class = pclass

        -- coppeliaSim won't report group properties via getPropertyName
        -- infer them via pname dots:
        if opts.groups ~= false then
            local parts = string.split(pname, '.', true)
            for i = 1, #parts-1 do
                local pname1 = table.join(table.slice(parts, 1, i), '.')
                local ok, err = pcall(function()
                    propertiesInfos[pname1] = locals.getPropertyInfos(target, '', pname1, {decodeMetaInfo = opts.decodeMetaInfo})
                end)
                if not ok then
                    printf('warning: %s: %s', pname1, err)
                end
            end
        end
    end
    return propertiesInfos
end

function locals.getProperties(target, methodName, opts)
    opts = opts or {}
    local propertiesValues = {}
    for pname, pinfos in pairs(sim.callMethod(target, 'getPropertiesInfos', opts)) do
        if pinfos.flags.readable then
            if not opts.skipLarge or not pinfos.flags.large then
                propertiesValues[pname] = sim.callMethod(target, 'getProperty', pname)
            end
        end
    end
    return propertiesValues
end

function locals.setProperties(target, methodName, props)
    for k, v in pairs(props) do
        locals.setProperty(target, 'setProperty', k, v)
    end
end

function locals.getProperty(target, methodName, pname, opts)
    opts = opts or {}
    local ptype = opts.type or sim.callMethod(target, 'getPropertyInfo', pname, opts)
    if not opts.noError then
        assert(ptype, 'no such property: ' .. pname)
    end
    local retVal
    if ptype then
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
    opts = opts or {}
    assert(type(opts) == 'table', 'opts must be a table')

    -- if opts.type is a string, e.g.: 'intvector', it will be resolved to int, e.g.: sim.propertytype_intvector
    if type(opts.type) == 'string' then
        opts.type = sim['propertytype_' .. opts.type]
        assert(opts.type, 'invalid property type string')
    end
    assert(opts.type == nil or math.type(opts.type) == 'integer', 'invalid type for option "type"')
    local ptype = opts.type

    -- opts.inferType:
    --     for customData.*/signal.* properties:
    --        defaults to true if opts.type not provided
    --        defaults to false otherwise
    --     otherwise defaults to false
    -- (can be overridden)
    local inferType = (string.startswith(pname, 'customData.') or string.startswith(pname, 'signal.')) and opts.type == nil
    if opts.inferType ~= nil then inferType = opts.inferType end

    if inferType then
        -- infer property type from the type of lua variable
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
        elseif ltype == 'function' then
            ptype = sim.propertytype_method
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
    elseif ptype == nil then
        ptype = sim.callMethod(target, 'getPropertyInfo', pname)
        if ptype == nil then
            if opts.noError then return else error('no such property: ' .. pname) end
        end
    end

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
    opts = opts or {}
    local infos = {}
    local ptype, pflags, metaInfo = sim.callMethod(target, 'getPropertyInfo', pname, {bitCoded = 1})
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
    local buf = callMethod(target, 'getTableProperty', tagName, options)
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
    return callMethod(target, 'setTableProperty', tagName, buf, options)
end

function __2.sysCallEx_init()
    -- Hook function, registered further down
    if sysCall_selChange then sysCall_selChange({sel = sim.getObjectSel()}) end
end

sim.Object = require 'sim.Object'
sim.Object.callMethod = sim.callMethod -- replace [C]callMethod with [Lua]sim.callMethod
sim.ObjectArray = require 'sim.ObjectArray'
sim.PropertyGroup = require 'sim.PropertyGroup'
sim.Enum = require 'sim.Enum'

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
    locals.throttle(-1, '', func, t, {args = table.pack(...)})
end

function sim.scheduleExecution(func, args, timePoint, simTime)
    if simTime then
        timePoint = timePoint - sim.scene.simulationTime
    else
        timePoint = timePoint - sim.app.systemTime
    end
    return locals.scheduleExecution(-1, '', func, timePoint, {simulationTime = simTime, args = args})
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
--[[
sim._qhull = nil
sim._serialClose = nil
sim._serialOpen = nil
sim._serialRead = nil
sim.addDrawingObjectItem = nil
sim.addForce = nil
sim.addForceAndTorque = nil
sim.addGraphCurve = nil
sim.addGraphStream = nil
sim.addParticleObject = nil
sim.addParticleObjectItem = nil
sim.addReferencedHandle = nil
sim.addToCollection = nil
sim.adjustView = nil
sim.alignShapeBB = nil
sim.announceSceneContentChange = nil
sim.auxFunc = nil
sim.auxiliaryConsoleClose = nil
sim.auxiliaryConsoleOpen = nil
sim.auxiliaryConsolePrint = nil
sim.auxiliaryConsoleShow = nil
sim.broadcastMsg = nil
sim.callMethod = nil
sim.callScriptFunction = nil
sim.cameraFitToView = nil
sim.cancelScheduledExecution = nil
sim.changeEntityColor = nil
sim.checkCollision = nil
sim.checkDistance = nil
sim.checkOctreePointOccupancy = nil
sim.checkProximitySensor = nil
sim.checkVisionSensor = nil
sim.closePath = nil
sim.closeScene = nil
sim.combineRgbImages = nil
sim.computeMassAndInertia = nil
sim.convertPropertyValue = nil
sim.copyPasteObjects = nil
sim.createCollectionEx = nil
sim.createDetachedScript = nil
sim.createDrawingObject = nil
sim.createDummy = nil
sim.createForceSensor = nil
sim.createHeightfieldShape = nil
sim.createJoint = nil
sim.createMarker = nil
sim.createOctree = nil
sim.createPointCloud = nil
sim.createPrimitiveShape = nil
sim.createProximitySensor = nil
sim.createScript = nil
sim.createShape = nil
sim.createTexture = nil
sim.createVisionSensor = nil
sim.destroyCollection = nil
sim.destroyGraphCurve = nil
sim.duplicateGraphCurveToStatic = nil
sim.executeScriptString = nil
sim.exportMesh = nil
sim.fastIdleLoop = nil
sim.floatingViewAdd = nil
sim.floatingViewRemove = nil
sim.generateShapeFromPath = nil
sim.getApiFunc = nil
sim.getApiInfo = nil
sim.getAutoYieldDelay = nil
sim.getBoolProperty = nil
sim.getBufferProperty = nil
sim.getClosestPosOnPath = nil
sim.getColorProperty = nil
sim.getConfigDistance = nil
sim.getContactInfo = nil
sim.getExplicitHandling = nil
sim.getExtensionString = nil
sim.getFloatArrayProperty = nil
sim.getFloatProperty = nil
sim.getGenesisEvents = nil
sim.getGraphCurve = nil
sim.getGraphInfo = nil
sim.getHandleArrayProperty = nil
sim.getHandleProperty = nil
sim.getIntArray2Property = nil
sim.getIntArrayProperty = nil
sim.getIntProperty = nil
sim.getJointDependency = nil
sim.getJointForce = nil
sim.getJointInterval = nil
sim.getJointMode = nil
sim.getJointPosition = nil
sim.getJointTargetForce = nil
sim.getJointTargetPosition = nil
sim.getJointTargetVelocity = nil
sim.getJointType = nil
sim.getJointVelocity = nil
sim.getLastInfo = nil
sim.getLinkDummy = nil
sim.getLongProperty = nil
sim.getMatrixProperty = nil
sim.getNavigationMode = nil
sim.getObject = nil
sim.getObjectAlias = nil
sim.getObjectAliasRelative = nil
sim.getObjectChildPose = nil
sim.getObjectColor = nil
sim.getObjectFromUid = nil
sim.getObjectHierarchyOrder = nil
sim.getObjectPose = nil
sim.getObjectPosition = nil
sim.getObjectQuaternion = nil
sim.getObjectSel = nil
sim.getObjectType = nil
sim.getObjectUid = nil
sim.getObjectVelocity = nil
sim.getOctreeVoxels = nil
sim.getPage = nil
sim.getPathInterpolatedConfig = nil
sim.getPathLengths = nil
sim.getPluginInfo = nil
sim.getPointCloudOptions = nil
sim.getPointCloudPoints = nil
sim.getPoseProperty = nil
sim.getProperties = nil
sim.getPropertiesInfos = nil
sim.getProperty = nil
sim.getPropertyInfo = nil
sim.getPropertyInfos = nil
sim.getPropertyName = nil
sim.getPropertyTypeString = nil
sim.getQuaternionFromMatrix = nil
sim.getQuaternionProperty = nil
sim.getReferencedHandle = nil
sim.getReferencedHandles = nil
sim.getReferencedHandlesTags = nil
sim.getScaledImage = nil
sim.getScript = nil
sim.getSettingBool = nil
sim.getSettingFloat = nil
sim.getSettingInt32 = nil
sim.getSettingString = nil
sim.getShapeAppearance = nil
sim.getShapeBB = nil
sim.getShapeColor = nil
sim.getShapeGeomInfo = nil
sim.getShapeInertia = nil
sim.getShapeMass = nil
sim.getShapeMesh = nil
sim.getShapeTextureId = nil
sim.getShapeViz = nil
sim.getSimulationState = nil
sim.getSimulationTime = nil
sim.getSimulationTimeStep = nil
sim.getSimulatorMessage = nil
sim.getStackTraceback = nil
sim.getStringArrayProperty = nil
sim.getStringProperty = nil
sim.getSystemTime = nil
sim.getTableProperty = nil
sim.getTextureId = nil
sim.getThreadId = nil
sim.getVector3Property = nil
sim.getVelocity = nil
sim.getVisionSensorDepth = nil
sim.getVisionSensorImg = nil
sim.getVisionSensorRes = nil
sim.groupShapes = nil
sim.handleAddOnScripts = nil
sim.handleDynamics = nil
sim.handleEmbeddedScripts = nil
sim.handleExtCalls = nil
sim.handleGraph = nil
sim.handleJointMotion = nil
sim.handleProximitySensor = nil
sim.handleSandboxScript = nil
sim.handleSensingStart = nil
sim.handleSimulationScripts = nil
sim.handleSimulationStart = nil
sim.handleVisionSensor = nil
sim.importMesh = nil
sim.importShape = nil
sim.initScript = nil
sim.insertObjectIntoOctree = nil
sim.insertObjectIntoPointCloud = nil
sim.insertPointsIntoPointCloud = nil
sim.insertVoxelsIntoOctree = nil
sim.intersectPointsWithPointCloud = nil
sim.isDynamicallyEnabled = nil
sim.isHandle = nil
sim.launchExecutable = nil
sim.loadImage = nil
sim.loadModel = nil
sim.loadScene = nil
sim.moduleEntry = nil
sim.openFile = nil
sim.packDoubleTable = nil
sim.packFloatTable = nil
sim.packInt32Table = nil
sim.packInt64Table = nil
sim.packTable = nil
sim.packUInt16Table = nil
sim.packUInt32Table = nil
sim.packUInt8Table = nil
sim.pauseSimulation = nil
sim.pushUserEvent = nil
sim.readTexture = nil
sim.refreshDialogs = nil
sim.relocateShapeFrame = nil
sim.removeDetachedScript = nil
sim.removeDrawingObject = nil
sim.removeModel = nil
sim.removeObjects = nil
sim.removeParticleObject = nil
sim.removePointsFromPointCloud = nil
sim.removeProperty = nil
sim.removeReferencedObjects = nil
sim.removeVoxelsFromOctree = nil
sim.resamplePath = nil
sim.resetDynamicObject = nil
sim.resetGraph = nil
sim.resetProximitySensor = nil
sim.resetVisionSensor = nil
sim.restoreEntityColor = nil
sim.ruckigPos = nil
sim.ruckigRemove = nil
sim.ruckigStep = nil
sim.ruckigVel = nil
sim.saveImage = nil
sim.saveModel = nil
sim.saveScene = nil
sim.scaleObject = nil
sim.scaleObjects = nil
sim.scheduleExecution = nil
sim.serialCheck = nil
sim.serialSend = nil
sim.setAutoYieldDelay = nil
sim.setBoolProperty = nil
sim.setBufferProperty = nil
sim.setColorProperty = nil
sim.setEventFilters = nil
sim.setExplicitHandling = nil
sim.setFloatArrayProperty = nil
sim.setFloatProperty = nil
sim.setGraphStreamTransformation = nil
sim.setGraphStreamValue = nil
sim.setHandleArrayProperty = nil
sim.setHandleProperty = nil
sim.setIntArray2Property = nil
sim.setIntArrayProperty = nil
sim.setIntProperty = nil
sim.setJointDependency = nil
sim.setJointInterval = nil
sim.setJointMode = nil
sim.setJointPosition = nil
sim.setJointTargetForce = nil
sim.setJointTargetPosition = nil
sim.setJointTargetVelocity = nil
sim.setLinkDummy = nil
sim.setLongProperty = nil
sim.setMatrixProperty = nil
sim.setNavigationMode = nil
sim.setObjectAlias = nil
sim.setObjectChildPose = nil
sim.setObjectColor = nil
sim.setObjectHierarchyOrder = nil
sim.setObjectParent = nil
sim.setObjectPose = nil
sim.setObjectPosition = nil
sim.setObjectQuaternion = nil
sim.setObjectSel = nil
sim.setPage = nil
sim.setPluginInfo = nil
sim.setPointCloudOptions = nil
sim.setPoseProperty = nil
sim.setProperties = nil
sim.setProperty = nil
sim.setPropertyInfo = nil
sim.setQuaternionProperty = nil
sim.setReferencedHandles = nil
sim.setShapeAppearance = nil
sim.setShapeColor = nil
sim.setShapeInertia = nil
sim.setShapeMass = nil
sim.setShapeMaterial = nil
sim.setShapeTexture = nil
sim.setStringArrayProperty = nil
sim.setStringProperty = nil
sim.setTableProperty = nil
sim.setVector3Property = nil
sim.setVisionSensorImg = nil
sim.startSimulation = nil
sim.stopSimulation = nil
sim.subtractObjectFromOctree = nil
sim.subtractObjectFromPointCloud = nil
sim.systemSemaphore = nil
sim.test = nil
sim.textEditorClose = nil
sim.textEditorGetInfo = nil
sim.textEditorOpen = nil
sim.textEditorShow = nil
sim.throttle = nil
sim.transformBuffer = nil
sim.transformImage = nil
sim.ungroupShape = nil
sim.unpackDoubleTable = nil
sim.unpackFloatTable = nil
sim.unpackInt32Table = nil
sim.unpackInt64Table = nil
sim.unpackTable = nil
sim.unpackUInt16Table = nil
sim.unpackUInt32Table = nil
sim.unpackUInt8Table = nil
sim.wait = nil
sim.writeTexture = nil
}
--]]
return sim
