__lazyLoadModules={'sim','simIK','simUI','simGeom','simMujoco','simAssimp','simBubble','simCHAI3D','simMTB','simOMPL','simOpenMesh','simQHull','simRRS1','simSDF','simSubprocess','simSurfRec','simURDF','simVision','simWS','simZMQ','simIM','simEigen','simIGL','simICP','simROS','simROS2'}

__oldModeConsts={syscb_init=true,syscb_cleanup=true,syscb_regular=true,syscb_actuation=true,syscb_sensing=true,syscb_nonsimulation=true,syscb_beforesimulation=true,syscb_aftersimulation=true,syscb_suspended=true,syscb_suspend=true,syscb_resume=true,syscb_beforeinstanceswitch=true,syscb_afterinstanceswitch=true,syscb_beforecopy=true,syscb_aftercopy=true,getScriptExecutionCount=true,mainscriptcall_initialization=true,mainscriptcall_cleanup=true,mainscriptcall_regular=true,childscriptcall_initialization=true,childscriptcall_cleanup=true,childscriptcall_actuation=true,childscriptcall_sensing=true,customizationscriptcall_initialization=true,customizationscriptcall_cleanup=true,customizationscriptcall_nonsimulation=true,customizationscriptcall_lastbeforesimulation=true,customizationscriptcall_firstaftersimulation=true,customizationscriptcall_simulationactuation=true,customizationscriptcall_simulationsensing=true,customizationscriptcall_simulationpause=true,customizationscriptcall_simulationpausefirst=true,customizationscriptcall_simulationpauselast=true,customizationscriptcall_lastbeforeinstanceswitch=true,customizationscriptcall_firstafterinstanceswitch=true,customizationscriptcall_beforecopy=true,customizationscriptcall_aftercopy=true}

math.atan2 = math.atan2 or math.atan
math.pow = math.pow or function(a,b) return a^b end
math.log10 = math.log10 or function(a) return math.log(a,10) end
math.ldexp = math.ldexp or function(x,exp) return x*2.0^exp end
math.frexp = math.frexp or function(x) return auxFunc('frexp',x) end
math.mod = math.mod or math.fmod
table.getn = table.getn or function(a) return #a end
if _VERSION~='Lua 5.1' then
    loadstring = load
end
if unpack then
    -- Lua5.1
    table.pack = function(...) return { n = select("#", ...), ... } end
    table.unpack = unpack
else
    unpack = table.unpack
end

_S.require=require
function require(...)
    local requiredName=table.unpack{...}
    for i,lazyModName in ipairs(__lazyLoadModules) do
        if lazyModName==requiredName then
            if not __inLazyLoader or __inLazyLoader==0 then
                if __usedLazyLoaders then
                    addLog(430,"implicit loading of modules has been disabled because one known module ("..requiredName..") was loaded explicitly.")
                end
                removeLazyLoaders()
            end
        end
    end
    local fl=setYieldAllowed(false) -- important when called from coroutine
    local retVals={_S.require(...)}
    setYieldAllowed(fl)
    auxFunc('usedmodule',requiredName)
    return table.unpack(retVals)
end

function rerequire(name)
    local searchPaths = string.split(package.path, package.config:sub(3, 3))
    local nameWithSlashes = name:gsub('%.', '/')
    for _, searchPath in ipairs(searchPaths) do
        local exists = false
        local fileName = searchPath:gsub('?', nameWithSlashes)
        local f = io.open(fileName, 'r')
        if f ~= nil then
            exists = true
            io.close(f)
        end
        if exists then
            local success, result = xpcall(
                function(filename, env)
                    local f = assert(loadfile(filename))
                    return f()
                end,
                function(err)
                    return debug.traceback(err)
                end,
                fileName
            )
            if success then
                return result
            else
                sim.addLog(sim.verbosity_errors, result)
                return
            end
        end
    end
end

_S.pcall=pcall
function pcall(...)
    local fl=setYieldAllowed(false) -- important when called from coroutine
    local retVals={_S.pcall(...)}
    setYieldAllowed(fl)
    return table.unpack(retVals)
end

_S.unloadPlugin=unloadPlugin
function unloadPlugin(name,options)
    options=options or {}
    local op=0
    if options.force then
        op=op|1
    end
    _S.unloadPlugin(name,op)
end

quit = quitSimulator
exit = quitSimulator

printToConsole=print
if auxFunc('headless') then
    function _S.printAsync(s)
        printToConsole(s)
    end
else
    function _S.printAsync(s)
        addLog(450 + 0x0f000, s)
    end
end

function print(...)
    local a = table.pack(...)
    local s = ''
    for i = 1, a.n do
        s = s .. (i > 1 and ', ' or '') .. _S.anyToString(a[i], {omitQuotes=true})
    end

    local lb = setAutoYield(false)
    _S.printAsync(s)
    setAutoYield(lb)
end

function printf(fmt, ...)
    local a = table.pack(...)
    for i = 1, a.n do
        a[i] = _S.anyToString(a[i])
    end
    print(string.format(fmt, table.unpack(a, 1, a.n)))
end

function printBytes(x)
    local s = ''
    for i = 1, #x do
        s = s .. string.format('%s%02x', i > 1 and ' ' or '', string.byte(x:sub(i, i)))
    end
    print(s)
end

function funcToString(f)
    for _, objName in ipairs(__lazyLoadModules) do
        local obj = _G[objName]
        if obj then
            local mt = getmetatable(obj)
            if not mt or not mt.__moduleLazyLoader then
                for funcName, func in pairs(obj) do
                    if type(func) == 'function' and func == f then
                        return objName .. '.' .. funcName
                    end
                end
            end
        end
    end
end

function help(what)
    if what == nil then
        simCmd = require 'simCmd'
        simCmd.help()
        return
    end
    if type(what) == 'function' then
        what = funcToString(what)
        assert(what, "name not known")
    end
    assert(type(what) == 'string', 'bad type')
    print(sim.getApiInfo(-1, what))
end

require 'tablex'

function _S.tableToString(tt, opts)
    opts = opts and table.clone(opts) or {}
    opts.visitedTables = opts.visitedTables and table.clone(opts.visitedTables) or {}
    opts.maxLevel = opts.maxLevel or 99
    opts.indent = opts.indent or 0
    opts.maxLevel = opts.maxLevel - 1
    opts.omitQuotes = false
    opts.longStringThreshold = 160

    if type(tt) == 'table' then
        if opts.maxLevel <= 0 then
            return tostring(tt)
        else
            if opts.oneLine == nil then
                opts.oneLine = true
                local s = _S.tableToString(tt, opts)
                if #s <= opts.longStringThreshold then return s end
                opts.oneLine = false
            end
            if opts.visitedTables[tt] then
                return tostring(tt) .. ' (already visited)'
            else
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
                    table.insert(sb, '{' .. (opts.oneLine and '' or '\n'))
                    -- Print the map content ordered according to type, then key:
                    local usedKeys = {}
                    for _, t in ipairs{'boolean', 'number', 'string', 'function', 'userdata', 'thread', 'table', 'any'} do
                        local keysByType = {}
                        for key, val in pairs(tt) do
                            if type(val) == t or (t == 'any' and not usedKeys[key]) then
                                table.insert(keysByType, key)
                                usedKeys[key]=true
                            end
                        end
                        table.sort(keysByType)
                        for _, key in ipairs(keysByType) do
                            local val = tt[key]
                            table.insert(sb, opts.oneLine and '' or string.rep(' ', opts.indent + 4))
                            if type(key) == 'string' then
                                table.insert(sb, _S.getShortString(key, {omitQuotes=true}))
                            else
                                table.insert(sb, tostring(key))
                            end
                            table.insert(sb, ' = ')
                            opts.indent = opts.indent + 4
                            table.insert(sb, _S.anyToString(val, opts))
                            opts.indent = opts.indent - 4
                            table.insert(sb, ',' .. (opts.oneLine and ' ' or '\n'))
                        end
                    end
                    table.insert(sb, opts.oneLine and '' or string.rep(' ', opts.indent))
                    table.insert(sb, '}')
                end
                -- siblings pointing onto a same table should still be explored!
                opts.visitedTables[tt] = false
                return table.concat(sb)
            end
        end
    else
        return _S.anyToString(tt, opts)
    end
end

function _S.anyToString(x, opts)
    local t = type(x)
    if t == 'nil' then
        return tostring(nil)
    elseif t == 'table' then
        return _S.tableToString(x, opts)
    elseif t == 'string' then
        return _S.getShortString(x, opts)
    else
        return tostring(x)
    end
end

function _S.getShortString(x, opts)
    opts = opts or {}
    opts.omitQuotes = opts.omitQuotes or false

    if type(x) == 'string' then
        if string.find(x,"\0") then
            return "[buffer string]"
        else
            local a, b = string.gsub(x,"[%a%d%p%s]", "@")
            if b ~= #x then
                return "[string containing special chars]"
            else
                if opts.longStringThreshold and #x > opts.longStringThreshold then
                    return "[long string]"
                else
                    if opts.omitQuotes then
                        return string.format('%s', x)
                    else
                        return string.format("'%s'", x)
                    end
                end
            end
        end
    end
    return "[not a string]"
end

function getAsString(...)
    local lb = setAutoYield(false)
    local a = table.pack(...)
    local s = ''
    for i = 1, a.n do
        s = s .. (i > 1 and ', ' or '') .. _S.anyToString(a[i])
    end
    setAutoYield(lb)
    return s
end

function moduleLazyLoader(name)
    local proxy={}
    local mt={
        __moduleLazyLoader={},
        __index=function(_,key)
            if __oldModeConsts[key] then
                auxFunc('deprecatedScriptMode')
            end
            if key=='registerScriptFuncHook' then
                return registerScriptFuncHook
            else
                if not __inLazyLoader then
                    __inLazyLoader=0
                end
                __inLazyLoader=__inLazyLoader+1
                _G[name]=require(name)
                __inLazyLoader=__inLazyLoader-1
                addLog(430,"module '"..name.."' was implicitly loaded.")
                __usedLazyLoaders=true
                return _G[name][key]
            end
        end,
    }
    setmetatable(proxy,mt)
    _G[name]=proxy
    return proxy
end

function setupLazyLoaders()
    __usedLazyLoaders=false
    for i,name in ipairs(__lazyLoadModules) do
        if not _G[name] then
            _G[name]=moduleLazyLoader(name)
        end
    end
end

function removeLazyLoaders()
    for i,name in ipairs(__lazyLoadModules) do
        if _G[name] then
            local mt=getmetatable(_G[name])
            if mt and mt.__moduleLazyLoader then
                _G[name]=nil
            end
        end
    end
    __usedLazyLoaders=nil
end

function _S.sysCallBase_init()
    -- Hook function, registered further down
    if sysCall_thread then
        __coroutine__=coroutine.create(sysCall_thread)
    end

    _S.initGlobals={}
    for key,val in pairs(_G) do
        _S.initGlobals[key]=true
    end
    _S.initGlobals._S=nil
end

function _S.sysCallBase_nonSimulation()
    -- Hook function, registered further down
    if __coroutine__ then
        if coroutine.status(__coroutine__)~='dead' then
            local _,ays=getAutoYield() -- save (autoYield should be on a thread-basis)
            if _S.coroutineAutoYields[__coroutine__] then
                setAutoYield(_S.coroutineAutoYields[__coroutine__])
            end
            local ok,errorMsg=coroutine.resume(__coroutine__)
            _,_S.coroutineAutoYields[__coroutine__]=getAutoYield()
            setAutoYield(ays) -- restore
            if errorMsg then
                error(debug.traceback(__coroutine__,errorMsg),2)
            end
        end
    end
end

function _S.sysCallBase_actuation()
    -- Hook function, registered further down
    if __coroutine__ then
        if coroutine.status(__coroutine__)~='dead' then
            local _,ays=getAutoYield() -- save (autoYield should be on a thread-basis)
            if _S.coroutineAutoYields[__coroutine__] then
                setAutoYield(_S.coroutineAutoYields[__coroutine__])
            end
            local ok,errorMsg=coroutine.resume(__coroutine__)
            _,_S.coroutineAutoYields[__coroutine__]=getAutoYield()
            setAutoYield(ays) -- restore
            if errorMsg then
                error(debug.traceback(__coroutine__,errorMsg),2)
            end
        end
    end
end

function _evalExec(inputStr)
    function pfunc(theStr)
        if sim.getNamedBoolParam('simCmd.setConvenienceVars') ~= false then
            H = sim.getObject
            SEL = sim.getObjectSel()
            SEL1 = SEL[#SEL]
        end

        local func, err = load('return '..theStr)
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
                    print(getAsString(table.unpack(ret, 1, ret.n)))
                end
            else
                sim.addLog(sim.verbosity_scripterrors | sim.verbosity_undecorated, err)
            end
        else
            sim.addLog(sim.verbosity_scripterrors | sim.verbosity_undecorated, err)
        end

        if sim.getNamedBoolParam('simCmd.setConvenienceVars') ~= false then
            if H ~= sim.getObject then
                sim.addLog(sim.verbosity_scriptwarnings | sim.verbosity_undecorated, "cannot change 'H' variable")
            end

            H = sim.getObject
            SEL = sim.getObjectSel()
            SEL1 = SEL[#SEL]
        end
    end
    pcall(pfunc, inputStr)
end

function _evalExecRet(inputStr)
    printToConsole("in base.lua, _evalExecRet: "..inputStr)
    local reply = "_*empty*_"
    function pfunc(theStr)
        local func, err = load('return '..theStr)
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
                reply = "Error: "..ret[2]
            end
        else
            reply = "Error: "..err
        end
    end
    pcall(pfunc, inputStr)
    return reply
end

function _getCompletion(input,pos)
    local ret={}
    if pos==#input then
        local what=input:match('[_%a][_%w%.]*$')
        local base,ext=what:match('^(.-)%.([^.]+)$')
        if base then
            base=getvar(base)
        else
            base,ext=_G,what
        end
        for k in pairs(base) do
            if k:startswith(ext) and #k>#ext then
                table.insert(ret,k:sub(#ext+1))
            end
        end
    end
    return ret
end

function _getCalltip(input,pos)
    local parserx=require'parserx'
    local cc=parserx.getCallContexts(input,pos)
    if cc and #cc>0 then
        local sym=cc[#cc][1]
        return sim.getApiInfo(-1,sym)
    else
        return ''
    end
end

_S.coroutineAutoYields={}
registerScriptFuncHook('sysCall_init','_S.sysCallBase_init',false) -- hook on *before* init is incompatible with implicit module load...
registerScriptFuncHook('sysCall_nonSimulation','_S.sysCallBase_nonSimulation',true)
registerScriptFuncHook('sysCall_actuation','_S.sysCallBase_actuation',true)

setupLazyLoaders()
