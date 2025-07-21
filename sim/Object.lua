local class = require 'middleclass'

return {
    extend = function(sim)
        sim.PropertyGroup = class 'sim.PropertyGroup'

        function sim.PropertyGroup:initialize(object, opts)
            opts = opts or {}
            self.__object = object
            self.__prefix = opts.prefix or ''
        end

        function sim.PropertyGroup:__index(k)
            if k:startswith '__' then
                return rawget(self, k)
            end

            local object = self.__object
            local prefix = self.__prefix
            if prefix ~= '' then k = prefix .. '.' .. k end

            local t

            -- check if we have some type hint for property `k`...
            if k ~= 'objectType' then
                local th = sim.Object.Properties or {}
                th = th[self.__object.objectType] or {}
                th = th[k] or {}
                if th.type then t = th.type end
                if th.alias then k = th.alias end
            end

            if self.__object:getPropertyInfo(k) then
                if not t then
                    t = sim.getPropertyTypeString(self.__object:getPropertyInfo(k))
                end
                return self.__object['get' .. t:capitalize() .. 'Property'](self.__object, k)
            end

            if self.__object:getPropertyName(0, {prefix = k .. '.'}) then
                return sim.PropertyGroup(self.__object, {prefix = k})
            end
        end

        function sim.PropertyGroup:__newindex(k, v)
            if k:startswith '__' then
                rawset(self, k, v)
                return
            end

            local prefix = self.__prefix
            if prefix ~= '' then k = prefix .. '.' .. k end
            local t = sim.getPropertyTypeString(self.__object:getPropertyInfo(k))
            self.__object['set' .. t:capitalize() .. 'Property'](self.__object, k, v)
        end

        function sim.PropertyGroup:__tostring()
            return 'sim.PropertyGroup(' .. self.__object .. ', {prefix = ' .. _S.anyToString(self.__prefix) .. '})'
        end

        function sim.PropertyGroup:__pairs()
            local prefix = self.__prefix
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
        end

        sim.ObjectChildren = class 'sim.ObjectChildren'

        function sim.ObjectChildren:initialize(object)
            self.__object = object
        end

        function sim.ObjectChildren:__index(k)
            if type(k) == 'string' then
                return self.__object / k
            elseif math.type(k) == 'integer' then
                return sim.Object(sim.getObjectChild(self.__object.__handle, k))
            end
        end

        function sim.ObjectChildren:__pairs()
            local r = {}
            for i, h in ipairs(sim.getObjectsInTree(self.__object.__handle, sim.handle_all, 3)) do
                r[sim.getObjectAlias(h)] = sim.Object(h)
            end
            local function stateless_iter(self, k)
                local v
                k, v = next(r, k)
                if v ~= nil then return k, v end
            end
            return stateless_iter, self, nil
        end

        function sim.ObjectChildren:__ipairs()
            local function stateless_iter(self, i)
                i = i + 1
                local h = sim.getObjectChild(self.__object.__handle, i)
                if h ~= -1 then return i, sim.Object(h) end
            end
            return stateless_iter, self, -1
        end

        sim.Object = class 'sim.Object'

        function sim.Object:initialize(handle, opts)
            opts = opts or {}

            local query
            if handle == '/' then
                handle = sim.handle_scene
                rawset(self, 'objectType', 'scene')
            elseif handle == '@' then
                handle = sim.handle_app
            elseif type(handle) == 'string' then
                query= handle
                handle = sim.getObject(query, opts)
            else
                assert(math.type(handle) == 'integer', 'invalid type for handle')
                assert(sim.isHandle(handle) or handle == sim.handle_app or handle == sim.handle_scene, 'invalid handle')
            end
            rawset(self, '__handle', handle)
            if query then
                rawset(self, '__query', query)
            elseif sim.isHandle(handle) then
                rawset(self, '__query', sim.getObjectAlias(handle))
            end

            local objectType
            if handle == sim.handle_app then
                objectType = 'app'
            elseif handle == sim.handle_scene then
                objectType = 'scene'
            else
                objectType = sim.getStringProperty(handle, 'objectType')
            end
            rawset(self, 'objectType', objectType)

            -- this property group exposes object's top-level properties as self's table keys (via __index):
            rawset(self, '__properties', sim.PropertyGroup(self))

            -- 'children' property provides a way to access direct children by index or by name:
            rawset(self, 'children', sim.ObjectChildren(self))

            -- pre-assign user namespaces to property groups:
            for _, namespace in ipairs{'customData', 'signal', 'namedParam'} do
                rawset(self, namespace, sim.PropertyGroup(self, {prefix = namespace}))
            end

            -- add methods from sim.* API:

            local function methodWrapper(kwargs)
                local apiFunc, info = kwargs[1], kwargs
                if (info.objType or objectType) == objectType then
                    return apiFunc
                end
            end

            rawset(self, '__methods', {
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
                checkSensor = methodWrapper{ sim.checkForceSensor, objType = 'forceSensor', },
                computeMassAndInertia = methodWrapper{ sim.computeMassAndInertia, },
                executeScriptString = methodWrapper{ sim.executeScriptString, objType = 'script', },
                getApiFunc = methodWrapper{ sim.getApiFunc, objType = 'script', },
                getApiInfo = methodWrapper{ sim.getApiInfo, objType = 'script', },
                getExtensionString = methodWrapper{ sim.getExtensionString, },
                getParent = methodWrapper{ sim.getObjectParent, },
                getMatrix = methodWrapper{ sim.getObjectMatrix, },
                getOrientation = methodWrapper{ sim.getObjectOrientation, },
                getPose = methodWrapper{ sim.getObjectPose, },
                getPosition = methodWrapper{ sim.getObjectPosition, },
                getQuaternion = methodWrapper{ sim.getObjectQuaternion, },
                getVelocity = methodWrapper{ sim.getObjectVelocity, },
                getDynVelocity = methodWrapper{ sim.getShapeVelocity, objType = 'shape', },
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
                setParent = methodWrapper{ sim.setObjectParent, },
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

                getHandleProperty = function(self, k)
                    return sim.Object(sim.getIntProperty(self.__handle, k))
                end,

                setHandleProperty = function(self, k, v)
                    return setIntArrayProperty(self.__handle, k, v)
                end,

                getHandlesProperty = function(self, k)
                    return map(function(h) return sim.Object(h) end, sim.getIntArrayProperty(self.__handle, k))
                end,

                setHandlesProperty = function(self, k, v)
                    return setIntArrayProperty(self.__handle, k, map(function(o) return #o end, v))
                end,
            })
        end

        function sim.Object:__copy()
            local o = sim.Object(rawget(self, '__handle'))
            rawset(o, '__query', rawget(self, '__query'))
            return o
        end

        function sim.Object:__deepcopy(m)
            return self:__copy()
        end

        function sim.Object:__index(k)
            -- int indexing for accessing siblings:
            if math.type(k) == 'integer' then
                assert(self.__query)
                return sim.Object(self.__query, {index = k})
            end

            -- lookup existing properties first:
            local v = rawget(self, k)
            if v then return v end

            -- redirect to methods:
            local m = rawget(self, '__methods')[k]
            if m ~= nil then return m end

            -- redirect to default property group otherwise:
            local p = rawget(self, '__properties')[k]
            if p ~= nil then return p end

            -- (script funcs proxy)
            -- this is bad, as every non-existent property access (top-level) turns into
            -- an existent function, pretty confusing...
            --[[
            return function(self, ...)
                return (rawget(self, 'callFunction') or function() end)(k, ...)
            end
            ]]--
        end

        function sim.Object:__newindex(k, v)
            self.__properties[k] = v
        end

        function sim.Object:__len()
            return self.__handle
        end

        function sim.Object:__tostring()
            return 'sim.Object(' .. self.__handle .. ')'
        end

        function sim.Object:__tohandle()
            return self.__handle
        end

        function sim.Object:__pairs()
            --local itertools = require 'itertools'
            --return itertools.chain(self.__properties, self.__methods)
            return pairs(self.__properties)
        end

        function sim.Object:__div(path)
            assert(self.__handle ~= sim.handle_app)
            local opts = {}
            if self.__handle == sim.handle_scene then
                if path:sub(1, 1) ~= '/' then path = '/' .. path end
            else
                if path:sub(1, 2) ~= './' then path = './' .. path end
                opts.proxy = self.__handle
            end
            return sim.Object(path, opts)
        end

        function sim.Object:isobject(o)
            assert(self == sim.Object, 'class method')
            return sim.Object.isInstanceOf(o, sim.Object)
        end

        function sim.Object:toobject(o)
            assert(self == sim.Object, 'class method')
            if sim.Object:isobject(o) then return o end
            if math.type(o) == 'integer' or type(o) == 'string' then return sim.Object(o) end
            error 'bad type'
        end

        sim.Object.Properties = {
            scene = {
                ['objects'] = {type = 'handles', alias = 'objectHandles'},
                ['orphans'] = {type = 'handles', alias = 'orphanHandles'},
                ['selection'] = {type = 'handles', alias = 'selectionHandles'},
            },
            dummy = {
                ['linkedDummy'] = {type = 'handle', alias = 'linkedDummyHandle'},
                ['mujoco.jointProxy'] = {type = 'handle', alias = 'mujoco.jointProxyHandle'},
            },
            proximitySensor = {
                ['detectedObjectHandle'] = {type = 'handle'},
            },
            shape = {
                ['meshes'] = {type = 'handles'},
            },
        }

        for _, t in ipairs{'dummy', 'forceSensor', 'joint', 'octree', 'pointCloud', 'proximitySensor', 'script', 'shape', 'texture', 'visionSensor'} do
            sim.Object.Properties[t] = sim.Object.Properties[t] or {}
            sim.Object.Properties[t]['parent'] = {type = 'handle', alias = 'parentHandle'}
        end

        -- definition of constants / static objects:
        sim.scene = sim.Object(sim.handle_scene)
        sim.app = sim.Object(sim.handle_app)
    end
}
