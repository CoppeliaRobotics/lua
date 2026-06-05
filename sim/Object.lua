local class = require 'middleclass'
local json = require 'dkjson'

local Object = class 'sim.Object'
local PropertyGroup = require 'sim.PropertyGroup'

local sim = {
    callMethod = callMethod,
    handle_scene = -12,
    handle_app = -13,
    handle_self = -4,
    propertytype_method = 240,
    propertyinfo_removable = 4,
}

function Object:initialize(handle)
    if Object:isobject(handle) then
        handle = handle.handle
    end
    if handle == sim.handle_self then
        handle = sim_detachedscript_handle
    end
    assert(math.type(handle) == 'integer', 'invalid argument type')
    rawset(self, '__handle', handle)
end

function Object:__setupPropertyGroups()
    if rawget(self, '__properties') then return end

    local handle = rawget(self, '__handle')

    rawset(self, '__properties', PropertyGroup(self))

    self.__properties:registerLocalProperty('handle', function() return self.__handle end)

    self.__properties:registerLocalProperty('__methods', function()
        local methods = {}
        for i = 0, 1e9 do
            local pname = self:callMethod('getPropertyName', i, {objectType = prefix})
            if not pname then break end
            local ptype = self:callMethod('getPropertyInfo', pname)
            if ptype == sim.propertytype_method then
                methods[pname] = function(o, ...)
                    return o:callMethod(pname, ...)
                end
            end
        end
        return methods
    end)

    local objectType = self:callMethod('getStringProperty', 'objectType')
    rawset(self, 'objectType', objectType)

    local namespaces = self:callMethod('getStringArrayProperty', 'metaInfo.namespaces')
    for _, ns in pairs(namespaces) do
        rawset(self, ns, PropertyGroup(self, {prefix = ns, newPropertyForcedType = (ns == 'refs' or ns == 'origRefs') and 22 or nil}))
    end
end

function Object:__index(k)
    self:__setupPropertyGroups()

    -- lookup existing properties first:
    local v = rawget(self, k)
    if v then return v end

    -- redirect to default property group otherwise:
    local p = (rawget(self, '__properties') or {})[k]
    if p ~= nil then return p end
end

function Object:__newindex(k, v)
    self:__setupPropertyGroups()

    self.__properties[k] = v
end

function Object:__copy()
    local o = self.class(self.__handle)
    return o
end

function Object:__deepcopy(m)
    return self:__copy()
end

function Object:__tostring()
    return self.class.name .. '(' .. self.__handle .. ')'
end

function Object:__tohandle()
    return self.__handle
end

function Object:__tocbor()
    local cbor = require 'simCBOR'
    local cbor_c = require 'org.conman.cbor_c'
    return cbor_c.encode(0xC0, cbor.Tags.Sim.Handle)
        .. cbor.encode(self.__handle)
end

function Object:__pairs()
    self:__setupPropertyGroups()

    return pairs(self.__properties)
end

function Object:__eq(o)
    return self.__handle == o.__handle
end

function Object:__isobject()
    return Object:isobject(self)
end

function Object:isobject(o)
    assert(self == Object, 'class method')
    return Object.isInstanceOf(o, Object)
end

function Object:callMethod(method, ...)
    -- note: this method will be overwritten by sim-2.lua, thus changing from
    --       sim.callMethod==[C]callMethod, to [Lua]sim.callMethod
    return sim.callMethod(self, method, ...)
end

function Object:isValid()
    return sim.callMethod(self, 'isValid')
end

function Object:getPropertyInfo(pname, opts)
    return self:callMethod('getPropertyInfo', pname, opts)
end

function Object:getPropertyInfos(pname, opts)
    return self:callMethod('getPropertyInfos', pname, opts)
end

--[[
-- getPropertyInfo with caching:

local propertyInfo   = {} -- cache for property info, by objectType

function Object:getPropertyInfo(pname, opts)
    opts = opts or {}
    if propertyInfo[self.objectType] == nil then
        propertyInfo[self.objectType] = {}
    end
    local ptype, pflags, descr
    if propertyInfo[self.objectType][pname] then
        ptype, pflags, descr = table.unpack(propertyInfo[self.objectType][pname])
    else
        ptype, pflags, descr = self:callMethod('getPropertyInfo', pname, table.update(opts, {bitCoded = 1}))
        if pflags and (pflags & sim.propertyinfo_removable) > 0 then
            return ptype, pflags, descr
        end
        if ptype then
            propertyInfo[self.objectType][pname] = {ptype, pflags, descr}
        end
    end
    return ptype, pflags, descr
end

function Object:getPropertyInfos(pname, opts)
    local sim = require 'sim-2'
    opts = opts or {}
    local infos = {}
    local ptype, pflags, metaInfo = self:getPropertyInfo(pname)
    if not ptype then return end
    infos.type = ptype
    infos.flags = {
        value = pflags,
        readable = pflags & sim.propertyinfo_notreadable == 0,
        writable = pflags & sim.propertyinfo_notwritable == 0,
        removable = pflags & sim.propertyinfo_removable > 0,
        silent = pflags & sim.propertyinfo_silent > 0,
        large = pflags & sim.propertyinfo_largedata > 0,
        deprecated = pflags & sim.propertyinfo_deprecated > 0,
        constant = pflags & sim.propertyinfo_constant > 0,
    }
    if opts.decodeMetaInfo ~= false then
        if metaInfo ~= '' then
            local json = require 'dkjson'
            local decodedMetaInfo = json.decode(metaInfo)
            assert(decodedMetaInfo ~= nil, 'invalid meta info: ' .. metaInfo)
            for k, v in pairs(decodedMetaInfo) do
                assert(infos[k] == nil)
                infos[k] = v
            end
        end
    else
        infos.metaInfo = metaInfo
    end
    return infos
end

]]

function Object:toobject(o)
    assert(self == Object, 'class method')
    if Object:isobject(o) then return o end
    if math.type(o) == 'integer' then return Object(o) end
    error 'bad type'
end

function Object.static.unittest()
    local sim = require 'sim-2'
    local scene = Object.scene
    f = scene:getObject '/Floor'
    b = scene:getObject '/Floor/box'
    if #scene.orphans > 0 then
        assert(scene.orphans[1].parent == nil)
    else
        print 'skipped orphans test'
    end
    assert(b == f.children[1])
    assert(b.parent == f)
    d1 = scene:createObject{
        objectType = 'dummy',
        name = 'd1',
    }
    assert(Object:isobject(d1))
    d2 = scene:createObject{
        objectType = 'dummy',
        name = 'd2',
        dummyType = 0, -- dummyType = sim.dummytype_dynloopclosure,
        linkedDummy = d1,
    }
    assert(d2.linkedDummy == d1)
    scene:removeObjects{d1, d2}
    cbor = require 'simCBOR'
    ip = table.fromipairs(f.children)
    assert(cbor.encode(ip) == cbor.encode{b})
    assert(b:getPosition(f):norm() < 1e-7)

    -- remove any leftover object from a previously failed test:
    local olda = scene:getObject('/a', {noError = true})
    if olda then olda:removeModel() end

    a = scene:createObject {objectType = 'dummy', name = 'a', }
    b = scene:createObject {objectType = 'dummy', name = 'b', }
    c = scene:createObject {objectType = 'dummy', name = 'c', }
    c.parent = b
    b.parent = a
    a.modelBase = true
    assert(c:getName(1) == '/a/c')
    b.modelBase = true
    assert(c:getName(1) == '/a/b/c')

    a.customData.i = 2
    assert(math.type(a.customData.i) == 'integer')

    a.customData.f = 2.5
    assert(type(a.customData.f) == 'number')

    a.customData.b = true
    assert(type(a.customData.b) == 'boolean')

    a.customData.str = 'abc'
    assert(type(a.customData.str) == 'string')

    a.customData.buf = Buffer 'abc'
    assert(Buffer:isbuffer(a.customData.buf))
    a:setBufferProperty('customData.buf2', Buffer 'abc')
    assert(Buffer:isbuffer(a.customData.buf2))
    assert(isbuffer(a.customData.buf2))
    a:setProperty('customData.buf3', Buffer 'abc')
    assert(Buffer:isbuffer(a.customData.buf3))
    assert(isbuffer(a.customData.buf3))

    a.customData.col = Color 'red'
    assert(Color:iscolor(a.customData.col))

    local simEigen = require 'simEigen'

    a.customData.vec2m = simEigen.Vector(2) -- this writes as "matrix" type
    assert(a:getPropertyInfo('customData.vec2m') == sim.propertytype_matrix)
    assert(simEigen.Vector:isvector(a.customData.vec2m, 2))
    --[[
    (getPropertyInfo type has been removed)
    a:setVector2Property('customData.vec2', simEigen.Vector(2)) -- this writes as "vector2" type
    assert(a:getPropertyInfo('customData.vec2') == sim.propertytype_vector2)
    assert(simEigen.Vector:isvector(a.customData.vec2, 2))
    ]]

    a.customData.vec3m = simEigen.Vector(3) -- this writes as "matrix" type
    assert(a:getPropertyInfo('customData.vec3m') == sim.propertytype_matrix)
    assert(simEigen.Vector:isvector(a.customData.vec3m, 3))
    a:setVector3Property('customData.vec3', simEigen.Vector(3)) -- this writes as "vector3" type
    assert(a:getPropertyInfo('customData.vec3') == sim.propertytype_vector3)
    assert(simEigen.Vector:isvector(a.customData.vec3, 3))

    a.customData.vecm = simEigen.Vector(10)
    assert(a:getPropertyInfo('customData.vecm') == sim.propertytype_matrix)
    assert(simEigen.Vector:isvector(a.customData.vecm))

    a.customData.mat3x3 = simEigen.Matrix(3, 3) -- this writes as "matrix" type
    assert(a:getPropertyInfo('customData.mat3x3') == sim.propertytype_matrix)
    assert(simEigen.Matrix:ismatrix(a.customData.mat3x3, 3, 3))
    --[[
    (matrix3x3 type has been removed)
    a:setMatrix3x3Property('customData.mat3x3', simEigen.Matrix(3, 3)) -- this writes as "matrix3x3" type
    assert(a:getPropertyInfo('customData.mat3x3') == sim.propertytype_matrix3x3)
    assert(simEigen.Matrix:ismatrix(a.customData.mat3x3, 3, 3))
    ]]

    a.customData.mat4x4 = simEigen.Matrix(4, 4) -- this writes as "matrix" type
    assert(a:getPropertyInfo('customData.mat4x4') == sim.propertytype_matrix)
    assert(simEigen.Matrix:ismatrix(a.customData.mat4x4, 4, 4))
    --[[
    (matrix4x4 type has been removed)
    a:setMatrix4x4Property('customData.mat4x4', simEigen.Matrix(4, 4)) -- this writes as "matrix4x4" type
    assert(a:getPropertyInfo('customData.mat4x4') == sim.propertytype_matrix4x4)
    assert(simEigen.Matrix:ismatrix(a.customData.mat4x4, 4, 4))
    ]]

    a.customData.mat = simEigen.Matrix(2, 2)
    assert(a:getPropertyInfo('customData.mat') == sim.propertytype_matrix)
    assert(simEigen.Matrix:ismatrix(a.customData.mat, 2, 2))

    a.customData.quat = simEigen.Quaternion{0, 1, 0, 0}
    assert(a:getPropertyInfo('customData.quat') == sim.propertytype_quaternion)
    assert(simEigen.Quaternion:isquaternion(a.customData.quat))

    a.customData.pose = simEigen.Pose{0, 0, 0, 0, 0, 0, 1}
    assert(a:getPropertyInfo('customData.pose') == sim.propertytype_pose)
    assert(simEigen.Pose:ispose(a.customData.pose))

    a:setProperties {
        ['color.diffuse'] = {0, 1, 1}
    }
    assert(a.color.diffuse:html() == '#00ffff')

    local oa = sim.ObjectArray{b, c}
    local t = oa:totable()
    assert(#t == 2 and t[1] == b.handle and t[2] == c.handle)
    a.refs.foo = oa
    assert(a.refs.foo[1] == b)
    assert(a.refs.foo[2] == c)

    scene:removeObjects{a, b, c}

    print(debug.getinfo(1, 'S').source, 'tests passed')
end

-- definition of constants / static objects:
Object.scene = Object(sim.handle_scene)
Object.app = Object(sim.handle_app)
Object.self = Object(sim.handle_self)

return Object
