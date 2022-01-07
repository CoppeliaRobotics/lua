pythonWrapper={}

function pythonWrapper.info(obj)
    if type(obj)=='string' then
        obj=pythonWrapper.getField(obj) 
    end
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

function getFreePortStr()
    local context=simZMQ.ctx_new()
    local socket=simZMQ.socket(context,simZMQ.REP)
    local p=23259
    while true do
        if simZMQ.bind(socket,string.format('tcp://127.0.0.1:%d',p))==0 then
            break
        end
        p=p+1
    end
    simZMQ.close(socket)
    simZMQ.ctx_term(context)
    return string.format('tcp://127.0.0.1:%d',p)
end

function sysCall_beforeMainScript()
    if sim.getScriptInt32Param(sim.handle_self,sim.scriptintparam_type)~=sim.scripttype_childscript then
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
end

function sysCall_init()
    if not simZMQ then
        sim.addLog(sim.verbosity_errors,'pythonWrapper: the ZMQ plugin is not available')
        return {cmd='cleanup'}
    end
    simZMQ.__raiseErrors(true) -- so we don't need to check retval with every call
    json=require 'dkjson'
    -- cbor=require 'cbor' -- encodes strings as buffers too, always
    cbor=require'org.conman.cbor'
    
    context=simZMQ.ctx_new()
    rpcSocket=simZMQ.socket(context,simZMQ.REP)
    rpcPortStr=getFreePortStr()
    simZMQ.setsockopt(rpcSocket,simZMQ.LINGER,sim.packUInt32Table{0})
    simZMQ.bind(rpcSocket,rpcPortStr)
    cntSocket=simZMQ.socket(context,simZMQ.PUB)
    simZMQ.setsockopt(cntSocket,simZMQ.CONFLATE,sim.packUInt32Table{1})
    simZMQ.setsockopt(cntSocket,simZMQ.LINGER,sim.packUInt32Table{0})
    cntPortStr=getFreePortStr()
    simZMQ.bind(cntSocket,cntPortStr)
    simulationTimeStepCount=0
    steppingClients={}
    steppedClients={}
    endSignal=false

    local prog=pythonProg..otherProg
    prog=prog:gsub("XXXconnectionAddress1XXX",rpcPortStr)
    prog=prog:gsub("XXXconnectionAddress2XXX",cntPortStr)
    if auxInstr==nil then auxInstr="" end
    prog=prog:gsub("XXXauxInstructionsXXX",auxInstr)
    
    initPython(prog,0)
    pythonInitialized=true
    handleRemote('sysCall_init')
end

function sim.getEndSignal()
    return endSignal
end

function sysCall_cleanup()
    if pythonInitialized then
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
        
        cleanupPython()
    end

    simZMQ.close(cntSocket)
    simZMQ.close(rpcSocket)
    simZMQ.ctx_term(context)
end

function initPython(p,method)
    callMethod=method
    if method==0 then
        local portStr=getFreePortStr()
        baseProg=baseProg:gsub("XXXconnectionAddress1XXX",portStr)
        local pyth=sim.getStringParam(sim.stringparam_defaultpython)
        local pyth2=sim.getNamedStringParam("pythonWrapper.python")
        if pyth2 then
            pyth=pyth2
        end
        if pyth==nil or #pyth==0 then
            local p=sim.getInt32Param(sim.intparam_platform)
            if p==1 then
                pyth='/usr/local/bin/python3' -- via Homebrew
            end
            if p==2 then
                pyth='/usr/bin/python3'
            end
        end
        local errMsg
        if pyth and #pyth>0 then
            local res,ret=pcall(function() return simSubprocess.execAsync(pyth,{'-c',baseProg},{useSearchPath=true,openNewConsole=false}) end)
            --[[ using a temp file:
            local td=sim.getStringParam(sim.stringparam_tempdir)
            pythonFilename=td..'/'..sim.getStringParam(sim.stringparam_uniqueid)..'.py'
            local pythonFile=io.open(pythonFilename,'w+')
            pythonFile:write(baseProg)
            pythonFile:close()
            sim.launchExecutable(pyth,pythonFilename,0)
            res=true
            --]]
            
            if res then
                subprocess=ret
                pyContext=simZMQ.ctx_new()
                socket=simZMQ.socket(pyContext,simZMQ.REQ)
                simZMQ.setsockopt(socket,simZMQ.LINGER,sim.packUInt32Table{0})
                simZMQ.connect(socket,portStr)
                simZMQ.send(socket,cbor.encode({cmd='loadCode',code=p}),0)
                local st=sim.getSystemTimeInMs(-1)
                local r,rep
                while sim.getSystemTimeInMs(st)<2000 do
                    r,rep=simZMQ.recv(socket,simZMQ.DONTWAIT)
                    if r>=0 then
                        break
                    end
                end
                if r>=0 then
                    local rep,o,t=cbor.decode(rep)
                    if rep.success then
                        simZMQ.send(socket,cbor.encode({cmd='callFunc',func='__startClientScript__',args={}}),0)
                    else
                        msg=rep.error
                        if msg and #msg>0 then
                            local p1=string.find(msg,'File "<string>"')
                            local p2=string.find(msg,'File "<string>"',p1+1)
                            msg="\n"..string.sub(msg,p2)
                            local obj=sim.getObject('.',{noError=true})
                            if obj>=0 then
                                msg=msg:gsub('File "<string>"',"["..sim.getObjectAlias(obj,1).."]")
                            end
                        end
                        if simSubprocess.isRunning(subprocess) then
                            simSubprocess.kill(subprocess)
                        end
                        simZMQ.close(socket)
                        simZMQ.ctx_term(pyContext)
                        error(msg)
                    end
                else
                    errMsg="The Python interpreter could not handle the wrapper script (or communication between the launched subprocess and CoppeliaSim could not be established via sockets). Make sure that modules 'cbor' and 'zmq' are properly installed, e.g. via:\n$ pip install cbor\n$ pip install pyzmq"
                    if simSubprocess.isRunning(subprocess) then
                        simSubprocess.kill(subprocess)
                    end
                    simZMQ.close(socket)
                    simZMQ.ctx_term(pyContext)
                end
            else
                errMsg="The Python interpreter could not be called. It is currently set at: '"..pyth.."'. You can specify it in system/usrset.txt with 'defaultPython', or via the named string parameter 'pythonWrapper.python' from the command line"
            end
        else
            errMsg="The Python interpreter was not set. Specify it in system/usrset.txt with 'defaultPython', or via the named string parameter 'pythonWrapper.python' from the command line"
        end
        if errMsg then
            local r=sim.readCustomDataBlock(sim.handle_app,'pythonWrapper.msgShown')
            if r==nil then
                -- show this only once
                sim.writeCustomDataBlock(sim.handle_app,'pythonWrapper.msgShown',"yes")
                simUI.msgBox(simUI.msgbox_type.warning,simUI.msgbox_buttons.ok,"Python interpreter",errMsg)
            end
            error(errMsg)
        end
    end
    if method==1 then
        state=simPython.initState()
        simPython.loadCode(state,p)
        callHandle=simPython.callFuncAsync(state,"__startClientScript__")
    end
end

function cleanupPython()
    if callMethod==0 then
        if subprocess then
            if simSubprocess.isRunning(subprocess) then
                simSubprocess.kill(subprocess)
            end
        end
        simZMQ.close(socket)
        simZMQ.ctx_term(pyContext)
    end
    if callMethod==1 then
        simPython.cleanupState(state)
    end
end

function getErrorPython()
    local a,msg
    if callMethod==0 then
        if subprocess then
            if simSubprocess.isRunning(subprocess) then
                local r,rep=simZMQ.recv(socket,simZMQ.DONTWAIT)
                if r>=0 then
                    local rep,o,t=cbor.decode(rep)
                    a=rep.success==false
                    msg=rep.error
                    if msg and #msg>0 then
                        local p1=string.find(msg,'__startClientScript__')
                        local p2=string.find(msg,'\n',p1)
                        msg=string.sub(msg,p2)
                        local obj=sim.getObject('.',{noError=true})
                        if obj>=0 then
                            msg=msg:gsub('File "<string>"',"["..sim.getObjectAlias(obj,1).."]")
                        end
                    end
                end
            end
        end
    end
    if callMethod==1 then
        a,msg=simPython.pollResult(state,callHandle)
    end
    return a,msg
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
    local a,pr=getErrorPython()
    if a and #pr>0 then
        pythonError=true
        error(pr)
    end
end

function handleRemote(callType,args,timeout)
    local retVal
    local st=sim.getSystemTimeInMs(-1)
    if callType=='sysCall_init' or ( pythonFuncs and pythonFuncs[callType]) then
        -- non-threaded, or first time, i.e. in init
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
        -- threaded
        if callType=='sysCall_nonSimulation' or callType=='sysCall_suspended' or callType=='sysCall_actuation' then
            if timeout == nil then
                timeout = 0.001
            end
            while true do
                handleErrors()
                pythonWrapper.handleQueue()
                if sim.getScriptInt32Param(sim.handle_self,sim.scriptintparam_type)~=sim.scripttype_childscript or next(steppingClients)==nil then
                    -- Customization scripts in general (stepping handled elsewhere), or scripts in non-stepping mode
                    if sim.getSystemTimeInMs(st)>timeout*1000 then
                        break
                    end
                else
                    -- stepping mode child scripts
                    local breakout=true
                    for uuid,v in pairs(steppingClients) do
                        if steppedClients[uuid]==nil then
                            breakout=false
                            break
                        end
                    end
                    if breakout then
                        break
                    end
                end
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

function getApi()
    str={}
    for k,v in pairs(_G) do
        if type(v)=='table' and k:find('sim',1,true)==1 then
            str[#str+1]=k
        end
    end
    return str
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

baseProg=[=[

import cbor
import zmq

context = zmq.Context()
socket = context.socket(zmq.REP)
socket.bind(f'XXXconnectionAddress1XXX')
module = {}
while True:
    req = cbor.loads(socket.recv())
    rep = {'success': True}
    
    req['cmd']=req['cmd']#.decode("utf-8")

    if req['cmd'] == 'loadCode':
        try:
            req['code']=req['code']#.decode("utf-8")
            exec(req['code'],module)
        except Exception as e:
            import traceback
            rep = {'success': False, 'error': traceback.format_exc()}
    elif req['cmd'] == 'callFunc':
        try:
            req['func']=req['func']#.decode("utf-8")
            func = module[req['func']]
            rep['ret'] = func(*req['args'])
        except Exception as e:
            import traceback
            rep = {'success': False, 'error': traceback.format_exc()}
    else:
        rep = {'success': False, 'error': f'unknown command: "{req["cmd"]}"'}

    socket.send(cbor.dumps(rep))
]=]

otherProg=[=[

import time
import sys
import os
import math
import uuid
import cbor
import zmq

def b64(b):
    import base64
    return base64.b64encode(b).decode('ascii')

class RemoteAPIClient:
    """Client to connect to CoppeliaSim's ZMQ Remote API."""

    def __init__(self):
        self.context = zmq.Context()
        self.socket = self.context.socket(zmq.REQ)
        self.cntsocket = self.context.socket(zmq.SUB)
        self.socket.connect(f'XXXconnectionAddress1XXX')
        self.cntsocket.setsockopt(zmq.SUBSCRIBE, b'')
        self.cntsocket.setsockopt(zmq.CONFLATE, 1)
        self.cntsocket.connect(f'XXXconnectionAddress2XXX')
        self.uuid=str(uuid.uuid4())

    def __del__(self):
        """Disconnect and destroy client."""
        self.socket.close()
        self.cntsocket.close()
        self.context.term()

    def _send(self, req):
        rawReq = cbor.dumps(req)
        self.socket.send(rawReq)

    def _recv(self):
        rawResp = self.socket.recv()
        resp = cbor.loads(rawResp)
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

    def getApi(self):
        return self.call('getApi', [])

    def step(self, *, wait=True):
        self.getStepCount(False)
        self.call('step', [self.uuid])
        self.getStepCount(wait)

    def getStepCount(self, wait):
        try:
            self.cntsocket.recv(0 if wait else zmq.NOBLOCK)
        except zmq.ZMQError:
            pass

def _getFuncIfExists(name):
    method=None
    try:
        method=globals()[name]
        #method=getattr(sys.modules[__name__],name)
    except BaseException as err:
        pass
    return method

def _switchThread():
    if client.threaded:
        client.step()

def _setThreadAutomaticSwitch(level):
    if client.threaded:
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
    else:
        return 0
    
def print(a):
    global sim
    sim.addLog(sim.verbosity_scriptinfos|sim.verbosity_undecorated,str(a))

def _wait(dt,simTime=True):
    retVal = 0.0
    if simTime:
        st = sim.getSimulationTime()
        while sim.getSimulationTime()-st<dt:
            _switchThread()
        retVal=sim.getSimulationTime()-st-dt
    else:
        st = sim.getSystemTimeInMs(-1)
        while sim.getSystemTimeInMs(st)<dt*1000:
            _switchThread()
    return retVal

def _waitForSignal(sigName):
    retVal = 0.0
    while True:
        retVal = sim.getInt32Signal(sigName)!=None or sim.getFloatSignal(sigName)!=None or sim.getDoubleSignal(sigName)!=None or sim.getStringSignal(sigName)!=None
        if retVal:
            break
        _switchThread()
    return retVal

def _moveToConfig(flags,currentPos,currentVel,currentAccel,maxVel,maxAccel,maxJerk,targetPos,targetVel,callback,auxData=None,cyclicJoints=None,timeStep=0):
    lb=_setThreadAutomaticSwitch(False)

    currentPosVelAccel=[]
    maxVelAccelJerk=[]
    targetPosVel=[]
    sel=[]
    outPos=[]
    outVel=[]
    outAccel=[]
    for i in range(len(currentPos)):
        v=currentPos[i]
        currentPosVelAccel.append(v)
        outPos.append(v)
        maxVelAccelJerk.append(maxVel[i])
        w=targetPos[i]
        if cyclicJoints and cyclicJoints[i]:
            while w-v>=math.pi*2:
                w=w-math.pi*2
            while w-v<0:
                w=w+math.pi*2
            if w-v>math.pi:
                w=w-math.pi*2
        targetPosVel.append(w)
        sel.append(1)
    for i in range(len(currentPos)):
        if currentVel:
            currentPosVelAccel.append(currentVel[i])
            outVel.append(currentVel[i])
        else:
            currentPosVelAccel.append(0)
            outVel.append(0)
        maxVelAccelJerk.append(maxAccel[i])
        if targetVel:
            targetPosVel.append(targetVel[i])
        else:
            targetPosVel.append(0)
    for i in range(len(currentPos)):
        if currentAccel:
            currentPosVelAccel.append(currentAccel[i])
            outAccel.append(currentAccel[i])
        else:
            currentPosVelAccel.append(0)
            outAccel.append(0)
        maxVelAccelJerk.append(maxJerk[i])

    ruckigObject = sim.ruckigPos(len(currentPos),0.0001,flags,currentPosVelAccel,maxVelAccelJerk,sel,targetPosVel)
    result = 0
    timeLeft = 0
    while result == 0:
        dt = timeStep
        if dt == 0:
            dt=sim.getSimulationTimeStep()
        syncTime = 0
        result,newPosVelAccel,syncTime = sim.ruckigStep(ruckigObject,dt)
        if result >= 0:
            if result == 0:
                timeLeft = dt-syncTime
            for i in range(len(currentPos)):
                outPos[i]=newPosVelAccel[i]
                outVel[i]=newPosVelAccel[len(currentPos)+i]
                outAccel[i]=newPosVelAccel[len(currentPos)*2+i]
            callback(outPos,outVel,outAccel,auxData)
        else:
            raise RuntimeError("sim.ruckigStep returned error code "+result)
        if result == 0:
            _switchThread()
    sim.ruckigRemove(ruckigObject)
    _setThreadAutomaticSwitch(lb)
    return outPos,outVel,outAccel,timeLeft

def _moveToPose(flags,currentPoseOrMatrix,maxVel,maxAccel,maxJerk,targetPoseOrMatrix,callback,auxData=None,metric=None,timeStep=0):
    lb = sim.setThreadAutomaticSwitch(False)

    usingMatrices = (len(currentPoseOrMatrix)>=12)
    if usingMatrices:
        currentMatrix = currentPoseOrMatrix
        targetMatrix = targetPoseOrMatrix
    else:
        currentMatrix = sim.buildMatrixQ(currentPoseOrMatrix,[currentPoseOrMatrix[3],currentPoseOrMatrix[4],currentPoseOrMatrix[5],currentPoseOrMatrix[6]])
        targetMatrix = sim.buildMatrixQ(targetPoseOrMatrix,[targetPoseOrMatrix[3],targetPoseOrMatrix[4],targetPoseOrMatrix[5],targetPoseOrMatrix[6]])

    outMatrix = sim.copyTable(currentMatrix)
    axis,angle = sim.getRotationAxis(currentMatrix,targetMatrix)
    timeLeft = 0
    if metric:
        # Here we treat the movement as a 1 DoF movement, where we simply interpolate via t between
        # the start and goal pose. This always results in straight line movement paths
        dx = [(targetMatrix[3]-currentMatrix[3])*metric[0],(targetMatrix[7]-currentMatrix[7])*metric[1],(targetMatrix[11]-currentMatrix[11])*metric[2],angle*metric[3]]
        distance = math.sqrt(dx[0]*dx[0]+dx[1]*dx[1]+dx[2]*dx[2]+dx[3]*dx[3])
        if distance > 0.000001:
            currentPosVelAccel = [0,0,0]
            maxVelAccelJerk = [maxVel[0],maxAccel[0],maxJerk[0]]
            targetPosVel = [distance,0]
            ruckigObject = sim.ruckigPos(1,0.0001,flags,currentPosVelAccel,maxVelAccelJerk,[1],targetPosVel)
            result = 0
            while result == 0:
                dt = timeStep
                if dt == 0:
                    dt = sim.getSimulationTimeStep()
                result,newPosVelAccel,syncTime = sim.ruckigStep(ruckigObject,dt)
                if result >= 0:
                    if result == 0:
                        timeLeft = dt-syncTime
                    t = newPosVelAccel[0]/distance
                    mi = sim.interpolateMatrices(currentMatrix,targetMatrix,t)
                    nv = [newPosVelAccel[1]]
                    na = [newPosVelAccel[2]]
                    if not usingMatrices:
                        q = sim.getQuaternionFromMatrix(mi)
                        mi = [mi[3],mi[7],mi[11],q[0],q[1],q[2],q[3]]
                    callback(mi,nv,na,auxData)
                else:
                    raise RuntimeError("sim.ruckigStep returned error code "+result)
                if result == 0:
                    sim.switchThread()
            sim.ruckigRemove(ruckigObject)
    else:
        # Here we treat the movement as a 4 DoF movement, where each of X, Y, Z and rotation
        # is handled and controlled individually. This can result in non-straight line movement paths,
        # due to how the Ruckig functions operate depending on 'flags'
        dx = [targetMatrix[3]-currentMatrix[3],targetMatrix[7]-currentMatrix[7],targetMatrix[11]-currentMatrix[11],angle]
        currentPosVelAccel = [0,0,0,0,0,0,0,0,0,0,0,0]
        maxVelAccelJerk = [maxVel[0],maxVel[1],maxVel[2],maxVel[3],maxAccel[0],maxAccel[1],maxAccel[2],maxAccel[3],maxJerk[0],maxJerk[1],maxJerk[2],maxJerk[3]]
        targetPosVel = [dx[0],dx[1],dx[2],dx[3],0,0,0,0,0]
        ruckigObject = sim.ruckigPos(4,0.0001,flags,currentPosVelAccel,maxVelAccelJerk,[1,1,1,1],targetPosVel)
        result = 0
        while result == 0:
            dt = timeStep
            if dt == 0:
                dt = sim.getSimulationTimeStep()
            result,newPosVelAccel,syncTime = sim.ruckigStep(ruckigObject,dt)
            if result >= 0:
                if result == 0:
                    timeLeft = dt-syncTime
                t = 0
                if abs(angle)>math.pi*0.00001:
                    t = newPosVelAccel[3]/angle
                mi = sim.interpolateMatrices(currentMatrix,targetMatrix,t)
                mi[3] = currentMatrix[3]+newPosVelAccel[0]
                mi[7] = currentMatrix[7]+newPosVelAccel[1]
                mi[11] = currentMatrix[11]+newPosVelAccel[2]
                nv = [newPosVelAccel[4],newPosVelAccel[5],newPosVelAccel[6],newPosVelAccel[7]]
                na = [newPosVelAccel[8],newPosVelAccel[9],newPosVelAccel[10],newPosVelAccel[11]]
                if not usingMatrices:
                    q = sim.getQuaternionFromMatrix(mi)
                    mi = [mi[3],mi[7],mi[11],q[0],q[1],q[2],q[3]]
                callback(mi,nv,na,auxData)
            else:
                raise RuntimeError("sim.ruckigStep returned error code "+result)
            if result == 0:
                sim.switchThread()
        sim.ruckigRemove(ruckigObject)

    if not usingMatrices:
        q = sim.getQuaternionFromMatrix(outMatrix)
        outMatrix = [outMatrix[3],outMatrix[7],outMatrix[11],q[0],q[1],q[2],q[3]]

    sim.setThreadAutomaticSwitch(lb)
    return outMatrix,timeLeft


def __startClientScript__():
    XXXauxInstructionsXXX
    global client
    client = RemoteAPIClient()
    allApiFuncs = client.getApi()
    for a in allApiFuncs:
        globals()[a] = client.getObject(a)
    #global sim
    #sim = client.getObject('sim')
    global threadLocLevel
    threadLocLevel = 0
    glob=globals()
    l={}
    for k in glob:
        if callable(glob[k]):
            l[k]=True
    client.call('serviceCall', ["pythonFuncs",l])
    
    sim.switchThread = _switchThread
    sim.setThreadAutomaticSwitch = _setThreadAutomaticSwitch
    sim.wait = _wait
    sim.waitForSignal = _waitForSignal
    sim.moveToConfig = _moveToConfig
    sim.moveToPose = _moveToPose
    threadFunc = _getFuncIfExists("threadMain")
    args = None
    if threadFunc==None:
        # Run as 'non-threaded'
        client.threaded = False
        funcToRun = "sysCall_init"
        func=_getFuncIfExists(funcToRun)
        if func:
            try:
                while funcToRun!="sysCall_cleanup":
                    func=_getFuncIfExists(funcToRun)
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
                        funcToRun = f[0]#.decode("utf-8")
                        args = f[1]
                    else:
                        funcToRun = f#.decode("utf-8")
                        args = None
            finally:
                # We expect to be able to run the cleanup code:
                func = _getFuncIfExists("sysCall_cleanup")
                func()
                client.call('serviceCall', ["callDone"])
        else:
            raise RuntimeError("sysCall_init function not found")
    else:
        # Run as 'threaded'
        client.threaded = True
        _setThreadAutomaticSwitch(False)
        client.call('serviceCall', ["runningThread"])
        try:
            threadFunc()
        finally:
            client.setStepping(False)
            client.call('serviceCall', ["threadEnded"])
]=]