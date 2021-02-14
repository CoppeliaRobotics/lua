path=require('path_customization')

_S.conveyorSystem={}

function _S.conveyorSystem.init(config)
    _S.conveyorSystem.config=config
    _S.conveyorSystem.model=sim.getObjectHandle(sim.handle_self)
    
    _S.conveyorSystem.velocity=_S.conveyorSystem.config.initVel
    _S.conveyorSystem.offset=_S.conveyorSystem.config.initPos
    sim.writeCustomDataBlock(_S.conveyorSystem.model,'PATHMOV',sim.packTable({currentPos=_S.conveyorSystem.offset}))
    
    path.init()

    local inf=path.readInfo()
    inf.ctrlPtFixedSize=true
    path.writeInfo(inf)
end

function sysCall_afterSimulation()
    _S.conveyorSystem.velocity=_S.conveyorSystem.config.initVel
    _S.conveyorSystem.offset=_S.conveyorSystem.config.initPos
    sim.writeCustomDataBlock(_S.conveyorSystem.model,'PATHMOV',sim.packTable({currentPos=_S.conveyorSystem.offset}))
    
    path.afterSimulation()
end

function sysCall_actuation()
    local dat=sim.readCustomDataBlock(_S.conveyorSystem.model,'PATHMOV')
    local off
    if dat then
        dat=sim.unpackTable(dat)
        if dat.pos then
            off=dat.pos
        end
        if dat.vel then
            _S.conveyorSystem.velocity=dat.vel
        end
    end
    if off or _S.conveyorSystem.velocity~=0 then
        if off then
            _S.conveyorSystem.offset=off
        else
            _S.conveyorSystem.offset=_S.conveyorSystem.offset+_S.conveyorSystem.velocity*sim.getSimulationTimeStep()
        end
        _S.conveyorSystem.setPathPos(_S.conveyorSystem.offset)
    end
    if not dat then
        dat={}
    end
    dat.currentPos=_S.conveyorSystem.offset
    sim.writeCustomDataBlock(_S.conveyorSystem.model,'PATHMOV',sim.packTable(dat))
end

function path.refreshTrigger(ctrlPts,pathData,config)
    local m=Matrix(math.floor(#pathData/7),7,pathData)
    _S.conveyorSystem.pathPositions=m:slice(1,1,m:rows(),3):data()
    _S.conveyorSystem.pathQuaternions=m:slice(1,4,m:rows(),7):data()
    _S.conveyorSystem.pathLengths,_S.conveyorSystem.totalLength=sim.getPathLengths(_S.conveyorSystem.pathPositions,3)
    local padCnt
    if (config.bitCoded&2)==0 then
        -- open
        padCnt=1+_S.conveyorSystem.totalLength//(_S.conveyorSystem.config.padSize[1]+_S.conveyorSystem.config.interPadSpace)
        _S.conveyorSystem.padOffset=_S.conveyorSystem.config.padSize[1]+_S.conveyorSystem.config.interPadSpace
        _S.conveyorSystem.totalL=_S.conveyorSystem.padOffset*padCnt
    else
        -- closed
        padCnt=_S.conveyorSystem.totalLength//(_S.conveyorSystem.config.padSize[1]+_S.conveyorSystem.config.interPadSpace)
        _S.conveyorSystem.padOffset=_S.conveyorSystem.totalLength/padCnt
        _S.conveyorSystem.totalL=_S.conveyorSystem.totalLength
    end
    

    local shapes=sim.getObjectsInTree(_S.conveyorSystem.model,sim.object_shape_type,1+2)
    local oldPads={}
    for i=1,#shapes,1 do
        local dat=sim.readCustomDataBlock(shapes[i],'PATHPAD')
        if dat then
            oldPads[#oldPads+1]=shapes[i]
        end
    end
    
    _S.conveyorSystem.padHandles={}
    if padCnt==#oldPads and sim.packTable(_S.conveyorSystem.config)==sim.readCustomDataBlock(_S.conveyorSystem.model,'CONVEYORSET') then
        _S.conveyorSystem.padHandles=oldPads -- reuse old pads, they are the same
    else
        sim.writeCustomDataBlock(_S.conveyorSystem.model,'CONVEYORSET',sim.packTable(_S.conveyorSystem.config))
        for i=1,#oldPads,1 do
            sim.removeObject(oldPads[i])
        end
        for i=1,padCnt,1 do
            local opt=16
            if _S.conveyorSystem.config.respondablePads then
                opt=opt+8
            end
            _S.conveyorSystem.padHandles[i]=sim.createPureShape(0,opt,_S.conveyorSystem.config.padSize,0.01)
            path.setObjectName(_S.conveyorSystem.padHandles[i],"pad")
            sim.setShapeColor(_S.conveyorSystem.padHandles[i],nil,sim.colorcomponent_ambient_diffuse,_S.conveyorSystem.config.padCol)
            sim.setObjectParent(_S.conveyorSystem.padHandles[i],_S.conveyorSystem.model,true)
            sim.writeCustomDataBlock(_S.conveyorSystem.padHandles[i],'PATHPAD','a')
            sim.setObjectProperty(_S.conveyorSystem.padHandles[i],sim.objectproperty_selectmodelbaseinstead)
        end
    end
    _S.conveyorSystem.setPathPos(_S.conveyorSystem.offset)
end

function path.shaping(path,pathIsClosed,upVector)
    local section={-_S.conveyorSystem.config.padSize[2]/2,-_S.conveyorSystem.config.padSize[2]/2-_S.conveyorSystem.config.padSize[3],-_S.conveyorSystem.config.padSize[2]/2,-_S.conveyorSystem.config.padSize[3],_S.conveyorSystem.config.padSize[2]/2,-_S.conveyorSystem.config.padSize[3],_S.conveyorSystem.config.padSize[2]/2,-_S.conveyorSystem.config.padSize[2]/2-_S.conveyorSystem.config.padSize[3],-_S.conveyorSystem.config.padSize[2]/2,-_S.conveyorSystem.config.padSize[2]/2-_S.conveyorSystem.config.padSize[3]}
    local options=0
    if pathIsClosed then
        options=options|4
    end
    local shape=sim.generateShapeFromPath(path,section,options,upVector)
    sim.setShapeColor(shape,nil,sim.colorcomponent_ambient_diffuse,_S.conveyorSystem.config.col)
    return shape
end

function _S.conveyorSystem.setPathPos(p)
    for i=1,#_S.conveyorSystem.padHandles,1 do
        p=p % _S.conveyorSystem.totalL
        local o=p
        if o>_S.conveyorSystem.totalLength then
            o=o-_S.conveyorSystem.padOffset
        end
        local h=_S.conveyorSystem.padHandles[i]
        local pos=sim.getPathInterpolatedConfig(_S.conveyorSystem.pathPositions,_S.conveyorSystem.pathLengths,o)
        pos[3]=pos[3]-_S.conveyorSystem.config.padSize[3]/2
        local quat=sim.getPathInterpolatedConfig(_S.conveyorSystem.pathQuaternions,_S.conveyorSystem.pathLengths,o,nil,{2,2,2,2})
        sim.setObjectPosition(h,_S.conveyorSystem.model,pos)
        sim.setObjectQuaternion(h,_S.conveyorSystem.model,quat)
        p=p+_S.conveyorSystem.padOffset
    end
end

return _S.conveyorSystem