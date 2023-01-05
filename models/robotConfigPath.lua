local robotConfigPath={}

function robotConfigPath.create(pathMtx,parent)
    local pathDummy=sim.createDummy(0.05)
    sim.setObjectAlias(pathDummy,'Path')
    sim.setModelProperty(pathDummy,0)
    sim.setObjectParent(pathDummy,parent)
    sim.setObjectInt32Param(pathDummy,sim.objintparam_visibility_layer,0)
    sim.setObjectInt32Param(pathDummy,sim.objintparam_manipulation_permissions,0)
    sim.setObjectProperty(pathDummy,sim.objectproperty_collapsed)
    sim.setObjectPose(pathDummy,sim.handle_parent,{0,0,0,0,0,0,1})
    local s=sim.addScript(sim.scripttype_customizationscript)
    sim.setScriptStringParam(s,sim.scriptstringparam_text,
[[require'models.robotConfigPath_customization']])
    sim.associateScriptWithObject(s,pathDummy)
    sim.writeCustomTableData(pathDummy,'path',pathMtx:totable())
    local stateDummy=sim.createDummy(0.01)
    sim.setObjectAlias(stateDummy,'State')
    sim.setObjectParent(stateDummy,pathDummy,false)
    sim.setObjectPose(stateDummy,pathDummy,{0,0,0,0,0,0,1})
    sim.setObjectInt32Param(stateDummy,sim.objintparam_visibility_layer,0)
    sim.setObjectInt32Param(stateDummy,sim.objintparam_manipulation_permissions,0)
    sim.setObjectProperty(stateDummy,sim.objectproperty_collapsed)
    local s=sim.addScript(sim.scripttype_customizationscript)
    sim.setScriptStringParam(s,sim.scriptstringparam_text,
[[require'models.robotConfig_customization'
model=sim.getObject'::'
color={1,1,0}
ik=false
]])
    sim.associateScriptWithObject(s,stateDummy)
end

return robotConfigPath
