local class = require 'middleclass'

local Buffer = class 'Buffer'

function Buffer:initialize(s)
    self.__buff__ = tostring(s)
end

function Buffer:__concat(other)
    return Buffer(tostring(self) .. tostring(other))
end

function Buffer:__len()
    return #self.__buff__
end

function Buffer:__eq(other)
    return Buffer:isbuffer(self) and Buffer:isbuffer(other) and self.__buff__ == other.__buff__
end

function Buffer:__index(k)
    return self.__buff__[k]
end

function Buffer:__newindex(k, v)
    error('attempt to modify a buffer value')
end

function Buffer:__tostring()
    return self.__buff__
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

require = wrap(require, function(origRequire)
    return function(...)
        local arg = ({...})[1]
        local first = not package.loaded[arg]
        local ret = {origRequire(...)}
        if first and arg == 'simCBOR' then
            (function(cbor)
                cbor.decode = wrap(cbor.decode, function(origFunc)
                    return function(b, ...)
                        if isbuffer(b) then
                            b = tostring(b)
                        end
                        return origFunc(b, ...)
                    end
                end)
            end)(ret[1])
        end
        return table.unpack(ret)
    end
end)

return Buffer
