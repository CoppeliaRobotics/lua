sim = require 'sim'

function sysCall_init()
    self = sim.getObject '.'
    model = model or sim.getObject ':'
    color = color or {1, 0, 0}
    transparency = transparency or 0.5
    ik = ik == nil and true or ik
    removeModelClone()
    if create then createModelClone() end
end

function sysCall_cleanup()
    removeModelClone(true)
end

function sysCall_userConfig()
    if clonedModel then
        removeModelClone()
    else
        createModelClone()
    end
end

function hasModelClone()
    return not not clonedModel
end

function removeModelClone(delayedRemoval)
    saveConfig()
    saveIkTarget()
    sim.removeReferencedObjects(self, nil, delayedRemoval)
    clonedModel = nil
end

function createModelClone()
    if clonedModel then removeModelClone() end
    local objects = {}
    sim.visitTree(
        model, function(handle)
            local parent = sim.getObjectParent(handle)
            local alias = sim.getObjectAlias(handle)
            if parent == model and alias == 'MotionPlanning' then return false end
            if parent == model and alias == 'Path' then return false end
            if parent == model and not ik and alias == 'IK' then return false end
            table.insert(objects, handle)
        end
    )
    -- XXX: to be able to find the jointGroup in the cloned model later, (i.e. in
    --      functions getConfig() / setConfig() below), we set a relation from
    --      model to jointGroup
    local jointGroup = sim.getReferencedHandle(self, 'jointGroup')
    sim.setReferencedHandles(model, {jointGroup}, 'jointGroup')
    local clonedObjects = sim.copyPasteObjects(objects, 16 + 32)
    clonedModel = clonedObjects[1]
    sim.setReferencedHandles(self, clonedObjects)
    local scriptsToInit = {}
    for _, handle in ipairs(clonedObjects) do
        local parent = sim.getObjectParent(handle)
        local alias = sim.getObjectAlias(handle)
        if sim.getObjectType(handle) == sim.sceneobject_script then
            if parent == clonedModel and alias == 'IK' then
                table.insert(scriptsToInit, handle)
            else
                local _a = sim.readCustomStringData(handle, '__jointGroup__')
                if parent == clonedModel and _a and #_a > 0 then
                    table.insert(scriptsToInit, handle)
                else
                    sim.removeObjects{handle}
                end
            end
        elseif sim.getObjectType(handle) == sim.sceneobject_shape then
            sim.setObjectProperty(handle, sim.objectproperty_selectinvisible)
            sim.setObjectInt32Param(handle, sim.shapeintparam_culling, 1)
            sim.setShapeColor(handle, nil, sim.colorcomponent_ambient_diffuse, color)
            sim.setShapeColor(handle, nil, sim.colorcomponent_transparency, {transparency})
        end
    end
    sim.setObjectParent(clonedModel, self, true)
    sim.setModelProperty(clonedModel, sim.getModelProperty(clonedModel)
        & ~sim.modelproperty_not_model
        | sim.modelproperty_not_collidable
        | sim.modelproperty_not_measurable
        | sim.modelproperty_not_detectable
        | sim.modelproperty_not_dynamic
        | sim.modelproperty_not_respondable
    )
    sim.setObjectProperty(self, sim.objectproperty_collapsed)
    for _, scriptHandle in ipairs(scriptsToInit) do sim.initScript(scriptHandle) end
    restoreConfig()
    restoreIkTarget()
    local ikObj = ObjectProxy('./IK', clonedModel)
    if ikObj then
        local target = ikObj:getTarget()
        sim.setObjectSel {target}
    end
end

function getConfig()
    if clonedModel then
        local jointGroup = sim.getReferencedHandle(clonedModel, 'jointGroup')
        jointGroup = sim.getScriptFunctions(jointGroup)
        return jointGroup:getConfig()
    else
        return sim.readCustomTableData(self, 'config')
    end
end

function setConfig(cfg)
    if clonedModel then
        local jointGroup = sim.getReferencedHandle(clonedModel, 'jointGroup')
        jointGroup = sim.getScriptFunctions(jointGroup)
        return jointGroup:setConfig(cfg)
    end
end

function saveConfig()
    if clonedModel then sim.writeCustomTableData(self, 'config', getConfig()) end
end

function restoreConfig()
    if clonedModel then
        local cfg = sim.readCustomTableData(self, 'config')
        if #cfg == 0 then return end
        setConfig(cfg)
    end
end

function saveIkTarget()
    if clonedModel then
        local ikObj = ObjectProxy('./IK', clonedModel)
        if ikObj then
            local target = ikObj:getTarget()
            local pose = sim.getObjectPose(target, clonedModel)
            sim.writeCustomTableData(self, 'ikTargetPose', pose)
        end
    end
end

function restoreIkTarget(pose)
    if clonedModel then
        local ikObj = ObjectProxy('./IK', clonedModel)
        if ikObj then
            local target = ikObj:getTarget()
            local pose = sim.readCustomTableData(self, 'ikTargetPose')
            if #pose == 0 then return end
            sim.setObjectPose(target, pose, clonedModel)
        end
    end
end

function reset()
    sim.writeCustomBufferData(self, 'config', '')
    sim.writeCustomBufferData(self, 'ikTargetPose', '')
end

function ObjectProxy(path, proxy, t)
    t = t or sim.scripttype_customization
    local o = sim.getObject(path, {proxy = proxy, noError = true})
    if o ~= -1 then return sim.getScriptFunctions(sim.getScript(t, o)) end
end
