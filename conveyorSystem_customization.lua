-- back-compatibility version for CoppeliaSim V4.2.0

path=require('path_customization')

_S.conveyorSystem={}

function _S.conveyorSystem.init(config)
    _S.conveyorSystem.config=config
    _S.conveyorSystem.model=sim.getObject('.')
    
    _S.conveyorSystem.velocity=_S.conveyorSystem.config.initVel
    _S.conveyorSystem.offset=_S.conveyorSystem.config.initPos
    sim.writeCustomDataBlock(_S.conveyorSystem.model,'CONVMOV',sim.packTable({currentPos=_S.conveyorSystem.offset}))
    
    path.init()

    local inf=path.readInfo()
    inf.ctrlPtFixedSize=true
    path.writeInfo(inf)
end

function sysCall_afterSimulation()
    _S.conveyorSystem.velocity=_S.conveyorSystem.config.initVel
    _S.conveyorSystem.offset=_S.conveyorSystem.config.initPos
    sim.writeCustomDataBlock(_S.conveyorSystem.model,'CONVMOV',sim.packTable({currentPos=_S.conveyorSystem.offset}))
    
    path.afterSimulation()
end

function sysCall_actuation()
    local dat=sim.readCustomDataBlock(_S.conveyorSystem.model,'CONVMOV')
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
        if _S.conveyorSystem.config.useRollers then
            for i=1,#_S.conveyorSystem.rolHandles,1 do
                sim.setJointPosition(_S.conveyorSystem.rolHandles[i],2*_S.conveyorSystem.offset/_S.conveyorSystem.config.rollerSize[1])
            end
        else
            _S.conveyorSystem.setPathPos(_S.conveyorSystem.offset)
        end
    end
    if not dat then
        dat={}
    end
    dat.currentPos=_S.conveyorSystem.offset
    sim.writeCustomDataBlock(_S.conveyorSystem.model,'CONVMOV',sim.packTable(dat))
end

function path.refreshTrigger(ctrlPts,pathData,config)
    local m=Matrix(math.floor(#pathData/7),7,pathData)
    _S.conveyorSystem.pathPositions=m:slice(1,1,m:rows(),3):data()
    _S.conveyorSystem.pathQuaternions=m:slice(1,4,m:rows(),7):data()
    _S.conveyorSystem.pathLengths,_S.conveyorSystem.totalLength=sim.getPathLengths(_S.conveyorSystem.pathPositions,3)
    local padCnt=0
    local rolCnt=0
    if (config.bitCoded&2)==0 then
        -- open
        if _S.conveyorSystem.config.useRollers then
            rolCnt=1+_S.conveyorSystem.totalLength//(_S.conveyorSystem.config.rollerSize[1]+_S.conveyorSystem.config.interPadSpace)
            _S.conveyorSystem.totalL=_S.conveyorSystem.totalLength
            _S.conveyorSystem.padOffset=_S.conveyorSystem.totalLength/(rolCnt-1)
        else
            padCnt=1+_S.conveyorSystem.totalLength//(_S.conveyorSystem.config.padSize[1]+_S.conveyorSystem.config.interPadSpace)
            _S.conveyorSystem.padOffset=_S.conveyorSystem.config.padSize[1]+_S.conveyorSystem.config.interPadSpace
            _S.conveyorSystem.totalL=_S.conveyorSystem.padOffset*padCnt
        end
    else
        -- closed
        if _S.conveyorSystem.config.useRollers then
            rolCnt=_S.conveyorSystem.totalLength//(_S.conveyorSystem.config.rollerSize[1]+_S.conveyorSystem.config.interPadSpace)
            _S.conveyorSystem.padOffset=_S.conveyorSystem.totalLength/rolCnt
        else
            padCnt=_S.conveyorSystem.totalLength//(_S.conveyorSystem.config.padSize[1]+_S.conveyorSystem.config.interPadSpace)
            _S.conveyorSystem.padOffset=_S.conveyorSystem.totalLength/padCnt
            _S.conveyorSystem.totalL=_S.conveyorSystem.totalLength
        end
    end

    local shapes=sim.getObjectsInTree(_S.conveyorSystem.model,sim.object_shape_type,1+2)
    local oldPads={}
    local oldRespondable
    local oldBorder
    for i=1,#shapes,1 do
        local dat=sim.readCustomDataBlock(shapes[i],'PATHPAD')
        if dat then
            if dat=='a' then
                oldPads[#oldPads+1]=shapes[i]
            end
            if dat=='b' then
                oldRespondable=shapes[i]
            end
            if dat=='c' then
                oldBorder=shapes[i]
            end
        end
    end

    local joints=sim.getObjectsInTree(_S.conveyorSystem.model,sim.object_joint_type,1+2)
    local oldJoints={}
    for i=1,#joints,1 do
        local dat=sim.readCustomDataBlock(joints[i],'PATHROL')
        if dat then
            oldJoints[#oldJoints+1]=joints[i]
        end
    end
    
    _S.conveyorSystem.padHandles={}
    _S.conveyorSystem.rolHandles={}
    if padCnt==#oldPads and rolCnt==#oldJoints and sim.packTable(_S.conveyorSystem.config)==sim.readCustomDataBlock(_S.conveyorSystem.model,'CONVEYORSET') then
        _S.conveyorSystem.padHandles=oldPads -- reuse old pads, they are the same
        _S.conveyorSystem.rolHandles=oldJoints 
    else
        sim.writeCustomDataBlock(_S.conveyorSystem.model,'CONVEYORSET',sim.packTable(_S.conveyorSystem.config))
        for i=1,#oldPads,1 do
            sim.removeObject(oldPads[i])
        end
        if oldRespondable then
            sim.removeObject(oldRespondable)
        end
        if oldBorder then
            sim.removeObject(oldBorder)
        end
        for i=1,#oldJoints,1 do
            sim.removeObject(sim.getObjectChild(oldJoints[i],0))
            sim.removeObject(oldJoints[i])
        end
        if _S.conveyorSystem.config.useRollers then
            for i=1,rolCnt,1 do
                local opt=16
                if _S.conveyorSystem.config.respondablePads then
                    opt=opt+8
                end
                local cyl=sim.createPureShape(2,opt,{_S.conveyorSystem.config.rollerSize[1],_S.conveyorSystem.config.rollerSize[1],_S.conveyorSystem.config.rollerSize[2]*0.95},0.01)
                sim.setObjectInt32Param(cyl,sim.objintparam_visibility_layer,1+256)
                local jnt=sim.createJoint(sim.joint_revolute_subtype,sim.jointmode_passive,0)
                _S.conveyorSystem.rolHandles[i]=jnt
                sim.setObjectParent(cyl,jnt,true)
                sim.setObjectAlias(jnt,'jrol')
                sim.setObjectAlias(cyl,'rol')
                sim.setShapeColor(cyl,nil,sim.colorcomponent_ambient_diffuse,_S.conveyorSystem.config.padCol)
                sim.setObjectParent(jnt,_S.conveyorSystem.model,true)
                sim.writeCustomDataBlock(jnt,'PATHROL','a')
                sim.setObjectProperty(cyl,sim.objectproperty_selectmodelbaseinstead)
                sim.setObjectInt32Param(jnt,sim.objintparam_visibility_layer,512)
                local o=(i-1)*_S.conveyorSystem.padOffset
                local pos=sim.getPathInterpolatedConfig(_S.conveyorSystem.pathPositions,_S.conveyorSystem.pathLengths,o)
                pos[3]=pos[3]-_S.conveyorSystem.config.rollerSize[1]/2
                local quat=sim.getPathInterpolatedConfig(_S.conveyorSystem.pathQuaternions,_S.conveyorSystem.pathLengths,o,nil,{2,2,2,2})
                local m=Matrix3x3:fromquaternion(quat)
                m=m*Matrix3x3:rotx(-math.pi/2)
                sim.setObjectPosition(jnt,_S.conveyorSystem.model,pos)
                sim.setObjectQuaternion(jnt,_S.conveyorSystem.model,Matrix3x3:toquaternion(m))
            end
        else
            for i=1,padCnt,1 do
                local opt=16
                if _S.conveyorSystem.config.respondablePads then
                    opt=opt+8
                end
                _S.conveyorSystem.padHandles[i]=sim.createPureShape(0,opt,{_S.conveyorSystem.config.padSize[1],_S.conveyorSystem.config.padSize[2]*0.95,_S.conveyorSystem.config.padSize[3]},0.01)
                sim.setObjectAlias(_S.conveyorSystem.padHandles[i],'pad')
                sim.setShapeColor(_S.conveyorSystem.padHandles[i],nil,sim.colorcomponent_ambient_diffuse,_S.conveyorSystem.config.padCol)
                sim.setObjectParent(_S.conveyorSystem.padHandles[i],_S.conveyorSystem.model,true)
                sim.writeCustomDataBlock(_S.conveyorSystem.padHandles[i],'PATHPAD','a')
                sim.setObjectProperty(_S.conveyorSystem.padHandles[i],sim.objectproperty_selectmodelbaseinstead)
                sim.setObjectInt32Param(_S.conveyorSystem.padHandles[i],sim.objintparam_visibility_layer,1+256)
            end
        end
        if _S.conveyorSystem.config.respondableBase then
            local cnt=1+_S.conveyorSystem.totalLength//(_S.conveyorSystem.config.respondableBaseElementLength*0.5)
            local off=_S.conveyorSystem.config.respondableBaseElementLength*0.5
            local el={}
            local p=0
            if _S.conveyorSystem.config.useRollers then
                for i=1,cnt,1 do
                    el[i]=sim.createPureShape(0,24,{_S.conveyorSystem.config.respondableBaseElementLength,_S.conveyorSystem.config.rollerSize[2],_S.conveyorSystem.config.rollerSize[1]/2},0.01)
                    local pos=sim.getPathInterpolatedConfig(_S.conveyorSystem.pathPositions,_S.conveyorSystem.pathLengths,p)
                    pos[3]=pos[3]-3*_S.conveyorSystem.config.rollerSize[1]/4
                    local quat=sim.getPathInterpolatedConfig(_S.conveyorSystem.pathQuaternions,_S.conveyorSystem.pathLengths,p,nil,{2,2,2,2})
                    sim.setObjectPosition(el[i],_S.conveyorSystem.model,pos)
                    sim.setObjectQuaternion(el[i],_S.conveyorSystem.model,quat)
                    p=p+off
                end
            else
                for i=1,cnt,1 do
                    el[i]=sim.createPureShape(0,24,{_S.conveyorSystem.config.respondableBaseElementLength,_S.conveyorSystem.config.padSize[2],0.02},0.01)
                    local pos=sim.getPathInterpolatedConfig(_S.conveyorSystem.pathPositions,_S.conveyorSystem.pathLengths,p)
                    pos[3]=pos[3]-0.01-_S.conveyorSystem.config.padSize[3]
                    local quat=sim.getPathInterpolatedConfig(_S.conveyorSystem.pathQuaternions,_S.conveyorSystem.pathLengths,p,nil,{2,2,2,2})
                    sim.setObjectPosition(el[i],_S.conveyorSystem.model,pos)
                    sim.setObjectQuaternion(el[i],_S.conveyorSystem.model,quat)
                    p=p+off
                end
            end
            local resp=sim.groupShapes(el)
            sim.setObjectParent(resp,_S.conveyorSystem.model,true)
            sim.writeCustomDataBlock(resp,'PATHPAD','b')
            sim.setObjectProperty(resp,sim.objectproperty_selectmodelbaseinstead)
            sim.setObjectInt32Param(resp,sim.objintparam_visibility_layer,256)
            sim.setObjectAlias(resp,'respondable')
        end
        if _S.conveyorSystem.config.useBorder then
            local cnt=_S.conveyorSystem.totalLength//(_S.conveyorSystem.config.borderSize[1]*0.5)
            local off=_S.conveyorSystem.totalLength/cnt
            local el={}
            local p=_S.conveyorSystem.config.borderSize[1]*0.5
            local cnt2=cnt-1
            if (config.bitCoded&2)~=0 then
                cnt2=cnt -- closed
            end
            local w=_S.conveyorSystem.config.padSize[2]
            if _S.conveyorSystem.config.useRollers then
                w=_S.conveyorSystem.config.rollerSize[2]
            end
            for i=1,cnt2,1 do
                local pa=sim.createPureShape(0,24,_S.conveyorSystem.config.borderSize,0.01)
                sim.setShapeColor(pa,nil,sim.colorcomponent_ambient_diffuse,_S.conveyorSystem.config.col)
                local pb=sim.createPureShape(0,24,_S.conveyorSystem.config.borderSize,0.01)
                sim.setShapeColor(pb,nil,sim.colorcomponent_ambient_diffuse,_S.conveyorSystem.config.col)
                sim.setObjectPosition(pa,-1,{0,(w-_S.conveyorSystem.config.borderSize[2])/2,0})
                sim.setObjectPosition(pb,-1,{0,-(w-_S.conveyorSystem.config.borderSize[2])/2,0})
                el[i]=sim.groupShapes({pa,pb})
                sim.reorientShapeBoundingBox(el[i],-1)
                local pos=sim.getPathInterpolatedConfig(_S.conveyorSystem.pathPositions,_S.conveyorSystem.pathLengths,p)
                if _S.conveyorSystem.config.useRollers then
                    pos[3]=pos[3]-_S.conveyorSystem.config.rollerSize[1]/2+_S.conveyorSystem.config.borderSize[3]/2
                else
                    pos[3]=pos[3]-_S.conveyorSystem.config.padSize[3]+_S.conveyorSystem.config.borderSize[3]/2
                end
                local quat=sim.getPathInterpolatedConfig(_S.conveyorSystem.pathQuaternions,_S.conveyorSystem.pathLengths,p,nil,{2,2,2,2})
                sim.setObjectPosition(el[i],_S.conveyorSystem.model,pos)
                sim.setObjectQuaternion(el[i],_S.conveyorSystem.model,quat)
                p=p+off
            end
            local resp=sim.groupShapes(el)
            sim.setObjectParent(resp,_S.conveyorSystem.model,true)
            sim.writeCustomDataBlock(resp,'PATHPAD','c')
            sim.setObjectProperty(resp,sim.objectproperty_selectmodelbaseinstead)
            sim.setObjectInt32Param(resp,sim.objintparam_visibility_layer,1+256)
            sim.setObjectAlias(resp,'border')
        end
    end
    if not _S.conveyorSystem.config.useRollers then
        _S.conveyorSystem.setPathPos(_S.conveyorSystem.offset)
    end
end

function path.shaping(path,pathIsClosed,upVector)
    local section
    if _S.conveyorSystem.config.useRollers then
     --   section={-_S.conveyorSystem.config.rollerSize[2]/2,-_S.conveyorSystem.config.rollerSize[2]/2-_S.conveyorSystem.config.rollerSize[1]/2,-_S.conveyorSystem.config.rollerSize[2]/2,-_S.conveyorSystem.config.rollerSize[1]/2,_S.conveyorSystem.config.rollerSize[2]/2,-_S.conveyorSystem.config.rollerSize[1]/2,_S.conveyorSystem.config.rollerSize[2]/2,-_S.conveyorSystem.config.rollerSize[2]/2-_S.conveyorSystem.config.rollerSize[1]/2,-_S.conveyorSystem.config.rollerSize[2]/2,-_S.conveyorSystem.config.rollerSize[2]/2-_S.conveyorSystem.config.rollerSize[1]/2}
        section={-_S.conveyorSystem.config.rollerSize[2]/2,-_S.conveyorSystem.config.rollerSize[1],-_S.conveyorSystem.config.rollerSize[2]/2,-_S.conveyorSystem.config.rollerSize[1]/2,_S.conveyorSystem.config.rollerSize[2]/2,-_S.conveyorSystem.config.rollerSize[1]/2,_S.conveyorSystem.config.rollerSize[2]/2,-_S.conveyorSystem.config.rollerSize[1],-_S.conveyorSystem.config.rollerSize[2]/2,-_S.conveyorSystem.config.rollerSize[1]}
    else
      --  section={-_S.conveyorSystem.config.padSize[2]/2,-_S.conveyorSystem.config.padSize[2]/2-_S.conveyorSystem.config.padSize[3],-_S.conveyorSystem.config.padSize[2]/2,-_S.conveyorSystem.config.padSize[3],_S.conveyorSystem.config.padSize[2]/2,-_S.conveyorSystem.config.padSize[3],_S.conveyorSystem.config.padSize[2]/2,-_S.conveyorSystem.config.padSize[2]/2-_S.conveyorSystem.config.padSize[3],-_S.conveyorSystem.config.padSize[2]/2,-_S.conveyorSystem.config.padSize[2]/2-_S.conveyorSystem.config.padSize[3]}
        section={-_S.conveyorSystem.config.padSize[2]/2,-0.02-_S.conveyorSystem.config.padSize[3],-_S.conveyorSystem.config.padSize[2]/2,-_S.conveyorSystem.config.padSize[3],_S.conveyorSystem.config.padSize[2]/2,-_S.conveyorSystem.config.padSize[3],_S.conveyorSystem.config.padSize[2]/2,-0.02-_S.conveyorSystem.config.padSize[3],-_S.conveyorSystem.config.padSize[2]/2,-0.02-_S.conveyorSystem.config.padSize[3]}
    end
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
        local h=_S.conveyorSystem.padHandles[i]
        p=p % _S.conveyorSystem.totalL
        local o=p
        if o>_S.conveyorSystem.totalLength then
            o=o-_S.conveyorSystem.padOffset
        end
        local pos=sim.getPathInterpolatedConfig(_S.conveyorSystem.pathPositions,_S.conveyorSystem.pathLengths,o)
        pos[3]=pos[3]-_S.conveyorSystem.config.padSize[3]/2
        local quat=sim.getPathInterpolatedConfig(_S.conveyorSystem.pathQuaternions,_S.conveyorSystem.pathLengths,o,nil,{2,2,2,2})
        local pp=sim.getObjectPosition(h,_S.conveyorSystem.model)
        sim.setObjectPosition(h,_S.conveyorSystem.model,pos)
        sim.setObjectQuaternion(h,_S.conveyorSystem.model,quat)
        pp[1]=math.abs(pp[1]-pos[1])
        pp[2]=math.abs(pp[2]-pos[2])
        pp[3]=math.abs(pp[3]-pos[3])
        if pp[1]>_S.conveyorSystem.config.padSize[2] or pp[2]>_S.conveyorSystem.config.padSize[2] or pp[3]>_S.conveyorSystem.config.padSize[2] then
            sim.resetDynamicObject(h) -- otherwise the object would quickly 'fly back' to the start of the conveyor and possibly hit other objects on its way
        end
        p=p+_S.conveyorSystem.padOffset
    end
end

return _S.conveyorSystem