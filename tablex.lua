function table.index(t)
    return function(idx)
        return t[idx]
    end
end

function table.eq(a,b)
    if a==nil and b==nil then return true end
    if a==nil or b==nil then return false end
    if type(a)~='table' or type(b)~='table' then return false end
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

function table.join(t,sep,opts,vt)
    sep=sep or ', '
    opts=opts or {}
    vt=vt or {}
    s=''
    vt[tostring(t)]=1
    local visitedKeys={}
    local function concat(prefix,key,val)
        if visitedKeys[key] then return end
        s=s..(s=='' and '' or sep)..prefix
        if type(val)=='table' then
            if vt[tostring(val)] then
                s=s..'...'
            else
                s=s..table.tostring(val)
            end
        else
            s=s..tostring(val)
        end
        visitedKeys[key]=1
    end
    for key,val in ipairs(t) do concat('',key,val) end
    for key,val in pairs(t) do concat(key..'=',key,val) end
    return s
end

function table.slice(t,first,last,step)
    local ret={}
    for i=first or 1,last or #t,step or 1 do
        table.insert(ret,t[i])
    end
    return ret
end

function table.tostring(t,sep,opts,vt)
    return '{'..table.join(t,sep,opts,vt)..'}'
end

function table.print(t)
    print(table.tostring(t))
end

function table.find(t,item,equalsFunc)
    equalsFunc=equalsFunc or function(x) return item==x end
    for i,x in ipairs(t) do
        if equalsFunc(x) then
            return i
        end
    end
end

function table.compare(a,b,compareFunc)
    compareFunc=compareFunc or function(a,b)
        if a<b then return -1 end
        if a>b then return 1 end
        return 0
    end
    if #a==0 and #b==0 then return 0 end
    if #a==0 then return -1 end
    if #b==0 then return 1 end
    local c=compareFunc(a[1],b[1])
    if c==0 then
        return table.compare(table.slice(a,2),table.slice(b,2),compareFunc)
    else
        return c
    end
end

if arg and #arg==1 and arg[1]=='test' then
    assert(table.eq({1,2,3},{1,2,3}))
    assert(not table.eq({1,2,3,4},{1,2,3}))
    assert(not table.eq({},{1,2,3}))
    assert(table.tostring{1,2,3}=='{1, 2, 3}')
    assert(table.find({10,20,30,40},30)==3)
    assert(table.find({10,20,30,40},50)==nil)
    assert(table.compare({10},{10})==0)
    assert(table.compare({10},{10,0})<0)
    assert(table.compare({10,0},{10})>0)
    assert(table.compare({11,0},{10,1})>0)
    assert(table.compare({9,0},{10,1})<0)
    print(debug.getinfo(1,'S').source,'tests passed')
end
