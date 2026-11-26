local sim = require('sim-2')
local sim1 = require('sim-1')
local class = require('middleclass')
local checkargs = require('checkargs-2')
local simEigen = require('simEigen')

local Vector = simEigen.Vector

local Motion = require('simMotion.Motion')
local helpers = require('simMotion.helpers')

local RuckigPosition = class('RuckigPosition', Motion)

function RuckigPosition:initialize(pparams)
    Motion.initialize(self)

    local params = helpers.copyParams(pparams)

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
            Vector(helpers.negateData(params.maxVel:data()))
    end

    if params.minAccel == nil then
        params.minAccel =
            Vector(helpers.negateData(params.maxAccel:data()))
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
        helpers.concat(
            posData,
            velData,
            accelData
        )

    local maxVelAccelJerk =
        helpers.concat(
            maxVelData,
            maxAccelData,
            maxJerkData,
            minVelData,
            minAccelData
        )

    local targetPosVel =
        helpers.concat(
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
        helpers.splitPosVelAccel(newData, dim)

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


return RuckigPosition
