local class = require 'middleclass'
local json = require 'dkjson'

local objectMetaInfo = {} -- cache for objectMetaInfo, by objectType
local objectMethods  = {} -- cache for object methods, by objectType

local Object = class 'sim.Object'
local PropertyGroup = require 'sim.PropertyGroup'

local sim = {
    callMethod = callMethod,
    handle_scene = -12,
    handle_app = -13,
    handle_self = -4,
    propertytype_method = 240,
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

    -- this property group exposes object's top-level properties as self's table keys (via __index):
    rawset(self, '__properties', PropertyGroup(self))

    self.__properties:registerLocalProperty('handle', function() return self.__handle end)

    local objectType = self:callMethod('getStringProperty', 'objectType')

    if not objectMetaInfo[objectType] then
        local mi = self:callMethod('getStringProperty', 'objectMetaInfo')
        objectMetaInfo[objectType] = json.decode(mi)
        assert(objectMetaInfo[objectType], 'invalid JSON in objectMetaInfo of ' .. handle)
    end
    for ns, opts in pairs(objectMetaInfo[objectType].namespaces) do
        rawset(self, ns, PropertyGroup(self, table.update({prefix = ns}, opts)))
    end

    if not objectMethods[objectType] then
        objectMethods[objectType] = {}
        for i = 0, 1e9 do
            local pname = self:callMethod('getPropertyName', i, {objectType = prefix})
            if not pname then break end
            local ptype = self:callMethod('getPropertyInfo', pname)
            if ptype == sim.propertytype_method then
                objectMethods[objectType][pname] = function(o, ...)
                    return o:callMethod(pname, ...)
                end
            end
        end
    end
    rawset(self, '__methods', objectMethods[objectType])
end

function Object:__index(k)
    self:__setupPropertyGroups()

    -- lookup existing properties first:
    local v = rawget(self, k)
    if v then return v end

    -- lookup method:
    local methods = rawget(self, '__methods')
    if methods[k] then return methods[k] end

    -- redirect to default property group otherwise:
    local p = rawget(self, '__properties')[k]
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
    local handle = rawget(self, '__handle')
    return sim.callMethod(handle, method, ...)
end

function Object:toobject(o)
    assert(self == Object, 'class method')
    if Object:isobject(o) then return o end
    if math.type(o) == 'integer' or type(o) == 'string' then return Object(o) end
    error 'bad type'
end

function Object.static.unittest()
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

    a = scene:createObject {objectType = 'dummy', name = 'a', }
    b = scene:createObject {objectType = 'dummy', name = 'b', }
    c = scene:createObject {objectType = 'dummy', name = 'c', }
    c.parent = b
    b.parent = a
    a.modelBase = true
    assert(c:getName(1) == '/a/c')
    b.modelBase = true
    assert(c:getName(1) == '/a/b/c')

    a:setBufferProperty('customData.buf2', Buffer '\x00\x01\x02')
    assert(Buffer:isbuffer(a.customData.buf2))
    assert(isbuffer(a.customData.buf2))
    a:setProperty('customData.buf3', Buffer '\x00\x01\x02')
    assert(Buffer:isbuffer(a.customData.buf3))
    assert(isbuffer(a.customData.buf3))

    local function testCustomData(o, n, v, t, tm, ...)
        o.customData[n] = v
        local errMsg = 'value ' .. tostring(v) .. ' not ' .. tostring(t) .. (tm and (' ' .. tostring(tm)) or '')
        if type(t) == 'string' then
            local tf = t == 'integer' and math.type or type
            assert(tf(o.customData[n]) == t, errMsg)
        else
            assert(t[tm](t, v, ...), errMsg)
        end
    end
    local simEigen = require 'simEigen'
    testCustomData(a, 'i', 2, 'integer')
    testCustomData(a, 'f', 2.5, 'number')
    testCustomData(a, 'b', true, 'boolean')
    testCustomData(a, 'str', '\x00\x01\x02', 'string')
    testCustomData(a, 'buf', Buffer '\x00\x01\x02', Buffer, 'isbuffer')
    testCustomData(a, 'col', Color 'red', Color, 'iscolor')
    testCustomData(a, 'v2', simEigen.Vector(2), simEigen.Vector, 'isvector', 2)
    testCustomData(a, 'v3', simEigen.Vector(3), simEigen.Vector, 'isvector', 3)
    testCustomData(a, 'm3x3', simEigen.Matrix(3, 3), simEigen.Matrix, 'ismatrix', 3, 3)
    testCustomData(a, 'm4x4', simEigen.Matrix(4, 4), simEigen.Matrix, 'ismatrix', 4, 4)
    --testCustomData(a, 'm', simEigen.Matrix(2, 2), simEigen.Matrix, 'ismatrix')
    testCustomData(a, 'q', simEigen.Quaternion{0, 1, 0, 0}, simEigen.Quaternion, 'isquaternion')
    testCustomData(a, 'p', simEigen.Pose{0, 0, 0, 0, 0, 0, 1}, simEigen.Pose, 'ispose')

    a:setProperties {
        ['color.diffuse'] = {0, 1, 1}
    }
    assert(a.color.diffuse:html() == '#00ffff')

    scene:removeObjects{a, b, c}

    print(debug.getinfo(1, 'S').source, 'tests passed')
end

-- definition of constants / static objects:
Object.scene = Object(sim.handle_scene)
Object.app = Object(sim.handle_app)
Object.self = Object(sim.handle_self)

return Object
