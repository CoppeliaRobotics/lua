_S.animator={}

function sysCall_actuation()
    _S.animator.actuation()
end

function sysCall_init()
    local config={}
    config.loop=false
    config.backAndForth=false
    config.dirAndSpeed=1
    config.initPos=0
    config.immobile=false
    _S.animator.init(config)
end

function _S.animator.init(config)
    _S.animator.config=config
    _S.animator.self=sim.getObjectHandle(sim.handle_self)
    _S.animator.handles=sim.getReferencedHandles(_S.animator.self)
    _S.animator.animationData=sim.unpackTable(sim.readCustomDataBlock(_S.animator.self,'animationData'))
    _S.animator.totalTime=_S.animator.animationData.times[#_S.animator.animationData.times]
    _S.animator.prevTime=sim.getSimulationTime()
    _S.animator.pos=_S.animator.config.initPos*_S.animator.totalTime
    local initM=sim.getObjectMatrix(_S.animator.self,sim.handle_parent)
    local p=_S.animator.animationData.initPoses[1]
    local m=sim.buildMatrixQ(p,{p[4],p[5],p[6],p[7]})
    sim.invertMatrix(m)
    _S.animator.corrM=sim.multiplyMatrices(initM,m)
    for i=2,#_S.animator.handles,1 do
        if not sim.isHandle(_S.animator.handles[i]) then
            _S.animator.handles[i]=-1 -- maybe the user remove one shape that was not needed in the animation?
        end
    end
    if _S.animator.config.color then
        for i=2,#_S.animator.handles,1 do
            if _S.animator.handles[i]~=-1 then
                sim.setShapeColor(_S.animator.handles[i],nil,sim.colorcomponent_ambient_diffuse,_S.animator.config.color)
                sim.setShapeColor(_S.animator.handles[i],nil,sim.colorcomponent_specular,{0.1,0.1,0.1})
                sim.setShapeColor(_S.animator.handles[i],nil,sim.colorcomponent_emission,{0,0,0})
            end
        end
    end
end

function _S.animator.actuation()
    local t=sim.getSimulationTime()
    local dt=t-_S.animator.prevTime
    local stop=false
    _S.animator.prevTime=t
    local newPos=_S.animator.pos+_S.animator.config.dirAndSpeed*dt
    if _S.animator.config.dirAndSpeed>=0 then
        if newPos>_S.animator.totalTime then
            if _S.animator.config.loop or _S.animator.config.backAndForth then
                if _S.animator.config.backAndForth then
                    _S.animator.config.dirAndSpeed=_S.animator.config.dirAndSpeed*-1
                    newPos=2*_S.animator.totalTime-newPos
                else
                    newPos=newPos-_S.animator.totalTime
                end
            else
                stop=true
                newPos=_S.animator.totalTime
            end
        end
    else
        if newPos<0 then
            if _S.animator.config.loop then
                _S.animator.config.dirAndSpeed=_S.animator.config.dirAndSpeed*-1
                newPos=newPos*-1
            else
                stop=true
                newPos=0
            end
        end
    end
    _S.animator.pos=newPos
    if not stop then
        _S.animator.applyPos()
    end
end

function _S.animator.applyPos()
    for i=1,#_S.animator.handles,1 do
        if _S.animator.handles[i]~=-1 then
            local p=sim.getPathInterpolatedConfig(_S.animator.animationData.poses[i],_S.animator.animationData.times,_S.animator.pos,{type='linear'},{0,0,0,2,2,2,2})
            if i==1 then
                if not _S.animator.config.immobile then
                    local m=sim.buildMatrixQ(p,{p[4],p[5],p[6],p[7]})
                    local m=sim.multiplyMatrices(_S.animator.corrM,m)
                    sim.setObjectMatrix(_S.animator.handles[i],sim.handle_parent,m)
                end
            else
                sim.setObjectPose(_S.animator.handles[i],sim.handle_parent,p)
            end
        end
    end
end

return _S.animator