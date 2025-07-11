return {
    extend = function(sim)
        sim.PropertyGroup = setmetatable(
            {
                __index = function(self, k)
                    local prefix = rawget(self, '__prefix')
                    if prefix ~= '' then k = prefix .. '.' .. k end
                    if self.__object:getPropertyInfo(k) then
                        local t = sim.getPropertyTypeString(self.__object:getPropertyInfo(k))
                        return self.__object['get' .. t:capitalize() .. 'Property'](self.__object, k)
                    end
                    if self.__object:getPropertyName(0, {prefix = k .. '.'}) then
                        return sim.PropertyGroup(self.__object, {prefix = k})
                    end
                end,
                __newindex = function(self, k, v)
                    local prefix = rawget(self, '__prefix')
                    if prefix ~= '' then k = prefix .. '.' .. k end
                    local t = sim.getPropertyTypeString(self.__object:getPropertyInfo(k))
                    self.__object['set' .. t:capitalize() .. 'Property'](self.__object, k, v)
                end,
                __tostring = function(self)
                    local prefix = rawget(self, '__prefix')
                    return 'sim.PropertyGroup(' .. self.__object .. ', {prefix = ' .. _S.anyToString(prefix) .. '})'
                end,
                __pairs = function(self)
                    local prefix = rawget(self, '__prefix')
                    if prefix ~= '' then prefix = prefix .. '.' end
                    local props = {}
                    local i = 0
                    while true do
                        local pname = self.__object:getPropertyName(i, {prefix = prefix})
                        if pname == nil then break end
                        pname = string.stripprefix(pname, prefix)
                        local pname2 = string.gsub(pname, '%..*$', '')
                        if pname == pname2 then
                            local ptype, pflags, descr = self.__object:getPropertyInfo(prefix .. pname)
                            local readable = pflags & 2 == 0
                            if readable then
                                local t = sim.getPropertyTypeString(ptype)
                                props[pname2] = self.__object['get' .. t:capitalize() .. 'Property'](self.__object, prefix .. pname)
                            end
                        elseif props[pname2] == nil then
                            props[pname2] = sim.PropertyGroup(self.__object, {prefix = prefix .. pname})
                        end
                        i = i + 1
                    end
                    props.children = self.__object.children
                    local function stateless_iter(self, k)
                        local v
                        k, v = next(props, k)
                        if v ~= nil then return k, v end
                    end
                    return stateless_iter, self, nil
                end,
            },
            {
                __call = function(self, object, opts)
                    opts = opts or {}
                    local obj = {__object = object, __prefix = opts.prefix or '', __obj = opts.obj}
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
                    local p = self.__properties[k]
                    if p ~= nil then return p end

                    -- otherwise as a function call:
                    if self.callFunction then
                        return function(self, ...)
                            return self:callFunction(k, ...)
                        end
                    end
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
                __tohandle = function(self)
                    return self.__handle
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
                    obj.__properties = sim.PropertyGroup(obj)

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
                        obj[namespace] = sim.PropertyGroup(obj, {prefix = namespace})
                    end

                    -- add methods from sim.* API:

                    local function methodWrapper(kwargs)
                        local apiFunc, info = kwargs[1], kwargs
                        local t = sim.getStringProperty(obj.__handle, 'objectType', {noError = true})
                        if not t and obj.__handle == sim.handle_scene then t = 'scene' end
                        if not t and obj.__handle == sim.handle_app then t = 'app' end
                        if (info.objType or t) == t then return apiFunc end
                    end

                    obj.__methods = {
                        addItemToCollection = methodWrapper{ sim.addItemToCollection, objType = 'collection', },
                        addForce = methodWrapper{ sim.addForce, objType = 'shape', },
                        addForceAndTorque = methodWrapper{ sim.addForceAndTorque, objType = 'shape', },
                        addReferencedHandle = methodWrapper{ sim.addReferencedHandle, },
                        alignBB = methodWrapper{ sim.alignShapeBB, objType = 'shape', },
                        callFunction = methodWrapper{ sim.callScriptFunction, objType = 'script', },
                        checkCollision = methodWrapper{ sim.checkCollision, },
                        checkPointOccupancy = methodWrapper{ sim.checkOctreePointOccupancy, objType = 'ocTree', },
                        checkProximitySensor = methodWrapper{ sim.checkProximitySensor, objType = 'proximitySensor', },
                        checkVisionSensor = methodWrapper{ sim.checkVisionSensor, objType = 'visionSensor', },
                        checkVisionSensorEx = methodWrapper{ sim.checkVisionSensorEx, objType = 'visionSensor', },
                        computeMassAndInertia = methodWrapper{ sim.computeMassAndInertia, },
                        executeScriptString = methodWrapper{ sim.executeScriptString, objType = 'script', },
                        getApiFunc = methodWrapper{ sim.getApiFunc, objType = 'script', },
                        getApiInfo = methodWrapper{ sim.getApiInfo, objType = 'script', },
                        getExtensionString = methodWrapper{ sim.getExtensionString, },
                        getMatrix = methodWrapper{ sim.getObjectMatrix, },
                        getOrientation = methodWrapper{ sim.getObjectOrientation, },
                        getPose = methodWrapper{ sim.getObjectPose, },
                        getPosition = methodWrapper{ sim.getObjectPosition, },
                        getQuaternion = methodWrapper{ sim.getObjectQuaternion, },
                        getObjectsInTree = methodWrapper{ sim.getObjectsInTree, },
                        getReferencedHandles = methodWrapper{ sim.getReferencedHandles, },
                        getReferencedHandle = methodWrapper{ sim.getReferencedHandle, },
                        getReferencedHandlesTags = methodWrapper{ sim.getReferencedHandlesTags, },
                        getStackTraceback = methodWrapper{ sim.getStackTraceback, objType = 'script', },
                        initScript = methodWrapper{ sim.initScript, objType = 'script', },
                        insertObjectIntoOctree = methodWrapper{ sim.insertObjectIntoOctree, objType = 'ocTree', },
                        insertObjectIntoPointCloud = methodWrapper{ sim.insertObjectIntoPointCloud, objType = 'pointCloud', },
                        insertPointsIntoPointCloud = methodWrapper{ sim.insertPointsIntoPointCloud, objType = 'pointCloud', },
                        insertVoxelsIntoOctree = methodWrapper{ sim.insertVoxelsIntoOctree, objType = 'ocTree', },
                        intersectPointsWithPointCloud = methodWrapper{ sim.intersectPointsWithPointCloud, objType = 'pointCloud', },
                        loadScene = methodWrapper{ sim.loadScene, objType = 'scene', },
                        readVisionSensor = methodWrapper{ sim.readVisionSensor, objType = 'visionSensor', },
                        relocateShapeFrame = methodWrapper{ sim.relocateShapeFrame, objType = 'shape', },
                        removeModel = methodWrapper{ sim.removeModel, },
                        removePointsFromPointCloud = methodWrapper{ sim.removePointsFromPointCloud, objType = 'pointCloud', },
                        removeReferencedObjects = methodWrapper{ sim.removeReferencedObjects, },
                        removeVoxelsFromOctree = methodWrapper{ sim.removeVoxelsFromOctree, objType = 'ocTree', },
                        resetDynamicObject = methodWrapper{ sim.resetDynamicObject, },
                        resetGraph = methodWrapper{ sim.resetGraph, objType = 'graph', },
                        resetProximitySensor = methodWrapper{ sim.resetProximitySensor, objType = 'proximitySensor', },
                        resetVisionSensor = methodWrapper{ sim.resetVisionSensor, objType = 'visionSensor', },
                        saveModel = methodWrapper{ sim.saveModel, },
                        saveScene = methodWrapper{ sim.saveScene, objType = 'scene', },
                        scaleObject = methodWrapper{ sim.scaleObject, },
                        setMatrix = methodWrapper{ sim.setObjectMatrix, },
                        setOrientation = methodWrapper{ sim.setObjectOrientation, },
                        setPose = methodWrapper{ sim.setObjectPose, },
                        setPosition = methodWrapper{ sim.setObjectPosition, },
                        setQuaternion = methodWrapper{ sim.setObjectQuaternion, },
                        setReferencedHandles = methodWrapper{ sim.setReferencedHandles, },
                        setShapeBB = methodWrapper{ sim.setShapeBB, },
                        subtractObjectFromOctree = methodWrapper{ sim.subtractObjectFromOctree, objType = 'ocTree', },
                        subtractObjectFromPointCloud = methodWrapper{ sim.subtractObjectFromPointCloud, objType = 'pointCloud', },
                        ungroupShape = methodWrapper{ sim.ungroupShape, objType = 'shape', },
                        visitTree = methodWrapper{ sim.visitTree, },
                        getShapeAppearance = methodWrapper{ sim.getShapeAppearance, objType = 'shape', },
                        setShapeAppearance = methodWrapper{ sim.setShapeAppearance, objType = 'shape', },
                        setBoolProperty = methodWrapper{ sim.setBoolProperty, },
                        getBoolProperty = methodWrapper{ sim.getBoolProperty, },
                        setIntProperty = methodWrapper{ sim.setIntProperty, },
                        getIntProperty = methodWrapper{ sim.getIntProperty, },
                        setLongProperty = methodWrapper{ sim.setLongProperty, },
                        getLongProperty = methodWrapper{ sim.getLongProperty, },
                        setFloatProperty = methodWrapper{ sim.setFloatProperty, },
                        getFloatProperty = methodWrapper{ sim.getFloatProperty, },
                        setStringProperty = methodWrapper{ sim.setStringProperty, },
                        getStringProperty = methodWrapper{ sim.getStringProperty, },
                        setBufferProperty = methodWrapper{ sim.setBufferProperty, },
                        getBufferProperty = methodWrapper{ sim.getBufferProperty, },
                        setTableProperty = methodWrapper{ sim.setTableProperty, },
                        getTableProperty = methodWrapper{ sim.getTableProperty, },
                        setIntArray2Property = methodWrapper{ sim.setIntArray2Property, },
                        getIntArray2Property = methodWrapper{ sim.getIntArray2Property, },
                        setVector2Property = methodWrapper{ sim.setVector2Property, },
                        getVector2Property = methodWrapper{ sim.getVector2Property, },
                        setVector3Property = methodWrapper{ sim.setVector3Property, },
                        getVector3Property = methodWrapper{ sim.getVector3Property, },
                        setQuaternionProperty = methodWrapper{ sim.setQuaternionProperty, },
                        getQuaternionProperty = methodWrapper{ sim.getQuaternionProperty, },
                        setPoseProperty = methodWrapper{ sim.setPoseProperty, },
                        getPoseProperty = methodWrapper{ sim.getPoseProperty, },
                        setColorProperty = methodWrapper{ sim.setColorProperty, },
                        getColorProperty = methodWrapper{ sim.getColorProperty, },
                        setFloatArrayProperty = methodWrapper{ sim.setFloatArrayProperty, },
                        getFloatArrayProperty = methodWrapper{ sim.getFloatArrayProperty, },
                        setIntArrayProperty = methodWrapper{ sim.setIntArrayProperty, },
                        getIntArrayProperty = methodWrapper{ sim.getIntArrayProperty, },
                        removeProperty = methodWrapper{ sim.removeProperty, },
                        getPropertyName = methodWrapper{ sim.getPropertyName, },
                        getPropertyInfo = methodWrapper{ sim.getPropertyInfo, },
                        setEventFilters = methodWrapper{ sim.setEventFilters, },
                        getProperty = methodWrapper{ sim.getProperty, },
                        setProperty = methodWrapper{ sim.setProperty, },
                        getPropertyTypeString = methodWrapper{ sim.getPropertyTypeString, },
                        getProperties = methodWrapper{ sim.getProperties, },
                        setProperties = methodWrapper{ sim.setProperties, },
                        getPropertiesInfos = methodWrapper{ sim.getPropertiesInfos, },
                    }
                    for name, wrapper in pairs(obj.__methods) do
                        if obj[name] == nil then
                            obj[name] = wrapper
                        end
                    end
                    return setmetatable(obj, sim.Object)
                end,
            }
        )

        -- definition of constants / static objects:
        sim.Scene = sim.Object(sim.handle_scene)
        sim.App = sim.Object(sim.handle_app)
    end
}
