startTimeout=2
sim=require('sim')
simZMQ=require('simZMQ')
simSubprocess=require('simSubprocess')
simUI=require('simUI')
cborDecode=require'org.conman.cbor' -- use only for decoding. For encoding use sim.packCbor
removeLazyLoaders()

pythonWrapper={}

function sim.setThreadSwitchTiming(switchTiming)
    -- Shadow the original func
    -- 0=disabled, otherwise switchTiming
    threadSwitchTiming=switchTiming
end

function sim.setStepping(_stepping)
    -- When stepping is true, CoppeliaSim ALWAYS blocks while Python runs some code
    -- When stepping is false, CoppeliaSim run concurently to Python, i.e. Python is "free" (until a request from Python comes)
    stepping=_stepping
end

function sim.handleExtCalls() -- can be called by Python when in free thread mode, to trigger callbacks such a UI button presses, etc.
end

function sysCall_init(...)
    returnTypes={}
    simZMQ.__raiseErrors(true) -- so we don't need to check retval with every call
    
    context=simZMQ.ctx_new()
    replySocket=simZMQ.socket(context,simZMQ.REP)
    replyPortStr=getFreePortStr()
    simZMQ.bind(replySocket,replyPortStr)
    
    local prog=pythonProg..otherProg
    prog=prog:gsub("XXXconnectionAddress1XXX",replyPortStr)
    local tmp=''
    if _additionalPaths then 
        for i=1,#_additionalPaths,1 do
            tmp=tmp..'sys.path.append("'.._additionalPaths[i]..'")\n'
        end
    end
    if additionalPaths then 
        for i=1,#additionalPaths,1 do
            tmp=tmp..'sys.path.append("'..additionalPaths[i]..'")\n'
        end
    end
    prog=prog:gsub("XXXadditionalPathsXXX",tmp)
    initPython(prog)
    pythonCallbacks={pythonCallback1,pythonCallback2,pythonCallback3}
    pythonCallbackStrs={'','',''}

    corout=coroutine.create(coroutineMain)
    threadInitLockLevel=setThreadAutomaticSwitch(false)
    threadSwitchTiming=0.002 -- time given to service Python scripts
    threadLastSwitchTime=0
    threadBusyCnt=0
    stepping=false -- in stepped mode switching is always explicit. Non-threaded scripts are also in stepped mode
    runNextStep=false -- in stepping mode, runNextStep triggers the next step
    protectedCallErrorDepth=0
    protectedCallDepth=0
    pythonMustHaveRaisedError=false
    callingPythonInBlockingMode=true
    receiveIsNext=true
    
    -- blocking functions calling back need special treatment:
    callbackFunctions={} 
    callbackFunctions[sim.moveToConfig]=true
    
    handleRequestsUntilExecutedReceived() -- handle commands from Python prior to start, e.g. initial function calls to CoppeliaSim

    -- Disable optional system callbacks that are not used on Python side (nonSimulation, init, beforeMainScript, cleanup, ext and userConfig are special):
    local optionalSysCallbacks={sysCall_actuation,sysCall_suspended,sysCall_beforeSimulation,sysCall_afterSimulation,sysCall_sensing,sysCall_suspend,sysCall_resume,sysCall_realTimeIdle,sysCall_beforeInstanceSwitch,sysCall_afterInstanceSwitch,sysCall_beforeSave,sysCall_afterSave,sysCall_beforeCopy,sysCall_afterCopy,sysCall_afterCreate,sysCall_beforeDelete,sysCall_afterDelete,sysCall_addOnScriptSuspend,sysCall_addOnScriptResume,sysCall_dyn,sysCall_joint,sysCall_contact,sysCall_vision,sysCall_trigger,sysCall_moduleEntry,sysCall_msg,sysCall_event}

    for i=1,#optionalSysCallbacks,1 do
        local nm=optionalSysCallbacks[i]
        if pythonFuncs[nm]==nil then
            _G[nm]=nil
        end
    end

    if pythonFuncs['sysCall_userConfig'] then
        sysCall_userConfig=_sysCall_userConfig -- special
    end

    stepping=(pythonFuncs['sysCall_thread']==nil) -- in non-threaded mode, we behave as if we were stepping

    if pythonFuncs["sysCall_init"]==nil and pythonFuncs["sysCall_thread"]==nil then
        error("can't find sysCall_init nor sysCall_thread functions")
    end

    return callRemoteFunction("sysCall_init",{...})
end

function sysCall_cleanup(...)
    if subprocess~=nil then
        inCleanup=true
        callRemoteFunction("sysCall_cleanup",{...})
    end

    cleanupPython()
    simZMQ.close(replySocket)
    simZMQ.ctx_term(context)
end

function coroutineMain()
    callRemoteFunction("sysCall_thread",{})
end

function sysCall_ext(funcName,...)
    local args={...}
    if pythonFuncs['sysCall_ext'] then
        return callRemoteFunction('sysCall_ext',{funcName,args})
    else
        if _G[funcName] then -- for now ignore functions in tables
            return _G[funcName](args)
        else
            return callRemoteFunction(funcName,args)
        end
    end
end

function resumeCoroutine()
    if coroutine.status(corout)~='dead' then
        protectedCallDepth=protectedCallDepth+1
        local ok,errorMsg=coroutine.resume(corout)
        protectedCallDepth=protectedCallDepth-1
        if errorMsg then
            error(debug.traceback(corout,errorMsg),2) -- this error is very certainly linked to the Python wrapper itself
        end
        checkPythonError()
    end
end

function sysCall_nonSimulation(...)
    if pythonFuncs['sysCall_thread'] then
        resumeCoroutine()
    end
    return callRemoteFunction("sysCall_nonSimulation",{...})
end

-- Special handling of sim.switchThread:
_simSwitchThread=sim.switchThread
function sim.switchThread()
    if sim.getSimulationState()==sim.simulation_stopped then
        _simSwitchThread()
    else
        local st=sim.getSimulationTime()
        while sim.getSimulationTime()==st do
            -- stays inside here until we are ready with next simulation step. This is important since
            -- other clients/scripts could too be hindering the main script to run in sysCall_beforeMainScript
            if stepping then
                runNextStep=true
            end
            _simSwitchThread()
        end
    end
end

function sysCall_beforeMainScript(...)
    if pythonFuncs['sysCall_thread'] then
        resumeCoroutine()
        if stepping and not runNextStep then
            return {doNotRunMainScript=true}
        end
        runNextStep=false
    end
    return callRemoteFunction("sysCall_beforeMainScript",{...})
end

function sysCall_actuation(...)
    return callRemoteFunction("sysCall_actuation",{...})
end

function sysCall_suspended(...)
    return callRemoteFunction("sysCall_suspended",{...})
end

function sysCall_sensing(...)
    return callRemoteFunction("sysCall_sensing",{...})
end

function sysCall_beforeSimulation(...)
    return callRemoteFunction("sysCall_beforeSimulation",{...})
end

function sysCall_afterSimulation(...)
    return callRemoteFunction("sysCall_afterSimulation",{...})
end

function sysCall_suspend(...)
    return callRemoteFunction("sysCall_suspend",{...})
end

function sysCall_resume(...)
    return callRemoteFunction("sysCall_resume",{...})
end

function sysCall_realTimeIdle(...)
    return callRemoteFunction("sysCall_realTimeIdle",{...})
end

function sysCall_beforeInstanceSwitch(...)
    return callRemoteFunction("sysCall_beforeInstanceSwitch",{...})
end

function sysCall_afterInstanceSwitch(...)
    return callRemoteFunction("sysCall_afterInstanceSwitch",{...})
end

function sysCall_beforeSave(...)
    return callRemoteFunction("sysCall_beforeSave",{...})
end

function sysCall_afterSave(...)
    return callRemoteFunction("sysCall_afterSave",{...})
end

function sysCall_beforeCopy(...)
    return callRemoteFunction("sysCall_beforeCopy",{...})
end

function sysCall_afterCopy(...)
    return callRemoteFunction("sysCall_afterCopy",{...})
end

function sysCall_afterCreate(...)
    return callRemoteFunction("sysCall_afterCreate",{...})
end

function sysCall_beforeDelete(...)
    return callRemoteFunction("sysCall_beforeDelete",{...})
end

function sysCall_afterDelete(...)
    return callRemoteFunction("sysCall_afterDelete",{...})
end

function sysCall_addOnScriptSuspend(...)
    return callRemoteFunction("sysCall_addOnScriptSuspend",{...})
end

function sysCall_addOnScriptResume(...)
    return callRemoteFunction("sysCall_addOnScriptResume",{...})
end

function sysCall_dyn(...)
    return callRemoteFunction("sysCall_dyn",{...})
end

function sysCall_joint(...)
    return callRemoteFunction("sysCall_joint",{...})
end

function sysCall_contact(...)
    return callRemoteFunction("sysCall_contact",{...})
end

function sysCall_vision(...)
    return callRemoteFunction("sysCall_vision",{...})
end

function sysCall_trigger(...)
    return callRemoteFunction("sysCall_trigger",{...})
end

function _sysCall_userConfig(...) -- special
    return callRemoteFunction("sysCall_userConfig",{...})
end

function sysCall_moduleEntry(...)
    return callRemoteFunction("sysCall_moduleEntry",{...})
end

function sysCall_msg(...)
    return callRemoteFunction("sysCall_msg",{...})
end

function sysCall_event(...)
    return callRemoteFunction("sysCall_event",{...})
end

function pythonCallback1(...)
    return callRemoteFunction(pythonCallbackStrs[1],{...})
end

function pythonCallback2(...)
    return callRemoteFunction(pythonCallbackStrs[2],{...})
end

function pythonCallback3(...)
    return callRemoteFunction(pythonCallbackStrs[3],{...})
end

function sim.testCB(a,cb,b)
    return cb(a,b)
end

function __require__(name)
    _G[name]=require(name)
    parseFuncsReturnTypes(name)
end

function setPythonFuncs(data)
    pythonFuncs=data
end

function __print__(str)
    print(str)
end

function pyTr() -- Dummy function called by Python trace on a regular basis if in freeMode and no interaction with CoppeliaSim since a while - Allows for callbacks to be sent
end

function __getApi__(nameSpace)
    str={}
    for k,v in pairs(_G) do
        if type(v)=='table' and k:find(nameSpace,1,true)==1 then
            str[#str+1]=k
        end
    end
    return str
end

function parseFuncsReturnTypes(nameSpace)
    local funcs=sim.getApiFunc(-1,'+'..nameSpace..'.')
    for i=1,#funcs,1 do
        local func=funcs[i]
        local inf=sim.getApiInfo(-1,func)
        local p=string.find(inf,'(',1,true)
        if p then
            inf=string.sub(inf,1,p-1)
            p=string.find(inf,'=')
            if p then
                inf=string.sub(inf,1,p-1)
                local t={}
                local i=1
                for token in (inf..","):gmatch("([^,]*),") do
                    p=string.find(token,' ')
                    if p then
                        token=string.sub(token,1,p-1)
                        if token=='string' then
                            t[i]=1
                        elseif token=='buffer' then
                            t[i]=2
                        else
                            t[i]=0
                        end
                    else
                        t[i]=0
                    end
                    i=i+1
                end
                returnTypes[func]=t
            else
                returnTypes[func]={}
            end
        end
    end
end

function handleRequest(req)
    local resp={}
    if req['func']~=nil and req['func']~='' then
        local func=_getField(req['func'])
        local args=req['args'] or {}
        if not func then
            pythonMustHaveRaisedError = true -- actually not just yet, we still need to send a reply tp Python
            resp['err']='No such function: '..req['func']
        else
            if func==sim.setThreadAutomaticSwitch then
                -- For backward compatibility with pythonWrapperV1
                func=sim.setStepping
                if #args>0 then
                    args[1]= (args[1]==0) or (args[1]==false)
                end
            end
            
            -- Handle function arguments:
            local prefix="<function "
            local cbi=1
            for i=1,#args,1 do
                if type(args[i])=='string' then
                    local p=string.find(args[i],prefix)
                    if p==1 then
                        local nm=string.sub(args[i],#prefix+1)
                        p=string.find(nm," ")
                        if p then
                            nm=string.sub(nm,1,p-1)
                            args[i]=pythonCallbacks[cbi]
                            pythonCallbackStrs[cbi]=nm
                            cbi=cbi+1
                        end
                    end
                end
            end
            
            local function errHandler(err)
                local trace = debug.traceback(err)
                local p=string.find(trace,"\nstack traceback:")
                if p then
                    trace=trace:sub(1,p-1) -- strip traceback from xpcall
                end
                -- Make sure the string survives the passage to Python unmodified:
                trace=string.gsub(trace,"\n","_=NL=_")
                trace=string.gsub(trace,"\t","_=TB=_")
                return trace
            end
            
            protectedCallDepth=protectedCallDepth+1
            local status,retvals=xpcall(function()
                local ret={func(unpack(args))}
                -- Try to assign correct types to text and buffers:
                local args=returnTypes[req['func']]
                if args then
                    local cnt=math.min(#ret,#args)
                    for i=1,cnt,1 do
                        if args[i]==1 then
                            ret[i]=ret[i]..'@:txt:'
                        elseif args[i]==2 then
                            ret[i]=ret[i]..'@:dat:'
                        end
                    end
                end
                return ret
            end,errHandler)
            protectedCallDepth=protectedCallDepth-1
            
            if status==false then
                pythonMustHaveRaisedError=true -- actually not just yet, we still need to send a reply tp Python
            end
            resp[status and 'ret' or 'err']=retvals
        end
    elseif req['eval']~=nil and req['eval']~='' then
        local status,retvals=pcall(function()
            -- cannot prefix 'return ' here, otherwise non-trivial code breaks
            -- local ret={loadstring('return '..req['eval'])()}
            local ret={loadstring(req['eval'])()}
            return ret
        end)
        if status==false then
            pythonMustHaveRaisedError=true -- actually not just yet, we still need to send a reply tp Python
        end
        resp[status and 'ret' or 'err']=retvals
    end
    return resp
end

function __info__(obj)
    if type(obj)=='string' then obj=_getField(obj) end
    if type(obj)~='table' then return obj end
    local ret={}
    for k,v in pairs(obj) do
        if type(v)=='table' then
            ret[k]=__info__(v)
        elseif type(v)=='function' then
            ret[k]={func={}}
        elseif type(v)~='function' then
            ret[k]={const=v}
        end
    end
    return ret
end

function _getField(f)
    local v=_G
    for w in string.gmatch(f,'[%w_]+') do
        v=v[w]
        if not v then return nil end
    end
    return v
end

function receive()
    -- blocking, but can switch thread
    if receiveIsNext then
        if callingPythonInBlockingMode then
            while simZMQ.poll({replySocket},{simZMQ.POLLIN},100)<=0 do
                if checkPythonError() then
                    return -- unwind xpcalls
                end
            end
        else
            while simZMQ.poll({replySocket},{simZMQ.POLLIN},0)<=0 do
                local r,l=getThreadAutomaticSwitch()
                if l-1==threadInitLockLevel then
                    if threadSwitchTiming>0 then
                        if sim.getSystemTime()-threadLastSwitchTime>=threadSwitchTiming or threadBusyCnt==0 then
                            if checkPythonError() then
                                return -- unwind xpcalls
                            end
                            _simSwitchThread() --sim.switchThread()
                            threadLastSwitchTime=sim.getSystemTime()
                            threadBusyCnt=0 -- after a switch, if the socket is idle, we switch immediately again. Otherwise we wait max. threadSwitchTiming
                        end
                    end
                end
            end
            threadBusyCnt=threadBusyCnt+1
        end

        local rc,dat=simZMQ.recv(replySocket,0)
        receiveIsNext=false
        local status,req=pcall(cborDecode.decode,dat)
        if not status then
            error('CBOR decode error: '..sim.transformBuffer(dat,sim.buffer_uint8,1,0,sim.buffer_base64))
        end
        return req
    else
        error('Trying to receive data from Python where a send is expected')
    end
end

function send(reply)
    if not receiveIsNext then
        local dat=reply
        status,reply=pcall(sim.packCbor,reply)
        if not status then
            error('CBOR encode error: '..getAsString(dat))
        end
        simZMQ.send(replySocket,reply,0)
        receiveIsNext=true
    else
        error('Trying to send data to Python where a receive is expected')
    end
end

function handleRequestsUntilExecutedReceived()
    -- Handle requests from Python, until we get a _*executed*_ message. Func is reentrant
    while true do
        local req=receive() -- blocking (but can switch thread (i.e. happens only with sysCall_thread))

        if req==nil then
            return -- unwind xpcalls
        end

        local callingPythonInBlockingModeSaved=callingPythonInBlockingMode
        callingPythonInBlockingMode=true


        -- Handle buffered callbacks:
        if bufferedCallbacks and #bufferedCallbacks>0 then
            local tmp=bufferedCallbacks
            bufferedCallbacks={}
            for i=1,#tmp,1 do
                callRemoteFunction(tmp[i].func,tmp[i].args)
                if checkPythonError() then
                    return -- unwind xpcalls
                end
            end
        end

        if req['func']=='_*executed*_' then
            return req.args
        end

        --print(req)
        local resp=handleRequest(req)

        if pythonMustHaveRaisedError then
            if protectedCallErrorDepth==0 then
                send(resp)
            end
            protectedCallErrorDepth=protectedCallErrorDepth-1
        else
            if checkPythonError() then
                return -- unwind xpcalls
            end
            send(resp)
        end

        callingPythonInBlockingMode=callingPythonInBlockingModeSaved
    end
end

function callRemoteFunction(callbackFunc,callbackArgs)
    -- Func is reentrant
    local retVal
    if checkPythonError() then
        return -- unwind xpcalls
    end

    if pythonFuncs and pythonFuncs[callbackFunc] then
        if callingPythonInBlockingMode then
            -- First handle buffered, async callbacks:
            if bufferedCallbacks and #bufferedCallbacks>0 then
                local tmp=bufferedCallbacks
                bufferedCallbacks={}
                for i=1,#tmp,1 do
                    callRemoteFunction(tmp[i].func,tmp[i].args)
                    if checkPythonError() then
                        return -- unwind xpcalls
                    end
                end
            end

            -- Tell Python to run a function:
            callingPythonInBlockingModeSaved=callingPythonInBlockingMode
            callingPythonInBlockingMode=(callbackFunc~='sysCall_thread')
            send({func=callbackFunc,args=callbackArgs})

            -- Wait for the reply from Python
            retVal=handleRequestsUntilExecutedReceived()
            callingPythonInBlockingMode=callingPythonInBlockingModeSaved
        else
            if bufferedCallbacks==nil then
                bufferedCallbacks={}
            end
            bufferedCallbacks[#bufferedCallbacks+1]={func=callbackFunc,args=callbackArgs}
        end
    end
    return retVal
end

function checkPythonError()
    if subprocess then
        if simSubprocess.isRunning(subprocess) then
            while pythonErrorMsg==nil do
                local r,rep=simZMQ.__noError.recv(pySocket,simZMQ.DONTWAIT)
                if r>=0 then
                    local rep,o,t=cborDecode.decode(rep)
                    if rep.err then
                        --print(getAsString(rep.err))
                        local msg=getCleanErrorMsg(rep.err)
                        msg='__[[__'..msg..'__]]__'
                        --print(getAsString(msg))
                        pythonErrorMsg=msg
                    end
                else
                    if not pythonMustHaveRaisedError then -- pythonMustHaveRaisedError: the error happened here and was transmitted to Python to raise an error there
                        break
                    end
                end
            end

            if pythonErrorMsg then
                if protectedCallDepth==0 then
                    local errMsg=pythonErrorMsg
                    if not inCleanup then
                        simZMQ.close(replySocket)
                        replySocket=simZMQ.socket(context,simZMQ.REP)
                        simZMQ.bind(replySocket,replyPortStr)
                        pythonErrorMsg=nil
                        protectedCallDepth=0
                        protectedCallErrorDepth=0
                        pythonMustHaveRaisedError=false
                        stepping=false
                        callingPythonInBlockingMode=true
                        receiveIsNext=true
                        simZMQ.send(pySocket,sim.packCbor({cmd='callFunc',func='__restartClientScript__',args={}}),0)
                        handleRequestsUntilExecutedReceived() -- handle commands from Python prior to start, e.g. initial function calls to CoppeliaSim
                    end
                    error(errMsg)
                end
            end
        end
    end
    return pythonErrorMsg
end

function getFreePortStr()
    local tmpContext=simZMQ.ctx_new()
    local tmpSocket=simZMQ.socket(tmpContext,simZMQ.REP)
    local p=23259
    while true do
        if simZMQ.__noError.bind(tmpSocket,string.format('tcp://127.0.0.1:%d',p))==0 then
            break
        end
        p=p+1
    end
    simZMQ.close(tmpSocket)
    simZMQ.ctx_term(tmpContext)
    return string.format('tcp://127.0.0.1:%d',p)
end

function initPython(prog)
    local pyth=sim.getStringParam(sim.stringparam_defaultpython)
    local pyth2=sim.getNamedStringParam("python")
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
    local showDlg=true
    if pyth and #pyth>0 then
        subprocess,controlPort=startPythonClientSubprocess(pyth)
        if controlPort then
            pyContext=simZMQ.ctx_new()
            pySocket=simZMQ.socket(pyContext,simZMQ.REQ)
            simZMQ.setsockopt(pySocket,simZMQ.LINGER,sim.packUInt32Table{0})
            simZMQ.connect(pySocket,controlPort)
            simZMQ.send(pySocket,sim.packCbor({cmd='loadCode',code=prog}),0)
            local st=sim.getSystemTime()
            local r,rep
            while sim.getSystemTime()-st<startTimeout or simSubprocess.isRunning(subprocess) do
                simSubprocess.wait(subprocess,0.1)
                r,rep=simZMQ.__noError.recv(pySocket,simZMQ.DONTWAIT)
                if r>=0 then
                    break
                end
            end
            if r>=0 then
                local rep,o,t=cborDecode.decode(rep)
                if rep.err then
                    showDlg=false
                    errMsg=rep.err
                    errMsg=getCleanErrorMsg(errMsg)
                    simSubprocess.wait(subprocess,0.1)
                    if simSubprocess.isRunning(subprocess) then
                        simSubprocess.kill(subprocess)
                        subprocess=nil
                    end
                else
                    simZMQ.send(pySocket,sim.packCbor({cmd='callFunc',func='__startClientScript__',args={}}),0)
                end
            else
                errMsg="The Python interpreter could not handle the wrapper script (or communication between the launched subprocess and CoppeliaSim could not be established via sockets).\nMake sure that the Python modules 'cbor' and 'zmq' are properly installed, e.g. via:\n$ /path/to/python -m pip install pyzmq\n$ /path/to/python -m pip install cbor\nAdditionally, you can try adjusting the value of startTimeout in lua/pythonWrapperV2.lua, at the top of the file"
                simSubprocess.wait(subprocess,0.1)
                if simSubprocess.isRunning(subprocess) then
                    simSubprocess.kill(subprocess)
                end
            end
        else
            errMsg=subprocess
            subprocess=nil
        end
    else
        local usrSysLoc=sim.getStringParam(sim.stringparam_usersettingsdir) 
        errMsg="The Python interpreter was not set. Specify it in "..usrSysLoc.."/usrset.txt with 'defaultPython', or via the named string parameter 'python' from the command line"
    end
    if errMsg then
        if showDlg then
            local r=sim.readCustomDataBlock(sim.handle_app,'msgShown')
            if r==nil then
                -- show this only once
                sim.writeCustomDataBlock(sim.handle_app,'msgShown',"yes")
                simUI.msgBox(simUI.msgbox_type.warning,simUI.msgbox_buttons.ok,"Python interpreter",errMsg)
            end
        end
        errMsg='__[[__'..errMsg..'__]]__'
        error(errMsg)
    end
end

-- For Python, we should always return a string:
_S.readCustomDataBlock=sim.readCustomDataBlock
function sim.readCustomDataBlock(obj,tag)
    local retVal=_S.readCustomDataBlock(obj,tag)
    if retVal==nil then
        retVal=''
    end
    return retVal
end

function startPythonClientSubprocess(pythonExec)
    local subprocess,controlPort
    local data=sim.readCustomTableData(sim.handle_app,'pythonClients_idleSubprocesses')
    if #data>0 then
        -- Use an existing idle process
        subprocess=data[#data].subprocess
        controlPort=data[#data].controlPort
        table.remove(data)
        sim.writeCustomTableData(sim.handle_app,'pythonClients_idleSubprocesses',data)
    else
        controlPort=getFreePortStr()
        local res,ret=pcall(function()
            return simSubprocess.execAsync(pythonExec,{sim.getStringParam(sim.stringparam_pythondir)..'/pythonLauncher.py',controlPort},{useSearchPath=true,openNewConsole=false}) 
            end)
        if res then
            subprocess=ret
        else
            local usrSysLoc=sim.getStringParam(sim.stringparam_usersettingsdir) 
            subprocess="The Python interpreter could not be called. It is currently set at: '"..pythonExec.."'. You can specify it in "..usrSysLoc.."/usrset.txt with 'defaultPython', or via the named string parameter 'python' from the command line"
            controlPort=nil
        end
    end
    return subprocess,controlPort
end

function cleanupPython()
    if subprocess then
        simSubprocess.wait(subprocess,0.1)
        if simSubprocess.isRunning(subprocess) then
            simSubprocess.kill(subprocess)
        end
    end
    if pySocket then
        simZMQ.close(pySocket)
        simZMQ.ctx_term(pyContext)
    end
end

function getCleanErrorMsg(inMsg)
    local msg=inMsg
    if msg and #msg>0 and not nakedErrors then
        --msg=string.gsub(msg,"Exception: ","  Exception: ")
        msg=string.gsub(msg,"_=NL=_","\n")
        msg=string.gsub(msg,"_=TB=_","\t")
        local tg="#__EXCEPTION__\n"
        local p=string.find(msg,tg)
        if p then
            msg=msg:sub(p+#tg)
            msg="Traceback (most recent call last):\n"..msg
        end
        local _,totLines=string.gsub(pythonProg,'\n','')
        totLines=totLines+1
        local toRemove={"[^\n]*rep%['ret'%] = func%(%*req%['args'%]%)[^\n]*\n","[^\n]*exec%(req%['code'%],module%)[^\n]*\n"}
        for i=1,#toRemove,1 do
            local p1,p2=string.find(msg,toRemove[i])
            if p1 then
                msg=string.sub(msg,1,p1-1)..string.sub(msg,p2+1)
            end
        end
        local p1=0,p2,p3
        while true do
            p2,p3=string.find(msg,'[^\n]*File "<string>", line %d+,[^\n]+\n',p1+1)
            if p2 then
                local lineNb=tonumber(string.sub(msg,string.find(msg,'%d+',p2)))
                if lineNb<=totLines then
                    p1=p2
                else
                    msg=string.sub(msg,1,p2-1)..string.sub(msg,p3+1)
                end
            else
                break
            end
        end
        if externalFile then
            msg=string.gsub(msg,'File "<string>"','File "'..externalFile..'"')
        else
            msg=string.gsub(msg,'File "<string>"','script')
        end
        msg=string.gsub(msg, "Exception: %d+:", "Exception")
    end
    return msg
end

function loadExternalFile(file)
    externalFile=file
    local f
    local absPath
    if sim.getInt32Param(sim.intparam_platform)==0 then
        absPath=( (file:sub(1,1)=='/') or (file:sub(1,1)=='\\') or (file:sub(2,2)==':') )
    else
        absPath=(file:sub(1,1)=='/')
    end
    if absPath then
        f=io.open(file,'rb')
    else
        local b={sim.getStringParam(sim.stringparam_application_path),sim.getStringParam(sim.stringparam_application_path)..'/python',sim.getStringParam(sim.stringparam_scene_path),sim.getStringParam(sim.stringparam_additionalpythonpath)}
        if additionalIncludePaths and #additionalIncludePaths>0 then
            for i=1,#additionalIncludePaths,1 do
                b[#b+1]=additionalIncludePaths[i]
            end
        end
        for i=1,#b,1 do
            if b[i]~='' then
                f=io.open(b[i]..'/'..file,'rb')
                if f then
                    file=b[i]..'/'..file
                    break
                end
            end
        end
    end
    if f==nil then
        error("include file '"..file.."' not found")
    end
    if not pythonProg then
        pythonProg=''
    end
    pythonProg=f:read('*all')..pythonProg
    f:close()
    while #file>0 do
        local c=file:sub(#file,#file)
        if c~='/' and c~='\\' then
            file=file:sub(1,#file-1)
        else
            break
        end
    end
    _additionalPaths={file}
end


otherProg=[=[

import time
import sys
import os
import cbor
import zmq

XXXadditionalPathsXXX

class LazyProxyObj:
    def __init__(self, client, name):
        self.client, self.name, self.obj = client, name, None
    def __getattr__(self, k):
        if not self.obj:
            self.obj = self.client.getObject(self.name)
        return getattr(self.obj, k)

class RemoteAPIClient:
    def __init__(self):
        self.context = zmq.Context()
        self.socket = self.context.socket(zmq.REQ)
        self.socket.connect(f'XXXconnectionAddress1XXX')

    def __del__(self):
        # Disconnect and destroy client
        self.socket.close()
        self.context.term()

    def _send(self, req):
        # convert a possible function to string:
        if 'args' in req and req['args']!=None and (isinstance(req['args'],tuple) or isinstance(req['args'],list)):
            req['args']=list(req['args'])
            for i in range(len(req['args'])):
                if callable(req['args'][i]):
                    req['args'][i]=str(req['args'][i])

        # pack and send:            
        rawReq = cbor.dumps(req)
        self.socket.send(rawReq)

    def _recv(self):
        rawResp = self.socket.recv()
        resp = cbor.loads(rawResp)
        return resp

    def _process_response(self, resp):
        ret = resp['ret']
        if len(ret) == 1:
            return ret[0]
        if len(ret) > 1:
            return tuple(ret)

    def call(self, func, args):
        # Call function with specified arguments. Is reentrant
        if func=='_*executed*_':
            args=[]
            while True:
                self._send({'func': '_*executed*_', 'args': args})
                reply = self._recv()
                if 'err' in reply:
                    raise Exception(reply.get('err')) #__EXCEPTION__
                #if reply['func']=='_*leave*_':
                #    return
                funcToRun=_getFuncIfExists(reply['func'])
                args=funcToRun(*reply['args'])
        else:
            self._send({'func': func, 'args': args})
            reply = self._recv()
            while isinstance(reply,dict) and 'func' in reply:
                # We have a callback
                funcToRun=_getFuncIfExists(reply['func'])
                args=funcToRun(*reply['args'])
                self._send({'func': '_*executed*_', 'args': args})
                reply = self._recv()
            if 'err' in reply:
                raise Exception(reply.get('err')) #__EXCEPTION__
            return self._process_response(reply)

    def getObject(self, name, _info=None):
        # Retrieve remote object from server
        ret = type(name, (), {})
        if not _info:
            _info = self.call('__info__', [name])
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
         
    def require(self, name):
        self.call('__require__', [name])
        ret = self.getObject(name)
        allApiFuncs = client.call('__getApi__', [name])
        for a in allApiFuncs:
            globals()[a] = LazyProxyObj(client,a)
        return ret         

def _getFuncIfExists(name):
    method=None
    try:
        method=globals()[name]
    except BaseException as err:
        pass
    return method

def require(a):
    return client.require(a)

def print(a):
    client.call('__print__', [str(a)])
    
'''def trace_function(frame, event, arg):
    if event == "line":
        cnt=0
        cnt=cnt+1
    return trace_function'''    

def __startClientScript__():
    global client
    client = RemoteAPIClient()
    glob=globals()
    allFuncs={}
    for i in glob:
        if callable(glob[i]):
            allFuncs[i]=True
    client.call('setPythonFuncs', [allFuncs])
    #sys.settrace(trace_function)
    client.call('_*executed*_', [])
    
def __restartClientScript__():
    client.call('_*executed*_', [])
]=]
