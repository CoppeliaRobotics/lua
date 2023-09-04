startTimeout=5
sim=require('sim')
simZMQ=require('simZMQ')
simSubprocess=require('simSubprocess')
simUI=require('simUI')
-- cbor=require 'cbor' -- encodes strings as buffers, always. DO NOT USE!!
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
    replyPortStr=pythonWrapper.getFreePortStr()
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
    
    pythonWrapper.initPython(prog)
    pythonCallbacks={pythonCallback1,pythonCallback2,pythonCallback3}
    pythonCallbackStrs={'','',''}

    corout=coroutine.create(coroutineMain)
    threadInitLockLevel=setThreadAutomaticSwitch(false)
    threadSwitchTiming=0.002 -- time given to service Python scripts in non-stepping mode (i.e. free mode). Not used in stepping mode
    stepping=true
    
    -- blocking functions calling back need special treatment:
    callbackFunctions={} 
    callbackFunctions[sim.moveToConfig]=true
    
    local ret=pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_init",{...})
    
    -- Disable optional system callbacks that are not used on Python side (nonSimulation, init, actuation, cleanup and ext are special):
    local optionalSysCallbacks={sysCall_beforeMainScript,sysCall_suspended,sysCall_beforeSimulation,sysCall_afterSimulation,sysCall_sensing,sysCall_suspend,sysCall_resume,sysCall_realTimeIdle,sysCall_beforeInstanceSwitch,sysCall_afterInstanceSwitch,sysCall_beforeSave,sysCall_afterSave,sysCall_beforeCopy,sysCall_afterCopy,sysCall_afterCreate,sysCall_beforeDelete,sysCall_afterDelete,sysCall_addOnScriptSuspend,sysCall_addOnScriptResume,sysCall_dyn,sysCall_joint,sysCall_contact,sysCall_vision,sysCall_trigger,sysCall_userConfig,sysCall_moduleEntry,sysCall_msg,sysCall_event}
    
    for i=1,#optionalSysCallbacks,1 do
        local nm=optionalSysCallbacks[i]
        if pythonFuncs[nm]==nil then
            _G[nm]=nil
        end
    end
    
    return ret
end

function sysCall_cleanup(...)
    inCleanup=true
    pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_cleanup",{...})
    pythonWrapper.callRemoteFunctionAndHandleQueue("_*leave*_",{...})
    pythonWrapper.cleanupPython()
    simZMQ.close(replySocket)
    simZMQ.ctx_term(context)
end

function coroutineMain()
    pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_thread",{})
end

function sysCall_ext(funcName,...)
    if _G[funcName] then -- for now ignore functions in tables
        return _G[funcName](...) 
    else
        return pythonWrapper.callRemoteFunctionAndHandleQueue(funcName,{...})
    end
end

function sysCall_nonSimulation(...)
    if pythonFuncs['sysCall_thread'] then
        if coroutine.status(corout)~='dead' then
            local ok,errorMsg=coroutine.resume(corout)
            if errorMsg then
                error(debug.traceback(corout,errorMsg),2)
            end
        else
            return {cmd='cleanup'}
        end
    else
        return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_nonSimulation",{...})
    end
end

function sysCall_actuation(...)
    if pythonFuncs['sysCall_thread'] then
        if coroutine.status(corout)~='dead' then
            local ok,errorMsg=coroutine.resume(corout)
            if errorMsg then
                error(debug.traceback(corout,errorMsg),2)
            end
        else
            return {cmd='cleanup'}
        end
    else
        return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_actuation",{...})
    end
end

function sysCall_suspended(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_suspended",{...})
end

function sysCall_beforeMainScript(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_beforeMainScript",{...})
end

function sysCall_sensing(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_sensing",{...})
end

function sysCall_beforeSimulation(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_beforeSimulation",{...})
end

function sysCall_afterSimulation(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_afterSimulation",{...})
end

function sysCall_suspend(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_suspend",{...})
end

function sysCall_resume(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_resume",{...})
end

function sysCall_realTimeIdle(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_realTimeIdle",{...})
end

function sysCall_beforeInstanceSwitch(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_beforeInstanceSwitch",{...})
end

function sysCall_afterInstanceSwitch(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_afterInstanceSwitch",{...})
end

function sysCall_beforeSave(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_beforeSave",{...})
end

function sysCall_afterSave(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_afterSave",{...})
end

function sysCall_beforeCopy(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_beforeCopy",{...})
end

function sysCall_afterCopy(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_afterCopy",{...})
end

function sysCall_afterCreate(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_afterCreate",{...})
end

function sysCall_beforeDelete(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_beforeDelete",{...})
end

function sysCall_afterDelete(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_afterDelete",{...})
end

function sysCall_addOnScriptSuspend(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_addOnScriptSuspend",{...})
end

function sysCall_addOnScriptResume(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_addOnScriptResume",{...})
end

function sysCall_dyn(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_dyn",{...})
end

function sysCall_joint(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_joint",{...})
end

function sysCall_contact(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_contact",{...})
end

function sysCall_vision(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_vision",{...})
end

function sysCall_trigger(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_trigger",{...})
end

function sysCall_userConfig(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_userConfig",{...})
end

function sysCall_moduleEntry(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_moduleEntry",{...})
end

function sysCall_msg(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_msg",{...})
end

function sysCall_event(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue("sysCall_event",{...})
end

function pythonCallback1(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue(pythonCallbackStrs[1],{...})
end

function pythonCallback2(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue(pythonCallbackStrs[2],{...})
end

function pythonCallback3(...)
    return pythonWrapper.callRemoteFunctionAndHandleQueue(pythonCallbackStrs[3],{...})
end

function sim.testCB(a,cb,b)
    return cb(a,b)
end

function pythonWrapper.require(name)
    _G[name]=require(name)
    pythonWrapper.parseFuncsReturnTypes(name)
end

function pythonWrapper.pythonFuncs(data)
    pythonFuncs=data
end

function pythonWrapper.print(str)
    print(str)
end

function pythonWrapper.pyTr() -- Dummy function called by Python trace on a regular basis if in freeMode and no interaction with CoppeliaSim since a while - Allows for callbacks to be sent
end

function pythonWrapper.getApi(nameSpace)
    str={}
    for k,v in pairs(_G) do
        if type(v)=='table' and k:find(nameSpace,1,true)==1 then
            str[#str+1]=k
        end
    end
    return str
end

function pythonWrapper.parseFuncsReturnTypes(nameSpace)
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

function pythonWrapper.handleRequest(req)
    local resp={}
    if req['func']~=nil and req['func']~='' then
        local func=pythonWrapper.getField(req['func'])
        local args=req['args'] or {}
        if not func then
            resp['error']='No such function: '..req['func']
        else
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
                local p=string.find(trace,"%[C%]: in function 'xpcall'")
                if p then
                    trace=trace:sub(1,p-3) -- strip traceback from xpcall on
                end
                -- Make sure the string survives the passage to Python unmodified:
                trace=string.gsub(trace,"\n","_=NL=_")
                trace=string.gsub(trace,"\t","_=TB=_")
                return trace
            end
            
            local savedStepping=stepping
            if callbackFunctions[func] then
                stepping=true
            end
            
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
            
            if callbackFunctions[func] then
                stepping=savedStepping
            end
           
            resp[status and 'ret' or 'error']=retvals
        end
    elseif req['eval']~=nil and req['eval']~='' then
        local status,retvals=pcall(function()
            -- cannot prefix 'return ' here, otherwise non-trivial code breaks
            -- local ret={loadstring('return '..req['eval'])()}
            local ret={loadstring(req['eval'])()}
            return ret
        end)
        resp[status and 'ret' or 'error']=retvals
    end
    resp['success']=resp['error']==nil
    return resp
end

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

function pythonWrapper.switchThreadIfNeeded()
    local r,l=getThreadAutomaticSwitch()
    if l-1==threadInitLockLevel then
        if not stepping then -- in stepping mode, switching is always explicit
            if threadSwitchTiming>0 then
                if not lastSwitchTime then
                    lastSwitchTime=sim.getSystemTime()
                end
                if sim.getSystemTime()-lastSwitchTime>=threadSwitchTiming then
                    sim.switchThread()
                    lastSwitchTime=sim.getSystemTime()
                end
            end
        end
    end
end

function pythonWrapper.callRemoteFunctionAndHandleQueue(callbackFunc,callbackArgs)
    -- Func is reentrant
    
    if pythonFuncs==nil or pythonFuncs[callbackFunc] or callbackFunc=="_*leave*_" then
        function handleRequestsUntilFuncExecuted()
            -- Handle requests from Python, until we get a _*executed*_ message
            while true do
                pythonWrapper.checkPythonError()
                local rc=simZMQ.poll({replySocket},{simZMQ.POLLIN},1000)
                if rc>0 then
                    local rc,req=simZMQ.recv(replySocket,0)
                    
                    -- Handle buffered callbacks:
                    if bufferedCallbacks and #bufferedCallbacks>0 then
                        local steppingSaved=stepping
                        stepping=true
                        local tmp=bufferedCallbacks
                        bufferedCallbacks={}
                        for i=1,#tmp,1 do
                            pythonWrapper.callRemoteFunctionAndHandleQueue(tmp[i].func,tmp[i].args)
                        end
                        stepping=steppingSaved
                    end
                    
                    local status,req=pcall(cborDecode.decode,req)
                    if not status then
                        error('CBOR decode error')
                    end
                    if req['func']=='_*executed*_' then
                        return req.args
                    end

                    -- in stepping mode switching is always explicit
                    --if stepping then
                    --    pythonWrapper.switchThreadIfNeeded()
                    --end
                    
                    local resp=pythonWrapper.handleRequest(req)
                    status,resp=pcall(sim.packCbor,resp)
                    if not status then
                        error('CBOR encode error')
                    end
                    simZMQ.send(replySocket,resp,0)

                    if not stepping then
                        while simZMQ.poll({replySocket},{simZMQ.POLLIN},0)<=0 do
                            pythonWrapper.switchThreadIfNeeded()
                        end
                    end
                end
            end
        end

        if not callRemoteFunctionAndHandleQueue_wasAlreadyCalled then
            callRemoteFunctionAndHandleQueue_wasAlreadyCalled=true
            handleRequestsUntilFuncExecuted()
        end
        
        pythonWrapper.checkPythonError()
        
        if pythonFuncs[callbackFunc] then -- when sysCall_init not present
            if stepping then
                -- First handle buffered callbacks:
                if bufferedCallbacks and #bufferedCallbacks>0 then
                    local tmp=bufferedCallbacks
                    bufferedCallbacks={}
                    for i=1,#tmp,1 do
                        pythonWrapper.callRemoteFunctionAndHandleQueue(tmp[i].func,tmp[i].args)
                    end
                end
            
                -- Tell Python to run a function:
                local status,resp=pcall(sim.packCbor,{func=callbackFunc,args=callbackArgs})
                if not status then
                    error('CBOR encode error')
                end
                simZMQ.send(replySocket,resp,0)
                
                if callbackFunc~='_*leave*_' then
                    ret=handleRequestsUntilFuncExecuted()
                    return ret
                end
            else
                if bufferedCallbacks==nil then
                    bufferedCallbacks={}
                end
                bufferedCallbacks[#bufferedCallbacks+1]={func=callbackFunc,args=callbackArgs}
                -- sim.addLog(sim.verbosity_scriptwarnings,"system callbacks to Python are suppressed while in free thread mode: "..callbackFunc)
            end
        end
    end
end

function pythonWrapper.checkPythonError()
    if subprocess then
        if simSubprocess.isRunning(subprocess) then
            local r,rep=simZMQ.__noError.recv(pySocket,simZMQ.DONTWAIT)
            if r>=0 then
                local rep,o,t=cborDecode.decode(rep)
                if rep.error then
                    local msg=pythonWrapper.getCleanErrorMsg(rep.error)
                    msg=msg..'__truncateStackFromHere__'
                    if not inCleanup then
                        callRemoteFunctionAndHandleQueue_wasAlreadyCalled=nil
                        simZMQ.send(pySocket,sim.packCbor({cmd='callFunc',func='__restartClientScript__',args={}}),0)
                    end
                    error(msg)
                end
            end
        end
    end
end

function pythonWrapper.getFreePortStr()
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

function pythonWrapper.initPython(prog)
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
        subprocess,controlPort=pythonWrapper.startPythonClientSubprocess(pyth)
        if controlPort then
            pyContext=simZMQ.ctx_new()
            pySocket=simZMQ.socket(pyContext,simZMQ.REQ)
            simZMQ.setsockopt(pySocket,simZMQ.LINGER,sim.packUInt32Table{0})
            simZMQ.connect(pySocket,controlPort)
            simZMQ.send(pySocket,sim.packCbor({cmd='loadCode',code=prog}),0)
            local st=sim.getSystemTime()
            local r,rep
            while sim.getSystemTime()-st<startTimeout do
                r,rep=simZMQ.__noError.recv(pySocket,simZMQ.DONTWAIT)
                if r>=0 then
                    break
                end
            end
            if r>=0 then
                local rep,o,t=cborDecode.decode(rep)
                if rep.success then
                    simZMQ.send(pySocket,sim.packCbor({cmd='callFunc',func='__startClientScript__',args={}}),0)
                else
                    errMsg=rep.error
                    errMsg=pythonWrapper.getCleanErrorMsg(errMsg)
                    if simSubprocess.isRunning(subprocess) then
                        simSubprocess.kill(subprocess)
                        subprocess=nil
                    end
                end
            else
                errMsg="The Python interpreter could not handle the wrapper script (or communication between the launched subprocess and CoppeliaSim could not be established via sockets). Make sure that the Python modules 'cbor' and 'zmq' are properly installed, e.g. via:\n$ /path/to/python -m pip install pyzmq\n$ /path/to/python -m pip install cbor. Additionally, you can try adjusting the value of startTimeout in lua/pythonWrapper.lua, at the top of the file"
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
        errMsg="The Python interpreter was not set. Specify it in "..usrSysLoc.."/usrset.txt with 'defaultPython', or via the named string parameter 'pythonWrapper.python' from the command line"
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

-- For Python, we should always return a string:
_S.readCustomDataBlock=sim.readCustomDataBlock
function sim.readCustomDataBlock(obj,tag)
    local retVal=_S.readCustomDataBlock(obj,tag)
    if retVal==nil then
        retVal=''
    end
    return retVal
end

function pythonWrapper.startPythonClientSubprocess(pythonExec)
    local subprocess,controlPort
    local data=sim.readCustomTableData(sim.handle_app,'pythonClients_idleSubprocesses')
    if #data>0 then
        -- Use an existing idle process
        subprocess=data[#data].subprocess
        controlPort=data[#data].controlPort
        table.remove(data)
        sim.writeCustomTableData(sim.handle_app,'pythonClients_idleSubprocesses',data)
    else
        controlPort=pythonWrapper.getFreePortStr()
        local res,ret=pcall(function()
            return simSubprocess.execAsync(pythonExec,{sim.getStringParam(sim.stringparam_pythondir)..'/pythonLauncher.py',controlPort},{useSearchPath=true,openNewConsole=false}) 
            end)
        if res then
            subprocess=ret
        else
            local usrSysLoc=sim.getStringParam(sim.stringparam_usersettingsdir) 
            subprocess="The Python interpreter could not be called. It is currently set at: '"..pythonExec.."'. You can specify it in "..usrSysLoc.."/usrset.txt with 'defaultPython', or via the named string parameter 'pythonWrapper.python' from the command line"
            controlPort=nil
        end
    end
    return subprocess,controlPort
end

function pythonWrapper.cleanupPython()
    if subprocess then
        if simSubprocess.isRunning(subprocess) then
            simSubprocess.kill(subprocess)
        end
    end
    if pySocket then
        simZMQ.close(pySocket)
        simZMQ.ctx_term(pyContext)
    end
end

function pythonWrapper.getCleanErrorMsg(inMsg)
    local msg=inMsg
    if msg and #msg>0 and not nakedErrors then
        msg=string.gsub(msg,"Exception: ","  Exception: ")
        msg=string.gsub(msg,"_=NL=_","\n")
        msg=string.gsub(msg,"_=TB=_","\t")
        local code=sim.getScriptStringParam(sim.handle_self,sim.scriptstringparam_text)
        local _,totLines=string.gsub(code,'\n','')
        totLines=totLines+1
        local toRemove={"[^\n]*rep%['ret'%] = func%(%*req%['args'%]%)[^\n]*\n","[^\n]*exec%(req%['code'%],module%)[^\n]*\n"}
        for i=1,#toRemove,1 do
            local p1,p2=string.find(msg,toRemove[i])
            if p1 then
                msg=string.sub(msg,1,p1-1)..string.sub(msg,p2+1)
            end
        end
        msg=string.gsub(msg,'File "<string>"','script')
        local p1=0,p2,p3
        while true do
            p2,p3=string.find(msg,'[^\n]*script, line %d+,[^\n]+\n',p1+1)
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
    end
    return msg
end

function loadExternalFile(file)
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
'''
import builtins
def sim_import(m):
    setattr(m, 'sim', '@SIM@')
    return m

builtins.__import__ = (lambda orig, f: lambda *args, **kwargs: f(orig(*args, **kwargs)))(builtins.__import__, sim_import)
'''

XXXadditionalPathsXXX

def b64(b):
    import base64
    return base64.b64encode(b).decode('ascii')

class LazyProxyObj:
    def __init__(self, client, name):
        self.client, self.name, self.obj = client, name, None
    def __getattr__(self, k):
        if not self.obj:
            self.obj = self.client.getObject(self.name)
        return getattr(self.obj, k)

class RemoteAPIClient:
    """Client to connect to CoppeliaSim's ZMQ Remote API."""

    def __init__(self):
        self.context = zmq.Context()
        self.socket = self.context.socket(zmq.REQ)
        self.socket.connect(f'XXXconnectionAddress1XXX')

    def __del__(self):
        """Disconnect and destroy client."""
        self.socket.close()
        self.context.term()

    def _send(self, req):
        # convert a possible function to string:
        if 'args' in req and req['args']!=None:
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
        if not resp.get('success', False):
            raise Exception(resp.get('error'))
        ret = resp['ret']
        if len(ret) == 1:
            return ret[0]
        if len(ret) > 1:
            return tuple(ret)

    def call(self, func, args):
        """Call function with specified arguments. Is reentrant."""
        if func=='_*executed*_':
            args=[]
            while True:
                self._send({'func': '_*executed*_', 'args': args})
                reply = self._recv()
                if reply['func']=='_*leave*_':
                    return
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
            return self._process_response(reply)

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
         
    def require(self, name):
        self.call('pythonWrapper.require', [name])
        ret = self.getObject(name)
        allApiFuncs = client.call('pythonWrapper.getApi', [name])
        for a in allApiFuncs:
            globals()[a] = LazyProxyObj(client,a)
        return ret         

def _getFuncIfExists(name):
    method=None
    try:
        method=globals()[name]
        #method=getattr(sys.modules[__name__],name)
    except BaseException as err:
        pass
    return method

def require(a):
    return client.require(a)
    
def print(a):
    client.call('pythonWrapper.print', [str(a)])
    
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
    client.call('pythonWrapper.pythonFuncs', [allFuncs])
    #sys.settrace(trace_function)
    client.call('_*executed*_', [])
    
def __restartClientScript__():
    client.call('_*executed*_', [])
]=]
