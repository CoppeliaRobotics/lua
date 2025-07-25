local motion = {}
local checkargs = require('checkargs')
local copy = require('copy')
local Matrix = require'simEigen'.Matrix
local Vector = require'simEigen'.Vector
local Pose = require'simEigen'.Pose
local Quaternion = require'simEigen'.Quaternion

function motion.extend(sim)

function sim.moveToConfig_init(params)
    params = params or {}
    params = copy.deepcopy(params) -- do not modify input values
    if params.pos then
        if not Vector:isvector(params.pos) then
            error("invalid 'pos' field.")
        end
        if params.joints ~= nil and (type(params.joints) ~= 'table' or #params.joints ~= #params.pos) then
            error("invalid 'joints' field.")
        end
    else
        if params.joints == nil then
            error("missing field: either 'pos' or 'joints' is required.")
        else
            if type(params.joints) ~= 'table' or #params.joints == 0 then
                error("invalid 'joints' field.")
            end
            params.pos = Vector(#params.joints, 0.0)
            for i = 1, #params.joints do
                params.pos[i] = sim.getJointPosition(params.joints[i])
            end
        end
    end
    local dim = #params.pos
    if not Vector:isvector(params.targetPos, dim) then
        error("missing or invalid 'targetPos' field.")
    end

    params.maxVel = params.maxVel or Vector(dim, 9999.0)
    params.maxAccel = params.maxAccel or Vector(dim, 99999.0)
    params.maxJerk = params.maxJerk or Vector(dim, 9999999.0)
    
    if type(params.maxVel) == 'number' then
        params.maxvel = Vector(dim, params.maxvel)
    end
    if not Vector:isvector(params.maxVel, dim) then
        error("invalid 'maxVel' field.")
    end
    if type(params.maxAccel) == 'number' then
        params.maxAccel = Vector(dim, params.maxAccel)
    end
    if not Vector:isvector(params.maxAccel, dim) then
        error("invalid 'maxAccel' field.")
    end
    if type(params.maxJerk) == 'number' then
        params.maxJerk = Vector(dim, params.maxJerk)
    end
    if not Vector:isvector(params.maxJerk, dim) then
        error("invalid 'maxJerk' field.")
    end
    
    params.flags = params.flags or -1
    if params.flags == -1 then params.flags = sim.ruckig_phasesync end
    params.flags = params.flags | sim.ruckig_minvel | sim.ruckig_minaccel

    params.vel = params.vel or Vector(dim, 0.0)
    params.accel = params.accel or Vector(dim, 0.0)
    params.minVel = params.minVel or (params.maxVel * -1.0)
    if type(params.minVel) == 'number' then
        params.minVel = Vector(dim, params.minVel)
    end
    if not Vector:isvector(params.minVel, dim) then
        error("missing or invalid 'minVel' field.")
    end
    params.minAccel = params.minAccel or (params.maxAccel * -1.0)
    if type(params.minAccel) == 'number' then
        params.minAccel = Vector(dim, params.minAccel)
    end
    if not Vector:isvector(params.minAccel, dim) then
        error("missing or invalid 'minAccel' field.")
    end
    params.targetVel = params.targetVel or Vector(dim, 0.0)
    params.timeStep = params.timeStep or 0
    if not Vector:isvector(params.vel, dim) then
        error("missing or invalid 'vel' field.")
    end
    if not Vector:isvector(params.accel, dim) then
        error("missing or invalid 'accel' field.")
    end
    if not Vector:isvector(params.targetVel, dim) then
        error("missing or invalid 'targetVel' field.")
    end

    for i = 1, dim do
        local v = params.pos[i]
        local w = params.targetPos[i]
        if params.cyclicJoints and params.cyclicJoints[i] then
            while w - v >= math.pi * 2 do w = w - math.pi * 2 end
            while w - v < 0 do w = w + math.pi * 2 end
            if w - v > math.pi then w = w - math.pi * 2 end
        end
        params.targetPos[i] = w
    end
    local currentPosVelAccel = params.pos:vertcat(params.vel, params.accel):data()
    local maxVelAccelJerk = params.maxVel:vertcat(params.maxAccel, params.maxJerk, params.minVel, params.minAccel):data()
    local targetPosVel = params.targetPos:vertcat(params.targetVel):data()
    local sel = table.rep(1, dim)
    
    params.ruckigObj = sim.ruckigPos(dim, 0.0001, params.flags, currentPosVelAccel, maxVelAccelJerk, sel, targetPosVel)
    if type(params.callback) == 'string' then
        params.callback = _G[params.callback]
    end
    if _S.simMoveToConfig_callbacks == nil then
        _S.simMoveToConfig_callbacks = {}
    end
    _S.simMoveToConfig_callbacks[params] = params.callback
    params.callback = nil -- callback are not convenient to transport back and forth to (possibly) Python
    params.timeLeft = 0
    
    return params
end

function sim.moveToConfig_step(data)
    local dt = data.timeStep
    if dt == 0 then
        dt = sim.getSimulationTimeStep()
    end
    local res, newPosVelAccel, syncTime = sim.ruckigStep(data.ruckigObj, dt)
    newPosVelAccel = Vector(newPosVelAccel)
    if res >= 0 then
        if res == 0 then
            data.timeLeft = dt - syncTime
        end
        data.pos = newPosVelAccel:block(1, 1, #data.pos, 1)
        data.vel = newPosVelAccel:block(#data.pos + 1, 1, #data.pos, 1)
        data.accel = newPosVelAccel:block(2 * #data.pos + 1, 1, #data.pos, 1)
        local cb = _S.simMoveToConfig_callbacks[data]
        if cb then
            if cb(data) then
                res = 2 -- aborted
            end
        else
            if data.joints then
                for i = 1, #data.joints do
                    if sim.isDynamicallyEnabled(data.joints[i]) then
                        sim.setJointTargetPosition(data.joints[i], data.pos[i])
                    else    
                        sim.setJointPosition(data.joints[i], data.pos[i])
                    end
                end
            end
        end
    end

    return res, data
end

function sim.moveToConfig_cleanup(data)
    if data.ruckigObj then
        sim.ruckigRemove(data.ruckigObj)
        data.ruckigObj = nil
        _S.simMoveToConfig_callbacks[data] = nil
    end
end

function sim.moveToConfig(...)
    local params = ...
    local lb = sim.setStepping(true)
    local data = sim.moveToConfig_init(params)
    local outParams = {}
    local res
    while true do
        res, outParams = sim.moveToConfig_step(data)
        if res < 0 then
            error('sim.moveToConfig_step returned error code ' .. res)
        end
        sim.step()
        if res ~= 0 then
            break
        end
    end
    sim.moveToConfig_cleanup(data)
    sim.setStepping(lb)
    return outParams
end

function sim.moveToPose_init(params)
    params = params or {}
    params = copy.deepcopy(params) -- do not modify input values
    params.relObject = params.relObject or -1
    if params.pose then
        if not Pose:ispose(params.pose) then
            error("invalid 'pose' field.")
        end
        params.relObject = -1
        params.object = nil
        params.ik = nil
    else
        if params.object then
            if type(params.object) ~= 'number' then
                error("invalid 'object' field.")
            end
            params.pose = sim.getObjectPose(params.object, params.relObject)
            params.ik = nil
        else
            if params.ik == nil then
                error("missing field: either 'pose', 'object' or 'ik' is required.")
            else
                if type(params.ik) ~= 'table' or type(params.ik.tip) ~= 'number' or type(params.ik.target) ~= 'number' then
                    error("invalid 'ik' field, or missing/invalid sub-fields.")
                end
                params.relObject = -1
                params.object = params.ik.target
                sim.setObjectPose(params.ik.target, sim.getObjectPose(params.ik.tip))
                params.pose = sim.getObjectPose(params.object)
            end
        end
    end
    
    if not Pose:ispose(params.targetPose) then
        error("missing or invalid 'targetPose' field.")
    end
    local dim = 4
    if params.metric then
        if not Vector:isvector(params.metric, 4) then
            error("invalid 'metric' field.")
        end
        dim = 1
    end

    params.maxVel = params.maxVel or Vector(dim, 9999.0)
    params.maxAccel = params.maxAccel or Vector(dim, 99999.0)
    params.maxJerk = params.maxJerk or Vector(dim, 9999999.0)
    
    if type(params.maxVel) == 'number' then
        params.maxVel = Vector(dim, params.maxVel)
    end
    if not Vector:isvector(params.maxVel, dim) then
        error("invalid 'maxVel' field.")
    end
    if type(params.maxAccel) == 'number' then
        params.maxAccel = Vector(dim, params.maxAccel)
    end
    if not Vector:isvector(params.maxAccel, dim) then
        error("invalid 'maxAccel' field.")
    end
    if type(params.maxJerk) == 'number' then
        params.maxJerk = Vector(dim, params.maxJerk)
    end
    if not Vector:isvector(params.maxJerk, dim) then
        error("invalid 'maxJerk' field.")
    end
    
    params.flags = params.flags or -1
    if params.flags == -1 then params.flags = sim.ruckig_phasesync end
    params.flags = params.flags | sim.ruckig_minvel | sim.ruckig_minaccel
    params.minVel = params.minVel or (params.maxVel * -1.0)
    if type(params.minVel) == 'number' then
        params.minVel = Vector(dim, params.minVel)
    end
    if not Vector:isvector(params.minVel, dim) then
        error("missing or invalid 'minVel' field.")
    end
    params.minAccel = params.minAccel or (params.maxAccel * -1.0)
    if type(params.minAccel) == 'number' then
        params.minAccel = Vector(dim, params.minAccel)
    end
    if not Vector:isvector(params.minAccel, dim) then
        error("missing or invalid 'minAccel' field.")
    end

    if params.ik then
        local simIK = require('simIK')
        params.ik.breakFlags = params.ik.breakFlags or 0
        params.ik.base = params.ik.base or -1
        params.ik.method = params.ik.method or simIK.method_damped_least_squares
        params.ik.damping = params.ik.damping or 0.02
        params.ik.iterations = params.ik.iterations or 20
        params.ik.constraints = params.ik.constraints or simIK.constraint_pose
        params.ik.precision = params.ik.precision or {0.001, 0.5 * math.pi / 180}
        params.ik.allowError = params.ik.allowError
        params.ik.ikEnv = simIK.createEnvironment()
        params.ik.ikGroup = simIK.createGroup(params.ik.ikEnv)
        simIK.setGroupCalculation(params.ik.ikEnv, params.ik.ikGroup, params.ik.method, params.ik.damping, params.ik.iterations)
        params.ik.ikElement, params.ik.simToIkMap, params.ik.ikToSimMap = simIK.addElementFromScene(params.ik.ikEnv, params.ik.ikGroup, params.ik.base, params.ik.tip, params.ik.target, params.ik.constraints)
        simIK.setElementPrecision(params.ik.ikEnv, params.ik.ikGroup, params.ik.ikElement, params.ik.precision)
        local hadJoints = params.ik.joints and (#params.ik.joints > 0)
        if not hadJoints then
            params.ik.joints = {}
        end
        for k, v in pairs(params.ik.simToIkMap) do
            if sim.getObjectType(k) == sim.sceneobject_joint then
                if hadJoints then
                    local found = false
                    for i = 1, #params.ik.joints do
                        if params.ik.joints[i] == k then
                            found = true
                            break
                        end
                    end
                    if not found then
                        simIK.setJointMode(params.ik.ikEnv, v, simIK.jointmode_passive)
                    end
                else
                    params.ik.joints[#params.ik.joints + 1] = k
                end
            end
        end
    end

    params.vel = params.vel or Vector(dim, 0.0)
    params.accel = params.accel or Vector(dim, 0.0)
    params.targetVel = params.targetVel or Vector(dim, 0.0)
    
    params.timeStep = params.timeStep or 0

    params.startMatrix = params.pose:totransform()
    params.targetMatrix = params.targetPose:totransform()
    params.matrix = params.startMatrix:copy()
    
    if type(params.callback) == 'string' then
        params.callback = _G[params.callback]
    end
    if _S.simMoveToPose_callbacks == nil then
        _S.simMoveToPose_callbacks = {}
    end
    _S.simMoveToPose_callbacks[params] = params.callback
    params.callback = nil -- callback are not convenient to transport back and forth to (possibly) Python
    
    params.timeLeft = 0
    params.dist = 1.0
    
    local axis, angle = sim.getRotationAxis(params.startMatrix, params.targetMatrix)
    params.angle = angle
    if params.metric then
        -- Here we treat the movement as a 1 DoF movement, where we simply interpolate via t between
        -- the start and goal pose. This always results in straight line movement paths
        local dx = {
            (params.targetMatrix[1][4] - params.startMatrix[1][4]) * params.metric[1],
            (params.targetMatrix[2][4] - params.startMatrix[2][4]) * params.metric[2],
            (params.targetMatrix[3][4] - params.startMatrix[4][4]) * params.metric[3], params.angle * params.metric[4],
        }
        params.dist = math.sqrt(dx[1] * dx[1] + dx[2] * dx[2] + dx[3] * dx[3] + dx[4] * dx[4])
        if params.dist > 0.000001 then
            local currentPosVelAccel = {0, params.vel[1], params.accel[1]}
            local maxVelAccelJerk = {params.maxVel[1], params.maxAccel[1], params.maxJerk[1], params.minVel[1], params.minAccel[1]}
            params.ruckigObj = sim.ruckigPos(1, 0.0001, params.flags, currentPosVelAccel, maxVelAccelJerk, {1}, {params.dist, params.targetVel[1]} )
        end
    else
        -- Here we treat the movement as a 4 DoF movement, where each of X, Y, Z and rotation
        -- is handled and controlled individually. This can result in non-straight line movement paths,
        -- due to how the Ruckig functions operate depending on 'flags'
        local dx = Vector({
            params.targetMatrix[1][4] - params.startMatrix[1][4], params.targetMatrix[2][4] - params.startMatrix[2][4],
            params.targetMatrix[3][4] - params.startMatrix[3][4], params.angle,
        })
        local currentPosVelAccel = Vector(dim, 0.0):vertcat(params.vel, params.accel):data()
        local maxVelAccelJerk = params.maxVel:vertcat(params.maxAccel, params.maxJerk, params.minVel, params.minAccel):data()
        local targetPosVel = dx:vertcat(params.targetVel):data()
        params.ruckigObj = sim.ruckigPos(dim, 0.0001, params.flags, currentPosVelAccel, maxVelAccelJerk, table.rep(1, dim), targetPosVel)
    end
    
    return params
end
            
function sim.moveToPose_step(data)
    local res
    local dt = data.timeStep
    if dt == 0 then
        dt = sim.getSimulationTimeStep()
    end
    if data.metric then
        -- Here we treat the movement as a 1 DoF movement, where we simply interpolate via t between
        -- the start and goal pose. This always results in straight line movement paths
        if data.dist > 0.000001 then
            local newPosVelAccel, syncTime
            res, newPosVelAccel, syncTime = sim.ruckigStep(data.ruckigObj, dt)
            if res >= 0 then
                if res == 0 then
                    data.timeLeft = dt - syncTime
                end
                local t = newPosVelAccel[1] / data.dist
                data.matrix = sim.interpolateMatrices(data.startMatrix, data.targetMatrix, t)
                data.pose = Pose:fromtransform(data.matrix)
                data.vel = Vector{newPosVelAccel[2]}
                data.accel = Vector{newPosVelAccel[3]}
                local cb = _S.simMoveToPose_callbacks[data]
                if cb then
                    if cb(data) then
                        res = 2 -- aborted
                    end
                else
                    if data.object then
                        sim.setObjectPose(data.object, data.pose, data.relObject)
                    end
                    if data.ik then
                        local simIK = require('simIK-2')
                        local r, f = simIK.handleGroup(data.ik.ikEnv, data.ik.ikGroup, {syncWorlds = true, allowError = data.ik.allowError})
                        if f & cmd.params.ik.breakFlags ~= 0 then
                            error('simIK.handleGroup in sim.moveToPose_step returned flags ' .. f)
                        end
                    end
                end
            end
        else
            res = 1 -- i.e. there is no motion to be executed
        end
    else
        -- Here we treat the movement as a 4 DoF movement, where each of X, Y, Z and rotation
        -- is handled and controlled individually. This can result in non-straight line movement paths,
        -- due to how the Ruckig functions operate depending on 'flags'
        local newPosVelAccel, syncTime
        res, newPosVelAccel, syncTime = sim.ruckigStep(data.ruckigObj, dt)
        if res >= 0 then
            if res == 0 then
                data.timeLeft = dt - syncTime
            end
            local t = 0
            if math.abs(data.angle) > math.pi * 0.00001 then
                t = newPosVelAccel[4] / data.angle
            end
            data.matrix = sim.interpolateMatrices(data.startMatrix, data.targetMatrix, t)
            data.matrix[1][4] = data.startMatrix[1][4] + newPosVelAccel[1]
            data.matrix[2][4] = data.startMatrix[2][4] + newPosVelAccel[2]
            data.matrix[3][4] = data.startMatrix[3][4] + newPosVelAccel[3]
            data.pose = Pose:fromtransform(data.matrix)
            data.vel  = Vector(table.slice(newPosVelAccel, 5, 8))
            data.accel = Vector(table.slice(newPosVelAccel, 9, 12))
            local cb = _S.simMoveToPose_callbacks[data]
            if cb then
                if cb(data) then
                    res = 2 -- aborted
                end
            else
                if data.object then
                    sim.setObjectPose(data.object, data.pose, data.relObject)
                end
                if data.ik then
                    local simIK = require('simIK-2')
                    simIK.handleGroup(data.ik.ikEnv, data.ik.ikGroup, {syncWorlds = true, allowError = data.ik.allowError})
                end
            end
        end
    end

    return res, data
end

function sim.moveToPose_cleanup(data)
    if data.ruckigObj then
        sim.ruckigRemove(data.ruckigObj)
        data.ruckigObj = nil
        _S.simMoveToPose_callbacks[data] = nil
    end
    if data.ik then
        local simIK = require('simIK-2')
        simIK.eraseEnvironment(data.ik.ikEnv)
        data.ik = nil
    end
end

function sim.moveToPose(...)
    local params = ...
    local lb = sim.setStepping(true)
    local data = sim.moveToPose_init(params)
    local outParams = {}
    local res
    while true do
        res, outParams = sim.moveToPose_step(data)
        if res < 0 then
            error('sim.moveToPose_step returned error code ' .. res)
        end
        sim.step()
        if res ~= 0 then
            break
        end
    end
    sim.moveToPose_cleanup(data)
    sim.setStepping(lb)
    return outParams
end

function sim.generateTimeOptimalTrajectory(...)
    local path, pathLengths, minMaxVel, minMaxAccel, trajPtSamples, boundaryCondition, timeout, script =
        checkargs({
            {type = 'table', item_type = 'float', size = '2..*'},
            {type = 'table', item_type = 'float', size = '2..*'},
            {type = 'table', item_type = 'float', size = '2..*'},
            {type = 'table', item_type = 'float', size = '2..*'},
            {type = 'int', default = 1000},
            {type = 'string', default = 'not-a-knot'},
            {type = 'float', default = 5},
            {type = 'int', default_nil = true, nullable = true},
    }, ...)

    local confCnt = #pathLengths
    local dof = math.floor(#path / confCnt)

    if (dof * confCnt ~= #path) or dof < 1 or confCnt < 2 or dof ~= #minMaxVel / 2 or
        dof ~= #minMaxAccel / 2 then error("Bad table size.") end
    local lb = sim.setStepping(true)

    local pM = Matrix(confCnt, dof, path)
    local mmvM = Matrix(dof, 2, minMaxVel)
    local mmaM = Matrix(dof, 2, minMaxAccel)

    local code = [=[
def sysCall_init():
    global ta, constraint, algo, np
    import toppra as ta
    import toppra.constraint as constraint
    import toppra.algorithm as algo
    import numpy as np
    ta.setup_logging("WARNING")

def sysCall_cleanup():
    pass

def cb(req):
    try:
        resp = cbb(req)
        resp['success'] = True
    except Exception as e:
        resp = {'success': False, 'error': str(e)}
    return resp

def rs(a):
    flattened = [item for sublist in a for item in sublist]
    reshaped_matrix = [flattened[i:i + 2] for i in range(0, len(flattened), 2)]
    return reshaped_matrix

def cbb(req):
    coefficients = ta.SplineInterpolator(req['ss_waypoints'], req['waypoints'], req.get('bc_type', 'not-a-knot'))
    pc_vel = constraint.JointVelocityConstraint(req['velocity_limits'])
    pc_acc = constraint.JointAccelerationConstraint(req['acceleration_limits'], discretization_scheme=constraint.DiscretizationType.Interpolation)
    instance = algo.TOPPRA([pc_vel, pc_acc], coefficients, solver_wrapper='seidel')
    jnt_traj = instance.compute_trajectory(0, 0)
    duration = jnt_traj.duration
    #print("Found optimal trajectory with duration {:f} sec".format(duration))
    n = coefficients.dof
    resp = dict(qs=[[]]*n, qds=[[]]*n, qdds=[[]]*n)
    ts = np.linspace(0, duration, req.get('samples', 100))
    for i in range(n):
        resp['qs'][i] = jnt_traj.eval(ts).tolist()
        resp['qds'][i] = jnt_traj.evald(ts).tolist()
        resp['qdds'][i] = jnt_traj.evaldd(ts).tolist()
    resp['ts'] = ts.tolist()
    return resp
]=]

    local removeScript = true
    if script then
        removeScript = false
    end
    if script == nil or script == -1 then
        script = sim.createScript(sim.scripttype_customization, code, 0, 'python')
        sim.setObjectAlias(script, 'toppraPythonScript_tmp')
        sim.initScript(script)
    end
    local toSend = {
        samples = trajPtSamples,
        ss_waypoints = pathLengths,
        waypoints = pM:totable(),
        velocity_limits = mmvM:totable(),
        acceleration_limits = mmaM:totable(),
        bc_type = boundaryCondition,
    }

    local s, r = pcall(sim.callScriptFunction, 'cb', script, toSend)
    if removeScript then
        sim.removeObjects({script})
        script = nil
    end
    sim.setStepping(lb)
    
    if s ~= true then
        error('Failed calling TOPPRA via the generated Python script. Make sure Python is configured for CoppeliaSim, and toppra as well as numpy are installed: ' .. sim.getProperty(sim.handle_app, 'defaultPython') .. ' -m pip install pyzmq cbor2 numpy toppra.')
    end

    if not r.success then
        error('toppra failed with following message: ' .. r.error)
    end
    return simEigen.Matrix(r.qs[1]):data(), r.ts, script
end

end -- end of motion.extend

return motion
