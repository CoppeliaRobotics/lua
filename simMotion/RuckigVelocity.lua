local sim = require('sim-2')
local sim1 = require('sim-1')
local class = require('middleclass')
local checkargs = require('checkargs-2')
local simEigen = require('simEigen')

local Vector = simEigen.Vector

local Motion = require('simMotion.Motion')
local helpers = require('simMotion.helpers')

local RuckigVelocity = class('RuckigVelocity', Motion)

function RuckigVelocity:initialize(pparams)
    Motion.initialize(self)

    local params = helpers.copyParams(pparams)

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
            Vector(helpers.negateData(params.maxAccel:data()))
    end

    local posData = params.pos:data()
    local velData = params.vel:data()
    local accelData = params.accel:data()

    local maxAccelData = params.maxAccel:data()
    local maxJerkData = params.maxJerk:data()
    local minAccelData = params.minAccel:data()

    local targetVelData = params.targetVel:data()

    local currentPosVelAccel =
        helpers.concat(
            posData,
            velData,
            accelData
        )

    local maxAccelJerk =
        helpers.concat(
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
        helpers.splitPosVelAccel(newData, dim)

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


return RuckigVelocity
