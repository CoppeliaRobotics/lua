function __call(b)
    cbor=require'org.conman.cbor'
    i=cbor.decode(b)
    require'var'
    f=getvar(i.func)
    local ok,r=pcall(function() return {f(table.unpack(i.args))} end)
    if ok then r={success=true,result=r} else r={success=false,error=r} end
    return cbor.encode(r)
end
