function table.eq(a,b)
    if #a~=#b then return false end
    for i=1,#a do
        if type(a)~=type(b) then return false end
        if type(a[i])=='table' then
            if not table.eq(a[i],b[i]) then return false end
        else
            if a[i]~=b[i] then return false end
        end
    end
    return true
end

function table.join(t,sep)
    sep=sep or ', '
    s=''
    for i,x in ipairs(t) do
        s=s..(s=='' and '' or sep)
        if type(x)=='table' then
            s=s..table.tostring(x)
        else
            s=s..tostring(x)
        end
    end
    return s
end

function table.slice(t,first,last,step)
    local ret={}
    for i=first or 1,last or #t,step or 1 do
        table.insert(ret,t[i])
    end
    return ret
end

function table.tostring(t,sep)
    return '{'..table.join(t,sep)..'}'
end

function table.print(t)
    print(table.tostring(t))
end

if arg and #arg==1 and arg[1]=='test' then
    assert(table.eq({1,2,3},{1,2,3}))
    assert(not table.eq({1,2,3,4},{1,2,3}))
    assert(not table.eq({},{1,2,3}))
    assert(table.tostring{1,2,3}=='{1, 2, 3}')
    print('tests passed')
end
