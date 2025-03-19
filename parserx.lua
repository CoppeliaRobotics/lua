local parser = require 'lua-parser.parser'
local pp = require 'lua-parser.pp'

local parserx = {}

function parserx.parseIncomplete(s, f, d)
    d = 1 + (d or 0)

    -- if the input is not "fixable", exit after
    -- a finite number of steps
    if d > 8 then return end

    local ast, error_msg = parser.parse(s, f)
    if ast then return s, ast end

    sym = error_msg:match " expected '(.*)' "
    if sym then return parserx.parseIncomplete(s .. ' ' .. sym, f, d) end

    if error_msg:match ' unclosed string%f[%A]' then
        -- ' or " ???
        local choices = d % 2 > 0 and {"'", '"'} or {'"', "'"}
        local s1, a = parserx.parseIncomplete(s .. choices[1], f, d)
        if a then
            return s1, a
        else
            local s2, b = parserx.parseIncomplete(s .. choices[2], f, d)
            if b then return s2, b end
        end
    end

    if error_msg:match ' expected a numeric or generic range ' then
        return parserx.parseIncomplete(s .. ' i=0,1,1 ', f, d)
    end

    if error_msg:match ' expected a condition after ' then
        return parserx.parseIncomplete(s .. ' false ', f, d)
    end

    if error_msg:match ' expected an expression ' then
        return parserx.parseIncomplete(s .. ' 0 ', f, d)
    end

    if error_msg:match " unexpected token, invalid start of statement" or
        error_msg:match " expected a field name after '.'" or
        error_msg:match " expected a function definition or assignment after local" or
        error_msg:match " expected a function name after 'function'" then
        -- these can't be fixed
        return
    end

    if sim.getNamedBoolParam('simExtLuaCmd.showUnhandledFixErrors') then error(error_msg) end
end

function parserx.getCompoundId(ast)
    if type(ast) ~= 'table' then return ast end
    if ast.tag == 'Id' then return ast[1] end
    if ast.tag == 'String' then return ast[1] end
    if ast.tag == 'Index' and ast[3] == nil then
        local id1 = parserx.getCompoundId(ast[1])
        local id2 = parserx.getCompoundId(ast[2])
        if id1 and id2 then
            return id1 .. '.' .. id2
        end
    end
end

function parserx.findCallsAtPosition(ast, pos, results)
    results = results or {}
    if type(ast) ~= 'table' then return end
    local fn = ''
    if ast.tag == 'Call' then fn = parserx.getCompoundId(ast[1]) or '' end
    for i, t in ipairs(ast) do
        if type(t) == 'table' then
            if type(t) == 'table' and ast.tag == 'Call' and t.pos <= pos and pos <= t.end_pos then
                local argindex = i - 1
                table.insert(results, {fn, argindex})
                if verbose then print('> ', fn, argindex) end
            end
            parserx.findCallsAtPosition(t, pos, results)
        end
    end
    -- if no call context are being returned for <fn>...
    -- but anyway we are in a call, so return <fn,1>:
    if ast.tag == 'Call' and ast.pos <= pos and pos <= ast.end_pos then
        local havefn = false
        for i = 1, #results do
            if results[i][1] == fn then
                havefn = true
                break
            end
        end
        if not havefn then
            if verbose then print('> ', fn, -1, '*') end
            table.insert(results, {fn, -1})
        end
    end
    return results
end

function parserx.dump(o, indent)
    indent = indent or ''
    if type(o) == 'table' then
        local s = '{\n'
        for k, v in pairs(o) do
            if type(k) == 'number' then k = '[' .. k .. ']' end
            s = s .. indent .. '    ' .. k .. '=' .. parserx.dump(v, indent .. '    ') .. ',\n'
        end
        return s .. indent .. '}'
    else
        return tostring(o)
    end
end

function parserx.getCallContexts(s, pos)
    s1, ast = parserx.parseIncomplete(s)
    if verbose then
        print(s)
        print(s1)
    end
    rs = parserx.findCallsAtPosition(ast, pos)
    return rs
end

if arg and arg[1] == 'test' then
    verbose = 1
    runAll = true
    numPassed, numTotal = 0, 0

    local function test(s, expected_ccs)
        numTotal = numTotal + 1
        local ccs = parserx.getCallContexts(s, #s)
        local d, e = parserx.dump(ccs), parserx.dump(expected_ccs)
        if d ~= e then
            print('test failed:', s)
            print('return value:', d)
            print('expected return value:', e)
            if not runAll then os.exit() end
        else
            numPassed = numPassed + 1
        end
    end

    test('if f("x', {{'f', 1}})
    test('if f(\'x', {{'f', 1}})
    test('for ', {})
    test('while ', {})
    test('if ', {})
    test('sim.setObjectAlias(sim.getObject("a"),"b', {{'sim.setObjectAlias', 2}})
    test('sim.setObjectPosition(h,-', {{'sim.setObjectPosition', 2}})
    test('sim.setObjectPosition(h,-1,{', {{'sim.setObjectPosition', 3}})
    test('sim.getObject(names[', {{'sim.getObject', 1}})
    test('sim.foo(x..', {{'sim.foo', 1}})
    test('sim.foo(a,b,c,sim.bar(x+', {{'sim.foo', 4}, {'sim.bar', 1}})
    test('sim.getObject(', {{'sim.getObject', 1}})
    test('sim.getObjectAlias(0,sim.getObject(),{', {{'sim.getObjectAlias', 3}})
    test('sim.getObjectAlias(sim.getObject(', {{'sim.getObjectAlias', 1}, {'sim.getObject', 1}})
    test('sim.getObjectAlias(sim.getObject()', {{'sim.getObjectAlias', 1}})
    test('sim.getObjectAlias(sim.getObject(),', {{'sim.getObjectAlias', 2}})

    print('Number of tests passed: ' .. numPassed .. '/' .. numTotal)
end

return parserx
