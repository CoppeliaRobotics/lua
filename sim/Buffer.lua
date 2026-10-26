local class = require 'middleclass'

local Buffer = class 'sim.Buffer'

function Buffer:initialize(s)
    if Buffer:isbuffer(s) then
        s = s.__buff__
    elseif type(s) == 'string' then
        -- already string
    else
        error('bad type: ' .. type(s))
    end
    rawset(self, '__buff__', s)
end

function Buffer:__concat(other)
    local lhs, rhs
    if Buffer:isbuffer(self) then
        lhs = self.__buff__
    elseif type(self) == 'string' then
        lhs = self
    else
        error('bad LHS type: ' .. type(self))
    end
    if Buffer:isbuffer(other) then
        rhs = other.__buff__
    elseif type(other) == 'string' then
        rhs = other
    else
        error('bad RHS type: ' .. type(other))
    end
    return Buffer(lhs .. rhs)
end

function Buffer:__len()
    return #self.__buff__
end

function Buffer:__eq(other)
    return Buffer:isbuffer(self) and Buffer:isbuffer(other) and self.__buff__ == other.__buff__
end

function Buffer:__index(k)
    if type(k) == 'string' and Buffer[k] == nil then
        -- Allow access to string methods, e.g., bufferObj:find(...)
        local strFunc = string[k]
        if strFunc and type(strFunc) == 'function' then
            -- Return a function that, when called, applies the string function to the buffer's content
            return function(bufferObj, ...)
                local ret = {strFunc(bufferObj.__buff__, ...)}
                if type(ret[1]) == 'string' then
                    ret[1] = Buffer(ret[1])
                end
                return table.unpack(ret)
            end
        end
    end
end

function Buffer:__newindex(k, v)
    error('attempt to modify a buffer value')
end

function Buffer:__tostring()
    return self.__buff__
end

function Buffer:__todisplay()
    return self.class.name .. '([' .. #self.__buff__ .. ' bytes])'
end

function Buffer:__tocbor()
    local cbor = require('simCBOR')
    return cbor.TYPE.BIN(self.__buff__)
end

function Buffer:__isbuffer()
    return Buffer:isbuffer(self)
end

function Buffer:isbuffer(o)
    assert(self == Buffer, 'class method')
    return Buffer.isInstanceOf(o, Buffer)
end

function Buffer:str()
    return self.__buff__
end

function Buffer:tobuffer(o)
    assert(self == Buffer, 'class method')
    if Buffer:isbuffer(o) then return o end
    if type(o) == 'string' then return Buffer(o) end
    error 'bad type'
end

return Buffer
