local class = require 'middleclass'

return {
    extend = function(sim)
        sim.PropertyGroup = class 'sim.PropertyGroup'

        function sim.PropertyGroup:initialize(handle, opts)
            self.__handle = handle
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

            local ptype = sim.getPropertyInfo(self.__handle, k)
            if ptype then
                local t = sim.getPropertyTypeString(ptype, true)
                return sim['get' .. t:capitalize() .. 'Property'](self.__handle, k)
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
                local t = sim.getPropertyTypeString(ptype, true)
                sim['set' .. t:capitalize() .. 'Property'](self.__handle, k, v)
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
                        local t = sim.getPropertyTypeString(ptype, true)
                        props[pname2] = sim['get' .. t:capitalize() .. 'Property'](self.__handle, prefix .. pname)
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

        function sim.Object.static:resolveFunction(funcName)
            local fields = string.split(funcName, '%.')
            local moduleName = table.remove(fields, 1)
            local module = moduleName == 'sim-2' and sim or require(moduleName)
            local func = module
            for _, field in ipairs(fields) do func = (func or {})[field] end
            return func
        end

        function sim.Object:initialize(handle)
            if sim.Object:isobject(handle) then
                handle = handle.handle
            end

            assert(math.type(handle) == 'integer', 'invalid argument type')
            rawset(self, '__handle', handle)

            -- this property group exposes object's top-level properties as self's table keys (via __index):
            rawset(self, '__properties', sim.PropertyGroup(handle))

            self.__properties:registerLocalProperty('handle', function() return self.__handle end)

            local json = require 'dkjson'
            local objMetaInfo = json.decode(sim.getStringProperty(self, 'objectMetaInfo'))
            for ns, opts in pairs(objMetaInfo.namespaces) do
                rawset(self, ns, sim.PropertyGroup(handle, table.update({prefix = ns}, opts)))
            end
            local methods = {}
            for m, f in pairs(objMetaInfo.methods) do
                methods[m] = sim.Object:resolveFunction(f)
                if methods[m] == nil then
                    sim.addLog(sim.verbosity_errors, string.format('sim.Object(%s): method %s: failed to resolve function %s', handle, m, f))
                end
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
            local cbor_c = require 'org.conman.cbor_c'
            return cbor_c.encode(0xC0, 4294999999)
                .. cbor.encode(self.__handle)
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
