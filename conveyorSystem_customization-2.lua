path=require('path_customization')

_S.conveyorSystem={}

function sysCall_actuation()
    _S.conveyorSystem.actuation()
end

function sysCall_afterSimulation()
    _S.conveyorSystem.afterSimulation()
end

function _S.conveyorSystem.init(config)
    _S.conveyorSystem.config=config
    _S.conveyorSystem.model=sim.getObjectHandle(sim.handle_self)
    sim.writeCustomTableData(_S.conveyorSystem.model,'__info__',{type='conveyor'})
    
    _S.conveyorSystem.vel=0
    _S.conveyorSystem.pos=0
    _S.conveyorSystem.targetVel=_S.conveyorSystem.config.targetVel
    _S.conveyorSystem.targetPos=nil
    sim.writeCustomTableData(_S.conveyorSystem.model,'__state__',{pos=_S.conveyorSystem.pos,vel=_S.conveyorSystem.vel})
    
    path.init()

    local inf=path.readInfo()
    inf.ctrlPtFixedSize=true
    path.writeInfo(inf)
end

function sysCall_afterSimulation()
    _S.conveyorSystem.vel=0
    _S.conveyorSystem.pos=0
    _S.conveyorSystem.targetVel=_S.conveyorSystem.config.targetVel
    _S.conveyorSystem.targetPos=nil
    sim.writeCustomTableData(_S.conveyorSystem.model,'__state__',{pos=_S.conveyorSystem.pos,vel=_S.conveyorSystem.vel})
    
    path.afterSimulation()
end

function _S.conveyorSystem.actuation()
    local prevPos=_S.conveyorSystem.pos
    local dat=sim.readCustomTableData(_S.conveyorSystem.model,'__ctrl__')
    if next(dat)~=nil then
        sim.writeCustomTableData(_S.conveyorSystem.model,'__ctrl__',{})
        if dat.pos then
            _S.conveyorSystem.targetPos=dat.pos
            _S.conveyorSystem.targetVel=nil
        end
        if dat.vel then
            _S.conveyorSystem.targetVel=dat.vel
            _S.conveyorSystem.targetPos=nil
        end
    end
    if _S.conveyorSystem.targetVel then
        local rml=sim.rmlVel(1,0.0001,-1,{_S.conveyorSystem.pos,_S.conveyorSystem.vel,99999},{_S.conveyorSystem.config.accel,99999},{1},{_S.conveyorSystem.targetVel})
        local r,newPosVelAccel=sim.rmlStep(rml,sim.getSimulationTimeStep())
        if r==0 then
            _S.conveyorSystem.pos=newPosVelAccel[1]
            _S.conveyorSystem.vel=newPosVelAccel[2]
        else
            _S.conveyorSystem.vel=_S.conveyorSystem.targetVel
            _S.conveyorSystem.pos=_S.conveyorSystem.pos+_S.conveyorSystem.vel*sim.getSimulationTimeStep()
        end
        sim.rmlRemove(rml)
    end
    if _S.conveyorSystem.targetPos then
        local rml=sim.rmlPos(1,0.0001,-1,{_S.conveyorSystem.pos,_S.conveyorSystem.vel,99999},{99999,_S.conveyorSystem.config.accel,99999},{1},{_S.conveyorSystem.targetPos,0})
        local r,newPosVelAccel=sim.rmlStep(rml,sim.getSimulationTimeStep())
        if r==0 then
            _S.conveyorSystem.pos=newPosVelAccel[1]
            _S.conveyorSystem.vel=newPosVelAccel[2]
        else
            _S.conveyorSystem.vel=0
            _S.conveyorSystem.pos=_S.conveyorSystem.targetPos
        end
        sim.rmlRemove(rml)
    end
    if prevPos~=_S.conveyorSystem.pos then
        if _S.conveyorSystem.config.type==2 then
            for i=1,#_S.conveyorSystem.rolHandles,1 do
                sim.setJointPosition(_S.conveyorSystem.rolHandles[i],_S.conveyorSystem.pos/_S.conveyorSystem.config.radius)
            end
        else
            _S.conveyorSystem.setPathPos(_S.conveyorSystem.pos)
        end
        sim.writeCustomTableData(_S.conveyorSystem.model,'__state__',{pos=_S.conveyorSystem.pos,vel=_S.conveyorSystem.vel})
    end
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
        if _S.conveyorSystem.config.type==2 then
            rolCnt=1+_S.conveyorSystem.totalLength//(_S.conveyorSystem.config.rollerRadius*2+_S.conveyorSystem.config.rollerSpacing)
            _S.conveyorSystem.totalL=_S.conveyorSystem.totalLength
            _S.conveyorSystem.padOffset=_S.conveyorSystem.totalLength/(rolCnt-1)
        else
            padCnt=1+_S.conveyorSystem.totalLength//(_S.conveyorSystem.config.beltElementWidth+_S.conveyorSystem.config.beltElementSpacing)
            _S.conveyorSystem.padOffset=_S.conveyorSystem.config.beltElementWidth+_S.conveyorSystem.config.beltElementSpacing
            _S.conveyorSystem.totalL=_S.conveyorSystem.padOffset*padCnt
        end
    else
        -- closed
        if _S.conveyorSystem.config.type==2 then
            rolCnt=_S.conveyorSystem.totalLength//(_S.conveyorSystem.config.rollerRadius*2+_S.conveyorSystem.config.rollerSpacing)
            _S.conveyorSystem.padOffset=_S.conveyorSystem.totalLength/rolCnt
        else
            padCnt=_S.conveyorSystem.totalLength//(_S.conveyorSystem.config.beltElementWidth+_S.conveyorSystem.config.beltElementSpacing)
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
    local fingerPrint=sim.readCustomDataBlock(_S.conveyorSystem.model,'__fingerPrint__')
    if padCnt==#oldPads and rolCnt==#oldJoints and sim.packTable(_S.conveyorSystem.config)==fingerPrint then
        _S.conveyorSystem.padHandles=oldPads -- reuse old pads, they are the same
        _S.conveyorSystem.rolHandles=oldJoints 
    else
        sim.writeCustomDataBlock(_S.conveyorSystem.model,'__fingerPrint__',sim.packTable(_S.conveyorSystem.config))
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
        if _S.conveyorSystem.config.type==2 then
            for i=1,rolCnt,1 do
                local opt=16
                if _S.conveyorSystem.config.respondable then
                    opt=opt+8
                end
                local cyl=sim.createPureShape(2,opt,{_S.conveyorSystem.config.rollerRadius*2,_S.conveyorSystem.config.rollerRadius*2,_S.conveyorSystem.config.width*0.95},0.01)
                sim.setObjectInt32Param(cyl,sim.objintparam_visibility_layer,1+256)
                local jnt=sim.createJoint(sim.joint_revolute_subtype,sim.jointmode_passive,0)
                _S.conveyorSystem.rolHandles[i]=jnt
                sim.setObjectParent(cyl,jnt,true)
                sim.setSimilarName(jnt,sim.getObjectName(_S.conveyorSystem.model),'__jrol')
                sim.setSimilarName(cyl,sim.getObjectName(_S.conveyorSystem.model),'__rol')
                sim.setShapeColor(cyl,nil,sim.colorcomponent_ambient_diffuse,_S.conveyorSystem.config.color)
                sim.setObjectParent(jnt,_S.conveyorSystem.model,true)
                sim.writeCustomDataBlock(jnt,'PATHROL','a')
                sim.setObjectProperty(cyl,sim.objectproperty_selectmodelbaseinstead)
                sim.setObjectInt32Param(jnt,sim.objintparam_visibility_layer,512)
                local o=(i-1)*_S.conveyorSystem.padOffset
                local pos=sim.getPathInterpolatedConfig(_S.conveyorSystem.pathPositions,_S.conveyorSystem.pathLengths,o)
                pos[3]=pos[3]-_S.conveyorSystem.config.rollerRadius
                local quat=sim.getPathInterpolatedConfig(_S.conveyorSystem.pathQuaternions,_S.conveyorSystem.pathLengths,o,nil,{2,2,2,2})
                local m=Matrix3x3:fromquaternion(quat)
                m=m*Matrix3x3:rotx(-math.pi/2)
                sim.setObjectPosition(jnt,_S.conveyorSystem.model,pos)
                sim.setObjectQuaternion(jnt,_S.conveyorSystem.model,Matrix3x3:toquaternion(m))
            end
        else
            for i=1,padCnt,1 do
                local opt=16
                if _S.conveyorSystem.config.respondable then
                    opt=opt+8
                end
                _S.conveyorSystem.padHandles[i]=sim.createPureShape(0,opt,{_S.conveyorSystem.config.beltElementWidth,_S.conveyorSystem.config.width*0.95,_S.conveyorSystem.config.beltElementThickness},0.01)
                sim.setSimilarName(_S.conveyorSystem.padHandles[i],sim.getObjectName(_S.conveyorSystem.model),'__pad')
                sim.setShapeColor(_S.conveyorSystem.padHandles[i],nil,sim.colorcomponent_ambient_diffuse,_S.conveyorSystem.config.color)
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
                    el[i]=sim.createPureShape(0,24,{--[[_S.conveyorSystem.config.respondableBaseElementLength--]]0.05,_S.conveyorSystem.config.width,_S.conveyorSystem.config.rollerRadius},0.01)
                    local pos=sim.getPathInterpolatedConfig(_S.conveyorSystem.pathPositions,_S.conveyorSystem.pathLengths,p)
                    pos[3]=pos[3]-3*_S.conveyorSystem.config.rollerRadius/2
                    local quat=sim.getPathInterpolatedConfig(_S.conveyorSystem.pathQuaternions,_S.conveyorSystem.pathLengths,p,nil,{2,2,2,2})
                    sim.setObjectPosition(el[i],_S.conveyorSystem.model,pos)
                    sim.setObjectQuaternion(el[i],_S.conveyorSystem.model,quat)
                    p=p+off
                end
            else
                for i=1,cnt,1 do
                    el[i]=sim.createPureShape(0,24,{--[[_S.conveyorSystem.config.respondableBaseElementLength--]]0.05,_S.conveyorSystem.config.width,0.02},0.01)
                    local pos=sim.getPathInterpolatedConfig(_S.conveyorSystem.pathPositions,_S.conveyorSystem.pathLengths,p)
                    pos[3]=pos[3]-0.01-_S.conveyorSystem.config.borderElementThickness
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
            sim.setSimilarName(resp,sim.getObjectName(_S.conveyorSystem.model),'__respondable')
        end
        if _S.conveyorSystem.config.border then
            local cnt=_S.conveyorSystem.totalLength//(_S.conveyorSystem.config.borderElementLength*0.5)
            local off=_S.conveyorSystem.totalLength/cnt
            local el={}
            local p=_S.conveyorSystem.config.borderElementLength*0.5
            local cnt2=cnt-1
            if (config.bitCoded&2)~=0 then
                cnt2=cnt -- closed
            end
            local w=_S.conveyorSystem.config.width
            for i=1,cnt2,1 do
                local pa=sim.createPureShape(0,24,{_S.conveyorSystem.config.borderElementLength,_S.conveyorSystem.config.borderElementThickness,_S.conveyorSystem.config.borderElementHeight},0.01)
                sim.setShapeColor(pa,nil,sim.colorcomponent_ambient_diffuse,_S.conveyorSystem.config.frameColor)
                local pb=sim.createPureShape(0,24,{_S.conveyorSystem.config.borderElementLength,_S.conveyorSystem.config.borderElementThickness,_S.conveyorSystem.config.borderElementHeight},0.01)
                sim.setShapeColor(pb,nil,sim.colorcomponent_ambient_diffuse,_S.conveyorSystem.config.frameColor)
                sim.setObjectPosition(pa,-1,{0,(w-_S.conveyorSystem.config.borderElementThickness)/2,0})
                sim.setObjectPosition(pb,-1,{0,-(w-_S.conveyorSystem.config.borderElementThickness)/2,0})
                el[i]=sim.groupShapes({pa,pb})
                sim.reorientShapeBoundingBox(el[i],-1)
                local pos=sim.getPathInterpolatedConfig(_S.conveyorSystem.pathPositions,_S.conveyorSystem.pathLengths,p)
                if _S.conveyorSystem.config.type==2 then
                    pos[3]=pos[3]-_S.conveyorSystem.config.rollerRadius+_S.conveyorSystem.config.borderElementHeight/2
                else
                    pos[3]=pos[3]-_S.conveyorSystem.config.beltElementThickness+_S.conveyorSystem.config.borderElementHeight/2
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
            sim.setSimilarName(resp,sim.getObjectName(_S.conveyorSystem.model),'__border')
        end
    end
    if _S.conveyorSystem.config.type==1 then
        _S.conveyorSystem.setPathPos(_S.conveyorSystem.pos)
    end
end

function path.shaping(path,pathIsClosed,upVector)
    local section
    if _S.conveyorSystem.config.type==2 then
        section={-_S.conveyorSystem.config.width/2,-_S.conveyorSystem.config.rollerRadius*2,-_S.conveyorSystem.config.width/2,-_S.conveyorSystem.config.rollerRadius,_S.conveyorSystem.config.width/2,-_S.conveyorSystem.config.rollerRadius,_S.conveyorSystem.config.width/2,-_S.conveyorSystem.config.rollerRadius*2,-_S.conveyorSystem.config.width/2,-_S.conveyorSystem.config.rollerRadius*2}
    else
        section={-_S.conveyorSystem.config.width/2,-0.02-_S.conveyorSystem.config.beltElementThickness,-_S.conveyorSystem.config.width/2,-_S.conveyorSystem.config.beltElementThickness,_S.conveyorSystem.config.width/2,-_S.conveyorSystem.config.beltElementThickness,_S.conveyorSystem.config.width/2,-0.02-_S.conveyorSystem.config.beltElementThickness,-_S.conveyorSystem.config.width/2,-0.02-_S.conveyorSystem.config.beltElementThickness}
    end
    local options=0
    if pathIsClosed then
        options=options|4
    end
    local shape=sim.generateShapeFromPath(path,section,options,upVector)
    sim.setShapeColor(shape,nil,sim.colorcomponent_ambient_diffuse,_S.conveyorSystem.config.frameColor)
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
        pos[3]=pos[3]-_S.conveyorSystem.config.beltElementThickness/2
        local quat=sim.getPathInterpolatedConfig(_S.conveyorSystem.pathQuaternions,_S.conveyorSystem.pathLengths,o,nil,{2,2,2,2})
        local pp=sim.getObjectPosition(h,_S.conveyorSystem.model)
        sim.setObjectPosition(h,_S.conveyorSystem.model,pos)
        sim.setObjectQuaternion(h,_S.conveyorSystem.model,quat)
        pp[1]=math.abs(pp[1]-pos[1])
        pp[2]=math.abs(pp[2]-pos[2])
        pp[3]=math.abs(pp[3]-pos[3])
        if pp[1]>_S.conveyorSystem.config.width or pp[2]>_S.conveyorSystem.config.width or pp[3]>_S.conveyorSystem.config.width then
            sim.resetDynamicObject(h) -- otherwise the object would quickly 'fly back' to the start of the conveyor and possibly hit other objects on its way
        end
        p=p+_S.conveyorSystem.padOffset
    end
end

sysCall_userConfig=nil -- path UI
require'configUi'

function sysCall_init()
    self=sim.getObjectHandle(sim.handle_self)
    local c=sim.readCustomTableData(self,'__config__')
    if next(c)==nil then
        c.type=1 -- belt
        c.width=0.2
        c.color={0.2,0.2,0.2}
        c.frameColor={0.5,0.5,0.5}
        c.respondable=true
        c.respondableBase=false
        c.border=true
        c.respondableBorder=true
        c.borderElementLength=0.05
        c.borderElementHeight=0.05
        c.borderElementThickness=0.005
        c.beltElementWidth=0.05
        c.beltElementThickness=0.005
        c.beltElementSpacing=0.002
        c.rollerRadius=0.025
        c.rollerSpacing=0.01
        c.targetVel=0.1
        c.accel=0.01
        sim.writeCustomTableData(self,'__config__',c)
    end
    conveyorSystem.init(c)
end

schema={
    width={
        type='float',
        name='Conveyor width',
        default=0.2,
        minimum=0.01,
        maximum=5,
        ui={control='spinbox',order=2,col=1,tab='general'},
    },
    targetVel={
        type='float',
        name='Target velocity',
        default=0.1,
        minimum=0.001,
        maximum=0.5,
        ui={control='spinbox',order=4,col=1,tab='general'},
    },
    accel={
        type='float',
        name='Acceleration',
        default=0.01,
        minimum=0.001,
        maximum=100,
        ui={control='spinbox',order=5,col=1,tab='general'},
    },
    type={
        name='Conveyor type',
        choices={[1]='belt',[2]='roller'},
        default=1,
        ui={control='radio',order=6,col=2,tab='general'},
    },
    color={
        type='color',
        name='Belt/rollers color',
        default={0.2,0.2,0.2},
        ui={order=7,col=2,tab='general'},
    },
    frameColor={
        type='color',
        name='Frame color',
        default={0.5,0.5,0.5},
        ui={order=8,col=2,tab='general'},
    },
    respondable={
        type='bool',
        name='Respondable belt/rollers',
        default=true,
        ui={order=9,col=1,tab='general'},
    },
    respondableBase={
        type='bool',
        name='Respondable base',
        default=false,
        ui={order=10,col=1,tab='general'},
    },
    border={
        type='bool',
        name='Use border',
        default=true,
        ui={order=12,col=1,tab='border'},
    },
    respondableBorder={
        type='bool',
        name='Respondable border',
        default=true,
        ui={order=13,col=1,tab='border'},
    },
    borderElementLength={
        type='float',
        name='Border element length',
        default=0.05,
        minimum=0.01,
        maximum=0.3,
        ui={control='spinbox',order=14,col=1,tab='border'},
    },
    borderElementHeight={
        type='float',
        name='Border element height',
        default=0.05,
        minimum=0.01,
        maximum=0.2,
        ui={control='spinbox',order=15,col=1,tab='border'},
    },
    borderElementThickness={
        type='float',
        name='Border element thickness',
        default=0.005,
        minimum=0.001,
        maximum=0.05,
        ui={control='spinbox',order=16,col=1,tab='border'},
    },
    beltElementWidth={
        type='float',
        name='Belt element length',
        default=0.05,
        minimum=0.005,
        maximum=0.5,
        ui={control='spinbox',order=20,col=1,tab="belt-type"},
    },
    beltElementThickness={
        type='float',
        name='Belt element thickness',
        default=0.005,
        minimum=0.001,
        maximum=0.2,
        ui={control='spinbox',order=21,col=1,tab="belt-type"},
    },
    beltElementSpacing={
        type='float',
        name='Belt element spacing',
        default=0.01,
        minimum=-0.1,
        maximum=2,
        ui={control='spinbox',order=22,col=1,tab="belt-type"},
    },
    rollerRadius={
        type='float',
        name='Roller radius',
        default=0.05,
        minimum=0.002,
        maximum=0.1,
        ui={control='spinbox',order=30,col=1,tab='roller-type'},
    },
    rollerSpacing={
        type='float',
        name='Roller spacing',
        default=0.01,
        minimum=-0.1,
        maximum=0.2,
        ui={control='spinbox',order=31,col=1,tab="roller-type"},
    },
}

configUi=ConfigUI('Conveyor',schema,_S.conveyorSystem.init)

return _S.conveyorSystem