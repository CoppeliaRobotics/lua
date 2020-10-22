local sim={}
__HIDDEN__={}
__HIDDEN__.dlg={}

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
            a[i]=__HIDDEN__.anyToString(a[i],{},99)
        elseif type(a[i])=='nil' then
            a[i]='nil'
        end
    end
    print(string.format(fmt,unpack(a,1,a.n)))
end

__HIDDEN__.require=require
function require(...)
    local fl
    if sim.setThreadSwitchAllowed then
        fl=sim.setThreadSwitchAllowed(false) -- important when called from coroutine
    end 
    local retVals={__HIDDEN__.require(...)}
    if fl then 
        sim.setThreadSwitchAllowed(fl) 
    end
    return unpack(retVals)
end

__HIDDEN__.pcall=pcall
function pcall(...)
    local fl
    if sim.setThreadSwitchAllowed then
        fl=sim.setThreadSwitchAllowed(false) -- important when called from coroutine
    end 
    local retVals={__HIDDEN__.pcall(...)}
    if fl then 
        sim.setThreadSwitchAllowed(fl) 
    end
    return unpack(retVals)
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

function sim.checkArgs(...)
    -- Usage:
    -- local args={{type='number',opt=true},{type='table',size=3,opt=true,subtype='number'},{type='table',size=-2,opt=true,subtype='number'}}
    -- local err=sim.checkArgs(debug.getinfo(1,"n").name,args,...)
    -- if err then error(err) end
    --
    -- Neg. table size n refers to the arg. index -n: it must be the same size as that argument

    local retVal
    for i=1,#arg[2],1 do
        local d=arg[2][i]
        local v=arg[i+2]
        if d.type=='table' then
            local reqSize=0
            if d.size then
                reqSize=d.size
            end
            if v==nil then
                if not d.opt then
                    retVal="Argument #"..i.." is not optional."
                    break
                end
            else
                if type(v)~='table' then
                    retVal="Type of argument #"..i.." is not correct (expected a table)." 
                    break
                else
                    if reqSize<0 then
                        if arg[2-reqSize]~=nil then
                            reqSize=#(arg[2-reqSize])
                        else
                            reqSize=-1
                        end
                    end
                    if reqSize>#v then
                        retVal="Size of table argument #"..i.." is not correct (expected a table of size "..reqSize..")." 
                        break
                    else
                        if d.subtype then
                            for j=1,#v,1 do
                                if type(v[j])~=d.subtype then
                                    retVal="Table argument #"..i.." contains invalid values (expected only "..d.subtype.."s)." 
                                    break
                                end
                            end
                        end
                    end
                end
            end
        else
            if v==nil then
                if not d.opt then
                    retVal="Argument #"..i.." is not optional."
                    break
                end
            else
                if d.type~=type(v) and d.type~='any' then
                    retVal="Type of argument #"..i.." is not correct (expected a "..d.type..")." 
                    break
                end
            end
        end
    end
    if retVal then
        retVal=retVal.." (in function '"..arg[1].."')"
    end
    return retVal
end

function sim.yawPitchRollToAlphaBetaGamma(yawAngle,pitchAngle,rollAngle)
    local args={{type='number'},{type='number'},{type='number'}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,yawAngle,pitchAngle,rollAngle)
    if err then error(err) end

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

function sim.alphaBetaGammaToYawPitchRoll(alpha,beta,gamma)
    local args={{type='number'},{type='number'},{type='number'}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,alpha,beta,gamma)
    if err then error(err) end

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
    local args={{type='table',opt=true}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,l)
    if err then error(err) end
    
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

function sim.getMatchingPersistentDataTags(pattern)
    local args={{type='string'}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,pattern)
    if err then error(err) end
    
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
                t=t..__HIDDEN__.tableToString(a[i],{},99)
            else
                t=t..__HIDDEN__.anyToString(a[i],{},99)
            end
        end
    end
    if #a==0 then
        t='nil'
    end
    sim.setThreadAutomaticSwitch(lb)
    return(t)
end

function table.pack(...)
    return {n=select("#", ...); ...}
end

function sim.displayDialog(title,mainTxt,style,modal,initTxt,titleCols,dlgCols,prevPos,dlgHandle)
    local args={{type='string'},{type='string'},{type='number'},{type='boolean'},{type='string',opt=true}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,title,mainTxt,style,modal,initTxt,titleCols,dlgCols,prevPos,dlgHandle)
    if err then error(err) end
    
    if sim.getBoolParameter(sim_boolparam_headless) then
        return -1
    end
    if type(initTxt)~='string' then
        initTxt=''
    end
    local retVal=-1
    local center=true
    if sim.boolAnd32(style,sim.dlgstyle_dont_center)>0 then
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

    if prevPos then
        xml=xml..' placement="absolute" position="'..prevPos[1]..','..prevPos[2]..'">'
    else
        if center then
            xml=xml..' placement="center">'
        else
            xml=xml..' placement="relative" position="-50,50">'
        end
    end
    mainTxt=string.gsub(mainTxt,"&&n","\n")
    xml=xml..'<label text="'..mainTxt..'"/>'
    if style==sim.dlgstyle_input then
        xml=xml..'<edit on-editing-finished="__HIDDEN__.dlg.input_callback" id="1"/>'
    end
    if style==sim.dlgstyle_ok or style==sim.dlgstyle_input then
        xml=xml..'<group layout="hbox" flat="true">'
        xml=xml..'<button text="Ok" on-click="__HIDDEN__.dlg.ok_callback"/>'
        xml=xml..'</group>'
    end
    if style==sim.dlgstyle_ok_cancel then
        xml=xml..'<group layout="hbox" flat="true">'
        xml=xml..'<button text="Ok" on-click="__HIDDEN__.dlg.ok_callback"/>'
        xml=xml..'<button text="Cancel" on-click="__HIDDEN__.dlg.cancel_callback"/>'
        xml=xml..'</group>'
    end
    if style==sim.dlgstyle_yes_no then
        xml=xml..'<group layout="hbox" flat="true">'
        xml=xml..'<button text="Yes" on-click="__HIDDEN__.dlg.yes_callback"/>'
        xml=xml..'<button text="No" on-click="__HIDDEN__.dlg.no_callback"/>'
        xml=xml..'</group>'
    end
    xml=xml..'</ui>'
    local ui=simUI.create(xml)
    if style==sim.dlgstyle_input then
        simUI.setEditValue(ui,1,initTxt)
    end
    if not __HIDDEN__.dlg.openDlgs then
        __HIDDEN__.dlg.openDlgs={}
        __HIDDEN__.dlg.openDlgsUi={}
    end
    if not __HIDDEN__.dlg.nextHandle then
        __HIDDEN__.dlg.nextHandle=0
    end
    if dlgHandle then
        retVal=dlgHandle
    else
        retVal=__HIDDEN__.dlg.nextHandle
        __HIDDEN__.dlg.nextHandle=__HIDDEN__.dlg.nextHandle+1
    end
    __HIDDEN__.dlg.openDlgs[retVal]={ui=ui,style=style,state=sim.dlgret_still_open,input=initTxt,title=title,mainTxt=mainTxt,titleCols=titleCols,dlgCols=dlgCols}
    __HIDDEN__.dlg.openDlgsUi[ui]=retVal
    
    if modal then
        while __HIDDEN__.dlg.openDlgs[retVal].state==sim.dlgret_still_open do
            sim.switchThread()
        end
    end
    return retVal
end

function sim.endDialog(dlgHandle)
    local args={{type='number'}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,dlgHandle)
    if err then error(err) end

    if not sim.getBoolParameter(sim_boolparam_headless) then
        if not __HIDDEN__.dlg.openDlgs[dlgHandle] then
            error("Argument #1 is not a valid dialog handle. (in function 'sim.endDialog')")
        end
        if __HIDDEN__.dlg.openDlgs[dlgHandle].state==sim.dlgret_still_open then
            __HIDDEN__.dlg.removeUi(dlgHandle)
        end
        if __HIDDEN__.dlg.openDlgs[dlgHandle].ui then
            __HIDDEN__.dlg.openDlgsUi[__HIDDEN__.dlg.openDlgs[dlgHandle].ui]=nil
        end
        __HIDDEN__.dlg.openDlgs[dlgHandle]=nil
    end
end

function sim.getDialogInput(dlgHandle)
    local args={{type='number'}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,dlgHandle)
    if err then error(err) end

    if sim.getBoolParameter(sim_boolparam_headless) then
        return ''
    end
    if not __HIDDEN__.dlg.openDlgs[dlgHandle] then
        error("Argument #1 is not a valid dialog handle. (in function 'sim.endDialog')")
    end
    local retVal
    retVal=__HIDDEN__.dlg.openDlgs[dlgHandle].input
    return retVal
end

function sim.getDialogResult(dlgHandle)
    local args={{type='number'}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,dlgHandle)
    if err then error(err) end

    if sim.getBoolParameter(sim_boolparam_headless) then
        return -1
    end
    if not __HIDDEN__.dlg.openDlgs[dlgHandle] then
        error("Argument #1 is not a valid dialog handle. (in function 'sim.endDialog')")
    end
    local retVal=-1
    retVal=__HIDDEN__.dlg.openDlgs[dlgHandle].state
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
    if __HIDDEN__.lastExecTime==nil then __HIDDEN__.lastExecTime={} end
    local h=string.dump(f)
    local now=sim.getSystemTime()
    if __HIDDEN__.lastExecTime[h]==nil or __HIDDEN__.lastExecTime[h]+t<now then
        f()
        __HIDDEN__.lastExecTime[h]=now
    end
end

function sysCallEx_beforeInstanceSwitch()
    __HIDDEN__.dlg.switch()
end

function sysCallEx_afterInstanceSwitch()
    __HIDDEN__.dlg.switchBack()
end

function sysCallEx_addOnScriptSuspend()
    __HIDDEN__.dlg.switch()
end

function sysCallEx_addOnScriptResume()
    __HIDDEN__.dlg.switchBack()
end

function sysCallEx_cleanup()
    if __HIDDEN__.dlg.openDlgsUi then
        for key,val in pairs(__HIDDEN__.dlg.openDlgsUi) do
            simUI.destroy(key)
        end
    end
end

function sim.getAlternateConfigs(jointHandles,inputConfig,tipHandle,lowLimits,ranges)
    local args={{type='table',size=1,subtype='number'},{type='table',size=-1,subtype='number'},{type='number',opt=true},{type='table',size=-1,opt=true,subtype='number'},{type='table',size=-1,opt=true,subtype='number'}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,jointHandles,inputConfig,tipHandle,lowLimits,ranges)
    if err then error(err) end
    
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
        if not tipHandle then
            tipHandle=-1
        end
        if tipHandle~=-1 then
            desiredPose=sim.getObjectMatrix(tipHandle,-1)
        end
        configs=__HIDDEN__.loopThroughAltConfigSolutions(jointHandles,desiredPose,confS,x,1,tipHandle)
    end
    
    for i=1,#jointHandles,1 do
        sim.setJointPosition(jointHandles[i],initConfig[i])
    end
    sim.setThreadAutomaticSwitch(lb)
    return configs
end

function sim.setObjectSelection(handles)
    local args={{type='table',subtype='number'}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,handles)
    if err then error(err) end
    
    sim.removeObjectFromSelection(sim.handle_all)
    sim.addObjectToSelection(handles)
end

function sim.moveToPose(flags,currentMatrix,maxVel,maxAccel,maxJerk,targetMatrix,callback,auxData,metric,timeStep)
    local lb=sim.setThreadAutomaticSwitch(false)
    
    local args={{type='number'},{type='table',size=12,subtype='number'},{type='table',size=1,subtype='number'},{type='table',size=-3,subtype='number'},{type='table',size=-3,subtype='number'},{type='table',size=12,subtype='number'},{type='function'},{type='any',opt=true},{type='table',size=4,subtype='number',opt=true},{type='number',opt=true}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,flags,currentMatrix,maxVel,maxAccel,maxJerk,targetMatrix,callback,auxData,metric,timeStep)
    if err then error(err) end
    if not metric and #maxVel<4 then
        error("Arguments #3, #4 and #5 should be of size 4. (in function 'sim.moveToPose')")    
    end
    if timeStep==nil then timeStep=0 end
    
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

function sim.moveToConfig(flags,currentPos,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetVel,callback,auxData,cyclicJoints,timeStep)
    local lb=sim.setThreadAutomaticSwitch(false)

    local args={{type='number'},{type='table',size=1,subtype='number'},{type='table',size=-2,subtype='number',opt=true},{type='table',size=-2,subtype='number',opt=true},{type='table',size=-2,subtype='number'},{type='table',size=-2,subtype='number'},{type='table',size=-2,subtype='number'},{type='table',size=-2,subtype='number'},{type='table',size=-2,subtype='number',opt=true},{type='function'},{type='any',opt=true},{type='table',size=-2,subtype='boolean',opt=true},{type='number',opt=true}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,flags,currentPos,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetVel,callback,auxData,cyclicJoints,timeStep)
    if err then error(err) end
    
    if timeStep==nil then timeStep=0 end
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

function sim.generateTimeOptimalTrajectory(path,minMaxVel,minMaxAccel,trajPtSamples,metric,boundaryCondition,timeout)
    local args={{type='table',subtype='table',size=2}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,path)
    if err then error(err) end
    local dof=#(path[1])
    local args={{type='table',subtype='table',size=2},
                {type='table',subtype='table',size=dof},
                {type='table',subtype='table',size=dof},
                {type='number',opt=true},
                {type='table',subtype='number',size=dof,opt=true},
                {type='string',opt=true},
                {type='number',opt=true}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,path,minMaxVel,minMaxAccel,trajPtSamples,metric,boundaryCondition,timeout)
    if err then error(err) end
    local lb=sim.setThreadAutomaticSwitch(false)
    if timeout==nil then timeout=5 end
    if trajPtSamples==nil then trajPtSamples=1000 end
    if boundaryCondition==nil then boundaryCondition='not-a-knot' end
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
            waypoints=path,
            velocity_limits=minMaxVel,
            acceleration_limits=minMaxAccel,
            bc_type=boundaryCondition
        })
        simB0.nodeCleanup(n)
    else
        error('BlueZero resolver was not detected.')
    end
    sim.setThreadAutomaticSwitch(lb)
    return r.qs[1],r.ts
end

function sim.getInterpolatedConfig(path,times,t,types,method,forceOpen)
    local args={{type='table',subtype='table',size=2},{type='table',subtype='number',size=-1,opt=true},{type='number'}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,path,times,t)
    if err then error(err) end
    local dof=#(path[1])
    local args={{type='table',subtype='table',size=2},{type='table',subtype='number',size=#path,opt=true},{type='number'},{type='table',subtype='number',size=dof,opt=true},{type='table',opt=true},{type='boolean',opt=true}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,path,times,t,types,method,forceOpen)
    if err then error(err) end
    if times==nil and #path>2 then
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
        if path[1][i]~=path[#path][i] then
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
    if #path>2 or times then
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
    if method and method.type=='quadraticBezier' then
        local i0,i1,i2
        if t<0.5 then
            if li==1 and not closed then
                retVal=__HIDDEN__.linearInterpolate(path[li],path[hi],t,types)
            else
                i0=li-1
                i1=li
                i2=hi
                if li==1 then
                    i0=#path-1
                end
                local a=__HIDDEN__.linearInterpolate(path[i0],path[i1],0.75+t*0.5,types)
                local b=__HIDDEN__.linearInterpolate(path[i1],path[i2],0.25+t*0.5,types)
                retVal=__HIDDEN__.linearInterpolate(a,b,0.5+t,types)
            end
        else
            if hi==#path and not closed then
                retVal=__HIDDEN__.linearInterpolate(path[li],path[hi],t,types)
            else
                i0=li
                i1=hi
                i2=hi+1
                if hi==#path then
                    i2=2
                end
                t=t-0.5
                local a=__HIDDEN__.linearInterpolate(path[i0],path[i1],0.5+t*0.5,types)
                local b=__HIDDEN__.linearInterpolate(path[i1],path[i2],t*0.5,types)
                retVal=__HIDDEN__.linearInterpolate(a,b,t,types)
            end
        end
    end
    if not method or method.type=='linear' then
        retVal=__HIDDEN__.linearInterpolate(path[li],path[hi],t,types)
    end
    return retVal
end

function sim.resamplePath(path,finalConfigCnt,metric,types,method,forceOpen)
    local args={{type='table',subtype='table',size=2}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,path)
    if err then error(err) end
    local dof=#(path[1])
    local args={{type='table',subtype='table',size=2},
                {type='number'},
                {type='table',subtype='number',size=dof,opt=true},
                {type='table',subtype='number',size=dof,opt=true},
                {type='table',opt=true},
                {type='boolean',opt=true},}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,path,finalConfigCnt,metric,types,method,forceOpen)
    if err then error(err) end

    local pathLengths=sim.getPathLengths(path,metric,types)
    local retVal={}
    for i=1,finalConfigCnt,1 do
        local c=sim.getInterpolatedConfig(path,pathLengths,pathLengths[#pathLengths]*(i-1)/(finalConfigCnt-1),types,method,forceOpen)
        retVal[i]=c
    end
    return retVal
end

function sim.getPathLengths(path,metric,types)
    local args={{type='table',subtype='table',size=2}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,path)
    if err then error(err) end
    local dof=#(path[1])
    local args={{type='table',subtype='table',size=2},
                {type='table',subtype='number',size=dof,opt=true},
                {type='table',subtype='number',size=dof,opt=true}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,path,metric,types)
    if err then error(err) end

    local dof=#(path[1])
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
    for i=1,#path-1,1 do
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

function sim.wait(dt,simTime)
    local args={{type='number'},{type='boolean',opt=true}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,dt,simTime)
    if err then error(err) end
    if simTime==nil then simTime=true end
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

function sim.waitForSignal(sigName)
    local args={{type='string'}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,sigName)
    if err then error(err) end
    local retVal
    while true do
        retVal=sim.getIntegerSignal(sigName) or sim.getFloatSignal(sigName) or sim.getStringSignal(sigName)
        if retVal then
            break
        end
        sim.switchThread()
    end
    return retVal
end

function sim.tubeRead(tubeHandle,blocking)
    -- For backward compatibility (01.10.2020)
    local args={{type='number'},{type='boolean',opt=true}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,tubeHandle,blocking)
    if err then error(err) end
    if blocking==nil then blocking=false end
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

function sim.serialRead(portHandle,length,blocking,closingStr,timeout)
    local args={{type='number'},{type='number'},{type='boolean',opt=true},{type='string',opt=true},{type='number',opt=true}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,portHandle,length,blocking,closingStr,timeout)
    if err then error(err) end
    if blocking==nil then blocking=false end
    if closingStr==nil then closingStr='' end
    if timeout==nil then timeout=0 end
    
    local retVal
    if blocking then
        local st=sim.getSystemTimeInMs(-1)
        while true do 
            local data=__HIDDEN__.serialPortData[portHandle]
            __HIDDEN__.serialPortData[portHandle]=''
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
                    __HIDDEN__.serialPortData[portHandle]=data
                end
                break
            end
            if closingStr~='' then
                local s,e=string.find(data,closingStr,1,true)
                if e then
                    retVal=string.sub(data,1,e)
                    if #data>e then
                        data=string.sub(data,e+1)
                        __HIDDEN__.serialPortData[portHandle]=data
                    end
                    break
                end
            end
            if sim.getSystemTimeInMs(st)>=(timeout*1000) and timeout~=0 then
                retVal=data
                break
            end
            sim.switchThread()
            __HIDDEN__.serialPortData[portHandle]=data
        end
    else
        local data=__HIDDEN__.serialPortData[portHandle]
        __HIDDEN__.serialPortData[portHandle]=''
        if #data<length then
            local d=sim._serialRead(portHandle,length-#data)
            if d then
                data=data..d
            end
        end
        if #data>length then
            retVal=string.sub(data,1,length)
            data=string.sub(data,length+1)
            __HIDDEN__.serialPortData[portHandle]=data
        else
            retVal=data
        end
    end
    return retVal
end

function sim.serialOpen(portString,baudRate)
    local args={{type='string'},{type='number'}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,portString,baudRate)
    if err then error(err) end
    
    local retVal=sim._serialOpen(portString,baudRate)
    if not __HIDDEN__.serialPortData then
        __HIDDEN__.serialPortData={}
    end
    __HIDDEN__.serialPortData[retVal]=''
    return retVal
end

function sim.serialClose(portHandle)
    local args={{type='number'}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,portHandle)
    if err then error(err) end

    sim._serialClose(portHandle)
    if __HIDDEN__.serialPortData then
        __HIDDEN__.serialPortData[portHandle]=nil
    end
end

function simRMLMoveToJointPositions(jhandles,flags,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetVel,direction)
    -- For backward compatibility (02.10.2020)
    return sim.rmlMoveToJointPositions(jhandles,flags,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetVel,direction)
end

function sim.rmlMoveToJointPositions(jhandles,flags,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetVel,direction)
    -- For backward compatibility (02.10.2020)
    local args={{type='table',size=1,subtype='number'},{type='number'},{type='table',size=-1,subtype='number',opt=true},{type='table',size=-1,subtype='number',opt=true},{type='table',size=-1,subtype='number'},{type='table',size=-1,subtype='number'},{type='table',size=-1,subtype='number'},{type='table',size=-1,subtype='number'},{type='table',size=-1,subtype='number',opt=true},{type='table',subtype='number',size=-1,opt=true}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,jhandles,flags,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetVel,direction)
    if err then error(err) end
    local lb=sim.setThreadAutomaticSwitch(false)
    
    if direction==nil then
        direction={}
        for i=1,#jhandles,1 do
            direction[i]=0
        end
    end
    function __HIDDEN__.tmpCb(conf,vel,accel,jhandles)
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
    
    local endPos,endVel,endAccel,timeLeft=sim.moveToConfig(flags,currentConf,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetVel,__HIDDEN__.tmpCb,jhandles,cycl)
    local res=0
    if endPos then res=1 end
    
    __HIDDEN__.tmpCb=nil
    sim.setThreadAutomaticSwitch(lb)
    return res,endPos,endVel,endAccel,timeLeft
end

function simRMLMoveToPosition(handle,rel,flags,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetQuat,targetVel)
    -- For backward compatibility (02.10.2020)
    return sim.rmlMoveToPose(handle,rel,flags,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetQuat,targetVel)
end

function sim.rmlMoveToPosition(handle,rel,flags,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetQuat,targetVel)
    -- For backward compatibility (02.10.2020)
    local args={{type='number'},{type='number'},{type='number'},{type='table',size=4,subtype='number',opt=true},{type='table',size=4,subtype='number',opt=true},{type='table',size=4,subtype='number'},{type='table',size=4,subtype='number'},{type='table',size=4,subtype='number'},{type='table',size=3,subtype='number',opt=true},{type='table',size=4,subtype='number',opt=true},{type='table',subtype='number',size=4,opt=true}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,handle,rel,flags,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetQuat,targetVel)
    if err then error(err) end
    local lb=sim.setThreadAutomaticSwitch(false)
    
    local mStart=sim.getObjectMatrix(handle,rel)
    if targetPos==nil then
        targetPos={mStart[4],mStart[8],mStart[12]}
    end
    if targetQuat==nil then
        targetQuat=sim.getObjectQuaternion(handle,rel)
    end
    local mGoal=sim.buildMatrixQ(targetPos,targetQuat)
    function __HIDDEN__.tmpCb(m,v,a,data)
        sim.setObjectMatrix(data.handle,data.rel,m)
    end
    local data={}
    data.handle=handle
    data.rel=rel
    local endMatrix,timeLeft=sim.moveToPose(flags,mStart,maxVel,maxAccel,maxJerk,mGoal,__HIDDEN__.tmpCb,data)
    local res=0
    local nPos,nQuat
    if endMatrix then 
        nPos={endMatrix[4],endMatrix[8],endMatrix[12]}
        nQuat=sim.getQuaternionFromMatrix(endMatrix)
        res=1 
    end
    __HIDDEN__.tmpCb=nil
    sim.setThreadAutomaticSwitch(lb)
    return res,nPos,nQuat,{0,0,0,0},{0,0,0,0},timeLeft
end


----------------------------------------------------------


-- Hidden, internal functions:
----------------------------------------------------------
function __HIDDEN__.linearInterpolate(conf1,conf2,t,types)
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

function __HIDDEN__.loopThroughAltConfigSolutions(jointHandles,desiredPose,confS,x,index,tipHandle)
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
            local s=__HIDDEN__.loopThroughAltConfigSolutions(jointHandles,desiredPose,c,x,index+1,tipHandle)
            for i=1,#s,1 do
                solutions[#solutions+1]=s[i]
            end
            c[index]=c[index]+math.pi*2
        end
        return solutions
    end
end

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
            return "[buffer string]"
        else
            local a,b=string.gsub(x,"[%a%d%p%s]", "@")
            if b~=#x then
                return "[string containing special chars]"
            else
                if #x>160 then
                    return "[long string]"
                else
                    return string.format('"%s"', x)
                end
            end
        end
    end
    return "[not a string]"
end

function __HIDDEN__.executeAfterLuaStateInit()
    quit=sim.quitSimulator
    exit=sim.quitSimulator
    sim.registerScriptFunction('quit@sim','quit()')
    sim.registerScriptFunction('exit@sim','exit()')
    sim.registerScriptFunction('sim.setDebugWatchList@sim','sim.setDebugWatchList(table vars=nil)')
    sim.registerScriptFunction('sim.getUserVariables@sim','table variables=sim.getUserVariables()')
    sim.registerScriptFunction('sim.getMatchingPersistentDataTags@sim','table tags=sim.getMatchingPersistentDataTags(string pattern)')

    sim.registerScriptFunction('sim.displayDialog@sim','number dlgHandle=sim.displayDialog(string title,string mainText,number style,\nboolean modal,string initTxt)')
    sim.registerScriptFunction('sim.getDialogResult@sim','number result=sim.getDialogResult(number dlgHandle)')
    sim.registerScriptFunction('sim.getDialogInput@sim','string input=sim.getDialogInput(number dlgHandle)')
    sim.registerScriptFunction('sim.endDialog@sim','number result=sim.endDialog(number dlgHandle)')
    sim.registerScriptFunction('sim.yawPitchRollToAlphaBetaGamma@sim','number alphaAngle,number betaAngle,number gammaAngle=sim.yawPitchRollToAlphaBetaGamma(\nnumber yawAngle,number pitchAngle,number rollAngle)')
    sim.registerScriptFunction('sim.alphaBetaGammaToYawPitchRoll@sim','number yawAngle,number pitchAngle,number rollAngle=sim.alphaBetaGammaToYawPitchRoll(\nnumber alphaAngle,number betaAngle,number gammaAngle)')
    sim.registerScriptFunction('sim.getAlternateConfigs@sim','table configs=sim.getAlternateConfigs(table jointHandles,\ntable inputConfig,number tipHandle=-1,table lowLimits=nil,table ranges=nil)')
    sim.registerScriptFunction('sim.setObjectSelection@sim','sim.setObjectSelection(table handles)')
    
    sim.registerScriptFunction('sim.moveToPose@sim','table_12 endMatrix,number timeLeft=sim.moveToPose(number flags,table_12 currentMatrix,\ntable maxVel,table maxAccel,table maxJerk,table_12 targetMatrix,\nfunction callback,auxData=nil,table_4 metric=nil,number timeStep=0)')
    sim.registerScriptFunction('sim.moveToConfig@sim','table endPos,table endVel,table endAccel,number timeLeft=sim.moveToConfig(number flags,\ntable currentPos,table currentVel,table currentAccel,table maxVel,table maxAccel,\ntable maxJerk,table targetPos,table targetVel,function callback,auxData=nil,table cyclicJoints=nil,number timeStep=0)')
    sim.registerScriptFunction('sim.switchThread@sim','sim.switchThread()')

    sim.registerScriptFunction('sim.getInterpolatedConfig@sim',"table config=sim.getInterpolatedConfig(table path,table times=nil,number t,table types=nil,method={type='linear'},forceOpen=false)")
    sim.registerScriptFunction('sim.resamplePath@sim','table path=sim.resamplePath(table path,number finalConfigCnt,table metric=nil,table types=nil)')
    sim.registerScriptFunction('sim.getPathLengths@sim','table pathLengths,number totalLength=sim.getPathLengths(table path,table metric=nil,table types=nil)')
    sim.registerScriptFunction('sim.generateTimeOptimalTrajectory@sim',"table path,table times=sim.generateTimeOptimalTrajectory(table path,table_2 minMaxVel,table_2 minMaxAccel,\nnumber trajPtSamples=1000,metric=nil,string boundaryCondition='not-a-knot',number timeout=5)")

    sim.registerScriptFunction('sim.wait@sim','number timeLeft=sim.wait(number dt,boolean simulationTime=true)')
    sim.registerScriptFunction('sim.waitForSignal@sim','number/string sigVal=sim.waitForSignal(string sigName)')
    
    sim.registerScriptFunction('sim.serialOpen@sim','number portHandle=sim.serialOpen(string portString,number baudrate)')
    sim.registerScriptFunction('sim.serialClose@sim','sim.serialClose(number portHandle)')
    sim.registerScriptFunction('sim.serialRead@sim',"string data=sim.serialRead(number portHandle,number dataLengthToRead,boolean blockingOperation,string closingString='',number timeout=0)")
    sim.registerScriptFunction('sim.rmlMoveToJointPositions@sim',"Deprecated. Use 'sim.moveToConfig' instead")
    sim.registerScriptFunction('sim.rmlMoveToPosition@sim',"Deprecated. Use 'sim.moveToPose' instead")
    
    if __initFunctions then
        for i=1,#__initFunctions,1 do
            __initFunctions[i]()
        end
        __initFunctions=nil
    end
    
    __HIDDEN__.initGlobals={}
    for key,val in pairs(_G) do
        __HIDDEN__.initGlobals[key]=true
    end
    __HIDDEN__.initGlobals.__HIDDEN__=nil
    __HIDDEN__.executeAfterLuaStateInit=nil
end

function __HIDDEN__.dlg.ok_callback(ui)
    local h=__HIDDEN__.dlg.openDlgsUi[ui]
    __HIDDEN__.dlg.openDlgs[h].state=sim.dlgret_ok
    if __HIDDEN__.dlg.openDlgs[h].style==sim.dlgstyle_input then
        __HIDDEN__.dlg.openDlgs[h].input=simUI.getEditValue(ui,1)
    end
    __HIDDEN__.dlg.removeUi(h)
end

function __HIDDEN__.dlg.cancel_callback(ui)
    local h=__HIDDEN__.dlg.openDlgsUi[ui]
    __HIDDEN__.dlg.openDlgs[h].state=sim.dlgret_cancel
    __HIDDEN__.dlg.removeUi(h)
end

function __HIDDEN__.dlg.input_callback(ui,id,val)
    local h=__HIDDEN__.dlg.openDlgsUi[ui]
    __HIDDEN__.dlg.openDlgs[h].input=val
end

function __HIDDEN__.dlg.yes_callback(ui)
    local h=__HIDDEN__.dlg.openDlgsUi[ui]
    __HIDDEN__.dlg.openDlgs[h].state=sim.dlgret_yes
    __HIDDEN__.dlg.removeUi(h)
end

function __HIDDEN__.dlg.no_callback(ui)
    local h=__HIDDEN__.dlg.openDlgsUi[ui]
    __HIDDEN__.dlg.openDlgs[h].state=sim.dlgret_no
    __HIDDEN__.dlg.removeUi(h)
end

function __HIDDEN__.dlg.removeUi(handle)
    local ui=__HIDDEN__.dlg.openDlgs[handle].ui
    local x,y=simUI.getPosition(ui)
    __HIDDEN__.dlg.openDlgs[handle].previousPos={x,y}
    simUI.destroy(ui)
    __HIDDEN__.dlg.openDlgsUi[ui]=nil
    __HIDDEN__.dlg.openDlgs[handle].ui=nil
end

function __HIDDEN__.dlg.switch()
    if __HIDDEN__.dlg.openDlgsUi then
        for key,val in pairs(__HIDDEN__.dlg.openDlgsUi) do
            local ui=key
            local h=val
            __HIDDEN__.dlg.removeUi(h)
        end
    end
end

function __HIDDEN__.dlg.switchBack()
    if __HIDDEN__.dlg.openDlgsUi then
        local dlgs=sim.unpackTable(sim.packTable(__HIDDEN__.dlg.openDlgs)) -- make a deep copy
        for key,val in pairs(dlgs) do
            if val.state==sim.dlgret_still_open then
                __HIDDEN__.dlg.openDlgs[key]=nil
                sim.displayDialog(val.title,val.mainTxt,val.style,false,val.input,val.titleCols,val.dlgCols,val.previousPos,key)
            end
        end
    end
end
----------------------------------------------------------

-- Hidden, debugging functions:
----------------------------------------------------------
__HIDDEN__.debug={}
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
            local prefix='DEBUG: '..simTimeStr..' '
            local t=__HIDDEN__.debug.getVarChanges(prefix)
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

return sim
