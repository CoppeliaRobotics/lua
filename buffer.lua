-- 'buffer' metatable:

__buffmetatable__ = {
    __concat = function(a, b)
        return tobuffer(tostring(a) .. tostring(b))
    end,
    __len = function(self)
        return #self.__buff__
    end,
    __eq = function(a, b)
        return isbuffer(a) and isbuffer(b) and a.__buff__ == b.__buff__
    end,
    __index = function(self, k)
        -- Mimic string behavior: return the character at position k if k is a number
        if type(k) == 'number' then
            return string.sub(self.__buff__, k, k) -- return a string
        elseif type(k) == 'string' then
            -- Allow access to string methods, e.g., bufferObj:find(...)
            local strFunc = string[k]
            if strFunc and type(strFunc) == 'function' then
                -- Return a function that, when called, applies the string function to the buffer's content
                return function(_, ...)
                    return strFunc(self.__buff__, ...) -- return a string
                end
            end
        end
        -- Optional: handle other keys or throw an error
        error('attempt to index a buffer value with an unsupported key')
    end,
    __newindex = function(self, k)
        error('attempt to modify a buffer value')
    end,
    __tostring = function(self)
        return self.__buff__
    end,
    __tocbor = function(self)
        return cbor.TYPE.BIN(self.__buff__)
    end,
    newobj = function(txt)
        if __buffmetatable__.isinstance(txt) then return txt end
        return setmetatable({__buff__ = tostring(txt)}, __buffmetatable__)
    end,
    isinstance = function(obj)
        return getmetatable(obj) == __buffmetatable__
    end,
}

-- 'buffer' interface:

function isbuffer(obj)
    if auxFunc('useBuffers') then
        return __buffmetatable__.isinstance(obj)
    else
        sim.addLog(sim.verbosity_warnings, 'called isbuffer() with useBuffers = false')
    end
end

function tobuffer(txt)
    if auxFunc('useBuffers') then
        return __buffmetatable__.newobj(txt)
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
        if first and arg == 'org.conman.cbor' then
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
