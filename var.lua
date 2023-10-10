require 'stringx'
require 'tablex'

function getvar(n, tblctx)
    tblctx = tblctx or _G
    local ns = string.split(n, '.', true)
    if #ns > 1 then return getvar(table.join(table.slice(ns, 2), '.'), tblctx[ns[1]]) end
    local is = string.split(n, '[', true)
    if #is == 1 then return tblctx[n] end
    assert(#is == 2, 'unsupported syntax')
    local it = string.split(is[2], ']', true)
    assert(#it == 2, 'unsupported syntax')
    assert(it[2] == '', 'unsupported syntax')
    local i = it[1]
    i = tonumber(i)
    return tblctx[is[1]][i]
end

function setvar(n, v, tblctx)
    tblctx = tblctx or _G
    local ns = string.split(n, '.', true)
    if #ns > 1 then
        if tblctx[ns[1]] == nil then tblctx[ns[1]] = {} end
        setvar(table.join(table.slice(ns, 2), '.'), v, tblctx[ns[1]])
        return
    end
    local is = string.split(n, '[', true)
    if #is == 1 then
        tblctx[n] = v
        return
    end
    assert(#is == 2, 'unsupported syntax')
    local it = string.split(is[2], ']', true)
    assert(#it == 2, 'unsupported syntax')
    assert(it[2] == '', 'unsupported syntax')
    local i = it[1]
    i = tonumber(i)
    tblctx[is[1]][i] = v
end

function getlocals(level)
    local ret = {}
    local i = 0
    while true do
        i = i + 1
        if level then
            local name, value = debug.getlocal(level + 1, i)
            if not name then return ret end
            ret[name] = value
        else
            if not pcall(
                function()
                    ret[i] = getlocals(i)
                end
            ) then break end
            if not next(ret[i]) then break end
        end
    end
    return ret
end

function f(str)
    str = str:gsub(
        '{(.-)}',
        function(name0)
            local value, opts, name = nil, {pctopt = 's'}, name0
            if name:sub(-1, -1) == '=' then
                opts.equal = true
                name = name:sub(1, -2)
            end
            if name:find(':') then
                local p = string.split(name, ':')
                assert(#p == 2, 'incorrect syntax')
                name = p[1]
                opts.pctopt = p[2]
            end
            for i = 1, 1e100 do
                local n, v = debug.getlocal(4, i)
                if not n then break end
                if name == n then
                    value = v;
                    break
                end
            end
            if value == nil and _G[name] then value = _G[name] end
            if value ~= nil then
                value = string.format('%' .. opts.pctopt, value)
                if opts.equal then value = name .. '=' .. value end
                return value
            else
                return string.format('{%s}', name0)
            end
        end
    )
    return str
end

if arg and #arg == 1 and arg[1] == 'test' then
    a = 'x1'
    assert(getvar 'a' == 'x1')
    b = {c = 'x2'}
    assert(getvar 'b.c' == 'x2')
    d = {'x3', 'y3', 'z3'}
    assert(getvar 'd[3]' == 'z3')
    e = {f = {'a', 'b'}}
    assert(getvar 'e.f[1]' == 'a')
    setvar('e.f[1]', 'A')
    assert(getvar 'e.f[1]' == 'A')
    setvar('g.h', 'x')
    assert(g.h == 'x')
    local l1 = 'a'
    local l2 = 'b'
    local L = getlocals(1)
    assert(L.l1 == 'a' and L.l2 == 'b')
    print(debug.getinfo(1, 'S').source, 'tests passed')
end
