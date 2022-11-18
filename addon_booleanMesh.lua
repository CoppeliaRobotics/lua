function sysCall_init()
    if sim.isPluginLoaded('IGL') then
        local sel=sim.getObjectSelection()
        if #sel~=2 or sim.getObjectType(sel[1])~=sim.object_shape_type or sim.getObjectType(sel[2])~=sim.object_shape_type then
            sim.addLog(sim.verbosity_scripterrors,'This tool requires exactly two shapes to be selected.')
        else
            local m=simIGL.meshBoolean(getMesh(sel[1]),getMesh(sel[2]),op())
            local h=sim.createMeshShape(3,math.pi/8,m.vertices,m.indices)
        end
    else
        sim.addLog(sim.verbosity_scripterrors,'This tool requires the IGL plugin.')
    end
    return {cmd='cleanup'}
end

function getMesh(h)
    local v,i,n=sim.getShapeMesh(h)
    local m=sim.getObjectMatrix(h,-1)
    v=sim.multiplyVector(m,v)
    return {vertices=v, indices=i}
end
