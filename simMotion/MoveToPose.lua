local sim = require('sim-2')
local sim1 = require('sim-1')
local simIK = require('simIK-1')
local class = require('middleclass')
local checkargs = require('checkargs-2')
local simEigen = require('simEigen')

local Vector = simEigen.Vector
local Pose = simEigen.Pose

local Motion = require('simMotion.Motion')
local RuckigPosition = require('simMotion.RuckigPosition')
local helpers = require('simMotion.helpers')

local pi = math.pi

local MoveToPose = class('MoveToPose', Motion)

function MoveToPose:initialize(pparams)
    Motion.initialize(self)

    local params = helpers.copyParams(pparams)

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
        params.flags = sim.ruckig.phaseSync
    end

    params.flags =
        params.flags |
        sim1.ruckig_minvel |
        sim1.ruckig_minaccel

    if params.minVel == nil then
        params.minVel = Vector(helpers.negateData(params.maxVel:data()))
    elseif type(params.minVel) == 'number' then
        params.minVel = Vector(dim, params.minVel)
    end

    if not Vector:isvector(params.minVel, dim) then
        error("missing or invalid 'minVel' field.")
    end

    if params.minAccel == nil then
        params.minAccel = Vector(helpers.negateData(params.maxAccel:data()))
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
            params.pos = Vector(1, 0.0)
            params.targetPos = Vector(1, params.dist)
            params.selection = {1}

            params.ruckigObj = RuckigPosition:new(params)
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

        params.pos = Vector(dim, 0.0)
        params.targetPos = Vector(targetPosData)
        params.selection = {1, 1, 1, 1}

        params.ruckigObj = RuckigPosition:new(params)
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

            -- The translation follows the Ruckig trajectory directly, while
            -- the rotation is interpolated with the (rotation) progress 't'.
            -- Deriving both from 't' would freeze pure-translation motions,
            -- i.e. when the rotation angle is zero.
            data.pose = Pose(
                data.startPose.t + Vector{rd.pos[1], rd.pos[2], rd.pos[3]},
                data.startPose.q:slerp(t, data.targetPose.q)
            )

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


return MoveToPose
