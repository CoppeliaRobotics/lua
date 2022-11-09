require'stringx'
require'tablex'

function getvar(n,tblctx)
    tblctx=tblctx or _G
    local ns=string.split(n,'.',true)
    if #ns>1 then
        return getvar(table.join(table.slice(ns,2),'.'),tblctx[ns[1]])
    end
    local is=string.split(n,'[',true)
    if #is==1 then
        return tblctx[n]
    end
    assert(#is==2,'unsupported syntax')
    local it=string.split(is[2],']',true)
    assert(#it==2,'unsupported syntax')
    assert(it[2]=='','unsupported syntax')
    local i=it[1]
    i=tonumber(i)
    return tblctx[is[1]][i]
end

function setvar(n,v,tblctx)
    tblctx=tblctx or _G
    local ns=string.split(n,'.',true)
    if #ns>1 then
        if tblctx[ns[1]]==nil then
            tblctx[ns[1]]={}
        end
        setvar(table.join(table.slice(ns,2),'.'),v,tblctx[ns[1]])
        return
    end
    local is=string.split(n,'[',true)
    if #is==1 then
        tblctx[n]=v
        return
    end
    assert(#is==2,'unsupported syntax')
    local it=string.split(is[2],']',true)
    assert(#it==2,'unsupported syntax')
    assert(it[2]=='','unsupported syntax')
    local i=it[1]
    i=tonumber(i)
    tblctx[is[1]][i]=v
end

function getlocals(level)
    local ret={}
    local i=0
    while true do
        i=i+1
        local name,value=debug.getlocal(level+1,i)
        if not name then return ret end
        ret[name]=value
    end
end

if arg and #arg==1 and arg[1]=='test' then
    a='x1'
    assert(getvar'a'=='x1')
    b={c='x2'}
    assert(getvar'b.c'=='x2')
    d={'x3','y3','z3'}
    assert(getvar'd[3]'=='z3')
    e={f={'a','b'}}
    assert(getvar'e.f[1]'=='a')
    setvar('e.f[1]','A')
    assert(getvar'e.f[1]'=='A')
    setvar('g.h','x')
    assert(g.h=='x')
    local l1='a'
    local l2='b'
    local L=getlocals(1)
    assert(L.l1=='a' and L.l2=='b')
    print('tests passed')
end
