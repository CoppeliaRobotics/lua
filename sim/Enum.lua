local class = require 'middleclass'

local EnumValue = class 'sim.EnumValue'

function EnumValue:initialize(intValue, stringValue, enum)
    self.intValue = intValue
    self.stringValue = stringValue
    self.enum = enum
end

function EnumValue:__tostring()
    return string.format('%d (%s)', self.intValue, self.stringValue)
end

local Enum = class 'sim.Enum'

function Enum.static:createEnums(sim)
    for _, n in ipairs(sim.app.enumTypes) do
        local n1 = n:sub(4):gsub("^.", string.lower)
        assert(sim[n1] == nil, 'cannot write enum to sim.' .. n1 .. ': name clash')
        sim[n1] = sim.Enum(n, sim.app:getEnumInfo(n))
    end
end

function Enum:initialize(name, items)
    assert(type(name) == 'string', 'enum name must be a string')
    assert(type(items) == 'table', 'invalid items type')
    assert(next(items), 'empty items')
    self.__name = name
    self.__items = {}
    self.__invItems = {}
    self.__plainItems = {}
    for k, v in pairs(items) do
        self:__addItem(k, v)
    end
end

function Enum:__addItem(k, v)
    assert(type(k) == 'string')
    assert(math.type(v) == 'integer')
    self.__items[k] = EnumValue(v, k, self)
    self.__invItems[v] = self.__items[k]
    self.__plainItems[k] = v
end

function Enum:__index(k)
    if type(k) == 'string' then
        return self.__items[k]
    elseif math.type(k) == 'integer' then
        return self.__invItems[k]
    else
        error('invalid key type')
    end
end

function Enum:__newindex(k, v)
    if k == '__items' or k == '__invItems' or k == '__plainItems' or k == '__name' then
        rawset(self, k, v)
        return
    end
    error()
end

function Enum:__tostring()
    return self.class.name .. '(\'' .. self.__name .. '\')'
end

function Enum:__pairs()
    return pairs(self.__plainItems)
end

function Enum:__dump()
    return table.clone(self)
end

return Enum
