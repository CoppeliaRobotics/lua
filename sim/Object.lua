local class = require 'middleclass'
local json = require 'dkjson'

local objectMetaInfo = {}

return {
    extend = function(sim)
        sim.PropertyGroup = class 'sim.PropertyGroup'

        function sim.PropertyGroup:initialize(handle, opts)
            self.__handle = handle
            self.__opts = table.clone(opts or {})
            self.__localProperties = {}
            if self.__opts.newPropertyForcedType then
                -- resolve constant value (i.e. 'sim.foo' -> sim.foo)
                local s = self.__opts.newPropertyForcedType
                assert(s:startswith 'sim.', 'invalid value for option "newPropertyForcedType": ' .. s)
                self.__opts.newPropertyForcedType = sim[s:sub(5)]
            end
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

            local ptype = sim.getPropertyInfo(self.__handle, k)
            if ptype then
                return sim.getPropertyGetter(ptype)(self.__handle, k)
            end

            if sim.getPropertyName(self.__handle, 0, {prefix = k .. '.'}) then
                return sim.PropertyGroup(self.__handle, {prefix = k})
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

            local ptype = self.__opts.newPropertyForcedType or sim.getPropertyInfo(self.__handle, k)
            if ptype then
                sim.getPropertySetter(ptype)(self.__handle, k, v)
            else
                sim.setProperty(self.__handle, k, v)
            end
        end

        function sim.PropertyGroup:__tostring()
            local s = 'sim.PropertyGroup(' .. self.__handle
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
                local pname = sim.getPropertyName(self.__handle, i, {prefix = prefix})
                if pname == nil then break end
                pname = string.stripprefix(pname, prefix)
                local pname2 = string.gsub(pname, '%..*$', '')
                if pname == pname2 then
                    local ptype, pflags, descr = sim.getPropertyInfo(self.__handle, prefix .. pname)
                    local readable = pflags & 2 == 0
                    if readable then
                        props[pname2] = sim.getPropertyGetter(ptype)(self.__handle, prefix .. pname)
                    end
                elseif props[pname2] == nil then
                    props[pname2] = sim.PropertyGroup(self.__handle, {prefix = prefix .. pname})
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

        function sim.Object.static:resolveFunction(methodName, funcName)
            local fields = string.split(funcName, '%.')
            local moduleName = table.remove(fields, 1)
            local moduleNameWithoutVer = moduleName:gsub('-.*', '')
            local funcNameWithoutVer = moduleNameWithoutVer .. '.' .. funcName:gsub('^[^.]+%.', '')
            local module = moduleName == 'sim-2' and sim or require(moduleName)
            local func = module
            for _, field in ipairs(fields) do func = (func or {})[field] end
            if func == sim.callMethod then
                -- new methods, via sim.callMethod interface
                -- (need first two args: target, methodName)
                return function(targetObject, ...)
                    return sim.callMethod(targetObject, methodName, ...)
                end
            else
                return function(...)
                    __proxyFuncName__ = funcNameWithoutVer .. ',' .. methodName .. '@method'
                    return func(...)
                end
            end
        end

        function sim.Object:initialize(handle)
            if sim.Object:isobject(handle) then
                handle = handle.handle
            end
            if handle == sim.handle_self then
                handle = sim_detachedscript_handle
            end
            assert(math.type(handle) == 'integer', 'invalid argument type')
            rawset(self, '__handle', handle)
        end

        function sim.Object:__setupPropertyGroups()
            if rawget(self, '__properties') then return end

            local handle = rawget(self, '__handle')

            -- this property group exposes object's top-level properties as self's table keys (via __index):
            rawset(self, '__properties', sim.PropertyGroup(handle))

            self.__properties:registerLocalProperty('handle', function() return self.__handle end)

            local objectType = sim.getStringProperty(handle, 'objectType')
            objectMetaInfo[objectType] = objectMetaInfo[objectType]
                or json.decode(sim.getStringProperty(handle, 'objectMetaInfo'))
            for ns, opts in pairs(objectMetaInfo[objectType].namespaces) do
                rawset(self, ns, sim.PropertyGroup(handle, table.update({prefix = ns}, opts)))
            end
            rawset(self, '__methods', objectMetaInfo[objectType].methods)
        end

        function sim.Object:__index(k)
            self:__setupPropertyGroups()

            -- lookup existing properties first:
            local v = rawget(self, k)
            if v then return v end

            -- lookup method:
            local methods = rawget(self, '__methods')
            if methods[k] then
                if type(methods[k]) == 'string' then
                    local funcName = methods[k]
                    methods[k] = sim.Object:resolveFunction(k, funcName)
                    assert(methods[k], string.format('sim.Object(%s): method %s: failed to resolve function %s', self.handle, k, funcName))
                end
                return methods[k]
            end

            -- redirect to default property group otherwise:
            local p = rawget(self, '__properties')[k]
            if p ~= nil then return p end
        end

        function sim.Object:__newindex(k, v)
            self:__setupPropertyGroups()

            self.__properties[k] = v
        end

        function sim.Object:__copy()
            local o = self.class(self.__handle)
            return o
        end

        function sim.Object:__deepcopy(m)
            return self:__copy()
        end

        function sim.Object:__tostring()
            return 'sim.Object(' .. self.__handle .. ')'
        end

        function sim.Object:__tohandle()
            return self.__handle
        end

        function sim.Object:__tocbor()
            local cbor = require 'simCBOR'
            local cbor_c = require 'org.conman.cbor_c'
            return cbor_c.encode(0xC0, cbor.Tags.Sim.Handle)
                .. cbor.encode(self.__handle)
        end

        function sim.Object:__pairs()
            self:__setupPropertyGroups()

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
            d1 = sim.scene:createObject{
                objectType = 'dummy',
                alias = 'd1',
            }
            assert(sim.Object:isobject(d1))
            d2 = sim.scene:createObject{
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

            a = sim.scene:createObject {objectType = 'dummy', alias = 'a', }
            b = sim.scene:createObject {objectType = 'dummy', alias = 'b', }
            c = sim.scene:createObject {objectType = 'dummy', alias = 'c', }
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

        function sim.ObjectArray:initialize(arg, count)
            if type(arg) == 'string' then
                arg = sim.scene:getObject(arg)
            end
            if math.type(arg) == 'integer' then
                arg = sim.Object(arg)
            end
            if type(arg) == 'table' and not getmetatable(arg) then
                local n = count or arg.n or #arg
                for i = 1, n do
                    arg[i] = (function(h)
                        if sim.Object:isobject(h) then return h end
                        if h == -1 or h == nil then return nil end
                        return sim.Object(h)
                    end)(arg[i])
                end
                arg.n = n
            end
            if sim.Object:isobject(arg) then
                -- implicit object array (argument = first object of the array)
                rawset(self, '__object0', arg)
                assert(self[1] == arg, 'implicit sim.ObjectArray must point to first object of the array')
            elseif type(arg) == 'table' and not getmetatable(arg) then
                -- explicit object array
                rawset(self, '__objects', arg)
                count = count or arg.n or #arg
            end
            rawset(self, '__count', count)
        end

        function sim.ObjectArray:__index(k)
            if type(k) == 'string' then
                local ret = {}
                for i = 1, #self do
                    table.insert(ret, self[i][k])
                end
                return ret
            end

            assert(math.type(k) == 'integer', 'invalid index type')
            local object0 = rawget(self, '__object0')
            if object0 then
                if k >= 1 then
                    local siblings = object0.parent and object0.parent.children or sim.scene.orphans
                    local name = object0.name
                    for i, child in ipairs(siblings) do
                        if child.name == name then
                            k = k - 1
                            if k <= 0 then return child end
                        end
                    end
                end
            else
                local objects = rawget(self, '__objects')
                return objects[k]
            end
        end

        function sim.ObjectArray:__len()
            local count = rawget(self, '__count')
            if count then return count end
            count = 0
            local object0 = rawget(self, '__object0')
            local siblings = object0.parent and object0.parent.children or sim.scene.orphans
            local name = object0.name
            for i, child in ipairs(siblings) do
                if child.name == name then
                    count = count + 1
                end
            end
            return count
        end

        function sim.ObjectArray:__newindex(k, v)
            for i = 1, #self do
                self[i][k] = v
            end
        end

        function sim.ObjectArray:__todisplay()
            return _S.anyToString(self:totable())
        end

        function sim.ObjectArray:totable()
            local ret = {}
            for i = 1, #self do
                table.insert(ret, self[i])
            end
            return ret
        end

        -- definition of constants / static objects:
        sim.scene = sim.Object(sim.handle_scene)
        sim.app = sim.Object(sim.handle_app)
        sim.self = sim.Object(sim.handle_self)
    end
}
