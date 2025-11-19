local checkargs = {
    checkarg = {},
    NIL = {},
}

local simEigen = require 'simEigen'
local Color = require 'Color'

function checkargs.checkarg.any(v, t)
    return v
end

function checkargs.checkarg.float(v, t)
    assert(type(v) == 'number', 'must be a float')
    return v
end

function checkargs.checkarg.int(v, t)
    assert(math.type(v) == 'integer', 'must be an int')
    return v
end

function checkargs.checkarg.string(v, t)
    assert(type(v) == 'string', 'must be a string')
    return v
end

function checkargs.checkarg.bool(v, t)
    assert(type(v) == 'boolean', 'must be a boolean')
    return v
end

function checkargs.checkarg.table(v, t)
    assert(type(v) == 'table', 'must be a table')
    if #v > 0 and t.item_type ~= nil then
        for _, i in ipairs{1, #v} do
            local ok, err = pcall(checkargs.checkarg[t.item_type], v[i])
            if not ok then
                error('must be a table, elements ' .. err)
            end
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
        error('must have exactly ' .. t.size .. ' elements')
    elseif #v < minsize then
        error('must have at least ' .. minsize .. ' elements')
    elseif #v > maxsize then
        error('must have at most ' .. maxsize .. ' elements')
    end
    return v
end

function checkargs.checkarg.func(v, t)
    assert(type(v) == 'function', 'must be a function')
    return v
end

function checkargs.checkarg.object(v, t)
    assert(type(v) == 'table' and v.class ~= nil and v.isInstanceOf(v, t.class), 'must be an object of class ' .. tostring(t.class))
    return v
end

function checkargs.checkarg.union(v, t)
    local allowedTypes, explanation, sep = '', '', ''
    for i, ti in ipairs(t.union) do
        allowedTypes = allowedTypes .. sep .. ti.type
        local valid, err = pcall(checkargs.checkarg[ti.type], v, ti)
        if valid then
            return v
        else
            explanation = explanation .. sep .. 'fails to validate as ' .. ti.type
            if err then explanation = explanation .. ' because ' .. err end
        end
        sep = ', '
    end
    error('must be any of: ' .. allowedTypes .. '; but ' .. explanation)
end

function checkargs.checkarg.handle(v, t)
    local sim = require 'sim-2'
    return sim.Object:toobject(v)
end

function checkargs.checkarg.matrix(v, t)
    return simEigen.Matrix:tomatrix(v, t.rows, t.cols)
end

function checkargs.checkarg.vector(v, t)
    return simEigen.Vector:tovector(v, t.size)
end

function checkargs.checkarg.vector3(v, t)
    return simEigen.Vector:tovector(v, 3)
end

function checkargs.checkarg.quaternion(v, t)
    return simEigen.Quaternion:toquaternion(v)
end

function checkargs.checkarg.pose(v, t)
    return simEigen.Pose:topose(v)
end

function checkargs.checkarg.color(v, t)
    return Color:tocolor(v)
end

function checkargs.getdefault(t)
    if t.default_nil == true then return checkargs.NIL end
    return t.default
end

function checkargs.checkargsEx(opts, types, ...)
    -- level offset at which we should output the error:
    local level = opts.level or 0
    -- function name displayed in error messages
    local funcName = opts.funcName
    -- offset for argument number in error messages:
    local defaultArgOffset = 0
    if funcName and __proxyFuncName__ then
        local method = __proxyFuncName__:endswith('@method')
        local matchFunc, target = __proxyFuncName__:stripsuffix('@method'):split(',')
        if matchFunc == funcName then
            __proxyFuncName__ = nil
            funcName = target
            if method then defaultArgOffset = 1 end
        end
    end
    local argOffset = opts.argOffset or defaultArgOffset

    -- level at which we should output the error (1 is current, 2 parent, etc...)
    local errorLevel = 2 + level

    local function infertype(t)
        if t.class ~= nil then return 'object' end
        if t.union ~= nil then return 'union' end
        error('type missing, and could not infer type', errorLevel + 1)
    end

    if funcName == nil then
        local info = debug.getinfo(2, 'n')
        if info and info.name then funcName = info.name end
    end
    local fn = (funcName or '?') .. ': '
    local arg = table.pack(...)
    -- check how many arguments are required (default arguments must come last):
    local minArgs = 0
    for i = 1, #types do
        if minArgs < (i - 1) and checkargs.getdefault(types[i]) == nil then
            error('checkargs: bad types spec: non-default arg cannot follow a default arg', errorLevel)
        elseif checkargs.getdefault(types[i]) == nil then
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
        if arg.n < i and checkargs.getdefault(t) ~= nil then
            if checkargs.getdefault(t) == checkargs.NIL then
                arg[i] = nil
            else
                arg[i] = checkargs.getdefault(t)
            end
        end
        -- nil is ok if field is nullable:
        if t.nullable and arg[i] == nil then
        else
            -- do the type check, using one of the checkargs.checkarg.type() functions
            if t.type == nil then t.type = infertype(t) end
            local checkFunc = checkargs.checkarg[t.type]
            if checkFunc == nil then
                error(string.format('function checkargs.checkarg.%s does not exist', t.type), errorLevel)
            end
            local ok, err = pcall(checkFunc, arg[i], t)
            if ok then
                arg[i] = err
            else
                error(fn .. string.format('argument %d %s', i + argOffset, err or string.format('must be a %s', t.type)), errorLevel)
            end
        end
    end
    return table.unpackx(arg, #types) -- from 'tablex' module
end

function checkargs.checkargs(types, ...)
    return checkargs.checkargsEx({level = 1}, types, ...)
end

setmetatable(checkargs, {
    __call = function(self, ...)
        return checkargs.checkargs(...)
    end,
})

function checkargs.unittest()
    function f(...)
        local i, s, ti = checkargs({
            {type = 'int'}, {type = 'string'}, {type = 'table', item_type = 'int', size = 3},
        }, ...)
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
        local i1, cb, i2 = checkargs({{type = 'int'}, {type = 'func', nullable = true, default = checkargs.NIL}, {type = 'int', default = 0}}, ...)
    end

    function v(...)
        local t = checkargs({{type = 'table'}}, ...)
    end

    local fail, succeed = false, true
    function test(name, expectedResult, f)
        print(string.format('running test %s...', name))
        local result, err = pcall(f)
        if result ~= expectedResult then
            error(string.format('test %s failed: %s', name, err or '-'))
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

    test(60, fail, function() y(22) end)
    test(61, succeed, function() y(1) end)

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
            {type = 'table', default = checkargs.NIL, nullable = true},
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

    local class = require 'middleclass'
    local SomeObj = class 'SomeObj'
    function SomeObj:initialize(x)
        self.x = x
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

return checkargs
