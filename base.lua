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

quit=quitSimulator
exit=quitSimulator

printToConsole=print
if auxFunc('headless') then
    function print(...)
        local lb=setAutoYield(false)
        printToConsole(getAsString(...))
        setAutoYield(lb)
    end
else
    function print(...)
        local lb=setAutoYield(false)
        addLog(450+0x0f000,getAsString(...))
        setAutoYield(lb)
    end
end

function printf(fmt,...)
    local a=table.pack(...)
    for i=1,a.n do
        if type(a[i])=='table' then
            a[i]=_S.anyToString(a[i],{},99)
        elseif type(a[i])=='nil' then
            a[i]='nil'
        end
    end
    print(string.format(fmt,table.unpack(a,1,a.n)))
end

function printBytes(x)
    s=''
    for i=1,#x do
        s=s..string.format('%s%02x',i>1 and ' ' or '',string.byte(x:sub(i,i)))
    end
    print(s)
end

function isArray(t)
    local m=0
    local count=0
    for k,v in pairs(t) do
        if type(k)=="number" and math.floor(k)==k and k>0 then
            if k>m then m=k end
            count=count+1
        else
            return false
        end
    end
    return m<=count
end

function _S.tableToString(tt,visitedTables,maxLevel,indent)
    indent = indent or 0
    maxLevel=maxLevel-1
    if type(tt) == 'table' then
        if maxLevel<=0 then
            return tostring(tt)
        else
            if  visitedTables[tt] then
                return tostring(tt)..' (already visited)'
            else
                visitedTables[tt]=true
                local sb = {}
                if isArray(tt) then
                    table.insert(sb, '{')
                    for i = 1, #tt do
                        table.insert(sb, _S.anyToString(tt[i], visitedTables,maxLevel, indent))
                        if i < #tt then table.insert(sb, ', ') end
                    end
                    table.insert(sb, '}')
                else
                    table.insert(sb, '{\n')
                    -- Print the map content ordered according to type, then key:
                    local tp={{'boolean',false},{'number',true},{'string',true},{'function',false},{'userdata',false},{'thread',true},{'table',false},{'any',false}}
                    local ts={}
                    local usedKeys={}
                    for j=1,#tp,1 do
                        local a={}
                        ts[#ts+1]=a
                        for key,val in pairs(tt) do
                            if type(key)==tp[j][1] or (tp[j][1]=='any' and usedKeys[key]==nil) then
                                a[#a+1]=key
                                usedKeys[key]=true
                            end
                        end
                        if tp[j][2] then
                            table.sort(a)
                        end
                        for k=1,#a,1 do
                            local key=a[k]
                            local val=tt[key]
                            table.insert(sb, string.rep(' ', indent+4))
                            if type(key)=='string' then
                                table.insert(sb, _S.getShortString(key,true))
                            else
                                table.insert(sb, tostring(key))
                            end
                            table.insert(sb, '=')
                            table.insert(sb, _S.anyToString(val, visitedTables,maxLevel, indent+4))
                            table.insert(sb, ',\n')
                        end
                    end
                    table.insert(sb, string.rep(' ', indent))
                    table.insert(sb, '}')
                end
                visitedTables[tt]=false -- siblings pointing onto a same table should still be explored!
                return table.concat(sb)
            end
        end
    else
        return _S.anyToString(tt, visitedTables,maxLevel, indent)
    end
end

function _S.anyToString(x, visitedTables,maxLevel,tblindent)
    local tblindent = tblindent or 0
    if 'nil' == type(x) then
        return tostring(nil)
    elseif 'table' == type(x) then
        return _S.tableToString(x, visitedTables,maxLevel, tblindent)
    elseif 'string' == type(x) then
        return _S.getShortString(x)
    else
        return tostring(x)
    end
end

function _S.getShortString(x,omitQuotes)
    if type(x)=='string' then
        if string.find(x,"\0") then
            return "[buffer string]"
        else
            local a,b=string.gsub(x,"[%a%d%p%s]", "@")
            if b~=#x then
                return "[string containing special chars]"
            else
                if #x>160 then
                    return "[long string]"
                else
                    if omitQuotes then
                        return string.format('%s', x)
                    else
                        return string.format('"%s"', x)
                    end
                end
            end
        end
    end
    return "[not a string]"
end

function getAsString(...)
    local lb=setAutoYield(false)
    local a={...}
    local t=''
    if #a==1 and type(a[1])=='string' then
--        t=string.format('"%s"', a[1])
        t=string.format('%s', a[1])
    else
        for i=1,#a,1 do
            if i~=1 then
                t=t..','
            end
            if type(a[i])=='table' then
                t=t.._S.tableToString(a[i],{},99)
            else
                t=t.._S.anyToString(a[i],{},99)
            end
        end
    end
    if #a==0 then
        t='nil'
    end
    setAutoYield(lb)
    return(t)
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

setupLazyLoaders()
