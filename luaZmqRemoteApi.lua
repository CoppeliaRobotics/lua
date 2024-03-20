sim = require 'sim'
simZMQ = require 'simZMQ'

local RemoteApiClient = {}

function RemoteApiClient.init(host, port)
    host = host or '127.0.0.1'
    port = port or 23000
    cbor = require 'org.conman.cbor'
    RemoteApiClient.context = simZMQ.ctx_new()
    RemoteApiClient.socket = simZMQ.socket(RemoteApiClient.context, simZMQ.REQ)
    simZMQ.connect(RemoteApiClient.socket, 'tcp://' .. host .. ':' .. port)
    RemoteApiClient.uuid = sim.getStringParam(sim.stringparam_uniqueid)
    RemoteApiClient.callbackFuncs = {}
    RemoteApiClient.VERSION = 2
end

function RemoteApiClient.cleanup()
    simZMQ.close(RemoteApiClient.socket)
    simZMQ.ctx_term(RemoteApiClient.context)
end

function RemoteApiClient._send(req)
    -- convert a possible function to string, and nil to "_*NIL*_":
    if req.args then
        local a = {}
        for i = 1, #req.args, 1 do
            if req.args[i] == nil then
                a[i] = '_*NIL*_'
            elseif type(req.args[i]) == 'function' then
                local funcStr = "f" .. sim.getStringParam(sim.stringparam_uniqueid)
                RemoteApiClient.callbackFuncs[funcStr] = req.args[i]
                a[i] = funcStr .. "@func"
            else
                a[i] = req.args[i]
            end
        end
        req.args = a
    end
    req.uuid = RemoteApiClient.uuid
    req.ver = RemoteApiClient.VERSION
    local rawReq = cbor.encode(req)
    simZMQ.send(RemoteApiClient.socket, rawReq, 0)
end

function RemoteApiClient._recv()
    local r, rawResp = simZMQ.recv(RemoteApiClient.socket, 0)
    local resp, a = cbor.decode(tostring(rawResp))
    return resp
end

function RemoteApiClient._process_response(resp)
    local ret = resp.ret
    if #ret == 1 then return ret[1] end
    if #ret > 1 then return unpack(ret) end
end

function RemoteApiClient.call(func, args)
    -- Call function with specified arguments. Is reentrant
    RemoteApiClient._send({func = func, args = args})
    local reply = RemoteApiClient._recv()

    while reply.func do
        -- We have a callback or a wait:
        if reply.func == '_*wait*_' then
            RemoteApiClient._send({func = '_*executed*_', args = {}})
        else
            local args = {}
            if RemoteApiClient.callbackFuncs[reply.func] then
                args = RemoteApiClient.callbackFuncs[reply.func](reply.args)
            else
                funcToRun = _G[reply.func]
                if funcToRun then -- we cannot raise an error: e.g. a custom UI async callback cannot be assigned to a specific client
                    args = funcToRun(reply.args)
                end
            end
            RemoteApiClient._send({func = '_*executed*_', args = args})
        end
        reply = RemoteApiClient._recv()
    end

    if reply.err then error(reply.err) end

    return RemoteApiClient._process_response(reply)
end

function RemoteApiClient.getObject(name, _info)
    local ret = {}
    if not _info then _info = RemoteApiClient.call('zmqRemoteApi.info', {name}) end
    for k, v in pairs(_info) do
        if type(v) ~= 'table' then error('found non table') end
        local s = 0
        for k_, v_ in pairs(v) do
            s = s + 1
            if s >= 2 then break end
        end
        if s == 1 and v.func then
            local func = name .. '.' .. k
            ret[k] = function(...)
                return RemoteApiClient.call(func, {...})
            end
        elseif s == 1 and v.const then
            ret[k] = v.const
        else
            ret[k] = RemoteApiClient.getObject(name .. '.' .. k, v)
        end
    end
    return ret
end

function RemoteApiClient.require(name)
    RemoteApiClient.call('zmqRemoteApi.require', {name})
    return RemoteApiClient.getObject(name)
end

function RemoteApiClient.setStepping(enable) -- for backw. comp., now via sim.setStepping
    enable = enable or true
    return RemoteApiClient.call('sim.setStepping', {enable})
end

function RemoteApiClient.step(wait) -- for backw. comp., now via sim.step
    wait = wait or true
    RemoteApiClient.call('sim.step', {wait})
end

return RemoteApiClient
