function sysCall_init()
    if sim.isPluginLoaded('IGL') then
        local sel=sim.getObjectSelection()
        if #sel~=2 or sim.getObjectType(sel[1])~=sim.object_shape_type or sim.getObjectType(sel[2])~=sim.object_shape_type then
            simUI.msgBox(simUI.msgbox_type.critical,simUI.msgbox_buttons.ok,'Mesh boolean add-on','This tool requires exactly two shapes to be selected.')
        else
            local m=simIGL.meshBoolean(simIGL.getMesh(sel[1]),simIGL.getMesh(sel[2]),op())
            local h=sim.createMeshShape(3,math.pi/8,m.vertices,m.indices)
        end
    else
        simUI.msgBox(simUI.msgbox_type.critical,simUI.msgbox_buttons.ok,'Mesh boolean add-on','This tool requires the IGL plugin.')
    end
    return {cmd='cleanup'}
end
