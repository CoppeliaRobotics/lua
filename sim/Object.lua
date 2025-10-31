local class = require 'middleclass'

return {
    extend = function(sim)
        sim.PropertyGroup = class 'sim.PropertyGroup'

        function sim.PropertyGroup:initialize(object, opts)
            opts = opts or {}
            self.__object = object
            self.__prefix = opts.prefix or ''
            self.__localProperties = {}
        end

        function sim.PropertyGroup:__index(k)
            assert(type(k) == 'string', 'invalid key type')

            if k:startswith '__' then
                return rawget(self, k)
            end

            if (self.__localProperties[k] or {}).get then
                return self.__localProperties[k].get(self.__object)
            end

            local object = self.__object
            local prefix = self.__prefix
            if prefix ~= '' then k = prefix .. '.' .. k end

            if self.__object:getPropertyInfo(k) then
                local t = sim.getPropertyTypeString(self.__object:getPropertyInfo(k), true)
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

            if (self.__localProperties[k] or {}).set then
                return self.__localProperties[k].set(self.__object, v)
            end

            local prefix = self.__prefix
            if prefix ~= '' then k = prefix .. '.' .. k end

            if self.__object:getPropertyInfo(k) then
                local t = sim.getPropertyTypeString(self.__object:getPropertyInfo(k), true)
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

        function sim.PropertyGroup:registerLocalProperty(k, getter, setter)
            self.__localProperties[k] = {get = getter, set = setter}
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

        sim.BaseObject = class 'sim.BaseObject'

        function sim.BaseObject:initialize(handle)
            assert(math.type(handle) == 'integer', 'invalid argument type')
            rawset(self, '__handle', handle)

            -- this property group exposes object's top-level properties as self's table keys (via __index):
            rawset(self, '__properties', sim.PropertyGroup(self))

            -- pre-assign user namespaces to property groups:
            rawset(self, 'customData', sim.PropertyGroup(self, {prefix = 'customData'}))
            rawset(self, 'signal', sim.PropertyGroup(self, {prefix = 'signal'}))

            -- add methods from sim.* API:
            rawset(self, '__methods', {})
            self.__methods.addReferencedHandle = sim.addReferencedHandle
            self.__methods.checkCollision = sim.checkCollision
            self.__methods.checkDistance = sim.checkDistance
            self.__methods.getBoolProperty = sim.getBoolProperty
            self.__methods.getBufferProperty = sim.getBufferProperty
            self.__methods.getColorProperty = sim.getColorProperty
            self.__methods.getExplicitHandling = sim.getExplicitHandling
            self.__methods.getFloatArrayProperty = sim.getFloatArrayProperty
            self.__methods.getFloatProperty = sim.getFloatProperty
            self.__methods.getHandleArrayProperty = sim.getHandleArrayProperty
            self.__methods.getHandleProperty = sim.getHandleProperty
            self.__methods.getIntArray2Property = sim.getIntArray2Property
            self.__methods.getIntArrayProperty = sim.getIntArrayProperty
            self.__methods.getIntProperty = sim.getIntProperty
            self.__methods.getLongProperty = sim.getLongProperty
            self.__methods.getPoseProperty = sim.getPoseProperty
            self.__methods.getProperties = sim.getProperties
            self.__methods.getPropertiesInfos = sim.getPropertiesInfos
            self.__methods.getProperty = sim.getProperty
            self.__methods.getPropertyInfo = sim.getPropertyInfo
            self.__methods.getPropertyName = sim.getPropertyName
            self.__methods.getPropertyTypeString = sim.getPropertyTypeString
            self.__methods.getQuaternionProperty = sim.getQuaternionProperty
            self.__methods.getReferencedHandle = sim.getReferencedHandle
            self.__methods.getReferencedHandles = sim.getReferencedHandles
            self.__methods.getReferencedHandlesTags = sim.getReferencedHandlesTags
            self.__methods.getStringProperty = sim.getStringProperty
            self.__methods.getTableProperty = sim.getTableProperty
            self.__methods.getVector2Property = sim.getVector2Property
            self.__methods.getVector3Property = sim.getVector3Property
            self.__methods.removeModel = sim.removeModel
            self.__methods.removeProperty = sim.removeProperty
            self.__methods.removeReferencedObjects = sim.removeReferencedObjects
            self.__methods.saveModel = sim.saveModel
            self.__methods.scaleObject = sim.scaleObject
            self.__methods.setBoolProperty = sim.setBoolProperty
            self.__methods.setBufferProperty = sim.setBufferProperty
            self.__methods.setColorProperty = sim.setColorProperty
            self.__methods.setEventFilters = sim.setEventFilters
            self.__methods.setFloatArrayProperty = sim.setFloatArrayProperty
            self.__methods.setFloatProperty = sim.setFloatProperty
            self.__methods.setHandleArrayProperty = sim.setHandleArrayProperty
            self.__methods.setHandleProperty = sim.setHandleProperty
            self.__methods.setIntArray2Property = sim.setIntArray2Property
            self.__methods.setIntArrayProperty = sim.setIntArrayProperty
            self.__methods.setIntProperty = sim.setIntProperty
            self.__methods.setLongProperty = sim.setLongProperty
            self.__methods.setPoseProperty = sim.setPoseProperty
            self.__methods.setProperties = sim.setProperties
            self.__methods.setProperty = sim.setProperty
            self.__methods.setQuaternionProperty = sim.setQuaternionProperty
            self.__methods.setReferencedHandles = sim.setReferencedHandles
            self.__methods.setStringProperty = sim.setStringProperty
            self.__methods.setTableProperty = sim.setTableProperty
            self.__methods.setVector2Property = sim.setVector2Property
            self.__methods.setVector3Property = sim.setVector3Property
            self.__methods.visitTree = sim.visitTree
        end

        function sim.BaseObject:__copy()
            local o = self.class(rawget(self, '__handle'))
            return o
        end

        function sim.BaseObject:__deepcopy(m)
            return self:__copy()
        end

        function sim.BaseObject:__index(k)
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

        function sim.BaseObject:__newindex(k, v)
            self.__properties[k] = v
        end

        function sim.BaseObject:__len()
            return self.__handle
        end

        function sim.BaseObject:__tostring()
            return self.class.name .. '(' .. self.__handle .. ')'
        end

        function sim.BaseObject:__tohandle()
            return self.__handle
        end

        function sim.BaseObject:__tocbor()
            local cbor = require 'simCBOR'
            return cbor.encode(self.__handle)
        end

        function sim.BaseObject:__pairs()
            --local itertools = require 'itertools'
            --return itertools.chain(self.__properties, self.__methods)
            return pairs(self.__properties)
        end

        function sim.BaseObject:__eq(o)
            return self.__handle == o.__handle
        end

        sim.Collection = class('sim.Collection', sim.BaseObject)

        function sim.Collection:initialize(handle)
            sim.BaseObject.initialize(self, handle)

            assert(self.objectType == 'collection', 'invalid constructor for object type ' .. self.objectType)

            self.__methods.addItem = function(...)
                local args = {...}
                if #args < 2 then
                    error('the function requires more arguments.')
                end
                return sim.addItemToCollection(args[2], sim.handle_single, self.__handle, ...)
            end
        end

        sim.App = class('sim.App', sim.BaseObject)

        function sim.App:initialize(handle)
            sim.BaseObject.initialize(self, handle)

            assert(handle == sim.handle_app, 'invalid handle')
            assert(self.objectType == 'app', 'invalid constructor for object type ' .. self.objectType)

            rawset(self, 'namedParam', sim.PropertyGroup(self, {prefix = 'namedParam'}))
        end

        sim.Scene = class('sim.Scene', sim.BaseObject)

        function sim.Scene:initialize(handle)
            sim.BaseObject.initialize(self, handle)

            assert(handle == sim.handle_scene, 'invalid handle')
            assert(self.objectType == 'scene', 'invalid constructor for object type ' .. self.objectType)

            self.__methods.getObjectsInTree = sim.getObjectsInTree
            self.__methods.load = sim.loadScene
            self.__methods.save = sim.saveScene
        end

        sim.SceneObject = class('sim.SceneObject', sim.BaseObject)

        function sim.SceneObject:initialize(handle)
            sim.BaseObject.initialize(self, handle)

            assert(sim.isHandle(handle), 'invalid handle')
            assert(sim.SceneObject.ObjectTypes[self.objectType], 'invalid constructor for object type ' .. self.objectType)

            -- 'children' property provides a way to access direct children by index or by name:
            rawset(self, 'children', sim.ObjectChildren(self))

            self.__methods.getMatrix = sim.getObjectMatrix
            self.__methods.getOrientation = sim.getObjectOrientation
            self.__methods.getPose = sim.getObjectPose
            self.__methods.getPosition = sim.getObjectPosition
            self.__methods.getQuaternion = sim.getObjectQuaternion
            self.__methods.getVelocity = sim.getObjectVelocity
            self.__methods.setMatrix = sim.setObjectMatrix
            self.__methods.setOrientation = sim.setObjectOrientation
            self.__methods.setParent = sim.setObjectParent
            self.__methods.setPose = sim.setObjectPose
            self.__methods.setPosition = sim.setObjectPosition
            self.__methods.setQuaternion = sim.setObjectQuaternion

            self.__properties:registerLocalProperty('absolutePose', function() return self:getPose(sim.handle_world) end)
        end

        function sim.SceneObject:__div(path)
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

        sim.Dummy = class('sim.Dummy', sim.SceneObject)

        function sim.Dummy:initialize(handle)
            sim.SceneObject.initialize(self, handle)

            assert(self.objectType == 'dummy', 'invalid constructor for object type ' .. self.objectType)
        end

        sim.ForceSensor = class('sim.ForceSensor', sim.SceneObject)

        function sim.ForceSensor:initialize(handle)
            sim.SceneObject.initialize(self, handle)

            assert(self.objectType == 'forceSensor', 'invalid constructor for object type ' .. self.objectType)

            self.__methods.checkSensor = sim.readForceSensor
            self.__methods.getForce = function ()
                local f, t = sim.readForceSensor(self.__handle)
                return f
            end
            self.__methods.getTorque = function ()
                local f, t = sim.readForceSensor(self.__handle)
                return t
            end
        end

        sim.Graph = class('sim.Graph', sim.SceneObject)

        function sim.Graph:initialize(handle)
            sim.SceneObject.initialize(self, handle)

            assert(self.objectType == 'graph', 'invalid constructor for object type ' .. self.objectType)

            self.__methods.addCurve = sim.addGraphCurve
            self.__methods.addStream = sim.addGraphStream
            self.__methods.resetGraph = sim.resetGraph
        end

        sim.Joint = class('sim.Joint', sim.SceneObject)

        function sim.Joint:initialize(handle)
            sim.SceneObject.initialize(self, handle)

            assert(self.objectType == 'joint', 'invalid constructor for object type ' .. self.objectType)

            self.__methods.getForce = sim.getJointForce
            self.__methods.resetDynamicObject = sim.resetDynamicObject
        end

        sim.OcTree = class('sim.OcTree', sim.SceneObject)

        function sim.OcTree:initialize(handle)
            sim.SceneObject.initialize(self, handle)

            assert(self.objectType == 'ocTree', 'invalid constructor for object type ' .. self.objectType)

            self.__methods.checkPointOccupancy = sim.checkOctreePointOccupancy
            self.__methods.insertObject = sim.insertObjectIntoOctree
            self.__methods.insertVoxels = sim.insertVoxelsIntoOctree
            self.__methods.removeVoxels = sim.removeVoxelsFromOctree
            self.__methods.subtractObject = sim.subtractObjectFromOctree
        end

        sim.PointCloud = class('sim.PointCloud', sim.SceneObject)

        function sim.PointCloud:initialize(handle)
            sim.SceneObject.initialize(self, handle)

            assert(self.objectType == 'pointCloud', 'invalid constructor for object type ' .. self.objectType)

            self.__methods.insertObject = sim.insertObjectIntoPointCloud
            self.__methods.insertPoints = sim.insertPointsIntoPointCloud
            self.__methods.intersectPoints = sim.intersectPointsWithPointCloud
            self.__methods.removePoints = sim.removePointsFromPointCloud
            self.__methods.subtractObject = sim.subtractObjectFromPointCloud
        end

        sim.ProximitySensor = class('sim.ProximitySensor', sim.SceneObject)

        function sim.ProximitySensor:initialize(handle)
            sim.SceneObject.initialize(self, handle)

            assert(self.objectType == 'proximitySensor', 'invalid constructor for object type ' .. self.objectType)

            self.__methods.checkSensor = sim.checkProximitySensor
            self.__methods.resetSensor = sim.resetProximitySensor
        end

        sim.Script = class('sim.Script', sim.SceneObject)

        function sim.Script:initialize(handle)
            sim.SceneObject.initialize(self, handle)

            assert(self.objectType == 'script', 'invalid constructor for object type ' .. self.objectType)

            self.__methods.callFunction = sim.callScriptFunction
            self.__methods.executeScriptString = sim.executeScriptString
            self.__methods.getApiFunc = sim.getApiFunc
            self.__methods.getApiInfo = sim.getApiInfo
            self.__methods.getStackTraceback = sim.getStackTraceback
            self.__methods.init = sim.initScript
        end

        sim.Shape = class('sim.Shape', sim.SceneObject)

        function sim.Shape:initialize(handle)
            sim.SceneObject.initialize(self, handle)

            assert(self.objectType == 'shape', 'invalid constructor for object type ' .. self.objectType)

            self.__methods.addForce = sim.addForce
            self.__methods.addForceAndTorque = sim.addForceAndTorque
            self.__methods.alignBB = sim.alignShapeBB
            self.__methods.computeMassAndInertia = sim.computeMassAndInertia
            self.__methods.getAppearance = sim.getShapeAppearance
            self.__methods.getDynVelocity = sim.getShapeVelocity
            self.__methods.relocateFrame = sim.relocateShapeFrame
            self.__methods.resetDynamicObject = sim.resetDynamicObject
            self.__methods.setAppearance = sim.setShapeAppearance
            self.__methods.setShapeBB = sim.setShapeBB
            self.__methods.ungroup = sim.ungroupShape
        end

        sim.Texture = class('sim.Texture', sim.SceneObject)

        function sim.Texture:initialize(handle)
            sim.SceneObject.initialize(self, handle)

            assert(self.objectType == 'texture', 'invalid constructor for object type ' .. self.objectType)
        end

        sim.VisionSensor = class('sim.VisionSensor', sim.SceneObject)

        function sim.VisionSensor:initialize(handle)
            sim.SceneObject.initialize(self, handle)

            assert(self.objectType == 'visionSensor', 'invalid constructor for object type ' .. self.objectType)

            self.__methods.checkSensor = sim.checkVisionSensor
            self.__methods.checkSensorEx = sim.checkVisionSensorEx
            self.__methods.read = sim.readVisionSensor
            self.__methods.reset = sim.resetVisionSensor
        end

        sim.SceneObject.ObjectTypes = {
            dummy = sim.Dummy,
            forceSensor = sim.ForceSensor,
            graph = sim.Graph,
            joint = sim.Joint,
            ocTree = sim.OcTree,
            pointCloud = sim.PointCloud,
            proximitySensor = sim.ProximitySensor,
            script = sim.Script,
            shape = sim.Shape,
            texture = sim.Texture,
            visionSensor = sim.VisionSensor,
        }

        sim.Object = {}

        setmetatable(sim.Object, {
            __call = function(self, arg, opts)
                local handle
                if math.type(arg) == 'integer' then
                    assert(opts == nil, 'invalid args')
                    handle = arg
                    assert(sim.isHandle(handle) or handle == sim.handle_app or handle == sim.handle_scene or handle >= 10000000, 'invalid handle')
                elseif type(arg) == 'string' then
                    local query = arg
                    assert(query:sub(1, 1) == '/' or query:sub(1, 1) == '.', 'invalid object query')
                    handle = sim.getObject(query, opts or {})
                    assert(handle ~= -1, 'no such object')
                elseif sim.Object:isobject(arg) then
                    assert(opts == nil, 'invalid args')
                    handle = #arg
                elseif type(arg) == 'table' then
                    assert(opts == nil, 'invalid args')
                    local initialProperties = arg
                    handle = sim.createObject(initialProperties)
                else
                    error 'invalid arguments to sim.Object(...)'
                end

                local objectType = sim.getStringProperty(handle, 'objectType')
                if objectType == 'app' then
                    return sim.App(handle)
                elseif objectType == 'scene' then
                    return sim.Scene(handle)
                else
                    local cls = sim.SceneObject.ObjectTypes[objectType]
                    assert(cls, 'unsupported object type: ' .. objectType)
                    return cls(handle)
                end
            end
        })

        function sim.Object:isobject(o)
            assert(self == sim.Object, 'class method')
            return sim.BaseObject.isInstanceOf(o, sim.BaseObject)
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
