local class = require 'middleclass'

return {
    extend = function(sim)
        sim.PropertyGroup = class 'sim.PropertyGroup'

        function sim.PropertyGroup:initialize(object, opts)
            self.__object = object
            self.__opts = table.clone(opts or {})
            self.__localProperties = {}
        end

        function sim.PropertyGroup:__index(k)
            assert(type(k) == 'string', 'invalid key type')

            if k:startswith '__' then
                return rawget(self, k)
            end

            if self.__localProperties[k] then
                assert(self.__localProperties[k].get, 'local property "' .. k .. '" can\'t be read')
                return self.__localProperties[k].get()
            end

            local prefix = self.__opts.prefix or ''
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

            if self.__localProperties[k] then
                assert(self.__localProperties[k].set, 'local property "' .. k .. '" can\'t be written')
                return self.__localProperties[k].set(v)
            end

            local prefix = self.__opts.prefix or ''
            if prefix ~= '' then k = prefix .. '.' .. k end

            local ptype = self.__opts.newPropertyForcedType or self.__object:getPropertyInfo(k)
            if ptype then
                local t = sim.getPropertyTypeString(ptype, true)
                self.__object['set' .. t:capitalize() .. 'Property'](self.__object, k, v)
            else
                self.__object:setProperty(k, v)
            end
        end

        function sim.PropertyGroup:__tostring()
            local s = 'sim.PropertyGroup(' .. tostring(self.__object)
            if next(self.__opts) then
                s = s .. ', ' .. table.tostring(self.__opts)
            end
            s = s .. ')'
            return s
        end

        function sim.PropertyGroup:__pairs()
            local prefix = self.__opts.prefix or ''
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

        sim.BaseObject = class 'sim.BaseObject'

        sim.BaseObject.getBoolProperty = sim.getBoolProperty
        sim.BaseObject.getBufferProperty = sim.getBufferProperty
        sim.BaseObject.getColorProperty = sim.getColorProperty
        sim.BaseObject.getExplicitHandling = sim.getExplicitHandling
        sim.BaseObject.getFloatArrayProperty = sim.getFloatArrayProperty
        sim.BaseObject.getFloatProperty = sim.getFloatProperty
        sim.BaseObject.getHandleArrayProperty = sim.getHandleArrayProperty
        sim.BaseObject.getHandleProperty = sim.getHandleProperty
        sim.BaseObject.getIntArray2Property = sim.getIntArray2Property
        sim.BaseObject.getIntArrayProperty = sim.getIntArrayProperty
        sim.BaseObject.getIntProperty = sim.getIntProperty
        sim.BaseObject.getLongProperty = sim.getLongProperty
        sim.BaseObject.getPoseProperty = sim.getPoseProperty
        sim.BaseObject.getProperties = sim.getProperties
        sim.BaseObject.getPropertiesInfos = sim.getPropertiesInfos
        sim.BaseObject.getProperty = sim.getProperty
        sim.BaseObject.getPropertyInfo = sim.getPropertyInfo
        sim.BaseObject.getPropertyName = sim.getPropertyName
        sim.BaseObject.getPropertyTypeString = sim.getPropertyTypeString
        sim.BaseObject.getQuaternionProperty = sim.getQuaternionProperty
        sim.BaseObject.getStringProperty = sim.getStringProperty
        sim.BaseObject.getTableProperty = sim.getTableProperty
        sim.BaseObject.getVector2Property = sim.getVector2Property
        sim.BaseObject.getVector3Property = sim.getVector3Property
        sim.BaseObject.removeProperty = sim.removeProperty
        sim.BaseObject.setBoolProperty = sim.setBoolProperty
        sim.BaseObject.setBufferProperty = sim.setBufferProperty
        sim.BaseObject.setColorProperty = sim.setColorProperty
        sim.BaseObject.setFloatArrayProperty = sim.setFloatArrayProperty
        sim.BaseObject.setFloatProperty = sim.setFloatProperty
        sim.BaseObject.setHandleArrayProperty = sim.setHandleArrayProperty
        sim.BaseObject.setHandleProperty = sim.setHandleProperty
        sim.BaseObject.setIntArray2Property = sim.setIntArray2Property
        sim.BaseObject.setIntArrayProperty = sim.setIntArrayProperty
        sim.BaseObject.setIntProperty = sim.setIntProperty
        sim.BaseObject.setLongProperty = sim.setLongProperty
        sim.BaseObject.setPoseProperty = sim.setPoseProperty
        sim.BaseObject.setProperties = sim.setProperties
        sim.BaseObject.setProperty = sim.setProperty
        sim.BaseObject.setQuaternionProperty = sim.setQuaternionProperty
        sim.BaseObject.setStringProperty = sim.setStringProperty
        sim.BaseObject.setTableProperty = sim.setTableProperty
        sim.BaseObject.setVector2Property = sim.setVector2Property
        sim.BaseObject.setVector3Property = sim.setVector3Property

        function sim.BaseObject:initialize(handle, checkObjectType)
            assert(math.type(handle) == 'integer', 'invalid argument type')
            rawset(self, '__handle', handle)

            -- this property group exposes object's top-level properties as self's table keys (via __index):
            rawset(self, '__properties', sim.PropertyGroup(self))

            self.__properties:registerLocalProperty('handle', function() return self.__handle end)

            if checkObjectType then
                assert(self.objectType == checkObjectType, 'invalid constructor for object type ' .. self.objectType)
            end
        end

        function sim.BaseObject:__copy()
            local o = self.class(rawget(self, '__handle'))
            return o
        end

        function sim.BaseObject:__deepcopy(m)
            return self:__copy()
        end

        function sim.BaseObject:__index(k)
            if k == '__methods' then -- support for coppeliaSim's _getCompletion
                local m = {}
                for k, v in pairs(self.class.__instanceDict) do
                    if k ~= 'initialize' and k:sub(1, 2) ~= '__' and type(v) == 'function' then
                        m[k] = v
                    end
                end
                return m
            end

            -- lookup existing properties first:
            local v = rawget(self, k)
            if v then return v end

            -- redirect to default property group otherwise:
            local p = rawget(self, '__properties')[k]
            if p ~= nil then return p end
        end

        function sim.BaseObject:__newindex(k, v)
            self.__properties[k] = v
        end

        function sim.BaseObject:__tostring()
            return 'sim.Object(' .. self.__handle .. ')'
        end

        function sim.BaseObject:__tohandle()
            return self.__handle
        end

        function sim.BaseObject:__tocbor()
            local cbor = require 'simCBOR'
            return cbor.encode(self.__handle)
        end

        function sim.BaseObject:__pairs()
            return pairs(self.__properties)
        end

        function sim.BaseObject:__eq(o)
            return self.__handle == o.__handle
        end

        sim.Collection = class('sim.Collection', sim.BaseObject)

        sim.Collection.addItem = sim.addToCollection
        sim.Collection.checkCollision = sim.checkCollision
        sim.Collection.checkDistance = sim.checkDistance
        sim.Collection.remove = sim.removeCollection
        sim.Collection.removeItem = sim.removeFromCollection

        function sim.Collection:initialize(handle)
            sim.BaseObject.initialize(self, handle, 'collection')
        end

        sim.App = class('sim.App', sim.BaseObject)

        function sim.App:initialize(handle)
            if handle == nil then handle = sim.handle_app end
            assert(handle == sim.handle_app, 'invalid handle')

            sim.BaseObject.initialize(self, handle, 'app')

            -- pre-assign user namespaces to property groups:
            rawset(self, 'customData', sim.PropertyGroup(self, {prefix = 'customData'}))
            rawset(self, 'signal', sim.PropertyGroup(self, {prefix = 'signal'}))
            rawset(self, 'namedParam', sim.PropertyGroup(self, {prefix = 'namedParam'}))
        end

        sim.Scene = class('sim.Scene', sim.BaseObject)

        sim.Scene.getObjectsInTree = sim.getObjectsInTree
        sim.Scene.load = sim.loadScene
        sim.Scene.save = sim.saveScene

        function sim.Scene:initialize(handle)
            if handle == nil then handle = sim.handle_scene end
            assert(handle == sim.handle_scene, 'invalid handle')

            sim.BaseObject.initialize(self, handle, 'scene')

            -- pre-assign user namespaces to property groups:
            rawset(self, 'customData', sim.PropertyGroup(self, {prefix = 'customData'}))
            rawset(self, 'signal', sim.PropertyGroup(self, {prefix = 'signal'}))
        end

        function sim.Scene:__div(path)
            if path:sub(1, 1) ~= '/' then path = '/' .. path end
            return sim.getObject(path)
        end

        sim.Mesh = class('sim.Mesh', sim.BaseObject)

        function sim.Mesh:initialize(handle)
            sim.BaseObject.initialize(self, handle, 'mesh')
        end

        sim.Texture = class('sim.Texture', sim.BaseObject)

        function sim.Texture:initialize(handle)
            sim.BaseObject.initialize(self, handle, 'texture')
        end

        sim.DrawingObject = class('sim.DrawingObject', sim.BaseObject)

        sim.DrawingObject.addItem = sim.addDrawingObjectItem
        sim.DrawingObject.remove = sim.removeDrawingObject

        function sim.DrawingObject:initialize(handle)
            sim.BaseObject.initialize(self, handle, 'drawingObject')
        end

        sim.SceneObject = class('sim.SceneObject', sim.BaseObject)

        sim.SceneObject.getAlias = sim.getObjectAlias
        sim.SceneObject.getPose = sim.getObjectPose
        sim.SceneObject.getPosition = sim.getObjectPosition
        sim.SceneObject.getQuaternion = sim.getObjectQuaternion
        sim.SceneObject.getVelocity = sim.getObjectVelocity
        sim.SceneObject.remove = function(self) return sim.removeObjects{self} end
        sim.SceneObject.scaleObject = sim.scaleObject
        sim.SceneObject.setParent = sim.setObjectParent
        sim.SceneObject.setPose = sim.setObjectPose
        sim.SceneObject.setPosition = sim.setObjectPosition
        sim.SceneObject.setQuaternion = sim.setObjectQuaternion
        sim.SceneObject.visitTree = sim.visitTree

        function sim.SceneObject:initialize(handle, checkObjectType)
            sim.BaseObject.initialize(self, handle, checkObjectType)

            assert(sim.isHandle(handle), 'invalid handle')

            -- pre-assign user namespaces to property groups:
            rawset(self, 'customData', sim.PropertyGroup(self, {prefix = 'customData'}))
            rawset(self, 'signal', sim.PropertyGroup(self, {prefix = 'signal'}))
            rawset(self, 'refs', sim.PropertyGroup(self, {prefix = 'refs', newPropertyForcedType = sim.propertytype_handlearray}))
            rawset(self, 'origRefs', sim.PropertyGroup(self, {prefix = 'origRefs', newPropertyForcedType = sim.propertytype_handlearray}))

            self.__properties:registerLocalProperty('matrix',
                function()
                    return self.pose:totransform()
                end,
                function(m)
                    local Pose = require('simEigen').Pose
                    self.pose = Pose:fromtransform(m)
                end
            )
            self.__properties:registerLocalProperty('absMatrix',
                function()
                    return self.absPose:totransform()
                end,
                function(m)
                    local Pose = require('simEigen').Pose
                    self.absPose = Pose:fromtransform(m)
                end
            )
        end

        function sim.SceneObject:__div(path)
            if path:sub(1, 2) ~= './' then path = './' .. path end
            return sim.getObject(path, {proxy = self.__handle})
        end

        sim.Camera = class('sim.Camera', sim.SceneObject)

        function sim.Camera:initialize(handle)
            sim.SceneObject.initialize(self, handle, 'camera')
        end

        sim.Dummy = class('sim.Dummy', sim.SceneObject)

        sim.Dummy.checkCollision = sim.checkCollision
        sim.Dummy.checkDistance = sim.checkDistance

        function sim.Dummy:initialize(handle)
            sim.SceneObject.initialize(self, handle, 'dummy')
        end

        sim.ForceSensor = class('sim.ForceSensor', sim.SceneObject)

        sim.ForceSensor.checkSensor = sim.readForceSensor
        sim.ForceSensor.getForce = function ()
            local f, t = sim.readForceSensor(self.__handle)
            return f
        end
        sim.ForceSensor.getTorque = function ()
            local f, t = sim.readForceSensor(self.__handle)
            return t
        end

        function sim.ForceSensor:initialize(handle)
            sim.SceneObject.initialize(self, handle, 'forceSensor')
        end

        sim.Graph = class('sim.Graph', sim.SceneObject)

        sim.Graph.addCurve = sim.addGraphCurve
        sim.Graph.addStream = sim.addGraphStream
        sim.Graph.resetGraph = sim.resetGraph

        function sim.Graph:initialize(handle)
            sim.SceneObject.initialize(self, handle, 'graph')
        end

        sim.Joint = class('sim.Joint', sim.SceneObject)

        sim.Joint.getForce = sim.getJointForce
        sim.Joint.resetDynamicObject = sim.resetDynamicObject
        sim.Joint.getVelocity = sim.getJointVelocity

        function sim.Joint:initialize(handle)
            sim.SceneObject.initialize(self, handle, 'joint')
        end

        sim.Light = class('sim.Light', sim.SceneObject)

        function sim.Light:initialize(handle)
            sim.SceneObject.initialize(self, handle, 'light')
        end

        sim.OcTree = class('sim.OcTree', sim.SceneObject)

        sim.OcTree.checkCollision = sim.checkCollision
        sim.OcTree.checkDistance = sim.checkDistance
        sim.OcTree.checkPointOccupancy = sim.checkOctreePointOccupancy
        sim.OcTree.insertObject = sim.insertObjectIntoOctree
        sim.OcTree.insertVoxels = sim.insertVoxelsIntoOctree
        sim.OcTree.removeVoxels = sim.removeVoxelsFromOctree
        sim.OcTree.subtractObject = sim.subtractObjectFromOctree

        function sim.OcTree:initialize(handle)
            sim.SceneObject.initialize(self, handle, 'ocTree')
        end

        sim.PointCloud = class('sim.PointCloud', sim.SceneObject)

        sim.PointCloud.checkCollision = sim.checkCollision
        sim.PointCloud.checkDistance = sim.checkDistance
        sim.PointCloud.insertObject = sim.insertObjectIntoPointCloud
        sim.PointCloud.insertPoints = sim.insertPointsIntoPointCloud
        sim.PointCloud.intersectPoints = sim.intersectPointsWithPointCloud
        sim.PointCloud.removePoints = sim.removePointsFromPointCloud
        sim.PointCloud.subtractObject = sim.subtractObjectFromPointCloud

        function sim.PointCloud:initialize(handle)
            sim.SceneObject.initialize(self, handle, 'pointCloud')
        end

        sim.ProximitySensor = class('sim.ProximitySensor', sim.SceneObject)

        sim.ProximitySensor.checkSensor = sim.checkProximitySensor
        sim.ProximitySensor.resetSensor = sim.resetProximitySensor

        function sim.ProximitySensor:initialize(handle)
            sim.SceneObject.initialize(self, handle, 'proximitySensor')
        end

        sim.Script = class('sim.Script', sim.SceneObject)

        sim.Script.callFunction = sim.callScriptFunction
        sim.Script.executeScriptString = sim.executeScriptString
        sim.Script.getApiFunc = sim.getApiFunc
        sim.Script.getApiInfo = sim.getApiInfo
        sim.Script.getStackTraceback = sim.getStackTraceback
        sim.Script.init = sim.initScript

        function sim.Script:initialize(handle)
            sim.SceneObject.initialize(self, handle, 'script')
        end

        sim.Shape = class('sim.Shape', sim.SceneObject)

        sim.Shape.addForce = sim.addForce
        sim.Shape.addForceAndTorque = sim.addForceAndTorque
        sim.Shape.alignBB = sim.alignShapeBB
        sim.Shape.checkCollision = sim.checkCollision
        sim.Shape.checkDistance = sim.checkDistance
        sim.Shape.computeMassAndInertia = sim.computeMassAndInertia
        sim.Shape.getAppearance = sim.getShapeAppearance
        sim.Shape.getDynVelocity = sim.getShapeVelocity
        sim.Shape.relocateFrame = sim.relocateShapeFrame
        sim.Shape.resetDynamicObject = sim.resetDynamicObject
        sim.Shape.setAppearance = sim.setShapeAppearance
        sim.Shape.setShapeBB = sim.setShapeBB
        sim.Shape.ungroup = sim.ungroupShape

        function sim.Shape:initialize(handle)
            sim.SceneObject.initialize(self, handle, 'shape')
        end

        sim.VisionSensor = class('sim.VisionSensor', sim.SceneObject)

        sim.VisionSensor.checkSensor = sim.checkVisionSensor
        sim.VisionSensor.checkSensorEx = sim.checkVisionSensorEx
        sim.VisionSensor.read = sim.readVisionSensor
        sim.VisionSensor.reset = sim.resetVisionSensor

        function sim.VisionSensor:initialize(handle)
            sim.SceneObject.initialize(self, handle, 'visionSensor')
        end

        sim.Object = {}

        sim.Object.class = {
            app = sim.App,
            scene = sim.Scene,
            mesh = sim.Mesh,
            texture = sim.Texture,
            collection = sim.Collection,
            drawingObject = sim.DrawingObject,
            camera = sim.Camera,
            dummy = sim.Dummy,
            forceSensor = sim.ForceSensor,
            graph = sim.Graph,
            joint = sim.Joint,
            light = sim.Light,
            ocTree = sim.OcTree,
            pointCloud = sim.PointCloud,
            proximitySensor = sim.ProximitySensor,
            script = sim.Script,
            shape = sim.Shape,
            texture = sim.Texture,
            visionSensor = sim.VisionSensor,
        }

        setmetatable(sim.Object, {
            __call = function(self, arg, opts)
                local handle
                if math.type(arg) == 'integer' then
                    assert(opts == nil, 'invalid args')
                    handle = arg
                    assert(sim.isHandle(handle) or handle == sim.handle_app or handle == sim.handle_scene or handle >= 10000000, 'invalid handle')
                elseif sim.Object:isobject(arg) then
                    assert(opts == nil, 'invalid args')
                    handle = arg.handle
                else
                    error 'invalid arguments to sim.Object(...)'
                end

                local objectType = sim.getStringProperty(handle, 'objectType')
                local cls = sim.Object.class[objectType]
                assert(cls, 'unsupported object type: ' .. objectType)
                return cls(handle)
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
            f = sim.getObject '/Floor'
            b = sim.getObject '/Floor/box'
            assert(b == f / 'box')
            if #sim.scene.orphans > 0 then
                assert(sim.scene.orphans[1].parent == nil)
            else
                print 'skipped orphans test'
            end
            assert(b == f.children[1])
            assert(b.parent == f)
            d1 = sim.createObject{
                objectType = 'dummy',
                alias = 'd1',
            }
            assert(sim.Object:isobject(d1))
            d2 = sim.createObject{
                objectType = 'dummy',
                alias = 'd2',
                dummyType = sim.dummytype_dynloopclosure,
                linkedDummy = d1,
            }
            assert(d2.linkedDummy == d1)
            sim.removeObjects{d1, d2}
            cbor = require 'simCBOR'
            ip = table.fromipairs(f.children)
            assert(cbor.encode(ip) == cbor.encode{b})
            assert(b:getPosition(f):norm() < 1e-7)

            a = sim.createObject {objectType = 'dummy', alias = 'a', }
            b = sim.createObject {objectType = 'dummy', alias = 'b', }
            c = sim.createObject {objectType = 'dummy', alias = 'c', }
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
            rawset(self, '__object', sim.getObject(...))
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
        sim.scene = sim.Scene()
        sim.app = sim.App()
    end
}
