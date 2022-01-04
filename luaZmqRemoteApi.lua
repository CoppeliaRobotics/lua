local RemoteApiClient={}

function RemoteApiClient.init(host,port,cntport)
    host=host or '127.0.0.1'
    port=port or 23002
    cntport=cntport or port+1
    RemoteApiClient.cbor=require'org.conman.cbor'
    RemoteApiClient.context=simZMQ.ctx_new()
    RemoteApiClient.socket=simZMQ.socket(RemoteApiClient.context,simZMQ.REQ)
    RemoteApiClient.cntsocket=simZMQ.socket(RemoteApiClient.context,simZMQ.SUB)
    simZMQ.connect(RemoteApiClient.socket,'tcp://'..host..':'..port)
    simZMQ.setsockopt(RemoteApiClient.cntsocket,simZMQ.SUBSCRIBE,'')
    simZMQ.setsockopt(RemoteApiClient.cntsocket,simZMQ.CONFLATE,sim.packUInt32Table{1})
    simZMQ.connect(RemoteApiClient.cntsocket,'tcp://'..host..':'..cntport)
    RemoteApiClient.uuid=sim.getStringParam(sim.stringparam_uniqueid)
end

function RemoteApiClient.cleanup()
    simZMQ.close(RemoteApiClient.socket)
    simZMQ.close(RemoteApiClient.cntsocket)
    simZMQ.ctx_term(RemoteApiClient.context)
end

function RemoteApiClient._send(req)
    local rawReq=RemoteApiClient.cbor.encode(req)
    simZMQ.send(RemoteApiClient.socket,rawReq,0)
end

function RemoteApiClient._recv()
    local r,rawResp=simZMQ.recv(RemoteApiClient.socket,0)
    local resp,a=RemoteApiClient.cbor.decode(rawResp)
    return resp
end

function RemoteApiClient._process_response(resp)
    if resp.success==nil or resp.success==false then
        error(resp.error)
    end
    local ret=resp.ret
    if #ret==1 then
        return ret[1]
    end
    if #ret>1 then
        return unpack(ret)
    end
end

function RemoteApiClient.call(func, args)
    RemoteApiClient._send({func=func,args=args})
    return RemoteApiClient._process_response(RemoteApiClient._recv())
end

function RemoteApiClient.getObject(name,_info)
    local ret={}
    if not _info then
        _info = RemoteApiClient.call('zmqRemoteApi.info', {name})
    end
    for k, v in pairs(_info) do
        if type(v)~='table' then
            error('found non table')
        end
        local s=0
        for k_, v_ in pairs(v) do
            s=s+1
            if s>=2 then
                break
            end
        end
        if s==1 and v.func then
            local func=name..'.'..k
            ret[k]=function(...) return RemoteApiClient.call(func,{...}) end
        elseif s==1 and v.const then
            ret[k]=v.const
        else
            ret[k]=RemoteApiClient.getObject(name..'.'..k,v)
        end
    end
    return ret
end

function RemoteApiClient.setStepping(enable)
    enable=enable or true
    return RemoteApiClient.call('setStepping', {enable,RemoteApiClient.uuid})
end

function RemoteApiClient.step(wait)
    wait=wait or true
    RemoteApiClient.getStepCount(false)
    RemoteApiClient.call('step', {RemoteApiClient.uuid})
    RemoteApiClient.getStepCount(wait)
end

function RemoteApiClient.getStepCount(wait)
    if wait then
        wait=0
    else
        wait=simZMQ.NOBLOCK
    end
    simZMQ.recv(RemoteApiClient.cntsocket,wait)
end

return RemoteApiClient