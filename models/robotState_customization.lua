function sysCall_init()
    self=sim.getObject'.'
    model=model or sim.getObject':'
    color=color or {1,0,0}
    transparency=transparency or 0.5
    ik=ik==nil and true or ik
    removeModelClone()
end

function sysCall_cleanup()
    removeModelClone()
end

function sysCall_userConfig()
    if clonedModel then
        removeModelClone()
    else
        createModelClone()
    end
end

function visitTree(handle,visitor)
    if not visitor(handle) then return end
    local i=0
    while true do
        local childHandle=sim.getObjectChild(handle,i)
        if childHandle==-1 then return end
        visitTree(childHandle,visitor)
        i=i+1
    end
end

function removeModelClone()
    saveConfig()
    saveIkTarget()
    sim.removeReferencedObjects(self)
    clonedModel=nil
end

function createModelClone()
    if clonedModel then
        removeModelClone()
    end
    local objects={}
    visitTree(model,function(handle)
        local parent=sim.getObjectParent(handle)
        local alias=sim.getObjectAlias(handle)
        if parent==model and alias=='JointGroup' then return end
        if parent==model and alias=='MotionPlanning' then return end
        if parent==model and alias=='Path' then return end
        if parent==model and not ik and alias=='IK' then return end
        table.insert(objects,handle)
        return true
    end)
    local clonedObjects=sim.copyPasteObjects(objects,4+8+16+32)
    clonedModel=clonedObjects[1]
    sim.setReferencedHandles(self,clonedObjects)
    for _,handle in ipairs(clonedObjects) do
        local parent=sim.getObjectParent(handle)
        local alias=sim.getObjectAlias(handle)
        for _,scriptType in ipairs{sim.scripttype_childscript,sim.scripttype_customizationscript} do
            local scriptHandle=sim.getScript(scriptType,handle)
            if not (parent==clonedModel and alias=='IK') and scriptHandle~=-1 then
                sim.removeScript(scriptHandle)
            end
        end
        if sim.getObjectType(handle)==sim.object_shape_type then
            sim.setObjectProperty(handle,sim.objectproperty_selectinvisible)
            sim.setObjectInt32Param(handle,sim.shapeintparam_respondable,0)
            sim.setObjectInt32Param(handle,sim.shapeintparam_static,1)
            sim.setObjectInt32Param(handle,sim.shapeintparam_culling,1)
            sim.setShapeColor(handle,nil,sim.colorcomponent_ambient_diffuse,color)
            sim.setShapeColor(handle,nil,sim.colorcomponent_transparency,{transparency})
        end
    end
    sim.setObjectParent(clonedModel,self,true)
    sim.setModelProperty(clonedModel,sim.getModelProperty(clonedModel)&~sim.modelproperty_not_model)
    sim.setObjectProperty(self,sim.objectproperty_collapsed)
    restoreConfig()
    restoreIkTarget()
    local target=sim.getObject('./target',{proxy=clonedModel,noError=true})
    if target==-1 then return end
    sim.setObjectSelection{target}
end

function getConfig()
    if clonedModel then
        local cfg={}
        visitTree(clonedModel,function(handle)
            if sim.getObjectType(handle)==sim.object_joint_type then
                table.insert(cfg,sim.getJointPosition(handle))
            end
            return true
        end)
        return cfg
    else
        return sim.readCustomTableData(self,'config')
    end
end

function saveConfig()
    if clonedModel then
        local cfg={}
        visitTree(clonedModel,function(handle)
            if sim.getObjectType(handle)==sim.object_joint_type then
                table.insert(cfg,sim.getJointPosition(handle))
            end
            return true
        end)
        sim.writeCustomTableData(self,'config',cfg)
    end
end

function restoreConfig()
    if clonedModel then
        local cfg=sim.readCustomTableData(self,'config')
        if #cfg==0 then return end
        local i=1
        visitTree(clonedModel,function(handle)
            if sim.getObjectType(handle)==sim.object_joint_type then
                sim.setJointPosition(handle,cfg[i])
                i=i+1
            end
            return true
        end)
    end
end

function saveIkTarget()
    if clonedModel then
        local target=sim.getObject('./target',{proxy=clonedModel,noError=true})
        if target==-1 then return end
        local pose=sim.getObjectPose(target,clonedModel)
        sim.writeCustomTableData(self,'ikTargetPose',pose)
    end
end

function restoreIkTarget(pose)
    if clonedModel then
        local target=sim.getObject('./target',{proxy=clonedModel,noError=true})
        if target==-1 then return end
        local pose=sim.readCustomTableData(self,'ikTargetPose')
        if #pose==0 then return end
        sim.setObjectPose(target,clonedModel,pose)
    end
end

function reset()
    sim.writeCustomDataBlock(self,'config','')
    sim.writeCustomDataBlock(self,'ikTargetPose','')
end
