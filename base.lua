__lazyLoadModules={'sim','simIK','simUI','simGeom','simMujoco','simAssimp','simBubble','simCHAI3D','simMTB','simOMPL','simOpenMesh','simQHull','simRRS1','simSDF','simSubprocess','simSurfRec','simURDF','simVision','simWS','simZMQ','simIM','simEigen','simIGL','simICP'}

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
    local nm=table.unpack{...}
    for i=1,#__lazyLoadModules,1 do
        if __lazyLoadModules[i]==nm then
            if not __inLazyLoader or __inLazyLoader==0 then
                __didExplicitLoading=true
            end
        end
    end
    local fl=setThreadSwitchAllowed(false) -- important when called from coroutine
    local retVals={_S.require(...)}
    setThreadSwitchAllowed(fl)
    auxFunc('usedmodule',nm)
    return table.unpack(retVals)
end

_S.pcall=pcall
function pcall(...)
    local fl=setThreadSwitchAllowed(false) -- important when called from coroutine
    local retVals={_S.pcall(...)}
    setThreadSwitchAllowed(fl)
    return table.unpack(retVals)
end

quit=quitSimulator
exit=quitSimulator

printToConsole=print
function print(...)
    local lb=setThreadAutomaticSwitch(false)
    addLog(450+0x0f000,getAsString(...))
    setThreadAutomaticSwitch(lb)
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
    local lb=setThreadAutomaticSwitch(false)
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
    setThreadAutomaticSwitch(lb)
    return(t)
end

-- Make registerScriptFuncHook work also with a function as arg 2:
function _S.registerScriptFuncHook(funcNm,func,before)
    local retVal
    if type(func)=='string' then
        retVal=_S.registerScriptFuncHookOrig(funcNm,func,before)
    else
        local str=tostring(func)
        retVal=_S.registerScriptFuncHookOrig(funcNm,'_S.'..str,before)
        _S[str]=func
    end
    return retVal
end
_S.registerScriptFuncHookOrig=registerScriptFuncHook
registerScriptFuncHook=_S.registerScriptFuncHook

function moduleLazyLoader(name)
    local proxy={}
    local mt={
        __index=function(_,key)
            if key=='registerScriptFuncHook' then
                return registerScriptFuncHook
            else
                if __didExplicitLoading then
                    error(name..": implicit loading of modules has been disabled because at least one known module was loaded explicitly.")
                else
                    if not __inLazyLoader then
                        __inLazyLoader=0
                    end
                    __inLazyLoader=__inLazyLoader+1
                    _G[name]=require(name)
                    __inLazyLoader=__inLazyLoader-1
                    addLog(430,"module '"..name.."' was implicitly loaded.")
                    return _G[name][key]
                end
            end
        end,
    }
    setmetatable(proxy,mt)
    _G[name]=proxy
    return proxy
end

for i=1,#__lazyLoadModules,1 do
    _G[__lazyLoadModules[i]]=moduleLazyLoader(__lazyLoadModules[i])
end

require('stringx')
require('tablex')
require('checkargs')
require('matrix')
require('grid')
require('functional')
require('var')

