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

function copy.unittest()
    local t = {1, 2, {10, 20}}
    local tc = copy.copy(t)
    local td = copy.deepcopy(t)
    t[1] = -1
    t[3][1] = -10
    assert(t[1] < 0 and t[3][1] < 0)
    assert(tc[1] > 0 and tc[3][1] < 0)
    assert(td[1] > 0 and td[3][1] > 0)

    local simEigen = require 'simEigen'
    local mtx = simEigen.Matrix
    local mt = {mtx{{1, 2}}, mtx{{3, 4}}}
    local mtc = copy.copy(mt)
    local mtd = copy.deepcopy(mt)
    mt[1] = mtx{{-1, -2}}
    mt[2][1][1] = -3
    assert(mt[1][1][1] < 0 and mt[2][1][1] < 0)
    assert(mtc[1][1][1] > 0 and mtc[2][1][1] < 0)
    assert(mtd[1][1][1] > 0 and mtd[2][1][1] > 0)
end

return copy
