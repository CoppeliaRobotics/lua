local simIK={}

function __HIDDEN__.simIKLoopThroughAltConfigSolutions(ikEnvironment,jointHandles,desiredPose,confS,x,index)
    if index>#jointHandles then
        return {sim.unpackDoubleTable(sim.packDoubleTable(confS))} -- copy the table
    else
        local c={}
        for i=1,#jointHandles,1 do
            c[i]=confS[i]
        end
        local solutions={}
        while c[index]<=x[index][2] do
            local s=__HIDDEN__.simIKLoopThroughAltConfigSolutions(ikEnvironment,jointHandles,desiredPose,c,x,index+1,tipHandle)
            for i=1,#s,1 do
                solutions[#solutions+1]=s[i]
            end
            c[index]=c[index]+math.pi*2
        end
        return solutions
    end
end

function simIK.getAlternateConfigs(ikEnvironment,jointHandles,lowLimits,ranges)
    local lb=sim.setThreadAutomaticSwitch(false)
    local args={{type='number'},{type='table',size=1,subtype='number'},{type='table',size=-2,subtype='number',opt=true},{type='table',size=-2,subtype='number',opt=true}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,ikEnvironment,jointHandles,lowLimits,ranges)
    if err then error(err) end

    local retVal={}
    local ikEnv=simIK.duplicateEnvironment(ikEnvironment)
    local x={}
    local confS={}
    local err=false
    local inputConfig={}
    for i=1,#jointHandles,1 do
        inputConfig[i]=simIK.getJointPosition(ikEnv,jointHandles[i])
        local c,interv=simIK.getJointInterval(ikEnv,jointHandles[i])
        local t=simIK.getJointType(ikEnv,jointHandles[i])
        local sp=simIK.getJointScrewPitch(ikEnv,jointHandles[i])
        if t==simIK.jointtype_revolute and not c then
            if sp==0 then
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
            simIK.setJointPosition(ikEnv,jointHandles[i],inputConfig[i])
        end
        local desiredPose=0
        configs=__HIDDEN__.simIKLoopThroughAltConfigSolutions(ikEnv,jointHandles,desiredPose,confS,x,1)
    end
    simIK.eraseEnvironment(ikEnv)
    sim.setThreadAutomaticSwitch(lb)
    return configs
end

function simIK.applySceneToIkEnvironment(ikEnv,ikGroup)
    local lb=sim.setThreadAutomaticSwitch(false)
    local args={{type='number'},{type='number'}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,ikEnv,ikGroup)
    if err then error(err) end
    
    local groupData=__HIDDEN__.ikEnvs[ikEnv].ikGroups[ikGroup]
    if groupData.notYetApplied then
        -- Joint dependencies can go across IK elements. So apply them the first time here:
        for k,v in pairs(groupData.joints) do
            if sim.getJointMode(k)==sim.jointmode_dependent and sim.getJointType(k)~=sim.joint_spherical_subtype then
                local m,o,f=sim.getJointDependency(k)
                if m~=-1 then
                    if groupData.joints[m] then
                        simIK.setJointMode(ikEnv,v,simIK.jointmode_dependent)
                        simIK.setJointDependency(ikEnv,v,groupData.joints[m],o,f)
                    else
                        simIK.setJointMode(ikEnv,v,simIK.jointmode_passive)
                    end
                end
            end
        end
        groupData.notYetApplied=nil
    end
    for k,v in pairs(groupData.joints) do
        if sim.getJointType(k)==sim.joint_spherical_subtype then
            simIK.setSphericalJointMatrix(ikEnv,v,sim.getJointMatrix(k))
        else
            simIK.setJointPosition(ikEnv,v,sim.getJointPosition(k))
        end
    end
    for i=1,#groupData.targetBasePairs,1 do
        simIK.setObjectMatrix(ikEnv,groupData.targetBasePairs[i][3],groupData.targetBasePairs[i][4],sim.getObjectMatrix(groupData.targetBasePairs[i][1],groupData.targetBasePairs[i][2]))
    end
    sim.setThreadAutomaticSwitch(lb)
end

function simIK.applyIkToScene(ikEnv,ikGroup,applyOnlyWhenSuccessful)
    local lb=sim.setThreadAutomaticSwitch(false)
    local args={{type='number'},{type='number'},{type='boolean',opt=true}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,ikEnv,ikGroup,applyOnlyWhenSuccessful)
    if err then error(err) end
    
    simIK.applySceneToIkEnvironment(ikEnv,ikGroup)
    local groupData=__HIDDEN__.ikEnvs[ikEnv].ikGroups[ikGroup]
    local res=simIK.handleIkGroup(ikEnv,ikGroup)
    if applyOnlyWhenSuccessful==nil then applyOnlyWhenSuccessful=false end
    if res==simIK.result_success or not applyOnlyWhenSuccessful then
        for k,v in pairs(groupData.joints) do
            if not groupData.passiveJoints[k] then
                if sim.getJointType(k)==sim.joint_spherical_subtype then
                    if sim.getJointMode(k)~=sim.jointmode_force then
                        sim.setSphericalJointMatrix(k,simIK.getJointMatrix(ikEnv,v))
                    end
                else
                    if sim.getJointMode(k)==sim.jointmode_force and sim.isDynamicallyEnabled(k) then
                        sim.setJointTargetPosition(k,simIK.getJointPosition(ikEnv,v))
                    else    
                        sim.setJointPosition(k,simIK.getJointPosition(ikEnv,v))
                    end
                end
            end
        end
    end
    sim.setThreadAutomaticSwitch(lb)
    return res
end

function simIK.addIkElementFromScene(ikEnv,ikGroup,simBase,simTip,simTarget,constraints)
    local lb=sim.setThreadAutomaticSwitch(false)
    local args={{type='number'},{type='number'},{type='number'},{type='number'},{type='number'},{type='number'}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,ikEnv,ikGroup,simBase,simTip,simTarget,constraints)
    if err then error(err) end
    
    if not __HIDDEN__.ikEnvs then
        __HIDDEN__.ikEnvs={}
    end
    if not __HIDDEN__.ikEnvs[ikEnv] then
        __HIDDEN__.ikEnvs[ikEnv]={}
    end
    if not __HIDDEN__.ikEnvs[ikEnv].ikGroups then
        __HIDDEN__.ikEnvs[ikEnv].ikGroups={}
        __HIDDEN__.ikEnvs[ikEnv].allObjects={}
    end
    local groupData=__HIDDEN__.ikEnvs[ikEnv].ikGroups[ikGroup]
    -- allObjects, i.e. the mapping, need to be scoped by ik env, and not ik group,
    -- otherwise we may have duplicates:
    local allObjects=__HIDDEN__.ikEnvs[ikEnv].allObjects
    if not groupData then
        groupData={}
        groupData.passiveJoints={}
        groupData.joints={}
        groupData.bases={}
        groupData.targets={}
        groupData.targetBasePairs={}
        groupData.notYetApplied=true
        __HIDDEN__.ikEnvs[ikEnv].ikGroups[ikGroup]=groupData
    end
    local ikBase=-1
    if simBase~=-1 then
        ikBase=allObjects[simBase] -- maybe already there
        if not ikBase then
            ikBase=simIK.createDummy(ikEnv,sim.getObjectName(simBase))
            simIK.setObjectMatrix(ikEnv,ikBase,-1,sim.getObjectMatrix(simBase,-1))
            allObjects[simBase]=ikBase
        end
        groupData.bases[simBase]=ikBase
    end
    
    local ikTip=allObjects[simTip] -- maybe already there
    if not ikTip then
        ikTip=simIK.createDummy(ikEnv,sim.getObjectName(simTip))
        simIK.setObjectMatrix(ikEnv,ikTip,-1,sim.getObjectMatrix(simTip,-1))
        allObjects[simTip]=ikTip
    end

    local ikTarget=allObjects[simTarget] -- maybe already there
    if not ikTarget then
        ikTarget=simIK.createDummy(ikEnv,sim.getObjectName(simTarget))
        simIK.setObjectMatrix(ikEnv,ikTarget,-1,sim.getObjectMatrix(simTarget,-1))
        allObjects[simTarget]=ikTarget
    end
    groupData.targets[simTarget]=ikTarget
    groupData.targetBasePairs[#groupData.targetBasePairs+1]={simTarget,simBase,ikTarget,ikBase}
    
    simIK.setLinkedDummy(ikEnv,ikTip,ikTarget)

    local simPrevIterator=simTip
    local simIterator=sim.getObjectParent(simPrevIterator)
    local ikPrevIterator=ikTip
    local ikIterator=-1
    while simIterator~=simBase do
        if allObjects[simIterator] then
            -- object already added, and parenting to child done
            ikIterator=allObjects[simIterator]
        else
            if sim.getObjectType(simIterator)~=sim.object_joint_type then
                ikIterator=simIK.createDummy(ikEnv,sim.getObjectName(simIterator))
            else
                local t=sim.getJointType(simIterator)
                ikIterator=simIK.createJoint(ikEnv,t,sim.getObjectName(simIterator))
                local c,interv=sim.getJointInterval(simIterator)
                simIK.setJointInterval(ikEnv,ikIterator,c,interv)
                local res,sp=sim.getObjectFloatParameter(simIterator,sim.jointfloatparam_screw_pitch)
                simIK.setJointScrewPitch(ikEnv,ikIterator,sp)
                local res,sp=sim.getObjectFloatParameter(simIterator,sim.jointfloatparam_step_size)
                simIK.setJointMaxStepSize(ikEnv,ikIterator,sp)
                local res,sp=sim.getObjectFloatParameter(simIterator,sim.jointfloatparam_ik_weight)
                simIK.setJointIkWeight(ikEnv,ikIterator,sp)
                if t==sim.joint_spherical_subtype then
                    simIK.setSphericalJointMatrix(ikEnv,ikIterator,sim.getJointMatrix(simIterator))
                else
                    simIK.setJointPosition(ikEnv,ikIterator,sim.getJointPosition(simIterator))
                end
            end
            allObjects[simIterator]=ikIterator
            simIK.setObjectMatrix(ikEnv,ikIterator,-1,sim.getObjectMatrix(simIterator,-1))
        end 
        if sim.getObjectType(simIterator)==sim.object_joint_type then
            groupData.joints[simIterator]=ikIterator
        end
        simIK.setObjectParent(ikEnv,ikPrevIterator,ikIterator)
        simPrevIterator=simIterator
        ikPrevIterator=ikIterator
        simIterator=sim.getObjectParent(simIterator)
        ikIterator=simIK.getObjectParent(ikEnv,ikIterator)
    end
    simIK.setObjectParent(ikEnv,ikPrevIterator,ikBase)
    simIK.setObjectParent(ikEnv,ikTarget,ikBase)

    local ikElement=simIK.addIkElement(ikEnv,ikGroup,ikTip)
    simIK.setIkElementBase(ikEnv,ikGroup,ikElement,ikBase,-1)
    simIK.setIkElementConstraints(ikEnv,ikGroup,ikElement,constraints)
    sim.setThreadAutomaticSwitch(lb)
    return ikElement,allObjects
end

function simIK.eraseEnvironment(ikEnv)
    local lb=sim.setThreadAutomaticSwitch(false)
    local args={{type='number'}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,ikEnv)
    if err then error(err) end
    
    if __HIDDEN__.ikEnvs then
        __HIDDEN__.ikEnvs[ikEnv]=nil
    end
    simIK._eraseEnvironment(ikEnv)
    sim.setThreadAutomaticSwitch(lb)
end

function simIK.getConfigForTipPose(ikEnv,ikGroup,joints,thresholdDist,maxTime,metric,callback,auxData,jointOptions,lowLimits,ranges)
    local lb=sim.setThreadAutomaticSwitch(false)
    local args={{type='number'},{type='number'},{type='table',size=1,subtype='number'},{type='number',opt=true},{type='number',opt=true},{type='table',size=4,subtype='number',opt=true},{type='function',opt=true},{type='any',opt=true},{type='table',size=-3,subtype='number',opt=true},{type='table',size=-3,subtype='number',opt=true},{type='table',size=-3,subtype='number',opt=true}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,ikEnv,ikGroup,joints,thresholdDist,maxTime,metric,callback,auxData,jointOptions,lowLimits,ranges)
    if err then error(err) end

    local env=simIK.duplicateEnvironment(ikEnv)
    if thresholdDist==nil then thresholdDist=0.1 end
    if maxTime==nil then maxTime=0.5 end
    if metric==nil then metric={1,1,1,0.1} end
    if jointOptions==nil then jointOptions={} end
    if lowLimits==nil then lowLimits={} end
    if ranges==nil then ranges={} end
    local retVal
    if type(callback)=='string' then
        -- deprecated
        retVal=simIK._getConfigForTipPose(env,ikGroup,joints,thresholdDist,maxTime,metric,callback,auxData,jointOptions,lowLimits,ranges)
    else
        if maxTime<0 then 
            maxTime=-maxTime/1000 -- probably calling the function the old way 
        end
        if maxTime>2 then maxTime=2 end
        function __cb(config)
            return callback(config,auxData)
        end
        local funcNm,t
        if callback then
            funcNm='__cb'
            local nm=sim.getScriptName(sim.handle_self)
            if nm~='' then
                funcNm=funcNm..'@'..nm
            end
            t=sim.getScriptAttribute(sim.handle_self,sim.scriptattribute_scripttype)
        end
        retVal=simIK._getConfigForTipPose(env,ikGroup,joints,thresholdDist,-maxTime*1000,metric,funcNm,t,jointOptions,lowLimits,ranges)
    end
    simIK.eraseEnvironment(env)
    sim.setThreadAutomaticSwitch(lb)
    return retVal
end

function simIK.generatePath(ikEnv,ikGroup,ikJoints,tip,ptCnt,callback,auxData)
    local lb=sim.setThreadAutomaticSwitch(false)
    local args={{type='number'},{type='number'},{type='table',size=1,subtype='number'},{type='number'},{type='number'},{type='function',opt=true},{type='any',opt=true}}
    local err=sim.checkArgs(debug.getinfo(1,"n").name,args,ikEnv,ikGroup,ikJoints,tip,ptCnt,callback,auxData)
    if err then error(err) end

    local env=simIK.duplicateEnvironment(ikEnv)
    local targetHandle=simIK.getLinkedDummy(env,tip)
    local startMatrix=simIK.getObjectMatrix(env,tip,-1)
    local goalMatrix=simIK.getObjectMatrix(env,targetHandle,-1)
    local retPath={{}}
    for i=1,#ikJoints,1 do
        retPath[1][i]=simIK.getJointPosition(env,ikJoints[i])
    end
    local success=true
    if callback then
        success=callback(retPath[1])
    end
    if success then
        for j=1,ptCnt-1,1 do
            local t=j/(ptCnt-1)
            local m=sim.interpolateMatrices(startMatrix,goalMatrix,t)
            simIK.setObjectMatrix(env,targetHandle,-1,m)
            success=simIK.handleIkGroup(env,ikGroup)==simIK.result_success
            if not success then
                break
            end
            retPath[j+1]={}
            for i=1,#ikJoints,1 do
                retPath[j+1][i]=simIK.getJointPosition(env,ikJoints[i])
            end
            if callback then
                success=callback(retPath[j+1])
            end
            if not success then
                break
            end
        end
    end
    if not success then
        retPath={}
    end
    simIK.eraseEnvironment(env)
    sim.setThreadAutomaticSwitch(lb)
    return retPath
end

function simIK.init()
    -- can only be executed once sim.* functions were initialized
    sim.registerScriptFunction('simIK.getAlternateConfigs@simIK','table configs=simIK.getAlternateConfigs(number environmentHandle,table jointHandles,table lowLimits=nil,table ranges=nil)')
    sim.registerScriptFunction('simIK.addIkElementFromScene@simIK','number ikElement,table simToIkObjectMap=simIK.addIkElementFromScene(number environmentHandle\n,number ikGroup,number baseHandle,number tipHandle,\nnumber targetHandle,number constraints)')
    sim.registerScriptFunction('simIK.applySceneToIkEnvironment@simIK','simIK.applySceneToIkEnvironment(number environmentHandle,number ikGroup)')
    sim.registerScriptFunction('simIK.applyIkToScene@simIK','number result=simIK.applyIkToScene(number environmentHandle,number ikGroup,bool applyOnlyWhenSuccessful=false)')
    sim.registerScriptFunction('simIK.eraseEnvironment@simIK','simIK.eraseEnvironment(number environmentHandle)')
    sim.registerScriptFunction('simIK.getConfigForTipPose@simIK','table jointPositions=simIK.getConfigForTipPose(number environmentHandle,\nnumber ikGroupHandle,table jointHandles,number thresholdDist=0.1,\nnumber maxTime=0.5,table_4 metric={1,1,1,0.1},function validationCallback=nil,\nauxData=nil,table jointOptions={},table lowLimits={},table ranges={})')
    sim.registerScriptFunction('simIK.generatePath@simIK','table configurationList=simIK.generatePath(number environmentHandle,\nnumber ikGroupHandle,table jointHandles,number tipHandle,\nnumber pathPointCount,function validationCallback=nil,auxData=nil)')
    
    simIK.init=nil
end

if not __initFunctions then
    __initFunctions={}
end
__initFunctions[#__initFunctions+1]=simIK.init

return simIK
