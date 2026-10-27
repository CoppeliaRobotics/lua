local class = require 'middleclass'
local cbor = require 'org.conman.cbor'

local array = class 'array'

local null = setmetatable({}, {__tocbor = function(self) return cbor.SIMPLE.null() end})

function array:initialize(values)
    self.n = 0
    if values ~= nil then
        assert(type(values) == "table", "array() expects an array-like table or nil")
        self.n = values.n or #values
        for i = 1, self.n do
            self[i] = values[i]
        end
    end
end

function array:__len()
    return self.n
end

function array:__tostring()
    local s = {}
    for i = 1, self.n do
        s[i] = string.anytostring(self[i])
    end
    return '{' .. table.join(s, ', ') .. '}'
end

function array:__tocbor(...)
    local arr = {}
    for i = 1, self.n do
        if self[i] == nil then
            arr[i] = null
        else
            arr[i] = self[i]
        end
    end
    return cbor.TYPE.ARRAY(arr, ...)
end

function array.static:pack(...)
    return array(table.pack(...))
end

return array
