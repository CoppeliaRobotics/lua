function range(from, to, step)
    assert(type(from) == 'number')
    step = step or 1
    if to == nil then from, to = 1, from end
    assert(type(to) == 'number')
    assert(from <= to)
    local ret = {}
    for i = from, to, step do table.insert(ret, i) end
    return ret
end

function map(f, ...)
    assert(type(f) == 'function')
    local tbls, ret = {...}, {}
    local i = 1
    while true do
        local args = {}
        for j, tbl in ipairs(tbls) do
            assert(type(tbl) == 'table')
            if tbl[i] == nil then return ret end
            table.insert(args, tbl[i])
        end
        table.insert(ret, f(table.unpack(args)))
        i = i + 1
    end
    return ret
end

function reduce(f, tbl, initial)
    assert(type(f) == 'function')
    assert(type(tbl) == 'table')
    initial = initial or 0
    local y = initial
    for i, x in ipairs(tbl) do y = f(y, x) end
    return y
end

function filter(f, tbl)
    assert(type(f) == 'function')
    assert(type(tbl) == 'table')
    local ret = {}
    for i, x in ipairs(tbl) do if f(x) then table.insert(ret, x) end end
    return ret
end

function foreach(f, ...)
    assert(type(f) == 'function')
    local tbls = {...}
    local i = 1
    while true do
        local args = {}
        for j, tbl in ipairs(tbls) do
            assert(type(tbl) == 'table')
            if tbl[i] == nil then return end
            table.insert(args, tbl[i])
        end
        f(table.unpack(args))
        i = i + 1
    end
end

function identity(...)
    return ...
end

function zip(...)
    return map(function(...) return {...} end, ...)
end

function negate(f)
    return function(x)
        return not f(x)
    end
end

function apply(f, ...)
    local args = table.pack(...)
    local count = args.n
    local offset = count - 1
    local packed = args[count]
    if type(packed) == 'table' then
        args[count] = nil
        for i, x in pairs(packed) do
            if type(i) == 'number' then
                count = offset + i
                args[count] = x
            end
        end
    end
    return f(table.unpack(args, 1, count))
end

function partial(f, ...)
    assert(type(f) == 'function')
    local args = table.pack(...)
    return function(...)
        local params = {table.unpack(args, 1, args.n)}
        params[args.n + 1] = table.pack(...)
        return apply(f, table.unpack(params, 1, args.n + 1))
    end
end

function any(f, tbl)
    f = f or function(x)
        return x
    end
    assert(type(f) == 'function')
    assert(type(tbl) == 'table')
    for i, x in ipairs(tbl) do if f(x) then return true end end
    return false
end

function all(f, tbl)
    f = f or function(x)
        return x
    end
    assert(type(f) == 'function')
    assert(type(tbl) == 'table')
    for i, x in ipairs(tbl) do if not f(x) then return false end end
    return true
end

function iter(tbl)
    local i = 0
    return function()
        i = i + 1
        if i <= #tbl then return table.unpack(tbl[i]) end
    end
end

function reify(func, name)
    name = name or ''
    _S = _S or {}
    _S.reifiedFunctions = _S.reifiedFunctions or {}
    if type(func) == 'function' then
        local funcStr = name .. string.gsub(tostring(func), '^function: 0x', '_f')
        if _S.reifiedFunctions[funcStr] ~= nil and _S.reifiedFunctions[funcStr] ~= func then
            error('function clash')
        end
        _S.reifiedFunctions[funcStr] = func
        return '_S.reifiedFunctions.' .. funcStr
    end
    if type(func) == 'string' then
        -- it is already string, but check that points to a function:
        assert(type(getvar(func)) == 'function')
        return func
    end
    error('unexpected type: ' .. type(func))
end

operator = {
    add = function(a, b) return a + b end,
    sub = function(a, b) return a - b end,
    mul = function(a, b) return a * b end,
    div = function(a, b) return a / b end,
    mod = function(a, b) return a % b end,
    idiv = function(a, b) return a // b end,
    pow = function(a, b) return a ^ b end,
    land = function(a, b) return a & b end,
    lor = function(a, b) return a | b end,
    lxor = function(a, b) return a ~ b end,
    lshl = function(a, b) return a << b end,
    lshr = function(a, b) return a >> b end,
    eq = function(a, b) return a == b end,
    neq = function(a, b) return a ~= b end,
    gt = function(a, b) return a > b end,
    ge = function(a, b) return a >= b end,
    lt = function(a, b) return a < b end,
    le = function(a, b) return a <= b end,
}

function sum(tbl)
    return reduce(operator.add, tbl)
end

function prod(tbl)
    return reduce(operator.mul, tbl)
end

if arg and #arg == 1 and arg[1] == 'test' then
    require 'tablex'
    assert(table.eq(range(3), {1, 2, 3}))
    assert(table.eq(map(operator.mul, {1, 2, 3}, {0, 1, 2}), {0, 2, 6}))
    assert(reduce(operator.add, {1, 2, 3, 4}) == 10)
    assert(table.eq(filter(function(x) return x % 2 == 0 end, {1, 2, 3, 4, 5}), {2, 4}))
    gt0 = partial(operator.lt, 0)
    assert(all(gt0, {1, 2, 3, 4}))
    assert(not all(gt0, {0, 1, 2, 3, 4}))
    assert(any(gt0, {-1, -2, 0, 1, -5}))
    assert(not any(gt0, {-1, -2, 0, -11, -5}))
    assert(table.eq(zip({1, 2, 3, 4}, {'a', 'b', 'c'}), {{1, 'a'}, {2, 'b'}, {3, 'c'}}))
    print(debug.getinfo(1, 'S').source, 'tests passed')
end
