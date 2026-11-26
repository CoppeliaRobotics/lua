-- simMotion: motion generation classes.
--
-- Various ways to access them:
--   local simMotion = require 'simMotion'             -- module table
--   import 'simMotion'                                -- creates a global 'simMotion'
--   import 'simMotion.*'                              -- classes at global scope (see __all)
--   import 'simMotion', 'MoveToPose'                  -- selective
--   local MoveToPose = require 'simMotion.MoveToPose' -- single class, plus its dependencies
--   sim.MoveToConfig                                  -- also exposed (lazily) by sim-2
--
-- The deprecated 'Motion' module name keeps working (deprecated/Motion.lua
-- returns this module).

local simMotion = {}

-- Class modules, in dependency order:
for _, n in ipairs{'Motion', 'RuckigPosition', 'RuckigVelocity', 'MoveToConfig', 'MoveToPose', 'TimeOptimalTrajectory'} do
    simMotion[n] = require('simMotion.' .. n)
end

-- Names placed at global scope by: import 'simMotion.*'
-- The abstract 'Motion' base class is deliberately not listed here (use
-- simMotion.Motion, or 'import 'simMotion', 'Motion'' if really needed):
-- a global 'Motion' would collide with the deprecated 'Motion' module.
simMotion.__all = {'MoveToConfig', 'MoveToPose', 'RuckigPosition', 'RuckigVelocity', 'TimeOptimalTrajectory'}


function simMotion.unittest()
    local simEigen = require('simEigen')
    local Vector = simEigen.Vector
    local Pose = simEigen.Pose

    local function stepUntilDone(motion, dt, maxSteps)
        maxSteps = maxSteps or 10000

        local res

        for _ = 1, maxSteps do
            res = motion:step(dt)

            if res ~= 0 then
                break
            end
        end

        assert(res ~= nil and res >= 0,
            'motion failed with error code: ' .. tostring(res))

        return motion:data()
    end

    -- class hierarchy:
    assert(simMotion.MoveToConfig.super == simMotion.Motion)
    assert(simMotion.MoveToPose.super == simMotion.Motion)
    assert(simMotion.RuckigPosition.super == simMotion.Motion)
    assert(simMotion.RuckigVelocity.super == simMotion.Motion)

    -- RuckigPosition:
    local m = simMotion.RuckigPosition{
        pos = Vector{0.0, 0.0, 0.0},
        targetPos = Vector{0.4, -0.2, 0.1},
        maxVel = Vector{1.0, 1.0, 1.0},
        maxAccel = Vector{2.0, 2.0, 2.0},
        maxJerk = Vector{20.0, 20.0, 20.0},
    }
    local data = stepUntilDone(m, 0.005)

    assert(#data.pos == 3 and #data.vel == 3 and #data.accel == 3)
    assert(math.abs(data.pos[1] - 0.4) < 0.01 and
        math.abs(data.pos[2] + 0.2) < 0.01 and
        math.abs(data.pos[3] - 0.1) < 0.01)
    m:remove()

    -- RuckigVelocity:
    m = simMotion.RuckigVelocity{
        vel = Vector{0.0},
        targetVel = Vector{0.5},
        maxAccel = Vector{1.0},
        maxJerk = Vector{10.0},
    }
    data = stepUntilDone(m, 0.01)

    assert(#data.pos == 1 and #data.vel == 1 and #data.accel == 1)
    assert(math.abs(data.vel[1] - 0.5) < 0.001)
    m:remove()

    -- MoveToConfig (no joints: only the interpolated data is checked):
    m = simMotion.MoveToConfig{
        pos = {0.0, 0.0},
        targetPos = {1.0, -1.0},
        maxVel = {1.0, 1.0},
        maxAccel = {2.0, 2.0},
        maxJerk = {20.0, 20.0},
    }
    data = stepUntilDone(m, 0.01)

    assert(#data.pos == 2 and #data.vel == 2 and #data.accel == 2)
    assert(math.abs(data.pos[1] - 1.0) < 0.01 and
        math.abs(data.pos[2] + 1.0) < 0.01)
    m:remove()

    -- MoveToPose (no object/IK: only the interpolated pose is checked):
    local targetPose = Pose{0.5, 0.2, 0.0, 0.0, 0.0, 0.7071068, 0.7071068}
    m = simMotion.MoveToPose{
        pose = Pose{0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0},
        targetPose = targetPose,
        maxVel = Vector{1.0, 1.0, 1.0, 1.0},
        maxAccel = Vector{2.0, 2.0, 2.0, 2.0},
        maxJerk = Vector{20.0, 20.0, 20.0, 20.0},
    }
    data = stepUntilDone(m, 0.01)

    assert(Pose:ispose(data.pose))
    assert((data.pose.t - targetPose.t):norm() < 0.01)
    m:remove()

    -- MoveToPose without rotation (pure translation must not stay stuck):
    m = simMotion.MoveToPose{
        pose = Pose{0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0},
        targetPose = Pose{0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0},
        maxVel = Vector{1.0, 1.0, 1.0, 1.0},
        maxAccel = Vector{2.0, 2.0, 2.0, 2.0},
        maxJerk = Vector{20.0, 20.0, 20.0, 20.0},
    }
    data = stepUntilDone(m, 0.01)

    local translated = data.pose.t
    assert(math.abs(translated[1] - 0.5) < 0.01 and
        math.abs(translated[2]) < 0.01 and
        math.abs(translated[3]) < 0.01)
    m:remove()

    print(debug.getinfo(1, 'S').source, 'tests passed')
end


return simMotion
