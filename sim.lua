local sim={}
__HIDDEN__={}
__HIDDEN__.debug={}

-- Old stuff, mainly for backward compatibility:
----------------------------------------------------------
function sim.include(relativePathAndFile,cmd)
    require("sim_old")
    return sim.include(relativePathAndFile,cmd)
end
function sim.includeRel(relativePathAndFile,cmd)
    require("sim_old")
    return sim.includeRel(relativePathAndFile,cmd)
end
function sim.includeAbs(absPathAndFile,cmd)
    require("sim_old")
    return sim.includeAbs(absPathAndFile,cmd)
end
function sim.canScaleObjectNonIsometrically(objHandle,scaleAxisX,scaleAxisY,scaleAxisZ)
    require("sim_old")
    return sim.canScaleObjectNonIsometrically(objHandle,scaleAxisX,scaleAxisY,scaleAxisZ)
end
function sim.canScaleModelNonIsometrically(modelHandle,scaleAxisX,scaleAxisY,scaleAxisZ,ignoreNonScalableItems)
    require("sim_old")
    return sim.canScaleModelNonIsometrically(modelHandle,scaleAxisX,scaleAxisY,scaleAxisZ,ignoreNonScalableItems)
end
function sim.scaleModelNonIsometrically(modelHandle,scaleAxisX,scaleAxisY,scaleAxisZ)
    require("sim_old")
    return sim.scaleModelNonIsometrically(modelHandle,scaleAxisX,scaleAxisY,scaleAxisZ)
end
function sim.UI_populateCombobox(ui,id,items_array,exceptItems_map,currentItem,sort,additionalItemsToTop_array)
    require("sim_old")
    return sim.UI_populateCombobox(ui,id,items_array,exceptItems_map,currentItem,sort,additionalItemsToTop_array)
end
----------------------------------------------------------


-- Hidden, internal functions:
----------------------------------------------------------
function __HIDDEN__.comparableTables(t1,t2)
    return ( isArray(t1)==isArray(t2) ) or ( isArray(t1) and #t1==0 ) or ( isArray(t2) and #t2==0 )
end

function __HIDDEN__.tableToString(tt,visitedTables,maxLevel,indent)
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
                        table.insert(sb, __HIDDEN__.anyToString(tt[i], visitedTables,maxLevel, indent))
                        if i < #tt then table.insert(sb, ', ') end
                    end
                    table.insert(sb, '}')
                else
                    table.insert(sb, '{\n')
                    -- Print the map content ordered according to type, then key:
                    local a = {}
                    for n in pairs(tt) do table.insert(a, n) end
                    table.sort(a)
                    local tp={'boolean','number','string','function','userdata','thread','table'}
                    for j=1,#tp,1 do
                        for i,n in ipairs(a) do
                            if type(tt[n])==tp[j] then
                                table.insert(sb, string.rep(' ', indent+4))
                                table.insert(sb, tostring(n))
                                table.insert(sb, '=')
                                table.insert(sb, __HIDDEN__.anyToString(tt[n], visitedTables,maxLevel, indent+4))
                                table.insert(sb, ',\n')
                            end
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
        return __HIDDEN__.anyToString(tt, visitedTables,maxLevel, indent)
    end
end

function __HIDDEN__.anyToString(x, visitedTables,maxLevel,tblindent)
    local tblindent = tblindent or 0
    if 'nil' == type(x) then
        return tostring(nil)
    elseif 'table' == type(x) then
        return __HIDDEN__.tableToString(x, visitedTables,maxLevel, tblindent)
    elseif 'string' == type(x) then
        return __HIDDEN__.getShortString(x)
    else
        return tostring(x)
    end
end

function __HIDDEN__.getShortString(x)
    if type(x)=='string' then
        if string.find(x,"\0") then
            return "<buffer string>"
        else
            local a,b=string.gsub(x,"[%a%d%p%s]", "@")
            if b~=#x then
                return "<string containing special chars>"
            else
                if #x>160 then
                    return "<long string>"
                else
                    return string.format('"%s"', x)
                end
            end
        end
    end
    return "<not a string>"
end

function __HIDDEN__.executeAfterLuaStateInit()
    sim.registerScriptFunction('sim.setDebugWatchList@sim','sim.setDebugWatchList(table vars)')
    sim.registerScriptFunction('sim.getUserVariables@sim','table variables=sim.getUserVariables()')
    __HIDDEN__.initGlobals={}
    for key,val in pairs(_G) do
        __HIDDEN__.initGlobals[key]=true
    end
    __HIDDEN__.initGlobals.__HIDDEN__=nil
    __HIDDEN__.executeAfterLuaStateInit=nil
end
----------------------------------------------------------

-- Hidden, debugging functions:
----------------------------------------------------------
function __HIDDEN__.debug.entryFunc(info)
    local scriptName=info[1]
    local funcName=info[2]
    local funcType=info[3]
    local callIn=info[4]
    local debugLevel=info[5]
    local sysCall=info[6]
    local simTime=info[7]
    local simTimeStr=''
    if (debugLevel~=sim.scriptdebug_vars_interval) or (not __HIDDEN__.debug.lastInterval) or (sim.getSystemTimeInMs(-1)>__HIDDEN__.debug.lastInterval+1000) then
        __HIDDEN__.debug.lastInterval=sim.getSystemTimeInMs(-1)
        if sim.getSimulationState()~=sim.simulation_stopped then
            simTimeStr=simTime..' '
        end
        if (debugLevel>=sim.scriptdebug_vars) or (debugLevel==sim.scriptdebug_vars_interval) then
            local prefix='DEBUG: '..simTimeStr..'['..scriptName..'] '
            local t=__HIDDEN__.debug.getVarChanges(prefix)
            if t then
                t="<font color='#44B'>"..t.."</font>@html"
                sim.addStatusbarMessage(t)
            end
        end
        if (debugLevel==sim.scriptdebug_allcalls) or (debugLevel==sim.scriptdebug_callsandvars) or ( (debugLevel==sim.scriptdebug_syscalls) and sysCall) then
            local t='DEBUG: '..simTimeStr..'['..scriptName..']'
            if callIn then
                t=t..' --&gt; '
            else
                t=t..' &lt;-- '
            end
            t=t..funcName..' ('..funcType..')'
            if callIn then
                t="<font color='#44B'>"..t.."</font>@html"
            else
                t="<font color='#44B'>"..t.."</font>@html"
            end
            sim.addStatusbarMessage(t)
        end
    end
end

function __HIDDEN__.debug.getVarChanges(pref)
    local t=''
    __HIDDEN__.debug.userVarsOld=__HIDDEN__.debug.userVars
    __HIDDEN__.debug.userVars=sim.unpackTable(sim.packTable(sim.getUserVariables())) -- deep copy
    if __HIDDEN__.debug.userVarsOld then
        if __HIDDEN__.debug.watchList and type(__HIDDEN__.debug.watchList)=='table' and #__HIDDEN__.debug.watchList>0 then
            for i=1,#__HIDDEN__.debug.watchList,1 do
                local str=__HIDDEN__.debug.watchList[i]
                if type(str)=='string' then
                    local var1=__HIDDEN__.debug.getVar('__HIDDEN__.debug.userVarsOld.'..str)
                    local var2=__HIDDEN__.debug.getVar('__HIDDEN__.debug.userVars.'..str)
                    if var1~=nil or var2~=nil then
                        t=__HIDDEN__.debug.getVarDiff(pref,str,var1,var2)
                    end
                end
            end
        else
            t=__HIDDEN__.debug.getVarDiff(pref,'',__HIDDEN__.debug.userVarsOld,__HIDDEN__.debug.userVars)
        end
    end
    __HIDDEN__.debug.userVarsOld=nil
    if #t>0 then
--        t=t:sub(1,-2) -- remove last linefeed
        t=t:sub(1,-4) -- remove last linefeed
        return t
    end
end

function __HIDDEN__.debug.getVar(varName)
    local f=loadstring('return '..varName)
    if f then
        local res,val=pcall(f)
        if res and val then
            return val
        end
    end
end

function __HIDDEN__.debug.getVarDiff(pref,varName,oldV,newV)
    local t=''
    local lf='<br>'--'\n'
    if ( type(oldV)==type(newV) ) and ( (type(oldV)~='table') or __HIDDEN__.comparableTables(oldV,newV) )  then  -- comparableTables: an empty map is seen as an array
        if type(newV)~='table' then
            if newV~=oldV then
                t=t..pref..'mod: '..varName..' ('..type(newV)..'): '..__HIDDEN__.getShortString(tostring(newV))..lf
            end
        else
            if isArray(oldV) and isArray(newV) then -- an empty map is seen as an array
                -- removed items:
                if #oldV>#newV then
                    for i=1,#oldV-#newV,1 do
                        t=t..__HIDDEN__.debug.getVarDiff(pref,varName..'['..i+#oldV-#newV..']',oldV[i+#oldV-#newV],nil)
                    end
                end
                -- added items:
                if #newV>#oldV then
                    for i=1,#newV-#oldV,1 do
                        t=t..__HIDDEN__.debug.getVarDiff(pref,varName..'['..i+#newV-#oldV..']',nil,newV[i+#newV-#oldV])
                    end
                end
                -- modified items:
                local l=math.min(#newV,#oldV)
                for i=1,l,1 do
                    t=t..__HIDDEN__.debug.getVarDiff(pref,varName..'['..i..']',oldV[i],newV[i])
                end
            else
                local nvarName=varName
                if nvarName~='' then nvarName=nvarName..'.' end
                -- removed items:
                for k,vo in pairs(oldV) do
                    if newV[k]==nil then
                        t=t..__HIDDEN__.debug.getVarDiff(pref,nvarName..k,vo,nil)
                    end
                end
                
                -- added items:
                for k,vn in pairs(newV) do
                    if oldV[k]==nil then
                        t=t..__HIDDEN__.debug.getVarDiff(pref,nvarName..k,nil,vn)
                    end
                end
                
                -- modified items:
                for k,vo in pairs(oldV) do
                    if newV[k] then
                        t=t..__HIDDEN__.debug.getVarDiff(pref,nvarName..k,vo,newV[k])
                    end
                end
            end
        end
    else
        if oldV==nil then
            if type(newV)~='table' then
                t=t..pref..'new: '..varName..' ('..type(newV)..'): '..__HIDDEN__.getShortString(tostring(newV))..lf
            else
                t=t..pref..'new: '..varName..' ('..type(newV)..')'..lf
                if isArray(newV) then
                    for i=1,#newV,1 do
                        t=t..__HIDDEN__.debug.getVarDiff(pref,varName..'['..i..']',nil,newV[i])
                    end
                else
                    local nvarName=varName
                    if nvarName~='' then nvarName=nvarName..'.' end
                    for k,v in pairs(newV) do
                        t=t..__HIDDEN__.debug.getVarDiff(pref,nvarName..k,nil,v)
                    end
                end
            end
        elseif newV==nil then
            if type(oldV)~='table' then
                t=t..pref..'del: '..varName..' ('..type(oldV)..'): '..__HIDDEN__.getShortString(tostring(oldV))..lf
            else
                t=t..pref..'del: '..varName..' ('..type(oldV)..')'..lf
            end
        else
            -- variable changed type.. register that as del and new:
            t=t..__HIDDEN__.debug.getVarDiff(pref,varName,oldV,nil)
            t=t..__HIDDEN__.debug.getVarDiff(pref,varName,nil,newV)
        end
    end
    return t
end
----------------------------------------------------------

-- Various useful functions:
----------------------------------------------------------
function sim.getObjectsWithTag(tagName,justModels)
    local retObjs={}
    local objs=sim.getObjectsInTree(sim.handle_scene)
    for i=1,#objs,1 do
        if (not justModels) or (sim.boolAnd32(sim.getModelProperty(objs[i]),sim.modelproperty_not_model)==0) then
            local dat=sim.readCustomDataBlockTags(objs[i])
            if dat then
                for j=1,#dat,1 do
                    if dat[j]==tagName then
                        retObjs[#retObjs+1]=objs[i]
                        break
                    end
                end
            end
        end
    end
    return retObjs
end

function sim.getObjectHandle_noErrorNoSuffixAdjustment(name)
    local suff=sim.getNameSuffix(nil)
    sim.setNameSuffix(-1)
    local retVal=sim.getObjectHandle(name..'@silentError')
    sim.setNameSuffix(suff)
    return retVal
end

function sim.executeLuaCode(theCode)
    local f=loadstring(theCode)
    if f then
        local a,b=pcall(f)
        return a,b
    else
        return false,'compilation error'
    end
end

function sim.fastIdleLoop(enable)
    local data=sim.readCustomDataBlock(sim.handle_app,'__IDLEFPSSTACKSIZE__')
    local stage=0
    local defaultIdleFps
    if data then
        data=sim.unpackInt32Table(data)
        stage=data[1]
        defaultIdleFps=data[2]
    else
        defaultIdleFps=sim.getInt32Parameter(sim.intparam_idle_fps)
    end
    if enable then
        stage=stage+1
    else
        if stage>0 then
            stage=stage-1
        end
    end
    if stage>0 then
        sim.setInt32Parameter(sim.intparam_idle_fps,0)
    else
        sim.setInt32Parameter(sim.intparam_idle_fps,defaultIdleFps)
    end
    sim.writeCustomDataBlock(sim.handle_app,'__IDLEFPSSTACKSIZE__',sim.packInt32Table({stage,defaultIdleFps}))
end

function sim.isPluginLoaded(pluginName)
    local index=0
    local moduleName=''
    while moduleName do
        moduleName=sim.getModuleName(index)
        if (moduleName==pluginName) then
            return(true)
        end
        index=index+1
    end
    return(false)
end

function isArray(t)
    local i = 0
    for _ in pairs(t) do
        i = i + 1
        if t[i] == nil then return false end
    end
    return true
end

function sim.setDebugWatchList(l)
    __HIDDEN__.debug.watchList=l
end

function sim.getUserVariables()
    local ng={}
    if __HIDDEN__.initGlobals then
        for key,val in pairs(_G) do
            if not __HIDDEN__.initGlobals[key] then
                ng[key]=val
            end
        end
    else
        ng=_G
    end
    -- hide a few additional system variables:
    ng.sim_current_script_id=nil
    ng.sim_call_type=nil
    ng.sim_code_function_to_run=nil
    ng.__notFirst__=nil
    ng.__scriptCodeToRun__=nil
    ng.__HIDDEN__=nil
    return ng
end

printToConsole=print -- keep this in front of the new print definition!

function print(...)
    local a={...}
    local t=''
    if #a==1 and type(a[1])=='string' then
        t=string.format('"%s"', a[1])
    else
        for i=1,#a,1 do
            if i~=1 then
                t=t..','
            end
            if type(a[i])=='table' then
                t=t..__HIDDEN__.tableToString(a[i],{},99)
            else
                t=t..__HIDDEN__.anyToString(a[i],{},99)
            end
        end
    end
    sim.addStatusbarMessage(t)
end

function printf(fmt,...)
    local a={...}
    for i=1,#a do
        if type(a[i])=='table' then
            a[i]=__HIDDEN__.anyToString(a[i],{},99)
        end
    end
    print(string.format(fmt,unpack(a)))
end

----------------------------------------------------------

return sim