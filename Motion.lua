local sim = require('sim-2')
local sim1 = require('sim-1')
local simIK = require('simIK-1')
local class = require('middleclass')
local checkargs = require('checkargs-2')
local copy = require('copy')
local simEigen = require('simEigen')

local Vector = simEigen.Vector
local Matrix = simEigen.Matrix
local Quaternion = simEigen.Quaternion
local Pose = simEigen.Pose


-- ═════════════════════════════════════════════
-- Helpers
-- ═════════════════════════════════════════════

local pi = math.pi
local twoPi = 2 * pi


-- Concatenates several flat Lua arrays.
-- Used instead of Matrix/Vector:vertcat().
local function concatArrays(...)
    local arrays = {...}
    local result = {}
    local k = 1

    for i = 1, #arrays do
        local a = arrays[i]
        for j = 1, #a do
            result[k] = a[j]
            k = k + 1
        end
    end

    return result
end


local function concat2(a, b)
    local na = #a
    local nb = #b
    local result = {}

    for i = 1, na do
        result[i] = a[i]
    end

    for i = 1, nb do
        result[na + i] = b[i]
    end

    return result
end


local function concat3(a, b, c)
    local na = #a
    local nb = #b
    local nc = #c
    local result = {}

    for i = 1, na do
        result[i] = a[i]
    end

    for i = 1, nb do
        result[na + i] = b[i]
    end

    local offset = na + nb
    for i = 1, nc do
        result[offset + i] = c[i]
    end

    return result
end


local function concat5(a, b, c, d, e)
    local result = {}
    local k = 1

    for i = 1, #a do
        result[k] = a[i]
        k = k + 1
    end

    for i = 1, #b do
        result[k] = b[i]
        k = k + 1
    end

    for i = 1, #c do
        result[k] = c[i]
        k = k + 1
    end

    for i = 1, #d do
        result[k] = d[i]
        k = k + 1
    end

    for i = 1, #e do
        result[k] = e[i]
        k = k + 1
    end

    return result
end


local function negateData(a)
    local result = {}

    for i = 1, #a do
        result[i] = -a[i]
    end

    return result
end


-- Extracts the three consecutive Ruckig sections without creating
-- Matrix/Vector temporaries.
local function splitPosVelAccel(data, dim)
    local pos = {}
    local vel = {}
    local accel = {}

    local offset1 = dim
    local offset2 = dim * 2

    for i = 1, dim do
        pos[i] = data[i]
        vel[i] = data[offset1 + i]
        accel[i] = data[offset2 + i]
    end

    return pos, vel, accel
end


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

    local params = copy.deepcopy(pparams)

    pparams.auxData = auxData
    params.auxData = auxData

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

        if params.joints ~= nil and
            (type(params.joints) ~= 'table' or #params.joints ~= #params.pos) then
            error("invalid 'joints' field.")
        end
    else
        if params.joints == nil then
            error("missing field: either 'pos' or 'joints' is required.")
        end

        if type(params.joints) ~= 'table' or #params.joints == 0 then
            error("invalid 'joints' field.")
        end

        local joints = params.joints
        local dim = #joints

        params.pos = Vector(dim, 0.0)

        for i = 1, dim do
            params.pos[i] = joints[i].joint.position
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

    if params.flags == -1 then
        params.flags = sim.ruckig_phasesync
    end

    params.flags =
        params.flags |
        sim1.ruckig_minvel |
        sim1.ruckig_minaccel

    params.vel = params.vel or Vector(dim, 0.0)
    params.accel = params.accel or Vector(dim, 0.0)

    if params.minVel == nil then
        params.minVel = Vector(negateData(params.maxVel:data()))
    elseif type(params.minVel) == 'number' then
        params.minVel = Vector(dim, params.minVel)
    end

    if not Vector:isvector(params.minVel, dim) then
        error("missing or invalid 'minVel' field.")
    end

    if params.minAccel == nil then
        params.minAccel = Vector(negateData(params.maxAccel:data()))
    elseif type(params.minAccel) == 'number' then
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

    local cyclicJoints = params.cyclicJoints

    if cyclicJoints then
        for i = 1, dim do
            if cyclicJoints[i] then
                local v = params.pos[i]
                local w = params.targetPos[i]
                local d = w - v

                while d >= twoPi do
                    w = w - twoPi
                    d = d - twoPi
                end

                while d < 0 do
                    w = w + twoPi
                    d = d + twoPi
                end

                if d > pi then
                    w = w - twoPi
                end

                params.targetPos[i] = w
            end
        end
    end

    local M = require 'Motion'
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

    local res = data.ruckigObj:step(dt)

    if res >= 0 then
        local ruckigData = data.ruckigObj:data()

        if res == 0 then
            data.timeLeft = dt - ruckigData.syncTime
        end

        -- These are now flat Lua tables:
        data.pos = ruckigData.pos
        data.vel = ruckigData.vel
        data.accel = ruckigData.accel

        if self._callback then
            if self._callback(data) then
                res = 2
            end
        else
            local joints = data.joints

            if joints then
                local pos = data.pos

                for i = 1, #joints do
                    local joint = joints[i]

                    if joint.dynamicallyEnabled then
                        joint.targetPosition = pos[i]
                    else
                        joint.joint.position = pos[i]
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
        data.ruckigObj:remove()
        data.ruckigObj = nil
    end

    self._callback = nil
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

    local params = copy.deepcopy(pparams)

    pparams.auxData = auxData
    params.auxData = auxData

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

    if params.pose then
        if not Pose:ispose(params.pose) then
            error("invalid 'pose' field.")
        end

        params.relObject = nil
        params.object = nil
        params.ik = nil
    else
        if params.object then
            if not sim.Object:isobject(params.object) or
                not params.object.metaInfo.isSceneObject then
                error("invalid 'object' field.")
            end

            params.pose = params.object:getPose({
                relativeToObject = params.relObject
            })

            params.ik = nil
        else
            if params.ik == nil then
                error("missing field: either 'pose', 'object' or 'ik' is required.")
            end

            if type(params.ik) ~= 'table' or
                not sim.Object:isobject(params.ik.tip) or
                not params.ik.tip.metaInfo.isSceneObject or
                not sim.Object:isobject(params.ik.target) or
                not params.ik.target.metaInfo.isSceneObject then
                error("invalid 'ik' field, or missing/invalid sub-fields.")
            end

            params.relObject = nil
            params.object = params.ik.target

            params.ik.target:setPose(params.ik.tip:getPose())
            params.pose = params.object:getPose()
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

    if params.flags == -1 then
        params.flags = sim.ruckig_phasesync
    end

    params.flags =
        params.flags |
        sim1.ruckig_minvel |
        sim1.ruckig_minaccel

    if params.minVel == nil then
        params.minVel = Vector(negateData(params.maxVel:data()))
    elseif type(params.minVel) == 'number' then
        params.minVel = Vector(dim, params.minVel)
    end

    if not Vector:isvector(params.minVel, dim) then
        error("missing or invalid 'minVel' field.")
    end

    if params.minAccel == nil then
        params.minAccel = Vector(negateData(params.maxAccel:data()))
    elseif type(params.minAccel) == 'number' then
        params.minAccel = Vector(dim, params.minAccel)
    end

    if not Vector:isvector(params.minAccel, dim) then
        error("missing or invalid 'minAccel' field.")
    end

    if params.ik then
        local ik = params.ik

        ik.breakFlags = ik.breakFlags or 0
        ik.base = ik.base or -1
        ik.method = ik.method or simIK.method_damped_least_squares
        ik.damping = ik.damping or 0.02
        ik.iterations = ik.iterations or 20
        ik.constraints = ik.constraints or simIK.constraint_pose
        ik.precision = ik.precision or {
            0.001,
            0.5 * pi / 180
        }

        ik.ikEnv = simIK.createEnvironment()
        ik.ikGroup = simIK.createGroup(ik.ikEnv)

        simIK.setGroupCalculation(
            ik.ikEnv,
            ik.ikGroup,
            ik.method,
            ik.damping,
            ik.iterations
        )

        ik.ikElement,
        ik.simToIkMap,
        ik.ikToSimMap =
            simIK.addElementFromScene(
                ik.ikEnv,
                ik.ikGroup,
                ik.base.handle,
                ik.tip.handle,
                ik.target.handle,
                ik.constraints
            )

        simIK.setElementPrecision(
            ik.ikEnv,
            ik.ikGroup,
            ik.ikElement,
            ik.precision
        )

        local hadJoints = ik.joints and #ik.joints > 0

        if not hadJoints then
            ik.joints = {}
        end

        local joints = ik.joints

        for k, v in pairs(ik.simToIkMap) do
            local object = sim.Object:toobject(k)

            if object.type == 'joint' then
                if hadJoints then
                    local found = false

                    for i = 1, #joints do
                        if joints[i] == object then
                            found = true
                            break
                        end
                    end

                    if not found then
                        simIK.setJointMode(
                            ik.ikEnv,
                            v,
                            simIK.jointmode_passive
                        )
                    end
                else
                    joints[#joints + 1] = object
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

    local _, angle =
        params.startPose.q:axisangle(params.targetPose.q)

    params.angle = angle

    if params.metric then
        local st = params.startPose.t
        local tt = params.targetPose.t
        local metric = params.metric

        local dx = (tt[1] - st[1]) * metric[1]
        local dy = (tt[2] - st[2]) * metric[2]
        local dz = (tt[3] - st[3]) * metric[3]
        local da = angle * metric[4]

        params.dist = math.sqrt(
            dx * dx +
            dy * dy +
            dz * dz +
            da * da
        )

        if params.dist > 0.000001 then
            local M = require 'Motion'

            params.pos = Vector(1, 0.0)
            params.targetPos = Vector(1, params.dist)
            params.selection = {1}

            params.ruckigObj = M.RuckigPosition:new(params)
        end
    else
        local st = params.startPose.t
        local tt = params.targetPose.t

        -- No temporary Vector here:
        local targetPosData = {
            tt[1] - st[1],
            tt[2] - st[2],
            tt[3] - st[3],
            angle
        }

        local M = require 'Motion'

        params.pos = Vector(dim, 0.0)
        params.targetPos = Vector(targetPosData)
        params.selection = {1, 1, 1, 1}

        params.ruckigObj = M.RuckigPosition:new(params)
    end

    self._data = params
end


function MoveToPose:step()
    local data = self._data

    if not data then
        error('MoveToPose not initialized or already cleaned up.')
    end

    local dt = data.timeStep

    if dt == 0 then
        dt = sim.scene.simulation.timeStep
    end

    local res

    if data.metric then
        if data.dist > 0.000001 then
            res = data.ruckigObj:step(dt)

            if res >= 0 then
                local rd = data.ruckigObj:data()

                if res == 0 then
                    data.timeLeft = dt - rd.syncTime
                end

                local t = rd.pos[1] / data.dist

                -- Flat tables:
                data.vel = rd.vel
                data.accel = rd.accel

                -- interp() creates the required final Pose directly.
                -- No intermediate Vector/Matrix concatenations.
                data.pose =
                    data.startPose:interp(t, data.targetPose)

                if self._callback then
                    if self._callback(data) then
                        res = 2
                    end
                else
                    if data.object then
                        data.object:setPose(
                            data.pose,
                            {relativeToObject = data.relObject}
                        )
                    end

                    if data.ik then
                        local ik = data.ik

                        local _, flags =
                            simIK.handleGroup(
                                ik.ikEnv,
                                ik.ikGroup,
                                {
                                    syncWorlds = true,
                                    allowError = ik.allowError
                                }
                            )

                        if flags & ik.breakFlags ~= 0 then
                            self:remove()

                            error(
                                'simIK.handleGroup in step returned flags ' ..
                                flags
                            )
                        end
                    end
                end
            end
        else
            res = 1
        end
    else
        res = data.ruckigObj:step(dt)

        if res >= 0 then
            local rd = data.ruckigObj:data()

            if res == 0 then
                data.timeLeft = dt - rd.syncTime
            end

            local t = 0.0

            if math.abs(data.angle) > pi * 0.00001 then
                t = rd.pos[4] / data.angle
            end

            data.vel = rd.vel
            data.accel = rd.accel

            -- The translation is implicitly interpolated by Pose:interp().
            -- This replaces:
            --
            -- startPose.t + Vector(...):block(...)
            --
            data.pose =
                data.startPose:interp(t, data.targetPose)

            if self._callback then
                if self._callback(data) then
                    res = 2
                end
            else
                if data.object then
                    data.object:setPose(
                        data.pose,
                        {relativeToObject = data.relObject}
                    )
                end

                if data.ik then
                    local ik = data.ik

                    simIK.handleGroup(
                        ik.ikEnv,
                        ik.ikGroup,
                        {
                            syncWorlds = true,
                            allowError = ik.allowError
                        }
                    )
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
        data.ruckigObj:remove()
        data.ruckigObj = nil
    end

    if data and data.ik then
        simIK.eraseEnvironment(data.ik.ikEnv)
        data.ik = nil
    end

    self._callback = nil
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
        {name = 'minVel', type = 'matrix', rows = dof, cols = 1, nullable = true},
        {name = 'maxAccel', type = 'matrix', rows = dof, cols = 1},
        {name = 'minAccel', type = 'matrix', rows = dof, cols = 1, nullable = true},
        {name = 'samples', type = 'int', default = 1000},
        {name = 'boundaryCondition', type = 'string', default = 'not-a-knot'},
    }, params)

    local maxVel = params.maxVel:data()
    local maxAccel = params.maxAccel:data()

    local minVel =
        params.minVel and
        params.minVel:data() or
        negateData(maxVel)

    local minAccel =
        params.minAccel and
        params.minAccel:data() or
        negateData(maxAccel)

    -- Direct construction instead of horzcat().
    local velocityLimits = {}
    local accelerationLimits = {}

    for i = 1, dof do
        velocityLimits[i] = {
            minVel[i],
            maxVel[i]
        }

        accelerationLimits[i] = {
            minAccel[i],
            maxAccel[i]
        }
    end

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

def cbb(req):
    coefficients = ta.SplineInterpolator(
        req['ss_waypoints'],
        req['waypoints'],
        req.get('bc_type', 'not-a-knot')
    )

    pc_vel = constraint.JointVelocityConstraint(
        req['velocity_limits']
    )

    pc_acc = constraint.JointAccelerationConstraint(
        req['acceleration_limits'],
        discretization_scheme=constraint.DiscretizationType.Interpolation
    )

    instance = algo.TOPPRA(
        [pc_vel, pc_acc],
        coefficients,
        solver_wrapper='seidel'
    )

    jnt_traj = instance.compute_trajectory(0, 0)

    duration = jnt_traj.duration
    n = coefficients.dof

    resp = dict(
        qs=[[] for _ in range(n)],
        qds=[[] for _ in range(n)],
        qdds=[[] for _ in range(n)]
    )

    ts = np.linspace(
        0,
        duration,
        req.get('samples', 100)
    )

    # Evaluate each quantity only once:
    qs = jnt_traj.eval(ts)
    qds = jnt_traj.evald(ts)
    qdds = jnt_traj.evaldd(ts)

    for i in range(n):
        resp['qs'][i] = qs[:, i].tolist()
        resp['qds'][i] = qds[:, i].tolist()
        resp['qdds'][i] = qdds[:, i].tolist()

    resp['ts'] = ts.tolist()

    return resp
]=]

    if not self._script then
        self._script =
            sim.app:createObject({
                type = 'detachedScript',
                ['detachedScript.type'] = 'addon',
                code = code,
                language = 'python'
            })

        self._script.addOnMenuPath =
            'Motion:TimeOptimalTrajectory'

        self._script:init()
    end

    local toSend = {
        samples = params.samples,
        ss_waypoints = params.pathLengths:data(),

        -- This conversion is only needed at the Lua/Python boundary:
        waypoints = params.path.T:totable(),

        velocity_limits = velocityLimits,
        acceleration_limits = accelerationLimits,

        bc_type = params.boundaryCondition,
    }

    local success, result =
        pcall(
            self._script.callFunction,
            self._script,
            'cb',
            toSend
        )

    sim.self:setStepping(false)

    if success ~= true then
        error(
            'Failed calling TOPPRA via the generated Python script. ' ..
            'Make sure Python is configured for CoppeliaSim, and toppra as well as numpy are installed: ' ..
            sim.app.defaultPython ..
            ' -m pip install pyzmq cbor2 psutil numpy toppra.'
        )
    end

    if not result.success then
        error(
            'toppra failed with following message: ' ..
            result.error
        )
    end

    return
        simEigen.Matrix(result.qs[1]).T,
        simEigen.Matrix(#result.ts, 1, result.ts)
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

    local params = copy.deepcopy(pparams)

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

        {name = 'vel', type = 'matrix', rows = dim, cols = 1,
            default = Vector(dim, 0.0)},

        {name = 'accel', type = 'matrix', rows = dim, cols = 1,
            default = Vector(dim, 0.0)},

        {name = 'targetPos', type = 'matrix', rows = dim, cols = 1},

        {name = 'targetVel', type = 'matrix', rows = dim, cols = 1,
            default = Vector(dim, 0.0)},

        {name = 'maxVel', type = 'matrix', rows = dim, cols = 1},

        {name = 'minVel', type = 'matrix', rows = dim, cols = 1,
            nullable = true},

        {name = 'maxAccel', type = 'matrix', rows = dim, cols = 1},

        {name = 'minAccel', type = 'matrix', rows = dim, cols = 1,
            nullable = true},

        {name = 'maxJerk', type = 'matrix', rows = dim, cols = 1},

        {name = 'selection', type = 'table', size = dim,
            item_type = 'int', default = table.rep(1, dim)},
    }, params)

    if params.minVel == nil then
        params.minVel =
            Vector(negateData(params.maxVel:data()))
    end

    if params.minAccel == nil then
        params.minAccel =
            Vector(negateData(params.maxAccel:data()))
    end

    local posData = params.pos:data()
    local velData = params.vel:data()
    local accelData = params.accel:data()

    local maxVelData = params.maxVel:data()
    local maxAccelData = params.maxAccel:data()
    local maxJerkData = params.maxJerk:data()
    local minVelData = params.minVel:data()
    local minAccelData = params.minAccel:data()

    local targetPosData = params.targetPos:data()
    local targetVelData = params.targetVel:data()

    -- All Ruckig inputs are directly built as flat arrays:
    local currentPosVelAccel =
        concat3(
            posData,
            velData,
            accelData
        )

    local maxVelAccelJerk =
        concat5(
            maxVelData,
            maxAccelData,
            maxJerkData,
            minVelData,
            minAccelData
        )

    local targetPosVel =
        concat2(
            targetPosData,
            targetVelData
        )

    self._ruckigObj =
        sim1.ruckigPos(
            dim,
            params.baseCycleTime,

            params.flags |
                sim1.ruckig_minvel |
                sim1.ruckig_minaccel,

            currentPosVelAccel,
            maxVelAccelJerk,
            params.selection,
            targetPosVel
        )

    self._data = params
end


function RuckigPosition:step(timeStep)
    local data = self._data

    if not data then
        error('RuckigPosition not initialized or already cleaned up.')
    end

    local dt = timeStep or data.timeStep

    if dt == 0 then
        dt = sim.scene.simulation.timeStep
    end

    local res, newData, syncTime =
        sim1.ruckigStep(
            self._ruckigObj,
            dt
        )

    local dim = #newData // 3

    -- Keep all output as ordinary flat Lua tables:
    local pos, vel, accel =
        splitPosVelAccel(newData, dim)

    data.pos = pos
    data.vel = vel
    data.accel = accel
    data.syncTime = syncTime

    return res
end


function RuckigPosition:remove()
    if self._ruckigObj then
        sim1.ruckigRemove(self._ruckigObj)
        self._ruckigObj = nil
    end

    self._callback = nil
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

    local params = copy.deepcopy(pparams)

    pparams.auxData = auxData
    params.auxData = auxData

    checkargs.checkfields({funcName = "RuckigVelocity"}, {
        {name = 'vel', type = 'matrix', rows = -1, cols = 1},
    }, params)

    local dim = params.vel:rows()

    checkargs.checkfields({funcName = "RuckigVelocity"}, {
        {name = 'baseCycleTime', type = 'float', default = 0.0001},
        {name = 'timeStep', type = 'float', default = 0.0},
        {name = 'flags', type = 'int', default = -1},

        {name = 'pos', type = 'matrix', rows = dim, cols = 1,
            default = Vector(dim, 0.0)},

        {name = 'accel', type = 'matrix', rows = dim, cols = 1,
            default = Vector(dim, 0.0)},

        {name = 'targetVel', type = 'matrix', rows = dim, cols = 1},

        {name = 'maxAccel', type = 'matrix', rows = dim, cols = 1},

        {name = 'minAccel', type = 'matrix', rows = dim, cols = 1,
            nullable = true},

        {name = 'maxJerk', type = 'matrix', rows = dim, cols = 1},

        {name = 'selection', type = 'table', size = dim,
            item_type = 'int', default = table.rep(1, dim)},
    }, params)

    if params.minAccel == nil then
        params.minAccel =
            Vector(negateData(params.maxAccel:data()))
    end

    local posData = params.pos:data()
    local velData = params.vel:data()
    local accelData = params.accel:data()

    local maxAccelData = params.maxAccel:data()
    local maxJerkData = params.maxJerk:data()
    local minAccelData = params.minAccel:data()

    local targetVelData = params.targetVel:data()

    local currentPosVelAccel =
        concat3(
            posData,
            velData,
            accelData
        )

    local maxAccelJerk =
        concat3(
            maxAccelData,
            maxJerkData,
            minAccelData
        )

    self._ruckigObj =
        sim1.ruckigVel(
            dim,
            params.baseCycleTime,

            params.flags |
                sim1.ruckig_minaccel,

            currentPosVelAccel,
            maxAccelJerk,
            params.selection,
            targetVelData
        )

    self._data = params
end


function RuckigVelocity:step(timeStep)
    local data = self._data

    if not data then
        error('RuckigVelocity not initialized or already cleaned up.')
    end

    local dt = timeStep or data.timeStep

    if dt == 0 then
        dt = sim.scene.simulation.timeStep
    end

    local res, newData, syncTime =
        sim1.ruckigStep(
            self._ruckigObj,
            dt
        )

    local dim = #newData // 3

    -- No Vector construction and no Matrix:block() calls:
    local pos, vel, accel =
        splitPosVelAccel(newData, dim)

    data.pos = pos
    data.vel = vel
    data.accel = accel
    data.syncTime = syncTime

    return res
end


function RuckigVelocity:remove()
    if self._ruckigObj then
        sim1.ruckigRemove(self._ruckigObj)
        self._ruckigObj = nil
    end

    self._callback = nil
end


return {
    Motion = Motion,
    MoveToConfig = MoveToConfig,
    MoveToPose = MoveToPose,
    RuckigPosition = RuckigPosition,
    RuckigVelocity = RuckigVelocity,
    TimeOptimalTrajectory = TimeOptimalTrajectory,
}
