checkarg = {}

NIL = {}
table.pack = table.pack or function(...)
    return {n = select("#", ...), ...}
end
table.unpack = table.unpack or unpack

function unpackx(arg, n, i)
    i = i or 1
    if i <= n then return arg[i], unpackx(arg, n, i + 1) end
end

function checkarg.any(v, t)
    return true
end

function checkarg.float(v, t)
    return type(v) == 'number'
end

function checkarg.int(v, t)
    return type(v) == 'number' and math.floor(v) == v, nil
end

function checkarg.string(v, t)
    return type(v) == 'string'
end

function checkarg.bool(v, t)
    return type(v) == 'boolean'
end

function checkarg.table(v, t)
    if type(v) ~= 'table' then return false, 'must be a table' end
    if #v > 0 and t.item_type ~= nil then
        if not checkarg[t.item_type](v[1]) or not checkarg[t.item_type](v[#v]) then
            return false, 'must be a table of elements of type ' .. t.item_type
        end
    end
    local minsize, maxsize = 0, 1 / 0
    if type(t.size) == 'string' and t.size ~= '' and t.size ~= '*' then
        i, j = t.size:find('%.%.')
        if i then
            minsize, maxsize = t.size:sub(1, i - 1), t.size:sub(j + 1)
            minsize = tonumber(minsize)
            maxsize = maxsize == '*' and 1 / 0 or tonumber(maxsize)
        else
            minsize = tonumber(t.size)
            maxsize = minsize
            if math.type(minsize) ~= 'integer' then
                error('incorrect value for size attribute')
            end
        end
    elseif math.type(t.size) == 'integer' then
        minsize, maxsize = t.size, t.size
    elseif t.size then
        error('incorrect value for "size" attribute')
    end
    if minsize == maxsize and #v ~= maxsize then
        return false, 'must have exactly ' .. t.size .. ' elements'
    elseif #v < minsize then
        return false, 'must have at least ' .. minsize .. ' elements'
    elseif #v > maxsize then
        return false, 'must have at most ' .. maxsize .. ' elements'
    end
    return true, nil
end

function checkarg.func(v, t)
    return type(v) == 'function'
end

function checkarg.handle(v, t)
    if type(v) ~= 'number' or math.type(v) ~= 'integer' then return false end
    -- this check requires coppeliaSim:
    if type(sim) == 'table' and type(sim.isHandle) == 'function' then
        return sim.isHandle(v)
    else
        return true
    end
end

function checkarg.object(v, t)
    if type(v) ~= 'table' then return false, 'not a table' end
    if getmetatable(v) ~= t.class then
        local errmsg = 'should be an object'
        if t.class.__classname then errmsg = errmsg .. ' of class ' .. t.class.__classname end
        return false, errmsg
    end
    return true, nil
end

function checkarg.union(v, t)
    local allowedTypes, explanation, sep = '', '', ''
    for i, ti in ipairs(t.union) do
        allowedTypes = allowedTypes .. sep .. ti.type
        local valid, err = checkarg[ti.type](v, ti)
        if valid then
            return true, nil
        else
            explanation = explanation .. sep .. 'fails to validate as ' .. ti.type
            if err then explanation = explanation .. ' because ' .. err end
        end
        sep = ', '
    end
    return false, 'must be any of: ' .. allowedTypes .. '; but ' .. explanation
end

function checkargsEx(opts, types, ...)
    -- level offset at which we should output the error:
    opts.level = opts.level or 0

    -- level at which we should output the error (1 is current, 2 parent, etc...)
    local errorLevel = 2 + opts.level

    function infertype(t)
        if t.class ~= nil then return 'object' end
        if t.union ~= nil then return 'union' end
        error('type missing, and could not infer type', errorLevel + 1)
    end
    local fn = '?: '
    local info = debug.getinfo(2, 'n')
    if info and info.name then fn = info.name .. ': ' end
    local arg = table.pack(...)
    -- check how many arguments are required (default arguments must come last):
    local minArgs = 0
    for i = 1, #types do
        if minArgs < (i - 1) and types[i].default == nil then
            error(
                'checkargs: bad types spec: non-default arg cannot follow a default arg', errorLevel
            )
        elseif types[i].default == nil then
            minArgs = minArgs + 1
        end
    end
    -- validate number of arguments:
    if arg.n < minArgs then
        error(fn .. 'not enough arguments', errorLevel)
    elseif arg.n > #types then
        error(fn .. 'too many arguments', errorLevel)
    end
    -- check types:
    for i = 1, #types do
        local t = types[i]
        -- fill default value:
        if arg.n < i and t.default ~= nil then
            if t.default == NIL then
                arg[i] = nil
            else
                arg[i] = t.default
            end
        end
        -- nil is ok if field is nullable:
        if t.nullable and arg[i] == nil then
        else
            -- do the type check, using one of the checkarg.type() functions
            if t.type == nil then t.type = infertype(t) end
            local checkFunc = checkarg[t.type]
            if checkFunc == nil then
                error(string.format('function checkarg.%s does not exist', t.type), errorLevel)
            end
            local ok, err = checkFunc(arg[i], t)
            if not ok then
                error(
                    fn ..
                        string.format(
                            'argument %d %s', i, err or string.format('must be a %s', t.type)
                        ), errorLevel
                )
            end
        end
    end
    return unpackx(arg, #types)
end

function checkargs(types, ...)
    return checkargsEx({level = 1}, types, ...)
end

-- tests:

if arg and #arg == 1 and arg[1] == 'test' then
    sim = sim or {}

    function f(...)
        local i, s, ti = checkargs(
                             {
                {type = 'int'}, {type = 'string'}, {type = 'table', item_type = 'int', size = 3},
            }, ...
                         )
    end

    function g(x)
        checkargs({{type = 'table', item_type = 'string', size = '3..*'}}, x)
    end

    function h(...)
        local b = checkargs({{type = 'bool', default = false}}, ...)
        return b
    end

    function z(...)
        -- test wrong default type: will fail when called without arg
        checkargs({{type = 'int', default = 3.5}}, ...)
    end

    function y(...)
        local handle = checkargs({{type = 'handle'}}, ...)
    end

    function x(...)
        local i, t = checkargs({{type = 'int'}, {type = 'table', item_type = 'float', nullable = true}}, ...)
    end

    function w(...)
        local i1, cb, i2 = checkargs({{type = 'int'}, {type = 'func', nullable = true, default = NIL}, {type = 'int', default = 0}}, ...)
    end

    function v(...)
        local t = checkargs({{type = 'table'}}, ...)
    end

    local fail, succeed = false, true
    function test(name, expectedResult, f)
        print(string.format('running test %s...', name))
        local result, err = pcall(f)
        if result ~= expectedResult then
            print(string.format('test %s failed: %s', name, err or '-'))
        end
    end
    test(1, succeed, function() f(3, 'a', {1, 2, 3}) end)
    test(2, fail, function() f('x', 'b', {4, 5, 6}) end)
    test(3, fail, function() f(5, 10, {7, 8, 9}) end)
    test(4, fail, function() f(6, 'd', 'a') end)
    test(5, fail, function() f(7, 'e', {10, 20}) end)
    test(6, fail, function() f(8, 'e', {10, 20, 40, 80}) end)
    test(7, fail, function() f(9, 'f', {'a', 'b', 'c'}) end)
    test(8, fail, function() f() end)
    test(9, fail, function() f(11, 'h', {50, 60, 70}, 56) end)
    test(10, fail, function() f(12, 'i', {80, 90, 100}, nil) end)
    test(11, fail, function() f(12.5, 'i', {80, 90, 100}) end)
    test(20, succeed, function() g {'x', 'x', 'x'} end)
    test(21, succeed, function() g {'x', 'y', 'z', 'z', 'z', 'z'} end)
    test(22, fail, function() g {'x'} end)
    test(23, fail, function() g {} end)
    test(24, fail, function() g() end)
    test(25, fail, function() g(1) end)
    test(26, fail, function() g(1, 2) end)
    test(30, succeed, function() h() end)
    test(31, succeed, function() h(true) end)
    test(32, succeed, function() h(false) end)
    test(33, fail, function() h(5) end)
    test(34, fail, function() h(nil) end)
    test(35, succeed, function() assert(h() == false) end)
    test(50, fail, function() z() end)

    -- mock sim.isHandle:
    function sim.isHandle(x)
        return x == 200 or x == 201 or x == 202
    end
    test(60, fail, function() y(22) end)
    test(61, succeed, function() y(200) end)

    test(70, succeed, function() x(1, {}) end)
    test(80, succeed, function() w( 0, function() return 1 end) end)
    test(81, succeed, function() w(0, nil) end)
    test(82, succeed, function() w(0) end)
    test(83, succeed, function() w( 0, function() return 1 end, 1) end)
    test(84, succeed, function() w(0, nil, 1) end)
    test(85, fail, function() w(0, 'f', 1) end)
    test(90, fail, function() v(9) end)
    test(91, succeed, function() v({'a', 1, true, {}}) end)

    function m(...)
        local a, b, c = checkargs({
            {type = 'int', default = 1},
            {type = 'table', default = NIL, nullable = true},
            {type = 'int', default = 2},
        }, ...)
        return a, b, c
    end
    test(
        100, succeed, function()
            local v1, v2, v3 = m()
            assert(v1 == 1)
            assert(v2 == nil)
            assert(v3 == 2)
        end
    )

    SomeObj = {__classname = 'SomeObj'}
    function SomeObj:new(x)
        return setmetatable({x = x}, self)
    end
    o1 = {}
    o2 = SomeObj:new(3)
    function useobj(o)
        checkargs({{type = 'object', class = SomeObj}}, o)
        local y = o.x
    end
    test(101, fail, function() useobj(o1) end)
    test(102, succeed, function() useobj(o2) end)
    -- test short version (type will be infered by checkargs.infertype)
    function useobj2(o)
        checkargs({{class = SomeObj}}, o)
        local y = o.x
    end
    test(103, fail, function() useobj2(o1) end)
    test(104, succeed, function() useobj2(o2) end)

    function u(...)
        x = checkargs({
            {union = {{type = 'int'}, {type = 'string'}, {type = 'table', item_type = 'int', size = '2..*'}}, default = 42},
        }, ...)
        return x
    end
    test(110, succeed, function() u(10) end)
    test(111, succeed, function() u('str') end)
    test(112, fail, function() u(math.pi) end)
    test(113, fail, function() u {'s', 's'} end)
    test(114, fail, function() u {1} end)
    test(115, succeed, function() assert(u() == 42) end)
    print(debug.getinfo(1, 'S').source, 'tests passed')
end

