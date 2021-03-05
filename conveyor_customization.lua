path=require('path_customization')

_S.conveyor={}

function sysCall_actuation()
    _S.conveyor.actuation()
end

function sysCall_afterSimulation()
    _S.conveyor.afterSimulation()
end

function _S.conveyor.init(config)
    _S.conveyor.config=config
    _S.conveyor.model=sim.getObjectHandle(sim.handle_self)
    
    _S.conveyor.velocity=_S.conveyor.config.initVel
    _S.conveyor.offset=_S.conveyor.config.initPos
    sim.writeCustomDataBlock(_S.conveyor.model,'CONVMOV',sim.packTable({currentPos=_S.conveyor.offset}))
    
    local ctrlPts=path.init()
    for i=1,9,1 do
        local a=math.pi/2-(i-1)*math.pi/8
        sim.setObjectPosition(ctrlPts[i],_S.conveyor.model,{_S.conveyor.config.radius*math.cos(a)+_S.conveyor.config.length/2,0,_S.conveyor.config.radius*math.sin(a)})
        sim.setObjectPosition(ctrlPts[9+i],_S.conveyor.model,{-_S.conveyor.config.radius*math.cos(a)-_S.conveyor.config.length/2,0,_S.conveyor.config.radius*math.sin(-a)})
    end
    local ctrlPts,pathData=path.setup()    
    local m=Matrix(math.floor(#pathData/7),7,pathData)
    _S.conveyor.pathPositions=m:slice(1,1,m:rows(),3):data()
    _S.conveyor.pathQuaternions=m:slice(1,4,m:rows(),7):data()
    _S.conveyor.pathLengths,_S.conveyor.totalLength=sim.getPathLengths(_S.conveyor.pathPositions,3)
    -- shift positions towards the outside, by the half thickness of the pads:
    for i=1,m:rows(),1 do
        local rot=Matrix3x3:fromquaternion(m:slice(i,4,i,7):data())
        local zaxis=rot:slice(1,3,3,3)
        local p=m:slice(i,1,i,3):t()
        p=p+zaxis*_S.conveyor.config.padSize[3]/2
        _S.conveyor.pathPositions[3*(i-1)+1]=p[1]
        _S.conveyor.pathPositions[3*(i-1)+2]=p[2]
        _S.conveyor.pathPositions[3*(i-1)+3]=p[3]
    end
    
    local padCnt=_S.conveyor.totalLength//(_S.conveyor.config.padSize[1]+_S.conveyor.config.interPadSpace)
    _S.conveyor.padOffset=(_S.conveyor.totalLength/padCnt)

    local shapes=sim.getObjectsInTree(_S.conveyor.model,sim.object_shape_type,1+2)
    local oldPads={}
    for i=1,#shapes,1 do
        local dat=sim.readCustomDataBlock(shapes[i],'PATHPAD')
        if dat then
            oldPads[#oldPads+1]=shapes[i]
        end
    end
    
    _S.conveyor.padHandles={}
    if padCnt==#oldPads and sim.packTable(_S.conveyor.config)==sim.readCustomDataBlock(_S.conveyor.model,'CONVEYORSET') then
        _S.conveyor.padHandles=oldPads -- reuse old pads, they are the same
    else
        sim.writeCustomDataBlock(_S.conveyor.model,'CONVEYORSET',sim.packTable(_S.conveyor.config))
        for i=1,#oldPads,1 do
            sim.removeObject(oldPads[i])
        end
        for i=1,padCnt,1 do
            local opt=16
            if _S.conveyor.config.respondablePads then
                opt=opt+8
            end
            _S.conveyor.padHandles[i]=sim.createPureShape(0,opt,_S.conveyor.config.padSize,0.01)
            sim.setSimilarName(_S.conveyor.padHandles[i],sim.getObjectName(_S.conveyor.model),'__pad')
            sim.setShapeColor(_S.conveyor.padHandles[i],nil,sim.colorcomponent_ambient_diffuse,_S.conveyor.config.padCol)
            sim.setObjectParent(_S.conveyor.padHandles[i],_S.conveyor.model,true)
            sim.writeCustomDataBlock(_S.conveyor.padHandles[i],'PATHPAD','a')
            sim.setObjectProperty(_S.conveyor.padHandles[i],sim.objectproperty_selectmodelbaseinstead)
        end
    end
    _S.conveyor.setPathPos(_S.conveyor.offset)
end

function _S.conveyor.afterSimulation()
    _S.conveyor.velocity=_S.conveyor.config.initVel
    _S.conveyor.offset=_S.conveyor.config.initPos
    sim.writeCustomDataBlock(_S.conveyor.model,'CONVMOV',sim.packTable({currentPos=_S.conveyor.offset}))
    
    path.afterSimulation()
end

function _S.conveyor.actuation()
    local dat=sim.readCustomDataBlock(_S.conveyor.model,'CONVMOV')
    local off
    if dat then
        dat=sim.unpackTable(dat)
        if dat.offset then
            off=dat.offset
        end
        if dat.vel then
            _S.conveyor.velocity=dat.vel
        end
    end
    if off or _S.conveyor.velocity~=0 then
        if off then
            _S.conveyor.offset=off
        else
            _S.conveyor.offset=_S.conveyor.offset+_S.conveyor.velocity*sim.getSimulationTimeStep()
        end
        _S.conveyor.setPathPos(_S.conveyor.offset)
    end
    if not dat then
        dat={}
    end
    dat.currentPos=_S.conveyor.offset
    sim.writeCustomDataBlock(_S.conveyor.model,'CONVMOV',sim.packTable(dat))
end

function path.shaping(path,pathIsClosed,upVector)
    local section={0,-_S.conveyor.config.padSize[2]/2,0,_S.conveyor.config.padSize[2]/2,-3*_S.conveyor.config.radius/4,_S.conveyor.config.padSize[2]/2,-3*_S.conveyor.config.radius/4,-_S.conveyor.config.padSize[2]/2,0,-_S.conveyor.config.padSize[2]/2}
    local options=0
    if pathIsClosed then
        options=options|4
    end
    local shape=sim.generateShapeFromPath(path,section,options,upVector)
    local vert,ind=sim.getShapeMesh(shape)
    vert,ind=simQHull.compute(vert,true)
    vert=sim.multiplyVector(sim.getObjectMatrix(shape,-1),vert)
    sim.removeObject(shape)
    shape=sim.createMeshShape(0,0,vert,ind)
    sim.setShapeColor(shape,nil,sim.colorcomponent_ambient_diffuse,_S.conveyor.config.col)
    if _S.conveyor.config.respondablePads then
        sim.setObjectInt32Parameter(shape,sim.shapeintparam_respondable,1)
    end
    return shape
end

function _S.conveyor.setPathPos(p)
    for i=1,#_S.conveyor.padHandles,1 do
        p=p % _S.conveyor.totalLength
        local h=_S.conveyor.padHandles[i]
        local pos=sim.getPathInterpolatedConfig(_S.conveyor.pathPositions,_S.conveyor.pathLengths,p)
        local quat=sim.getPathInterpolatedConfig(_S.conveyor.pathQuaternions,_S.conveyor.pathLengths,p,nil,{2,2,2,2})
        sim.setObjectPosition(h,_S.conveyor.model,pos)
        sim.setObjectQuaternion(h,_S.conveyor.model,quat)
        p=p+_S.conveyor.padOffset
    end
end

return _S.conveyor