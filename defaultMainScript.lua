-- This is the main script. The main script is not supposed to be modified,
-- unless there is a very good reason to do it.
-- Without main script, there is no simulation.
sim = require('sim-2')

function sysCall_init()
end

function sysCall_actuation()
    sim.scene:handleSimulationScripts(sim.syscb_actuation)
    sim.scene:handleCustomizationScripts(sim.syscb_actuation)
    sim.app:handleAddOnScripts(sim.syscb_actuation)
    sim.app:handleSandboxScript(sim.syscb_actuation)
    sim.scene:stepKinematicJoints()
    sim.scene.dynamics:step()
end

function sysCall_sensing()
    local proxSensors = sim.scene:getObjects({types = {'proximitySensor'}})
    for i = 1, #proxSensors do
        local s = proxSensors[i]
        if not s.explicitHandling then
            s:handleSensor()
        end
    end
    local visionSensors = sim.scene:getObjects({types = {'visionSensor'}})
    for i = 1, #visionSensors do
        local s = visionSensors[i]
        if not s.explicitHandling then
            s:handleSensor()
        end
    end
    sim.scene:handleSimulationScripts(sim.syscb_sensing)
    sim.scene:handleCustomizationScripts(sim.syscb_sensing)
    sim.app:handleAddOnScripts(sim.syscb_sensing)
    sim.app:handleSandboxScript(sim.syscb_sensing)
end

function sysCall_cleanup()
    sim.scene:handleSimulationScripts(sim.syscb_cleanup)
    local proxSensors = sim.scene:getObjects({types = {'proximitySensor'}})
    for i = 1, #proxSensors do
        local s = proxSensors[i]
        if not s.explicitHandling then
            s:resetSensor()
        end
    end
    local visionSensors = sim.scene:getObjects({types = {'visionSensor'}})
    for i = 1, #visionSensors do
        local s = visionSensors[i]
        if not s.explicitHandling then
            s:resetSensor()
        end
    end
end

function sysCall_suspend()
    sim.scene:handleSimulationScripts(sim.syscb_suspend)
    sim.scene:handleCustomizationScripts(sim.syscb_suspend)
    sim.app:handleAddOnScripts(sim.syscb_suspend)
    sim.app:handleSandboxScript(sim.syscb_suspend)
end

function sysCall_suspended()
    sim.scene:handleSimulationScripts(sim.syscb_suspended)
    sim.scene:handleCustomizationScripts(sim.syscb_suspended)
    sim.app:handleAddOnScripts(sim.syscb_suspended)
    sim.app:handleSandboxScript(sim.syscb_suspended)
end

function sysCall_resume()
    sim.scene:handleSimulationScripts(sim.syscb_resume)
    sim.scene:handleCustomizationScripts(sim.syscb_resume)
    sim.app:handleAddOnScripts(sim.syscb_resume)
    sim.app:handleSandboxScript(sim.syscb_resume)
end

function sysCall_joint(inData)
    if inData.mode == sim.jointmode_kinematic then
        if _S.kinJointMotionData == nil then _S.kinJointMotionData = {} end
        if _S.kinJointMotionData[inData.joint.handle] == nil then
            _S.kinJointMotionData[inData.joint.handle] = {vel = 0, accel = 0}
        end
        local joint = _S.kinJointMotionData[inData.joint.handle]
        if inData.initVel then
            joint.vel = inData.initVel
            joint.accel = 0
        end
        local res, outData = pcall(jointKinematicMotion, joint, inData)
        return outData
    end
end

function jointKinematicMotion(joint, inData)
    local Motion = require'Motion'
    local outData = nil
    local dt = sim.scene.simulation.timeStep
    local p = inData.pos
    if inData.targetPos then
        if ((inData.revolute == true) and (math.abs(inData.error) > 0.01 * math.pi / 180)) or
            ((inData.revolute == false) and (math.abs(inData.error) > 0.0001)) or (joint.vel ~= 0) then
            local params = {
                pos = {p},
                vel = {joint.vel},
                accel = {joint.accel},
                targetPos = {p + inData.error},
                maxVel = {inData.maxVel},
                maxAccel = {inData.maxAccel},
                maxJerk = {inData.maxJerk}
            }
            local motion = Motion.RuckigPosition(params)
            local result = motion:step()
            if result >= 0 then
                local data = motion:data()
                outData = {
                    pos = data.pos[1],
                    vel = data.vel[1],
                    accel = data.accel[1],
                }
                if result == 0 then
                    joint.vel = outData.vel
                    joint.accel = outData.accel
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
            motion:remove()
        end
    else
        if inData.targetVel ~= 0 or joint.vel ~= 0 or joint.accel ~= 0 then
            if inData.targetVel == joint.vel and joint.accel == 0 then
                outData = {pos = p + joint.vel * dt, vel = joint.vel, accel = 0.0}
            else
                local params = {
                    pos = {p},
                    vel = {joint.vel},
                    accel = {joint.accel},
                    targetVel = {inData.targetVel},
                    maxAccel = {inData.maxAccel},
                    maxJerk = {inData.maxJerk}
                }
                local motion = Motion.RuckigVelocity(params)
                local result = motion:step()
                if result >= 0 then
                    local data = motion:data()
                    if result == 0 then
                        outData = {
                            pos = data.pos[1],
                            vel = data.vel[1],
                            accel = data.accel[1],
                        }
                        joint.vel = outData.vel
                        joint.accel = data.accel[1]
                    else
                        outData = {
                            pos = data.pos[1] + joint.vel * -data.syncTime,
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
                motion:remove()
            end
        else
            outData = {immobile = true}
        end
    end
    return outData
end

