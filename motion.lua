local motion = {}

function motion.extend(sim)

function sim.moveToConfig_init(params)
    params = params or {}
    params = table.deepcopy(params) -- do not modify input values
    if params.pos then
        if type(params.pos) ~= 'table' or #params.pos == 0 then
            error("invalid 'pos' field.")
        end
        if params.joints ~= nil and (type(params.joints) ~= 'table' or #params.joints ~= #params.pos) then
            error("invalid 'pos' field.")
        end
    else
        if params.joints == nil then
            error("missing field: either 'pos' or 'joints' is required.")
        else
            if type(params.joints) ~= 'table' or #params.joints == 0 then
                error("invalid 'joints' field.")
            end
            params.pos = {}
            for i = 1, #params.joints do
                params.pos[i] = sim.getJointPosition(params.joints[i])
            end
        end
    end
    local dim = #params.pos
    if params.targetPos == nil or type(params.targetPos) ~= 'table' or #params.targetPos ~= dim then
        error("missing or invalid 'targetPos' field.")
    end
    if params.maxVel ~= nil and (type(params.maxVel) ~= 'table' or #params.maxVel ~= dim) then
        if not params.tolerantArgs or #params.maxVel < dim then
            error("invalid 'maxVel' field.")
        end
    end
    if params.maxAccel ~= nil and (type(params.maxAccel) ~= 'table' or #params.maxAccel ~= dim) then
        if not params.tolerantArgs or #params.maxAccel < dim then
            error("invalid 'maxAccel' field.")
        end
    end
    if params.maxJerk ~= nil and (type(params.maxJerk) ~= 'table' or #params.maxJerk ~= dim) then
        if not params.tolerantArgs or #params.maxJerk < dim then
            error("invalid 'maxJerk' field.")
        end
    end
    if params.maxVel or params.maxAccel or params.maxJerk then
        if params.maxVel == nil then
            error("missing 'maxVel' field.")
        end
        if params.maxAccel == nil then
            error("missing 'maxAccel' field.")
        end
        if params.maxJerk == nil then
            error("missing 'maxJerk' field.")
        end
        params.flags = params.flags or -1
        if params.flags == -1 then params.flags = sim.ruckig_phasesync end
        params.flags = params.flags | sim.ruckig_minvel | sim.ruckig_minaccel
    else
        params.maxVel = params.maxVel or table.rep(9999.0, dim)
        params.maxAccel = params.maxAccel or table.rep(99999.0, dim)
        params.maxJerk = params.maxJerk or table.rep(9999999.0, dim)
        params.flags = sim.ruckig_nosync | sim.ruckig_minvel | sim.ruckig_minaccel
        params.timeStep = 10.0
    end
    params.vel = params.vel or table.rep(0.0, dim)
    params.accel = params.accel or table.rep(0.0, dim)
    params.minVel = params.minVel or map(function(h) return (-h) end, params.maxVel)
    params.minAccel = params.minAccel or map(function(h) return (-h) end, params.maxAccel)
    params.targetVel = params.targetVel or table.rep(0.0, dim)
    params.timeStep = params.timeStep or 0
    if type(params.vel) ~= 'table' or #params.vel ~= dim then
        if not params.tolerantArgs or #params.vel < dim then
            error("missing or invalid 'vel' field.")
        end
    end
    if type(params.accel) ~= 'table' or #params.accel ~= dim then
        if not params.tolerantArgs or #params.accel < dim then
            error("missing or invalid 'accel' field.")
        end
    end
    if type(params.minVel) ~= 'table' or #params.minVel ~= dim then
        if not params.tolerantArgs or #params.minVel < dim then
            error("missing or invalid 'minVel' field.")
        end
    end
    if type(params.minAccel) ~= 'table' or #params.minAccel ~= dim then
        if not params.tolerantArgs or #params.minAccel < dim then
            error("missing or invalid 'minAccel' field.")
        end
    end
    if type(params.targetVel) ~= 'table' or #params.targetVel ~= dim then
        if not params.tolerantArgs or #params.targetVel < dim then
            error("missing or invalid 'targetVel' field.")
        end
    end
    table.slice(params.vel, 1, dim)
    table.slice(params.accel, 1, dim)
    table.slice(params.maxVel, 1, dim)
    table.slice(params.minVel, 1, dim)
    table.slice(params.maxAccel, 1, dim)
    table.slice(params.minAccel, 1, dim)
    table.slice(params.maxJerk, 1, dim)
    table.slice(params.targetVel, 1, dim)

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
    local currentPosVelAccel = table.add(params.pos, params.vel, params.accel)
    local maxVelAccelJerk = table.add(params.maxVel, params.maxAccel, params.maxJerk, params.minVel, params.minAccel)
    local targetPosVel = table.add(params.targetPos, params.targetVel)
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
    if res >= 0 then
        if res == 0 then
            data.timeLeft = dt - syncTime
        end
        for i = 1, #data.pos do
            data.pos[i] = newPosVelAccel[i]
            data.vel[i] = newPosVelAccel[#data.pos + i]
            data.accel[i] = newPosVelAccel[#data.pos * 2 + i]
        end
        local cb = _S.simMoveToConfig_callbacks[data]
        if cb then
            if data.legacyFunc then
                if cb(data.pos, data.vel, data.accel, data.auxData) then
                    res = 2 -- aborted
                end
            else
                if cb(data) then
                    res = 2 -- aborted
                end
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
    
    -- backw. compatibility part:
    -----------------------------
    if type(params) == 'number' then
        params = {}
        local flags, currentPos, currentVel, currentAccel, maxVel, maxAccel, maxJerk, targetPos,
              targetVel, callback, auxData, cyclicJoints, timeStep = checkargs({
            {type = 'int'},
            {type = 'table', item_type = 'float'},
            {type = 'table', item_type = 'float', nullable = true},
            {type = 'table', item_type = 'float', nullable = true},
            {type = 'table', item_type = 'float'},
            {type = 'table', item_type = 'float'},
            {type = 'table', item_type = 'float'},
            {type = 'table', item_type = 'float'},
            {type = 'table', item_type = 'float', nullable = true},
            {type = 'any'},
            {type = 'any', default = NIL, nullable = true},
            {type = 'table', item_type = 'bool', default = NIL, nullable = true},
            {type = 'float', default = 0},
        }, ...)
        params.tolerantArgs = true
        params.flags = flags
        params.pos = currentPos
        params.vel = currentVel
        params.accel = currentAccel
        params.maxVel = table.slice(maxVel, 1, #params.pos)
        params.minVel = map(function(h) return (-h) end, params.maxVel)
        params.maxAccel = table.slice(maxAccel, 1, #params.pos)
        params.minAccel = map(function(h) return (-h) end, params.maxAccel)
        params.maxJerk = maxJerk
        params.targetPos = targetPos
        params.targetVel = targetVel
        params.auxData = auxData
        params.cyclicJoints = cyclicJoints
        params.timeStep = timeStep
        params.callback = callback
        params.legacyFunc = true
        if params.flags >= 0 and (params.flags & sim.ruckig_minvel) ~= 0 then
            params.minVel = table.slice(maxVel, #params.pos + 1)
            params.flags = params.flags - sim.ruckig_minvel
        end
        if params.flags >= 0 and (params.flags & sim.ruckig_minaccel) ~= 0 then
            params.minAccel = table.slice(maxAccel, #params.pos + 1)
            params.flags = params.flags - sim.ruckig_minaccel
        end
    end
    -----------------------------

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
    if data.legacyFunc then
        return outParams.pos, outParams.vel, outParams.accel, outParams.timeLeft -- ret args for backw. comp.
    else
        return outParams
    end
end

function sim.moveToPose_init(params)
    params = params or {}
    params = table.deepcopy(params) -- do not modify input values
    params.relObject = params.relObject or -1
    if params.pose then
        if type(params.pose) ~= 'table' or #params.pose ~= 7 then
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
    
    if params.targetPose == nil or type(params.targetPose) ~= 'table' or #params.targetPose ~= 7 then
        error("missing or invalid 'targetPose' field.")
    end
    local dim = 4
    if params.metric then
        dim = 1
    end

    if params.maxVel ~= nil and (type(params.maxVel) ~= 'table' or #params.maxVel ~= dim) then
        if not params.tolerantArgs or #params.maxVel < dim then
            error("invalid 'maxVel' field.")
        end
    end
    if params.maxAccel ~= nil and (type(params.maxAccel) ~= 'table' or #params.maxAccel ~= dim) then
        if not params.tolerantArgs or #params.maxAccel < dim then
            error("invalid 'maxAccel' field.")
        end
    end
    if params.maxJerk ~= nil and (type(params.maxJerk) ~= 'table' or #params.maxJerk ~= dim) then
        if not params.tolerantArgs or #params.maxJerk < dim then
            error("invalid 'maxJerk' field.")
        end
    end
    if params.maxVel or params.maxAccel or params.maxJerk then
        if params.maxVel == nil then
            error("missing 'maxVel' field.")
        end
        if params.maxAccel == nil then
            error("missing 'maxAccel' field.")
        end
        if params.maxJerk == nil then
            error("missing 'maxJerk' field.")
        end
        params.flags = params.flags or -1
        if params.flags == -1 then params.flags = sim.ruckig_phasesync end
        params.flags = params.flags | sim.ruckig_minvel | sim.ruckig_minaccel
    else
        params.maxVel = params.maxVel or table.rep(9999.0, dim)
        params.maxAccel = params.maxAccel or table.rep(99999.0, dim)
        params.maxJerk = params.maxJerk or table.rep(9999999.0, dim)
        params.flags = sim.ruckig_nosync | sim.ruckig_minvel | sim.ruckig_minaccel
        params.timeStep = 10.0
    end

    params.minVel = params.minVel or map(function(h) return (-h) end, params.maxVel)
    params.minAccel = params.minAccel or map(function(h) return (-h) end, params.maxAccel)
    if type(params.minVel) ~= 'table' or #params.minVel ~= dim then
        error("missing or invalid 'minVel' field.")
    end
    if type(params.minAccel) ~= 'table' or #params.minAccel ~= dim then
        error("missing or invalid 'minAccel' field.")
    end
    
    if params.ik then
        simIK = require('simIK')
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

    params.vel = params.vel or table.rep(0.0, dim)
    params.accel = params.accel or table.rep(0.0, dim)
    params.targetVel = params.targetVel or table.rep(0.0, dim)
    
    params.timeStep = params.timeStep or 0
    table.slice(params.maxVel, 1, dim)
    table.slice(params.minVel, 1, dim)
    table.slice(params.maxAccel, 1, dim)
    table.slice(params.minAccel, 1, dim)
    table.slice(params.maxJerk, 1, dim)

    params.startMatrix = sim.poseToMatrix(params.pose)
    params.targetMatrix = sim.poseToMatrix(params.targetPose)
    params.matrix = table.clone(params.startMatrix)
    
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
            (params.targetMatrix[4] - params.startMatrix[4]) * params.metric[1],
            (params.targetMatrix[8] - params.startMatrix[8]) * params.metric[2],
            (params.targetMatrix[12] - params.startMatrix[12]) * params.metric[3], params.angle * params.metric[4],
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
        local dx = {
            params.targetMatrix[4] - params.startMatrix[4], params.targetMatrix[8] - params.startMatrix[8],
            params.targetMatrix[12] - params.startMatrix[12], params.angle,
        }
        local currentPosVelAccel = table.add(table.rep(0.0, dim), params.vel, params.accel)
        local maxVelAccelJerk = table.add(params.maxVel, params.maxAccel, params.maxJerk, params.minVel, params.minAccel)
        local targetPosVel = table.add(dx, params.targetVel)
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
                data.pose = sim.matrixToPose(data.matrix)
                data.vel = {newPosVelAccel[2]}
                data.accel = {newPosVelAccel[3]}
                local cb = _S.simMoveToPose_callbacks[data]
                if cb then
                    if data.legacyFunc then
                        local arg = data.pose
                        if data.useMatrices then
                            arg = data.matrix
                        end
                        if cb(arg, data.vel, data.accel, data.auxData) then
                            res = 2 -- aborted
                        end
                    else
                        if cb(data) then
                            res = 2 -- aborted
                        end
                    end
                else
                    if data.object then
                        sim.setObjectPose(data.object, data.pose, data.relObject)
                    end
                    if data.ik then
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
            data.matrix[4] = data.startMatrix[4] + newPosVelAccel[1]
            data.matrix[8] = data.startMatrix[8] + newPosVelAccel[2]
            data.matrix[12] = data.startMatrix[12] + newPosVelAccel[3]
            data.pose = sim.matrixToPose(data.matrix)
            data.vel  = table.slice(newPosVelAccel, 5, 8)
            data.accel = table.slice(newPosVelAccel, 9, 12)
            local cb = _S.simMoveToPose_callbacks[data]
            if cb then
                if data.legacyFunc then
                    local arg = data.pose
                    if data.useMatrices then
                        arg = data.matrix
                    end
                    if cb(arg, data.vel, data.accel, data.auxData) then
                        res = 2 -- aborted
                    end
                else
                    if cb(data) then
                        res = 2 -- aborted
                    end
                end
            else
                if data.object then
                    sim.setObjectPose(data.object, data.pose, data.relObject)
                end
                if data.ik then
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
        simIK.eraseEnvironment(data.ik.ikEnv)
        data.ik = nil
    end
end

function sim.moveToPose(...)
    local params = ...
    
    -- backw. compatibility part:
    -----------------------------
    if type(params) == 'number' then
        params = {}
        local flags, currentPoseOrMatrix, maxVel, maxAccel, maxJerk, targetPoseOrMatrix, callback,
              auxData, metric, timeStep = checkargs({
            {type = 'int'},
            {type = 'table', size = '7..12'},
            {type = 'table', item_type = 'float'},
            {type = 'table', item_type = 'float'},
            {type = 'table', item_type = 'float'},
            {type = 'table', size = '7..12'},
            {type = 'any'},
            {type = 'any', default = NIL, nullable = true},
            {type = 'table', size = 4, default = NIL, nullable = true},
            {type = 'float', default = 0},
        }, ...)
        params.tolerantArgs = true
        params.flags = flags
        if #currentPoseOrMatrix == 7 then
            params.pose = currentPoseOrMatrix
        else
            params.pose = sim.matrixToPose(currentPoseOrMatrix)
            params.useMatrices = true
        end
        params.metric = metric
        local dim = 4
        if params.metric then
            dim = 1
        end
        params.maxVel = table.slice(maxVel, 1, dim)
        params.minVel = map(function(h) return (-h) end, params.maxVel)
        params.maxAccel = table.slice(maxAccel, 1, dim)
        params.minAccel = map(function(h) return (-h) end, params.maxAccel)
        params.maxJerk = table.slice(maxJerk, 1, dim)
        if #targetPoseOrMatrix == 7 then
            params.targetPose = targetPoseOrMatrix
        else
            params.targetPose = sim.matrixToPose(targetPoseOrMatrix)
        end
        params.callback = callback
        params.legacyFunc = true
        params.auxData = auxData
        params.timeStep = timeStep

        if params.flags >= 0 and (params.flags & sim.ruckig_minvel) ~= 0 then
            params.minVel = table.slice(maxVel, dim + 1)
            params.flags = params.flags - sim.ruckig_minvel
        end
        if params.flags >= 0 and (params.flags & sim.ruckig_minaccel) ~= 0 then
            params.minAccel = table.slice(maxAccel, dim + 1)
            params.flags = params.flags - sim.ruckig_minaccel
        end
    end
    -----------------------------
    
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
    if data.legacyFunc then
        return outParams.matrix, outParams.timeLeft -- ret args for backw. comp.
    else
        return outParams
    end
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
            {type = 'int', default = NIL, nullable = true},
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
        error('Failed calling TOPPRA via the generated Python script. Make sure Python is configured for CoppeliaSim, and toppra as well as numpy are installed: python -m pip install pyzmq cbor2 numpy toppra.')
    end

    if not r.success then
        error('toppra failed with following message: ' .. r.error)
    end
    return Matrix:fromtable(r.qs[1]):data(), r.ts, script
end

end -- end of motion.extend

return motion
