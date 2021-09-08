-----------------------------------------
-- Required for backward compatibility --
-----------------------------------------

function simRMLMoveToJointPositions(jhandles,flags,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetVel,direction)
    -- Deprecated function, for backward compatibility (02.10.2020)
    return sim.rmlMoveToJointPositions(jhandles,flags,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetVel,direction)
end

function sim.rmlMoveToJointPositions(...)
    -- Deprecated function, for backward compatibility (02.10.2020)
    
    local jhandles,flags,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetVel,direction=checkargs({{type='table',size='1..*',item_type='int'},{type='int'},{type='table',size='1..*',item_type='float',nullable=true},{type='table',size='1..*',item_type='float',nullable=true},{type='table',size='1..*',item_type='float'},{type='table',size='1..*',item_type='float'},{type='table',size='1..*',item_type='float'},{type='table',size='1..*',item_type='float'},{type='table',size='1..*',item_type='float',default=NIL,nullable=true},{type='table',item_type='float',size='1..*',default=NIL,nullable=true}},...)
    local dof=#jhandles
    
    if dof<1 or (currentVel and dof>#currentVel) or (currentAccel and dof>#currentAccel) or dof>#maxVel or dof>#maxAccel or dof>#maxJerk or dof>#targetPos or (targetVel and dof>#targetVel) or (direction and dof>#direction) then
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
    -- Deprecated function, for backward compatibility (02.10.2020)
    return sim.rmlMoveToPose(handle,rel,flags,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetQuat,targetVel)
end

function sim.rmlMoveToPosition(...)
    -- Deprecated function, for backward compatibility (02.10.2020)
    local handle,rel,flags,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetQuat,targetVel=checkargs({{type='int'},{type='int'},{type='int'},{type='table',size=4,item_type='float',nullable=true},{type='table',size=4,item_type='float',nullable=true},{type='table',size=4,item_type='float'},{type='table',size=4,item_type='float'},{type='table',size=4,item_type='float'},{type='table',size=3,item_type='float',nullable=true},{type='table',size=4,item_type='float',default=NIL,nullable=true},{type='table',item_type='float',size=4,default=NIL,nullable=true}},...)

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
    -- Deprecated function, for backward compatibility (02.10.2020)
    return math.floor(a)|math.floor(b)
end
function sim.boolAnd32(a,b)
    -- Deprecated function, for backward compatibility (02.10.2020)
    return math.floor(a)&math.floor(b)
end
function sim.boolXor32(a,b)
    -- Deprecated function, for backward compatibility (02.10.2020)
    return math.floor(a)~math.floor(b)
end
function sim.boolOr16(a,b)
    -- Deprecated function, for backward compatibility (02.10.2020)
    return math.floor(a)|math.floor(b)
end
function sim.boolAnd16(a,b)
    -- Deprecated function, for backward compatibility (02.10.2020)
    return math.floor(a)&math.floor(b)
end
function sim.boolXor16(a,b)
    -- Deprecated function, for backward compatibility (02.10.2020)
    return math.floor(a)~math.floor(b)
end

function sim.setSimilarName(handle,original,suffix)
    -- Deprecated function, for backward compatibility (16.06.2021)
    sim.setObjectName(handle,'__setSimilarName__tmp__')
    local base
    local hash=''
    local index=-1
    local p=string.find(original,'#%d')
    if p then
        base=original:sub(1,p-1)
        hash='#'
        index=math.floor(tonumber(original:sub(p+1)))
    else
        base=original
    end
    base=base..suffix
    local cnt=-1
    local newName
    while true do
        local nm=base
        if hash=='#' then
            if cnt>=0 then
                nm=nm..cnt
            end
            nm=nm..'#'..index
            newName=nm
            cnt=cnt+1
        else
            if index>=0 then
                nm=nm..index
            end
            newName=nm
            nm=nm..'#'
            index=index+1
        end
        if sim.getObjectHandle(nm,{noError=true})==-1 then
            break
        end
    end
    sim.setObjectName(handle,newName)
end

function sim.tubeRead(...)
    -- Deprecated function, for backward compatibility (01.10.2020)
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

function sim.getObjectHandle_noErrorNoSuffixAdjustment(name)
    -- Deprecated function, for backward compatibility (16.06.2021)
    local suff=sim.getNameSuffix(nil)
    sim.setNameSuffix(-1)
    local retVal=sim.getObjectHandle(name,{noError=true})
    sim.setNameSuffix(suff)
    return retVal
end

function sim.moveToPosition(objH,relH,p,o,v,a,m)
    -- Deprecated function, for backward compatibility (06.07.2021)
    local dt=0
    local r=sim._moveToPos_1(objH,relH,p,o,v,a,m)
    if r>=0 then
        local lb=sim.setThreadAutomaticSwitch(false)
        local res=0
        while res==0 do
            res,dt=sim._moveToPos_2(r)
            sim.switchThread()
        end
        sim._del(r)
        sim.setThreadAutomaticSwitch(lb)
    end
    return dt
end

function sim.moveToJointPositions(t1,t2,v,a,al)
    -- Deprecated function, for backward compatibility (06.07.2021)
    local dt=0
    local r=sim._moveToJointPos_1(t1,t2,v,a,al)
    if r>=0 then
        local lb=sim.setThreadAutomaticSwitch(false)
        local res=0
        while res==0 do
            res,dt=sim._moveToJointPos_2(r)
            sim.switchThread()
        end
        sim._del(r)
        sim.setThreadAutomaticSwitch(lb)
    end
    return dt
end

function sim.moveToObject(objH,obj2H,op,rd,v,a)
    -- Deprecated function, for backward compatibility (06.07.2021)
    local dt=0
    local r=sim._moveToObj_1(objH,obj2H,op,rd,v,a)
    if r>=0 then
        local lb=sim.setThreadAutomaticSwitch(false)
        local res=0
        while res==0 do
            res,dt=sim._moveToObj_2(r)
            sim.switchThread()
        end
        sim._del(r)
        sim.setThreadAutomaticSwitch(lb)
    end
    return dt
end

function sim.followPath(objH,pathH,op,p,v,a)
    -- Deprecated function, for backward compatibility (06.07.2021)
    local dt=0
    local r=sim._followPath_1(objH,pathH,op,p,v,a)
    if r>=0 then
        local lb=sim.setThreadAutomaticSwitch(false)
        local res=0
        while res==0 do
            res,dt=sim._followPath_2(r)
            sim.switchThread()
        end
        sim._del(r)
        sim.setThreadAutomaticSwitch(lb)
    end
    return dt
end

function sim.include(relativePathAndFile,cmd)
    -- Relative to the CoppeliaSimLib path
    if not __notFirst__ then
        local appPath=sim.getStringParam(sim.stringparam_application_path)
        if sim.getInt32Param(sim.intparam_platform)==1 then
            appPath=appPath.."/../../.."
        end
        sim.includeAbs(appPath..relativePathAndFile,cmd)
    else
        if __scriptCodeToRun__ then
            __scriptCodeToRun__()
        end
    end
end

function sim.includeRel(relativePathAndFile,cmd)
    -- Relative to the current scene path
    if not __notFirst__ then
        local scenePath=sim.getStringParam(sim.stringparam_scene_path)
        sim.includeAbs(scenePath..relativePathAndFile,cmd)
    else
        if __scriptCodeToRun__ then
            __scriptCodeToRun__()
        end
    end
end

function sim.includeAbs(absPathAndFile,cmd)
    -- Absolute path
    if not __notFirst__ then
        __notFirst__=true
        __scriptCodeToRun__=assert(loadfile(absPathAndFile))
        if cmd then
            local tmp=assert(loadstring(cmd))
            if tmp then
                tmp()
            end
        end
    end
    if __scriptCodeToRun__ then
        __scriptCodeToRun__()
    end
end

function sim.canScaleObjectNonIsometrically(objHandle,scaleAxisX,scaleAxisY,scaleAxisZ)
    local xIsY=(math.abs(1-math.abs(scaleAxisX/scaleAxisY))<0.001)
    local xIsZ=(math.abs(1-math.abs(scaleAxisX/scaleAxisZ))<0.001)
    local xIsYIsZ=(xIsY and xIsZ)
    if xIsYIsZ then
        return true -- iso scaling in this case
    end
    local t=sim.getObjectType(objHandle)
    if t==sim.object_joint_type then
        return true
    end
    if t==sim.object_dummy_type then
        return true
    end
    if t==sim.object_camera_type then
        return true
    end
    if t==sim.object_mirror_type then
        return true
    end
    if t==sim.object_light_type then
        return true
    end
    if t==sim.object_forcesensor_type then
        return true
    end
    if t==sim.object_path_type then
        return true
    end
    if t==sim.object_pointcloud_type then
        return false
    end
    if t==sim.object_octree_type then
        return false
    end
    if t==sim.object_graph_type then
        return false
    end
    if t==sim.object_proximitysensor_type then
        local p=sim.getObjectInt32Param(objHandle,sim.proxintparam_volume_type)
        if p==sim.volume_cylinder then
            return xIsY
        end
        if p==sim.volume_disc then
            return xIsZ
        end
        if p==sim.volume_cone then
            return false
        end
        if p==sim.volume_randomizedray then
            return false
        end
        return true
    end
    if t==sim.object_mill_type then
        local p=sim.getObjectInt32Param(objHandle,sim.millintparam_volume_type)
        if p==sim.volume_cylinder then
            return xIsY
        end
        if p==sim.volume_disc then
            return xIsZ
        end
        if p==sim.volume_cone then
            return false
        end
        return true
    end
    if t==sim.object_visionsensor_type then
        return xIsY
    end
    if t==sim.object_shape_type then
        local r,pt=sim.getShapeGeomInfo(objHandle)
        if sim.boolAnd32(r,1)~=0 then
            return false -- compound
        end
        if pt==sim.pure_primitive_spheroid then
            return false
        end
        if pt==sim.pure_primitive_disc then
            return xIsY
        end
        if pt==sim.pure_primitive_cylinder then
            return xIsY
        end
        if pt==sim.pure_primitive_cone then
            return xIsY
        end
        if pt==sim.pure_primitive_heightfield then
            return xIsY
        end
        return true
    end
end

function sim.canScaleModelNonIsometrically(modelHandle,scaleAxisX,scaleAxisY,scaleAxisZ,ignoreNonScalableItems)
    local xIsY=(math.abs(1-math.abs(scaleAxisX/scaleAxisY))<0.001)
    local xIsZ=(math.abs(1-math.abs(scaleAxisX/scaleAxisZ))<0.001)
    local yIsZ=(math.abs(1-math.abs(scaleAxisY/scaleAxisZ))<0.001)
    local xIsYIsZ=(xIsY and xIsZ)
    if xIsYIsZ then
        return true -- iso scaling in this case
    end
    local allDescendents=sim.getObjectsInTree(modelHandle,sim.handle_all,1)
    -- First the model base:
    local t=sim.getObjectType(modelHandle)
    if (t==sim.object_pointcloud_type) or (t==sim.object_pointcloud_type) or (t==sim.object_pointcloud_type) then
        if not ignoreNonScalableItems then
            if not sim.canScaleObjectNonIsometrically(modelHandle,scaleAxisX,scaleAxisY,scaleAxisZ) then
                return false
            end
        end
    else
        if not sim.canScaleObjectNonIsometrically(modelHandle,scaleAxisX,scaleAxisY,scaleAxisZ) then
            return false
        end
    end
    -- Ok, we can scale the base, now check the descendents:
    local baseFrameScalingFactors={scaleAxisX,scaleAxisY,scaleAxisZ}
    for i=1,#allDescendents,1 do
        local h=allDescendents[i]
        t=sim.getObjectType(h)
        if ( (t~=sim.object_pointcloud_type) and (t~=sim.object_pointcloud_type) and (t~=sim.object_pointcloud_type) ) or (not ignoreNonScalableItems) then
            local m=sim.getObjectMatrix(h,modelHandle)
            local axesMapping={-1,-1,-1} -- -1=no mapping
            local matchingAxesCnt=0
            local objFrameScalingFactors={nil,nil,nil}
            local singleMatchingAxisIndex
            for j=1,3,1 do
                local newAxis={m[j],m[j+4],m[j+8]}
                local x={math.abs(newAxis[1]),math.abs(newAxis[2]),math.abs(newAxis[3])}
                local v=math.max(math.max(x[1],x[2]),x[3])
                if v>0.99 then
                    matchingAxesCnt=matchingAxesCnt+1
                    if x[1]>0.9 then
                        axesMapping[j]=1
                        objFrameScalingFactors[j]=baseFrameScalingFactors[axesMapping[j]]
                        singleMatchingAxisIndex=j
                    end
                    if x[2]>0.9 then
                        axesMapping[j]=2
                        objFrameScalingFactors[j]=baseFrameScalingFactors[axesMapping[j]]
                        singleMatchingAxisIndex=j
                    end
                    if x[3]>0.9 then
                        axesMapping[j]=3
                        objFrameScalingFactors[j]=baseFrameScalingFactors[axesMapping[j]]
                        singleMatchingAxisIndex=j
                    end
                end
            end
            if matchingAxesCnt==0 then
                -- the child frame is not aligned at all with the model frame. And scaling is not iso-scaling
                -- Dummies, cameras, lights and force sensors do not mind:
                local t=sim.getObjectType(h)
                if (t~=sim.object_dummy_type) and (t~=sim.object_camera_type) and (t~=sim.object_light_type) and (t~=sim.object_forcesensor_type) then
                    return false
                end
            else
                if matchingAxesCnt==3 then
                    if not sim.canScaleObjectNonIsometrically(h,objFrameScalingFactors[1],objFrameScalingFactors[2],objFrameScalingFactors[3]) then
                        return false
                    end
                else
                    -- We have only one axis that matches. We can scale the object only if the two non-matching axes have the same scaling factor:
                    local otherFactors={nil,nil}
                    for j=1,3,1 do
                        if j~=axesMapping[singleMatchingAxisIndex] then
                            if otherFactors[1] then
                                otherFactors[2]=baseFrameScalingFactors[j]
                            else
                                otherFactors[1]=baseFrameScalingFactors[j]
                            end
                        end
                    end
                    if (math.abs(1-math.abs(otherFactors[1]/otherFactors[2]))<0.001) then
                        local fff={otherFactors[1],otherFactors[1],otherFactors[1]}
                        fff[singleMatchingAxisIndex]=objFrameScalingFactors[singleMatchingAxisIndex]
                        if not sim.canScaleObjectNonIsometrically(h,fff[1],fff[2],fff[3]) then
                            return false
                        end
                    else
                        return false
                    end
                end
            end
        end
    end
    return true
end

function sim.scaleModelNonIsometrically(modelHandle,scaleAxisX,scaleAxisY,scaleAxisZ)
    local xIsY=(math.abs(1-math.abs(scaleAxisX/scaleAxisY))<0.001)
    local xIsZ=(math.abs(1-math.abs(scaleAxisX/scaleAxisZ))<0.001)
    local xIsYIsZ=(xIsY and xIsZ)
    if xIsYIsZ then
        sim.scaleObjects({modelHandle},scaleAxisX,false) -- iso scaling in this case
    else
        local avgScaling=(scaleAxisX+scaleAxisY+scaleAxisZ)/3
        local allDescendents=sim.getObjectsInTree(modelHandle,sim.handle_all,1)
        -- First the model base:
        sim.scaleObject(modelHandle,scaleAxisX,scaleAxisY,scaleAxisZ,0)
        -- Now scale all the descendents:
        local baseFrameScalingFactors={scaleAxisX,scaleAxisY,scaleAxisZ}
        for i=1,#allDescendents,1 do
            local h=allDescendents[i]
            -- First scale the object itself:
            local m=sim.getObjectMatrix(h,modelHandle)
            local axesMapping={-1,-1,-1} -- -1=no mapping
            local matchingAxesCnt=0
            local objFrameScalingFactors={nil,nil,nil}
            for j=1,3,1 do
                local newAxis={m[j],m[j+4],m[j+8]}
                local x={math.abs(newAxis[1]),math.abs(newAxis[2]),math.abs(newAxis[3])}
                local v=math.max(math.max(x[1],x[2]),x[3])
                if v>0.99 then
                    matchingAxesCnt=matchingAxesCnt+1
                    if x[1]>0.9 then
                        axesMapping[j]=1
                        objFrameScalingFactors[j]=baseFrameScalingFactors[axesMapping[j]]
                    end
                    if x[2]>0.9 then
                        axesMapping[j]=2
                        objFrameScalingFactors[j]=baseFrameScalingFactors[axesMapping[j]]
                    end
                    if x[3]>0.9 then
                        axesMapping[j]=3
                        objFrameScalingFactors[j]=baseFrameScalingFactors[axesMapping[j]]
                    end
                end
            end
            if matchingAxesCnt==0 then
                -- the child frame is not aligned at all with the model frame.
                sim.scaleObject(h,avgScaling,avgScaling,avgScaling,0)
            end

            if matchingAxesCnt==3 then
                -- the child frame is orthogonally aligned with the model frame
                sim.scaleObject(h,objFrameScalingFactors[1],objFrameScalingFactors[2],objFrameScalingFactors[3],0)
            else
                -- We have only one axis that is aligned with the model frame
                local objFactor,objIndex
                for j=1,3,1 do
                    if objFrameScalingFactors[j]~=nil then
                        objFactor=objFrameScalingFactors[j]
                        objIndex=j
                        break
                    end
                end
                local otherFactors={nil,nil}
                for j=1,3,1 do
                    if baseFrameScalingFactors[j]~=objFactor then
                        if otherFactors[1]==nil then
                            otherFactors[1]=baseFrameScalingFactors[j]
                        else
                            otherFactors[2]=baseFrameScalingFactors[j]
                        end
                    end
                end
                if (math.abs(1-math.abs(otherFactors[1]/otherFactors[2]))<0.001) then
                    local fff={otherFactors[1],otherFactors[1],otherFactors[1]}
                    fff[objIndex]=objFactor
                    sim.scaleObject(h,fff[1],fff[2],fff[3],0)
                else
                    local of=(otherFactors[1]+otherFactors[2])/2
                    local fff={of,of,of}
                    fff[objIndex]=objFactor
                    sim.scaleObject(h,fff[1],fff[2],fff[3],0)
                end
            end
            -- Now scale also the position of that object:
            local parentObjH=sim.getObjectParent(h)
            local m=sim.getObjectMatrix(parentObjH,modelHandle)
            m[4]=0
            m[8]=0
            m[12]=0
            local mi={}
            for j=1,12,1 do
                mi[j]=m[j]
            end
            sim.invertMatrix(mi)
            local p=sim.getObjectPosition(h,parentObjH)
            p=sim.multiplyVector(m,p)
            p[1]=p[1]*scaleAxisX
            p[2]=p[2]*scaleAxisY
            p[3]=p[3]*scaleAxisZ
            p=sim.multiplyVector(mi,p)
            sim.setObjectPosition(h,parentObjH,p)
        end
    end
end

function sim.UI_populateCombobox(ui,id,items_array,exceptItems_map,currentItem,sort,additionalItemsToTop_array)
    local _itemsTxt={}
    local _itemsMap={}
    for i=1,#items_array,1 do
        local txt=items_array[i][1]
        if (not exceptItems_map) or (not exceptItems_map[txt]) then
            _itemsTxt[#_itemsTxt+1]=txt
            _itemsMap[txt]=items_array[i][2]
        end
    end
    if sort then
        table.sort(_itemsTxt)
    end
    local tableToReturn={}
    if additionalItemsToTop_array then
        for i=1,#additionalItemsToTop_array,1 do
            tableToReturn[#tableToReturn+1]={additionalItemsToTop_array[i][1],additionalItemsToTop_array[i][2]}
        end
    end
    for i=1,#_itemsTxt,1 do
        tableToReturn[#tableToReturn+1]={_itemsTxt[i],_itemsMap[_itemsTxt[i]]}
    end
    if additionalItemsToTop_array then
        for i=1,#additionalItemsToTop_array,1 do
            table.insert(_itemsTxt,i,additionalItemsToTop_array[i][1])
        end
    end
    local index=0
    for i=1,#_itemsTxt,1 do
        if _itemsTxt[i]==currentItem then
            index=i-1
            break
        end
    end
    simUI.setComboboxItems(ui,id,_itemsTxt,index,true)
    return tableToReturn,index
end

function sim.displayDialog(...)
    local title,mainTxt,style,modal,initTxt,d1,d2,d3=checkargs({{type='string'},{type='string'},{type='int'},{type='bool'},{type='string',default='',nullable=true},{type='any',default=NIL,nillable=true},{type='any',default=NIL,nillable=true},{type='any',default=NIL,nillable=true}},...)
    
    if sim.getBoolParam(sim.boolparam_headless) then
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
    if not _S.dlg.allDlgResults then
        _S.dlg.allDlgResults={}
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
    _S.dlg.openDlgs[retVal]=ui
    _S.dlg.openDlgsUi[ui]=retVal
    _S.dlg.allDlgResults[retVal]={state=sim.dlgret_still_open,input=initTxt,style=style}
    
    if modal then
        while _S.dlg.allDlgResults[retVal]==sim.dlgret_still_open do
            sim.switchThread()
        end
    end
    return retVal
end

function sim.endDialog(...)
    local dlgHandle=checkargs({{type='int'}},...)

    if not sim.getBoolParam(sim.boolparam_headless) then
        if _S.dlg.allDlgResults[dlgHandle].state==sim.dlgret_still_open then
            _S.dlg.removeUi(dlgHandle)
        end
    end
end

function sim.getDialogInput(...)
    local dlgHandle=checkargs({{type='int'}},...)
    local retVal=''
    if not sim.getBoolParam(sim.boolparam_headless) then
        if _S.dlg.allDlgResults[dlgHandle] then
            retVal=_S.dlg.allDlgResults[dlgHandle].input
        end
    end
    return retVal
end

function sim.getDialogResult(...)
    local dlgHandle=checkargs({{type='int'}},...)
    local retVal=-1
    if not sim.getBoolParam(sim.boolparam_headless) then
        if _S.dlg.allDlgResults[dlgHandle] then
            retVal=_S.dlg.allDlgResults[dlgHandle].state
        end
    end
    return retVal
end

