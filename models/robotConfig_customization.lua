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
    removeModelClone()
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

function removeModelClone()
    saveConfig()
    saveIkTarget()
    sim.removeReferencedObjects(self)
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
    local clonedObjects = sim.copyPasteObjects(objects, 16 + 32)
    clonedModel = clonedObjects[1]
    sim.setReferencedHandles(self, clonedObjects)
    local scriptsToInit = {}
    for _, handle in ipairs(clonedObjects) do
        local parent = sim.getObjectParent(handle)
        local alias = sim.getObjectAlias(handle)
        local scriptHandle = sim.getScript(sim.scripttype_customization, handle)
        if scriptHandle ~= -1 then
            if parent == clonedModel and alias == 'IK' then
                table.insert(scriptsToInit, scriptHandle)
            else
                local _a = sim.readCustomStringData(handle, '__jointGroup__')
                if parent == clonedModel and _a and #_a > 0 then
                    table.insert(scriptsToInit, scriptHandle)
                else
                    sim.removeScript(scriptHandle)
                end
            end
        end
        if sim.getObjectType(handle) == sim.sceneobject_shape then
            sim.setObjectProperty(handle, sim.objectproperty_selectinvisible)
            sim.setObjectInt32Param(handle, sim.shapeintparam_respondable, 0)
            sim.setObjectInt32Param(handle, sim.shapeintparam_static, 1)
            sim.setObjectInt32Param(handle, sim.shapeintparam_culling, 1)
            sim.setShapeColor(handle, nil, sim.colorcomponent_ambient_diffuse, color)
            sim.setShapeColor(handle, nil, sim.colorcomponent_transparency, {transparency})
        end
    end
    sim.setObjectParent(clonedModel, self, true)
    sim.setModelProperty(
        clonedModel, sim.getModelProperty(clonedModel) & ~sim.modelproperty_not_model
    )
    sim.setObjectProperty(self, sim.objectproperty_collapsed)
    for _, scriptHandle in ipairs(scriptsToInit) do sim.initScript(scriptHandle) end
    restoreConfig()
    restoreIkTarget()
    local ikObj = ObjectProxy('./IK', clonedModel)
    if ikObj then
        local target = ikObj:getTarget()
        sim.setObjectSelection {target}
    end
end

function getConfig()
    if clonedModel then
        local jointGroup = ObjectProxy(jointGroupPath, clonedModel)
        return jointGroup:getConfig()
    else
        return sim.readCustomTableData(self, 'config')
    end
end

function setConfig(cfg)
    if clonedModel then
        local jointGroup = ObjectProxy(jointGroupPath, clonedModel)
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
