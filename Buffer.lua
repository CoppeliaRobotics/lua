local class = require 'middleclass'

local Buffer = class 'Buffer'

function Buffer:initialize(s)
    if Buffer:isbuffer(s) then
        self.__buff__ = s.__buff__
    elseif type(s) == 'string' then
        self.__buff__ = s
    else
        error('bad type: ' .. type(s))
    end
end

function Buffer:__concat(other)
    if Buffer:isbuffer(s) then
        return Buffer(self.__buff__ .. other.__buff__)
    elseif type(s) == 'string' then
        return Buffer(self.__buff__ .. other)
    else
        error('bad type: ' .. type(other))
    end
end

function Buffer:__len()
    return #self.__buff__
end

function Buffer:__eq(other)
    return Buffer:isbuffer(self) and Buffer:isbuffer(other) and self.__buff__ == other.__buff__
end

--function Buffer:__index(k)
--    return self.__buff__[k]
--end

--function Buffer:__newindex(k, v)
--    error('attempt to modify a buffer value')
--end

function Buffer:__tostring()
    return self.__buff__
end

function Buffer:__todisplay()
    return 'Buffer([' .. #self.__buff__ .. ' bytes])'
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

-- 'buffer' interface:

function isbuffer(obj)
    if auxFunc('useBuffers') then
        return Buffer:isbuffer(obj)
    else
        addLog(sim.verbosity_warnings, 'called isbuffer() with useBuffers = false')
    end
end

function tobuffer(txt)
    if auxFunc('useBuffers') then
        return Buffer:tobuffer(txt)
    else
        return tostring(txt)
    end
end

-- 'buffer' integration with common functions:

tonumber = wrap(tonumber, function(origFunc)
    return function(s)
        if isbuffer(s) then
            s = tostring(s)
        end
        return origFunc(s)
    end
end)

string.byte = wrap(string.byte, function(origFunc)
    return function(s, ...)
        if isbuffer(s) then
            s = tostring(s)
        end
        return origFunc(s, ...)
    end
end)

string.sub = wrap(string.sub, function(origFunc)
    return function(s, ...)
        if isbuffer(s) then
            s = tostring(s)
        end
        return origFunc(s, ...)
    end
end)

string.gsub = wrap(string.gsub, function(origFunc)
    return function(s, ...)
        if isbuffer(s) then
            s = tostring(s)
        end
        return origFunc(s, ...)
    end
end)

string.match = wrap(string.match, function(origFunc)
    return function(s, ...)
        if isbuffer(s) then
            s = tostring(s)
        end
        return origFunc(s, ...)
    end
end)

string.gmatch = wrap(string.gmatch, function(origFunc)
    return function(s, ...)
        if isbuffer(s) then
            s = tostring(s)
        end
        return origFunc(s, ...)
    end
end)

string.find = wrap(string.find, function(origFunc)
    return function(s, ...)
        if isbuffer(s) then
            s = tostring(s)
        end
        return origFunc(s, ...)
    end
end)

string.len = wrap(string.len, function(origFunc)
    return function(s, ...)
        if isbuffer(s) then
            s = tostring(s)
        end
        return origFunc(s, ...)
    end
end)

string.rep = wrap(string.rep, function(origFunc)
    return function(s, ...)
        if isbuffer(s) then
            s = tostring(s)
        end
        return origFunc(s, ...)
    end
end)

string.reverse = wrap(string.reverse, function(origFunc)
    return function(s, ...)
        if isbuffer(s) then
            s = tostring(s)
        end
        return origFunc(s, ...)
    end
end)

string.upper = wrap(string.upper, function(origFunc)
    return function(s, ...)
        if isbuffer(s) then
            s = tostring(s)
        end
        return origFunc(s, ...)
    end
end)

string.lower = wrap(string.lower, function(origFunc)
    return function(s, ...)
        if isbuffer(s) then
            s = tostring(s)
        end
        return origFunc(s, ...)
    end
end)

return Buffer
