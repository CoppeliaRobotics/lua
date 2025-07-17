local copy = {}

function copy.copy(o, opts)
    opts = opts or {}
    local t = type(o)
    local c = o
    if t == 'table' then
        local mt = getmetatable(o)
        if mt == nil then
            c = table.clone(o)
        else
            c = callmeta(o, '__copy')
            assert(c ~= nil, 'object has a metatable but does not define __copy or __copy returned nil')
        end
    end
    return c
end

function copy.deepcopy(o, opts, copies)
    opts = opts or {}
    copies = copies or {}
    local t = type(o)
    local c = o
    if t == 'table' then
        local mt = getmetatable(o)
        if mt then
            c = callmeta(o, '__deepcopy')
            assert(c ~= nil, 'object has a metatable but does not define __deepcopy or __deepcopy returned nil')
        elseif copies[o] then
            c = copies[o]
        else
            c = {}
            copies[o] = c
            for k, v in next, o, nil do
                c[copy.deepcopy(k, opts, copies)] = copy.deepcopy(v, opts, copies)
            end
        end
    end
    return c
end

return copy
