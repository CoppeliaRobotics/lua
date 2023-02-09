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

    local result=compute(sel[1],sel[2])
    if #sel>2 then
        local toRemove={}
        for i=3,#sel do
            table.insert(toRemove,result)
            result=compute(result,sel[i])
        end
        sim.removeObjects(toRemove)
    end
    sim.reorientShapeBoundingBox(result,sim.handle_world)

    return {cmd='cleanup'}
end

function blendColor(a,b)
    return (0.5*(Vector(a)+Vector(b))):data()
end

function compute(a,b)
    local m=simIGL.meshBoolean(simIGL.getMesh(a),simIGL.getMesh(b),op())
    local edgesA=sim.getObjectInt32Param(a,sim.shapeintparam_edge_visibility)
    local edgesB=sim.getObjectInt32Param(b,sim.shapeintparam_edge_visibility)
    local h=sim.createMeshShape(1+2*edgesA*edgesB,math.pi/8,m.vertices,m.indices)
    local _,coladA=sim.getShapeColor(a,'',sim.colorcomponent_ambient_diffuse)
    local _,coladB=sim.getShapeColor(b,'',sim.colorcomponent_ambient_diffuse)
    sim.setShapeColor(h,'',sim.colorcomponent_ambient_diffuse,blendColor(coladA,coladB))
    local _,colspA=sim.getShapeColor(a,'',sim.colorcomponent_specular)
    local _,colspB=sim.getShapeColor(b,'',sim.colorcomponent_specular)
    sim.setShapeColor(h,'',sim.colorcomponent_specular,blendColor(colspA,colspB))
    local _,colemA=sim.getShapeColor(a,'',sim.colorcomponent_emission)
    local _,colemB=sim.getShapeColor(b,'',sim.colorcomponent_emission)
    sim.setShapeColor(h,'',sim.colorcomponent_emission,blendColor(colemA,colemB))
    return h
end
