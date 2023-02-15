function sysCall_init()
    if not sim.isPluginLoaded('IGL') then
        simUI.msgBox(simUI.msgbox_type.critical,simUI.msgbox_buttons.ok,'Mesh boolean add-on','This tool requires the IGL plugin.')
        return {cmd='cleanup'}
    end

    local maxSel=2
    if type(acceptsMoreThan2)=='function' and acceptsMoreThan2() then maxSel=1/0 end
    local sel=sim.getObjectSelection()
    if #sel<2 or #sel>maxSel then
        simUI.msgBox(simUI.msgbox_type.critical,simUI.msgbox_buttons.ok,'Mesh boolean add-on','This tool requires 2'..(maxSel==2 and '' or ' (or more)')..' shapes to be selected.')
        return {cmd='cleanup'}
    end

    for i,h in ipairs(sel) do
        if sim.getObjectType(h)~=sim.object_shape_type then
            simUI.msgBox(simUI.msgbox_type.critical,simUI.msgbox_buttons.ok,'Mesh boolean add-on','This tool only works with shapes.')
            return {cmd='cleanup'}
        end
    end

    local result=simIGL.meshBooleanShape(sel,op())
    sim.announceSceneContentChange()

    return {cmd='cleanup'}
end
