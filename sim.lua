local sim={}
__HIDDEN__={}
__HIDDEN__.dlg={}
printToConsole=print -- will be overwritten further down

-- Various useful functions:
----------------------------------------------------------
function sim.yawPitchRollToAlphaBetaGamma(yawAngle,pitchAngle,rollAngle)
    sim.setThreadAutomaticSwitch(false)
    local Rx=sim.buildMatrix({0,0,0},{rollAngle,0,0})
    local Ry=sim.buildMatrix({0,0,0},{0,pitchAngle,0})
    local Rz=sim.buildMatrix({0,0,0},{0,0,yawAngle})
    local m=sim.multiplyMatrices(Ry,Rx)
    m=sim.multiplyMatrices(Rz,m)
    local alphaBetaGamma=sim.getEulerAnglesFromMatrix(m)
    local alpha=alphaBetaGamma[1]
    local beta=alphaBetaGamma[2]
    local gamma=alphaBetaGamma[3]
    sim.setThreadAutomaticSwitch(true)
    return alpha,beta,gamma
end

function sim.alphaBetaGammaToYawPitchRoll(alpha,beta,gamma)
    sim.setThreadAutomaticSwitch(false)
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
    sim.setThreadAutomaticSwitch(true)
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
    local result = {}
    for index, value in ipairs(sim.getPersistentDataTags()) do
        if value:match(pattern) then
            result[#result + 1] = value
        end
    end
    return result
end

function print(...)
    sim.setThreadAutomaticSwitch(false)
    sim.addLog(sim.verbosity_scriptinfos+sim.verbosity_undecorated,getAsString(...))
    sim.setThreadAutomaticSwitch(true)
end

function getAsString(...)
    sim.setThreadAutomaticSwitch(false)
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
    sim.setThreadAutomaticSwitch(true)
    return(t)
end

function table.pack(...)
    return {n=select("#", ...); ...}
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


function sim.displayDialog(title,mainTxt,style,modal,initTxt,titleCols,dlgCols,prevPos,dlgHandle)
    if sim.getBoolParameter(sim_boolparam_headless) then
        return -1
    end
    assert(type(title)=='string' and type(mainTxt)=='string' and type(style)=='number' and type(modal)=='boolean',"One of the function's argument type is not correct")
    if type(initTxt)~='string' then
        initTxt=''
    end
    local retVal=-1
    local center=true
    if sim.boolAnd32(style,sim.dlgstyle_dont_center)>0 then
        center=false
        style=style-sim.dlgstyle_dont_center
    end
    assert(not modal or sim.isScriptExecutionThreaded()>0,"Can't use modal operation with non-threaded scripts")
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
    if not sim.getBoolParameter(sim_boolparam_headless) then
        assert(type(dlgHandle)=='number' and __HIDDEN__.dlg.openDlgs and __HIDDEN__.dlg.openDlgs[dlgHandle],"Argument 1 is not a valid dialog handle")
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
    if sim.getBoolParameter(sim_boolparam_headless) then
        return ''
    end
    local retVal
    assert(type(dlgHandle)=='number' and __HIDDEN__.dlg.openDlgs and __HIDDEN__.dlg.openDlgs[dlgHandle],"Argument 1 is not a valid dialog handle")
    retVal=__HIDDEN__.dlg.openDlgs[dlgHandle].input
    return retVal
end

function sim.getDialogResult(dlgHandle)
    if sim.getBoolParameter(sim_boolparam_headless) then
        return -1
    end
    local retVal=-1
    assert(type(dlgHandle)=='number' and __HIDDEN__.dlg.openDlgs and __HIDDEN__.dlg.openDlgs[dlgHandle],"Argument 1 is not a valid dialog handle")
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
    local retVal={}
    sim.setThreadAutomaticSwitch(false)
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
    sim.setThreadAutomaticSwitch(true)
    return configs
end

function sim.setObjectSelection(handles)
    sim.removeObjectFromSelection(sim.handle_all)
    sim.addObjectToSelection(handles)
end

function sim.moveToPose(flags,currentMatrix,maxVel,maxAccel,maxJerk,targetMatrix,callback,auxData,metric)
    sim.setThreadAutomaticSwitch(false)
    local outMatrix=sim.unpackDoubleTable(sim.packDoubleTable(currentMatrix))
    local axis,angle=sim.getRotationAxis(currentMatrix,targetMatrix)
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
                result,newPosVelAccel=sim.rmlStep(rmlObject,sim.getSimulationTimeStep())
                if result~=-1 then
                    local t=newPosVelAccel[1]/distance
                    local mi=sim.interpolateMatrices(currentMatrix,targetMatrix,t)
                    local nv={newPosVelAccel[2]}
                    local na={newPosVelAccel[3]}
                    callback(mi,nv,na,auxData)
                end
                sim.switchThread()
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
            result,newPosVelAccel=sim.rmlStep(rmlObject,sim.getSimulationTimeStep())
            if result~=-1 then
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
            sim.switchThread()
        end
        sim.rmlRemove(rmlObject)
    end
    sim.setThreadAutomaticSwitch(true)
    return outMatrix
end

function sim.moveToConfig(flags,currentPos,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetVel,callback,auxData,cyclicJoints)
    sim.setThreadAutomaticSwitch(false)
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
    while result==0 do
        result,newPosVelAccel=sim.rmlStep(rmlObject,sim.getSimulationTimeStep())
        if result~=-1 then
            for i=1,#currentPos,1 do
                outPos[i]=newPosVelAccel[i]
                outVel[i]=newPosVelAccel[#currentPos+i]
                outAccel[i]=newPosVelAccel[#currentPos*2+i]
            end
            callback(outPos,outVel,outAccel,auxData)
        end
        sim.switchThread()
    end
    sim.rmlRemove(rmlObject)
    sim.setThreadAutomaticSwitch(true)
    return outPos,outVel,outAccel
end

function sim.switchThread()
    if sim.isScriptRunningInThread()==1 then
        sim._switchThread()
    else
        coroutine.yield()
    end
end
----------------------------------------------------------


-- Hidden, internal functions:
----------------------------------------------------------
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
    sim.registerScriptFunction('sim.setDebugWatchList@sim','sim.setDebugWatchList(table vars)')
    sim.registerScriptFunction('sim.getUserVariables@sim','table variables=sim.getUserVariables()')
    sim.registerScriptFunction('sim.getMatchingPersistentDataTags@sim','table tags=sim.getMatchingPersistentDataTags(string pattern)')

    sim.registerScriptFunction('sim.displayDialog@sim','number dlgHandle=sim.displayDialog(string title,string mainText,number style,\nboolean modal,string initTxt)')
    sim.registerScriptFunction('sim.getDialogResult@sim','number result=sim.getDialogResult(number dlgHandle)')
    sim.registerScriptFunction('sim.getDialogInput@sim','string input=sim.getDialogInput(number dlgHandle)')
    sim.registerScriptFunction('sim.endDialog@sim','number result=sim.endDialog(number dlgHandle)')
    sim.registerScriptFunction('sim.yawPitchRollToAlphaBetaGamma@sim','number alphaAngle,number betaAngle,number gammaAngle=sim.yawPitchRollToAlphaBetaGamma(\nnumber yawAngle,number pitchAngle,number rollAngle)')
    sim.registerScriptFunction('sim.alphaBetaGammaToYawPitchRoll@sim','number yawAngle,number pitchAngle,number rollAngle=sim.alphaBetaGammaToYawPitchRoll(\nnumber alphaAngle,number betaAngle,number gammaAngle)')
    sim.registerScriptFunction('sim.getAlternateConfigs@sim','table configs=sim.getAlternateConfigs(table jointHandles,\ntable inputConfig,number tipHandle=-1,table lowLimits=nil,table ranges=nil)')
    sim.registerScriptFunction('sim.setObjectSelection@sim','sim.setObjectSelection(number handles)')
    
    sim.registerScriptFunction('sim.moveToPose@sim','table_12 endMatrix=sim.moveToPose(number flags,table_12 currentMatrix,\ntable maxVel,table maxAccel,table maxJerk,table_12 targetMatrix,\nfunction callback,auxData,table_4 metric=nil)')
    sim.registerScriptFunction('sim.moveToConfig@sim','table endPos,table endVel,table endAccel=sim.moveToConfig(number flags,\ntable currentPos,table currentVel,table currentAccel,table maxVel,table maxAccel,\ntable maxJerk,table targetPos,table targetVel,function callback,auxData,table cyclicJoints=nil)')
    sim.registerScriptFunction('sim.switchThread@sim','sim.switchThread()')
    
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
