scriptClientBridge = {}

function scriptClientBridge.require(n)
    _G[n] = require(n)
end

function scriptClientBridge.call(b)
    cbor = require 'org.conman.cbor'
    i = cbor.decode(tostring(b))
    require 'var'
    f = getvar(i.func)
    local ok, r = pcall(function() return {f(table.unpack(i.args))} end)
    if ok then
        r = {success = true, result = r}
    else
        r = {success = false, error = r}
    end
    return cbor.encode(r)
end

function scriptClientBridge.info(obj)
    if type(obj) == 'string' then obj = scriptClientBridge.getField(obj) end
    if type(obj) ~= 'table' then return obj end
    local ret = {}
    for k, v in pairs(obj) do
        if type(v) == 'table' then
            ret[k] = scriptClientBridge.info(v)
        elseif type(v) == 'function' then
            ret[k] = {func = {}}
        elseif type(v) ~= 'function' then
            ret[k] = {const = v}
        end
    end
    return ret
end

function scriptClientBridge.getField(f)
    local v = _G
    for w in string.gmatch(f, '[%w_]+') do
        v = v[w]
        if not v then return nil end
    end
    return v
end
