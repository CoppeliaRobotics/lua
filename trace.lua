if string.gsplit == nil and string.split == nil then
    function string:gsplit(delimiter)
        local function escape_magic(s)
            local MAGIC_CHARS_SET = '[()%%.[^$%]*+%-?]'
            if s == nil then return end
            return (s:gsub(MAGIC_CHARS_SET, '%%%1'))
        end
        delimiter = delimiter or ' '
        if self:sub(-#delimiter) ~= delimiter then self = self .. delimiter end
        return self:gmatch('(.-)' .. escape_magic(delimiter))
    end

    function string:split(delimiter, tabled)
        tabled = tabled or false
        local ans = {}
        for item in self:gsplit(delimiter) do table.insert(ans, item) end
        if tabled then return ans end
        return unpack(ans)
    end
end

local function trace(f, funcName)
    if type(f) == 'function' then
        return function(...)
            local ret = {f(...)}
            local s = funcName .. '(' .. getAsString(...) .. ') --> ' .. getAsString(unpack(ret))
            print(s)
            return unpack(ret)
        end
    elseif type(f) == 'string' then
        funcName = funcName or f
        error('not implemented yet')
    else
        error('invalid arg type')
    end
end

return trace
