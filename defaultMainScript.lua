sim = require('sim')
backCompatibility = require('deprecated.defaultMainScriptBackCompatibility')
-- This is the main script. The main script is not supposed to be modified,
-- unless there is a very good reason to do it.
-- Without main script, there is no simulation.

function sysCall_init()
    sim.handleSimulationStart()
    backCompatibility.handle(0)
end

function sysCall_actuation()
    backCompatibility.handle(1)
    sim.handleEmbeddedScripts(sim.syscb_actuation)
    backCompatibility.handle(2)
    sim.handleAddOnScripts(sim.syscb_actuation)
    sim.handleSandboxScript(sim.syscb_actuation)
    sim.handleJointMotion()
    backCompatibility.handle(3)
    sim.handleDynamics(sim.getSimulationTimeStep())
end

function sysCall_sensing()
    sim.handleSensingStart()
    backCompatibility.handle(4)
    sim.handleProximitySensor(sim.handle_all_except_explicit)
    sim.handleVisionSensor(sim.handle_all_except_explicit)
    backCompatibility.handle(5)
    sim.handleEmbeddedScripts(sim.syscb_sensing)
    backCompatibility.handle(6)
    sim.handleAddOnScripts(sim.syscb_sensing)
    sim.handleSandboxScript(sim.syscb_sensing)
    backCompatibility.handle(7)
end

function sysCall_cleanup()
    sim.handleSimulationScripts(sim.syscb_cleanup)
    backCompatibility.handle(8)
    sim.resetProximitySensor(sim.handle_all_except_explicit)
    sim.resetVisionSensor(sim.handle_all_except_explicit)
    backCompatibility.handle(9)
end

function sysCall_suspend()
    sim.handleEmbeddedScripts(sim.syscb_suspend)
    sim.handleAddOnScripts(sim.syscb_suspend)
    sim.handleSandboxScript(sim.syscb_suspend)
end

function sysCall_suspended()
    sim.handleEmbeddedScripts(sim.syscb_suspended)
    sim.handleAddOnScripts(sim.syscb_suspended)
    sim.handleSandboxScript(sim.syscb_suspended)
end

function sysCall_resume()
    sim.handleEmbeddedScripts(sim.syscb_resume)
    sim.handleAddOnScripts(sim.syscb_resume)
    sim.handleSandboxScript(sim.syscb_resume)
end

function sysCall_joint(inData)
    if inData.mode == sim.jointmode_kinematic then
        if _S.kinJointMotionData == nil then _S.kinJointMotionData = {} end
        if _S.kinJointMotionData[inData.handle] == nil then
            _S.kinJointMotionData[inData.handle] = {vel = 0, accel = 0}
        end
        local joint = _S.kinJointMotionData[inData.handle]
        if inData.initVel then
            joint.vel = inData.initVel
            joint.accel = 0
        end
        local res, outData = pcall(jointKinematicMotion, joint, inData)
        return outData
    end
end

function jointKinematicMotion(joint, inData)
    local outData = nil
    local dt = sim.getSimulationTimeStep()
    local p = inData.pos
    if inData.targetPos then
        if ((inData.revolute == true) and (math.abs(inData.error) > 0.01 * math.pi / 180)) or
            ((inData.revolute == false) and (math.abs(inData.error) > 0.0001)) or (joint.vel ~= 0) then
            local rmlObject = sim.ruckigPos(
                                  1, 0.0001, -1, {p, joint.vel, joint.accel},
                                  {inData.maxVel, inData.maxAccel, inData.maxJerk}, {1},
                                  {p + inData.error, 0}
                              )
            local result, newPosVelAccel = sim.ruckigStep(rmlObject, dt)
            if result >= 0 then
                outData = {
                    pos = newPosVelAccel[1],
                    vel = newPosVelAccel[2],
                    accel = newPosVelAccel[3],
                }
                if result == 0 then
                    joint.vel = newPosVelAccel[2]
                    joint.accel = newPosVelAccel[3]
                else
                    joint.vel = 0
                    joint.accel = 0
                    outData = {immobile = true}
                end
            else
                joint.vel = 0
                joint.accel = 0
                outData = {immobile = true}
            end
            sim.ruckigRemove(rmlObject)
        end
    else
        if inData.targetVel ~= 0 or joint.vel ~= 0 or joint.accel ~= 0 then
            if inData.targetVel == joint.vel and joint.accel == 0 then
                outData = {pos = p + joint.vel * dt, vel = joint.vel, accel = 0.0}
            else
                local rmlObject = sim.ruckigVel(
                                      1, 0.0001, -1, {p, joint.vel, joint.accel},
                                      {inData.maxAccel, inData.maxJerk}, {1}, {inData.targetVel}
                                  )
                local result, newPosVelAccel, sync = sim.ruckigStep(rmlObject, dt)
                if result >= 0 then
                    if result == 0 then
                        outData = {
                            pos = newPosVelAccel[1],
                            vel = newPosVelAccel[2],
                            accel = newPosVelAccel[3],
                        }
                        joint.vel = newPosVelAccel[2]
                        joint.accel = newPosVelAccel[3]
                    else
                        local ddt = -sync -- vel. reached, we have some residual time
                        outData = {
                            pos = newPosVelAccel[1] + joint.vel * ddt,
                            vel = inData.targetVel,
                            accel = 0.0,
                        }
                        joint.vel = inData.targetVel
                        joint.accel = 0
                    end
                else
                    joint.vel = inData.targetVel
                    joint.accel = 0
                end
                sim.ruckigRemove(rmlObject)
            end
        else
            outData = {immobile = true}
        end
    end
    return outData
end

