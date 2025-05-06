table.getn = table.getn or function(a)
    return #a
end

if unpack then
    -- Lua5.1
    table.pack = function(...)
        return {n = select("#", ...), ...}
    end
    table.unpack = unpack
else
    unpack = table.unpack
end

function table.index(t)
    return function(idx)
        return t[idx]
    end
end

function table.eq(a, b)
    if a == nil and b == nil then return true end
    if a == nil or b == nil then return false end
    if type(a) ~= 'table' or type(b) ~= 'table' then return false end
    if #a ~= #b then return false end
    --[[
    for i = 1, #a do
        if type(a) ~= type(b) then return false end
        if type(a[i]) == 'table' then
            if not table.eq(a[i], b[i]) then return false end
        else
            if a[i] ~= b[i] then return false end
        end
    end
    ]]
    for ak, av in pairs(a) do
        if b[ak] == nil then return false end
    end
    for bk, bv in pairs(b) do
        local av = a[bk]
        if av == nil then return false end
        if type(av) ~= type(bv) then return false end
        if type(av) == 'table' then
            if not table.eq(av, bv) then return false end
        else
            if av ~= bv then return false end
        end
    end
    return true
end

function table.keys(t)
    local r = {}
    for k in pairs(t) do table.insert(r, k) end
    return r
end

function table.isarray(t)
    if type(t) ~= 'table' then return false end
    local m = 0
    local count = 0
    for k, v in pairs(t) do
        if type(k) == 'number' and math.type(k) == 'integer' and k >= 1 then
            if k > m then m = k end
            count = count + 1
        else
            return false
        end
    end
    return m == count
end

function table.join(t, sep, opts, visited)
    sep = sep or ', '
    opts = opts and table.clone(opts) or {}
    opts.indentString = opts.indentString or '    '
    opts.quoteStrings = opts.quoteStrings == true
    if opts.indent == true then opts.indent = 0 end
    if opts.indent then opts.indent = opts.indent + 1 end
    visited = visited or {}
    local s = ''
    visited[t] = true
    local function concat(showKey, key, val)
        if not opts.indent and s ~= '' then s = s .. sep end
        if opts.indent then s = s .. string.rep(opts.indentString, opts.indent) end
        if showKey then
            if type(key) ~= 'string' then s = s .. '[' end
            s = s .. tostring(key)
            if type(key) ~= 'string' then s = s .. ']' end
            s = s .. ' = '
        end
        if type(val) == 'table' then
            if visited[val] then
                s = s .. '...'
            else
                s = s .. table.tostring(val, sep, opts, visited)
            end
        elseif type(val) == 'string' then
            if opts.quoteStrings then
                s = s .. "'" .. val .. "'"
            else
                s = s .. val
            end
        else
            s = s .. tostring(val)
        end
        if opts.indent then s = s .. sep .. '\n' end
    end
    local allKeys = {}
    for key in pairs(t) do allKeys[key] = true end
    for key, val in ipairs(t) do
        allKeys[key] = nil
        concat(false, key, val)
    end
    allKeys = table.keys(allKeys)
    table.sort(
        allKeys, function(k1, k2)
            -- sort keys by type, then by name
            local v1, v2 = t[k1], t[k2]
            local t1, t2 = type(v1), type(v2)
            local function order(k)
                return ({
                    ['boolean'] = 1,
                    ['number'] = 2,
                    ['string'] = 3,
                    ['function'] = 4,
                    ['userdata'] = 5,
                    ['thread'] = 6,
                    ['table'] = 7,
                })[k] or 8
            end
            local o1, o2 = order(t1), order(t2)
            return o1 < o2 or (o1 == o2 and k1 < k2)
        end
    )
    for _, key in ipairs(allKeys) do
        local val = t[key]
        concat(true, key, val)
    end
    return s
end

function table.tostring(t, sep, opts, visited)
    opts = opts and table.clone(opts) or {}
    opts.indentString = opts.indentString or '    '
    opts.quoteStrings = opts.quoteStrings ~= false
    if opts.indent == true then opts.indent = 0 end

    local s = '{'
    if next(t) then
        if opts.indent then s = s .. '\n' end
        s = s .. table.join(t, sep, opts, visited)
        if opts.indent then s = s .. string.rep(opts.indentString, opts.indent) end
    end
    s = s .. '}'
    return s
end

function table.slice(t, first, last, step)
    local ret = {}
    for i = first or 1, last or #t, step or 1 do table.insert(ret, t[i]) end
    return ret
end

function table.print(t)
    print(table.tostring(t))
end

function table.find(t, item, equalsFunc)
    equalsFunc = equalsFunc or function(x)
        return item == x
    end
    for i, x in ipairs(t) do if equalsFunc(x) then return i end end
end

function table.compare(a, b, compareFunc)
    compareFunc = compareFunc or function(a, b)
        if a < b then return -1 end
        if a > b then return 1 end
        return 0
    end
    if #a == 0 and #b == 0 then return 0 end
    if #a == 0 then return -1 end
    if #b == 0 then return 1 end
    local c = compareFunc(a[1], b[1])
    if c == 0 then
        return table.compare(table.slice(a, 2), table.slice(b, 2), compareFunc)
    else
        return c
    end
end

function table.reversed(t)
    local ret = {}
    for k, v in pairs(t) do ret[k] = v end
    for i = 1, #t do ret[#t - i + 1] = t[i] end
    return ret
end

function table.clone(t)
    local copy = {}
    for k, v in pairs(t) do copy[k] = v end
    return copy
end

function table.deepcopy(orig, opts, copies)
    opts = opts or {}
    copies = copies or {}

    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        local mo = getmetatable(orig)
        if mo and opts.cloneMetatable == nil then
            addLog(430, "cloning (table.deepcopy) a table with a metatable: the metatable will not be cloned. pass opts={cloneMetatable=true} to clone it, or opts={cloneMetatable=false} to silence this warning.")
            opts.cloneMetatable = false
        end

        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[table.deepcopy(orig_key, opts, copies)] = table.deepcopy(orig_value, opts, copies)
            end
            if mo then
                if opts.cloneMetatable then
                    setmetatable(copy, table.deepcopy(getmetatable(orig), opts, copies))
                else
                    setmetatable(copy, getmetatable(orig))
                end
            end
        end
    else
        copy = orig
    end
    return copy
end

function table.add(...)
    local ar = {...}
    local retVal = {}
    for i = 1, #ar do
        for j, v in ipairs(ar[i]) do
            table.insert(retVal, v)
        end
    end
    return retVal
end

function table.extend(t, ...)
    local ar = {...}
    for i = 1, #ar do
        for j, v in ipairs(ar[i]) do
            table.insert(t, v)
        end
    end
end

function table.rep(value, size)
    local retVal = {}
    for i = 1, size do
        table.insert(retVal, value)
    end
    return retVal
end

function table.batched(tbl, n)
    local retVal = {}
    local ind = 1
    while ind <= #tbl do
        local t = {}
        for i = 1, n do
            table.insert(t, tbl[ind])
            ind = ind + 1
        end
        table.insert(retVal, t)
    end
    return retVal
end

function table.flatten(tbl, opts, prefix, tbl1)
    opts = opts or {}
    prefix = prefix or ''
    tbl1 = tbl1 or {}
    for k, v in pairs(tbl) do
        assert(type(k) == 'string', 'only string keys are supported')
        if type(v) == 'table' and not table.isarray(v) and type(k) == 'string' then
            table.flatten(v, opts, prefix .. k .. '.', tbl1)
        else
            tbl1[prefix .. k] = v
        end
    end
    return tbl1
end

function table.collapse(tbl, depth)
    depth = depth or 1
    if depth < 0 then
        depth = 999
    end
    if depth == 0 then
        return tbl
    end
    local retVal = {}
    local cnt = 0
    for _, sublist in ipairs(tbl) do
        if table.isarray(sublist) then
            cnt = cnt + 1
            for _, item in ipairs(sublist) do
                table.insert(retVal, item)
            end
        else
            table.insert(retVal, sublist)
        end
    end
    if cnt == 0 then
        depth = 1
    end
    return table.collapse(retVal, depth - 1)
end

function table.unflatten(tbl, opts)
    opts = opts or {}
    local ret = {}
    for k, v in pairs(tbl) do
        assert(type(k) == 'string', 'only string keys are supported')
        local ks = {}
        for ki in string.gmatch(k, '([^.]+)') do table.insert(ks, ki) end
        local tmp = ret
        for i = 1, #ks - 1 do
            tmp[ks[i]] = tmp[ks[i]] or {}
            tmp = tmp[ks[i]]
        end
        tmp[ks[#ks]] = v
    end
    return ret
end

function table.update(t, ...)
    local ar = {...}
    for i = 1, #ar do
        for k, v in pairs(ar[i]) do
            t[k] = v
        end
    end
    return t
end

function table.items(tbl, opts)
    opts = opts or {}
    opts.sort = opts.sort ~= false
    local ret = {}
    for k, v in pairs(tbl) do
        table.insert(ret, {k, v})
    end
    if opts.sort then
        table.sort(ret, function(a, b) return a[1] < b[1] end)
    end
    return ret
end

if arg and #arg == 1 and arg[1] == 'test' then
    assert(table.eq({1, 2, 3}, {1, 2, 3}))
    assert(not table.eq({1, 2, 3, 4}, {1, 2, 3}))
    assert(not table.eq({}, {1, 2, 3}))
    assert(table.tostring {1, 2, 3} == '{1, 2, 3}')
    assert(table.find({10, 20, 30, 40}, 30) == 3)
    assert(table.find({10, 20, 30, 40}, 50) == nil)
    assert(table.compare({10}, {10}) == 0)
    assert(table.compare({10}, {10, 0}) < 0)
    assert(table.compare({10, 0}, {10}) > 0)
    assert(table.compare({11, 0}, {10, 1}) > 0)
    assert(table.compare({9, 0}, {10, 1}) < 0)
    assert(table.eq(table.reversed {10, 20, 30}, {30, 20, 10}))
    assert(table.compare(table.add({1, 2},{3, 4},{5, 6}), {1, 2, 3, 4, 5, 6}) == 0)
    assert(table.compare(table.add({},{}), {}) == 0)
    assert(table.compare(table.rep(21, 3), {21, 21, 21}) == 0)
    assert(table.tostring(table.batched({1, 2, 3, 4, 5, 6}, 2)) == '{{1, 2}, {3, 4}, {5, 6}}')
    assert(table.eq(table.flatten {a = {b = 1, c = 3}, x = {y = 10, z = 3}}, {['a.b'] = 1, ['a.c'] = 3, ['x.y'] = 10, ['x.z'] = 3}))
    assert(table.eq(table.unflatten {['a.b'] = 1, ['a.c'] = 3, ['x.y'] = 10, ['x.z'] = 3}, {a = {b = 1, c = 3}, x = {y = 10, z = 3}}))
    assert(table.eq(table.items({a = 'A', b = 3, c = {'c', 'd'}}, {sort = true}), {{'a', 'A'}, {'b', 3}, {'c', {'c', 'd'}}}))
    print(debug.getinfo(1, 'S').source, 'tests passed')
end
