local checkargs = {
    checkarg = {},
    NIL = {},
}

function checkargs.parserange(r)
    if r == nil or r == '*' then
        return -math.huge, math.huge
    end
    if type(r) == 'string' then
        local min, max = r:match('([%d%.%*]+)%.%.([%d%.%*]+)')
        if min and max then
            min = min == '*' and -math.huge or tonumber(min)
            max = max == '*' and math.huge or tonumber(max)
            return min, max
        else
            local minMax = r:match("(%d+)")
            if minMax then
                minMax = tonumber(minMax)
                return minMax, minMax
            else
                error('invalid argument format for checkargs.parserange(): ' .. r)
            end
        end
    elseif math.type(r) == 'integer' then
        return r, r
    elseif type(r) == 'table' and #r == 2 and type(r[1]) == 'number' and type(r[2]) == 'number' then
        return r[1], r[2]
    else
        error('invalid argument type for checkargs.parserange(): ' .. type(r))
    end
end

function checkargs.infertype(t)
    if t.type then return t.type end
    if t.class ~= nil then return 'object' end
    if t.union ~= nil then return 'union' end
end

local simEigen = require 'simEigen'
local Color = require 'Color'

function checkargs.checkarg.any(v, t)
    return v
end

function checkargs.checkarg.float(v, t)
    if type(v) ~= 'number' then
        error('must be a float', 0)
    end
    if t and t.range then
        local min, max = checkargs.parserange(t.range)
        assert(v >= min and v <= max, 'value not in range')
    end
    return v
end

function checkargs.checkarg.int(v, t)
    if math.type(v) ~= 'integer' then
        error('must be an int', 0)
    end
    if t and t.range then
        local min, max = checkargs.parserange(t.range)
        assert(v >= min and v <= max, 'value not in range')
    end
    return v
end

function checkargs.checkarg.string(v, t)
    if type(v) ~= 'string' then
        error('must be a string', 0)
    end
    return v
end

function checkargs.checkarg.bool(v, t)
    if type(v) ~= 'boolean' then
        error('must be a boolean', 0)
    end
    return v
end

function checkargs.checkarg.table(v, t)
    if type(v) ~= 'table' then
        error('must be a table', 0)
    end
    if #v > 0 and t.item_type ~= nil then
        for _, i in ipairs{1, #v} do
            local ok, err = pcall(checkargs.checkarg[t.item_type], v[i])
            if not ok then
                error('must be a table, elements ' .. err, 0)
            end
        end
    end
    local minsize, maxsize = checkargs.parserange(t.size)
    if minsize == maxsize and #v ~= maxsize then
        error('must have exactly ' .. t.size .. ' elements', 0)
    elseif #v < minsize then
        error('must have at least ' .. minsize .. ' elements', 0)
    elseif #v > maxsize then
        error('must have at most ' .. maxsize .. ' elements', 0)
    end
    return v
end

function checkargs.checkarg.func(v, t)
    if type(v) ~= 'function' then
        error('must be a function', 0)
    end
    return v
end

function checkargs.checkarg.object(v, t)
    if type(v) ~= 'table' or v.class == nil or not v.isInstanceOf(v, t.class) then
        error('must be an object of class ' .. tostring(t.class), 0)
    end
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
    error('must be any of: ' .. allowedTypes .. '; but ' .. explanation, 0)
end

function checkargs.checkarg.handle(v, t)
    local sim = require 'sim-2'
    if not (math.type(v) == 'integer' and v >= 0) and not sim.Object:isobject(v) then
        error('must be an handle', 0)
    end
    return sim.Object:toobject(v)
end

function checkargs.checkarg.matrix(v, t)
    if t.strict and not simEigen.Matrix:ismatrix(v) then
        error('must be a matrix', 0)
    end
    return simEigen.Matrix:tomatrix(v, t.rows, t.cols)
end

function checkargs.checkarg.vector(v, t)
    if t.strict and not simEigen.Vector:isvector(v) then
        error('must be a vector', 0)
    end
    return simEigen.Vector:tovector(v, t.size)
end

function checkargs.checkarg.vector3(v, t)
    if t.strict and not simEigen.Vector:isvector(v, 3) then
        error('must be a vector3', 0)
    end
    return simEigen.Vector:tovector(v, 3)
end

function checkargs.checkarg.quaternion(v, t)
    if t.strict and not simEigen.Quaternion:isquaternion(v) then
        error('must be a quaternion', 0)
    end
    return simEigen.Quaternion:toquaternion(v)
end

function checkargs.checkarg.pose(v, t)
    if t.strict and not simEigen.Pose:ispose(v) then
        error('must be a pose', 0)
    end
    return simEigen.Pose:topose(v)
end

function checkargs.checkarg.color(v, t)
    if t.strict and not Color:iscolor(v) then
        error('must be a color', 0)
    end
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
    if funcName == nil then
        local info = debug.getinfo(2, 'n')
        if info and info.name then funcName = info.name end
    end
    -- offset for argument number in error messages:
    local argOffset = opts.argOffset
    if funcName and __proxyFuncName__ then
        local method = __proxyFuncName__:endswith('@method')
        local matchFunc, target = table.unpack(__proxyFuncName__:stripsuffix('@method'):split(','))
        if matchFunc == funcName then
            __proxyFuncName__ = nil
            funcName = target
            if method and argOffset == nil then argOffset = -1 end
        end
    end

    -- level at which we should output the error (1 is current, 2 parent, etc...)
    local errorLevel = 2 + level

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
            t.type = checkargs.infertype(t)
            if t.type == nil then
                error(t.type ~= nil, 'type missing, and could not infer type', errorLevel)
            end
            local checkFunc = checkargs.checkarg[t.type]
            if checkFunc == nil then
                error(string.format('function checkargs.checkarg.%s does not exist', t.type), errorLevel)
            end
            local ok, err = pcall(checkFunc, arg[i], t)
            if ok then
                arg[i] = err
            else
                error(fn .. string.format('argument %d %s', i + (argOffset or 0), err or string.format('must be a %s', t.type)), errorLevel)
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

function checkargs.checkfields(funcInfo, schema, args, strict)
    local funcName = funcInfo.funcName or "?"
    args = args or {}

    -- 1. Strict mode checks
    if strict then
        local validKeys = {}
        for _, item in ipairs(schema) do
            validKeys[item.name] = true
        end
        for k, _ in pairs(args) do
            if not validKeys[k] then
                error(string.format("Error in '%s': Unexpected argument '%s' provided.", funcName, k), 2)
            end
        end
    end

    -- 2. Validate Schema
    for _, field in ipairs(schema) do
        local val = args[field.name]

        -- A. Check Existence & Defaults
        if val == nil then
            local def = checkargs.getdefault(field)
            if def ~= nil then
                if def == checkargs.NIL then
                    args[field.name] = nil
                    val = nil
                else
                    args[field.name] = def
                    val = def
                end
            elseif field.optional == true or field.nullable == true then
                goto continue
            else
                error(string.format("Error in '%s': Missing required argument '%s'.", funcName, field.name), 2)
            end
        end

        -- If optional/nullable and still nil after default check, skip validation
        if val == nil and (field.optional or field.nullable) then
            goto continue
        end

        -- B. Check Type (Reuse existing validators)
        local typeName = checkargs.infertype(field)
        if typeName == nil then
            error(string.format("Error in '%s': Schema definition for '%s' missing type.", funcName, field.name), 2)
        end

        local checkFunc = checkargs.checkarg[typeName]
        if not checkFunc then
            error(string.format("Error in '%s': Unknown type validator '%s' for argument '%s'.", funcName, typeName, field.name), 2)
        end

        -- Call the validator.
        -- Note: checkFunc returns the (potentially converted) value or throws error.
        local ok, resultOrErr = pcall(checkFunc, val, field)

        if not ok then
            -- Strip the 'must be a ...' prefix if possible or just append
            error(string.format("Error in '%s': Argument '%s' %s", funcName, field.name, resultOrErr), 2)
        else
            -- Update arg with converted value (e.g. handle -> object, matrix table -> Matrix)
            args[field.name] = resultOrErr
            val = resultOrErr
        end

        ::continue::
    end

    return true
end

function checkargs.unittest()
    local fail, succeed = false, true
    local function test(name, expectedResult, f)
        print(string.format('running test %s...', name))
        local result, err = pcall(f)
        if result ~= expectedResult then
            error(string.format('test %s failed: %s', name, err or '-'))
        end
    end

    local function f(...)
        local i, s, ti = checkargs({
            {type = 'int'}, {type = 'string'}, {type = 'table', item_type = 'int', size = 3},
        }, ...)
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

    local function g(x)
        checkargs({{type = 'table', item_type = 'string', size = '3..*'}}, x)
    end
    test(20, succeed, function() g {'x', 'x', 'x'} end)
    test(21, succeed, function() g {'x', 'y', 'z', 'z', 'z', 'z'} end)
    test(22, fail, function() g {'x'} end)
    test(23, fail, function() g {} end)
    test(24, fail, function() g() end)
    test(25, fail, function() g(1) end)
    test(26, fail, function() g(1, 2) end)

    local function h(...)
        local b = checkargs({{type = 'bool', default = false}}, ...)
        return b
    end
    test(30, succeed, function() h() end)
    test(31, succeed, function() h(true) end)
    test(32, succeed, function() h(false) end)
    test(33, fail, function() h(5) end)
    test(34, fail, function() h(nil) end)
    test(35, succeed, function() assert(h() == false) end)

    local function z(...)
        -- test wrong default type: will fail when called without arg
        checkargs({{type = 'int', default = 3.5}}, ...)
    end
    test(50, fail, function() z() end)

    local function y(...)
        local handle = checkargs({{type = 'handle'}}, ...)
    end
    test(60, fail, function() y(999999) end) -- delicate test: if an object with handle 999999 exists, the test does not fail
    test(61, succeed, function() y(1) end)

    local function x(...)
        local i, t = checkargs({{type = 'int'}, {type = 'table', item_type = 'float', nullable = true}}, ...)
    end
    test(70, succeed, function() x(1, {}) end)

    local function w(...)
        local i1, cb, i2 = checkargs({{type = 'int'}, {type = 'func', nullable = true, default = checkargs.NIL}, {type = 'int', default = 0}}, ...)
    end
    test(80, succeed, function() w( 0, function() return 1 end) end)
    test(81, succeed, function() w(0, nil) end)
    test(82, succeed, function() w(0) end)
    test(83, succeed, function() w( 0, function() return 1 end, 1) end)
    test(84, succeed, function() w(0, nil, 1) end)
    test(85, fail, function() w(0, 'f', 1) end)

    local function v(...)
        local t = checkargs({{type = 'table'}}, ...)
    end
    test(90, fail, function() v(9) end)
    test(91, succeed, function() v({'a', 1, true, {}}) end)

    local function m(...)
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
    local function useobj(o)
        checkargs({{type = 'object', class = SomeObj}}, o)
        local y = o.x
    end
    test(101, fail, function() useobj(o1) end)
    test(102, succeed, function() useobj(o2) end)
    -- test short version (type will be infered by checkargs.infertype)
    local function useobj2(o)
        checkargs({{class = SomeObj}}, o)
        local y = o.x
    end
    test(103, fail, function() useobj2(o1) end)
    test(104, succeed, function() useobj2(o2) end)

    local function u(...)
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

    -- test checkargs.checkfields:
    test(200, succeed, function()
        local simEigen = require 'simEigen'
        local fi = {funcName = 'dummyFunc'}
        local t

        t = {foo = 3}
        checkargs.checkfields(fi, {{name = 'bar', type = 'matrix', cols = 2, default = simEigen.Matrix(2, 2, {1.0, 0.0, 0.0, 1.0})}}, t)
        assert(simEigen.Matrix:ismatrix(t.bar, 2, 2))

        t = {bar = simEigen.Matrix(3, 3, {1, 2, 3, 4, 5, 6, 7, 8, 9})}
        checkargs.checkfields(fi, {{name = 'bar', type = 'matrix', rows = 3, cols = 3, default = simEigen.Matrix(2, 2, {1.0, 0.0, 0.0, 1.0})}}, t)
        assert(simEigen.Matrix:ismatrix(t.bar, 3, 3))
    end)
    test(201, fail, function()
        local simEigen = require 'simEigen'
        local fi = {funcName = 'dummyFunc'}
        local t = {bar = simEigen.Matrix(3, 3, {1, 2, 3, 4, 5, 6, 7, 8, 9})}
        checkargs.checkfields(fi, {{name = 'bar', type = 'matrix', rows = 4, default = simEigen.Matrix(4, 1, {1.0, 0.0, 0.0, 1.0})}}, t)
    end)
    test(202, fail, function()
        local simEigen = require 'simEigen'
        local fi = {funcName = 'dummyFunc'}
        local t = {bar = 'badtype'}
        checkargs.checkfields(fi, {{name = 'bar', type = 'matrix', rows = 4, default = simEigen.Matrix(4, 1, {1.0, 0.0, 0.0, 1.0})}}, t)
    end)
    test(203, fail, function()
        -- test strict mode (extraneous arg: bar)
        local t = {bar = 5}
        checkargs.checkfields({}, {{name = 'foo', type = 'int', default = 4}}, t, true)
        print(t)
    end)

    -- check range of checkarg.int
    test(210, succeed, function() checkargs.checkarg.int(5, {range='*'}) end)
    test(211, succeed, function() checkargs.checkarg.int(5, {range='0..9'}) end)
    test(212, succeed, function() checkargs.checkarg.int(5, {range='0..*'}) end)
    test(213, succeed, function() checkargs.checkarg.int(5, {range='*'}) end)
    test(220, fail, function() checkargs.checkarg.int(15, {range='0..9'}) end)
    test(221, fail, function() checkargs.checkarg.int(-15, {range='0..9'}) end)
    test(222, fail, function() checkargs.checkarg.int(-15, {range='0..*'}) end)

    print(debug.getinfo(1, 'S').source, 'tests passed')
end

return checkargs
