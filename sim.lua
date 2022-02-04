_S={}

math.atan2 = math.atan2 or math.atan
math.pow = math.pow or function(a,b) return a^b end
math.log10 = math.log10 or function(a) return math.log(a,10) end
math.ldexp = math.ldexp or function(x,exp) return x*2.0^exp end
math.frexp = math.frexp or function(x) return sim.auxFunc('frexp',x) end
math.mod = math.mod or math.fmod
table.getn = table.getn or function(a) return #a end
if _VERSION~='Lua 5.1' then
    loadstring = load
end
if unpack then
    -- Lua5.1
    table.pack = function(...) return { n = select("#", ...), ... } end
    table.unpack = unpack
else
    unpack = table.unpack
end

_S.require=require
function require(...)
    local fl
    if sim.setThreadSwitchAllowed then
        fl=sim.setThreadSwitchAllowed(false) -- important when called from coroutine
    end
    local retVals={_S.require(...)}
    if fl then
        sim.setThreadSwitchAllowed(fl)
    end
    return table.unpack(retVals)
end

_S.pcall=pcall
function pcall(...)
    local fl
    if sim.setThreadSwitchAllowed then
        fl=sim.setThreadSwitchAllowed(false) -- important when called from coroutine
    end
    local retVals={_S.pcall(...)}
    if fl then
        sim.setThreadSwitchAllowed(fl)
    end
    return table.unpack(retVals)
end

printToConsole=print
function print(...)
    if sim.addLog then
        local lb=sim.setThreadAutomaticSwitch(false)
        sim.addLog(sim.verbosity_scriptinfos+sim.verbosity_undecorated,getAsString(...))
        sim.setThreadAutomaticSwitch(lb)
    else
        printToConsole(...)
    end
end

function printf(fmt,...)
    local a=table.pack(...)
    for i=1,a.n do
        if type(a[i])=='table' then
            a[i]=_S.anyToString(a[i],{},99)
        elseif type(a[i])=='nil' then
            a[i]='nil'
        end
    end
    print(string.format(fmt,table.unpack(a,1,a.n)))
end

function printBytes(x)
    s=''
    for i=1,#x do
        s=s..string.format('%s%02x',i>1 and ' ' or '',string.byte(x:sub(i,i)))
    end
    print(s)
end

function sim.switchThread()
    if sim.getThreadSwitchAllowed() then
        if sim.isScriptRunningInThread()==1 then
            sim._switchThread() -- old, deprecated threads
        else
            local thread,yieldForbidden=coroutine.running()
            if not yieldForbidden then
                coroutine.yield()
            end
        end
    end
end

function sim.yawPitchRollToAlphaBetaGamma(...)
    local yawAngle,pitchAngle,rollAngle=checkargs({{type='float'},{type='float'},{type='float'}},...)

    local lb=sim.setThreadAutomaticSwitch(false)
    local Rx=sim.buildMatrix({0,0,0},{rollAngle,0,0})
    local Ry=sim.buildMatrix({0,0,0},{0,pitchAngle,0})
    local Rz=sim.buildMatrix({0,0,0},{0,0,yawAngle})
    local m=sim.multiplyMatrices(Ry,Rx)
    m=sim.multiplyMatrices(Rz,m)
    local alphaBetaGamma=sim.getEulerAnglesFromMatrix(m)
    local alpha=alphaBetaGamma[1]
    local beta=alphaBetaGamma[2]
    local gamma=alphaBetaGamma[3]
    sim.setThreadAutomaticSwitch(lb)
    return alpha,beta,gamma
end

function sim.alphaBetaGammaToYawPitchRoll(...)
    local alpha,beta,gamma=checkargs({{type='float'},{type='float'},{type='float'}},...)

    local lb=sim.setThreadAutomaticSwitch(false)
    local m=sim.buildMatrix({0,0,0},{alpha,beta,gamma})
    local v=m[9]
    if v>1 then v=1 end
    if v<-1 then v=-1 end
    local pitchAngle=math.asin(-v)
    local yawAngle,rollAngle
    if math.abs(v)<0.999999 then
        rollAngle=math.atan2(m[10],m[11])
        yawAngle=math.atan2(m[5],m[1])
    else
        -- Gimbal lock
        rollAngle=math.atan2(-m[7],m[6])
        yawAngle=0
    end
    sim.setThreadAutomaticSwitch(lb)
    return yawAngle,pitchAngle,rollAngle
end

function sim.getObjectsWithTag(tagName,justModels)
    local retObjs={}
    local objs=sim.getObjectsInTree(sim.handle_scene)
    for i=1,#objs,1 do
        if (not justModels) or ((sim.getModelProperty(objs[i]) & sim.modelproperty_not_model)==0) then
            local dat=sim.readCustomDataBlockTags(objs[i])
            if dat then
                for j=1,#dat,1 do
                    if dat[j]==tagName then
                        retObjs[#retObjs+1]=objs[i]
                        break
                    end
                end
            end
        end
    end
    return retObjs
end

function sim.executeLuaCode(theCode)
    local f=loadstring(theCode)
    if f then
        local a,b=pcall(f)
        return a,b
    else
        return false,'compilation error'
    end
end

function sim.fastIdleLoop(enable)
    local data=sim.readCustomDataBlock(sim.handle_app,'__IDLEFPSSTACKSIZE__')
    local stage=0
    local defaultIdleFps
    if data then
        data=sim.unpackInt32Table(data)
        stage=data[1]
        defaultIdleFps=data[2]
    else
        defaultIdleFps=sim.getInt32Param(sim.intparam_idle_fps)
    end
    if enable then
        stage=stage+1
    else
        if stage>0 then
            stage=stage-1
        end
    end
    if stage>0 then
        sim.setInt32Param(sim.intparam_idle_fps,0)
    else
        sim.setInt32Param(sim.intparam_idle_fps,defaultIdleFps)
    end
    sim.writeCustomDataBlock(sim.handle_app,'__IDLEFPSSTACKSIZE__',sim.packInt32Table({stage,defaultIdleFps}))
end

function sim.isPluginLoaded(pluginName)
    local index=0
    local moduleName=''
    while moduleName do
        moduleName=sim.getModuleName(index)
        if (moduleName==pluginName) then
            return(true)
        end
        index=index+1
    end
    return(false)
end

function isArray(t)
    local m=0
    local count=0
    for k, v in pairs(t) do
        if type(k) == "number" and math.floor(k)==k and k>0 then
            if k>m then m=k end
            count=count+1
        else
            return false
        end
    end
    return m<=count
end

function sim.getUserVariables()
    local ng={}
    if _S.initGlobals then
        for key,val in pairs(_G) do
            if not _S.initGlobals[key] then
                ng[key]=val
            end
        end
    else
        ng=_G
    end
    -- hide a few additional system variables:
    ng.sim_call_type=nil
    ng.sim_code_function_to_run=nil
    ng.__notFirst__=nil
    ng.__scriptCodeToRun__=nil
    ng._S=nil
    ng.H=nil
    ng.restart=nil
    return ng
end

function sim.getMatchingPersistentDataTags(...)
    local pattern=checkargs({{type='string'}},...)
    local result = {}
    for index, value in ipairs(sim.getPersistentDataTags()) do
        if value:match(pattern) then
            result[#result + 1] = value
        end
    end
    return result
end

function getAsString(...)
    local lb=sim.setThreadAutomaticSwitch(false)
    local a={...}
    local t=''
    if #a==1 and type(a[1])=='string' then
--        t=string.format('"%s"', a[1])
        t=string.format('%s', a[1])
    else
        for i=1,#a,1 do
            if i~=1 then
                t=t..','
            end
            if type(a[i])=='table' then
                t=t.._S.tableToString(a[i],{},99)
            else
                t=t.._S.anyToString(a[i],{},99)
            end
        end
    end
    if #a==0 then
        t='nil'
    end
    sim.setThreadAutomaticSwitch(lb)
    return(t)
end

function math.random2(lower,upper)
    -- same as math.random, but each script has its own generator
    local r=sim.getRandom()
    if lower then
        local b=1
        local d
        if upper then
            b=lower
            d=upper-b
        else
            d=lower-b
        end
        local e=d/(d+1)
        r=b+math.floor(r*d/e)
    end
    return r
end

function math.randomseed2(seed)
    -- same as math.randomseed, but each script has its own generator
    sim.getRandom(seed)
end

function sim.throttle(t,f)
    if _S.lastExecTime==nil then _S.lastExecTime={} end
    local h=string.dump(f)
    local now=sim.getSystemTime()
    if _S.lastExecTime[h]==nil or _S.lastExecTime[h]+t<now then
        f()
        _S.lastExecTime[h]=now
    end
end

function sim.getAlternateConfigs(...)
    local jointHandles,inputConfig,tipHandle,lowLimits,ranges=checkargs({{type='table',item_type='int'},{type='table',item_type='float'},{type='int',default=-1},{type='table',item_type='float',default=NIL,nullable=true},{type='table',item_type='float',default=NIL,nullable=true}},...)

    if #jointHandles<1 or #jointHandles~=#inputConfig or (lowLimits and #jointHandles~=#lowLimits) or (ranges and #jointHandles~=#ranges) then
        error("Bad table size.")
    end

    local lb=sim.setThreadAutomaticSwitch(false)
    local initConfig={}
    local x={}
    local confS={}
    local err=false
    for i=1,#jointHandles,1 do
        initConfig[i]=sim.getJointPosition(jointHandles[i])
        local c,interv=sim.getJointInterval(jointHandles[i])
        local t=sim.getJointType(jointHandles[i])
        local sp=sim.getObjectFloatParam(jointHandles[i],sim.jointfloatparam_screw_pitch)
        if t==sim.joint_revolute_subtype and not c then
            if sp==0 then
                if inputConfig[i]-math.pi*2>=interv[1] or inputConfig[i]+math.pi*2<=interv[1]+interv[2] then
                    -- We use the low and range values from the joint's settings
                    local y=inputConfig[i]
                    while y-math.pi*2>=interv[1] do
                        y=y-math.pi*2
                    end
                    x[i]={y,interv[1]+interv[2]}
                end
            end
        end
        if x[i] then
            if lowLimits and ranges then
                -- the user specified low and range values. Use those instead:
                local l=lowLimits[i]
                local r=ranges[i]
                if r~=0 then
                    if r>0 then
                        if l<interv[1] then
                            -- correct for user bad input
                            r=r-(interv[1]-l)
                            l=interv[1]
                        end
                        if l>interv[1]+interv[2] then
                            -- bad user input. No alternative position for this joint
                            x[i]={inputConfig[i],inputConfig[i]}
                            err=true
                        else
                            if l+r>interv[1]+interv[2] then
                                -- correct for user bad input
                                r=interv[1]+interv[2]-l
                            end
                            if inputConfig[i]-math.pi*2>=l or inputConfig[i]+math.pi*2<=l+r then
                                local y=inputConfig[i]
                                while y<l do
                                    y=y+math.pi*2
                                end
                                while y-math.pi*2>=l do
                                    y=y-math.pi*2
                                end
                                x[i]={y,l+r}
                            else
                                -- no alternative position for this joint
                                x[i]={inputConfig[i],inputConfig[i]}
                                err=(inputConfig[i]<l) or (inputConfig[i]>l+r)
                            end
                        end
                    else
                        r=-r
                        l=inputConfig[i]-r*0.5
                        if l<x[i][1] then
                            l=x[i][1]
                        end
                        local u=inputConfig[i]+r*0.5
                        if u>x[i][2] then
                            u=x[i][2]
                        end
                        x[i]={l,u}
                    end
                end
            end
        else
            -- there's no alternative position for this joint
            x[i]={inputConfig[i],inputConfig[i]}
        end
        confS[i]=x[i][1]
    end
    local configs={}
    if not err then
        for i=1,#jointHandles,1 do
            sim.setJointPosition(jointHandles[i],inputConfig[i])
        end
        local desiredPose=0
        if tipHandle~=-1 then
            desiredPose=sim.getObjectMatrix(tipHandle,-1)
        end
        configs=_S.loopThroughAltConfigSolutions(jointHandles,desiredPose,confS,x,1,tipHandle)
    end

    for i=1,#jointHandles,1 do
        sim.setJointPosition(jointHandles[i],initConfig[i])
    end
    if next(configs)~=nil then
        configs=Matrix:fromtable(configs)
        configs=configs:data()
    end
    sim.setThreadAutomaticSwitch(lb)
    return configs
end

function sim.moveToPose(...)
    local flags,currentPoseOrMatrix,maxVel,maxAccel,maxJerk,targetPoseOrMatrix,callback,auxData,metric,timeStep=checkargs({{type='int'},{type='table',size='7..12'},{type='table',item_type='float'},{type='table',item_type='float'},{type='table',item_type='float'},{type='table',size='7..12'},{type='any'},{type='any',default=NIL,nullable=true},{type='table',size=4,default=NIL,nullable=true},{type='float',default=0}},...)

    if #maxVel<1 or #maxVel~=#maxAccel or #maxVel~=#maxJerk then
        error("Bad table size.")
    end
    if not metric and #maxVel<4 then
        error("Arguments #3, #4 and #5 should be of size 4. (in function 'sim.moveToPose')")
    end

    local lb=sim.setThreadAutomaticSwitch(false)

    local usingMatrices=(#currentPoseOrMatrix>=12)
    local currentMatrix,targetMatrix
    if usingMatrices then
        currentMatrix=currentPoseOrMatrix
        targetMatrix=targetPoseOrMatrix
    else
        currentMatrix=sim.buildMatrixQ(currentPoseOrMatrix,{currentPoseOrMatrix[4],currentPoseOrMatrix[5],currentPoseOrMatrix[6],currentPoseOrMatrix[7]})
        targetMatrix=sim.buildMatrixQ(targetPoseOrMatrix,{targetPoseOrMatrix[4],targetPoseOrMatrix[5],targetPoseOrMatrix[6],targetPoseOrMatrix[7]})
    end

    local outMatrix=sim.copyTable(currentMatrix)
    local axis,angle=sim.getRotationAxis(currentMatrix,targetMatrix)
    local timeLeft=0
    if type(callback)=='string' then
        callback=_G[callback]
    end
    if metric then
        -- Here we treat the movement as a 1 DoF movement, where we simply interpolate via t between
        -- the start and goal pose. This always results in straight line movement paths
        local dx={(targetMatrix[4]-currentMatrix[4])*metric[1],(targetMatrix[8]-currentMatrix[8])*metric[2],(targetMatrix[12]-currentMatrix[12])*metric[3],angle*metric[4]}
        local distance=math.sqrt(dx[1]*dx[1]+dx[2]*dx[2]+dx[3]*dx[3]+dx[4]*dx[4])
        if distance>0.000001 then
            local currentPosVelAccel={0,0,0}
            local maxVelAccelJerk={maxVel[1],maxAccel[1],maxJerk[1]}
            local targetPosVel={distance,0}
            local ruckigObject=sim.ruckigPos(1,0.0001,flags,currentPosVelAccel,maxVelAccelJerk,{1},targetPosVel)
            local result=0
            while result==0 do
                local dt=timeStep
                if dt==0 then
                    dt=sim.getSimulationTimeStep()
                end
                local syncTime
                result,newPosVelAccel,syncTime=sim.ruckigStep(ruckigObject,dt)
                if result>=0 then
                    if result==0 then
                        timeLeft=dt-syncTime
                    end
                    local t=newPosVelAccel[1]/distance
                    outMatrix=sim.interpolateMatrices(currentMatrix,targetMatrix,t)
                    local nv={newPosVelAccel[2]}
                    local na={newPosVelAccel[3]}
                    if not usingMatrices then
                        local q=sim.getQuaternionFromMatrix(outMatrix)
                        outMatrix={outMatrix[4],outMatrix[8],outMatrix[12],q[1],q[2],q[3],q[4]}
                    end
                    if callback(outMatrix,nv,na,auxData) then
                        break
                    end
                else
                    error('sim.ruckigStep returned error code '..result)
                end
                if result==0 then
                    sim.switchThread()
                end
            end
            sim.ruckigRemove(ruckigObject)
        end
    else
        -- Here we treat the movement as a 4 DoF movement, where each of X, Y, Z and rotation
        -- is handled and controlled individually. This can result in non-straight line movement paths,
        -- due to how the Ruckig functions operate depending on 'flags'
        local dx={targetMatrix[4]-currentMatrix[4],targetMatrix[8]-currentMatrix[8],targetMatrix[12]-currentMatrix[12],angle}
        local currentPosVelAccel={0,0,0,0,0,0,0,0,0,0,0,0}
        local maxVelAccelJerk={maxVel[1],maxVel[2],maxVel[3],maxVel[4],maxAccel[1],maxAccel[2],maxAccel[3],maxAccel[4],maxJerk[1],maxJerk[2],maxJerk[3],maxJerk[4]}
        local targetPosVel={dx[1],dx[2],dx[3],dx[4],0,0,0,0,0}
        local ruckigObject=sim.ruckigPos(4,0.0001,flags,currentPosVelAccel,maxVelAccelJerk,{1,1,1,1},targetPosVel)
        local result=0
        while result==0 do
            local dt=timeStep
            if dt==0 then
                dt=sim.getSimulationTimeStep()
            end
            local syncTime
            result,newPosVelAccel,syncTime=sim.ruckigStep(ruckigObject,dt)
            if result>=0 then
                if result==0 then
                    timeLeft=dt-syncTime
                end
                local t=0
                if math.abs(angle)>math.pi*0.00001 then
                    t=newPosVelAccel[4]/angle
                end
                outMatrix=sim.interpolateMatrices(currentMatrix,targetMatrix,t)
                outMatrix[4]=currentMatrix[4]+newPosVelAccel[1]
                outMatrix[8]=currentMatrix[8]+newPosVelAccel[2]
                outMatrix[12]=currentMatrix[12]+newPosVelAccel[3]
                local nv={newPosVelAccel[5],newPosVelAccel[6],newPosVelAccel[7],newPosVelAccel[8]}
                local na={newPosVelAccel[9],newPosVelAccel[10],newPosVelAccel[11],newPosVelAccel[12]}
                if not usingMatrices then
                    local q=sim.getQuaternionFromMatrix(outMatrix)
                    outMatrix={outMatrix[4],outMatrix[8],outMatrix[12],q[1],q[2],q[3],q[4]}
                end
                if callback(outMatrix,nv,na,auxData) then
                    break
                end
            else
                error('sim.ruckigStep returned error code '..result)
            end
            if result==0 then
                sim.switchThread()
            end
        end
        sim.ruckigRemove(ruckigObject)
    end

    sim.setThreadAutomaticSwitch(lb)
    return outMatrix,timeLeft
end

function sim.moveToConfig(...)
    local flags,currentPos,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetVel,callback,auxData,cyclicJoints,timeStep=checkargs({{type='int'},{type='table',item_type='float'},{type='table',item_type='float',nullable=true},{type='table',item_type='float',nullable=true},{type='table',item_type='float'},{type='table',item_type='float'},{type='table',item_type='float'},{type='table',item_type='float'},{type='table',item_type='float',nullable=true},{type='any'},{type='any',default=NIL,nullable=true},{type='table',item_type='bool',default=NIL,nullable=true},{type='float',default=0}},...)

    if #currentPos<1 or #currentPos>#maxVel or #currentPos>#maxAccel or #currentPos>#maxJerk or #currentPos>#targetPos or (currentVel and #currentPos>#currentVel) or (currentAccel and #currentPos>#currentAccel) or (targetVel and #currentPos>#targetVel) or (cyclicJoints and #currentPos>#cyclicJoints) then
        error("Bad table size.")
    end

    local lb=sim.setThreadAutomaticSwitch(false)

    local currentPosVelAccel={}
    local maxVelAccelJerk={}
    local targetPosVel={}
    local sel={}
    local outPos={}
    local outVel={}
    local outAccel={}
    for i=1,#currentPos,1 do
        local v=currentPos[i]
        currentPosVelAccel[i]=v
        outPos[i]=v
        maxVelAccelJerk[i]=maxVel[i]
        local w=targetPos[i]
        if cyclicJoints and cyclicJoints[i] then
            while w-v>=math.pi*2 do
                w=w-math.pi*2
            end
            while w-v<0 do
                w=w+math.pi*2
            end
            if w-v>math.pi then
                w=w-math.pi*2
            end
        end
        targetPosVel[i]=w
        sel[i]=1
    end
    for i=#currentPos+1,#currentPos*2 do
        if currentVel then
            currentPosVelAccel[i]=currentVel[i-#currentPos]
            outVel[i-#currentPos]=currentVel[i-#currentPos]
        else
            currentPosVelAccel[i]=0
            outVel[i-#currentPos]=0
        end
        maxVelAccelJerk[i]=maxAccel[i-#currentPos]
        if targetVel then
            targetPosVel[i]=targetVel[i-#currentPos]
        else
            targetPosVel[i]=0
        end
    end
    for i=#currentPos*2+1,#currentPos*3 do
        if currentAccel then
            currentPosVelAccel[i]=currentAccel[i-#currentPos*2]
            outAccel[i-#currentPos*2]=currentAccel[i-#currentPos*2]
        else
            currentPosVelAccel[i]=0
            outAccel[i-#currentPos*2]=0
        end
        maxVelAccelJerk[i]=maxJerk[i-#currentPos*2]
    end

    local ruckigObject=sim.ruckigPos(#currentPos,0.0001,flags,currentPosVelAccel,maxVelAccelJerk,sel,targetPosVel)
    local result=0
    local timeLeft=0
    if type(callback)=='string' then
        callback=_G[callback]
    end
    while result==0 do
        local dt=timeStep
        if dt==0 then
            dt=sim.getSimulationTimeStep()
        end
        local syncTime
        result,newPosVelAccel,syncTime=sim.ruckigStep(ruckigObject,dt)
        if result>=0 then
            if result==0 then
                timeLeft=dt-syncTime
            end
            for i=1,#currentPos,1 do
                outPos[i]=newPosVelAccel[i]
                outVel[i]=newPosVelAccel[#currentPos+i]
                outAccel[i]=newPosVelAccel[#currentPos*2+i]
            end
            if callback(outPos,outVel,outAccel,auxData) then
                break
            end
        else
            error('sim.ruckigStep returned error code '..result)
        end
        if result==0 then
            sim.switchThread()
        end
    end
    sim.ruckigRemove(ruckigObject)
    sim.setThreadAutomaticSwitch(lb)
    return outPos,outVel,outAccel,timeLeft
end

function sim.generateTimeOptimalTrajectory(...)
    local path,pathLengths,minMaxVel,minMaxAccel,trajPtSamples,boundaryCondition,timeout=checkargs({{type='table',item_type='float',size='2..*'},{type='table',item_type='float',size='2..*'},{type='table',item_type='float',size='2..*'},{type='table',item_type='float',size='2..*'},{type='int',default=1000},{type='string',default='not-a-knot'},{type='float',default=5}},...)

    local confCnt=#pathLengths
    local dof=math.floor(#path/confCnt)

    if (dof*confCnt~=#path) or dof<1 or confCnt<2 or dof~=#minMaxVel/2 or dof~=#minMaxAccel/2 then
        error("Bad table size.")
    end
    local lb=sim.setThreadAutomaticSwitch(false)

    local pM=Matrix(confCnt,dof,path)
    local mmvM=Matrix(2,dof,minMaxVel)
    local mmaM=Matrix(2,dof,minMaxAccel)

    sim.addLog(sim.verbosity_scriptinfos,"Trying to connect via ZeroMQ to the 'toppra' service... make sure the 'docker-image-zmq-toppra' container is running. Details can be found at https://github.com/CoppeliaRobotics/docker-image-zmq-toppra")
    local context=simZMQ.ctx_new()
    local socket=simZMQ.socket(context,simZMQ.REQ)
    simZMQ.setsockopt(socket,simZMQ.RCVTIMEO,sim.packInt32Table{1000*timeout})
    simZMQ.setsockopt(socket,simZMQ.LINGER,sim.packInt32Table{500})
    local result=simZMQ.connect(socket,'tcp://localhost:22505')
    if result==-1 then
        local err=simZMQ.errnum()
        error('connect failed: '..err..': '..simZMQ.strerror(err))
    end
    local json=require'dkjson'
    local result=simZMQ.send(socket,json.encode{
        samples=trajPtSamples,
        ss_waypoints=pathLengths,
        waypoints=pM:totable(),
        velocity_limits=mmvM:totable(),
        acceleration_limits=mmaM:totable(),
        bc_type=boundaryCondition
    },0)
    if result==-1 then
        local err=simZMQ.errnum()
        error('send failed: '..err..': '..simZMQ.strerror(err))
    end
    local msg=simZMQ.msg_new()
    simZMQ.msg_init(msg)
    
    local st=sim.getSystemTimeInMs(-1)
    result=-1
    while sim.getSystemTimeInMs(st)<2000 do
        local rc,revents=simZMQ.poll({socket},{simZMQ.POLLIN},0)
        if rc>0 then
            result=simZMQ.msg_recv(msg,socket,0)
            break
        end
    end
    if result==-1 then
        local err=simZMQ.errnum()
        error('recv failed: '..err..': '..simZMQ.strerror(err))
    end
    local data=simZMQ.msg_data(msg)
    simZMQ.msg_close(msg)
    simZMQ.msg_destroy(msg)

    local r=json.decode(data)
    simZMQ.close(socket)
    simZMQ.ctx_term(context)

    sim.setThreadAutomaticSwitch(lb)
    return Matrix:fromtable(r.qs[1]):data(),r.ts
end

function sim.copyTable(...)
    local orig,copies=checkargs({{type='any'},{type='table',default={}}},...)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[sim.copyTable(orig_key, copies)] = sim.copyTable(orig_value, copies)
            end
            setmetatable(copy, sim.copyTable(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function sim.getPathInterpolatedConfig(...)
    local path,times,t,method,types=checkargs({{type='table',item_type='float',size='2..*'},{type='table',item_type='float',size='2..*'},{type='float'},{type='table',default={type='linear',strength=1.0,forceOpen=false},nullable=true},{type='table',item_type='int',size='1..*',default=NIL,nullable=true}},...)

    local confCnt=#times
    local dof=math.floor(#path/confCnt)

    if (dof*confCnt~=#path) or (types and dof~=#types) then
        error("Bad table size.")
    end

    if types==nil then
        types={}
        for i=1,dof,1 do
            types[i]=0
        end
    end
    local retVal={}
    local li=1
    local hi=2
    if t<0 then t=0 end
--    if confCnt>2 then
        if t>=times[#times] then t=times[#times]-0.00000001 end
        local ll,hl
        for i=2,#times,1 do
            li=i-1
            hi=i
            ll=times[li]
            hl=times[hi]
            if hl>t then -- >= gives problems with overlapping points
                break
            end
        end
        t=(t-ll)/(hl-ll)
--    else
--        if t>1 then t=1 end
--    end
    if method and method.type=='quadraticBezier' then
        local w=1
        if method.strength then
            w=method.strength
        end
        if w<0.05 then
            w=0.05
        end
        local closed=true
        for i=1,dof,1 do
            if (path[i]~=path[(confCnt-1)*dof+i]) then
                closed=false
                break
            end
        end
        if method.forceOpen then
            closed=false
        end
        local i0,i1,i2
        if t<0.5 then
            if li==1 and not closed then
                retVal=_S.linearInterpolate(_S.getConfig(path,dof,li),_S.getConfig(path,dof,hi),t,types)
            else
                if t<0.5*w then
                    i0=li-1
                    i1=li
                    i2=hi
                    if li==1 then
                        i0=confCnt-1
                    end
                    local a=_S.linearInterpolate(_S.getConfig(path,dof,i0),_S.getConfig(path,dof,i1),1-0.25*w+t*0.5,types)
                    local b=_S.linearInterpolate(_S.getConfig(path,dof,i1),_S.getConfig(path,dof,i2),0.25*w+t*0.5,types)
                    retVal=_S.linearInterpolate(a,b,0.5+t/w,types)
                else
                    retVal=_S.linearInterpolate(_S.getConfig(path,dof,li),_S.getConfig(path,dof,hi),t,types)
                end
            end
        else
            if hi==confCnt and not closed then
                retVal=_S.linearInterpolate(_S.getConfig(path,dof,li),_S.getConfig(path,dof,hi),t,types)
            else
                if t>(1-0.5*w) then
                    i0=li
                    i1=hi
                    i2=hi+1
                    if hi==confCnt then
                        i2=2
                    end
                    t=t-(1-0.5*w)
                    local a=_S.linearInterpolate(_S.getConfig(path,dof,i0),_S.getConfig(path,dof,i1),1-0.5*w+t*0.5,types)
                    local b=_S.linearInterpolate(_S.getConfig(path,dof,i1),_S.getConfig(path,dof,i2),t*0.5,types)
                    retVal=_S.linearInterpolate(a,b,t/w,types)
                else
                    retVal=_S.linearInterpolate(_S.getConfig(path,dof,li),_S.getConfig(path,dof,hi),t,types)
                end
            end
        end
    end
    if not method or method.type=='linear' then
        retVal=_S.linearInterpolate(_S.getConfig(path,dof,li),_S.getConfig(path,dof,hi),t,types)
    end
    return retVal
end

function sim.createPath(...)
    local retVal
    local attrib,intParams,floatParams,col=...
    if type(attrib)=='number' then
        retVal=sim._createPath(attrib,intParams,floatParams,col) -- for backward compatibility
    else
        local ctrlPts,options,subdiv,smoothness,orientationMode,upVector=checkargs({{type='table',item_type='float',size='14..*'},{type='int',default=0},{type='int',default=100},{type='float',default=1.0},{type='int',default=0},{type='table',item_type='float',size='3',default={0,0,1}}},...)
        local fl=sim.setThreadSwitchAllowed(false)
        retVal=sim.createDummy(0.04,{0,0.68,0.47,0,0,0,0,0,0,0,0,0})
        sim.setObjectAlias(retVal,"Path")
        local scriptHandle=sim.addScript(sim.scripttype_customizationscript)
        local code=[[path=require('path_customization')

function path.shaping(path,pathIsClosed,upVector)
    local section={0.02,-0.02,0.02,0.02,-0.02,0.02,-0.02,-0.02,0.02,-0.02}
    local color={0.7,0.9,0.9}
    local options=0
    if pathIsClosed then
        options=options|4
    end
    local shape=sim.generateShapeFromPath(path,section,options,upVector)
    sim.setShapeColor(shape,nil,sim.colorcomponent_ambient_diffuse,color)
    return shape
end]]
        sim.setScriptText(scriptHandle,code)
        sim.associateScriptWithObject(scriptHandle,retVal)
        local prop=sim.getModelProperty(retVal)
        sim.setModelProperty(retVal,(prop|sim.modelproperty_not_model)-sim.modelproperty_not_model) -- model
        prop=sim.getObjectProperty(retVal)
        sim.setObjectProperty(retVal,prop|sim.objectproperty_canupdatedna|sim.objectproperty_collapsed)
        local data=sim.packTable({ctrlPts,options,subdiv,smoothness,orientationMode,upVector})
        sim.writeCustomDataBlock(retVal,"ABC_PATH_CREATION",data)
        sim.initScript(scriptHandle)
        sim.setThreadSwitchAllowed(fl)
    end
    return retVal
end

function sim.createCollection(arg1,arg2)
    local retVal
    if type(arg1)=='string' then
        retVal=sim._createCollection(arg1,arg2) -- for backward compatibility
    else
        retVal=sim.createCollectionEx(arg1)
    end
    return retVal
end

function sim.resamplePath(...)
    local path,pathLengths,finalConfigCnt,method,types=checkargs({{type='table',item_type='float',size='2..*'},{type='table',item_type='float',size='2..*'},{type='int'},{type='table',default={type='linear',strength=1.0,forceOpen=false}},{type='table',item_type='int',size='1..*',default=NIL,nullable=true}},...)

    local confCnt=#pathLengths
    local dof=math.floor(#path/confCnt)

    if dof*confCnt~=#path or (confCnt<2) or (types and dof~=#types) then
        error("Bad table size.")
    end

    local retVal={}
    for i=1,finalConfigCnt,1 do
        local c=sim.getPathInterpolatedConfig(path,pathLengths,pathLengths[#pathLengths]*(i-1)/(finalConfigCnt-1),method,types)
        for j=1,dof,1 do
            retVal[(i-1)*dof+j]=c[j]
        end
    end
    return retVal
end

function sim.getConfigDistance(...)
    local confA,confB,metric,types=checkargs({{type='table',item_type='float',size='1..*'},{type='table',item_type='float',size='1..*'},{type='table',item_type='float',default=NIL,nullable=true},{type='table',item_type='int',default=NIL,nullable=true}},...)
    if (#confA~=#confB) or (metric and #confA~=#metric) or (types and #confA~=#types) then
        error("Bad table size.")
    end
    return _S.getConfigDistance(confA,confB,metric,types)
end

function _S.getConfigDistance(confA,confB,metric,types)
    if metric==nil then
        metric={}
        for i=1,#confA,1 do
            metric[i]=1
        end
    end
    if types==nil then
        types={}
        for i=1,#confA,1 do
            types[i]=0
        end
    end

    local d=0
    local qcnt=0
    for j=1,#confA,1 do
        local dd=0
        if types[j]==0 then
            dd=(confB[j]-confA[j])*metric[j] -- e.g. joint with limits
        end
        if types[j]==1 then
            local dx=math.atan2(math.sin(confB[j]-confA[j]),math.cos(confB[j]-confA[j]))
            local v=confA[j]+dx
            dd=math.atan2(math.sin(v),math.cos(v))*metric[j] -- cyclic rev. joint (-pi;pi)
        end
        if types[j]==2 then
            qcnt=qcnt+1
            if qcnt==4 then
                qcnt=0
                local m1=sim.buildMatrixQ({0,0,0},{confA[j-3],confA[j-2],confA[j-1],confA[j-0]})
                local m2=sim.buildMatrixQ({0,0,0},{confB[j-3],confB[j-2],confB[j-1],confB[j-0]})
                local a,angle=sim.getRotationAxis(m1,m2)
                dd=angle*metric[j-3]
            end
        end
        d=d+dd*dd
    end
    return math.sqrt(d)
end

function sim.getPathLengths(...)
    local path,dof,cb=checkargs({{type='table',item_type='float',size='2..*'},{type='int'},{type='any',default=NIL,nullable=true}},...)
    local confCnt=math.floor(#path/dof)
    if dof<1 or (confCnt<2) then
        error("Bad table size.")
    end
    local distancesAlongPath={0}
    local totDist=0
    local pM=Matrix(confCnt,dof,path)
    for i=1,pM:rows()-1,1 do
        local d=ccc
        if cb then
            if type(cb)=='string' then
                d=_G[cb](pM[i]:data(),pM[i+1]:data())
            else
                d=cb(pM[i]:data(),pM[i+1]:data())
            end
        else
            d=sim.getConfigDistance(pM[i]:data(),pM[i+1]:data())
        end
        totDist=totDist+d
        distancesAlongPath[i+1]=totDist
    end
    return distancesAlongPath,totDist
end

function sim.changeEntityColor(...)
    local entityHandle,color,colorComponent=checkargs({{type='int'},{type='table', size=3, item_type='float'},{type='int',default=sim.colorcomponent_ambient_diffuse}},...)
    local colorData={}
    local objs={entityHandle}
    if sim.isHandle(entityHandle,sim.appobj_collection_type) then
        objs=sim.getCollectionObjects(entityHandle)
    end
    for i=1,#objs,1 do
        if sim.getObjectType(objs[i])==sim.object_shape_type then
            local visible=sim.getObjectInt32Param(objs[i],sim.objintparam_visible)
            if visible==1 then
                local res,col=sim.getShapeColor(objs[i],'@compound',colorComponent)
                colorData[#colorData+1]={handle=objs[i],data=col,comp=colorComponent}
                sim.setShapeColor(objs[i],nil,colorComponent,color)
            end
        end
    end
    return colorData
end

function sim.restoreEntityColor(...)
    local colorData=checkargs({{type='table'},size='1..*'},...)
    for i=1,#colorData,1 do
        if sim.isHandle(colorData[i].handle,sim.appobj_object_type) then
            sim.setShapeColor(colorData[i].handle,'@compound',colorData[i].comp,colorData[i].data)
        end
    end
end

function sim.wait(...)
    local dt,simTime=checkargs({{type='float'},{type='bool',default=true}},...)

    local retVal=0
    if simTime then
        local st=sim.getSimulationTime()
        while sim.getSimulationTime()-st<dt do
            sim.switchThread()
        end
        retVal=sim.getSimulationTime()-st-dt
    else
        local st=sim.getSystemTimeInMs(-1)
        while sim.getSystemTimeInMs(st)<dt*1000 do
            sim.switchThread()
        end
    end
    return retVal
end

function sim.waitForSignal(...)
    local sigName=checkargs({{type='string'}},...)
    local retVal
    while true do
        retVal=sim.getInt32Signal(sigName) or sim.getFloatSignal(sigName) or sim.getDoubleSignal(sigName) or sim.getStringSignal(sigName)
        if retVal then
            break
        end
        sim.switchThread()
    end
    return retVal
end

function sim.serialRead(...)
    local portHandle,length,blocking,closingStr,timeout=checkargs({{type='int'},{type='int'},{type='bool',default=false},{type='string',default=''},{type='float',default=0}},...)

    local retVal
    if blocking then
        local st=sim.getSystemTimeInMs(-1)
        while true do
            local data=_S.serialPortData[portHandle]
            _S.serialPortData[portHandle]=''
            if #data<length then
                local d=sim._serialRead(portHandle,length-#data)
                if d then
                    data=data..d
                end
            end
            if #data>=length then
                retVal=string.sub(data,1,length)
                if #data>length then
                    data=string.sub(data,length+1)
                    _S.serialPortData[portHandle]=data
                end
                break
            end
            if closingStr~='' then
                local s,e=string.find(data,closingStr,1,true)
                if e then
                    retVal=string.sub(data,1,e)
                    if #data>e then
                        data=string.sub(data,e+1)
                        _S.serialPortData[portHandle]=data
                    end
                    break
                end
            end
            if sim.getSystemTimeInMs(st)>=(timeout*1000) and timeout~=0 then
                retVal=data
                break
            end
            sim.switchThread()
            _S.serialPortData[portHandle]=data
        end
    else
        local data=_S.serialPortData[portHandle]
        _S.serialPortData[portHandle]=''
        if #data<length then
            local d=sim._serialRead(portHandle,length-#data)
            if d then
                data=data..d
            end
        end
        if #data>length then
            retVal=string.sub(data,1,length)
            data=string.sub(data,length+1)
            _S.serialPortData[portHandle]=data
        else
            retVal=data
        end
    end
    return retVal
end

function sim.serialOpen(...)
    local portString,baudRate=checkargs({{type='string'},{type='int'}},...)

    local retVal=sim._serialOpen(portString,baudRate)
    if not _S.serialPortData then
        _S.serialPortData={}
    end
    _S.serialPortData[retVal]=''
    return retVal
end

function sim.serialClose(...)
    local portHandle=checkargs({{type='int'}},...)

    sim._serialClose(portHandle)
    if _S.serialPortData then
        _S.serialPortData[portHandle]=nil
    end
end

function sim.getShapeBB(handle)
    local s={}
    local m=sim.getObjectFloatParam(handle,sim.objfloatparam_objbbox_max_x)
    local n=sim.getObjectFloatParam(handle,sim.objfloatparam_objbbox_min_x)
    s[1]=m-n
    local m=sim.getObjectFloatParam(handle,sim.objfloatparam_objbbox_max_y)
    local n=sim.getObjectFloatParam(handle,sim.objfloatparam_objbbox_min_y)
    s[2]=m-n
    local m=sim.getObjectFloatParam(handle,sim.objfloatparam_objbbox_max_z)
    local n=sim.getObjectFloatParam(handle,sim.objfloatparam_objbbox_min_z)
    s[3]=m-n
    return s
end

function sim.setShapeBB(handle,size)
    local s=sim.getShapeBB(handle)
    for i=1,3,1 do
        if math.abs(s[i])>0.00001 then
            s[i]=size[i]/s[i]
        end
    end
    sim.scaleObject(handle,s[1],s[2],s[3],0)
end

function sim.getModelBB(handle)
    -- Undocumented function (for now)
    local s={}
    local m=sim.getObjectFloatParam(handle,sim.objfloatparam_modelbbox_max_x)
    local n=sim.getObjectFloatParam(handle,sim.objfloatparam_modelbbox_min_x)
    s[1]=m-n
    local m=sim.getObjectFloatParam(handle,sim.objfloatparam_modelbbox_max_y)
    local n=sim.getObjectFloatParam(handle,sim.objfloatparam_modelbbox_min_y)
    s[2]=m-n
    local m=sim.getObjectFloatParam(handle,sim.objfloatparam_modelbbox_max_z)
    local n=sim.getObjectFloatParam(handle,sim.objfloatparam_modelbbox_min_z)
    s[3]=m-n
    return s
end

function sim.readCustomTableData(...)
    local handle,tagName=checkargs({{type='int'},{type='string'}},...)
    local data=sim.readCustomDataBlock(handle,tagName)
    if data==nil then
        data={}
    else
        data=sim.unpackTable(data)
    end
    return data
end

function sim.writeCustomTableData(...)
    local handle,tagName,theTable=checkargs({{type='int'},{type='string'},{type='table'}},...)
    if next(theTable)==nil then
        sim.writeCustomDataBlock(handle,tagName,'')
    else
        sim.writeCustomDataBlock(handle,tagName,sim.packTable(theTable))
    end
end

function sim.getObject(path,options)
    options=options or {}
    local proxy=-1
    local index=-1
    local option=0
    if options.proxy then
        proxy=options.proxy
    end
    if options.index then
        index=options.index
    end
    if options.noError and options.noError~=false then
        option=1
    end
    return sim._getObject(path,index,proxy,option)
end

function sim.getObjectFromUid(path,options)
    options=options or {}
    local option=0
    if options.noError and options.noError~=false then
        option=1
    end
    return sim._getObjectFromUid(path,option)
end

function sim.getObjectHandle(path,options)
    options=options or {}
    local proxy=-1
    local index=-1
    local option=0
    if options.proxy then
        proxy=options.proxy
    end
    if options.index then
        index=options.index
    end
    if options.noError and options.noError~=false then
        option=1
    end
    return sim._getObjectHandle(path,index,proxy,option)
end

function sim.generateTextShape(...)
    local txt,color,height,centered,alphabetModel=checkargs({{type='string'},{type='table',item_type='float',size=3,default=NIL,nullable=true},{type='float',default=NIL,nullable=true},{type='bool',default=NIL,nullable=true},{type='string',default=NIL,nullable=true}},...)
    local textUtils=require('textUtils')
    return textUtils.generateTextShape(txt,color,height,centered,alphabetModel)
end

function sim.getThreadExistRequest()
    local s=sim.getSimulationState()
    return s==sim.simulation_stopped or s==sim.simulation_advancing_abouttostop or s==sim.simulation_advancing_lastbeforestop
end


function sim.getNamedBoolParam(name)
    local v=sim.getNamedStringParam(name)
    if v==nil then return nil end
    if v=='true' then return true end
    if v=='false' then return false end
    if v=='on' then return true end
    if v=='off' then return false end
    if v=='1' then return true end
    if v=='0' then return false end
    error(string.format('expected a bool value for param "%s"',name))
end

function sim.getNamedFloatParam(name)
    local v=sim.getNamedStringParam(name)
    if v==nil then return nil end
    return tonumber(v)
end

function sim.getNamedInt32Param(name)
    local v=sim.getNamedStringParam(name)
    if v==nil then return nil end
    v=tonumber(v)
    if math.type(v)=='integer' then return v end
    error(string.format('expected an integer value for param "%s"',name))
end

function sim.setNamedBoolParam(name,value)
    return sim.setNamedStringParam(name,tostring(value))
end

function sim.setNamedFloatParam(name,value)
    return sim.setNamedStringParam(name,tostring(value))
end

function sim.setNamedInt32Param(name,value)
    return sim.setNamedStringParam(name,tostring(value))
end

sim.getStringNamedParam=sim.getNamedStringParam
sim.setStringNamedParam=sim.setNamedStringParam

-- Hidden, internal functions:
----------------------------------------------------------
function _S.linearInterpolate(conf1,conf2,t,types)
    local retVal={}
    local qcnt=0
    for i=1,#conf1,1 do
        if types[i]==0 then
            retVal[i]=conf1[i]*(1-t)+conf2[i]*t -- e.g. joint with limits
        end
        if types[i]==1 then
            local dx=math.atan2(math.sin(conf2[i]-conf1[i]),math.cos(conf2[i]-conf1[i]))
            local v=conf1[i]+dx*t
            retVal[i]=math.atan2(math.sin(v),math.cos(v)) -- cyclic rev. joint (-pi;pi)
        end
        if types[i]==2 then
            qcnt=qcnt+1
            if qcnt==4 then
                qcnt=0
                local m1=sim.buildMatrixQ({0,0,0},{conf1[i-3],conf1[i-2],conf1[i-1],conf1[i-0]})
                local m2=sim.buildMatrixQ({0,0,0},{conf2[i-3],conf2[i-2],conf2[i-1],conf2[i-0]})
                local m=sim.interpolateMatrices(m1,m2,t)
                local q=sim.getQuaternionFromMatrix(m)
                retVal[i-3]=q[1]
                retVal[i-2]=q[2]
                retVal[i-1]=q[3]
                retVal[i-0]=q[4]
            end
        end
    end
    return retVal
end

function _S.getConfig(path,dof,index)
    local retVal={}
    for i=1,dof,1 do
        retVal[#retVal+1]=path[(index-1)*dof+i]
    end
    return retVal
end

function _S.loopThroughAltConfigSolutions(jointHandles,desiredPose,confS,x,index,tipHandle)
    if index>#jointHandles then
        if tipHandle==-1 then
            return {sim.copyTable(confS)}
        else
            for i=1,#jointHandles,1 do
                sim.setJointPosition(jointHandles[i],confS[i])
            end
            local p=sim.getObjectMatrix(tipHandle,-1)
            local axis,angle=sim.getRotationAxis(desiredPose,p)
            if math.abs(angle)<0.1*180/math.pi then -- checking is needed in case some joints are dependent on others
                return {sim.copyTable(confS)}
            else
                return {}
            end
        end
    else
        local c={}
        for i=1,#jointHandles,1 do
            c[i]=confS[i]
        end
        local solutions={}
        while c[index]<=x[index][2] do
            local s=_S.loopThroughAltConfigSolutions(jointHandles,desiredPose,c,x,index+1,tipHandle)
            for i=1,#s,1 do
                solutions[#solutions+1]=s[i]
            end
            c[index]=c[index]+math.pi*2
        end
        return solutions
    end
end

function _S.comparableTables(t1,t2)
    return ( isArray(t1)==isArray(t2) ) or ( isArray(t1) and #t1==0 ) or ( isArray(t2) and #t2==0 )
end

function _S.tableToString(tt,visitedTables,maxLevel,indent)
    indent = indent or 0
    maxLevel=maxLevel-1
    if type(tt) == 'table' then
        if maxLevel<=0 then
            return tostring(tt)
        else
            if  visitedTables[tt] then
                return tostring(tt)..' (already visited)'
            else
                visitedTables[tt]=true
                local sb = {}
                if isArray(tt) then
                    table.insert(sb, '{')
                    for i = 1, #tt do
                        table.insert(sb, _S.anyToString(tt[i], visitedTables,maxLevel, indent))
                        if i < #tt then table.insert(sb, ', ') end
                    end
                    table.insert(sb, '}')
                else
                    table.insert(sb, '{\n')
                    -- Print the map content ordered according to type, then key:
                    local tp={{'boolean',false},{'number',true},{'string',true},{'function',false},{'userdata',false},{'thread',true},{'table',false},{'any',false}}
                    local ts={}
                    local usedKeys={}
                    for j=1,#tp,1 do
                        local a={}
                        ts[#ts+1]=a
                        for key,val in pairs(tt) do
                            if type(key)==tp[j][1] or (tp[j][1]=='any' and usedKeys[key]==nil) then
                                a[#a+1]=key
                                usedKeys[key]=true
                            end
                        end
                        if tp[j][2] then
                            table.sort(a)
                        end
                        for k=1,#a,1 do
                            local key=a[k]
                            local val=tt[key]
                            table.insert(sb, string.rep(' ', indent+4))
                            if type(key)=='string' then
                                table.insert(sb, _S.getShortString(key,true))
                            else
                                table.insert(sb, tostring(key))
                            end
                            table.insert(sb, '=')
                            table.insert(sb, _S.anyToString(val, visitedTables,maxLevel, indent+4))
                            table.insert(sb, ',\n')
                        end
                    end
                    table.insert(sb, string.rep(' ', indent))
                    table.insert(sb, '}')
                end
                visitedTables[tt]=false -- siblings pointing onto a same table should still be explored!
                return table.concat(sb)
            end
        end
    else
        return _S.anyToString(tt, visitedTables,maxLevel, indent)
    end
end

function _S.anyToString(x, visitedTables,maxLevel,tblindent)
    local tblindent = tblindent or 0
    if 'nil' == type(x) then
        return tostring(nil)
    elseif 'table' == type(x) then
        return _S.tableToString(x, visitedTables,maxLevel, tblindent)
    elseif 'string' == type(x) then
        return _S.getShortString(x)
    else
        return tostring(x)
    end
end

function _S.getShortString(x,omitQuotes)
    if type(x)=='string' then
        if string.find(x,"\0") then
            return "[buffer string]"
        else
            local a,b=string.gsub(x,"[%a%d%p%s]", "@")
            if b~=#x then
                return "[string containing special chars]"
            else
                if #x>160 then
                    return "[long string]"
                else
                    if omitQuotes then
                        return string.format('%s', x)
                    else
                        return string.format('"%s"', x)
                    end
                end
            end
        end
    end
    return "[not a string]"
end

function _S.sysCallEx_init()
    -- Hook function, registered further down
    quit=sim.quitSimulator
    exit=sim.quitSimulator
    sim.registerScriptFunction('quit@sim','quit()')
    sim.registerScriptFunction('exit@sim','exit()')
    sim.registerScriptFunction('sim.getUserVariables@sim','string[] variables=sim.getUserVariables()')
    sim.registerScriptFunction('sim.getMatchingPersistentDataTags@sim','string[] tags=sim.getMatchingPersistentDataTags(string pattern)')

    sim.registerScriptFunction('sim.yawPitchRollToAlphaBetaGamma@sim','float alphaAngle,float betaAngle,float gammaAngle=sim.yawPitchRollToAlphaBetaGamma(float yawAngle,float pitchAngle,float rollAngle)')
    sim.registerScriptFunction('sim.alphaBetaGammaToYawPitchRoll@sim','float yawAngle,float pitchAngle,float rollAngle=sim.alphaBetaGammaToYawPitchRoll(float alphaAngle,float betaAngle,float gammaAngle)')
    sim.registerScriptFunction('sim.getAlternateConfigs@sim','float[] configs=sim.getAlternateConfigs(int[] jointHandles,float[] inputConfig,int tipHandle=-1,float[] lowLimits=nil,float[] ranges=nil)')
    sim.registerScriptFunction('sim.setObjectSelection@sim','sim.setObjectSelection(int[] handles)')

    sim.registerScriptFunction('sim.moveToPose@sim','float[7] endPose,float timeLeft=sim.moveToPose(int flags,float[7] currentPose,float[] maxVel,float[] maxAccel,float[] maxJerk,float[7] targetPose,func callback,any auxData=nil,float[4] metric=nil,float timeStep=0.0)\nfloat[12] endMatrix,float timeLeft=sim.moveToPose(int flags,float[12] currentMatrix,float[] maxVel,float[] maxAccel,float[] maxJerk,float[12] targetMatrix,func callback,any auxData=nil,float[4] metric=nil,float timeStep=0.0)')
    sim.registerScriptFunction('sim.moveToConfig@sim','float[] endPos,float[] endVel,float[] endAccel,float timeLeft=sim.moveToConfig(int flags,float[] currentPos,float[] currentVel,float[] currentAccel,float[] maxVel,float[] maxAccel,float[] maxJerk,float[] targetPos,float[] targetVel,func callback,any auxData=nil,bool[] cyclicJoints=nil,float timeStep=0.0)')
    sim.registerScriptFunction('sim.switchThread@sim','sim.switchThread()')

    sim.registerScriptFunction('sim.copyTable@sim',"any[] copy=sim.copyTable(any[] original)\nmap copy=sim.copyTable(map original)")

    sim.registerScriptFunction('sim.getPathInterpolatedConfig@sim',"float[] config=sim.getPathInterpolatedConfig(float[] path,float[] pathLengths,float t,map method={type='linear',strength=1.0,forceOpen=false},int[] types=nil)")
    sim.registerScriptFunction('sim.resamplePath@sim',"float[] path=sim.resamplePath(float[] path,float[] pathLengths,int finalConfigCnt,map method={type='linear',strength=1.0,forceOpen=false},int[] types=nil)")
    sim.registerScriptFunction('sim.getPathLengths@sim','float[] pathLengths,float totalLength=sim.getPathLengths(float[] path,int dof,func distCallback=nil)')
    sim.registerScriptFunction('sim.getConfigDistance@sim','float distance=sim.getConfigDistance(float[] configA,float[] configB,float[] metric=nil,int[] types=nil)')
    sim.registerScriptFunction('sim.generateTimeOptimalTrajectory@sim',"float[] path,float[] times=sim.generateTimeOptimalTrajectory(float[] path,float[] pathLengths,float[] minMaxVel,float[] minMaxAccel,int trajPtSamples=1000,string boundaryCondition='not-a-knot',float timeout=5)")
    sim.registerScriptFunction('sim.wait@sim','float timeLeft=sim.wait(float dt,bool simulationTime=true)')
    sim.registerScriptFunction('sim.waitForSignal@sim','any sigVal=sim.waitForSignal(string sigName)')

    sim.registerScriptFunction('sim.serialOpen@sim','int portHandle=sim.serialOpen(string portString,int baudrate)')
    sim.registerScriptFunction('sim.serialClose@sim','sim.serialClose(int portHandle)')
    sim.registerScriptFunction('sim.serialRead@sim',"buffer data=sim.serialRead(int portHandle,int dataLengthToRead,bool blockingOperation,buffer closingString='',float timeout=0)")

    sim.registerScriptFunction('sim.changeEntityColor@sim','map[] originalColorData=sim.changeEntityColor(int entityHandle,float[3] newColor,int colorComponent=sim.colorcomponent_ambient_diffuse)')
    sim.registerScriptFunction('sim.restoreEntityColor@sim','sim.restoreEntityColor(map[] originalColorData)')
    sim.registerScriptFunction('sim.createPath@sim','int pathHandle=sim.createPath(float[] ctrlPts,int options=0,int subdiv=100,float smoothness=1.0,int orientationMode=0,float[3] upVector={0,0,1})')
    sim.registerScriptFunction('sim.createCollection@sim','int collectionHandle=sim.createCollection(int options)')
    sim.registerScriptFunction('sim.readCustomTableData@sim','any data=sim.readCustomTableData(int objectHandle,string tagName)')
    sim.registerScriptFunction('sim.writeCustomTableData@sim','sim.writeCustomTableData(int objectHandle,string tagName,any[] data)\nsim.writeCustomTableData(int objectHandle,string tagName,map data)')
    sim.registerScriptFunction('sim.getObject@sim','int objectHandle=sim.getObject(string path,map options)')
    sim.registerScriptFunction('sim.getObjectFromUid@sim','sim.getObjectFromUid(string path,map options)')
    --sim.registerScriptFunction('sim.getObjectHandle@sim','deprecated. Use sim.getObject instead')
    sim.registerScriptFunction('sim.getShapeBB@sim','float[3] size=sim.getShapeBB(int shapeHandle)')
    sim.registerScriptFunction('sim.setShapeBB@sim','sim.setShapeBB(int shapeHandle,float[3] size)')
    sim.registerScriptFunction('sim.generateTextShape@sim','int modelHandle=sim.generateTextShape(string txt,float[3] color={1,1,1},float height=0.1,bool centered=false,string alphabetLocation=nil)')
    sim.registerScriptFunction('sysCall_thread@sim','entry point for threaded Python scripts') -- actually only for syntax highlighting and call tip
    sim.registerScriptFunction('sim.getThreadExistRequest@sim','bool exit=sim.getThreadExistRequest()') -- actually only for syntax highlighting and call tip
    sim.registerScriptFunction('sim.handleExtCalls@sim','sim.handleExtCalls() (Python only)') -- actually only for syntax highlighting and call tip

    -- Keep for backward compatibility:
    -----------------------------------
    if sim.rmlPos==nil then
        sim.rmlPos=sim.ruckigPos
        sim.rmlVel=sim.ruckigVel
        sim.rmlStep=sim.ruckigStep
        sim.rmlRemove=sim.ruckigRemove
    end
    -----------------------------------

    _S.initGlobals={}
    for key,val in pairs(_G) do
        _S.initGlobals[key]=true
    end
    _S.initGlobals._S=nil
end

----------------------------------------------------------

-- Old stuff, mainly for backward compatibility:
----------------------------------------------------------
function simRMLMoveToJointPositions(...) require("sim_old") return simRMLMoveToJointPositions(...) end
function sim.rmlMoveToJointPositions(...) require("sim_old") return sim.rmlMoveToJointPositions(...) end
function simRMLMoveToPosition(...) require("sim_old") return simRMLMoveToPosition(...) end
function sim.rmlMoveToPosition(...) require("sim_old") return sim.rmlMoveToPosition(...) end
function sim.boolOr32(...) require("sim_old") return sim.boolOr32(...) end
function sim.boolAnd32(...) require("sim_old") return sim.boolAnd32(...) end
function sim.boolXor32(...) require("sim_old") return sim.boolXor32(...) end
function sim.boolOr16(...) require("sim_old") return sim.boolOr16(...) end
function sim.boolAnd16(...) require("sim_old") return sim.boolAnd16(...) end
function sim.boolXor16(...) require("sim_old") return sim.boolXor16(...) end
function sim.setSimilarName(...) require("sim_old") return sim.setSimilarName(...) end
function sim.tubeRead(...) require("sim_old") return sim.tubeRead(...) end
function sim.getObjectHandle_noErrorNoSuffixAdjustment(...) require("sim_old") return sim.getObjectHandle_noErrorNoSuffixAdjustment(...) end
function sim.moveToPosition(...) require("sim_old") return sim.moveToPosition(...) end
function sim.moveToJointPositions(...) require("sim_old") return sim.moveToJointPositions(...) end
function sim.moveToObject(...) require("sim_old") return sim.moveToObject(...) end
function sim.followPath(...) require("sim_old") return sim.followPath(...) end
function sim.include(...) require("sim_old") return sim.include(...) end
function sim.includeRel(...) require("sim_old") return sim.includeRel(...) end
function sim.includeAbs(...) require("sim_old") return sim.includeAbs(...) end
function sim.canScaleObjectNonIsometrically(...) require("sim_old") return sim.canScaleObjectNonIsometrically(...) end
function sim.canScaleModelNonIsometrically(...) require("sim_old") return sim.canScaleModelNonIsometrically(...) end
function sim.scaleModelNonIsometrically(...) require("sim_old") return sim.scaleModelNonIsometrically(...) end
function sim.UI_populateCombobox(...) require("sim_old") return sim.UI_populateCombobox(...) end
function sim.displayDialog(...) require("sim_old") return sim.displayDialog(...) end
function sim.endDialog(...) require("sim_old") return sim.endDialog(...) end
function sim.getDialogInput(...) require("sim_old") return sim.getDialogInput(...) end
function sim.getDialogResult(...) require("sim_old") return sim.getDialogResult(...) end
_S.dlg={}
function _S.dlg.ok_callback(ui)
    local h=_S.dlg.openDlgsUi[ui]
    _S.dlg.allDlgResults[h].state=sim.dlgret_ok
    if _S.dlg.allDlgResults[h].style==sim.dlgstyle_input then
        _S.dlg.allDlgResults[h].input=simUI.getEditValue(ui,1)
    end
    _S.dlg.removeUi(h)
end
function _S.dlg.cancel_callback(ui)
    local h=_S.dlg.openDlgsUi[ui]
    _S.dlg.allDlgResults[h].state=sim.dlgret_cancel
    _S.dlg.removeUi(h)
end
function _S.dlg.input_callback(ui,id,val)
    local h=_S.dlg.openDlgsUi[ui]
    _S.dlg.allDlgResults[h].input=val
end
function _S.dlg.yes_callback(ui)
    local h=_S.dlg.openDlgsUi[ui]
    _S.dlg.allDlgResults[h].state=sim.dlgret_yes
    if _S.dlg.allDlgResults[h].style==sim.dlgstyle_input then
        _S.dlg.allDlgResults[h].input=simUI.getEditValue(ui,1)
    end
    _S.dlg.removeUi(h)
end
function _S.dlg.no_callback(ui)
    local h=_S.dlg.openDlgsUi[ui]
    _S.dlg.allDlgResults[h].state=sim.dlgret_no
    if _S.dlg.allDlgResults[h].style==sim.dlgstyle_input then
        _S.dlg.allDlgResults[h].input=simUI.getEditValue(ui,1)
    end
    _S.dlg.removeUi(h)
end
function _S.dlg.removeUi(handle)
    local ui=_S.dlg.openDlgs[handle]
    simUI.destroy(ui)
    _S.dlg.openDlgsUi[ui]=nil
    _S.dlg.openDlgs[handle]=nil
    if _S.dlg.allDlgResults[handle].state==sim.dlgret_still_open then
        _S.dlg.allDlgResults[handle].state=sim.dlgret_cancel
    end
end
function _S.dlg.switch()
    -- remove all
    if _S.dlg.openDlgsUi then
        local toRem={}
        for key,val in pairs(_S.dlg.openDlgsUi) do
            toRem[#toRem+1]=val
        end
        for i=1,#toRem,1 do
            _S.dlg.removeUi(toRem[i])
        end
        _S.dlg.openDlgsUi=nil
        _S.dlg.openDlgs=nil
    end
end
function _S.sysCallEx_beforeInstanceSwitch()
    -- Hook function, registered further down
    _S.dlg.switch() -- remove all
end
function _S.sysCallEx_addOnScriptSuspend()
    -- Hook function, registered further down
    _S.dlg.switch() -- remove all
end
function _S.sysCallEx_cleanup()
    -- Hook function, registered further down
    _S.dlg.switch() -- remove all
end

-- Make sim.registerScriptFuncHook work also with a function as arg 2:
function _S.registerScriptFuncHook(funcNm,func,before)
    if type(func)=='string' then
        _S.registerScriptFuncHookOrig(funcNm,func,before)
    else
        local str=tostring(func)
        _S.registerScriptFuncHookOrig(funcNm,'_S.'..str,before)
        _S[str]=func
    end
end
_S.registerScriptFuncHookOrig=sim.registerScriptFuncHook
sim.registerScriptFuncHook=_S.registerScriptFuncHook

sim.registerScriptFuncHook('sysCall_init','_S.sysCallEx_init',true)
sim.registerScriptFuncHook('sysCall_cleanup','_S.sysCallEx_cleanup',false)
sim.registerScriptFuncHook('sysCall_beforeInstanceSwitch','_S.sysCallEx_beforeInstanceSwitch',false)
sim.registerScriptFuncHook('sysCall_addOnScriptSuspend','_S.sysCallEx_addOnScriptSuspend',false)
----------------------------------------------------------

require('checkargs')
require('matrix')
require('grid')
