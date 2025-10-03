__oldModeConsts = {
    syscb_init = true,
    syscb_cleanup = true,
    syscb_regular = true,
    syscb_actuation = true,
    syscb_sensing = true,
    syscb_nonsimulation = true,
    syscb_beforesimulation = true,
    syscb_aftersimulation = true,
    syscb_suspended = true,
    syscb_suspend = true,
    syscb_resume = true,
    syscb_beforeinstanceswitch = true,
    syscb_afterinstanceswitch = true,
    syscb_beforecopy = true,
    syscb_aftercopy = true,
    getScriptExecutionCount = true,
    mainscriptcall_initialization = true,
    mainscriptcall_cleanup = true,
    mainscriptcall_regular = true,
    childscriptcall_initialization = true,
    childscriptcall_cleanup = true,
    childscriptcall_actuation = true,
    childscriptcall_sensing = true,
    customizationscriptcall_initialization = true,
    customizationscriptcall_cleanup = true,
    customizationscriptcall_nonsimulation = true,
    customizationscriptcall_lastbeforesimulation = true,
    customizationscriptcall_firstaftersimulation = true,
    customizationscriptcall_simulationactuation = true,
    customizationscriptcall_simulationsensing = true,
    customizationscriptcall_simulationpause = true,
    customizationscriptcall_simulationpausefirst = true,
    customizationscriptcall_simulationpauselast = true,
    customizationscriptcall_lastbeforeinstanceswitch = true,
    customizationscriptcall_firstafterinstanceswitch = true,
    customizationscriptcall_beforecopy = true,
    customizationscriptcall_aftercopy = true,
}

if _VERSION ~= 'Lua 5.1' then
    loadstring = load
end

pcall(require, 'devmode')

if _DEVMODE then
    -- DEBUG: print each time global variable "sim" is about to be wrote to:
    local mt = getmetatable(_G) or {}
    local old_newindex = mt.__newindex
    mt.__newindex = function(tbl, key, value)
        if key == 'sim' or key == 'simIK' or key == 'simUI' or key == 'simGeom' or key == 'simMujoco' or key == 'simAssimp' or key == 'simBubble' or key == 'simCHAI3D' or key == 'simMTB' or key == 'simOMPL' or key == 'simOpenMesh' or key == 'simQHull' or key == 'simRRS1' or key == 'simSDF' or key == 'simSubprocess' or key == 'simSurfRec' or key == 'simURDF' or key == 'simVision' or key == 'simWS' or key == 'simZMQ' or key == 'simIM' or key == 'simEigen' or key == 'simIGL' or key == 'simICP' or key == 'simROS' or key == 'simROS2' or key == 'simEvent' then
            local info = debug.getinfo(2, "nSl")
            local sloc = info.short_src .. ':' .. info.currentline
            if info.name then sloc = info.name .. ' in ' .. sloc end
            addLog(430, sloc .. ": write to global '" .. key .. "'!")
        end
        if old_newindex then
            if type(old_newindex) == "function" then
                return old_newindex(tbl, key, value)
            else
                rawset(old_newindex, key, value)
                return
            end
        end
        rawset(tbl, key, value)
    end
    setmetatable(_G, mt)
end

function wrap(originalFunction, wrapperFunctionGenerator)
    --[[
    e.g. a wrapper that print args before calling the original function:

    sim.getObject = wrap(sim.getObject, function(origFunc)
        return function(...)
            print('you are calling sim.getObject with args:', ...)
            return origFunc(...)
        end
    end)

    ]]--
    return wrapperFunctionGenerator(originalFunction)
end

function wrapTypes(sim, func, argType, retType)
    return wrap(func, function(origFunc)
        return function(...)
            local Color = require 'color'
            local simEigen = require 'simEigen'
            local args = {...}
            for i = 1, #args do
                local t = argType and argType[i]
                if t == 'handle' then
                    if type(args[i]) == 'string' then
                        args[i] = sim.getObject(args[i])
                    end
                    if sim.Object:isobject(args[i]) then
                        args[i] = #args[i]
                    end
                elseif t == 'handles' then
                    assert(type(args[i]) == 'table', 'bad type')
                    for j = 1, #args[i] do
                        if sim.Object:isobject(args[i][j]) then
                            args[i][j] = #args[i][j]
                        end
                    end
                elseif t then
                    local a = callmeta(args[i], '__to' .. t)
                    if a ~= nil then
                        args[i] = a
                    end
                end
            end
            local ret = {origFunc(table.unpack(args))}
            for i = 1, #ret do
                local t = retType and retType[i]
                if t then
                    local cls = ({
                        handle = function(h)
                            -- for now don't wrap handle with sim.Object
                            return h
                            -- return sim.Object(h)
                        end,
                        handles = function(h)
                            -- for now don't wrap handles with {sim.Object}
                            return h
                            -- return sim.Object(h)
                        end,
                        vector2 = function(data)
                            return simEigen.Vector(data)
                        end,
                        vector3 = function(data)
                            return simEigen.Vector(data)
                        end,
                        matrix3x3 = function(data)
                            return simEigen.Matrix(3, 3, data)
                        end,
                        matrix4x4 = function(data)
                            if #data == 12 then data = table.add(data, {0, 0, 0, 1}) end
                            return simEigen.Matrix(4, 4, data)
                        end,
                        quaternion = function(data)
                            return simEigen.Quaternion(data)
                        end,
                        pose = function(data)
                            return simEigen.Pose(data)
                        end,
                        color = function(data)
                            return Color(data)
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

function callmeta(o, mm, d)
    local mt = getmetatable(o)
    if mt and mt[mm] then
        if type(mt[mm]) == 'function' then
            return mt[mm](o)
        else
            return mt[mm]
        end
    else
        return d
    end
end

require = wrap(require, function(origRequire)
    return function(...)
        local requiredName = table.unpack {...}
        local fl = setYieldAllowed(false) -- important when called from coroutine
        local retVals = {origRequire(...)}
        setYieldAllowed(fl)
        auxFunc('usedmodule', requiredName)
        return table.unpack(retVals)
    end
end)

function import(moduleName, ...)
    assert(type(moduleName) == 'string', 'invalid argument type')
    local names = {...}
    local opts = {}

    local origModuleName = moduleName

    -- shortand for: import 'simFoo.*'
    if moduleName:endswith '.*' and #names == 0 then
        moduleName = moduleName:sub(1, #moduleName - 2)
        return import(moduleName, '*')
    end
    local mod = require(moduleName)

    -- allow to pass opts as: import(moduleName, ..., {opt1=val1, ...})
    if type(names[#names]) == 'table' then
        opts = table.remove(names)
    end

    if #names == 0 then
        if not opts.keepVersionSuffix then
            moduleName = moduleName:gsub('[-%d]+$', '')
        end
        if _G[moduleName] ~= nil and _G[moduleName] ~= mod and not opts.silent then
            addLog(300, 'import "' .. origModuleName .. '": overwriting global variable "' .. moduleName .. '"')
        end
        _G[moduleName] = mod
    elseif #names == 1 and names[1] == '*' then
        -- modules can optionally define a __all key and/or a __all_exclude key
        -- to specify which names to [not] import when doing a star-import
        local allNames = mod.__all or table.keys(mod)
        local excludeNames = {}
        for _, name in ipairs(mod.__all_exclude or {'unittest'}) do
            excludeNames[name] = true
        end
        for _, name in ipairs(allNames) do
            if not excludeNames[name] then
                if _G[name] ~= nil then
                    local isLazyLoader = not not (getmetatable(_G[name]) or {}).__moduleLazyLoader
                    if _G[name] ~= mod[name] and not opts.silent and not isLazyLoader then
                        addLog(300, 'import "' .. origModuleName .. '": overwriting global variable "' .. name .. '"')
                    end
                end
                _G[name] = mod[name]
            end
        end
    else
        for _, name in ipairs(names) do
            assert(type(name) == 'string', 'invalid argument type')
            assert(name ~= '*', 'name "*" must be the only one')
            assert(mod[name] ~= nil, string.format('name "%s" not found in module "%s"', name, moduleName))
            _G[name] = mod[name]
        end
    end
end

pcall = wrap(pcall, function(origPcall)
    return function(...)
        local fl = setYieldAllowed(false) -- important when called from coroutine
        local retVals = {origPcall(...)}
        setYieldAllowed(fl)
        return table.unpack(retVals)
    end
end)

unloadPlugin = wrap(unloadPlugin, function(origUnloadPlugin)
    return function(name, options)
        options = options or {}
        local op = 0
        if options.force then op = op | 1 end
        origUnloadPlugin(name, op)
    end
end)

quit = quitSimulator
exit = quitSimulator

printToConsole = print
if auxFunc('headless') then
    function _S.printAsync(s)
        printToConsole(s)
    end
else
    function _S.printAsync(s)
        addLog(450 + 0x0f000, s)
    end
end

tostring = wrap(tostring, function(origToString)
    return function(...)
        local lb = setAutoYield(false)
        local retVals = {origToString(...)}
        setAutoYield(lb)
        return table.unpack(retVals)
    end
end)

function print(...)
    local lb = setAutoYield(false)
    local a = table.pack(...)
    local s = ''
    for i = 1, a.n do
        s = s .. (i > 1 and ', ' or '') .. _S.anyToString(a[i], {omitQuotes = true})
    end
    _S.printAsync(s)
    setAutoYield(lb)
end

function printf(fmt, ...)
    local lb = setAutoYield(false)
    local a = table.pack(...)
    for i = 1, a.n do
        if type(a[i]) == 'table' then
            a[i] = _S.anyToString(a[i])
        elseif a[i] == nil then
            a[i] = 'nil'
        end
    end
    print(string.format(fmt, table.unpack(a, 1, a.n)))
    setAutoYield(lb)
end

function _S.funcToString(f)
    local sim = require 'sim'
    local allModules = sim.getLoadedPlugins()
    table.insert(allModules, 1, 'sim')
    for _, objName in ipairs(allModules) do
        local obj = _G[objName]
        if obj then
            for funcName, func in pairs(obj) do
                if type(func) == 'function' and func == f then
                    return objName .. '.' .. funcName
                end
            end
        end
    end
end

function help(what)
    local sim = require 'sim'
    if what == nil then
        local simCmd = require 'simCmd'
        simCmd.help()
        return
    end
    if type(what) == 'function' then
        what = _S.funcToString(what)
        assert(what, "name not known")
    end
    assert(type(what) == 'string', 'bad type')
    print(sim.getApiInfo(-1, what))
end

function _S.tableToString(tt, opts)
    opts = opts and table.clone(opts) or {}
    opts.visitedTables = opts.visitedTables and table.clone(opts.visitedTables) or {}
    opts.maxLevel = opts.maxLevel or 99
    opts.indentString = opts.indentString or '    '
    opts.maxLevel = opts.maxLevel - 1
    opts.omitQuotes = false
    opts.longStringThreshold = 160

    if (getmetatable(tt) or {}).__tostring then return tostring(tt) end

    -- if type(tt) ~= 'table' then
    --    return _S.anyToString(tt, opts)
    -- end

    if opts.maxLevel <= 0 or opts.visitedTables[tt] then
        return tostring(tt) .. (opts.maxLevel <= 0 and ' (too deep)' or ' (already visited)')
    end

    -- print short tables in single line, unless explicitly wanted otherwise:
    if opts.indent == nil then
        opts.indent = false
        local s = _S.tableToString(tt, opts)
        if #s <= opts.longStringThreshold then return s end
        opts.indent = true
    end

    if opts.indent == true then opts.indent = 0 end
    if opts.indent then opts.indent = opts.indent + 1 end
    opts.visitedTables[tt] = true
    local sb = {}
    if table.isarray(tt) then
        table.insert(sb, '{')
        for i = 1, #tt do
            if i > 1 then table.insert(sb, ', ') end
            table.insert(sb, _S.anyToString(tt[i], opts))
        end
        table.insert(sb, '}')
    else
        table.insert(sb, '{' .. (opts.indent and '\n' or ''))
        -- Print the map content ordered according to type, then key:
        local usedKeys = {}
        for _, t in ipairs {
            'boolean', 'number', 'string', 'function', 'userdata', 'thread', 'table', 'any',
        } do
            local keys = {}
            for key, val in pairs(tt) do
                if type(val) == t or (t == 'any' and not usedKeys[key]) then
                    table.insert(keys, key)
                    usedKeys[key] = true
                end
            end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            for _, key in ipairs(keys) do
                local val = tt[key]
                if opts.indent then
                    table.insert(sb, string.rep(opts.indentString, opts.indent))
                end
                table.insert(sb, _S.tableKeyToString(key))
                table.insert(sb, ' = ')
                table.insert(sb, _S.anyToString(val, opts))
                table.insert(sb, ',' .. (opts.indent and '\n' or ' '))
            end
        end
        if opts.indent then table.insert(sb, string.rep(opts.indentString, opts.indent - 1)) end
        table.insert(sb, '}')
    end
    return table.concat(sb)
end

function _S.anyToString(x, opts)
    opts = opts or {}
    local t = type(x)
    if t == 'nil' then
        return tostring(nil)
    elseif t == 'table' then
        if isbuffer(x) then
            return string.format('[buffer (%s bytes)]', #x)
        else
            local mt = getmetatable(x) or {}
            if opts.display and mt.__todisplay then return mt.__todisplay(x, opts) end
            if mt.__tostring then return tostring(x) end
            -- displays inside table won't render good:
            opts = table.update({}, opts, {display = false})
            return _S.tableToString(x, opts)
        end
    elseif t == 'string' then
        return _S.getShortString(x, opts)
    elseif t == 'number' then
        return _S.numberToString(x, opts)
    else
        return tostring(x)
    end
end

function _S.numberToString(x, opts)
    if math.type(x) ~= 'float' then
        return tostring(x)
    end

    opts = opts and table.clone(opts) or {}
    opts.numFloatDigits = math.max(0, opts.numFloatDigits or 6)
    opts.stripTrailingZeros = opts.stripTrailingZeros ~= false

    local s = string.format('%.' .. opts.numFloatDigits .. 'f', x)
    if opts.stripTrailingZeros then
        local i, d = table.unpack(string.split(s, '%.'))
        d = string.gsub(d or '', '0*$', '')
        s = i .. '.' .. d
    end
    return s
end

function _S.getShortString(x, opts)
    opts = opts or {}
    opts.omitQuotes = opts.omitQuotes or false
    opts.allowBinary = opts.allowBinary or false
    opts.allowBinary = true

    if type(x) == 'string' then
        if not string.isprintable(x) and not opts.allowBinary then
            return string.format('[binary string (%s bytes)]', #x)
        end
        if opts.longStringThreshold and #x > opts.longStringThreshold then
            return string.format('[long string (%s bytes)]', #x)
        end
        if opts.omitQuotes then
            return string.format('%s', x)
        else
            return string.format("'%s'", string.escapequotes(x, '\''))
        end
    end
    return "[not a string]"
end

function _S.isIdentifier(x)
    return type(x) == 'string' and x:match('^[a-zA-Z_][a-zA-Z0-9_]*$') ~= nil
end

function _S.tableKeyToString(x)
    if type(x) == 'string' then
        if _S.isIdentifier(x) then
            return x
        else
            return '[' .. _S.getShortString(x) .. ']'
        end
    else
        return '[' .. tostring(x) .. ']'
    end
end

function getAsString(...)
    local lb = setAutoYield(false)
    local a = table.pack(...)
    local s = ''
    for i = 1, a.n do
        if i > 1 then s = s .. ', ' end
        s = s .. _S.anyToString(a[i])
    end
    setAutoYield(lb)
    return s
end

function getAsDisplayString(...)
    -- for simCmd statusbar output etc...
    local lb = setAutoYield(false)
    local a = table.pack(...)
    local s = {}
    for i = 1, a.n do
        if i > 1 then table.insert(s, ', ') end
        table.insert(s, _S.anyToString(a[i], {display = true}))
    end
    setAutoYield(lb)
    return string.blockhstack(s, 0)
end

function _S.sysCallBase_init()
    -- Hook function, registered further down. Needs to work without sim.lua!
    if sysCall_thread then __coroutine__ = coroutine.create(sysCall_thread) end
end

function _S.sysCallBase_nonSimulation()
    -- Hook function, registered further down. Needs to work without sim.lua!
    if __coroutine__ then
        if coroutine.status(__coroutine__) ~= 'dead' then
            local _, ays = getAutoYield() -- save (autoYield should be on a thread-basis)
            if _S.coroutineAutoYields[__coroutine__] then
                setAutoYield(_S.coroutineAutoYields[__coroutine__])
            end
            local ok, errorMsg = coroutine.resume(__coroutine__)
            _, _S.coroutineAutoYields[__coroutine__] = getAutoYield()
            setAutoYield(ays) -- restore
            if errorMsg then error(debug.traceback(__coroutine__, errorMsg), 2) end
        end
    end
end

function _S.sysCallBase_actuation()
    -- Hook function, registered further down. Needs to work without sim.lua!
    if __coroutine__ then
        if coroutine.status(__coroutine__) ~= 'dead' then
            local _, ays = getAutoYield() -- save (autoYield should be on a thread-basis)
            if _S.coroutineAutoYields[__coroutine__] then
                setAutoYield(_S.coroutineAutoYields[__coroutine__])
            end
            local ok, errorMsg = coroutine.resume(__coroutine__)
            _, _S.coroutineAutoYields[__coroutine__] = getAutoYield()
            setAutoYield(ays) -- restore
            if errorMsg then error(debug.traceback(__coroutine__, errorMsg), 2) end
        end
    end
end

function _evalExec(inputStr)
    local sim = require 'sim'
    local function setConvenienceVars()
        H = sim.getObject
        SEL = sim.getObjectSel()
        if _G.sim and _G.sim.Object then
            SEL = map(function(h) return _G.sim.Object(h) end, SEL)
        end
        SEL1 = SEL[#SEL]
    end
    local function pfunc(theStr)
        if sim.getNamedBoolParam('simCmd.setConvenienceVars') ~= false then
            setConvenienceVars()
        end

        local func, err = load('return ' .. theStr)
        local rr = true
        if not func then
            rr = false
            func, err = load(theStr)
        end
        if func then
            local ret = nil
            local success, err = pcall(function() ret = table.pack(func()) end)
            if success then
                if ret.n > 0 and rr then
                    print(getAsDisplayString(table.unpack(ret, 1, ret.n)))
                end
            else
                addLog(420 | 0x0f000, err)
            end
        else
            addLog(420 | 0x0f000, err)
        end

        if sim.getNamedBoolParam('simCmd.setConvenienceVars') ~= false then
            if H ~= sim.getObject then
                addLog(430 | 0x0f000, "cannot change 'H' variable")
            end
            setConvenienceVars()
        end
    end
    pcall(pfunc, inputStr)
end

function _evalExecRet(inputStr)
    printToConsole("in base.lua, _evalExecRet: " .. inputStr)
    local reply = "_*empty*_"
    local function pfunc(theStr)
        local func, err = load('return ' .. theStr)
        local rr = true
        if not func then
            rr = false
            func, err = load(theStr)
        end
        if func then
            local ret = nil
            local success, err = pcall(function() ret = table.pack(func()) end)
            if success then
                if ret.n > 0 and rr then
                    reply = ret
                end
            else
                reply = "Error: " .. ret[2]
            end
        else
            reply = "Error: " .. err
        end
    end
    pcall(pfunc, inputStr)
    return reply
end

function _getCompletion(input, pos)
    local var = require 'var'
    local ret = {}
    if pos == #input then
        local what = input:match('[_%a][_%w%.:]*$')
        if what then
            local base, sep, ext = what:match('^(.-)([.:])([^.:]+)$')
            if base then
                base = var.getvar(base)
            else
                base, ext = _G, what
            end

            if base then
                local lookupTable = base
                if sep == ":" and type(base) == "table" and type(base.__methods) == "table" then
                    lookupTable = base.__methods
                end

                for k in pairs(lookupTable) do
                    if k:startswith(ext) and #k > #ext then
                        table.insert(ret, k:sub(#ext + 1))
                    end
                end
            end
        end
    end
    return ret
end

function _getCalltip(input, pos)
    local sim = require 'sim'
    local parserx = require 'parserx'
    local cc = parserx.getCallContexts(input, pos)
    if cc and #cc > 0 then
        local sym = cc[#cc][1]
        return sim.getApiInfo(-1, sym)
    else
        return ''
    end
end

-- IMPORTANT: put std module requires here, after wrap(require, ...) otherwise
--            code editor won't load the -ce files (see auxFunc('usedmodule' ...))
require('buffer')
require('mathx')
require('stringx')
require('tablex')
import('functional', '*')
import('var', '*')
import('utils')

_S.coroutineAutoYields = {}
registerScriptFuncHook('sysCall_init', '_S.sysCallBase_init', false) -- hook on *before* init is incompatible with implicit module load...
registerScriptFuncHook('sysCall_nonSimulation', '_S.sysCallBase_nonSimulation', true)
registerScriptFuncHook('sysCall_actuation', '_S.sysCallBase_actuation', true)

if not _DEVMODE or not (type(_DEVMODE) == 'table' and _DEVMODE.NO_LAZYLOADERS) then
    require 'deprecated.lazyLoaders'
end
