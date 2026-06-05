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

local enumCache = {}

function Enum.static:fromName(name)
    if enumCache[name] then
        return enumCache[name]
    end
    local apidoc = require 'sim.apidoc'
    local enumInfo = apidoc.getEnum(name)
    assert(enumInfo, 'no such enum: ' .. name)
    local enum = Enum(name, enumInfo.items)
    enumCache[name] = enum
    return enum
end

function Enum.static:value(enumName, enumValue)
    local enum = Enum:fromName(enumName)
    return enum[enumValue]
end

function Enum:initialize(name, items)
    self.__name = name
    self.__items = {}
    self.__invItems = {}
    for k, v in pairs(items) do self:__addItem(k, v) end
end

function Enum:__addItem(k, v)
    assert(type(k) == 'string')
    assert(math.type(v) == 'integer')
    self.__items[k] = EnumValue(v, k, self)
    self.__invItems[v] = self.__items[k]
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
    if k == '__items' or k == '__invItems' or k == '__name' then
        rawset(self, k, v)
        return
    end
    error()
end

function Enum:__tostring()
    return self.class.name .. '(' .. self.__name .. ')'
end

function Enum:__pairs()
    return pairs(self.__items)
end

return Enum
