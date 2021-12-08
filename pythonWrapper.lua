pythonWrapper={}

function pythonWrapper.info(obj)
    if type(obj)=='string' then obj=pythonWrapper.getField(obj) end
    if type(obj)~='table' then return obj end
    local ret={}
    for k,v in pairs(obj) do
        if type(v)=='table' then
            ret[k]=pythonWrapper.info(v)
        elseif type(v)=='function' then
            ret[k]={func={}}
        elseif type(v)~='function' then
            ret[k]={const=v}
        end
    end
    return ret
end

function pythonWrapper.getField(f)
    local v=_G
    for w in string.gmatch(f,'[%w_]+') do
        v=v[w]
        if not v then return nil end
    end
    return v
end

function pythonWrapper.handleRequest(req)
    local resp={}
    if req['func']~=nil and req['func']~='' then
        local func=pythonWrapper.getField(req['func'])
        local args=req['args'] or {}
        if not func then
            resp['error']='No such function: '..req['func']
        else
            local status,retvals=pcall(function()
                local ret={func(unpack(args))}
                return ret
            end)
            resp[status and 'ret' or 'error']=retvals
        end
    elseif req['eval']~=nil and req['eval']~='' then
        local status,retvals=pcall(function()
            local ret={loadstring('return '..req['eval'])()}
            return ret
        end)
        resp[status and 'ret' or 'error']=retvals
    end
    resp['success']=resp['error']==nil
    return resp
end

function pythonWrapper.handleRawMessage(rawReq)
    -- if first byte is '{', it *might* be a JSON payload
    if rawReq:byte(1)==123 then
        local req,ln,err=json.decode(rawReq)
        if req~=nil then
            local resp=pythonWrapper.handleRequest(req)
            return json.encode(resp)
        end
    end

    -- if we are here, it should be a CBOR payload
    local status,req=pcall(cbor.decode,rawReq)
    if status then
        local resp=pythonWrapper.handleRequest(req)
        return cbor.encode(resp)
    end

    sim.addLog(sim.verbosity_errors,'cannot decode message: no suitable decoder')
    return ''
end

function pythonWrapper.handleQueue()
    while true do
        local rc,revents=simZMQ.poll({rpcSocket},{simZMQ.POLLIN},0)
        if rc<=0 then break end

        local rc,req=simZMQ.recv(rpcSocket,0)

        local resp=pythonWrapper.handleRawMessage(req)

        simZMQ.send(rpcSocket,resp,0)
    end
end

function pythonWrapper.publishStepCount()
    simZMQ.send(cntSocket,sim.packUInt32Table{simulationTimeStepCount},0)
end

function getFreePort()
    local d=sim.readCustomDataBlock(sim.handle_app,'pythonClientZmqPort@tmp')
    if not d then
        d={}
    else
        d=sim.unpackTable(d)
    end
    local p=23059
    while d[p] do
        p=p+2
    end
    d[p]=true
    sim.writeCustomDataBlock(sim.handle_app,'pythonClientZmqPort@tmp',sim.packTable(d))
    return p
end

function releasePort(p)
    local d=sim.readCustomDataBlock(sim.handle_app,'pythonClientZmqPort@tmp')
    if d then
        d=sim.unpackTable(d)
        d[p]=nil
        sim.writeCustomDataBlock(sim.handle_app,'pythonClientZmqPort@tmp',sim.packTable(d))
    end
end

function sysCall_beforeMainScript()
    pythonWrapper.handleQueue()
    local outData
    if next(steppingClients)~=nil then
        local canStep=true
        for uuid,v in pairs(steppingClients) do
            if steppedClients[uuid]==nil then
                canStep=false
                break
            end
        end
        outData={doNotRunMainScript=(not canStep)}
    end
    return outData
end

function sysCall_init()
    rpcPort=getFreePort()
    if not simZMQ then
        sim.addLog(sim.verbosity_errors,'pythonWrapper: the ZMQ plugin is not available')
        return {cmd='cleanup'}
    end
    simZMQ.__raiseErrors(true) -- so we don't need to check retval with every call
    cntPort=tonumber(sim.getStringNamedParam('pythonWrapper.cntPort') or (rpcPort+1))
    json=require 'dkjson'
    cbor=require 'cbor'
    context=simZMQ.ctx_new()
    rpcSocket=simZMQ.socket(context,simZMQ.REP)
    simZMQ.bind(rpcSocket,string.format('tcp://*:%d',rpcPort))
    cntSocket=simZMQ.socket(context,simZMQ.PUB)
    simZMQ.setsockopt(cntSocket,simZMQ.CONFLATE,sim.packUInt32Table{1})
    simZMQ.bind(cntSocket,string.format('tcp://*:%d',cntPort))
    simulationTimeStepCount=0
    steppingClients={}
    steppedClients={}
    endSignal=false
    
    local prog=pythonProg..otherProg
    prog=prog:gsub("XXXrpcPortXXX",tostring(rpcPort))

    state=simPython.initState()
    simPython.loadCode(state,prog)
    callHandle=simPython.callFuncAsync(state,"start")
    handleRemote('sysCall_init')
end

function sim.getEndSignal()
    return endSignal
end

function sysCall_cleanup()
    endSignal=true
    simulationTimeStepCount=simulationTimeStepCount+1
    pythonWrapper.publishStepCount()
    
    local st=sim.getSystemTimeInMs(-1)
    while sim.getSystemTimeInMs(st)<300 do
        if threaded then
            if threadEnded then
                break
            end
            pythonWrapper.handleQueue()
        else
            handleRemote('sysCall_cleanup',nil,0.31)
        end
    end
    
    simPython.cleanupState(state)

    if not simZMQ then return end
    simZMQ.close(cntSocket)
    simZMQ.close(rpcSocket)
    simZMQ.ctx_term(context)
    releasePort(rpcPort)
end

function sysCall_actuation()
    steppedClients={}
    handleRemote('sysCall_actuation')
    simulationTimeStepCount=simulationTimeStepCount+1
    pythonWrapper.publishStepCount()
end

function sysCall_nonSimulation()
    pythonWrapper.publishStepCount() -- so that the last client.step(True) doesn't block
    handleRemote('sysCall_nonSimulation')
end

function sysCall_beforeSimulation()
    simulationTimeStepCount=0
    handleRemote('sysCall_beforeSimulation')
end

function sysCall_afterSimulation()
    steppingClients={} 
    steppedClients={}
    handleRemote('sysCall_afterSimulation')
end

function sysCall_sensing()
    local nm='sysCall_sensing'
    handleRemote(nm)
    if pythonFuncs==nil or pythonFuncs[nm]==nil then
        _G[nm]=nil
    end
end

function sysCall_suspend()
    local nm='sysCall_suspend'
    handleRemote(nm)
    if pythonFuncs==nil or pythonFuncs[nm]==nil then
        _G[nm]=nil
    end
end

function sysCall_suspended()
    local nm='sysCall_suspended'
    handleRemote(nm)
    if pythonFuncs==nil or pythonFuncs[nm]==nil then
        _G[nm]=nil
    end
end

function sysCall_resume()
    local nm='sysCall_resume'
    handleRemote(nm)
    if pythonFuncs==nil or pythonFuncs[nm]==nil then
        _G[nm]=nil
    end
end

function sysCall_beforeInstanceSwitch()
    local nm='sysCall_beforeInstanceSwitch'
    handleRemote(nm)
    if pythonFuncs==nil or pythonFuncs[nm]==nil then
        _G[nm]=nil
    end
end

function sysCall_afterInstanceSwitch()
    local nm='sysCall_afterInstanceSwitch'
    handleRemote(nm)
    if pythonFuncs==nil or pythonFuncs[nm]==nil then
        _G[nm]=nil
    end
end

function sysCall_addOnScriptSuspend()
    local nm='sysCall_addOnScriptSuspend'
    handleRemote(nm)
    if pythonFuncs==nil or pythonFuncs[nm]==nil then
        _G[nm]=nil
    end
end

function sysCall_addOnScriptResume()
    local nm='sysCall_addOnScriptResume'
    handleRemote(nm)
    if pythonFuncs==nil or pythonFuncs[nm]==nil then
        _G[nm]=nil
    end
end

--[[
-- Following are not implemented because either:
    - They would be quite slow, since called very often
    - They do not work in Python, since they can be called while already inside of a system callback
    
function sysCall_dynCallback(inData)
    local nm='sysCall_dynCallback'
    handleRemote(nm)
    if pythonFuncs==nil or pythonFuncs[nm]==nil then
        _G[nm]=nil
    end
end

function sysCall_jointCallback(inData)
    local nm='sysCall_jointCallback'
    if pythonFuncs==nil or pythonFuncs[nm]==nil then
        _G[nm]=nil
    end
    return handleRemote('sysCall_jointCallback',inData)
end

function sysCall_contactCallback(inData)
    local nm='sysCall_contactCallback'
    if pythonFuncs==nil or pythonFuncs[nm]==nil then
        _G[nm]=nil
    end
    return handleRemote('sysCall_contactCallback',inData)
end

function sysCall_event(inData)
    local nm='sysCall_event'
    handleRemote(nm)
    if pythonFuncs==nil or pythonFuncs[nm]==nil then
        _G[nm]=nil
    end
end

function sysCall_beforeCopy(inData)
    local nm='sysCall_beforeCopy'
    handleRemote(nm)
    if pythonFuncs==nil or pythonFuncs[nm]==nil then
        _G[nm]=nil
    end
end

function sysCall_afterCopy(inData)
    local nm='sysCall_afterCopy'
    handleRemote(nm)
    if pythonFuncs==nil or pythonFuncs[nm]==nil then
        _G[nm]=nil
    end
end

function sysCall_afterCreate(inData)
    local nm='sysCall_afterCreate'
    handleRemote(nm)
    if pythonFuncs==nil or pythonFuncs[nm]==nil then
        _G[nm]=nil
    end
end

function sysCall_beforeDelete(inData)
    local nm='sysCall_beforeDelete'
    handleRemote(nm)
    if pythonFuncs==nil or pythonFuncs[nm]==nil then
        _G[nm]=nil
    end
end

function sysCall_afterDelete(inData)
    local nm='sysCall_afterDelete'
    handleRemote(nm)
    if pythonFuncs==nil or pythonFuncs[nm]==nil then
        _G[nm]=nil
    end
end

function sysCall_vision(inData)
    local nm='sysCall_vision'
    if pythonFuncs==nil or pythonFuncs[nm]==nil then
        _G[nm]=nil
    end
    return handleRemote('sysCall_vision',inData)
end

function sysCall_trigger(inData)
    local nm='sysCall_trigger'
    if pythonFuncs==nil or pythonFuncs[nm]==nil then
        _G[nm]=nil
    end
    return handleRemote('sysCall_trigger',inData)
end

function sysCall_userConfig()
    local nm='sysCall_userConfig'
    handleRemote(nm)
    if pythonFuncs==nil or pythonFuncs[nm]==nil then
        _G[nm]=nil
    end
end
--]]

function handleErrors()
    local a,pr=simPython.pollResult(state,callHandle)
    if a and #pr>0 then
        pythonError=true
        error(pr)
    end
end

function handleRemote(callType,args,timeout)
    local retVal
    local st=sim.getSystemTimeInMs(-1)
    if callType=='sysCall_init' or ( pythonFuncs and pythonFuncs[callType]) then
        if timeout == nil then
            timeout = 9999
        end
        nextCall=callType
        nextCallArgs=args
        callDone=false
        while not callDone do
            handleErrors()
            pythonWrapper.handleQueue()
            if threaded or sim.getSystemTimeInMs(st)>timeout*1000 then
                break
            end
        end
        retVal=returnData
    else
        if timeout == nil then
            timeout = 0.002
        end
        while true do
            handleErrors()
            pythonWrapper.handleQueue()
            if sim.getSystemTimeInMs(st)>timeout*1000 then
                break
            end
        end
    end
    return retVal
end

function serviceCall(cmd,msg)
    local retArg1,retArg2
    if cmd=='callDone' then
        callDone=true
        nextCall=nil
        nextCallArgs=nil
        returnData=msg
    end
    if cmd=='getNextCall' then
        returnData=nil
        retArg1=nextCall
        retArg2=nextCallArgs
    end
    if cmd=='runningThread' then
        threaded=true
    end
    if cmd=='threadEnded' then
        threadEnded=true
    end
    if cmd=='print' then
        print(msg)
    end
    if cmd=='pythonFuncs' then
        pythonFuncs=msg
    end
    return retArg1,retArg2
end

function setStepping(enable,uuid)
    if uuid==nil then
        uuid='ANY' -- to support older clients
    end
    if enable then
        steppingClients[uuid]=true
    else
        steppingClients[uuid]=nil
    end
    steppedClients[uuid]=nil
end

function step(uuid)
    if uuid==nil then
        uuid='ANY' -- to support older clients
    end
    steppedClients[uuid]=true
end

otherProg=[[

import time
import sys
import os
import uuid
import cbor
import zmq

def b64(b):
    import base64
    return base64.b64encode(b).decode('ascii')

class RemoteAPIClient:
    """Client to connect to CoppeliaSim's ZMQ Remote API."""

    def __init__(self, host='localhost', port=23000, cntport=None, *, verbose=None):
        """Create client and connect to the ZMQ Remote API server."""
        self.verbose = int(os.environ.get('VERBOSE', '0')) if verbose is None else verbose
        self.context = zmq.Context()
        self.socket = self.context.socket(zmq.REQ)
        self.cntsocket = self.context.socket(zmq.SUB)
        self.socket.connect(f'tcp://{host}:{port}')
        self.cntsocket.setsockopt(zmq.SUBSCRIBE, b'')
        self.cntsocket.setsockopt(zmq.CONFLATE, 1)
        self.cntsocket.connect(f'tcp://{host}:{cntport if cntport else port+1}')
        self.uuid=str(uuid.uuid4())

    def __del__(self):
        """Disconnect and destroy client."""
        self.socket.close()
        self.cntsocket.close()
        self.context.term()

    def _send(self, req):
        if self.verbose > 0:
            print('Sending:', req)
        rawReq = cbor.dumps(req)
        if self.verbose > 1:
            print(f'Sending raw len={len(rawReq)}, base64={b64(rawReq)}')
        self.socket.send(rawReq)

    def _recv(self):
        rawResp = self.socket.recv()
        if self.verbose > 1:
            print(f'Received raw len={len(rawResp)}, base64={b64(rawResp)}')
        resp = cbor.loads(rawResp)
        if self.verbose > 0:
            print('Received:', resp)
        return resp

    def _process_response(self, resp):
        if not resp.get('success', False):
            raise Exception(resp.get('error'))
        ret = resp['ret']
        if len(ret) == 1:
            return ret[0]
        if len(ret) > 1:
            return tuple(ret)

    def call(self, func, args):
        """Call function with specified arguments."""
        self._send({'func': func, 'args': args})
        return self._process_response(self._recv())

    def getObject(self, name, _info=None):
        """Retrieve remote object from server."""
        ret = type(name, (), {})
        if not _info:
            _info = self.call('pythonWrapper.info', [name])
        for k, v in _info.items():
            if not isinstance(v, dict):
                raise ValueError('found nondict')
            if len(v) == 1 and 'func' in v:
                setattr(ret, k, lambda *a, func=f'{name}.{k}': self.call(func, a))
            elif len(v) == 1 and 'const' in v:
                setattr(ret, k, v['const'])
            else:
                setattr(ret, k, self.getObject(f'{name}.{k}', _info=v))
        return ret

    def setStepping(self, enable=True):
        return self.call('setStepping', [enable,self.uuid])

    def step(self, *, wait=True):
        self.getStepCount(False)
        self.call('step', [self.uuid])
        self.getStepCount(wait)

    def getStepCount(self, wait):
        try:
            self.cntsocket.recv(0 if wait else zmq.NOBLOCK)
        except zmq.ZMQError:
            pass

def getFuncIfExists(name):
    method=None
    try:
        method=globals()[name]
        #method=getattr(sys.modules[__name__],name)
    except BaseException as err:
        pass
    return method

def switchThread():
    client.step()

def setThreadAutomaticSwitch(level):
    global threadLocLevel
    prev = threadLocLevel
    if isinstance(level,bool):
        if level == True:
            threadLocLevel -= 1
            if threadLocLevel < 0:
                threadLocLevel = 0
        if level == False:
            threadLocLevel += 1
    else:
        if level >= 0:
            threadLocLevel = level
    if prev != threadLocLevel:
        if threadLocLevel == 0:
            client.setStepping(False)
        if prev == 0 and threadLocLevel == 1:
            client.setStepping(True)
    return level

def start():
    global client
    client = RemoteAPIClient("localhost",XXXrpcPortXXX)
    global sim
    sim = client.getObject('sim')
    global threadLocLevel
    threadLocLevel = 0
    glob=globals()
    l={}
    for k in glob:
        if callable(glob[k]):
            l[k]=True
    client.call('serviceCall', ["pythonFuncs",l])
    
    sim.switchThread = switchThread
    sim.setThreadAutomaticSwitch = setThreadAutomaticSwitch
    threadFunc = getFuncIfExists("threadMain")
    args=None
    if threadFunc==None:
        # Run as 'non-threaded'
        funcToRun = "sysCall_init"
        try:
            while funcToRun!="sysCall_cleanup":
                func=getFuncIfExists(funcToRun)
                if (func!=None):
                    if args:
                        func(args)
                    else:    
                        func()
                client.call('serviceCall', ["callDone"])
                f = client.call('serviceCall', ["getNextCall"])
                while f == None:
                    f = client.call('serviceCall', ["getNextCall"])
                if isinstance(f, tuple):
                    funcToRun = f[0].decode("utf-8")
                    args = f[1]
                else:
                    funcToRun = f.decode("utf-8")
                    args = None
        finally:
            # We expect to be able to run the cleanup code:
            func = getFuncIfExists("sysCall_cleanup")
            func()
            client.call('serviceCall', ["callDone"])
    else:
        # Run as 'threaded'
        setThreadAutomaticSwitch(False)
        client.call('serviceCall', ["runningThread"])
        try:
            threadFunc()
        finally:
            client.setStepping(False)
            client.call('serviceCall', ["threadEnded"])
]]