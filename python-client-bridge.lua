pythonClientBridge={}

function pythonClientBridge.require(n)
    _G[n]=require(n)
end

function pythonClientBridge.call(b)
    cbor=require'org.conman.cbor'
    i=cbor.decode(b)
    require'var'
    f=getvar(i.func)
    local ok,r=pcall(function() return {f(table.unpack(i.args))} end)
    if ok then r={success=true,result=r} else r={success=false,error=r} end
    return cbor.encode(r)
end

function pythonClientBridge.info(obj)
    if type(obj)=='string' then obj=pythonClientBridge.getField(obj) end
    if type(obj)~='table' then return obj end
    local ret={}
    for k,v in pairs(obj) do
        if type(v)=='table' then
            ret[k]=pythonClientBridge.info(v)
        elseif type(v)=='function' then
            ret[k]={func={}}
        elseif type(v)~='function' then
            ret[k]={const=v}
        end
    end
    return ret
end

function pythonClientBridge.getField(f)
    local v=_G
    for w in string.gmatch(f,'[%w_]+') do
        v=v[w]
        if not v then return nil end
    end
    return v
end
