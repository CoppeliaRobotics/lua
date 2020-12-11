sim={}
_S={}
_S.dlg={}

math.atan2 = math.atan2 or math.atan
math.pow = math.pow or function(a,b) return a^b end
math.log10 = math.log10 or function(a) return math.log(a,10) end
math.ldexp = math.ldexp or function(x,exp) return x*2.0^exp end
math.frexp = math.frexp or function(x) return sim.auxFunc('frexp',x) end
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
    local fl
    if sim.setThreadSwitchAllowed then
        fl=sim.setThreadSwitchAllowed(false) -- important when called from coroutine
    end 
    local retVals={_S.require(...)}
    if fl then 
        sim.setThreadSwitchAllowed(fl) 
    end
    return table.unpack(retVals)
end

_S.pcall=pcall
function pcall(...)
    local fl
    if sim.setThreadSwitchAllowed then
        fl=sim.setThreadSwitchAllowed(false) -- important when called from coroutine
    end 
    local retVals={_S.pcall(...)}
    if fl then 
        sim.setThreadSwitchAllowed(fl) 
    end
    return table.unpack(retVals)
end

printToConsole=print
function print(...)
    if sim.addLog then
        local lb=sim.setThreadAutomaticSwitch(false)
        sim.addLog(sim.verbosity_scriptinfos+sim.verbosity_undecorated,getAsString(...))
        sim.setThreadAutomaticSwitch(lb)
    else
        printToConsole(...)
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

function sim.switchThread()
    if sim.getThreadSwitchAllowed() then
        if sim.isScriptRunningInThread()==1 then
            sim._switchThread()
        else
            if coroutine.running() then
                coroutine.yield()
            end
        end
    end
end

function sim.yawPitchRollToAlphaBetaGamma(...)
    local yawAngle,pitchAngle,rollAngle=checkargs({{type='float'},{type='float'},{type='float'}},...)

    local lb=sim.setThreadAutomaticSwitch(false)
    local Rx=sim.buildMatrix({0,0,0},{rollAngle,0,0})
    local Ry=sim.buildMatrix({0,0,0},{0,pitchAngle,0})
    local Rz=sim.buildMatrix({0,0,0},{0,0,yawAngle})
    local m=sim.multiplyMatrices(Ry,Rx)
    m=sim.multiplyMatrices(Rz,m)
    local alphaBetaGamma=sim.getEulerAnglesFromMatrix(m)
    local alpha=alphaBetaGamma[1]
    local beta=alphaBetaGamma[2]
    local gamma=alphaBetaGamma[3]
    sim.setThreadAutomaticSwitch(lb)
    return alpha,beta,gamma
end

function sim.alphaBetaGammaToYawPitchRoll(...)
    local alpha,beta,gamma=checkargs({{type='float'},{type='float'},{type='float'}},...)

    local lb=sim.setThreadAutomaticSwitch(false)
    local m=sim.buildMatrix({0,0,0},{alpha,beta,gamma})
    local v=m[9]
    if v>1 then v=1 end
    if v<-1 then v=-1 end
    local pitchAngle=math.asin(-v)
    local yawAngle,rollAngle
    if math.abs(v)<0.999999 then
        rollAngle=math.atan2(m[10],m[11])
        yawAngle=math.atan2(m[5],m[1])
    else
        -- Gimbal lock
        rollAngle=math.atan2(-m[7],m[6])
        yawAngle=0
    end
    sim.setThreadAutomaticSwitch(lb)
    return yawAngle,pitchAngle,rollAngle
end

function sim.getObjectsWithTag(tagName,justModels)
    local retObjs={}
    local objs=sim.getObjectsInTree(sim.handle_scene)
    for i=1,#objs,1 do
        if (not justModels) or ((sim.getModelProperty(objs[i]) & sim.modelproperty_not_model)==0) then
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
    -- found in lua-cjson (by Mark Pulford):
    local m = 0
    local count = 0
    for k, v in pairs(t) do
        if type(k) == "number" then
            if k > m then m = k end
            count = count + 1
        else
            return false
        end
    end
    if m > count * 2 then
        return false
    end
    return true
end

function sim.setDebugWatchList(...)
    local l=checkargs({{type='table',default=NIL,nullable=true}},...)
    _S.debug.watchList=l
end

function sim.getUserVariables()
    local ng={}
    if _S.initGlobals then
        for key,val in pairs(_G) do
            if not _S.initGlobals[key] then
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
    ng._S=nil
    return ng
end

function sim.getMatchingPersistentDataTags(...)
    local pattern=checkargs({{type='string'}},...)
    local result = {}
    for index, value in ipairs(sim.getPersistentDataTags()) do
        if value:match(pattern) then
            result[#result + 1] = value
        end
    end
    return result
end

function getAsString(...)
    local lb=sim.setThreadAutomaticSwitch(false)
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
    sim.setThreadAutomaticSwitch(lb)
    return(t)
end

function sim.displayDialog(...)
    local title,mainTxt,style,modal,initTxt=checkargs({{type='string'},{type='string'},{type='int'},{type='bool'},{type='string',default='',nullable=true}},...)
    
    if sim.getBoolParameter(sim_boolparam_headless) then
        return -1
    end
    local retVal=-1
    local center=true
    if (style & sim.dlgstyle_dont_center)>0 then
        center=false
        style=style-sim.dlgstyle_dont_center
    end
    if modal and style==sim.dlgstyle_message then
        modal=false
    end
    local xml='<ui title="'..title..'" closeable="false" resizable="false"'
    if modal then
        xml=xml..' modal="true"'
    else
        xml=xml..' modal="false"'
    end

    if center then
        xml=xml..' placement="center">'
    else
        xml=xml..' placement="relative" position="-50,50">'
    end
    mainTxt=string.gsub(mainTxt,"&&n","\n")
    xml=xml..'<label text="'..mainTxt..'"/>'
    if style==sim.dlgstyle_input then
        xml=xml..'<edit on-editing-finished="_S.dlg.input_callback" id="1"/>'
    end
    if style==sim.dlgstyle_ok or style==sim.dlgstyle_input then
        xml=xml..'<group layout="hbox" flat="true">'
        xml=xml..'<button text="Ok" on-click="_S.dlg.ok_callback"/>'
        xml=xml..'</group>'
    end
    if style==sim.dlgstyle_ok_cancel then
        xml=xml..'<group layout="hbox" flat="true">'
        xml=xml..'<button text="Ok" on-click="_S.dlg.ok_callback"/>'
        xml=xml..'<button text="Cancel" on-click="_S.dlg.cancel_callback"/>'
        xml=xml..'</group>'
    end
    if style==sim.dlgstyle_yes_no then
        xml=xml..'<group layout="hbox" flat="true">'
        xml=xml..'<button text="Yes" on-click="_S.dlg.yes_callback"/>'
        xml=xml..'<button text="No" on-click="_S.dlg.no_callback"/>'
        xml=xml..'</group>'
    end
    xml=xml..'</ui>'
    local ui=simUI.create(xml)
    if style==sim.dlgstyle_input then
        simUI.setEditValue(ui,1,initTxt)
    end
    if not _S.dlg.openDlgs then
        _S.dlg.openDlgs={}
        _S.dlg.openDlgsUi={}
    end
    if not _S.dlg.nextHandle then
        _S.dlg.nextHandle=0
    end
    retVal=_S.dlg.nextHandle
    _S.dlg.nextHandle=_S.dlg.nextHandle+1
    _S.dlg.openDlgs[retVal]={ui=ui,style=style,state=sim.dlgret_still_open,input=initTxt,title=title,mainTxt=mainTxt}
    _S.dlg.openDlgsUi[ui]=retVal
    
    if modal then
        while _S.dlg.openDlgs[retVal].state==sim.dlgret_still_open do
            sim.switchThread()
        end
    end
    return retVal
end

function sim.endDialog(...)
    local dlgHandle=checkargs({{type='int'}},...)

    if not sim.getBoolParameter(sim_boolparam_headless) then
        if not _S.dlg.openDlgs[dlgHandle] then
            error("Argument #1 is not a valid dialog handle.")
        end
        if _S.dlg.openDlgs[dlgHandle].state==sim.dlgret_still_open then
            _S.dlg.removeUi(dlgHandle)
        end
        if _S.dlg.openDlgs[dlgHandle].ui then
            _S.dlg.openDlgsUi[_S.dlg.openDlgs[dlgHandle].ui]=nil
        end
        _S.dlg.openDlgs[dlgHandle]=nil
    end
end

function sim.getDialogInput(...)
    local dlgHandle=checkargs({{type='int'}},...)

    if sim.getBoolParameter(sim_boolparam_headless) then
        return ''
    end
    if not _S.dlg.openDlgs[dlgHandle] then
        error("Argument #1 is not a valid dialog handle.")
    end
    local retVal
    retVal=_S.dlg.openDlgs[dlgHandle].input
    return retVal
end

function sim.getDialogResult(...)
    local dlgHandle=checkargs({{type='int'}},...)

    if sim.getBoolParameter(sim_boolparam_headless) then
        return -1
    end
    if not _S.dlg.openDlgs[dlgHandle] then
        error("Argument #1 is not a valid dialog handle.")
    end
    local retVal=-1
    retVal=_S.dlg.openDlgs[dlgHandle].state
    return retVal
end

function math.random2(lower,upper)
    -- same as math.random, but each script has its own generator
    local r=sim.getRandom()
    if lower then
        local b=1
        local d
        if upper then
            b=lower
            d=upper-b
        else
            d=lower-b
        end
        local e=d/(d+1)
        r=b+math.floor(r*d/e)
    end
    return r
end

function math.randomseed2(seed)
    -- same as math.randomseed, but each script has its own generator
    sim.getRandom(seed)
end

function sim.throttle(t,f)
    if _S.lastExecTime==nil then _S.lastExecTime={} end
    local h=string.dump(f)
    local now=sim.getSystemTime()
    if _S.lastExecTime[h]==nil or _S.lastExecTime[h]+t<now then
        f()
        _S.lastExecTime[h]=now
    end
end

function sysCallEx_beforeInstanceSwitch()
    _S.dlg.switch()
end

function sysCallEx_afterInstanceSwitch()
    _S.dlg.switchBack()
end

function sysCallEx_addOnScriptSuspend()
    _S.dlg.switch()
end

function sysCallEx_addOnScriptResume()
    _S.dlg.switchBack()
end

function sysCallEx_cleanup()
    if _S.dlg.openDlgsUi then
        for key,val in pairs(_S.dlg.openDlgsUi) do
            simUI.destroy(key)
        end
    end
end

function sim.getAlternateConfigs(...)
    local jointHandles,inputConfig,tipHandle,lowLimits,ranges=checkargs({{type='table',item_type='int'},{type='table',item_type='float'},{type='int',default=-1},{type='table',item_type='float',default=NIL,nullable=true},{type='table',item_type='float',default=NIL,nullable=true}},...)

    if #jointHandles<1 or #jointHandles~=#inputConfig or (lowLimits and #jointHandles~=#lowLimits) or (ranges and #jointHandles~=#ranges) then
        error("Bad table size.")
    end
    
    local retVal={}
    local lb=sim.setThreadAutomaticSwitch(false)
    local initConfig={}
    local x={}
    local confS={}
    local err=false
    for i=1,#jointHandles,1 do
        initConfig[i]=sim.getJointPosition(jointHandles[i])
        local c,interv=sim.getJointInterval(jointHandles[i])
        local t=sim.getJointType(jointHandles[i])
        local res,sp=sim.getObjectFloatParameter(jointHandles[i],sim.jointfloatparam_screw_pitch)
        if t==sim.joint_revolute_subtype and not c then
            if res==1 and sp==0 then
                if inputConfig[i]-math.pi*2>=interv[1] or inputConfig[i]+math.pi*2<=interv[1]+interv[2] then
                    -- We use the low and range values from the joint's settings
                    local y=inputConfig[i]
                    while y-math.pi*2>=interv[1] do
                        y=y-math.pi*2
                    end
                    x[i]={y,interv[1]+interv[2]}
                end
            end
        end
        if x[i] then
            if lowLimits and ranges then
                -- the user specified low and range values. Use those instead:
                local l=lowLimits[i]
                local r=ranges[i]
                if r~=0 then
                    if r>0 then
                        if l<interv[1] then
                            -- correct for user bad input
                            r=r-(interv[1]-l)
                            l=interv[1] 
                        end
                        if l>interv[1]+interv[2] then
                            -- bad user input. No alternative position for this joint
                            x[i]={inputConfig[i],inputConfig[i]}
                            err=true
                        else
                            if l+r>interv[1]+interv[2] then
                                -- correct for user bad input
                                r=interv[1]+interv[2]-l
                            end
                            if inputConfig[i]-math.pi*2>=l or inputConfig[i]+math.pi*2<=l+r then
                                local y=inputConfig[i]
                                while y<l do
                                    y=y+math.pi*2
                                end
                                while y-math.pi*2>=l do
                                    y=y-math.pi*2
                                end
                                x[i]={y,l+r}
                            else
                                -- no alternative position for this joint
                                x[i]={inputConfig[i],inputConfig[i]}
                                err=(inputConfig[i]<l) or (inputConfig[i]>l+r)
                            end
                        end
                    else
                        r=-r
                        l=inputConfig[i]-r*0.5
                        if l<x[i][1] then
                            l=x[i][1]
                        end
                        local u=inputConfig[i]+r*0.5
                        if u>x[i][2] then
                            u=x[i][2]
                        end
                        x[i]={l,u}
                    end
                end
            end
        else
            -- there's no alternative position for this joint
            x[i]={inputConfig[i],inputConfig[i]}
        end
        confS[i]=x[i][1]
    end
    local configs={}
    if not err then
        for i=1,#jointHandles,1 do
            sim.setJointPosition(jointHandles[i],inputConfig[i])
        end
        local desiredPose=0
        if tipHandle~=-1 then
            desiredPose=sim.getObjectMatrix(tipHandle,-1)
        end
        configs=_S.loopThroughAltConfigSolutions(jointHandles,desiredPose,confS,x,1,tipHandle)
    end
    
    for i=1,#jointHandles,1 do
        sim.setJointPosition(jointHandles[i],initConfig[i])
    end
    sim.setThreadAutomaticSwitch(lb)
    return configs
end

function sim.setObjectSelection(...)
    local handles=checkargs({{type='table',item_type='int'}},...)
    
    sim.removeObjectFromSelection(sim.handle_all)
    sim.addObjectToSelection(handles)
end

function sim.moveToPose(...)
    local flags,currentMatrix,maxVel,maxAccel,maxJerk,targetMatrix,callback,auxData,metric,timeStep=checkargs({{type='int'},{type='table',size=12},{type='table',item_type='float'},{type='table',item_type='float'},{type='table',item_type='float'},{type='table',size=12},{type='func'},{type='any',default=NIL,nullable=true},{type='table',size=4,default=NIL,nullable=true},{type='float',default=0}},...)

    if #maxVel<1 or #maxVel~=#maxAccel or #maxVel~=#maxJerk then
        error("Bad table size.")
    end
    if not metric and #maxVel<4 then
        error("Arguments #3, #4 and #5 should be of size 4. (in function 'sim.moveToPose')")    
    end
    
    local lb=sim.setThreadAutomaticSwitch(false)
    
    local outMatrix=sim.unpackDoubleTable(sim.packDoubleTable(currentMatrix))
    local axis,angle=sim.getRotationAxis(currentMatrix,targetMatrix)
    local timeLeft=0
    if metric then
        -- Here we treat the movement as a 1 DoF movement, where we simply interpolate via t between
        -- the start and goal pose. This always results in straight line movement paths
        local dx={(targetMatrix[4]-currentMatrix[4])*metric[1],(targetMatrix[8]-currentMatrix[8])*metric[2],(targetMatrix[12]-currentMatrix[12])*metric[3],angle*metric[4]}
        local distance=math.sqrt(dx[1]*dx[1]+dx[2]*dx[2]+dx[3]*dx[3]+dx[4]*dx[4])
        if distance>0.000001 then
            local currentPosVelAccel={0,0,0}
            local maxVelAccelJerk={maxVel[1],maxAccel[1],maxJerk[1]}
            local targetPosVel={distance,0}
            local rmlObject=sim.rmlPos(1,0.0001,-1,currentPosVelAccel,maxVelAccelJerk,{1},targetPosVel)
            local result=0
            while result==0 do
                local dt=timeStep
                if dt==0 then
                    dt=sim.getSimulationTimeStep()
                end
                local syncTime
                result,newPosVelAccel,syncTime=sim.rmlStep(rmlObject,dt)
                if result~=-1 then
                    if result==0 then
                        timeLeft=dt-syncTime
                    end
                    local t=newPosVelAccel[1]/distance
                    local mi=sim.interpolateMatrices(currentMatrix,targetMatrix,t)
                    local nv={newPosVelAccel[2]}
                    local na={newPosVelAccel[3]}
                    callback(mi,nv,na,auxData)
                end
                if result==0 then
                    sim.switchThread()
                end
            end
            sim.rmlRemove(rmlObject)
        end
    else
        -- Here we treat the movement as a 4 DoF movement, where each of X, Y, Z and rotation
        -- is handled and controlled individually. This can result in non-straight line movement paths,
        -- due to how the RML functions operate depending on 'flags'
        local dx={targetMatrix[4]-currentMatrix[4],targetMatrix[8]-currentMatrix[8],targetMatrix[12]-currentMatrix[12],angle}
        local currentPosVelAccel={0,0,0,0,0,0,0,0,0,0,0,0}
        local maxVelAccelJerk={maxVel[1],maxVel[2],maxVel[3],maxVel[4],maxAccel[1],maxAccel[2],maxAccel[3],maxAccel[4],maxJerk[1],maxJerk[2],maxJerk[3],maxJerk[4]}
        local targetPosVel={dx[1],dx[2],dx[3],dx[4],0,0,0,0,0}
        local rmlObject=sim.rmlPos(4,0.0001,-1,currentPosVelAccel,maxVelAccelJerk,{1,1,1,1},targetPosVel)
        local result=0
        while result==0 do
            local dt=timeStep
            if dt==0 then
                dt=sim.getSimulationTimeStep()
            end
            local syncTime
            result,newPosVelAccel,syncTime=sim.rmlStep(rmlObject,dt)
            if result~=-1 then
                if result==0 then
                    timeLeft=dt-syncTime
                end
                local t=0
                if math.abs(angle)>math.pi*0.00001 then
                    t=newPosVelAccel[4]/angle
                end
                local mi=sim.interpolateMatrices(currentMatrix,targetMatrix,t)
                mi[4]=currentMatrix[4]+newPosVelAccel[1]
                mi[8]=currentMatrix[8]+newPosVelAccel[2]
                mi[12]=currentMatrix[12]+newPosVelAccel[3]
                local nv={newPosVelAccel[5],newPosVelAccel[6],newPosVelAccel[7],newPosVelAccel[8]}
                local na={newPosVelAccel[9],newPosVelAccel[10],newPosVelAccel[11],newPosVelAccel[12]}
                callback(mi,nv,na,auxData)
            end
            if result==0 then
                sim.switchThread()
            end
        end
        sim.rmlRemove(rmlObject)
    end
    sim.setThreadAutomaticSwitch(lb)
    return outMatrix,timeLeft
end

function sim.moveToConfig(...)
    local flags,currentPos,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetVel,callback,auxData,cyclicJoints,timeStep=checkargs({{type='int'},{type='table',item_type='float'},{type='table',item_type='float',nullable=true},{type='table',item_type='float',nullable=true},{type='table',item_type='float'},{type='table',item_type='float'},{type='table',item_type='float'},{type='table',item_type='float'},{type='table',item_type='float',nullable=true},{type='func'},{type='any',default=NIL,nullable=true},{type='table',item_type='bool',default=NIL,nullable=true},{type='float',default=0}},...)

    if #currentPos<1 or #currentPos>#maxVel or #currentPos>#maxAccel or #currentPos>#maxJerk or #currentPos>#targetPos or (currentVel and #currentPos>#currentVel) or (currentAccel and #currentPos>#currentAccel) or (targetVel and #currentPos>#targetVel) or (cyclicJoints and #currentPos>#cyclicJoints) then
        error("Bad table size.")
    end
    
    local lb=sim.setThreadAutomaticSwitch(false)
    
    local currentPosVelAccel={}
    local maxVelAccelJerk={}
    local targetPosVel={}
    local sel={}
    local outPos={}
    local outVel={}
    local outAccel={}
    for i=1,#currentPos,1 do
        local v=currentPos[i]
        currentPosVelAccel[i]=v
        outPos[i]=v
        maxVelAccelJerk[i]=maxVel[i]
        local w=targetPos[i]
        if cyclicJoints and cyclicJoints[i] then
            while w-v>=math.pi*2 do
                w=w-math.pi*2
            end
            while w-v<0 do
                w=w+math.pi*2
            end
            if w-v>math.pi then
                w=w-math.pi*2
            end            
        end
        targetPosVel[i]=w
        sel[i]=1
    end
    for i=#currentPos+1,#currentPos*2 do
        if currentVel then
            currentPosVelAccel[i]=currentVel[i-#currentPos]
            outVel[i-#currentPos]=currentVel[i-#currentPos]
        else
            currentPosVelAccel[i]=0
            outVel[i-#currentPos]=0
        end
        maxVelAccelJerk[i]=maxAccel[i-#currentPos]
        if targetVel then
            targetPosVel[i]=targetVel[i-#currentPos]
        else
            targetPosVel[i]=0
        end
    end
    for i=#currentPos*2+1,#currentPos*3 do
        if currentAccel then
            currentPosVelAccel[i]=currentAccel[i-#currentPos*2]
            outAccel[i-#currentPos*2]=currentAccel[i-#currentPos*2]
        else
            currentPosVelAccel[i]=0
            outAccel[i-#currentPos*2]=0
        end
        maxVelAccelJerk[i]=maxJerk[i-#currentPos*2]
    end

    local rmlObject=sim.rmlPos(#currentPos,0.0001,flags,currentPosVelAccel,maxVelAccelJerk,sel,targetPosVel)
    local result=0
    local timeLeft=0
    while result==0 do
        local dt=timeStep
        if dt==0 then
            dt=sim.getSimulationTimeStep()
        end
        local syncTime
        result,newPosVelAccel,syncTime=sim.rmlStep(rmlObject,dt)
        if result~=-1 then
            if result==0 then
                timeLeft=dt-syncTime
            end
            for i=1,#currentPos,1 do
                outPos[i]=newPosVelAccel[i]
                outVel[i]=newPosVelAccel[#currentPos+i]
                outAccel[i]=newPosVelAccel[#currentPos*2+i]
            end
            callback(outPos,outVel,outAccel,auxData)
        end
        if result==0 then
            sim.switchThread()
        end
    end
    sim.rmlRemove(rmlObject)
    sim.setThreadAutomaticSwitch(lb)
    return outPos,outVel,outAccel,timeLeft
end

function sim.generateTimeOptimalTrajectory(...)
    local path,minMaxVel,minMaxAccel,trajPtSamples,metric,boundaryCondition,timeout=checkargs({{type='object',class=Matrix},{type='object',class=Matrix},{type='object',class=Matrix},{type='int',default=1000},{type='table',item_type='int',default=NIL,nullable=true},{type='string',default='not-a-knot'},{type='float',default=5}},...)
    local dof=path:cols()
    
    if dof<1 or path:rows()<2 or dof~=minMaxVel:rows() or dof~=minMaxAccel:rows() or minMaxVel:cols()<2 or minMaxAccel:cols()<2 or (metric and dof~=#metric) then
        error("Bad matrix/table size.")
    end
    local lb=sim.setThreadAutomaticSwitch(false)
    if metric==nil then
        metric={}
        for i=1,dof,1 do
            metric[i]=1
        end
    end
    local distancesAlongPath=sim.getPathLengths(path,metric)
    local dkjson=require 'dkjson'
    local r
    sim.addLog(sim.verbosity_scriptinfos,"Checking if the BlueZero resolver is running, this can take a few seconds...")
    if simB0.pingResolver() then
        sim.addLog(sim.verbosity_scriptinfos,"Trying to connect via BlueZero to the 'toppra' service... make sure the 'docker-image-bluezero-toppra' container is running. Details can be found at https://github.com/CoppeliaRobotics/docker-image-bluezero-toppra")
        local n=simB0.nodeCreate('toppra-service-client')
        local c=simB0.serviceClientCreate(n,'toppra')
        simB0.nodeInit(n)
        simB0.socketSetOption(c,'readTimeout',timeout*1000)
        
        r=simB0.serviceClientCallJSON(c,{
            samples=trajPtSamples,
            ss_waypoints=distancesAlongPath,
            waypoints=path.totable({}),
            velocity_limits=minMaxVel.totable({}),
            acceleration_limits=minMaxAccel.totable({}),
            bc_type=boundaryCondition
        })
        simB0.nodeCleanup(n)
    else
        error('BlueZero resolver was not detected.')
    end
    sim.setThreadAutomaticSwitch(lb)
    return Matrix:fromtable(r.qs[1]),r.ts
end

function sim.copyTable(...)
    local orig,copies=checkargs({{type='any'},{type='table',default={}}},...)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[sim.copyTable(orig_key, copies)] = sim.copyTable(orig_value, copies)
            end
            setmetatable(copy, sim.copyTable(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function sim.getPathInterpolatedConfig(...)
    local path,times,t,types,method,forceOpen=checkargs({{type='object',class=Matrix},{type='table',item_type='float',nullable=true},{type='float'},{type='table',item_type='int',default=NIL,nullable=true},{type='table',default={type='linear'}},{type='bool',default=false}},...)
    local confCnt=path:rows()
    local dof=path:cols()
    
    if dof<1 or (confCnt<2) or (times and confCnt~=#times) or (types and dof~=#types) then
        error("Bad matrix/table size.")
    end

    if times==nil and confCnt>2 then
        error("Argument #2 is not optional when the path contains more than 2 configurations.")
    end
    if types==nil then 
        types={}
        for i=1,dof,1 do
            types[i]=0
        end
    end
    local closed=true
    for i=1,dof,1 do
        if path[1][i]~=path[confCnt][i] then
            closed=false
            break
        end
    end
    if forceOpen then
        closed=false
    end
    local retVal={}
    local li=1
    local hi=2
    if t<0 then t=0 end
    if confCnt>2 or times then
        if t>times[#times] then t=times[#times] end
        local ll,hl
        for i=2,#times,1 do
            li=i-1
            hi=i
            ll=times[li]
            hl=times[hi]
            if hl>=t then
                break
            end
        end
        t=(t-ll)/(hl-ll)
    else
        if t>1 then t=1 end
    end
    if method.type=='quadraticBezier' then
        local i0,i1,i2
        if t<0.5 then
            if li==1 and not closed then
                retVal=_S.linearInterpolate(path[li],path[hi],t,types)
            else
                i0=li-1
                i1=li
                i2=hi
                if li==1 then
                    i0=confCnt-1
                end
                local a=_S.linearInterpolate(path[i0],path[i1],0.75+t*0.5,types)
                local b=_S.linearInterpolate(path[i1],path[i2],0.25+t*0.5,types)
                retVal=_S.linearInterpolate(a,b,0.5+t,types)
            end
        else
            if hi==confCnt and not closed then
                retVal=_S.linearInterpolate(path[li],path[hi],t,types)
            else
                i0=li
                i1=hi
                i2=hi+1
                if hi==confCnt then
                    i2=2
                end
                t=t-0.5
                local a=_S.linearInterpolate(path[i0],path[i1],0.5+t*0.5,types)
                local b=_S.linearInterpolate(path[i1],path[i2],t*0.5,types)
                retVal=_S.linearInterpolate(a,b,t,types)
            end
        end
    end
    if not method or method.type=='linear' then
        retVal=_S.linearInterpolate(path[li],path[hi],t,types)
    end
    return retVal
end

function sim.resamplePath(...)
    local path,finalConfigCnt,metric,types,method,forceOpen=checkargs({{type='object',class=Matrix},{type='int'},{type='table',item_type='float',default=NIL,nullable=true},{type='table',item_type='int',default=NIL,nullable=true},{type='table',default={type='linear'}},{type='bool',default=false}},...)
    local dof=path:cols()
    
    if dof<1 or (path.rows()<2) or (metric and dof~=#metric) or (types and dof~=#types) then
        error("Bad table size.")
    end

    local pathLengths=sim.getPathLengths(path,metric,types)
    local retVal={data={},dims={finalConfigCnt,dof}}
    for i=1,finalConfigCnt,1 do
        local c=sim.getPathInterpolatedConfig(path,pathLengths,pathLengths[#pathLengths]*(i-1)/(finalConfigCnt-1),types,method,forceOpen)
        for j=1,#c,1 do
            retVal.data[#retVal.data+1]=c[j]
        end
    end
    return retVal
end

function sim.getPathLengths(...)
    local path,metric,types=checkargs({{type='object',class=Matrix},{type='table',item_type='float',default=NIL,nullable=true},{type='table',item_type='int',default=NIL,nullable=true}},...)
    local dof=path:cols()
    
    if dof<1 or (path:rows()<2) or (metric and dof~=#metric) or (types and dof~=#types) then
        error("Bad matrix/table size.")
    end

    if metric==nil then
        metric={}
        for i=1,dof,1 do
            metric[i]=1
        end
    end
    if types==nil then 
        types={}
        for i=1,dof,1 do
            types[i]=0
        end
    end 
    local distancesAlongPath={0}
    local totDist=0
    for i=1,path:rows()-1,1 do
        local d=0
        local qcnt=0
        for j=1,dof,1 do
            local dd=0
            if types[j]==0 then
                dd=(path[i+1][j]-path[i][j])*metric[j] -- e.g. joint with limits
            end
            if types[j]==1 then
                local dx=math.atan2(math.sin(path[i+1][j]-path[i][j]),math.cos(path[i+1][j]-path[i][j]))
                local v=path[i][j]+dx
                dd=math.atan2(math.sin(v),math.cos(v))*metric[j] -- cyclic rev. joint (-pi;pi)
            end
            if types[j]==2 then
                qcnt=qcnt+1
                if qcnt==4 then
                    qcnt=0
                    local m1=sim.buildMatrixQ({0,0,0},{path[i][j-3],path[i][j-2],path[i][j-1],path[i][j-0]})
                    local m2=sim.buildMatrixQ({0,0,0},{path[i+1][j-3],path[i+1][j-2],path[i+1][j-1],path[i+1][j-0]})
                    local a,angle=sim.getRotationAxis(m1,m2)
                    dd=angle*metric[j-3]
                end
            end
            d=d+dd*dd
        end
        totDist=totDist+math.sqrt(d)
        distancesAlongPath[i+1]=totDist
    end
    return distancesAlongPath,totDist
end

function sim.changeEntityColor(...)
    local entityHandle,color,colorComponent=checkargs({{type='int'},{type='table', size=3, item_type='float'},{type='int',default=sim.colorcomponent_ambient_diffuse}},...)
    local colorData={}
    local objs={entityHandle}
    if sim.isHandleValid(entityHandle,sim.appobj_collection_type)==1 then
        objs=sim.getCollectionObjects(entityHandle)
    end
    for i=1,#objs,1 do
        if sim.getObjectType(objs[i])==sim.object_shape_type then
            local res,visible=sim.getObjectInt32Parameter(objs[i],sim.objintparam_visible)
            if visible==1 then
                local res,col=sim.getShapeColor(objs[i],'@compound',colorComponent)
                colorData[#colorData+1]={handle=objs[i],data=col,comp=colorComponent}
                sim.setShapeColor(objs[i],nil,colorComponent,color)
            end
        end
    end
    return colorData
end

function sim.restoreEntityColor(...)
    local colorData=checkargs({{type='table'},min_size=1},...)
    for i=1,#colorData,1 do
        if sim.isHandleValid(colorData[i].handle,sim.appobj_object_type)==1 then
            sim.setShapeColor(colorData[i].handle,'@compound',colorData[i].comp,colorData[i].data)
        end
    end
end

function sim.wait(...)
    local dt,simTime=checkargs({{type='float'},{type='bool',default=true}},...)
    
    local retVal=0
    if simTime then
        local st=sim.getSimulationTime()
        while sim.getSimulationTime()-st<dt do
            sim.switchThread()
        end
        retVal=sim.getSimulationTime()-st-dt
    else
        local st=sim.getSystemTimeInMs(-1)
        while sim.getSystemTimeInMs(st)<dt*1000 do
            sim.switchThread()
        end
    end
    return retVal
end

function sim.waitForSignal(...)
    local sigName=checkargs({{type='string'}},...)
    local retVal
    while true do
        retVal=sim.getIntegerSignal(sigName) or sim.getFloatSignal(sigName) or sim.getDoubleSignal(sigName) or sim.getStringSignal(sigName)
        if retVal then
            break
        end
        sim.switchThread()
    end
    return retVal
end

function sim.tubeRead(...)
    -- For backward compatibility (01.10.2020)
    local tubeHandle,blocking=checkargs({{type='int'},{type='bool',default=false}},...)
    local retVal
    if blocking then
        while true do
            retVal=sim._tubeRead(tubeHandle)
            if retVal then
                break
            end
            sim.switchThread()
        end
    else
        retVal=sim._tubeRead(tubeHandle)
    end
    return retVal
end

function sim.serialRead(...)
    local portHandle,length,blocking,closingStr,timeout=checkargs({{type='int'},{type='int'},{type='bool',default=false},{type='string',default=''},{type='float',default=0}},...)
    
    local retVal
    if blocking then
        local st=sim.getSystemTimeInMs(-1)
        while true do 
            local data=_S.serialPortData[portHandle]
            _S.serialPortData[portHandle]=''
            if #data<length then
                local d=sim._serialRead(portHandle,length-#data)
                if d then
                    data=data..d
                end
            end
            if #data>=length then
                retVal=string.sub(data,1,length)
                if #data>length then
                    data=string.sub(data,length+1)
                    _S.serialPortData[portHandle]=data
                end
                break
            end
            if closingStr~='' then
                local s,e=string.find(data,closingStr,1,true)
                if e then
                    retVal=string.sub(data,1,e)
                    if #data>e then
                        data=string.sub(data,e+1)
                        _S.serialPortData[portHandle]=data
                    end
                    break
                end
            end
            if sim.getSystemTimeInMs(st)>=(timeout*1000) and timeout~=0 then
                retVal=data
                break
            end
            sim.switchThread()
            _S.serialPortData[portHandle]=data
        end
    else
        local data=_S.serialPortData[portHandle]
        _S.serialPortData[portHandle]=''
        if #data<length then
            local d=sim._serialRead(portHandle,length-#data)
            if d then
                data=data..d
            end
        end
        if #data>length then
            retVal=string.sub(data,1,length)
            data=string.sub(data,length+1)
            _S.serialPortData[portHandle]=data
        else
            retVal=data
        end
    end
    return retVal
end

function sim.serialOpen(...)
    local portString,baudRate=checkargs({{type='string'},{type='int'}},...)
    
    local retVal=sim._serialOpen(portString,baudRate)
    if not _S.serialPortData then
        _S.serialPortData={}
    end
    _S.serialPortData[retVal]=''
    return retVal
end

function sim.serialClose(...)
    local portHandle=checkargs({{type='int'}},...)

    sim._serialClose(portHandle)
    if _S.serialPortData then
        _S.serialPortData[portHandle]=nil
    end
end

function simRMLMoveToJointPositions(jhandles,flags,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetVel,direction)
    -- For backward compatibility (02.10.2020)
    return sim.rmlMoveToJointPositions(jhandles,flags,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetVel,direction)
end

function sim.rmlMoveToJointPositions(...)
    -- For backward compatibility (02.10.2020)
    
    local jhandles,flags,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetVel,direction=checkargs({{type='table',min_size=1,item_type='int'},{type='int'},{type='table',min_size=1,item_type='float',nullable=true},{type='table',min_size=1,item_type='float',nullable=true},{type='table',min_size=1,item_type='float'},{type='table',min_size=1,item_type='float'},{type='table',min_size=1,item_type='float'},{type='table',min_size=1,item_type='float'},{type='table',min_size=1,item_type='float',default=NIL,nullable=true},{type='table',item_type='float',min_size=1,default=NIL,nullable=true}},...)
    local dof=#jhandles
    
    if dof<1 or (currentVel and dof~=#currentVel) or (currentAccel and dof~=#currentAccel) or dof~=#maxVel or dof~=#maxAccel or dof~=#maxJerk or dof~=#targetPos or (targetVel and dof~=#targetVel) or (direction and dof~=#direction) then
        error("Bad table size.")
    end

    local lb=sim.setThreadAutomaticSwitch(false)
    
    if direction==nil then
        direction={}
        for i=1,#jhandles,1 do
            direction[i]=0
        end
    end
    function _S.tmpCb(conf,vel,accel,jhandles)
        for i=1,#conf,1 do
            local k=jhandles[i]
            if sim.getJointMode(k)==sim.jointmode_force and sim.isDynamicallyEnabled(k) then
                sim.setJointTargetPosition(k,conf[i])
            else    
                sim.setJointPosition(k,conf[i])
            end
        end
    end
    
    local currentConf={}
    local cycl={}
    for i=1,#jhandles,1 do
        currentConf[i]=sim.getJointPosition(jhandles[i])
        local c,interv=sim.getJointInterval(jhandles[i])
        local t=sim.getJointType(jhandles[i])
        local isCyclic=(t==sim.joint_revolute_subtype and c)
        cycl[i]=isCyclic
        if isCyclic and (direction[i]~=0) then
            cycl[i]=false
            if direction[i]>0 then
                while targetPos[i]>currentConf[i]+2*math.pi*direction[i] do
                    targetPos[i]=targetPos[i]-2*math.pi
                end
                while targetPos[i]<currentConf[i]+2*math.pi*(direction[i]-1) do
                    targetPos[i]=targetPos[i]+2*math.pi
                end
            else
                while targetPos[i]<currentConf[i]+2*math.pi*direction[i] do
                    targetPos[i]=targetPos[i]+2*math.pi
                end
                while targetPos[i]>currentConf[i]+2*math.pi*(direction[i]+1) do
                    targetPos[i]=targetPos[i]-2*math.pi
                end
            end
        end
    end
    
    local endPos,endVel,endAccel,timeLeft=sim.moveToConfig(flags,currentConf,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetVel,_S.tmpCb,jhandles,cycl)
    local res=0
    if endPos then res=1 end
    
    _S.tmpCb=nil
    sim.setThreadAutomaticSwitch(lb)
    return res,endPos,endVel,endAccel,timeLeft
end

function simRMLMoveToPosition(handle,rel,flags,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetQuat,targetVel)
    -- For backward compatibility (02.10.2020)
    return sim.rmlMoveToPose(handle,rel,flags,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetQuat,targetVel)
end

function sim.rmlMoveToPosition(...)
    -- For backward compatibility (02.10.2020)
    
    local handle,rel,flags,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetQuat,targetVel=checkargs({{type='int'},{type='int'},{type='int'},{type='table',size=4,item_type='float',nullable=true},{type='table',size=4,item_type='float',nullable=true},{type='table',size=4,item_type='float'},{type='table',size=4,item_type='float'},{type='table',size=4,item_type='float'},{type='table',size=3,item_type='float',nullable=true},{type='table',size=4,item_type='float',default=NIL,nullable=true},{type='table',item_type='float',size=4,nullable=true}},...)

    local lb=sim.setThreadAutomaticSwitch(false)
    
    local mStart=sim.getObjectMatrix(handle,rel)
    if targetPos==nil then
        targetPos={mStart[4],mStart[8],mStart[12]}
    end
    if targetQuat==nil then
        targetQuat=sim.getObjectQuaternion(handle,rel)
    end
    local mGoal=sim.buildMatrixQ(targetPos,targetQuat)
    function _S.tmpCb(m,v,a,data)
        sim.setObjectMatrix(data.handle,data.rel,m)
    end
    local data={}
    data.handle=handle
    data.rel=rel
    local endMatrix,timeLeft=sim.moveToPose(flags,mStart,maxVel,maxAccel,maxJerk,mGoal,_S.tmpCb,data)
    local res=0
    local nPos,nQuat
    if endMatrix then 
        nPos={endMatrix[4],endMatrix[8],endMatrix[12]}
        nQuat=sim.getQuaternionFromMatrix(endMatrix)
        res=1 
    end
    _S.tmpCb=nil
    sim.setThreadAutomaticSwitch(lb)
    return res,nPos,nQuat,{0,0,0,0},{0,0,0,0},timeLeft
end

function sim.boolOr32(a,b)
    -- For backward compatibility (02.10.2020)
    return math.floor(a)|math.floor(b)
end
function sim.boolAnd32(a,b)
    -- For backward compatibility (02.10.2020)
    return math.floor(a)&math.floor(b)
end
function sim.boolXor32(a,b)
    -- For backward compatibility (02.10.2020)
    return math.floor(a)~math.floor(b)
end
function sim.boolOr16(a,b)
    -- For backward compatibility (02.10.2020)
    return math.floor(a)|math.floor(b)
end
function sim.boolAnd16(a,b)
    -- For backward compatibility (02.10.2020)
    return math.floor(a)&math.floor(b)
end
function sim.boolXor16(a,b)
    -- For backward compatibility (02.10.2020)
    return math.floor(a)~math.floor(b)
end

----------------------------------------------------------


-- Hidden, internal functions:
----------------------------------------------------------

function _S.linearInterpolate(conf1,conf2,t,types)
    local retVal={}
    local qcnt=0
    for i=1,#conf1,1 do
        if types[i]==0 then
            retVal[i]=conf1[i]*(1-t)+conf2[i]*t -- e.g. joint with limits
        end
        if types[i]==1 then
            local dx=math.atan2(math.sin(conf2[i]-conf1[i]),math.cos(conf2[i]-conf1[i]))
            local v=conf1[i]+dx*t
            retVal[i]=math.atan2(math.sin(v),math.cos(v)) -- cyclic rev. joint (-pi;pi)
        end
        if types[i]==2 then
            qcnt=qcnt+1
            if qcnt==4 then
                qcnt=0
                local m1=sim.buildMatrixQ({0,0,0},{conf1[i-3],conf1[i-2],conf1[i-1],conf1[i-0]})
                local m2=sim.buildMatrixQ({0,0,0},{conf2[i-3],conf2[i-2],conf2[i-1],conf2[i-0]})
                local m=sim.interpolateMatrices(m1,m2,t)
                local q=sim.getQuaternionFromMatrix(m)
                retVal[i-3]=q[1]
                retVal[i-2]=q[2]
                retVal[i-1]=q[3]
                retVal[i-0]=q[4]
            end
        end
    end
    return retVal
end

function _S.loopThroughAltConfigSolutions(jointHandles,desiredPose,confS,x,index,tipHandle)
    if index>#jointHandles then
        if tipHandle==-1 then
            return {sim.unpackDoubleTable(sim.packDoubleTable(confS))} -- copy the table
        else
            for i=1,#jointHandles,1 do
                sim.setJointPosition(jointHandles[i],confS[i])
            end
            local p=sim.getObjectMatrix(tipHandle,-1)
            local axis,angle=sim.getRotationAxis(desiredPose,p)
            if math.abs(angle)<0.1*180/math.pi then -- checking is needed in case some joints are dependent on others
                return {sim.unpackDoubleTable(sim.packDoubleTable(confS))} -- copy the table
            else
                return {}
            end
        end
    else
        local c={}
        for i=1,#jointHandles,1 do
            c[i]=confS[i]
        end
        local solutions={}
        while c[index]<=x[index][2] do
            local s=_S.loopThroughAltConfigSolutions(jointHandles,desiredPose,c,x,index+1,tipHandle)
            for i=1,#s,1 do
                solutions[#solutions+1]=s[i]
            end
            c[index]=c[index]+math.pi*2
        end
        return solutions
    end
end

function _S.comparableTables(t1,t2)
    return ( isArray(t1)==isArray(t2) ) or ( isArray(t1) and #t1==0 ) or ( isArray(t2) and #t2==0 )
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

function _S.executeAfterLuaStateInit()
    quit=sim.quitSimulator
    exit=sim.quitSimulator
    sim.registerScriptFunction('quit@sim','quit()')
    sim.registerScriptFunction('exit@sim','exit()')
    sim.registerScriptFunction('sim.setDebugWatchList@sim','sim.setDebugWatchList(table vars=nil)')
    sim.registerScriptFunction('sim.getUserVariables@sim','table variables=sim.getUserVariables()')
    sim.registerScriptFunction('sim.getMatchingPersistentDataTags@sim','table tags=sim.getMatchingPersistentDataTags(string pattern)')

    sim.registerScriptFunction('sim.displayDialog@sim','int dlgHandle=sim.displayDialog(string title,string mainText,int style,\nboolean modal,string initTxt)')
    sim.registerScriptFunction('sim.getDialogResult@sim','int result=sim.getDialogResult(int dlgHandle)')
    sim.registerScriptFunction('sim.getDialogInput@sim','string input=sim.getDialogInput(int dlgHandle)')
    sim.registerScriptFunction('sim.endDialog@sim','int result=sim.endDialog(int dlgHandle)')
    sim.registerScriptFunction('sim.yawPitchRollToAlphaBetaGamma@sim','float alphaAngle,float betaAngle,float gammaAngle=sim.yawPitchRollToAlphaBetaGamma(\nfloat yawAngle,float pitchAngle,float rollAngle)')
    sim.registerScriptFunction('sim.alphaBetaGammaToYawPitchRoll@sim','float yawAngle,float pitchAngle,float rollAngle=sim.alphaBetaGammaToYawPitchRoll(\nfloat alphaAngle,float betaAngle,float gammaAngle)')
    sim.registerScriptFunction('sim.getAlternateConfigs@sim','table configs=sim.getAlternateConfigs(table jointHandles,\ntable inputConfig,int tipHandle=-1,table lowLimits=nil,table ranges=nil)')
    sim.registerScriptFunction('sim.setObjectSelection@sim','sim.setObjectSelection(table handles)')
    
    sim.registerScriptFunction('sim.moveToPose@sim','table_12 endMatrix,float timeLeft=sim.moveToPose(int flags,table_12 currentMatrix,\ntable maxVel,table maxAccel,table maxJerk,table_12 targetMatrix,\nfunction callback,auxData=nil,table_4 metric=nil,float timeStep=0)')
    sim.registerScriptFunction('sim.moveToConfig@sim','table endPos,table endVel,table endAccel,float timeLeft=sim.moveToConfig(int flags,\ntable currentPos,table currentVel,table currentAccel,table maxVel,table maxAccel,\ntable maxJerk,table targetPos,table targetVel,function callback,auxData=nil,table cyclicJoints=nil,float timeStep=0)')
    sim.registerScriptFunction('sim.switchThread@sim','sim.switchThread()')

    sim.registerScriptFunction('sim.copyTable@sim',"table copy=sim.copyTable(table original)")
    
    sim.registerScriptFunction('sim.getPathInterpolatedConfig@sim',"table config=sim.getPathInterpolatedConfig(Matrix path,table times,float t,table types=nil,method={type='linear'},forceOpen=false)")
    sim.registerScriptFunction('sim.resamplePath@sim','Matrix path=sim.resamplePath(Matrix path,int finalConfigCnt,table metric=nil,table types=nil)')
    sim.registerScriptFunction('sim.getPathLengths@sim','table pathLengths,float totalLength=sim.getPathLengths(Matrix path,table metric=nil,table types=nil)')
    sim.registerScriptFunction('sim.generateTimeOptimalTrajectory@sim',"Matrix path,table times=sim.generateTimeOptimalTrajectory(Matrix path,Matrix minMaxVel,Matrix minMaxAccel,\nint trajPtSamples=1000,metric=nil,string boundaryCondition='not-a-knot',float timeout=5)")

    sim.registerScriptFunction('sim.wait@sim','float timeLeft=sim.wait(float dt,boolean simulationTime=true)')
    sim.registerScriptFunction('sim.waitForSignal@sim','number/string sigVal=sim.waitForSignal(string sigName)')
    
    sim.registerScriptFunction('sim.serialOpen@sim','int portHandle=sim.serialOpen(string portString,int baudrate)')
    sim.registerScriptFunction('sim.serialClose@sim','sim.serialClose(int portHandle)')
    sim.registerScriptFunction('sim.serialRead@sim',"string data=sim.serialRead(int portHandle,int dataLengthToRead,boolean blockingOperation,string closingString='',float timeout=0)")
    sim.registerScriptFunction('sim.rmlMoveToJointPositions@sim',"Deprecated. Use 'sim.moveToConfig' instead")
    sim.registerScriptFunction('sim.rmlMoveToPosition@sim',"Deprecated. Use 'sim.moveToPose' instead")
    
    sim.registerScriptFunction('sim.changeEntityColor@sim','table originalColorData=sim.changeEntityColor(int entityHandle,table_3 newColor,\nint colorComponent=sim.colorcomponent_ambient_diffuse)')
    sim.registerScriptFunction('sim.restoreEntityColor@sim','sim.restoreEntityColor(table originalColorData)')
    
    if __initFunctions then
        for i=1,#__initFunctions,1 do
            __initFunctions[i]()
        end
        __initFunctions=nil
    end
    
    _S.initGlobals={}
    for key,val in pairs(_G) do
        _S.initGlobals[key]=true
    end
    _S.initGlobals._S=nil
    _S.executeAfterLuaStateInit=nil
end

function _S.dlg.ok_callback(ui)
    local h=_S.dlg.openDlgsUi[ui]
    _S.dlg.openDlgs[h].state=sim.dlgret_ok
    if _S.dlg.openDlgs[h].style==sim.dlgstyle_input then
        _S.dlg.openDlgs[h].input=simUI.getEditValue(ui,1)
    end
    _S.dlg.removeUi(h)
end

function _S.dlg.cancel_callback(ui)
    local h=_S.dlg.openDlgsUi[ui]
    _S.dlg.openDlgs[h].state=sim.dlgret_cancel
    _S.dlg.removeUi(h)
end

function _S.dlg.input_callback(ui,id,val)
    local h=_S.dlg.openDlgsUi[ui]
    _S.dlg.openDlgs[h].input=val
end

function _S.dlg.yes_callback(ui)
    local h=_S.dlg.openDlgsUi[ui]
    _S.dlg.openDlgs[h].state=sim.dlgret_yes
    _S.dlg.removeUi(h)
end

function _S.dlg.no_callback(ui)
    local h=_S.dlg.openDlgsUi[ui]
    _S.dlg.openDlgs[h].state=sim.dlgret_no
    _S.dlg.removeUi(h)
end

function _S.dlg.removeUi(handle)
    local ui=_S.dlg.openDlgs[handle].ui
    local x,y=simUI.getPosition(ui)
    _S.dlg.openDlgs[handle].previousPos={x,y}
    simUI.destroy(ui)
    _S.dlg.openDlgsUi[ui]=nil
    _S.dlg.openDlgs[handle].ui=nil
end

function _S.dlg.switch()
    if _S.dlg.openDlgsUi then
        for key,val in pairs(_S.dlg.openDlgsUi) do
            local ui=key
            local h=val
            _S.dlg.removeUi(h)
        end
    end
end

function _S.dlg.switchBack()
    if _S.dlg.openDlgsUi then
        local dlgs=sim.unpackTable(sim.packTable(_S.dlg.openDlgs)) -- make a deep copy
        for key,val in pairs(dlgs) do
            if val.state==sim.dlgret_still_open then
                _S.dlg.openDlgs[key]=nil
                sim.displayDialog(val.title,val.mainTxt,val.style,false,val.input,val.titleCols,val.dlgCols,val.previousPos,key)
            end
        end
    end
end
----------------------------------------------------------

-- Hidden, debugging functions:
----------------------------------------------------------
_S.debug={}
function _S.debug.entryFunc(info)
    local scriptName=info[1]
    local funcName=info[2]
    local funcType=info[3]
    local callIn=info[4]
    local debugLevel=info[5]
    local sysCall=info[6]
    local simTime=info[7]
    local simTimeStr=''
    if (debugLevel~=sim.scriptdebug_vars_interval) or (not _S.debug.lastInterval) or (sim.getSystemTimeInMs(-1)>_S.debug.lastInterval+1000) then
        _S.debug.lastInterval=sim.getSystemTimeInMs(-1)
        if sim.getSimulationState()~=sim.simulation_stopped then
            simTimeStr=simTime..' '
        end
        if (debugLevel>=sim.scriptdebug_vars) or (debugLevel==sim.scriptdebug_vars_interval) then
            local prefix='DEBUG: '..simTimeStr..' '
            local t=_S.debug.getVarChanges(prefix)
            if t then
                sim.addLog(sim.verbosity_msgs,t)
            end
        end
        if (debugLevel==sim.scriptdebug_allcalls) or (debugLevel==sim.scriptdebug_callsandvars) or ( (debugLevel==sim.scriptdebug_syscalls) and sysCall) then
            local t='DEBUG: '..simTimeStr
            if callIn then
                t=t..' --> '
            else
                t=t..' <-- '
            end
            t=t..funcName..' ('..funcType..')'
            sim.addLog(sim.verbosity_msgs,t)
        end
    end
end

function _S.debug.getVarChanges(pref)
    local t=''
    _S.debug.userVarsOld=_S.debug.userVars
    _S.debug.userVars=sim.unpackTable(sim.packTable(sim.getUserVariables())) -- deep copy
    if _S.debug.userVarsOld then
        if _S.debug.watchList and type(_S.debug.watchList)=='table' and #_S.debug.watchList>0 then
            for i=1,#_S.debug.watchList,1 do
                local str=_S.debug.watchList[i]
                if type(str)=='string' then
                    local var1=_S.debug.getVar('_S.debug.userVarsOld.'..str)
                    local var2=_S.debug.getVar('_S.debug.userVars.'..str)
                    if var1~=nil or var2~=nil then
                        t=_S.debug.getVarDiff(pref,str,var1,var2)
                    end
                end
            end
        else
            t=_S.debug.getVarDiff(pref,'',_S.debug.userVarsOld,_S.debug.userVars)
        end
    end
    _S.debug.userVarsOld=nil
    if #t>0 then
--        t=t:sub(1,-2) -- remove last linefeed
        t=t:sub(1,-4) -- remove last linefeed
        return t
    end
end

function _S.debug.getVar(varName)
    local f=loadstring('return '..varName)
    if f then
        local res,val=pcall(f)
        if res and val then
            return val
        end
    end
end

function _S.debug.getVarDiff(pref,varName,oldV,newV)
    local t=''
    local lf='<br>'--'\n'
    if ( type(oldV)==type(newV) ) and ( (type(oldV)~='table') or _S.comparableTables(oldV,newV) )  then  -- comparableTables: an empty map is seen as an array
        if type(newV)~='table' then
            if newV~=oldV then
                t=t..pref..'mod: '..varName..' ('..type(newV)..'): '.._S.getShortString(tostring(newV))..lf
            end
        else
            if isArray(oldV) and isArray(newV) then -- an empty map is seen as an array
                -- removed items:
                if #oldV>#newV then
                    for i=1,#oldV-#newV,1 do
                        t=t.._S.debug.getVarDiff(pref,varName..'['..i+#oldV-#newV..']',oldV[i+#oldV-#newV],nil)
                    end
                end
                -- added items:
                if #newV>#oldV then
                    for i=1,#newV-#oldV,1 do
                        t=t.._S.debug.getVarDiff(pref,varName..'['..i+#newV-#oldV..']',nil,newV[i+#newV-#oldV])
                    end
                end
                -- modified items:
                local l=math.min(#newV,#oldV)
                for i=1,l,1 do
                    t=t.._S.debug.getVarDiff(pref,varName..'['..i..']',oldV[i],newV[i])
                end
            else
                local nvarName=varName
                if nvarName~='' then nvarName=nvarName..'.' end
                -- removed items:
                for k,vo in pairs(oldV) do
                    if newV[k]==nil then
                        t=t.._S.debug.getVarDiff(pref,nvarName..k,vo,nil)
                    end
                end
                
                -- added items:
                for k,vn in pairs(newV) do
                    if oldV[k]==nil then
                        t=t.._S.debug.getVarDiff(pref,nvarName..k,nil,vn)
                    end
                end
                
                -- modified items:
                for k,vo in pairs(oldV) do
                    if newV[k] then
                        t=t.._S.debug.getVarDiff(pref,nvarName..k,vo,newV[k])
                    end
                end
            end
        end
    else
        if oldV==nil then
            if type(newV)~='table' then
                t=t..pref..'new: '..varName..' ('..type(newV)..'): '.._S.getShortString(tostring(newV))..lf
            else
                t=t..pref..'new: '..varName..' ('..type(newV)..')'..lf
                if isArray(newV) then
                    for i=1,#newV,1 do
                        t=t.._S.debug.getVarDiff(pref,varName..'['..i..']',nil,newV[i])
                    end
                else
                    local nvarName=varName
                    if nvarName~='' then nvarName=nvarName..'.' end
                    for k,v in pairs(newV) do
                        t=t.._S.debug.getVarDiff(pref,nvarName..k,nil,v)
                    end
                end
            end
        elseif newV==nil then
            if type(oldV)~='table' then
                t=t..pref..'del: '..varName..' ('..type(oldV)..'): '.._S.getShortString(tostring(oldV))..lf
            else
                t=t..pref..'del: '..varName..' ('..type(oldV)..')'..lf
            end
        else
            -- variable changed type.. register that as del and new:
            t=t.._S.debug.getVarDiff(pref,varName,oldV,nil)
            t=t.._S.debug.getVarDiff(pref,varName,nil,newV)
        end
    end
    return t
end
----------------------------------------------------------

-- Old stuff, mainly for backward compatibility:
----------------------------------------------------------
function sim.include(relativePathAndFile,cmd) require("sim_old") return sim.include(relativePathAndFile,cmd) end
function sim.includeRel(relativePathAndFile,cmd) require("sim_old") return sim.includeRel(relativePathAndFile,cmd) end
function sim.includeAbs(absPathAndFile,cmd) require("sim_old") return sim.includeAbs(absPathAndFile,cmd) end
function sim.canScaleObjectNonIsometrically(objHandle,scaleAxisX,scaleAxisY,scaleAxisZ) require("sim_old") return sim.canScaleObjectNonIsometrically(objHandle,scaleAxisX,scaleAxisY,scaleAxisZ) end
function sim.canScaleModelNonIsometrically(modelHandle,scaleAxisX,scaleAxisY,scaleAxisZ,ignoreNonScalableItems) require("sim_old") return sim.canScaleModelNonIsometrically(modelHandle,scaleAxisX,scaleAxisY,scaleAxisZ,ignoreNonScalableItems) end
function sim.scaleModelNonIsometrically(modelHandle,scaleAxisX,scaleAxisY,scaleAxisZ) require("sim_old") return sim.scaleModelNonIsometrically(modelHandle,scaleAxisX,scaleAxisY,scaleAxisZ) end
function sim.UI_populateCombobox(ui,id,items_array,exceptItems_map,currentItem,sort,additionalItemsToTop_array) require("sim_old") return sim.UI_populateCombobox(ui,id,items_array,exceptItems_map,currentItem,sort,additionalItemsToTop_array) end
----------------------------------------------------------

require('checkargs')
require('matrix')
require('grid')

return sim
