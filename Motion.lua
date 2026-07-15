local sim = require('sim-2')
local sim1 = require('sim-1')
local class = require('middleclass')
local checkargs = require('checkargs-2')
local copy = require('copy')
local simEigen = require('simEigen')
local Vector, Matrix, Quaternion, Pose = simEigen.Vector, simEigen.Matrix, simEigen.Quaternion, simEigen.Pose

-- ═════════════════════════════════════════════
-- Motion (abstract base)
-- ═════════════════════════════════════════════
local Motion = class('Motion')

function Motion:initialize()
    self._callback = nil
    self._data = nil
end

function Motion:step()
    error('step() must be implemented by a subclass.')
end

function Motion:remove()
    error('remove() must be implemented by a subclass.')
end

function Motion:data()
    return self._data
end

function Motion:run()
    sim.self:setStepping(true)
    local res
    while true do
        res = self:step()
        sim.self:step()
        if res ~= 0 then
            break
        end
    end
    local outData = self._data
    self:remove()
    sim.self:setStepping(false)
    return outData
end

-- ═════════════════════════════════════════════
-- MoveToConfig
-- ═════════════════════════════════════════════
local MoveToConfig = class('MoveToConfig', Motion)

function MoveToConfig:initialize(pparams)
    Motion.initialize(self)

    pparams = pparams or {}
    local auxData = pparams.auxData
    pparams.auxData = nil
    local params = copy.deepcopy(pparams) -- do not modify input values
    pparams.auxData = auxData
    params.auxData = auxData

    -- Following just to implicitly convert tables to vectors. Arg checking happens further down for historical reasons 
    checkargs.checkfields({funcName = 'MoveToConfig:new'}, {
        {name = 'pos', type = 'vector', nullable = true},
        {name = 'vel', type = 'vector', nullable = true},
        {name = 'accel', type = 'vector', nullable = true},
        {name = 'maxVel', type = 'vector', nullable = true},
        {name = 'minVel', type = 'vector', nullable = true},
        {name = 'maxAccel', type = 'vector', nullable = true},
        {name = 'minAccel', type = 'vector', nullable = true},
        {name = 'maxJerk', type = 'vector', nullable = true},
        {name = 'targetVel', type = 'vector', nullable = true},
        {name = 'targetPos', type = 'vector', nullable = true},
    }, params)
    
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
                params.pos[i] = params.joints[i].joint.position
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
    params.flags = params.flags | sim1.ruckig_minvel | sim1.ruckig_minaccel

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

--[[
    local currentPosVelAccel = params.pos:vertcat(params.vel, params.accel):data()
    local maxVelAccelJerk = params.maxVel:vertcat(params.maxAccel, params.maxJerk, params.minVel, params.minAccel):data()
    local targetPosVel = params.targetPos:vertcat(params.targetVel):data()
    local sel = table.rep(1, dim)
    params.ruckigObj = sim.ruckigPos(dim, 0.0001, params.flags, currentPosVelAccel, maxVelAccelJerk, sel, targetPosVel)
--]]
    local M = require'Motion'
    params.ruckigObj = M.RuckigPosition:new(params)

    if type(params.callback) == 'string' then
        params.callback = _G[params.callback]
    end
    self._callback = params.callback
    params.callback = nil
    params.timeLeft = 0

    self._data = params
end

function MoveToConfig:step()
    local data = self._data
    if not data then
        error('MoveToConfig not initialized or already cleaned up.')
    end

    local dt = data.timeStep
    if dt == 0 then
        dt = sim.scene.simulation.timeStep
    end
--[[
    local res, newPosVelAccel, syncTime = sim.ruckigStep(data.ruckigObj, dt)
    newPosVelAccel = Vector(newPosVelAccel)
    --]]
    local res = data.ruckigObj:step(dt)

    if res >= 0 then
        if res == 0 then
--            data.timeLeft = dt - syncTime
            data.timeLeft = dt - data.ruckigObj:data().syncTime
        end
        --[[
        data.pos = newPosVelAccel:block(1, 1, #data.pos, 1)
        data.vel = newPosVelAccel:block(#data.pos + 1, 1, #data.pos, 1)
        data.accel = newPosVelAccel:block(2 * #data.pos + 1, 1, #data.pos, 1)
        --]]
        data.pos = data.ruckigObj:data().pos
        data.vel = data.ruckigObj:data().vel
        data.accel = data.ruckigObj:data().accel
        if self._callback then
            if self._callback(data) then
                res = 2 -- aborted
            end
        else
            if data.joints then
                for i = 1, #data.joints do
                    if data.joints[i].dynamicallyEnabled then
                        data.joints[i].targetPosition = data.pos[i]
                    else
                        data.joints[i].joint.position = data.pos[i]
                    end
                end
            end
        end
    end

    if res < 0 then
        self:remove()
        error('MoveToConfig step returned error code ' .. res)
    end

    return res
end

function MoveToConfig:remove()
    local data = self._data
    if data and data.ruckigObj then
--        sim.ruckigRemove(data.ruckigObj)
        data.ruckigObj:remove()
        data.ruckigObj = nil
    end
    self._callback = nil
    -- keep data readable! self._data = nil
end

-- ═════════════════════════════════════════════
-- MoveToPose
-- ═════════════════════════════════════════════
local MoveToPose = class('MoveToPose', Motion)

function MoveToPose:initialize(pparams)
    Motion.initialize(self)

    pparams = pparams or {}
    local auxData = pparams.auxData
    pparams.auxData = nil
    local params = copy.deepcopy(pparams) -- do not modify input values
    pparams.auxData = auxData
    params.auxData = auxData
    --params.relObject = params.relObject or -1

    -- Following just to implicitly convert tables to vectors. Arg checking happens further down for historical reasons 
    checkargs.checkfields({funcName = 'MoveToPose:new'}, {
        {name = 'pose', type = 'pose', nullable = true},
        {name = 'object', type = 'handle', nullable = true},
        {name = 'targetPose', type = 'pose', nullable = true},
        {name = 'targetVel', type = 'vector', nullable = true},
        {name = 'metric', type = 'vector', nullable = true},
        {name = 'maxVel', type = 'vector', nullable = true},
        {name = 'minVel', type = 'vector', nullable = true},
        {name = 'maxAccel', type = 'vector', nullable = true},
        {name = 'minAccel', type = 'vector', nullable = true},
        {name = 'maxJerk', type = 'vector', nullable = true},
    }, params)

    --[[
    todo, convert to IK class:
                            <li>ik (map): mandatory if neither pose nor object are specified. Contains IK-relevant informations, if a kinematic chain should move via IK to a target: 
                                <ul> 
                                    <li>tip (handle): specifies the tip object (on the end-effector) </li> 
                                    <li>target (handle): specifies the target object (the object to reach) </li> 
                                    <li>base (handle, defaults to nil): optional. Specifies the base object (the base of the kinematic chain)</li> 
                                    <li>joints (handle[], defaults to all joints within tip and base): optional. Specifies the handles of the joints involved in IK calculations</li> 
                                    <li>method (int, defaults to simIK.method_damped_least_squares): optional. Specifies the resolution method</li> 
                                    <li>damping (float, defaults to 0.02): optional. Specifies the resolution damping</li> 
                                    <li>iterations (int, defaults to 20): optional. Specifies the max. number of iterations</li> 
                                    <li>constraints (int, defaults to simIK.constraint_pose): optional. Specifies the constraints</li> 
                                    <li>precision (int[2], defaults to [0.001, 0.5 * math.pi / 180.0]): optional. Specifies the desired precision (linear and angular)</li> 
                                    <li>allowError (bool, defaults to false): optional. Specifies whether a resolution with precision values over what is allowed will be applied anyway</li> 
                                    <li>breakFlags (int, defaults to 0): optional. Specified the reasons-flags required for simIK.handleGroup to fail</li> 
                                </ul> 
                            </li>
    --]]

    if params.pose then
        if not Pose:ispose(params.pose) then
            error("invalid 'pose' field.")
        end
        params.relObject = nil
        params.object = nil
        params.ik = nil
    else
        if params.object then
            if not sim.Object:isobject(params.object) or not params.object.metaInfo.isSceneObject then
                error("invalid 'object' field.")
            end
            params.pose = params.object:getPose({relativeToObject = params.relObject})
            params.ik = nil
        else
            if params.ik == nil then
                error("missing field: either 'pose', 'object' or 'ik' is required.")
            else
                if type(params.ik) ~= 'table' or ((not sim.Object:isobject(params.ik.tip)) or (not params.ik.tip.metaInfo.isSceneObject)) or ((not sim.Object:isobject(params.ik.target)) or (not params.ik.target.metaInfo.isSceneObject)) then
                    error("invalid 'ik' field, or missing/invalid sub-fields.")
                end
                params.relObject = nil
                params.object = params.ik.target
                params.ik.target:setPose(params.ik.tip:getPose())
                params.pose = params.object:getPose()
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
    params.flags = params.flags | sim1.ruckig_minvel | sim1.ruckig_minaccel
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
        local simIK = require('simIK-1')
        params.ik.breakFlags = params.ik.breakFlags or 0
        params.ik.base = params.ik.base or -1
        params.ik.method = params.ik.method or simIK.method_damped_least_squares
        params.ik.damping = params.ik.damping or 0.02
        params.ik.iterations = params.ik.iterations or 20
        params.ik.constraints = params.ik.constraints or simIK.constraint_pose
        params.ik.precision = params.ik.precision or {0.001, 0.5 * math.pi / 180}
        --params.ik.allowError = params.ik.allowError
        params.ik.ikEnv = simIK.createEnvironment()
        params.ik.ikGroup = simIK.createGroup(params.ik.ikEnv)
        simIK.setGroupCalculation(params.ik.ikEnv, params.ik.ikGroup, params.ik.method, params.ik.damping, params.ik.iterations)
        params.ik.ikElement, params.ik.simToIkMap, params.ik.ikToSimMap = simIK.addElementFromScene(params.ik.ikEnv, params.ik.ikGroup, params.ik.base.handle, params.ik.tip.handle, params.ik.target.handle, params.ik.constraints)
        simIK.setElementPrecision(params.ik.ikEnv, params.ik.ikGroup, params.ik.ikElement, params.ik.precision)
        local hadJoints = params.ik.joints and (#params.ik.joints > 0)
        if not hadJoints then
            params.ik.joints = {}
        end
        for k, v in pairs(params.ik.simToIkMap) do
            k = sim.Object:toobject(k)
            if k.type == 'joint' then
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

    params.startPose = params.pose:copy()

    if type(params.callback) == 'string' then
        params.callback = _G[params.callback]
    end
    self._callback = params.callback
    params.callback = nil

    params.timeLeft = 0
    params.dist = 1.0

    local axis, angle = params.startPose.q:axisangle(params.targetPose.q)
    params.angle = angle

    if params.metric then
        local dx = {
            (params.targetPose.t[1] - params.startPose.t[1]) * params.metric[1],
            (params.targetPose.t[2] - params.startPose.t[2]) * params.metric[2],
            (params.targetPose.t[3] - params.startPose.t[3]) * params.metric[3],
            params.angle * params.metric[4]
        }
        params.dist = math.sqrt(dx[1] * dx[1] + dx[2] * dx[2] + dx[3] * dx[3] + dx[4] * dx[4])
        if params.dist > 0.000001 then
            --[[
            local currentPosVelAccel = {0, params.vel[1], params.accel[1]}
            local maxVelAccelJerk = {params.maxVel[1], params.maxAccel[1], params.maxJerk[1], params.minVel[1], params.minAccel[1]}
            params.ruckigObj = sim.ruckigPos(1, 0.0001, params.flags, currentPosVelAccel, maxVelAccelJerk, {1}, {params.dist, params.targetVel[1]})
            --]]
            local M = require'Motion'
            params.pos = Vector(1, 0.0)
            params.targetPos = Vector(1, params.dist)
            params.selection = table.rep(1, dim)
            params.ruckigObj = M.RuckigPosition:new(params)
            
        end
    else
        local dx = Vector({
            params.targetPose.t[1] - params.startPose.t[1],
            params.targetPose.t[2] - params.startPose.t[2],
            params.targetPose.t[3] - params.startPose.t[3],
            params.angle
        })
        --[[
        local currentPosVelAccel = Vector(dim, 0.0):vertcat(params.vel, params.accel):data()
        local maxVelAccelJerk = params.maxVel:vertcat(params.maxAccel, params.maxJerk, params.minVel, params.minAccel):data()
        local targetPosVel = dx:vertcat(params.targetVel):data()
        params.ruckigObj = sim.ruckigPos(dim, 0.0001, params.flags, currentPosVelAccel, maxVelAccelJerk, table.rep(1, dim), targetPosVel)
        --]]
        local M = require'Motion'
        params.pos = Vector(dim, 0.0)
        params.targetPos = dx
        params.selection = table.rep(1, dim)
        params.ruckigObj = M.RuckigPosition:new(params)
    end

    self._data = params
end

function MoveToPose:step()
    local data = self._data
    if not data then
        error('MoveToPose not initialized or already cleaned up.')
    end

    local res
    local dt = data.timeStep
    if dt == 0 then
        dt = sim.scene.simulation.timeStep
    end

    if data.metric then
        if data.dist > 0.000001 then
            --[[
            local newPosVelAccel, syncTime
            res, newPosVelAccel, syncTime = sim.ruckigStep(data.ruckigObj, dt)
            --]]
            res = data.ruckigObj:step(dt)
            if res >= 0 then
                if res == 0 then
                --    data.timeLeft = dt - syncTime
                    data.timeLeft = dt - data.ruckigObj:data().syncTime
                end
                --[[
                local t = newPosVelAccel[1] / data.dist
                data.vel = Vector{newPosVelAccel[2]}
                data.accel = Vector{newPosVelAccel[3]}
                --]]
                local t = data.ruckigObj:data().pos[1] / data.dist
                data.vel = data.ruckigObj:data().vel
                data.accel = data.ruckigObj:data().accel
                
                data.pose = data.startPose:interp(t, data.targetPose)
                if self._callback then
                    if self._callback(data) then
                        res = 2 -- aborted
                    end
                else
                    if data.object then
                        data.object:setPose(data.pose, {relativeToObject = data.relObject})
                    end
                    if data.ik then
                        local simIK = require('simIK-1')
                        local r, f = simIK.handleGroup(data.ik.ikEnv, data.ik.ikGroup, {syncWorlds = true, allowError = data.ik.allowError})
                        if f & data.ik.breakFlags ~= 0 then
                            self:remove()
                            error('simIK.handleGroup in step returned flags ' .. f)
                        end
                    end
                end
            end
        else
            res = 1
        end
    else
        --[[
        local newPosVelAccel, syncTime
        res, newPosVelAccel, syncTime = sim.ruckigStep(data.ruckigObj, dt)
        --]]
        res = data.ruckigObj:step(dt)
        if res >= 0 then
            if res == 0 then
            --    data.timeLeft = dt - syncTime
                data.timeLeft = dt - data.ruckigObj:data().syncTime
            end
            local t = 0
            --[[
            if math.abs(data.angle) > math.pi * 0.00001 then
                t = newPosVelAccel[4] / data.angle
            end
            data.pose = Pose(data.startPose.t + Vector(table.slice(newPosVelAccel, 1, 3)), data.startPose.q:slerp(t, data.targetPose.q))
            data.vel = Vector(table.slice(newPosVelAccel, 5, 8))
            data.accel = Vector(table.slice(newPosVelAccel, 9, 12))
            --]]
            
            if math.abs(data.angle) > math.pi * 0.00001 then
                t = data.ruckigObj:data().pos[4] / data.angle
            end
            data.pose = Pose(data.startPose.t + data.ruckigObj:data().pos:block(1, 1, 3, 1), data.startPose.q:slerp(t, data.targetPose.q))
            data.vel = data.ruckigObj:data().vel
            data.accel = data.ruckigObj:data().accel
            
            if self._callback then
                if self._callback(data) then
                    res = 2 -- aborted
                end
            else
                if data.object then
                    data.object:setPose(data.pose, {relativeToObject = data.relObject})
                end
                if data.ik then
                    local simIK = require('simIK-1')
                    simIK.handleGroup(data.ik.ikEnv, data.ik.ikGroup, {syncWorlds = true, allowError = data.ik.allowError})
                end
            end
        end
    end

    if res < 0 then
        self:remove()
        error('MoveToPose step returned error code ' .. res)
    end

    return res
end

function MoveToPose:remove()
    local data = self._data
    if data and data.ruckigObj then
    --    sim.ruckigRemove(data.ruckigObj)
        data.ruckigObj:remove()
        data.ruckigObj = nil
    end
    if data and data.ik then
        local simIK = require('simIK-1')
        simIK.eraseEnvironment(data.ik.ikEnv)
        data.ik = nil
    end
    self._callback = nil
    -- keep data readable! self._data = nil
end

-- ═════════════════════════════════════════════
-- TimeOptimalTrajectory
-- ═════════════════════════════════════════════
local TimeOptimalTrajectory = class('TimeOptimalTrajectory')

function TimeOptimalTrajectory:initialize()
    self._script = nil
    self._bla = nil
end

function TimeOptimalTrajectory:generate(params)
    checkargs.checkfields({funcName = "TimeOptimalTrajectory"}, {
        {name = 'pathLengths', type = 'matrix', rows = -1, cols = 1},
    }, params)
    local confCnt = params.pathLengths:rows()
    if confCnt < 2 then
        error("at least 2 configurations must be provided.")
    end
    checkargs.checkfields({funcName = "TimeOptimalTrajectory"}, {
        {name = 'path', type = 'matrix', rows = -1, cols = confCnt},
    }, params)
    local dof = params.path:rows()
    checkargs.checkfields({funcName = "TimeOptimalTrajectory"}, {
        {name = 'maxVel', type = 'matrix', rows = dof, cols = 1},
        {name = 'minVel', type = 'matrix', rows = dof, cols = 1, nullable=true},
        {name = 'maxAccel', type = 'matrix', rows = dof, cols = 1},
        {name = 'minAccel', type = 'matrix', rows = dof, cols = 1, nullable=true},
        {name = 'samples', type = 'int', default=1000},
        {name = 'boundaryCondition', type = 'string', default='not-a-knot'},
    }, params)
    local pM = params.path
    local minVel = params.minVel or params.maxVel * -1.0
    local minAccel = params.minAccel or params.maxAccel * -1.0
    local mmvM = minVel:horzcat(params.maxVel)
    local mmaM = minAccel:horzcat(params.maxAccel)
    sim.self:setStepping(true)
    
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

    -- Reuse or create the Python script
    if not self._script then
        self._script = sim.app:createObject({type = 'detachedScript', ['detachedScript.type'] = 'addon', code = code, language = 'python'})
        self._script.addOnMenuPath = 'Motion:TimeOptimalTrajectory'
        self._script:init()
    end
    
    local toSend = {
        samples = params.samples,
        ss_waypoints = params.pathLengths:data(),
        waypoints = params.path.T:totable(),
        velocity_limits = mmvM:totable(),
        acceleration_limits = mmaM:totable(),
        bc_type = params.boundaryCondition,
    }
    local s, r = pcall(self._script.callFunction, self._script, 'cb', toSend)
    sim.self:setStepping(false)

    if s ~= true then
        error('Failed calling TOPPRA via the generated Python script. Make sure Python is configured for CoppeliaSim, and toppra as well as numpy are installed: ' .. sim.app.defaultPython .. ' -m pip install pyzmq cbor2 psutil numpy toppra.')
    end

    if not r.success then
        error('toppra failed with following message: ' .. r.error)
    end
    return simEigen.Matrix(r.qs[1]).T, simEigen.Matrix(#r.ts, 1, r.ts)
end

function TimeOptimalTrajectory:remove()
    if self._script then
        self._script:remove()
        self._script = nil
    end
end

-- ═════════════════════════════════════════════
-- RuckigPosition
-- ═════════════════════════════════════════════
local RuckigPosition = class('RuckigPosition', Motion)

function RuckigPosition:initialize(pparams)
    Motion.initialize(self)

    pparams = pparams or {}
    local auxData = pparams.auxData
    pparams.auxData = nil
    local params = copy.deepcopy(pparams) -- do not modify input values
    pparams.auxData = auxData
    params.auxData = auxData

    checkargs.checkfields({funcName = "RuckigPosition"}, {
        {name = 'pos', type = 'matrix', rows = -1, cols = 1},
    }, params)
    local dim = params.pos:rows()

    checkargs.checkfields({funcName = "RuckigPosition"}, {
        {name = 'baseCycleTime', type = 'float', default = 0.0001},
        {name = 'timeStep', type = 'float', default = 0.0},
        {name = 'flags', type = 'int', default = -1},
        {name = 'vel', type = 'matrix', rows = dim, cols = 1, default = Vector(dim, 0.0)},
        {name = 'accel', type = 'matrix', rows = dim, cols = 1, default = Vector(dim, 0.0)},
        {name = 'targetPos', type = 'matrix', rows = dim, cols = 1},
        {name = 'targetVel', type = 'matrix', rows = dim, cols = 1, default = Vector(dim, 0.0)},
        {name = 'maxVel', type = 'matrix', rows = dim, cols = 1},
        {name = 'minVel', type = 'matrix', rows = dim, cols = 1, nullable = true},
        {name = 'maxAccel', type = 'matrix', rows = dim, cols = 1},
        {name = 'minAccel', type = 'matrix', rows = dim, cols = 1, nullable = true},
        {name = 'maxJerk', type = 'matrix', rows = dim, cols = 1},
        {name = 'selection', type = 'table', size = dim, item_type = 'int', default = table.rep(1, dim)},
    }, params)

    params.minVel = params.minVel or -params.maxVel
    params.minAccel = params.minAccel or -params.maxAccel
    
    self._ruckigObj = sim1.ruckigPos(dim, params.baseCycleTime, params.flags | sim1.ruckig_minvel | sim1.ruckig_minaccel, params.pos:vertcat(params.vel):vertcat(params.accel):data(),
        params.maxVel:vertcat(params.maxAccel):vertcat(params.maxJerk):vertcat(params.minVel):vertcat(params.minAccel):data(),
        params.selection, params.targetPos:vertcat(params.targetVel):data())

    self._data = params
end

function RuckigPosition:step()
    local data = self._data
    if not data then
        error('RuckigPosition not initialized or already cleaned up.')
    end

    local dt = data.timeStep
    if dt == 0 then
        dt = sim.scene.simulation.timeStep
    end

    local res, newPosVelAccel, syncTime = sim1.ruckigStep(self._ruckigObj, dt)
    newPosVelAccel = Vector(newPosVelAccel)
    local dim = #newPosVelAccel // 3
    data.pos = newPosVelAccel:block(1, 1, dim, 1)
    data.vel = newPosVelAccel:block(dim + 1, 1, dim, 1)
    data.accel = newPosVelAccel:block(2 * dim + 1, 1, dim, 1)
    data.syncTime = syncTime

    return res
end

function RuckigPosition:remove()
    local data = self._data
    if data and data.ruckigObj then
        sim1.ruckigRemove(data.ruckigObj)
        data.ruckigObj = nil
    end
    self._callback = nil
    -- keep data readable! self._data = nil
end

-- ═════════════════════════════════════════════
-- RuckigVelocity
-- ═════════════════════════════════════════════
local RuckigVelocity = class('RuckigVelocity', Motion)

function RuckigVelocity:initialize(pparams)
    Motion.initialize(self)

    pparams = pparams or {}
    local auxData = pparams.auxData
    pparams.auxData = nil
    local params = copy.deepcopy(pparams) -- do not modify input values
    pparams.auxData = auxData
    params.auxData = auxData

    checkargs.checkfields({funcName = "RuckigVelocity"}, {
        {name = 'velocity', type = 'matrix', rows = -1, cols = 1},
    }, params)
    local dim = params.velocity:rows()

    checkargs.checkfields({funcName = "RuckigVelocity"}, {
        {name = 'baseCycleTime', type = 'float', default = 0.0001},
        {name = 'flags', type = 'int', default = -1},
        {name = 'pos', type = 'matrix', rows = dim, cols = 1, default = Vector(dim, 0.0)},
        {name = 'accel', type = 'matrix', rows = dim, cols = 1, default = Vector(dim, 0.0)},
        {name = 'targetVel', type = 'matrix', rows = dim, cols = 1},
        {name = 'maxAccel', type = 'matrix', rows = dim, cols = 1},
        {name = 'minAccel', type = 'matrix', rows = dim, cols = 1, nullable = true},
        {name = 'maxJerk', type = 'matrix', rows = dim, cols = 1},
        {name = 'selection', type = 'table', size = dim, item_type = 'int', default = table.rep(1, dim)},
    }, params)
    
    params.minAccel = params.minAccel or -params.maxAccel
    
    self._ruckigObj = sim1.ruckigVel(dim, params.baseCycleTime, params.flags | sim.ruckig_minaccel, params.pos:vertcat(params.vel):vertcat(params.accel):data(),
        params.maxAccel:vertcat(params.maxJerk):vertcat(params.minAccel):data(),
        params.selection, params.targetVel:data())

    self._data = params
end

function RuckigVelocity:step()
    local data = self._data
    if not data then
        error('RuckigVelocity not initialized or already cleaned up.')
    end

    local dt = data.timeStep
    if dt == 0 then
        dt = sim.scene.simulation.timeStep
    end

    local res, newPosVelAccel, syncTime = sim1.ruckigStep(self._ruckigObj, dt)
    newPosVelAccel = Vector(newPosVelAccel)
    local dim = #newPosVelAccel // 3
    data.pos = newPosVelAccel:block(1, 1, dim, 1)
    data.vel = newPosVelAccel:block(dim + 1, 1, dim, 1)
    data.accel = newPosVelAccel:block(2 * dim + 1, 1, dim, 1)
    data.syncTime = syncTime

    return res
end

function RuckigVelocity:remove()
    local data = self._data
    if data and data.ruckigObj then
        sim1.ruckigRemove(data.ruckigObj)
        data.ruckigObj = nil
    end
    self._callback = nil
    -- keep data readable! self._data = nil
end

return {
    Motion = Motion,
    MoveToConfig = MoveToConfig,
    MoveToPose = MoveToPose,
    RuckigPosition = RuckigPosition,
    RuckigVelocity = RuckigVelocity,
    TimeOptimalTrajectory = TimeOptimalTrajectory,
}
