sim = require 'sim'

local robotConfigPath = {}

function robotConfigPath.create(pathMtx, parent, jointGroup)
    local pathScript = sim.createScript(sim.scripttype_customization, [[require 'models.robotConfigPath_customization']])
    sim.setObjectAlias(pathScript, 'Path')
    sim.setModelProperty(pathScript, 0)
    sim.setObjectParent(pathScript, parent)
    sim.setObjectInt32Param(pathScript, sim.objintparam_visibility_layer, 0)
    sim.setObjectInt32Param(pathScript, sim.objintparam_manipulation_permissions, 0)
    sim.setObjectProperty(pathScript, sim.objectproperty_collapsed)
    sim.setObjectPose(pathScript, {0, 0, 0, 0, 0, 0, 1}, sim.handle_parent)
    sim.writeCustomTableData(pathScript, 'path', pathMtx:totable())
    sim.setReferencedHandles(pathScript, {jointGroup}, 'jointGroup')
    local stateScript = sim.createScript(sim.scripttype_customization, [[require 'models.robotConfig_customization-3'
model = sim.getObject '::'
color = {1, 1, 0}
ik = false
]])
    sim.setObjectAlias(stateScript, 'State')
    sim.setObjectParent(stateScript, pathScript, false)
    sim.setObjectPose(stateScript, {0, 0, 0, 0, 0, 0, 1}, pathScript)
    sim.setObjectInt32Param(stateScript, sim.objintparam_visibility_layer, 0)
    sim.setObjectInt32Param(stateScript, sim.objintparam_manipulation_permissions, 0)
    sim.setObjectProperty(stateScript, sim.objectproperty_collapsed)
    sim.setReferencedHandles(stateScript, {jointGroup}, 'jointGroup')
end

return robotConfigPath
