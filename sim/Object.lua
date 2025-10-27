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
            assert(type(k) == 'string', 'invalid key type')

            if k:startswith '__' then
                return rawget(self, k)
            end

            local object = self.__object
            local prefix = self.__prefix
            if prefix ~= '' then k = prefix .. '.' .. k end

            local t

            -- check if we have some type hint for property `k`...
            local objectType = rawget(self.__object, 'objectType')
            local th = sim.Object.Properties or {}
            th = (th[objectType] or {})[k] or th.object[k] or {}
            if th.type then t = th.type end
            if th.alias then k = th.alias end

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

            local t

            -- check if we have some type hint for property `k`...
            local objectType = rawget(self.__object, 'objectType')
            local th = sim.Object.Properties or {}
            th = (th[self.__object.objectType] or {})[k] or th.object[k] or {}
            if th.type then t = th.type end
            if th.alias then k = th.alias end

            if self.__object:getPropertyInfo(k) then
                if not t then
                    t = sim.getPropertyTypeString(self.__object:getPropertyInfo(k))
                end
                self.__object['set' .. t:capitalize() .. 'Property'](self.__object, k, v)
            end
        end

        function sim.PropertyGroup:__tostring()
            return 'sim.PropertyGroup(' .. tostring(self.__object) .. ', {prefix = ' .. _S.anyToString(self.__prefix) .. '})'
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
                        local t = sim.getPropertyTypeString(ptype, true)
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
                if k >= 1 then
                    local h = sim.getObjectChild(self.__object.__handle, k - 1)
                    if h ~= -1 then
                        return sim.Object(h)
                    end
                end
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
                if k ~= nil then return k, v end
            end
            return stateless_iter, self, nil
        end

        function sim.ObjectChildren:__ipairs()
            local function stateless_iter(self, i)
                i = i + 1
                local h = self.__object[i]
                if h ~= -1 then return i, sim.Object(h) end
            end
            return stateless_iter, self, 0
        end

        sim.Object = class 'sim.Object'

        function sim.Object:initialize(handle, opts)
            if math.type(handle) == 'integer' then
                assert(opts == nil, 'invalid args')
                assert(sim.isHandle(handle) or handle == sim.handle_app or handle == sim.handle_scene or handle >= 10000000, 'invalid handle')
            elseif type(handle) == 'string' then
                local query = handle
                assert(query:sub(1, 1) == '/' or query:sub(1, 1) == '.', 'invalid object query')
                handle = sim.getObject(query, opts or {})
                assert(handle ~= -1, 'object query returned error')
            elseif sim.Object:isobject(handle) then
                assert(opts == nil, 'invalid args')
                handle = #handle
            elseif type(handle) == 'table' then
                assert(opts == nil, 'invalid args')
                local initialProperties = handle
                handle = sim.createObject(initialProperties)
            else
                error 'invalid type for handle'
            end

            rawset(self, '__handle', handle)

            local objectType = sim.getStringProperty(handle, 'objectType')
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
                getMass = methodWrapper{ sim.getShapeMass, objType = 'shape', },
                setMass = methodWrapper{ sim.setShapeMass, objType = 'shape', },
                getInertia = methodWrapper{ sim.getShapeInertia, objType = 'shape', },
                setInertia = methodWrapper{ sim.setShapeInertia, objType = 'shape', },
                addItemToCollection = methodWrapper{ sim.addItemToCollection, objType = 'collection', },
                addForce = methodWrapper{ sim.addForce, objType = 'shape', },
                addForceAndTorque = methodWrapper{ sim.addForceAndTorque, objType = 'shape', },
                addReferencedHandle = methodWrapper{ sim.addReferencedHandle, },
                alignBB = methodWrapper{ sim.alignShapeBB, objType = 'shape', },
                callFunction = methodWrapper{ sim.callScriptFunction, objType = 'script', },
                checkCollision = methodWrapper{ sim.checkCollision, },
                checkDistance = methodWrapper{ sim.checkDistance, },
                checkPointOccupancy = methodWrapper{ sim.checkOctreePointOccupancy, objType = 'ocTree', },
                checkSensorEx = methodWrapper{ sim.checkVisionSensorEx, objType = 'visionSensor', },
                computeMassAndInertia = methodWrapper{ sim.computeMassAndInertia, },
                executeScriptString = methodWrapper{ sim.executeScriptString, objType = 'script', },
                getAlias = methodWrapper{ sim.getObjectAlias, },
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
                    local h = sim.getIntProperty(self.__handle, k)
                    if h ~= -1 then
                        return sim.Object(h)
                    end
                end,

                setHandleProperty = function(self, k, v)
                    if v == nil then
                        v = -1
                    elseif sim.Object:isobject(v) then
                        v = #v
                    end
                    return sim.setIntProperty(self.__handle, k, v)
                end,

                getHandlesProperty = function(self, k)
                    return map(
                        function(h)
                            if h ~= -1 then
                                return sim.Object(h)
                            end
                        end,
                        sim.getIntArrayProperty(self.__handle, k)
                    )
                end,

                setHandlesProperty = function(self, k, v)
                    if v == nil then
                        v = {}
                    end
                    return sim.setIntArrayProperty(
                        self.__handle,
                        k,
                        map(
                            function(o)
                                if sim.Object:isobject(o) then
                                    o = #o
                                end
                                return o
                            end,
                            v
                        )
                    )
                end,
            })

            if objectType == 'forceSensor' then
                self.__methods.checkSensor = sim.checkForceSensor
            elseif objectType == 'proximitySensor' then
                self.__methods.checkSensor = sim.checkProximitySensor
            elseif objectType == 'visionSensor' then
                self.__methods.checkSensor = sim.checkVisionSensor
            end
            --[[
            if objectType == 'shape' then
                self.__methods.changeColor = function(...)
                    local args = {...}
                    print(args)
                    if #args[1] > 0 and (type(args[1]) == 'table') and args[1].handle then
                        return sim.changeEntityColor(args[1])
                    else
                        return sim.changeEntityColor(self.__handle, ...)
                    end
                end
            end
            --]]
        end

        function sim.Object:__copy()
            local o = sim.Object(rawget(self, '__handle'))
            return o
        end

        function sim.Object:__deepcopy(m)
            return self:__copy()
        end

        function sim.Object:__index(k)
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

        function sim.Object:__tocbor()
            local cbor = require 'simCBOR'
            return cbor.encode(self.__handle)
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

        function sim.Object:__eq(o)
            return self.__handle == o.__handle
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

        function sim.Object.unittest()
            f = sim.Object '/Floor'
            b = sim.Object '/Floor/box'
            assert(b == f / 'box')
            if #sim.scene.orphans > 0 then
                assert(sim.scene.orphans[1].parent == nil)
            else
                print 'skipped orphans test'
            end
            assert(f.children.box == b)
            assert(f.children.box == f.children[1])
            assert(b.parent == f)
            d1 = sim.Object{
                objectType = 'dummy',
                alias = 'd1',
            }
            assert(sim.Object:isobject(d1))
            d2 = sim.Object{
                objectType = 'dummy',
                alias = 'd2',
                dummyType = sim.dummytype_dynloopclosure,
                linkedDummyHandle = #d1,
            }
            assert(d2.linkedDummy == d1)
            sim.removeObjects{d1, d2}
            cbor = require 'simCBOR'
            p = table.frompairs(f.children)
            assert(cbor.encode(p) == cbor.encode{box = b})
            ip = table.fromipairs(f.children)
            assert(cbor.encode(ip) == cbor.encode{b})
            assert(b:getPosition(f):norm() < 1e-7)

            a = sim.Object {objectType = 'dummy', alias = 'a', }
            b = sim.Object {objectType = 'dummy', alias = 'b', }
            c = sim.Object {objectType = 'dummy', alias = 'c', }
            c.parent = b
            b.parent = a
            a.modelBase = true
            assert(c:getAlias(1) == '/a/c')
            b.modelBase = true
            assert(c:getAlias(1) == '/a/b/c')
            sim.removeObjects{a, b, c}

            print(debug.getinfo(1, 'S').source, 'tests passed')
        end

        sim.Object.SceneObjectTypes = {
            'dummy',
            'forceSensor',
            'graph',
            'joint',
            'ocTree',
            'pointCloud',
            'proximitySensor',
            'script',
            'shape',
            'texture',
            'visionSensor',
        }

        sim.Object.CreatableObjectTypes = table.add(
            {
                'collection',
            },
            sim.Object.SceneObjectTypes
        )

        sim.Object.Properties = {
            scene = {
                ['objects'] = {type = 'handles', alias = 'objectHandles'},
                ['orphans'] = {type = 'handles', alias = 'orphanHandles'},
                ['selection'] = {type = 'handles', alias = 'selectionHandles'},
            },
            object = {
                ['parent'] = {type = 'handle', alias = 'parentHandle'},
            },
            dummy = {
                ['linkedDummy'] = {type = 'handle', alias = 'linkedDummyHandle'},
                ['mujoco.jointProxy'] = {type = 'handle', alias = 'mujoco.jointProxyHandle'},
            },
            proximitySensor = {
                ['detectedObject'] = {type = 'handle', alias = 'detectedObjectHandle'},
            },
            shape = {
                ['meshes'] = {type = 'handles'},
            },
        }

        sim.ObjectArray = class 'sim.ObjectArray'

        function sim.ObjectArray:initialize(...)
            rawset(self, '__object', sim.Object(...))
            assert(self[0] == self.__object, 'sim.ObjectArray must point to first object of the array')
        end

        function sim.ObjectArray:__index(k)
            assert(math.type(k) == 'integer', 'invalid index type')
            if k >= 0 then
                local parent = self.__object.parent or sim.scene
                local alias = self.__object.alias
                for i, child in ipairs(parent.children) do
                    if child.alias == alias then
                        k = k - 1
                        if k < 0 then return child end
                    end
                end
            end
        end

        -- definition of constants / static objects:
        sim.scene = sim.Object(sim.handle_scene)
        sim.app = sim.Object(sim.handle_app)
    end
}
