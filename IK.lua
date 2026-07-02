local simIK = loadPlugin('simIK')
local simEigen = require'simEigen'
local class = require('middleclass')
local sim = require('sim')
local sim2 = require('sim-2')
local checkargs = require('checkargs-2')
local properties = require('middleclassProperties')

-- module-level bookkeeping that is genuinely cross-cutting (set elsewhere, e.g. python bindings):
local __ = {}

--==================================================================
-- internal (env is passed explicitly because these are pure helpers)
--==================================================================

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
-- IK object class
--==================================================================
local IKObject = class('IKObject')
properties.enable(IKObject)

IKObject.static.property('objectType', {
    type = sim.propertytype_string,
    flags = sim.propertyinfo_silent | sim.propertyinfo_notwritable | sim.propertyinfo_modelhashexclude,
    info = {description = "The object type"},
    get = function(self)
        local t = simIK.getObjectType(self._ik.handle, self.handle)
        local retVal = 'unknown'
        local items = {[simIK.objecttype_dummy] = 'dummy', [simIK.objecttype_joint] = 'joint'}
        local r = items[t]
        if r then
            retVal = r
        end
        return retVal
    end,
})

function IKObject:setPose(p, opt)
    p = checkargs.checkargsEx({funcName = 'IKObject:setPose'}, {
        {type = 'pose'},
    }, p)
    opt = opt or {}
    local hRel = -1
    if opt.relativeToObject then
        hRel = opt.relativeToObject.handle
    end
    simIK.setObjectTransformation(self._ik.handle, self.handle, p.t:data(), p.q:data(), hRel)
end

function IKObject:getPose(opt)
    opt = opt or {}
    local hRel = -1
    if opt.relativeToObject then
        hRel = opt.relativeToObject.handle
    end
    local t, q = simIK.getObjectTransformation(self._ik.handle, self.handle, hRel)
    return simEigen.Pose(t, q)
end

function IKObject:setPosition(p, opt)
    p = checkargs.checkargsEx({funcName = 'IKObject:setPosition'}, {
        {type = 'vector3'},
    }, p)
    opt = opt or {}
    local hRel = -1
    if opt.relativeToObject then
        hRel = opt.relativeToObject.handle
    end
    local t, q = simIK.getObjectTransformation(self._ik.handle, self.handle, hRel)
    simIK.setObjectTransformation(self._ik.handle, self.handle, p:data(), q, hRel)
end

function IKObject:getPosition(opt)
    opt = opt or {}
    local hRel = -1
    if opt.relativeToObject then
        hRel = opt.relativeToObject.handle
    end
    local t, q = simIK.getObjectTransformation(self._ik.handle, self.handle, hRel)
    return simEigen.Vector(t)
end

function IKObject:setQuaternion(p, opt)
    p = checkargs.checkargsEx({funcName = 'IKObject:setQuaternion'}, {
        {type = 'quaternion'},
    }, p)
    opt = opt or {}
    local hRel = -1
    if opt.relativeToObject then
        hRel = opt.relativeToObject.handle
    end
    local t, q = simIK.getObjectTransformation(self._ik.handle, self.handle, hRel)
    simIK.setObjectTransformation(self._ik.handle, self.handle, t, p:data(), hRel)
end

function IKObject:getQuaternion(opt)
    opt = opt or {}
    local hRel = -1
    if opt.relativeToObject then
        hRel = opt.relativeToObject.handle
    end
    local t, q = simIK.getObjectTransformation(self._ik.handle, self.handle, hRel)
    return simEigen.Quaternion(q)
end

function IKObject:initialize(ik, objectHandle)
    self._ik = ik
    self.handle = objectHandle
end

--==================================================================
-- IK joint class
--==================================================================
local IKJoint = class("IKJoint", IKObject)
properties.enable(IKJoint)

IKJoint.static.property('passive', {
    type = sim.propertytype_bool,
    info = {description = "Whether the joint participates in IK resolution"},
    get = function(self) 
        return simIK.getJointMode(self._ik.handle, self.handle) == simIK.jointmode_passive
    end,
    set = function(self, value)
        value = checkargs.checkargsEx({funcName = 'IKJoint.passive property'}, {
            {type = 'bool'},
        }, value)
        local v = simIK.jointmode_ik
        if value then
            v = simIK.jointmode_passive
        end
        simIK.setJointMode(self._ik.handle, self.handle, v)
    end,
})

IKJoint.static.property('jointPosition', {
    type = sim.propertytype_float,
    info = {description = "The prismatic/revolute joint's linear/angular displacement"},
    get = function(self) 
        return simIK.getJointPosition(self._ik.handle, self.handle)
    end,
    set = function(self, value)
        value = checkargs.checkargsEx({funcName = 'IKJoint.position property'}, {
            {type = 'float'},
        }, value)
        simIK.setJointPosition(self._ik.handle, self.handle, value)
    end,
})

IKJoint.static.property('jointQuaternion', {
    type = sim.propertytype_quaternion,
    info = {description = "The spherical joint's orientation"},
    get = function(self) 
        local p, q = simIK.getJointTransformation(self._ik.handle, self.handle)
        return simEigen.quaternion(q)
    end,
    set = function(self, value)
        value = checkargs.checkargsEx({funcName = 'IKJoint.quaternion property'}, {
            {type = 'quaternion'},
        }, value)
        simIK.setSphericalJointRotation(self._ik.handle, self.handle, value:data())
    end,
})

IKJoint.static.property('jointConfiguration', {
    type = sim.propertytype_floatarray,
    info = {description = "The joint's configuration. 1 value for prismatic and revolute joints, 4 values for a spherical joint"},
    get = function(self)
        local retVal
        if simIK.getJointType(self._ik.handle, self.handle) == simIK.jointtype_spherical then
            local p, q = simIK.getJointTransformation(self._ik.handle, self.handle)
            retVal = q:data()
        else
            retVal = {simIK.getJointPosition(self._ik.handle, self.handle)}
        end
        return retVal
    end,
    set = function(self, value)
        value = checkargs.checkargsEx({funcName = 'IKJoint.configuration property'}, {
            {type = 'table', itemType = 'float', size = "1..4"},
        }, value)
        if simIK.getJointType(self._ik.handle, self.handle) == simIK.jointtype_spherical then
            simIK.setSphericalJointRotation(self._ik.handle, self.handle, value)
        else
            simIK.setJointPosition(self._ik.handle, self.handle, value[1])
        end
    end,
})

IKJoint.static.property('weight', {
    type = sim.propertytype_float,
    info = {description = "The joint weight"},
    get = function(self)
        return simIK.getJointWeight(self._ik.handle, self.handle)
    end,
    set = function(self, value)
        value = checkargs.checkargsEx({funcName = 'IKJoint.weight property'}, {
            {type = 'float'},
        }, value)
        simIK.setJointWeight(self._ik.handle, self.handle, value)
    end,
})

IKJoint.static.property('limitMargin', {
    type = sim.propertytype_float,
    info = {description = "The joint limit margin"},
    get = function(self)
        return simIK.getJointLimitMargin(self._ik.handle, self.handle)
    end,
    set = function(self, value)
        value = checkargs.checkargsEx({funcName = 'IKJoint.limitMargin property'}, {
            {type = 'float'},
        }, value)
        simIK.setJointLimitMargin(self._ik.handle, self.handle, value)
    end,
})

IKJoint.static.property('maxStepSize', {
    type = sim.propertytype_float,
    info = {description = "The joint maximum step size"},
    get = function(self)
        return simIK.getJointMaxStepSize(self._ik.handle, self.handle)
    end,
    set = function(self, value)
        value = checkargs.checkargsEx({funcName = 'IKJoint.maxStepSize property'}, {
            {type = 'float'},
        }, value)
        simIK.setJointMaxStepSize(self._ik.handle, self.handle, value)
    end,
})

IKJoint.static.property('jointType', {
    type = sim.propertytype_string,
    flags = sim.propertyinfo_silent | sim.propertyinfo_notwritable | sim.propertyinfo_modelhashexclude,
    info = {description = "The joint type"},
    get = function(self)
        local t = simIK.getJointType(self._ik.handle, self.handle)
        local retVal = 'unknown'
        local items = {[simIK.jointtype_prismatic] = 'prismatic', [simIK.jointtype_revolute] = 'revolute', [simIK.jointtype_spherical] = 'spherical'}
        local r = items[t]
        if r then
            retVal = r
        end
        return retVal
    end,
})

IKJoint.static.property('bounds', {
    type = sim.propertytype_floatarray,
    flags = sim.propertyinfo_silent | sim.propertyinfo_notwritable | sim.propertyinfo_modelhashexclude,
    info = {description = "The joint lower and upper bounds"},
    get = function(self)
        local t = simIK.getJointType(self._ik.handle, self.handle)
        local cycl, interv = simIK.getJointInterval(self._ik.handle, self.handle)
        local retVal = {}
        if t ~= simIK.jointtype_spherical then
            if cycl then
                retVal = {-math.pi, math.pi}
            else
                retVal = {interv[1], interv[1] + interv[2]}
            end
        end
        return retVal
    end,
})

IKJoint.static.property('searchMetric', {
    type = sim.propertytype_float,
    info = {description = "The joint weight in search operations"},
    get = function(self)
        return self._searchMetric
    end,
    set = function(self, value)
        value = checkargs.checkargsEx({funcName = 'IKJoint.searchMetric property'}, {
            {type = 'float'},
        }, value)
        self._searchMetric = value
    end,
})

function IKJoint:initialize(ik, objectHandle)
    IKObject.initialize(self, ik, objectHandle)
    self._searchMetric = 1.0
end

--==================================================================
-- IK element class
--==================================================================
local IKElement = class('IKElement')
properties.enable(IKElement)

IKElement.static.property('constraints', {
    type = sim.propertytype_int,
    info = {description = "Element constraints"},
    get = function(self) 
        return simIK.getElementConstraints(self._ik.handle, self._group.handle, self.handle)
    end,
    set = function(self, value)
        value = checkargs.checkargsEx({funcName = 'IKElement.constraints property'}, {
            {type = 'int'},
        }, value)
        simIK.setElementConstraints(self._ik.handle, self._group.handle, self.handle, value)
    end,
})

IKElement.static.property('enabled', {
    type = sim.propertytype_bool,
    info = {description = "Element enable state"},
    get = function(self) 
        return simIK.getElementFlags(self._ik.handle, self._group.handle, self.handle) & 1
    end,
    set = function(self, value)
        value = checkargs.checkargsEx({funcName = 'IKElement.enabled property'}, {
            {type = 'bool'},
        }, value)
        value = value and 1 or 0
        simIK.setElementFlags(self._ik.handle, self._group.handle, self.handle, value)
    end,
})

IKElement.static.property('precision', {
    type = sim.propertytype_floatarray,
    info = {description = "Element precision"},
    get = function(self) 
        return simIK.getElementPrecision(self._ik.handle, self._group.handle, self.handle)
    end,
    set = function(self, value)
        value = checkargs.checkargsEx({funcName = 'IKElement.precision property'}, {
            {type = 'table', itemType = 'float', size = 2},
        }, value)
        simIK.setElementPrecision(self._ik.handle, self._group.handle, self.handle, value)
    end,
})

IKElement.static.property('weights', {
    type = sim.propertytype_floatarray,
    info = {description = "Element weights"},
    get = function(self) 
        return simIK.getElementWeights(self._ik.handle, self._group.handle, self.handle)
    end,
    set = function(self, value)
        value = checkargs.checkargsEx({funcName = 'IKElement.weights property'}, {
            {type = 'table', itemType = 'float', size = 2},
        }, value)
        simIK.setElementWeights(self._ik.handle, self._group.handle, self.handle, value)
    end,
})

function IKElement:initialize(ik, group, elementHandle, opt)
    self._ik = ik
    self._group = group
    self.handle = elementHandle
    
    opt = opt or {}

    checkargs.checkfields({funcName = 'IKElement:new'}, {
        {name = 'precision', type = 'table', size = 2, itemType = 'float', nullable = true},
        {name = 'weights', type = 'table', size = 3, itemType = 'float', nullable = true},
        {name = 'constraints', type = 'int', nullable = true},
        {name = 'enabled', type = 'bool', nullable = true},
    }, opt)

    if opt.precision then
        simIK.setElementPrecision(self._ik.handle, self._group.handle, self.handle, opt.precision)
    end
    if opt.weights then
        simIK.setElementWeights(self._ik.handle, self._group.handle, self.handle, opt.weights)
    end
    if opt.enabled then
        simIK.setElementFlags(self._ik.handle, self._group.handle, self.handle, opt.enabled and 1 or 0)
    end
end

--==================================================================
-- IK group class
--==================================================================
local IKGroup = class('IKGroup')
properties.enable(IKGroup)

IKGroup.static.property('method', {
    type = sim.propertytype_int,
    info = {description = "Group calculation method"},
    get = function(self) 
        local m, damp, it = simIK.getGroupCalculation(self._ik.handle, self.handle)
        local retVal = 'unknown'
        local items = {[simIK.method_pseudo_inverse] = 'pseudoInverse', [simIK.method_undamped_pseudo_inverse] = 'undampedPseudoInverse', [simIK.method_damped_least_squares] = 'dampedLeastSquares', [simIK.method_jacobian_transpose] = 'jacobianTranspose'}
        local r = items[m]
        if r then
            retVal = r
        end
        return retVal
    end,
    set = function(self, value)
        value = checkargs.checkargsEx({funcName = 'IKGroup.method property'}, {
            {enum = {pseudoInverse = simIK.method_pseudo_inverse, undampedPseudoInverse = simIK.method_undamped_pseudo_inverse, dampedLeastSquares = simIK.method_damped_least_squares, jacobianTranspose = simIK.method_jacobian_transpose}},
        }, value)
        local m, damp, it = simIK.getGroupCalculation(self._ik.handle, self.handle)
        simIK.setGroupCalculation(self._ik.handle, self.handle, value, damp, it)
    end,
})

IKGroup.static.property('maxIterations', {
    type = sim.propertytype_int,
    info = {description = "Maximum number of iterations"},
    get = function(self) 
        local m, damp, it = simIK.getGroupCalculation(self._ik.handle, self.handle)
        return it
    end,
    set = function(self, value)
        value = checkargs.checkargsEx({funcName = 'IKGroup.maxIterations property'}, {
            {type = 'int'},
        }, value)
        local m, damp, it = simIK.getGroupCalculation(self._ik.handle, self.handle)
        simIK.setGroupCalculation(self._ik.handle, self.handle, m, damp, value)
    end,
})

IKGroup.static.property('damping', {
    type = sim.propertytype_float,
    info = {description = "Damping coefficient"},
    get = function(self) 
        local m, damp, it = simIK.getGroupCalculation(self._ik.handle, self.handle)
        return damp
    end,
    set = function(self, value)
        value = checkargs.checkargsEx({funcName = 'IKGroup.damping property'}, {
            {type = 'float'},
        }, value)
        local m, damp, it = simIK.getGroupCalculation(self._ik.handle, self.handle)
        simIK.setGroupCalculation(self._ik.handle, self.handle, m, value, it)
    end,
})

function IKGroup:initialize(ik, groupHandle, opt)
    self._ik = ik
    self.handle = groupHandle
    self.elements = {}
    self.joints = {}
    opt = opt or {}
    
    checkargs.checkfields({funcName = 'IKGroup:new'}, {
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

    local meth, damp, it = simIK.getGroupCalculation(self._ik.handle, self.handle)
    if opt.method then
        meth = opt.method
    end
    if opt.damping then
        damp = opt.damping
    end
    if opt.maxIterations then
        it = opt.maxIterations
    end
    simIK.setGroupCalculation(self._ik.handle, self.handle, meth, damp, it)
    local fl = simIK.getGroupFlags(self._ik.handle, self.handle)
    if opt.enabled ~= nil then
        fl = fl & simIK.group_enabled
        if not opt.enabled then
            fl = fl - simIK.group_enabled
        end
    end

    if opt.ignoreMaxSteps ~= nil then
        fl = fl & simIK.group_ignoremaxsteps
        if not opt.ignoreMaxSteps then
            fl = fl - simIK.group_ignoremaxsteps
        end
    end

    if opt.restoreOnBadLinTol ~= nil then
        fl = fl & simIK.group_restoreonbadlintol
        if not opt.restoreOnBadLinTol then
            fl = fl - simIK.group_restoreonbadlintol
        end
    end

    if opt.restoreOnBadAngTol ~= nil then
        fl = fl & simIK.group_restoreonbadangtol
        if not opt.restoreOnBadAngTol then
            fl = fl - simIK.group_restoreonbadangtol
        end
    end

    if opt.avoidLimits ~= nil then
        fl = fl & simIK.group_avoidlimits
        if not opt.avoidLimits then
            fl = fl - simIK.group_avoidlimits
        end
    end

    if opt.stopOnLimitHit ~= nil then
        fl = fl & simIK.group_stoponlimithit
        if not opt.stopOnLimitHit then
            fl = fl - simIK.group_stoponlimithit
        end
    end
    simIK.setGroupFlags(self._ik.handle, self.handle, fl)
end

function IKGroup:solve(opt)
    local retVal = false
    local reason = simIK.calc_notperformed
    local achievedPrecision = {0.0, 0.0}
    local ok
    for k, v in pairs(self.elements) do
        if not v.passive then
            ok = true
            break
        end
    end
    if ok then
        opt = opt or {}
        
        checkargs.checkfields({funcName = 'IKGroup:solve'}, {
            {name = 'debug', type = 'int', default = 0},
            {name = 'syncWorlds', type = 'bool', default = true},
            {name = 'allowError', type = 'bool', default = true},
        }, opt)

        if opt.syncWorlds then 
            self:syncFromSim()
        end
        retVal, reason, achievedPrecision = self._ik:_handleGroups({self.handle}, opt)
        if (reason & (simIK.calc_notperformed | simIK.calc_cannotinvert | simIK.calc_invalidcallbackdata)) == 0 then
            -- no serious error
            if opt.allowError then
                retVal = true
                if opt.syncWorlds then
                    self:syncToSim()
                end
            else
                retVal = (reason == 0)
            end
        else
            -- serious error
            retVal = false
        end
        self._ik:_debugGroupIfNeeded(self.handle, opt.debug)
        if (not retVal) and opt.syncWorlds then 
            self:syncFromSim() -- not really necessary, but better to keep IK world ordered
        end
    end
    return retVal, reason, achievedPrecision
end

function IKGroup:addElementFromScene(base, tip, target, const, opt)
    base, tip, target, const, opt = checkargs.checkargsEx({funcName = 'addElementFromScene'}, {
        {type = 'handle', nullable = true},
        {type = 'handle'},
        {type = 'handle'},
        {type = 'int'},
        {type = 'table', nullable = true},
    }, base, tip, target, const, opt)

    local ik = self._ik
    local baseH = -1
    if base then
        baseH = base.handle
    end
    local tipH = tip.handle
    local targetH = target.handle
    opt = opt or {}
    local elementHandle, simToIkMap = ik:_addElementFromScene(self.handle, baseH, tipH, targetH, const)
    opt.constraints = const
    local element = IKElement(ik, self, elementHandle, opt)
    self.elements[elementHandle] = element
    
    -- Wrap simIK objects:
    for k, v in pairs(simToIkMap) do
        if self._ik.objects[k] == nil then
            if simIK.getObjectType(ik.handle, v) == simIK.objecttype_joint then
                local joint = IKJoint(ik, v)
                ik.objects[k] = joint
                ik.joints[k] = joint
            else
                local obj = IKObject(ik, v)
                ik.objects[k] = obj
            end
        end
    end
    
    local obj = tip.parent
    while obj ~= base do
        if obj.type == 'joint' and ik.joints[obj.handle] then
            self.joints[obj.handle] = ik.joints[obj.handle]
        end
        obj = obj.parent
    end
    self.simToIkMap = simToIkMap
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
    self.objects = {}
    self.joints = {}
    self.groups = {}
    self._groupMap = {}
    
    -- internal use:
    self._ikGroupData = {}
    self._ikGroupHandles = {}
    self._simToIkMap = {}
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
    local groupHandle = simIK.createIkGroup(self.handle)
    self._ikGroupHandles[#self._ikGroupHandles + 1] = groupHandle
    local group = IKGroup(self, groupHandle, opt)
    self.groups[#self.groups + 1] = group
    self._groupMap[groupHandle] = group
    return group
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

function IK:_debugGroupIfNeeded(ikGroup, debugFlags)
    local groupData = self._ikGroupData[ikGroup]
    if not groupData then return end

    local p = sim.getIntProperty(sim.handle_app, 'signal.simIK.debug_world', {noError = true})
    if (p and (p & 1) ~= 0) or ((debugFlags & 1) ~= 0) then
        local lb = sim.setStepping(true)
        groupData.visualDebug = {}
        for i = 1, #groupData.targetTipBaseTriplets do
            groupData.visualDebug[i] = self:_createDebugOverlay(
                                           groupData.targetTipBaseTriplets[i][5],
                                           groupData.targetTipBaseTriplets[i][6]
                                       )
        end
        sim.setStepping(lb)
    else
        if groupData.visualDebug then
            for i = 1, #groupData.visualDebug do
                self:_eraseDebugOverlay(groupData.visualDebug[i])
            end
        end
        groupData.visualDebug = {}
    end
end

function IK:_addElementFromScene(ikGroup, simBase, simTip, simTarget, constraints)
    local ikEnv = self.handle
    local lb = sim.setStepping(true)

    local groupData = self._ikGroupData[ikGroup]
    -- simToIkMap is scoped by env (not by group) to avoid duplicates:
    local simToIkMap = self._simToIkMap
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
            simIK.setObjectMatrix(self.handle, ikJo_s, sim.getObjectMatrix(slave), simIK.handle_world)
            groupData.joints[slave] = ikJo_s
        end
        if ikJo_m == nil then
            ikJo_m = createIkJointFromSimJoint(master)
            simToIkMap[master] = ikJo_m
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
    return ikElement, simToIkMap
end

function IK:remove()
    local lb = sim.setStepping(true)
    for k, v in pairs(self._ikGroupData) do
        if v.visualDebug then
            for i = 1, #v.visualDebug do
                self:_eraseDebugOverlay(v.visualDebug[i])
            end
        end
    end
    self.groups = {}
    self.objects = {}
    self.joints = {}
    self._groupMap = {}
    self._ikGroupData = {}
    self._ikGroupHandles = {}
    self._simToIkMap = {}
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

function IK:_debugJacobianDisplay(inData)
    local groupData = self._ikGroupData[inData.group.handle]
    local groupIdStr = string.format('env:%d/group:%d', self.handle, inData.group.handle)
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
    local retVal = false
    local reason = simIK.calc_notperformed
    local achievedPrecision = {0.0, 0.0}

    opt = opt or {}
    checkargs.checkfields({funcName = 'IK:solve'}, {
        {name = 'debug', type = 'int', default = 0},
        {name = 'syncWorlds', type = 'bool', default = true},
        {name = 'allowError', type = 'bool', default = true},
    }, opt)

    local sync = opt.syncWorlds
    if sync then
        opt.synWorlds = false
        self:syncFromSim()
    end

    for i = 1, #self.groups do
        local ret, rea, prec = self.groups[i]:solve(opt)
        if (rea & simIK.calc_notperformed) == 0 then
            if reason == simIK.calc_notperformed then
                reason = 0
            end
            reason = reason | rea
            for j = 1, 2 do
                if prec[j] > achievedPrecision[j] then
                    achievedPrecision[j] = prec[j]
                end
            end
            retVal = ret
            if not retVal then
                break
            end
        end
    end

    if sync then
        if retVal then
            self:syncToSim()
        else
            self:syncFromSim() -- not really necessary, but better to keep IK world ordered
        end
    end
    return retVal, reason, achievedPrecision
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
        data.group = self._groupMap[groupId]
        if pythonCallback then
            data.jacobian = jacobian
            data.e = errorVect
        else
            data.jacobian = simEigen.Matrix(#rows_constr, #cols_handles, jacobian)
            data.e = simEigen.Vector(errorVect)
        end
        for i = 1, #rows_constr do
            data.rows[i] = {constraint = rows_constr[i], element = data.group.elements[rows_ikEl[i]]}
        end
        for i = 1, #cols_handles do
            data.cols[i] = {joint = cols_handles[i], dofIndex = cols_dofIndex[i]}
        end
        data.iteration = iteration
        if debugJacobian then self:_debugJacobianDisplay(data) end
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

function IK:_createDebugOverlay(...)
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

function IK:_eraseDebugOverlay(...)
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

return IK
