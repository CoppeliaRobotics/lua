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
    for i = 1, #a do
        if type(a) ~= type(b) then return false end
        if type(a[i]) == 'table' then
            if not table.eq(a[i], b[i]) then return false end
        else
            if a[i] ~= b[i] then return false end
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

function table.deepcopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[table.deepcopy(orig_key, copies)] = table.deepcopy(orig_value, copies)
            end
            setmetatable(copy, table.deepcopy(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end


function table.add(...)
    local ar = {...}
    local retVal = {}
    for i = 1, #ar do
        for j = 1, #ar[i], 1 do
            table.insert(retVal, ar[i][j])
        end
    end
    return retVal
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
    print(debug.getinfo(1, 'S').source, 'tests passed')
end
