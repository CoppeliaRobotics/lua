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

        sim.Object = class 'sim.Object'

        sim.Object.static.objMetaInfo = {
            baseObject = {
                methods = {
                    getBoolProperty = 'sim-2.getBoolProperty',
                    getBufferProperty = 'sim-2.getBufferProperty',
                    getColorProperty = 'sim-2.getColorProperty',
                    getExplicitHandling = 'sim-2.getExplicitHandling',
                    getFloatArrayProperty = 'sim-2.getFloatArrayProperty',
                    getFloatProperty = 'sim-2.getFloatProperty',
                    getHandleArrayProperty = 'sim-2.getHandleArrayProperty',
                    getHandleProperty = 'sim-2.getHandleProperty',
                    getIntArray2Property = 'sim-2.getIntArray2Property',
                    getIntArrayProperty = 'sim-2.getIntArrayProperty',
                    getIntProperty = 'sim-2.getIntProperty',
                    getLongProperty = 'sim-2.getLongProperty',
                    getPoseProperty = 'sim-2.getPoseProperty',
                    getProperties = 'sim-2.getProperties',
                    getPropertiesInfos = 'sim-2.getPropertiesInfos',
                    getProperty = 'sim-2.getProperty',
                    getPropertyInfo = 'sim-2.getPropertyInfo',
                    getPropertyName = 'sim-2.getPropertyName',
                    getPropertyTypeString = 'sim-2.getPropertyTypeString',
                    getQuaternionProperty = 'sim-2.getQuaternionProperty',
                    getStringProperty = 'sim-2.getStringProperty',
                    getTableProperty = 'sim-2.getTableProperty',
                    getVector2Property = 'sim-2.getVector2Property',
                    getVector3Property = 'sim-2.getVector3Property',
                    removeProperty = 'sim-2.removeProperty',
                    setBoolProperty = 'sim-2.setBoolProperty',
                    setBufferProperty = 'sim-2.setBufferProperty',
                    setColorProperty = 'sim-2.setColorProperty',
                    setFloatArrayProperty = 'sim-2.setFloatArrayProperty',
                    setFloatProperty = 'sim-2.setFloatProperty',
                    setHandleArrayProperty = 'sim-2.setHandleArrayProperty',
                    setHandleProperty = 'sim-2.setHandleProperty',
                    setIntArray2Property = 'sim-2.setIntArray2Property',
                    setIntArrayProperty = 'sim-2.setIntArrayProperty',
                    setIntProperty = 'sim-2.setIntProperty',
                    setLongProperty = 'sim-2.setLongProperty',
                    setPoseProperty = 'sim-2.setPoseProperty',
                    setProperties = 'sim-2.setProperties',
                    setProperty = 'sim-2.setProperty',
                    setQuaternionProperty = 'sim-2.setQuaternionProperty',
                    setStringProperty = 'sim-2.setStringProperty',
                    setTableProperty = 'sim-2.setTableProperty',
                    setVector2Property = 'sim-2.setVector2Property',
                    setVector3Property = 'sim-2.setVector3Property',
                },
            },
            app = {
                superClass = 'baseObject',
                namespaces = {
                    customData = true,
                    signal = true,
                    namedParam = true,
                    refs = false,
                    origRefs = false,
                },
                methods = {
                },
            },
            scene = {
                superClass = 'baseObject',
                namespaces = {
                    customData = true,
                    signal = true,
                    namedParam = false,
                    refs = false,
                    origRefs = false,
                },
                methods = {
                    getObjectsInTree = 'sim-2.getObjectsInTree',
                    load = 'sim-2.loadScene',
                    save = 'sim-2.saveScene',
                },
            },
            mesh = {
                superClass = 'baseObject',
                methods = {
                },
            },
            texture = {
                superClass = 'baseObject',
                methods = {
                },
            },
            collection = {
                superClass = 'baseObject',
                methods = {
                    addItem = 'sim-2.addToCollection',
                    checkCollision = 'sim-2.checkCollision',
                    checkDistance = 'sim-2.checkDistance',
                    remove = 'sim-2.removeCollection',
                    removeItem = 'sim-2.removeFromCollection',
                },
            },
            drawingObject = {
                superClass = 'baseObject',
                methods = {
                    addItem = 'sim-2.addDrawingObjectItem',
                    remove = 'sim-2.removeDrawingObject',
                },
            },
            sceneObject = {
                superClass = 'baseObject',
                namespaces = {
                    customData = true,
                    signal = true,
                    namedParam = false,
                    refs = true,
                    origRefs = true,
                },
                methods = {
                    getAlias = 'sim-2.getObjectAlias',
                    getPose = 'sim-2.getObjectPose',
                    getPosition = 'sim-2.getObjectPosition',
                    getQuaternion = 'sim-2.getObjectQuaternion',
                    getVelocity = 'sim-2.getObjectVelocity',
                    --remove = function(self) return sim.removeObjects{self} end,
                    scaleObject = 'sim-2.scaleObject',
                    setParent = 'sim-2.setObjectParent',
                    setPose = 'sim-2.setObjectPose',
                    setPosition = 'sim-2.setObjectPosition',
                    setQuaternion = 'sim-2.setObjectQuaternion',
                    visitTree = 'sim-2.visitTree',
                },
            },
            camera = {
                superClass = 'sceneObject',
                methods = {
                },
            },
            dummy = {
                superClass = 'sceneObject',
                methods = {
                    checkCollision = 'sim-2.checkCollision',
                    checkDistance = 'sim-2.checkDistance',
                },
            },
            forceSensor = {
                superClass = 'sceneObject',
                methods = {
                    checkSensor = 'sim-2.readForceSensor',
                },
            },
            graph = {
                superClass = 'sceneObject',
                methods = {
                    addCurve = 'sim-2.addGraphCurve',
                    addStream = 'sim-2.addGraphStream',
                    resetGraph = 'sim-2.resetGraph',
                },
            },
            joint = {
                superClass = 'sceneObject',
                methods = {
                    getForce = 'sim-2.getJointForce',
                    resetDynamicObject = 'sim-2.resetDynamicObject',
                    getVelocity = 'sim-2.getJointVelocity',
                },
            },
            light = {
                superClass = 'sceneObject',
                methods = {
                },
            },
            ocTree = {
                superClass = 'sceneObject',
                methods = {
                    checkCollision = 'sim-2.checkCollision',
                    checkDistance = 'sim-2.checkDistance',
                    checkPointOccupancy = 'sim-2.checkOctreePointOccupancy',
                    insertObject = 'sim-2.insertObjectIntoOctree',
                    insertVoxels = 'sim-2.insertVoxelsIntoOctree',
                    removeVoxels = 'sim-2.removeVoxelsFromOctree',
                    subtractObject = 'sim-2.subtractObjectFromOctree',
                },
            },
            pointCloud = {
                superClass = 'sceneObject',
                methods = {
                    checkCollision = 'sim-2.checkCollision',
                    checkDistance = 'sim-2.checkDistance',
                    insertObject = 'sim-2.insertObjectIntoPointCloud',
                    insertPoints = 'sim-2.insertPointsIntoPointCloud',
                    intersectPoints = 'sim-2.intersectPointsWithPointCloud',
                    removePoints = 'sim-2.removePointsFromPointCloud',
                    subtractObject = 'sim-2.subtractObjectFromPointCloud',
                },
            },
            proximitySensor = {
                superClass = 'sceneObject',
                methods = {
                    checkSensor = 'sim-2.checkProximitySensor',
                    resetSensor = 'sim-2.resetProximitySensor',
                },
            },
            script = {
                superClass = 'sceneObject',
                methods = {
                    callFunction = 'sim-2.callScriptFunction',
                    executeScriptString = 'sim-2.executeScriptString',
                    getApiFunc = 'sim-2.getApiFunc',
                    getApiInfo = 'sim-2.getApiInfo',
                    getStackTraceback = 'sim-2.getStackTraceback',
                    init = 'sim-2.initScript',
                },
            },
            shape = {
                superClass = 'sceneObject',
                methods = {
                    addForce = 'sim-2.addForce',
                    addForceAndTorque = 'sim-2.addForceAndTorque',
                    alignBB = 'sim-2.alignShapeBB',
                    checkCollision = 'sim-2.checkCollision',
                    checkDistance = 'sim-2.checkDistance',
                    computeMassAndInertia = 'sim-2.computeMassAndInertia',
                    getAppearance = 'sim-2.getShapeAppearance',
                    getDynVelocity = 'sim-2.getShapeVelocity',
                    relocateFrame = 'sim-2.relocateShapeFrame',
                    resetDynamicObject = 'sim-2.resetDynamicObject',
                    setAppearance = 'sim-2.setShapeAppearance',
                    setShapeBB = 'sim-2.setShapeBB',
                    ungroup = 'sim-2.ungroupShape',
                },
            },
            visionSensor = {
                superClass = 'sceneObject',
                methods = {
                    checkSensor = 'sim-2.checkVisionSensor',
                    checkSensorEx = 'sim-2.checkVisionSensorEx',
                    read = 'sim-2.readVisionSensor',
                    reset = 'sim-2.resetVisionSensor',
                },
            },
        }

        function sim.Object.static:getObjMetaInfo(objectType)
            local ret = {
                methods = {},
                namespaces = {},
            }
            local objMetaInfo = sim.Object.objMetaInfo[objectType]
            while objMetaInfo do
                for k, v in pairs(objMetaInfo.methods) do
                    if ret.methods[k] == nil then
                        ret.methods[k] = v
                    end
                end
                for k, v in pairs(objMetaInfo.namespaces or {}) do
                    if ret.namespaces[k] == nil then
                        ret.namespaces[k] = v
                    end
                end
                objMetaInfo = sim.Object.objMetaInfo[objMetaInfo.superClass or '']
            end
            return ret
        end

        function sim.Object.static:resolveFunction(funcName)
            local fields = string.split(funcName, '%.')
            local moduleName = table.remove(fields, 1)
            local module
            if moduleName == 'sim-2' then
                module = sim
            else
                module = require(moduleName)
            end
            for _, field in ipairs(fields) do
                module = module[field]
            end
            return module
        end

        function sim.Object:initialize(handle)
            if sim.Object:isobject(handle) then
                handle = handle.handle
            end

            assert(math.type(handle) == 'integer', 'invalid argument type')
            rawset(self, '__handle', handle)

            -- this property group exposes object's top-level properties as self's table keys (via __index):
            rawset(self, '__properties', sim.PropertyGroup(self))

            self.__properties:registerLocalProperty('handle', function() return self.__handle end)

            local objMetaInfo = sim.Object:getObjMetaInfo(sim.getStringProperty(self, 'objectType'))
            for ns, b in pairs(objMetaInfo.namespaces) do
                if b then
                    rawset(self, ns, sim.PropertyGroup(self, {prefix = ns}))
                end
            end
            local methods = {}
            for m, f in pairs(objMetaInfo.methods) do
                methods[m] = sim.Object:resolveFunction(f)
            end
            rawset(self, '__methods', methods)
        end

        function sim.Object:__copy()
            local o = self.class(self.__handle)
            return o
        end

        function sim.Object:__deepcopy(m)
            return self:__copy()
        end

        function sim.Object:__index(k)
            -- lookup existing properties first:
            local v = rawget(self, k)
            if v then return v end

            -- lookup method:
            local m = (rawget(self, '__methods') or {})[k]
            if m then return m end

            -- redirect to default property group otherwise:
            local p = rawget(self, '__properties')[k]
            if p ~= nil then return p end
        end

        function sim.Object:__newindex(k, v)
            self.__properties[k] = v
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
            return pairs(self.__properties)
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

        function sim.Object.static.unittest()
            f = sim.getObject '/Floor'
            b = sim.getObject '/Floor/box'
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
        sim.scene = sim.Object(sim.handle_scene)
        sim.app = sim.Object(sim.handle_app)
    end
}
