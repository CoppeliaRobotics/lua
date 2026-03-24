local class = require 'middleclass'

local Enum = class 'sim.Enum'

function Enum:initialize(name, items)
    self.__name = name
    self.__items = {}
    self.__invItems = {}
    for n, v in pairs(items) do
        assert(type(n) == 'string', 'bad enum key type: ' .. type(n))
        assert(type(v) == 'number', 'bad enum value type: ' .. type(v))
        assert(math.type(v) == 'integer', 'bad enum value type: ' .. math.type(v))
        self.__items[n] = v
        assert(self.__invItems[v] == nil, 'duplicate enum value: ' .. v)
        self.__invItems[v] = n
    end
end

function Enum:__index(k)
    if type(k) == 'string' then
        return self.__items[k]
    elseif math.type(k) == 'integer' then
        return self.__invItems[k]
    end
    error('invalid index type')
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
