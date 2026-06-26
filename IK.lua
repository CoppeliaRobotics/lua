local simIK = loadPlugin('simIK')
local simEigen = require'simEigen'
local class = require('middleclass')
local sim = require('sim')
local sim2 = require('sim-2')
local checkargs = require('checkargs-2')

-- module-level bookkeeping that is genuinely cross-cutting (set elsewhere, e.g. python bindings):
local __ = {}

--==================================================================
-- internal (env is passed explicitly because these are pure helpers)
--==================================================================

local function _loopThroughAltConfigSolutions(ikEnv, jointHandles, desiredPose, confS, x, index)
    if index > #jointHandles then
        return {sim.unpackDoubleTable(sim.packDoubleTable(confS))} -- copy the table
    else
        local c = {}
        for i = 1, #jointHandles do c[i] = confS[i] end
        local solutions = {}
        while c[index] <= x[index][2] do
            local s = _loopThroughAltConfigSolutions(ikEnv, jointHandles, desiredPose, c, x, index + 1)
            for i = 1, #s do solutions[#solutions + 1] = s[i] end
            c[index] = c[index] + math.pi * 2
        end
        return solutions
    end
end

local function _getAltConfigsImpl(ikEnv, jointHandles, inputConfig)
    local retVal = {}
    local x = {}
    local confS = {}
    local err = false
    for i = 1, #jointHandles do
        local c, interv = simIK.getJointInterval(ikEnv, jointHandles[i])
        local t = simIK.getJointType(ikEnv, jointHandles[i])
        local sp = simIK.getJointScrewLead(ikEnv, jointHandles[i])
        if t == simIK.jointtype_revolute and not c then
            if sp == 0 then
                if inputConfig[i] - math.pi * 2 >= interv[1] or inputConfig[i] + math.pi * 2 <=
                    interv[1] + interv[2] then
                    local y = inputConfig[i]
                    while y - math.pi * 2 >= interv[1] do y = y - math.pi * 2 end
                    x[i] = {y, interv[1] + interv[2]}
                end
            end
        end
        if not x[i] then
            x[i] = {inputConfig[i], inputConfig[i]}
        end
        confS[i] = x[i][1]
    end
    local configs = {}
    if not err then
        local desiredPose = 0
        configs = _loopThroughAltConfigSolutions(ikEnv, jointHandles, desiredPose, confS, x, 1)
    end
    -- Exclude the input config:
    for j = 1, #configs do
        local distSq = 0.0
        for i = 1, #inputConfig do
            local d = inputConfig[i] - configs[j][i]
            distSq = distSq + d * d
        end
        if distSq < 0.1 then
            table.remove(configs, j)
            break
        end
    end
    return configs
end

function simIK._getObjectPose(env, handle, rel)
    rel = rel or simIK.handle_world
    local p, q = simIK.getObjectTransformation(env, handle, rel)
    return {p[1], p[2], p[3], q[1], q[2], q[3], q[4]}
end

function simIK:_setObjectPose(env, handle, p, rel)
    rel = rel or simIK.handle_world
    return simIK.setObjectTransformation(env, handle, {p[1], p[2], p[3]}, {p[4], p[5], p[6], p[7]}, rel)
end


--==================================================================
-- IK element class
--==================================================================
local IKElement = class('IKElement')

function IKElement:initialize(ik, group, elementHandle, simToIkMap, ikToSimMap, opt)
    self._ik = ik
    self._group = group
    self.handle = elementHandle
    self.simToIkMap = simToIkMap
    self.ikToSimMap = ikToSimMap
    self._opt = {}
    
    -- Defaults:
    self._opt.constraints = 0
    self._opt.enabled = true
    self._opt.precision = {0.0005, 0.001745}
    self._opt.weights = {1.0, 1.0, 1.0}
    
    self:update(opt)
end

function IKElement:update(opt)
    opt = opt or {}

    for k, v in pairs(self._opt) do
        if opt[k] == nil then
            opt[k] = v
        end
    end
    
    for k, v in pairs(opt) do
        if self._opt[k] == nil then
            sim2.app:logWarn("unrecognized option '" .. k .. "'.\n" .. debug.traceback())
        end
    end
    
    checkargs.checkfields({funcName = 'update'}, {
        {name = 'precision', type = 'table', size = 2, itemType = 'float', nullable = true},
        {name = 'weights', type = 'table', size = 3, itemType = 'float', nullable = true},
        {name = 'constraints', type = 'int', nullable = true},
        {name = 'enabled', type = 'bool', nullable = true},
    }, opt)

    self._opt = opt
    simIK.setElementConstraints(self._ik.handle, self._group.handle, self.handle, opt.constraints)
    simIK.setElementPrecision(self._ik.handle, self._group.handle, self.handle, opt.precision)
    simIK.setElementWeights(self._ik.handle, self._group.handle, self.handle, opt.weights)
    simIK.setElementFlags(self._ik.handle, self._group.handle, self.handle, opt.enabled and 1 or 0)
end

--function IKElement:group() return self._group end
--function IKElement:ik()    return self._group._ik end
--function IKElement:handle() return self.handle end

--==================================================================
-- IK group class
--==================================================================
local IKGroup = class('IKGroup')

function IKGroup:initialize(ik, groupHandle, opt)
    self._ik = ik
    self.handle = groupHandle
    self.elements = {}
    self._opt = {}
    
    -- Defaults:
    self._opt.method = simIK.method_pseudo_inverse
    self._opt.damping = 0.1
    self._opt.maxIterations = 3
    self._opt.enabled = true
    self._opt.ignoreMaxSteps = true
    self._opt.restoreOnBadLinTol = false
    self._opt.restoreOnBadAngTol = false
    self._opt.avoidLimits = false
    self._opt.stopOnLimitHit = false
    
    self:update(opt)
end

function IKGroup:update(opt)
    opt = opt or {}

    for k, v in pairs(self._opt) do
        if opt[k] == nil then
            opt[k] = v
        end
    end
    
    for k, v in pairs(opt) do
        if self._opt[k] == nil then
            sim2.app:logWarn("unrecognized option '" .. k .. "'.\n" .. debug.traceback())
        end
    end
    
    checkargs.checkfields({funcName = 'update'}, {
        {name = 'method', enum = {pseudoInverse = simIK.method_pseudo_inverse, undampedPseudoInverse = simIK.method_undamped_pseudo_inverse, dampedLeastSquares = simIK.method_damped_least_squares, jacobianTranspose = simIK.method_jacobian_transpose}, nullable = true},
        {name = 'damping', type = 'float', nullable = true},
        {name = 'maxIterations', type = 'int', range = '1..*', nullable = true},
        {name = 'enabled', type = 'bool', nullable = true},
        {name = 'ignoreMaxSteps', type = 'bool', nullable = true},
        {name = 'restoreOnBadLinTol', type = 'bool', nullable = true},
        {name = 'restoreOnBadAngTol', type = 'bool', nullable = true},
        {name = 'avoidLimits', type = 'bool', nullable = true},
        {name = 'stopOnLimitHit', type = 'bool', nullable = true},
    }, opt)

    self._opt = opt
    simIK.setGroupCalculation(self._ik.handle, self.handle, self._opt.method, self._opt.damping, self._opt.maxIterations)
    local fl = 0
    fl = fl + (self._opt.enabled and 1 or 0) * simIK.group_enabled
    fl = fl + (self._opt.ignoreMaxSteps and 1 or 0) * simIK.group_ignoremaxsteps
    fl = fl + (self._opt.restoreOnBadLinTol and 1 or 0) * simIK.group_restoreonbadlintol
    fl = fl + (self._opt.restoreOnBadAngTol and 1 or 0) * simIK.group_restoreonbadangtol
    fl = fl + (self._opt.avoidLimits and 1 or 0) * simIK.group_avoidlimits
    fl = fl + (self._opt.stopOnLimitHit and 1 or 0) * simIK.group_stoponlimithit
    simIK.setGroupFlags(self._ik.handle, self.handle, fl)
end

function IKGroup:solve(opt)
    opt = checkargs({
        {type = 'table', default = {}},
    }, opt)
    opt.debug = opt.debug or 0
    if opt.syncWorlds then 
        self:syncFromSim()
    end
    local retVal, reason, prec = self._ik:_handleGroups({self.handle}, opt)
    if opt.syncWorlds then
        if (reason & simIK.calc_notwithintolerance) == 0 or opt.allowError then
            self:syncToSim()
        end
    end
    self._ik:debugGroupIfNeeded(self.handle, opt.debug)
    return retVal, reason, prec
end

--function IKGroup:ik()     return self._ik end
--function IKGroup:handle() return self.handle end

function IKGroup:addElementFromScene(base, tip, target, const, opt)
    local ik = self._ik
    
    local ikElement, simToIkMap, ikToSimMap = ik:_addElementFromScene(self.handle, base, tip, target, const)
    opt = opt or {}
    opt.constraints = const
    local element = IKElement(ik, self, ikElement, simToIkMap, ikToSimMap, opt)
    self.elements[#self.elements + 1] = element
    return element
end

function IKGroup:syncFromSim()
    local ikEnv = self._ik.handle
    local lb = sim.setStepping(true)
    local groupData = self._ik._ikGroupData[self.handle]
    for k, v in pairs(groupData.joints) do
        if sim.isHandle(k) then
            if sim.getJointType(k) == sim.joint_spherical then
                simIK.setSphericalJointMatrix(ikEnv, v, sim.getJointMatrix(k))
            else
                simIK.setJointPosition(ikEnv, v, sim.getJointPosition(k))
            end
        else
            -- probably a joint in a dependency relation that was removed
            simIK.eraseObject(ikEnv, v)
            groupData.joints[k] = nil
            self._ik._simToIkMap[k] = nil
            self._ik._ikToSimMap[v] = nil
        end
    end
    for i = 1, #groupData.targetTipBaseTriplets do
        simIK.setObjectMatrix(ikEnv,
            groupData.targetTipBaseTriplets[i][4], sim.getObjectMatrix(
                groupData.targetTipBaseTriplets[i][1], groupData.targetTipBaseTriplets[i][3]
            ), groupData.targetTipBaseTriplets[i][6]
        )
    end
    sim.setStepping(lb)
end

function IKGroup:syncToSim()
    local ikEnv = self._ik.handle
    local lb = sim.setStepping(true)
    local groupData = self._ik._ikGroupData[self.handle]
    for k, v in pairs(groupData.joints) do
        if sim.isHandle(k) then
            if sim.getJointType(k) == sim.joint_spherical then
                if sim.getJointMode(k) ~= sim.jointmode_dynamic or not sim.isDynamicallyEnabled(k) then
                    sim.setSphericalJointMatrix(k, simIK.getJointMatrix(ikEnv, v))
                end
            else
                if sim.getJointMode(k) == sim.jointmode_dynamic and sim.isDynamicallyEnabled(k) then
                    sim.setJointTargetPosition(k, simIK.getJointPosition(ikEnv, v))
                else
                    sim.setJointPosition(k, simIK.getJointPosition(ikEnv, v))
                end
            end
        else
            simIK.eraseObject(ikEnv, v)
            groupData.joints[k] = nil
            self._ik._simToIkMap[k] = nil
            self._ik._ikToSimMap[v] = nil
        end
    end
    sim.setStepping(lb)
end

--==================================================================
-- IK class
--==================================================================

local IK = class('IK')

function IK:initialize()
    self.handle = simIK.createEnvironment()
    self.groups = {} 
    
    -- internal use:
    self._ikGroupData = {}
    self._ikGroupHandles = {}
    self._simToIkMap = {}
    self._ikToSimMap = {}
    self._ikDebug = nil
    
    self.constraint_x = simIK.constraint_x
    self.constraint_y = simIK.constraint_y
    self.constraint_z = simIK.constraint_z
    self.constraint_alphabeta = simIK.constraint_alpha_beta
    self.constraint_gamma = simIK.constraint_gamma
    self.constraint_position = simIK.constraint_position
    self.constraint_orientation = simIK.constraint_orientation
    self.constraint_pose = simIK.constraint_pose

    self.result_notperformed = simIK.result_not_performed
    self.result_success = simIK.result_success
    self.result_fail = simIK.result_fail

    self.calc_notperformed = simIK.calc_notperformed
    self.calc_cannotinvert = simIK.calc_cannotinvert
    self.calc_notwithintolerance = simIK.calc_notwithintolerance
    self.calc_stepstoobig = simIK.calc_stepstoobig
    self.calc_limithit = simIK.calc_limithit
    self.calc_invalidcallbackdata = simIK.calc_invalidcallbackdata
end

function IK:createGroup(opt)
--[[

getGroupJoints  
simIK.getGroupJointLimitHits
--]]


    local groupHandle = simIK.createIkGroup(self.handle)
    self._ikGroupHandles[#self._ikGroupHandles + 1] = groupHandle
    local group = IKGroup(self, groupHandle, opt)
    self.groups[#self.groups + 1] = group
    return group
end

local envForwarded = {
    'setJointMode',
    'getJointMode',
    'setElementFlags',
    'getElementFlags',
    'setJointPosition',
    'getJointPosition',
    'setGroupCalculation',
    'getGroupCalculation',
    'setElementPrecision',
    'getElementPrecision',
    'getObjects',
    'getObjectParent',
    'setObjectParent',
    'getObjectType',
    'createDummy',
    'createJoint',
    'getJointType',
    'getJointInterval',
    'setJointInterval',
    'getJointScrewLead',
    'setJointScrewLead',
    'getJointWeight',
    'setJointWeight',
    'getJointLimitMargin',
    'setJointLimitMargin',
    'getJointMaxStepSize',
    'setJointMaxStepSize',
    'getTargetDummy',
    'setTargetDummy',
    'getJointDependency',
    'getGroupFlags',
    'setGroupFlags',
    'getGroupJointLimitHits',
    'getGroupJoints',
    'addElement',
    'getElementBase',
    'setElementBase',
    'getElementConstraints',
    'setElementConstraints',
    'getElementWeights',
    'setElementWeights',
    'computeJacobian',
    'computeGroupJacobian',
}

for _, name in ipairs(envForwarded) do
    assert(IK[name] == nil, 'IK method already defined: ' .. name)
    assert(simIK[name] ~= nil, 'no such simIK function: ' .. name)
    IK[name] = function(self, ...)
        return simIK[name](self.handle, ...)
    end
end

function IK:getObjectPose(handle, rel)
    rel = rel or simIK.handle_world
    local p, q = simIK.getObjectTransformation(self.handle, handle, rel)
    return simEigen.Pose({p[1], p[2], p[3], q[1], q[2], q[3], q[4]})
end

function IK:setObjectPose(handle, p, rel)
    rel = rel or simIK.handle_world
    if simEigen.Pose:ispose(pose) then
        p = p:data()
    end
    return simIK.setObjectTransformation(self.handle, handle, {p[1], p[2], p[3]}, {p[4], p[5], p[6], p[7]}, rel)
end

function IK:getObjectPosition(handle, rel)
    rel = rel or simIK.handle_world
    local p, q = simIK.getObjectTransformation(self.handle, handle, rel)
    return simEigen.Vector3(p)
end

function IK:setObjectPosition(handle, p, rel)
    rel = rel or simIK.handle_world
    local po, q = simIK.getObjectTransformation(self.handle, handle, rel)
    if simEigen.Vector:isvector(p, 3) then
        p = p:data()
    end
    return simIK.setObjectTransformation(self.handle, handle, p, q, rel)
end

function IK:getObjectQuaternion(handle, rel)
    rel = rel or simIK.handle_world
    local p, q = simIK.getObjectTransformation(self.handle, handle, rel)
    return simEigen.Quaternion(q)
end

function IK:setObjectQuaternion(handle, q, rel)
    rel = rel or simIK.handle_world
    local p, qo = simIK.getObjectTransformation(self.handle, handle, rel)
    if simEigen.Quaternion:isquaternion(q) then
        q = q:data()
    end
    return simIK.setObjectTransformation(self.handle, handle, p, q, rel)
end

function IK:getObject(...)
    return simIK.getObjectHandle(self.handle, ...)
end

function IK:removeObject(...)
    return simIK.eraseObject(self.handle, ...)
end

function IK:getJointQuaternion(...)
    local p = simIK.getJointPose(self.handle, ...)
    return simEigen.Quaternion({p[5], p[6], p[7], p[4]})
end

function IK:setJointQuaternion(h, q)
    if simEigen.Quaternion:isquaternion(q) then
        q = q:data()
    end
    q = {q[4], q[1], q[2], q[3]}
    return simIK.setJointQuaternion(self.handle, h, q)
end

function IK:updateJoint(handle, opt)
    checkargs.checkfields({funcName = 'updateJoint'}, {
        {name = 'interval', type = 'table', size = 2, itemType = 'float', nullable = true},
        {name = 'weight', type = 'float', nullable = true},
        {name = 'limitMargin', type = 'float', nullable = true},
        {name = 'maxStepSize', type = 'float', nullable = true},
        {name = 'screwLead', type = 'float', nullable = true},
        {name = 'masterJoint', type = 'int', nullable = true},
        {name = 'offset', type = 'float', nullable = true},
        {name = 'scaling', type = 'float', nullable = true},
        {name = 'passive', type = 'bool', nullable = true},
        {name = 'cyclic', type = 'bool', nullable = true},
    }, opt)
    if opt.passive ~= nil then
        local m = simIK.jointmode_ik
        if opt.passive then
            m = simIK.jointmode_passive
        end
        simIK.setJointMode(self.handle, handle, m) 
    end
    if opt.interval or (opt.cyclic ~= nil) then
        local c, int = simIK.getJointInterval(self.handle, handle, opt.cyclic)
        int[2] = int[1] + int[2]
        if opt.interval then
            int = opt.interval
        end
        if opt.cyclic then
            c = opt.cyclic
        end
        int[2] = int[2] - int[1]
        simIK.setJointInterval(self.handle, handle, c, int) 
    end
    if opt.weight then
        simIK.setJointWeight(self.handle, handle, opt.weight) 
    end
    if opt.limitMargin then
        simIK.setJointLimitMargin(self.handle, handle, opt.limitMargin) 
    end
    if opt.maxStepSize then
        simIK.setJointMaxStepSize(self.handle, handle, opt.maxStepSize) 
    end
    if opt.screwLead then
        simIK.setJointScrewLead(self.handle, handle, opt.screwLead) 
    end
    if opt.masterJoint or opt.offset or opt.scaling or opt.callback then
        local m, o, mult = simIK.getJointDependency(self.handle, handle)
        if opt.masterJoint then
            m = opt.masterJoint
        end
        if opt.offset then
            o = opt.offset
        end
        if opt.scaling then
            mult = opt.scaling
        end
        ik:_setJointDependency(handle, m, o, mult, opt.callback)
    end
end

function IK:getAlternateConfigs(...)
    local jointHandles, lowLimits, ranges = checkargs({
        {type = 'table', size = '1..*', item_type = 'int'},
        {type = 'table', size = '1..*', item_type = 'float', default_nil = true, nullable = true},
        {type = 'table', size = '1..*', item_type = 'float', default_nil = true, nullable = true},
    }, ...)

    local ikEnv = self.handle
    local dof = #jointHandles
    if (lowLimits and dof ~= #lowLimits) or (ranges and dof ~= #ranges) then
        error("Bad table size.")
    end

    local lb = sim.setStepping(true)

    local x = {}
    local confS = {}
    local err = false
    local inputConfig = {}
    for i = 1, #jointHandles do
        inputConfig[i] = simIK.getJointPosition(ikEnv, jointHandles[i])
        local c, interv = simIK.getJointInterval(ikEnv, jointHandles[i])
        local t = simIK.getJointType(ikEnv, jointHandles[i])
        local sp = simIK.getJointScrewLead(ikEnv, jointHandles[i])
        if t == simIK.jointtype_revolute and not c then
            if sp == 0 then
                if inputConfig[i] - math.pi * 2 >= interv[1] or inputConfig[i] + math.pi * 2 <=
                    interv[1] + interv[2] then
                    local y = inputConfig[i]
                    while y - math.pi * 2 >= interv[1] do y = y - math.pi * 2 end
                    x[i] = {y, interv[1] + interv[2]}
                end
            end
        end
        if x[i] then
            if lowLimits and ranges then
                local l = lowLimits[i]
                local r = ranges[i]
                if r ~= 0 then
                    if r > 0 then
                        if l < interv[1] then
                            r = r - (interv[1] - l)
                            l = interv[1]
                        end
                        if l > interv[1] + interv[2] then
                            x[i] = {inputConfig[i], inputConfig[i]}
                            err = true
                        else
                            if l + r > interv[1] + interv[2] then
                                r = interv[1] + interv[2] - l
                            end
                            if inputConfig[i] - math.pi * 2 >= l or inputConfig[i] + math.pi * 2 <=
                                l + r then
                                local y = inputConfig[i]
                                while y < l do y = y + math.pi * 2 end
                                while y - math.pi * 2 >= l do y = y - math.pi * 2 end
                                x[i] = {y, l + r}
                            else
                                x[i] = {inputConfig[i], inputConfig[i]}
                                err = (inputConfig[i] < l) or (inputConfig[i] > l + r)
                            end
                        end
                    else
                        r = -r
                        l = inputConfig[i] - r * 0.5
                        if l < x[i][1] then l = x[i][1] end
                        local u = inputConfig[i] + r * 0.5
                        if u > x[i][2] then u = x[i][2] end
                        x[i] = {l, u}
                    end
                end
            end
        else
            x[i] = {inputConfig[i], inputConfig[i]}
        end
        confS[i] = x[i][1]
    end
    local configs = {}
    if not err then
        local desiredPose = 0
        configs = _loopThroughAltConfigSolutions(ikEnv, jointHandles, desiredPose, confS, x, 1)
    end
    sim.setStepping(lb)

    if next(configs) ~= nil then
        local simEigen = require('simEigen')
        configs = simEigen.Matrix:fromtable(configs)
        configs = configs:data()
    end
    return configs
end

function IK:syncFromSim()
    local lb = sim.setStepping(true)
    for g = 1, #self.groups do
        self.groups[g]:syncFromSim()
    end
    sim.setStepping(lb)
end

function IK:syncToSim()
    local lb = sim.setStepping(true)
    for g = 1, #self.groups do
        self.groups[g]:syncToSim()
    end
    sim.setStepping(lb)
end

function IK:debugGroupIfNeeded(ikGroup, debugFlags)
    local groupData = self._ikGroupData[ikGroup]
    if not groupData then return end

    local p = sim.getIntProperty(sim.handle_app, 'signal.simIK.debug_world', {noError = true})
    if (p and (p & 1) ~= 0) or ((debugFlags & 1) ~= 0) then
        local lb = sim.setStepping(true)
        groupData.visualDebug = {}
        for i = 1, #groupData.targetTipBaseTriplets do
            groupData.visualDebug[i] = self:createDebugOverlay(
                                           groupData.targetTipBaseTriplets[i][5],
                                           groupData.targetTipBaseTriplets[i][6]
                                       )
        end
        sim.setStepping(lb)
    else
        if groupData.visualDebug then
            for i = 1, #groupData.visualDebug do
                self:eraseDebugOverlay(groupData.visualDebug[i])
            end
        end
        groupData.visualDebug = {}
    end
end

function IK:_addElementFromScene(...)
    local ikGroup, simBase, simTip, simTarget, constraints = checkargs({
        {type = 'int'},
        {type = 'int'},
        {type = 'int'},
        {type = 'int'},
        {type = 'int'},
    }, ...)

    local ikEnv = self.handle
    local lb = sim.setStepping(true)

    local groupData = self._ikGroupData[ikGroup]
    -- simToIkMap and ikToSimMap are scoped by env (not by group) to avoid duplicates:
    local simToIkMap = self._simToIkMap
    local ikToSimMap = self._ikToSimMap
    if not groupData then
        groupData = {joints = {}, targetTipBaseTriplets = {}}
        self._ikGroupData[ikGroup] = groupData
    end

    local function createIkJointFromSimJoint(simJoint)
        local t = sim.getJointType(simJoint)
        local ikJoint = simIK.createJoint(ikEnv, t)
        local c, interv = sim.getJointInterval(simJoint)
        simIK.setJointInterval(ikEnv, ikJoint, c, interv)
        local sp = sim.getFloatProperty(simJoint, 'screwLead')
        simIK.setJointScrewLead(ikEnv, ikJoint, sp)
        if t == sim.joint_spherical then
            simIK.setSphericalJointMatrix(ikEnv, ikJoint, sim.getJointMatrix(simJoint))
        else
            simIK.setJointPosition(ikEnv, ikJoint, sim.getJointPosition(simJoint))
        end
        return ikJoint
    end

    local function iterateAndAdd(theTip, theBase)
        local ikPrevIterator = -1
        local simIterator = theTip
        while true do
            local ikIterator = -1
            if simToIkMap[simIterator] then
                ikIterator = simToIkMap[simIterator]
            else
                if sim.getObjectType(simIterator) ~= sim.sceneobject_joint then
                    ikIterator = simIK.createDummy(ikEnv)
                else
                    ikIterator = createIkJointFromSimJoint(simIterator)
                end
                simToIkMap[simIterator] = ikIterator
                ikToSimMap[ikIterator] = simIterator
                simIK.setObjectMatrix(self.handle, ikIterator, sim.getObjectMatrix(simIterator), simIK.handle_world)
            end
            if sim.getObjectType(simIterator) == sim.sceneobject_joint then
                groupData.joints[simIterator] = ikIterator
            end
            if ikPrevIterator ~= -1 then
                simIK.setObjectParent(ikEnv, ikPrevIterator, ikIterator)
            end
            local newSimIterator = sim.getObjectParent(simIterator)
            if simIterator == theBase or newSimIterator == -1 then break end
            simIterator = newSimIterator
            ikPrevIterator = ikIterator
        end
    end

    iterateAndAdd(simTip, -1) -- add the whole chain down to world, otherwise subtle bugs!
    local ikTip = simToIkMap[simTip]
    local ikBase = -1
    if simBase ~= -1 then ikBase = simToIkMap[simBase] end
    iterateAndAdd(simTarget, -1) -- add the whole target chain down to world too!
    local ikTarget = simToIkMap[simTarget]
    simIK.setTargetDummy(ikEnv, ikTip, ikTarget)
    groupData.targetTipBaseTriplets[#groupData.targetTipBaseTriplets + 1] = {
        simTarget, simTip, simBase, ikTarget, ikTip, ikBase,
    }

    -- joint dependencies (slaves/masters/passives):
    local simJoints = sim.getObjectsInTree(sim.handle_scene, sim.sceneobject_joint)
    local slaves = {}
    local masters = {}
    local passives = {}
    for i = 1, #simJoints do
        local jo = simJoints[i]
        if sim.getJointMode(jo) == sim.jointmode_dependent then
            local dep, off, mult = sim.getJointDependency(jo)
            if dep ~= -1 then
                slaves[#slaves + 1] = jo
                masters[#masters + 1] = dep
            else
                passives[#passives + 1] = jo
            end
        end
    end
    for i = 1, #passives do
        local ikJo = simToIkMap[passives[i]]
        if ikJo then simIK.setJointMode(ikEnv, ikJo, simIK.jointmode_passive) end
    end
    for i = 1, #slaves do
        local slave = slaves[i]
        local master = masters[i]
        local ikJo_s = simToIkMap[slave]
        local ikJo_m = simToIkMap[master]
        if ikJo_s == nil then
            ikJo_s = createIkJointFromSimJoint(slave)
            simToIkMap[slave] = ikJo_s
            ikToSimMap[ikJo_s] = slave
            simIK.setObjectMatrix(self.handle, ikJo_s, sim.getObjectMatrix(slave), simIK.handle_world)
            groupData.joints[slave] = ikJo_s
        end
        if ikJo_m == nil then
            ikJo_m = createIkJointFromSimJoint(master)
            simToIkMap[master] = ikJo_m
            ikToSimMap[ikJo_m] = master
            simIK.setObjectMatrix(self.handle, ikJo_m, sim.getObjectMatrix(master), simIK.handle_world)
            groupData.joints[master] = ikJo_m
        end
        local dep, off, mult = sim.getJointDependency(slave)
        self:_setJointDependency(ikJo_s, ikJo_m, off, mult)
    end

    local ikElement = simIK.addElement(ikEnv, ikGroup, ikTip)
    simIK.setElementBase(ikEnv, ikGroup, ikElement, ikBase, -1)
    simIK.setElementConstraints(ikEnv, ikGroup, ikElement, constraints)
    sim.setStepping(lb)
    return ikElement, simToIkMap, ikToSimMap
end

-- this replaces simIK.eraseEnvironment() and the constructor-owned environment:
function IK:remove()
    local lb = sim.setStepping(true)
    for k, v in pairs(self._ikGroupData) do
        if v.visualDebug then
            for i = 1, #v.visualDebug do
                self:eraseDebugOverlay(v.visualDebug[i])
            end
        end
    end
    self.groups = {}
    self._ikGroupData = {}
    self._ikGroupHandles = {}
    self._simToIkMap = {}
    self._ikToSimMap = {}
    if self.handle then
        simIK._eraseEnvironment(self.handle)
        self.handle = nil
    end
    sim.setStepping(lb)
end

function IK:_findConfig(...)
    local ikGroup, joints, thresholdDist, maxTime, metric, callback, auxData = checkargs({
        {type = 'int'},
        {type = 'table', size = '1..*', item_type = 'int'},
        {type = 'float', default = 0.1},
        {type = 'float', default = 0.5},
        {type = 'table', size = 4, item_type = 'float', default = {1, 1, 1, 0.1}, nullable = true},
        {type = 'any', default_nil = true, nullable = true},
        {type = 'any', default_nil = true, nullable = true},
    }, ...)

    local env = self.handle
    local lb = sim.setStepping(true)
    if metric == nil then metric = {1, 1, 1, 0.1} end
    local __callback
    function __ikcb(config)
        local fun = _G
        if string.find(__callback, "%.") then
            for w in __callback:gmatch("[^%.]+") do
                if fun[w] then fun = fun[w] end
            end
        else
            fun = fun[__callback]
        end
        if type(fun) == 'function' then
            return fun(config, auxData)
        end
    end
    local funcNm, t
    if callback then
        __callback = reify(callback)
        funcNm = '__ikcb'
        t = sim.getScript(sim.handle_self)
    end
    -- IK:_findConfig is a different table than simIK._findConfig, so no recursion here:
    local retVal = simIK._findConfig(env, ikGroup, joints, thresholdDist, maxTime * 1000, metric, funcNm, t)
    sim.setStepping(lb)
    return retVal
end

function IK:debugJacobianDisplay(inData)
    local groupData = self._ikGroupData[inData.groupHandle]
    local groupIdStr = string.format('env:%d/group:%d', self.handle, inData.groupHandle)
    local simQML
    pcall(function() simQML = require 'simQML' end)
    if simQML then
        if groupData.jacobianDebug == nil then
            groupData.jacobianDebug = {qmlEngine = simQML.createEngine()}
            function jacobianDebugClicked()
                jacobianDebugPrint = true
            end
            simQML.setEventHandler(groupData.jacobianDebug.qmlEngine, 'dispatchEventsToFunctions')
            simQML.loadData(
                groupData.jacobianDebug.qmlEngine, [[
                import QtQuick 2.12
                import QtQuick.Window 2.12
                import CoppeliaSimPlugin 1.0

                PluginWindow {
                    id: mainWindow
                    width: cellSize * cols
                    height: cellSize * rows
                    title: "Jacobian ]] .. groupIdStr .. [["

                    readonly property string groupId: "]] .. groupIdStr .. [["

                    property int rows: 6
                    property int cols: 12
                    readonly property int cellSize: 15

                    property real absMin: 0
                    property real absMax: 0.001
                    property bool initMax: true

                    property var jacobianData: {
                        var _t = []
                        for(var iy = 0; iy < rows; iy++) {
                            var _r = []
                            for(var ix = 0; ix < cols; ix++) {
                                var z = iy/rows - ix/cols
                                z = Math.sign(z) * Math.pow(10, 3 * Math.abs(z))
                                _r.push(z)
                            }
                            _t.push(_r)
                        }
                        return _t
                    }

                    function colorMap(value) {
                        var min = Math.log10(Math.max(0.00001, absMin))
                        var max = Math.log10(absMax)
                        var sign = Math.sign(value)
                        value = Math.max(0, Math.min(1, (Math.log10(Math.abs(value)) - min) / Math.max(1e-9, max - min)))
                        var c = x => Math.min(Math.max(x, 0), 1)
                        var r = c(sign * value)
                        var b = c(-sign * value)
                        return Qt.rgba(1 - b, 1 - 0.6 * (r + b), 1 - r)
                    }

                    Column {
                        Repeater {
                            model: mainWindow.rows
                            Row {
                                readonly property int i: index
                                readonly property var rowData: mainWindow.jacobianData[i] || new Array(mainWindow.cols).fill(0)
                                Repeater {
                                    model: mainWindow.cols
                                    Rectangle {
                                        readonly property int j: index
                                        readonly property real elemData: rowData[j] || 0
                                        width: mainWindow.width / mainWindow.cols
                                        height: mainWindow.height / mainWindow.rows
                                        color: colorMap(elemData)
                                        border.color: Qt.rgba(0, 0, 0, 0.03)
                                        opacity: 0.8
                                        Text {
                                            anchors.fill: parent
                                            text: Number(elemData).toLocaleString(Qt.locale("en_US"), 'f', width / font.pixelSize)
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            readonly property real k: 0.33
                                            font.pixelSize: Math.min(k * parent.width, k * parent.height, 14)
                                            opacity: Math.min(font.pixelSize / 11, 1)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onPressed: simBridge.sendEvent('jacobianDebugClicked', {})
                    }

                    Component.onCompleted: {
                        x = Screen.width - width - 5
                        y = Screen.height - height - 180
                    }

                    function setData(info) {
                        if(info.groupId !== mainWindow.groupId) return
                        var d = info.jacobian
                        var _t = []
                        if(mainWindow.initMax && d.length > 0 && d[0].length > 0) {
                            mainWindow.initMax = false
                            mainWindow.absMin = Math.abs(d[0][0])
                            mainWindow.absMax = Math.abs(d[0][0])
                        }
                        for(var iy = 0; iy < d.length; iy++) {
                            var _r = []
                            for(var ix = 0; ix < d[0].length; ix++) {
                                mainWindow.absMin = Math.min(mainWindow.absMin, Math.abs(d[iy][ix]))
                                mainWindow.absMax = Math.max(mainWindow.absMax, Math.abs(d[iy][ix]))
                                _r.push(d[iy][ix])
                            }
                            _t.push(_r)
                        }
                        mainWindow.jacobianData = _t
                        mainWindow.rows = d.length
                        mainWindow.cols = d[0].length
                    }
                }
            ]]
            )
        end
        simQML.sendEvent(
            groupData.jacobianDebug.qmlEngine, 'setData',
            {groupId = groupIdStr, jacobian = inData.jacobian:totable()}
        )
    end
    if jacobianDebugPrint then
        jacobianDebugPrint = false
        inData.jacobian:print 'J'
    end
end

function IK:solve(opt)
    opt = checkargs({
        {type = 'table', default = {}},
    }, opt)
    opt.debug = opt.debug or 0
    if opt.syncWorlds then 
        self:syncFromSim()
    end
    local retVal, reason, prec = self:_handleGroups(self._ikGroupHandles, opt)
    if opt.syncWorlds then
        if (reason & simIK.calc_notwithintolerance) == 0 or opt.allowError then
            self:syncToSim()
        end
    end
    for i = 1, #self._ikGroupData do self:debugGroupIfNeeded(self._ikGroupData[i], opt.debug) end
    return retVal, reason, prec
end


function IK:_handleGroups(ikGroups, options)
    local ikEnv = self.handle
    local lb = sim.setStepping(true)
    local debugFlags = 0
    if options.debug then debugFlags = options.debug end
    local p = sim.getIntProperty(sim.handle_app, 'signal.simIK.debug_world', {noError = true})
    local debugJacobian = (((debugFlags & 2) ~= 0) or (p and (p & 2) ~= 0))
    local pythonCallback = false
    function __cb(rows_constr, rows_ikEl, cols_handles, cols_dofIndex, jacobian, errorVect, groupId, iteration)
        local data = {}
        data.rows = {}
        data.cols = {}
        if pythonCallback then
            data.jacobian = jacobian
            data.e = errorVect
        else
            data.jacobian = Matrix(#rows_constr, #cols_handles, jacobian)
            data.e = Matrix(#rows_constr, 1, errorVect)
        end
        for i = 1, #rows_constr do
            data.rows[i] = {constraint = rows_constr[i], element = rows_ikEl[i]}
        end
        for i = 1, #cols_handles do
            data.cols[i] = {joint = cols_handles[i], dofIndex = cols_dofIndex[i]}
        end
        data.groupHandle = groupId
        data.iteration = iteration
        if debugJacobian then self:debugJacobianDisplay(data) end
        local j = {}
        local e = {}
        local dq = {}
        local jpinv = {}
        if options.callback then
            local outData
            if type(options.callback) == 'string' then
                outData = _G[options.callback](data, options.auxData)
            else
                outData = options.callback(data, options.auxData)
            end
            if outData then
                if pythonCallback then
                    if outData.jacobian then
                        if #outData.jacobian == #cols_handles * #rows_constr then
                            j = outData.jacobian
                        else
                            error("invalid jacobian matrix size")
                        end
                    end
                    if outData.e then
                        if #outData.e == #rows_constr then
                            e = outData.e
                        else
                            error("invalid e vector size")
                        end
                    end
                    if outData.dq then
                        if #outData.dq == #cols_handles then
                            dq = outData.dq
                        else
                            error("invalid dq vector size")
                        end
                    end
                    if outData.jacobianPinv then
                        if #outData.jacobianPinv == #cols_handles * #rows_constr then
                            jpinv = outData.jacobianPinv
                        else
                            error("invalid jacobian pseudo-inverse matrix size")
                        end
                    end
                else
                    if outData.jacobian then
                        if outData.jacobian:cols() == #cols_handles and outData.jacobian:rows() ==
                            #rows_constr then
                            j = outData.jacobian:data()
                        else
                            error("invalid jacobian matrix size")
                        end
                    end
                    if outData.e then
                        if outData.e:rows() == #rows_constr and outData.e:cols() == 1 then
                            e = outData.e:data()
                        else
                            error("invalid e vector size")
                        end
                    end
                    if outData.dq then
                        if outData.dq:rows() == #cols_handles and outData.dq:cols() == 1 then
                            dq = outData.dq:data()
                        else
                            error("invalid dq vector size")
                        end
                    end
                    if outData.jacobianPinv then
                        if outData.jacobianPinv:rows() == #cols_handles and outData.jacobianPinv:cols() ==
                            #rows_constr then
                            jpinv = outData.jacobianPinv:data()
                        else
                            error("invalid jacobian pseudo-inverse matrix size")
                        end
                    end
                end
            end
        end
        return j, e, dq, jpinv
    end
    local funcNm, t
    if options.callback or debugJacobian then
        funcNm = '__cb'
        t = sim.getScript(sim.handle_self)
        if __.pythonCallbacks and __.pythonCallbacks[options.callback] then
            pythonCallback = true
        end
    end
    local retVal, reason, prec = simIK._handleGroups(self.handle, ikGroups, funcNm, t)
    sim.setStepping(lb)
    return retVal, reason, prec
end

function IK:getFailureDescription(reason)
    local d = {}
    for _, k in ipairs {
        'notperformed', 'cannotinvert', 'notwithintolerance', 'stepstoobig', 'limithit',
    } do
        local f = 'calc_' .. k
        if reason & simIK[f] > 0 then
            reason = reason & ~simIK[f]
            table.insert(d, k)
        end
    end
    if reason ~= 0 then table.insert(d, tostring(reason)) end
    return table.tostring(d)
end

function IK:_setJointDependency(slaveJoint, masterJoint, offset, mult, callback)
    local ikEnv = self.handle
    function __depcb(env, sJoint, masterPos)
        if type(callback) == 'string' then
            return _G[callback](env, sJoint, masterPos)
        else
            return callback(env, sJoint, masterPos)
        end
    end
    local funcNm, t
    if callback then
        funcNm = '__depcb'
        t = sim.getScript(sim.handle_self)
    end
    simIK._setJointDependency(ikEnv, slaveJoint, masterJoint, offset, mult, funcNm, t)
end

function IK:generatePath(...)
    local ikGroup, ikJoints, tip, ptCnt, callback, auxData = checkargs({
        {type = 'int'},
        {type = 'table', size = '1..*', item_type = 'int'},
        {type = 'int'},
        {type = 'int'},
        {type = 'any', default_nil = true, nullable = true},
        {type = 'any', default_nil = true},
    }, ...)

    local lb = sim.setStepping(true)

    local tmpEnv = simIK.duplicateEnvironment(self.handle)
    local targetHandle = simIK.getTargetDummy(tmpEnv, tip)
    local startMatrix = simIK.getObjectMatrix(tmpEnv, tip, simIK.handle_world)
    local goalMatrix = simIK.getObjectMatrix(tmpEnv, targetHandle, simIK.handle_world)
    local retPath = {{}}
    for i = 1, #ikJoints do retPath[1][i] = simIK.getJointPosition(tmp.handle, ikJoints[i]) end
    local success = true
    if callback then
        if type(callback) == 'string' then
            success = _G[callback](retPath[1], auxData)
        else
            success = callback(retPath[1], auxData)
        end
    end
    if success then
        for j = 1, ptCnt - 1 do
            local t = j / (ptCnt - 1)
            local m = sim.interpolateMatrices(startMatrix, goalMatrix, t)
            simIK.setObjectMatrix(tmpEnv, targetHandle, m, simIK.handle_world)
            success = simIK._handleGroups(tmpEnv, {ikGroup}) == simIK.result_success
            if not success then break end
            retPath[j + 1] = {}
            for i = 1, #ikJoints do
                retPath[j + 1][i] = simIK.getJointPosition(tmp.handle, ikJoints[i])
            end
            if callback then
                if type(callback) == 'string' then
                    success = _G[callback](retPath[j + 1], auxData)
                else
                    success = callback(retPath[j + 1], auxData)
                end
            end
            if not success then break end
        end
    end
    simIK._eraseEnvironment(tmpEnv)
    tmp:remove()
    sim.setStepping(lb)
    if not success then
        retPath = {}
    else
        retPath = table.collapse(retPath)
    end
    return retPath
end

function IK:createDebugOverlay(...)
    local ikTip, ikBase = checkargs({
        {type = 'int'},
        {type = 'int', default = -1},
    }, ...)

    local ikEnv = self.handle
    if not self._ikDebug then self._ikDebug = {tips = {}, nextId = 0} end
    if not self._ikDebug.tips[ikTip] then
        self._ikDebug.tips[ikTip] = {drawingConts = {}, id = self._ikDebug.nextId}
        self._ikDebug.nextId = self._ikDebug.nextId + 1
    end
    local drawingConts = self._ikDebug.tips[ikTip].drawingConts

    local ikTarget = simIK.getTargetDummy(ikEnv, ikTip)
    if drawingConts.targetCont == nil then
        drawingConts.targetCont = sim.addDrawingObject(
                                      sim.drawing_spherepts | sim.drawing_overlay |
                                          sim.drawing_cyclic, 0.012, 0, -1, 1, {1, 0, 0}
                                  )
    end
    sim.addDrawingObjectItem(drawingConts.targetCont, simIK._getObjectPose(self.handle, ikTarget))
    if drawingConts.tipCont == nil then
        drawingConts.tipCont = sim.addDrawingObject(
                                   sim.drawing_spherepts | sim.drawing_overlay | sim.drawing_cyclic,
                                   0.01, 0, -1, 1, {0, 1, 0}
                               )
    end
    sim.addDrawingObjectItem(drawingConts.tipCont, simIK._getObjectPose(self.handle, ikTip))
    if drawingConts.linkCont == nil then
        drawingConts.linkCont = sim.addDrawingObject(
                                    sim.drawing_lines | sim.drawing_overlay, 2, 0, -1, 0, {0, 0, 0}
                                )
    else
        sim.addDrawingObjectItem(drawingConts.linkCont, nil)
    end
    if drawingConts.linkContN == nil then
        drawingConts.linkContN = sim.addDrawingObject(
                                     sim.drawing_spherepts | sim.drawing_overlay, 0.01, 0, -1, 0,
                                     {1, 1, 1}
                                 )
    else
        sim.addDrawingObjectItem(drawingConts.linkContN, nil)
    end
    if drawingConts.baseCont == nil then
        drawingConts.baseCont = sim.addDrawingObject(
                                    sim.drawing_cubepts | sim.drawing_overlay | sim.drawing_cyclic,
                                    0.01, 0, -1, 1, {1, 0, 1}
                                )
    end
    local w = {0, 0, 0, 1, 0, 0, 0}
    if ikBase ~= -1 then w = simIK._getObjectPose(self.handle, ikBase) end
    sim.addDrawingObjectItem(drawingConts.baseCont, w)
    if drawingConts.jointCont == nil then
        drawingConts.jointCont = {}
        drawingConts.jointCont[1] = sim.addDrawingObject(
                                        sim.drawing_lines | sim.drawing_overlay, 4, 0, -1, 0,
                                        {1, 0.5, 0}
                                    )
        drawingConts.jointCont[2] = sim.addDrawingObject(
                                        sim.drawing_lines | sim.drawing_overlay, 2, 0, -1, 0,
                                        {0, 0.5, 1}
                                    )
        drawingConts.jointCont[3] = sim.addDrawingObject(
                                        sim.drawing_lines | sim.drawing_overlay, 4, 0, -1, 0,
                                        {0.5, 0.5, 0.5}
                                    )
        drawingConts.jointCont[4] = sim.addDrawingObject(
                                        sim.drawing_spherepts | sim.drawing_overlay, 0.012, 0, -1,
                                        0, {1, 0.5, 0}
                                    )
        drawingConts.jointCont[5] = -1
        drawingConts.jointCont[6] = sim.addDrawingObject(
                                        sim.drawing_spherepts | sim.drawing_overlay, 0.012, 0, -1,
                                        0, {0.5, 0.5, 0.5}
                                    )
    else
        sim.addDrawingObjectItem(drawingConts.jointCont[1], nil)
        sim.addDrawingObjectItem(drawingConts.jointCont[2], nil)
        sim.addDrawingObjectItem(drawingConts.jointCont[3], nil)
        sim.addDrawingObjectItem(drawingConts.jointCont[4], nil)
        sim.addDrawingObjectItem(drawingConts.jointCont[6], nil)
    end

    local obj = ikTip
    local prevObj = obj
    while obj ~= -1 and obj ~= ikBase do
        local t = simIK.getObjectType(ikEnv, obj)
        if t == simIK.objecttype_joint then
            local p = simIK._getObjectPose(self.handle, prevObj)
            local m1 = simIK.getObjectMatrix(self.handle, obj, simIK.handle_world)
            local m2 = simIK.getJointMatrix(ikEnv, obj)
            m1 = sim.multiplyMatrices(m1, m2)
            p[4] = m1[4]
            p[5] = m1[8]
            p[6] = m1[12]
            sim.addDrawingObjectItem(drawingConts.linkCont, p)
            local spherical = (simIK.getJointType(ikEnv, obj) == simIK.jointtype_spherical)
            local m = simIK.getJointMode(ikEnv, obj)
            local d = simIK.getJointDependency(ikEnv, obj)
            local hs = 0.025
            local ind1 = 0
            local ind2 = 1
            if spherical then ind1 = 3 end
            if d >= 0 then
                ind2 = 2
                hs = 0.05
            elseif m == simIK.jointmode_passive then
                ind2 = 3
            end
            local mm = simIK.getObjectMatrix(self.handle, obj, simIK.handle_world)
            if spherical then
                sim.addDrawingObjectItem(drawingConts.jointCont[ind1 + ind2], {mm[4], mm[8], mm[12]})
            else
                sim.addDrawingObjectItem(
                    drawingConts.jointCont[ind1 + ind2], {
                        mm[4] - mm[3] * hs, mm[8] - mm[7] * hs, mm[12] - mm[11] * hs,
                        mm[4] + mm[3] * hs, mm[8] + mm[7] * hs, mm[12] + mm[11] * hs,
                    }
                )
            end
        else
            if prevObj ~= obj then
                local p = simIK._getObjectPose(self.handle, obj)
                local p2 = simIK._getObjectPose(self.handle, prevObj)
                p[4] = p2[1]
                p[5] = p2[2]
                p[6] = p2[3]
                sim.addDrawingObjectItem(drawingConts.linkCont, p)
                sim.addDrawingObjectItem(drawingConts.linkContN, p)
            end
        end
        prevObj = obj
        obj = simIK.getObjectParent(ikEnv, obj)
    end

    local p = simIK._getObjectPose(self.handle, prevObj)
    p[4] = 0
    p[5] = 0
    p[6] = 0
    if ikBase ~= -1 then
        local p2 = simIK._getObjectPose(self.handle, ikBase)
        p[4] = p2[1]
        p[5] = p2[2]
        p[6] = p2[3]
    end
    sim.addDrawingObjectItem(drawingConts.linkCont, p)

    return self._ikDebug.tips[ikTip].id
end

function IK:eraseDebugOverlay(...)
    local id = checkargs({
        {type = 'int'},
    }, ...)

    if self._ikDebug then
        for tipHandle, tip in pairs(self._ikDebug.tips) do
            if tip.id == id then
                if tip.drawingConts.targetCont ~= nil then
                    sim.removeDrawingObject(tip.drawingConts.targetCont)
                    tip.drawingConts.targetCont = nil
                end
                if tip.drawingConts.tipCont ~= nil then
                    sim.removeDrawingObject(tip.drawingConts.tipCont)
                    tip.drawingConts.tipCont = nil
                end
                if tip.drawingConts.linkCont ~= nil then
                    sim.removeDrawingObject(tip.drawingConts.linkCont)
                    tip.drawingConts.linkCont = nil
                end
                if tip.drawingConts.linkContN ~= nil then
                    sim.removeDrawingObject(tip.drawingConts.linkContN)
                    tip.drawingConts.linkContN = nil
                end
                if tip.drawingConts.baseCont ~= nil then
                    sim.removeDrawingObject(tip.drawingConts.baseCont)
                    tip.drawingConts.baseCont = nil
                end
                if tip.drawingConts.jointCont ~= nil then
                    sim.removeDrawingObject(tip.drawingConts.jointCont[1])
                    sim.removeDrawingObject(tip.drawingConts.jointCont[2])
                    sim.removeDrawingObject(tip.drawingConts.jointCont[3])
                    sim.removeDrawingObject(tip.drawingConts.jointCont[4])
                    sim.removeDrawingObject(tip.drawingConts.jointCont[6])
                    tip.drawingConts.jointCont = nil
                end
                return
            end
        end
    end
end

function IK:solvePath(...)
    -- simPath can be a Path object handle, or the path data itself
    -- ikPath: a dummy with a pose and parent consistent with simPath
    local ikGroup, ikTarget, ikJoints, simJoints, ikPath, simPath, collisionPairs, opts =
        checkargs({
            {type = 'int'},
            {type = 'int'},
            {type = 'table', size = '1..*', item_type = 'int'},
            {type = 'table', size = '1..*', item_type = 'int'},
            {type = 'int'},
            {union = {{type = 'handle'}, {type = 'table'}}},
            {type = 'table', default = {}},
            {type = 'table', default = {}},
        }, ...)

    local simEigen = require('simEigen')
    collisionPairs = collisionPairs or {}
    local delta = opts.delta or 0.005
    local errorCallback = opts.errorCallback or function(e) end
    local function reportError(...)
        errorCallback(string.format(...))
    end
    local function callStepCb(failed)
        if opts.stepCallback then opts.stepCallback(failed) end
    end

    local pathData = simPath
    if math.type(simPath) == 'integer' and sim.isHandle(simPath) then
        pathData = sim.getBufferProperty(simPath, 'customData.PATH')
        assert(pathData ~= nil and #pathData > 0, 'object does not contain PATH data')
        pathData = sim.unpackDoubleTable(pathData)
    end
    local m = simEigen.Matrix(#pathData // 7, 7, pathData)
    local pathPositions = m:block(1, 1, m:rows(), 3):data()
    local pathQuaternions = m:block(1, 4, m:rows(), 4):data()
    local pathLengths, totalLength = sim.getPathLengths(pathPositions, 3)

    local moveIkTarget = opts.moveIkTarget or function(posAlongPath)
        local pose = sim.getPathInterpolatedConfig(
                         pathData, pathLengths, posAlongPath, nil, {0, 0, 0, 2, 2, 2, 2}
                     )
        if ikPath ~= -1 then
            local pathPose = simIK._getObjectPose(self.handle, ikPath)
            pose = sim.multiplyPoses(pathPose, pose)
        end
        simIK._setObjectPose(self.handle, ikTarget, pose)
    end
    local getConfig = opts.getConfig or partial(map, sim.getJointPosition, simJoints)
    local setConfig = opts.setConfig or partial(foreach, sim.setJointPosition, simJoints)
    local getIkConfig = opts.getIkConfig or
                            partial(map, partial(simIK.getJointPosition, self.handle), ikJoints)
    local setIkConfig = opts.setIkConfig or
                            partial(foreach, partial(simIK.setJointPosition, self.handle), ikJoints)

    local origIkCfg = getIkConfig()

    local cfgs = {}
    local posAlongPath = 0
    local finished = false

    moveIkTarget(0)
    local cfg = self:findConfigs(ikGroup, ikJoints)
    if #cfg == 0 then
        reportError('Failed to find initial config')
        goto fail
    else
        cfg = cfg[1]
    end

    setIkConfig(cfg)

    while not finished do
        if math.abs(posAlongPath - totalLength) < 1e-6 then finished = true end
        moveIkTarget(posAlongPath)
        local ikResult, failureCode = self:_handleGroups({ikGroup}, {callback = opts.jacobianCallback})
        if ikResult ~= simIK.result_success then
            reportError(
                'Failed to perform IK step at t=%.2f (reason: %s)', posAlongPath / totalLength,
                self:getFailureDescription(failureCode)
            )
            goto fail
        end
        if #collisionPairs > 0 then
            local origSimCfg = getConfig()
            setConfig(getIkConfig())
            for i = 1, #collisionPairs, 2 do
                if sim.checkCollision(collisionPairs[i], collisionPairs[i + 1]) ~= 0 then
                    local function getObjectAlias(h)
                        if h == sim.handle_all then return '[[all]]' end
                        local r, a = pcall(sim.getObjectAlias, h)
                        return r and a or h
                    end
                    reportError(
                        'Failed due to collision %s/%s at t=%.2f',
                        getObjectAlias(collisionPairs[i]), getObjectAlias(collisionPairs[i + 1]),
                        posAlongPath / totalLength
                    )
                    setConfig(origSimCfg)
                    goto fail
                end
            end
            setConfig(origSimCfg)
        end
        callStepCb(false)
        table.insert(cfgs, getIkConfig())
        posAlongPath = math.min(posAlongPath + delta, totalLength)
    end

    if cfgs then
        setIkConfig(origIkCfg)
        return cfgs
    end

    ::fail::
    callStepCb(true)
    setIkConfig(origIkCfg)
end

function IK:findConfigs(...)
    local ikGroup, ikJoints, params, otherConfigs = checkargs({
        {type = 'int'},
        {type = 'table', size = '1..*', item_type = 'int'},
        {type = 'table', default_nil = true, nullable = true},
        {type = 'table', size = '1..*', item_type = 'int', default_nil = true, nullable = true},
    }, ...)
    params = params or {}
    if params.findAlt == nil then params.findAlt = true end
    params.maxDist = params.maxDist or 0.3
    params.maxTime = params.maxTime or 0.2
    params.pMetric = params.pMetric or {1.0, 1.0, 1.0, 0.1}
    params.cMetric = params.cMetric or table.rep(1.0, #ikJoints)
    otherConfigs = otherConfigs or {}
    local lb = sim.setStepping(true)
    local retConfs = {}

    local st = sim.getSystemTime()
    while true do
        local ct = sim.getSystemTime()
        local conf = self:_findConfig(
                         ikGroup, ikJoints, params.maxDist,
                         math.max(params.maxTime - (ct - st), 0.01), params.pMetric, params.cb,
                         params.auxData
                     )
        if conf then
            if #retConfs == 0 then
                retConfs = otherConfigs
            end
            local altConfigs = {}
            if params.findAlt then
                altConfigs = _getAltConfigsImpl(self.handle, ikJoints, conf)
                if params.cb then
                    local cnt = 1
                    while cnt <= #altConfigs do
                        if params.cb(altConfigs[cnt], params.auxData) then
                            cnt = cnt + 1
                        else
                            table.remove(altConfigs, cnt)
                        end
                    end
                end
            end
            retConfs[#retConfs + 1] = conf
            for i = 1, #altConfigs do
                retConfs[#retConfs + 1] = altConfigs[i]
            end
        end
        if (not params.findMultiple) or (ct - st >= params.maxTime) then
            break
        end
    end

    if #retConfs > 1 then
        local cc = self:getConfig(ikJoints)
        local configs = {}
        local dists = {}
        for i = 1, #retConfs do
            local d = sim.getConfigDistance(cc, retConfs[i], params.cMetric)
            dists[i] = d
            configs[d] = retConfs[i]
        end
        retConfs = {}
        table.sort(dists)
        for i = 1, #dists do
            retConfs[#retConfs + 1] = configs[dists[i]]
        end
    end
    sim.setStepping(lb)
    return retConfs
end

function IK:getConfig(jh)
    local retVal = {}
    for i = 1, #jh do
        retVal[i] = simIK.getJointPosition(self.handle, jh[i])
    end
    return retVal
end

function IK:setConfig(jh, config)
    for i = 1, #jh do
        simIK.setJointPosition(self.handle, jh[i], config[i])
    end
end

return IK
