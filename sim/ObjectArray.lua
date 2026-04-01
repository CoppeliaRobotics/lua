local class = require 'middleclass'

local ObjectArray = class 'sim.ObjectArray'

function ObjectArray:initialize(arg, count)
    local Object = require 'sim.Object'
    if type(arg) == 'string' then
        arg = Object.scene:getObject(arg)
    end
    if math.type(arg) == 'integer' then
        arg = Object(arg)
    end
    if type(arg) == 'table' and not getmetatable(arg) then
        local n = count or arg.n or #arg
        for i = 1, n do
            arg[i] = (function(h)
                if Object:isobject(h) then return h end
                if h == -1 or h == nil then return nil end
                return Object(h)
            end)(arg[i])
        end
        arg.n = n
    end
    if Object:isobject(arg) then
        -- implicit object array (argument = first object of the array)
        rawset(self, '__object0', arg)
        assert(self[1] == arg, 'implicit ' .. self.class.name .. ' must point to first object of the array')
    elseif type(arg) == 'table' and not getmetatable(arg) then
        -- explicit object array
        rawset(self, '__objects', arg)
        count = count or arg.n or #arg
    end
    rawset(self, '__count', count)
end

function ObjectArray:__index(k)
    -- object-array property access (return a list of values)
    if type(k) == 'string' then
        local ret = {}
        for i = 1, #self do
            local obj = self[i]
            local v
            if obj ~= nil then
                v = obj[k]
            elseif obj == nil and k == 'handle' then
                -- handle is special: replace nil with -1
                v = -1
            end
            ret[i] = v
        end
        return ret
    end

    assert(math.type(k) == 'integer', 'invalid index type')
    local object0 = rawget(self, '__object0')
    local scene = require 'sim.Object'.scene
    if object0 then
        if k >= 1 then
            local siblings = object0.parent and object0.parent.children or scene.orphans
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

function ObjectArray:__len()
    local count = rawget(self, '__count')
    if count then return count end
    count = 0
    local object0 = rawget(self, '__object0')
    local scene = require 'sim.Object'.scene
    local siblings = object0.parent and object0.parent.children or scene.orphans
    local name = object0.name
    for i, child in ipairs(siblings) do
        if child.name == name then
            count = count + 1
        end
    end
    return count
end

function ObjectArray:__newindex(k, v)
    assert(type(k) ~= 'number', self.class.name .. ' contents cannot be modified. Use method :totable() to copy into a plain table.')
    assert(type(k) == 'string', 'invalid index type')
    for i = 1, #self do
        self[i][k] = v
    end
end

function ObjectArray:__tostring()
    return self.class.name .. _S.anyToString(self:totable())
end

function ObjectArray:__isobjectarray()
    return ObjectArray:isobjectarray(self)
end

function ObjectArray:__tocbor()
    local cbor = require 'simCBOR'
    local cbor_c = require 'org.conman.cbor_c'
    return cbor_c.encode(0xC0, cbor.Tags.Sim.HandleArray)
        .. cbor.encode(self.handle)
end

function ObjectArray:isobjectarray(o)
    assert(self == ObjectArray, 'class method')
    return ObjectArray.isInstanceOf(o, ObjectArray)
end

function ObjectArray:totable()
    local ret = {}
    for i = 1, #self do
        if self[i] then
            table.insert(ret, self[i].__handle)
        else
            table.insert(ret, -1)
        end
    end
    return ret
end

return ObjectArray
