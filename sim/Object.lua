return {
    extend = function(sim)
        sim.PropertyGroup = setmetatable(
            {
                __index = function(self, k)
                    local prefix = rawget(self, '__prefix')
                    if prefix ~= '' then k = prefix .. '.' .. k end
                    if sim.getPropertyInfo(self.__handle, k) then
                        return sim.getProperty(self.__handle, k)
                    end
                    if sim.getPropertyName(self.__handle, 0, {prefix = k .. '.'}) then
                        return sim.PropertyGroup(self.__handle, {prefix = k})
                    end
                end,
                __newindex = function(self, k, v)
                    local prefix = rawget(self, '__prefix')
                    if prefix ~= '' then k = prefix .. '.' .. k end
                    sim.setProperty(self.__handle, k, v)
                end,
                __tostring = function(self)
                    local prefix = rawget(self, '__prefix')
                    return 'sim.PropertyGroup(' .. self.__handle .. ', {prefix = ' .. _S.anyToString(prefix) .. '})'
                end,
                __pairs = function(self)
                    local prefix = rawget(self, '__prefix')
                    if prefix ~= '' then prefix = prefix .. '.' end
                    local props = {}
                    local i = 0
                    while true do
                        local pname = sim.getPropertyName(self.__handle, i, {prefix = prefix})
                        if pname == nil then break end
                       pname = string.stripprefix(pname, prefix)
                        local pname2 = string.gsub(pname, '%..*$', '')
                        if pname == pname2 then
                            local ptype, pflags, descr = sim.getPropertyInfo(self.__handle, prefix .. pname)
                            local readable = pflags & 2 == 0
                            if readable then
                                props[pname2] = sim.getProperty(self.__handle, prefix .. pname)
                            end
                        elseif props[pname2] == nil then
                            props[pname2] = sim.PropertyGroup(self.__handle, {prefix = prefix .. pname})
                        end
                        i = i + 1
                    end
                    if self.__obj then
                        props.children = self.__obj.children
                    end
                    local function stateless_iter(self, k)
                        local v
                        k, v = next(props, k)
                        if v ~= nil then return k, v end
                    end
                    return stateless_iter, self, nil
                end,
            },
            {
                __call = function(self, handle, opts)
                    opts = opts or {}
                    local obj = {__handle = handle, __prefix = opts.prefix or '', __obj = opts.obj}
                    return setmetatable(obj, sim.PropertyGroup)
                end,
            }
        )

        sim.Object = setmetatable(
            {
                __index = function(self, k)
                    -- int indexing for accessing siblings:
                    if math.type(k) == 'integer' then
                        assert(self.__query)
                        return sim.Object(self.__query, {index = k})
                    end

                    -- lookup existing properties first:
                    local v = rawget(self, k)
                    if v then return v end

                    -- redirect to default property group otherwise:
                    return self.__properties[k]
                end,
                __newindex = function(self, k, v)
                    self.__properties[k] = v
                end,
                __len = function(self)
                    return self.__handle
                end,
                __tostring = function(self)
                    return 'sim.Object(' .. self.__handle .. ')'
                end,
                __pairs = function(self)
                    --local itertools = require 'itertools'
                    --return itertools.chain(self.__properties, self.__methods)
                    return pairs(self.__properties)
                end,
                __div = function(self, path)
                    assert(self.__handle ~= sim.handle_app)
                    local opts = {}
                    if self.__handle == sim.handle_scene then
                        if path:sub(1, 1) ~= '/' then path = '/' .. path end
                    else
                        if path:sub(1, 2) ~= './' then path = './' .. path end
                        opts.proxy = self.__handle
                    end
                    return sim.Object(path, opts)
                end,
            },
            {
                __call = function(self, handle, opts)
                    if handle == '/' then return sim.Object(sim.handle_scene) end
                    if handle == '@' then return sim.Object(sim.handle_app) end

                    opts = opts or {}

                    local obj = {__handle = handle,}

                    if type(handle) == 'string' then
                        obj.__handle = sim.getObject(handle, opts)
                        obj.__query = handle
                    else
                        assert(math.type(handle) == 'integer', 'invalid type for handle')
                        assert(sim.isHandle(handle) or table.find({sim.handle_app, sim.handle_scene}, handle), 'invalid handle')
                        if sim.isHandle(handle) then
                            obj.__query = sim.getObjectAlias(handle)
                        end
                    end

                    -- this property group exposes object's top-level properties as self's table keys (via __index):
                    obj.__properties = sim.PropertyGroup(obj.__handle, {obj = obj})

                    -- 'children' property provides a way to access direct children by index or by name:
                    obj.children = setmetatable({}, {
                        __index = function(self, k)
                            if type(k) == 'string' then
                                return obj / k
                            elseif math.type(k) == 'integer' then
                                return sim.Object(sim.getObjectChild(obj.__handle, k))
                            end
                        end,
                        __pairs = function(self)
                            local r = {}
                            for i, h in ipairs(sim.getObjectsInTree(obj.__handle, sim.handle_all, 3)) do
                                r[sim.getObjectAlias(h)] = sim.Object(h)
                            end
                            local function stateless_iter(self, k)
                                local v
                                k, v = next(r, k)
                                if v ~= nil then return k, v end
                            end
                            return stateless_iter, self, nil
                        end,
                        __ipairs = function(self)
                            local function stateless_iter(self, i)
                                i = i + 1
                                local h = sim.getObjectChild(obj.__handle, i)
                                if h ~= -1 then return i, sim.Object(h) end
                            end
                            return stateless_iter, self, -1
                        end,
                    })

                    -- pre-assign user namespaces to property groups:
                    for _, namespace in ipairs{'customData', 'signal', 'namedParam'} do
                        obj[namespace] = sim.PropertyGroup(obj.__handle, {prefix = namespace})
                    end

                    local sim_
                    sim, sim_ = {}, sim
                    sim.addForce = {}
                    sim.addItemToCollection = {}
                    sim.addReferencedHandle = {}
                    sim.alignShapeBB = {}
                    sim.checkCollision = {}
                    sim.checkCollisionEx = {}
                    sim.checkCollisionEx = {}
                    sim.checkOctreePointOccupancy = {type = 'ocTree', }
                    sim.checkProximitySensor = {type = 'proximitySensor', }
                    sim.checkProximitySensorEx = {type = 'proximitySensor', }
                    sim.checkProximitySensorEx2 = {type = 'proximitySensor', }
                    sim.checkVisionSensor = {type = 'visionSensor', }
                    sim.checkVisionSensorEx = {type = 'visionSensor', }
                    sim.computeMassAndInertia = {}
                    sim.executeScriptString = {type = 'script', }
                    sim.getApiFunc = {type = 'script', }
                    sim.getApiInfo = {type = 'script', }
                    sim.getExtensionString = {}
                    sim.getObject = {}
                    sim.getObjectMatrix = {}
                    sim.getObjectOrientation = {}
                    sim.getObjectPose = {}
                    sim.getObjectPosition = {}
                    sim.getObjectQuaternion = {}
                    sim.getObjectsInTree = {}
                    sim.getReferencedHandles = {}
                    sim.getReferencedHandle = {}
                    sim.getReferencedHandlesTags = {}
                    sim.getScriptFunctions = {type = 'script', }
                    sim.getStackTraceback = {type = 'script', }
                    sim.initScript = {type = 'script', }
                    sim.insertObjectIntoOctree = {type = 'ocTree', }
                    sim.insertObjectIntoPointCloud = {type = 'pointCloud', }
                    sim.insertPointsIntoPointCloud = {type = 'pointCloud', }
                    sim.insertVoxelsIntoOctree = {type = 'ocTree', }
                    sim.intersectPointsWithPointCloud = {type = 'pointCloud', }
                    sim.loadScene = {type = 'scene', }
                    sim.readVisionSensor = {type = 'visionSensor', }
                    sim.relocateShapeFrame = {type = 'shape', }
                    sim.removeModel = {}
                    sim.removePointsFromPointCloud = {type = 'pointCloud', }
                    sim.removeReferencedObjects = {}
                    sim.removeVoxelsFromOctree = {type = 'ocTree', }
                    sim.resetDynamicObject = {}
                    sim.resetGraph = {type = 'graph', }
                    sim.resetProximitySensor = {type = 'proximitySensor', }
                    sim.resetVisionSensor = {type = 'visionSensor', }
                    sim.saveModel = {}
                    sim.saveScene = {type = 'scene', }
                    sim.scaleObject = {}
                    sim.setObjectMatrix = {}
                    sim.setObjectOrientation = {}
                    sim.setObjectPose = {}
                    sim.setObjectPosition = {}
                    sim.setObjectQuaternion = {}
                    sim.setReferencedHandles = {}
                    sim.setShapeBB = {}
                    sim.subtractObjectFromOctree = {type = 'ocTree', }
                    sim.subtractObjectFromPointCloud = {type = 'pointCloud', }
                    sim.ungroupShape = {type = 'shape', }
                    sim.visitTree = {}
                    sim.getShapeAppearance = {type = 'shape', }
                    sim.setShapeAppearance = {type = 'shape', }
                    sim.setBoolProperty = {}
                    sim.getBoolProperty = {}
                    sim.setIntProperty = {}
                    sim.getIntProperty = {}
                    sim.setLongProperty = {}
                    sim.getLongProperty = {}
                    sim.setFloatProperty = {}
                    sim.getFloatProperty = {}
                    sim.setStringProperty = {}
                    sim.getStringProperty = {}
                    sim.setBufferProperty = {}
                    sim.getBufferProperty = {}
                    sim.setTableProperty = {}
                    sim.getTableProperty = {}
                    sim.setIntArray2Property = {}
                    sim.getIntArray2Property = {}
                    sim.setVector2Property = {}
                    sim.getVector2Property = {}
                    sim.setVector3Property = {}
                    sim.getVector3Property = {}
                    sim.setQuaternionProperty = {}
                    sim.getQuaternionProperty = {}
                    sim.setPoseProperty = {}
                    sim.getPoseProperty = {}
                    sim.setColorProperty = {}
                    sim.getColorProperty = {}
                    sim.setFloatArrayProperty = {}
                    sim.getFloatArrayProperty = {}
                    sim.setIntArrayProperty = {}
                    sim.getIntArrayProperty = {}
                    sim.removeProperty = {}
                    sim.getPropertyName = {}
                    sim.getPropertyInfo = {}
                    sim.setEventFilters = {}
                    sim.getProperty = {}
                    sim.setProperty = {}
                    sim.getPropertyTypeString = {}
                    sim.getProperties = {}
                    sim.setProperties = {}
                    sim.getPropertiesInfos = {}
                    local methods = sim
                    sim = sim_
                    local t = sim.getStringProperty(obj.__handle, 'objectType', {noError = true})
                    if not t and obj.__handle == sim.handle_scene then t = 'scene' end
                    if not t and obj.__handle == sim.handle_app then t = 'app' end
                    obj.__methods = {}
                    for method, info in pairs(methods) do
                        if (info.type or t) == t then
                            obj[method] = function(self, ...)
                                return sim[method](self.__handle, ...)
                            end
                            obj.__methods[method] = obj[method]
                        end
                    end

                    return setmetatable(obj, sim.Object)
                end,
            }
        )

        sim.Scene = sim.Object(sim.handle_scene)
        sim.App = sim.Object(sim.handle_app)
    end
}
