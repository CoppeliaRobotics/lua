local sim = require('sim-2')
local sim1 = require('sim-1')
local class = require('middleclass')
local checkargs = require('checkargs-2')
local simEigen = require('simEigen')

local Vector = simEigen.Vector

local Motion = require('simMotion.Motion')
local RuckigPosition = require('simMotion.RuckigPosition')
local helpers = require('simMotion.helpers')

local pi = math.pi
local twoPi = 2 * pi

local MoveToConfig = class('MoveToConfig', Motion)

function MoveToConfig:initialize(pparams)
    Motion.initialize(self)

    local params = helpers.copyParams(pparams)

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
        params.flags = sim.ruckig.phaseSync
    end

    params.flags =
        params.flags |
        sim1.ruckig_minvel |
        sim1.ruckig_minaccel

    params.vel = params.vel or Vector(dim, 0.0)
    params.accel = params.accel or Vector(dim, 0.0)

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

    params.ruckigObj = RuckigPosition:new(params)

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


return MoveToConfig
