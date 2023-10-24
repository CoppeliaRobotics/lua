startTimeout = 2
sim = require('sim') -- keep here, since we have several sim-functions defined/redefined here
simZMQ = require('simZMQ')
simSubprocess = require('simSubprocess')
cbor = require 'org.conman.cbor'
removeLazyLoaders()

function sim.setThreadSwitchTiming(switchTiming)
    -- Shadow the original func
    -- 0=disabled, otherwise switchTiming
    threadSwitchTiming = switchTiming
end

function sim.setThreadAutomaticSwitch()
    -- Shadow the original function
end

originalSetStepping = sim.setStepping
function sim.setStepping(enabled)
    -- Shadow original function:
    -- When stepping is true, CoppeliaSim ALWAYS blocks while Python runs some code
    -- When stepping is false, CoppeliaSim run concurently to Python, i.e. Python is "free" (until a request from Python comes)
    local retVal = 0
    if currentFunction == sim.setStepping then
        if pythonFuncs['sysCall_thread'] then
            retVal = steppingLevel
            if enabled then
                steppingLevel = steppingLevel + 1
            else
                if steppingLevel > 0 then steppingLevel = steppingLevel - 1 end
            end
        end
    else
        retVal = originalSetStepping(enabled)
    end
    return retVal
end

originalAcquireLock = sim.acquireLock
function sim.acquireLock()
    if currentFunction == sim.acquireLock then
        holdCalls = holdCalls + 1
    else
        originalAcquireLock()
    end
end

originalReleaseLock = sim.releaseLock
function sim.releaseLock()
    if currentFunction == sim.releaseLock then
        if holdCalls > 0 then holdCalls = holdCalls - 1 end
    else
        originalReleaseLock()
    end
end

-- Special handling of sim.yield:
originalYield = sim.yield
function sim.yield()
    if sim.getSimulationState() == sim.simulation_stopped then
        originalYield()
    else
        local st = sim.getSimulationTime()
        while sim.getSimulationTime() == st do
            -- stays inside here until we are ready with next simulation step. This is important since
            -- other clients/scripts could too be hindering the main script to run in sysCall_beforeMainScript
            originalYield()
        end
    end
end

function sim.step()
    -- Shadow original function:
    sim.yield()
end

function sim.switchThread()
    -- Shadow original function:
    sim.yield()
end

function sim.protectedCalls(enable)
    protectedCalls = enable
end

function yieldIfAllowed()
    local retVal = false
    if holdCalls == 0 and doNotInterruptCommLevel == 0 and steppingLevel == 0 then
        originalYield()
        retVal = true
    end
    return retVal
end

function tobin(data)
    local d = {data = data}
    setmetatable(
        d, {
            __tocbor = function(self)
                return cbor.TYPE.BIN(self.data)
            end,
        }
    )
    return d
end

function totxt(data)
    local d = {data = data}
    setmetatable(
        d, {
            __tocbor = function(self)
                return cbor.TYPE.TEXT(self.data)
            end,
        }
    )
    return d
end

function toarray(data)
    local d = {data = data}
    setmetatable(
        d, {
            __tocbor = function(self)
                return cbor.TYPE.ARRAY(self.data)
            end,
        }
    )
    return d
end

function tomap(data)
    local d = {data = data}
    setmetatable(
        d, {
            __tocbor = function(self)
                return cbor.TYPE.MAP(self.data)
            end,
        }
    )
    return d
end

function sysCall_init(...)
    returnTypes = {}
    simZMQ.__raiseErrors(true) -- so we don't need to check retval with every call

    context = simZMQ.ctx_new()
    replySocket = simZMQ.socket(context, simZMQ.REP)
    replyPortStr = getFreePortStr()
    simZMQ.bind(replySocket, replyPortStr)

    local prog = pythonBoilerplate .. pythonUserCode
    prog = prog:gsub("XXXconnectionAddress1XXX", replyPortStr)
    local tmp = ''
    if _additionalPaths then
        for i = 1, #_additionalPaths, 1 do
            tmp = tmp .. 'sys.path.append("' .. _additionalPaths[i] .. '")\n'
        end
    end
    if additionalPaths then
        for i = 1, #additionalPaths, 1 do
            tmp = tmp .. 'sys.path.append("' .. additionalPaths[i] .. '")\n'
        end
    end
    prog = prog:gsub("XXXadditionalPathsXXX", tmp)

    initPython(prog)

    local optionalSysCallbacks = {
        'sysCall_beforeMainScript', 'sysCall_suspended', 'sysCall_beforeSimulation',
        'sysCall_afterSimulation', 'sysCall_sensing', 'sysCall_suspend', 'sysCall_resume',
        'sysCall_realTimeIdle', 'sysCall_beforeInstanceSwitch', 'sysCall_afterInstanceSwitch',
        'sysCall_beforeSave', 'sysCall_afterSave', 'sysCall_beforeCopy', 'sysCall_afterCopy',
        'sysCall_afterCreate', 'sysCall_beforeDelete', 'sysCall_afterDelete',
        'sysCall_addOnScriptSuspend', 'sysCall_addOnScriptResume', 'sysCall_dyn', 'sysCall_joint',
        'sysCall_contact', 'sysCall_vision', 'sysCall_trigger', 'sysCall_moduleEntry',
        'sysCall_msg', 'sysCall_event',
    }

    if subprocess then
        _pythonRunning = true
        pythonCallbacks = {pythonCallback1, pythonCallback2, pythonCallback3}
        pythonCallbackStrs = {'', '', ''}

        corout = coroutine.create(coroutineMain)
        setAutoYield(false)
        threadSwitchTiming = 0.002 -- time given to service Python scripts
        threadLastSwitchTime = 0
        threadBusyCnt = 0
        steppingLevel = 0 -- in stepping mode switching is always explicit
        protectedCallErrorDepth = 0
        protectedCallDepth = 0
        pythonMustHaveRaisedError = false
        receiveIsNext = true
        holdCalls = 0
        doNotInterruptCommLevel = 0

        handleRequestsUntilExecutedReceived() -- handle commands from Python prior to start, e.g. initial function calls to CoppeliaSim

        -- Disable optional system callbacks that are not used on Python side (nonSimulation, init, actuation, cleanup, ext and userConfig are special):
        for i = 1, #optionalSysCallbacks, 1 do
            local nm = optionalSysCallbacks[i]
            if pythonFuncs[nm] == nil then _G[nm] = nil end
        end

        if pythonFuncs['sysCall_userConfig'] then
            sysCall_userConfig = _sysCall_userConfig -- special
        end

        if pythonFuncs["sysCall_init"] == nil and pythonFuncs["sysCall_thread"] == nil then
            error("can't find sysCall_init nor sysCall_thread functions")
        end

        auxFunc('stts', 'pythonEmbeddedScript')

        return callRemoteFunction("sysCall_init", {...})
    else
        -- Failed initializing Python. And since we have not generated an error, we disable most funcs (want to continue with Lua only)
        for i = 1, #optionalSysCallbacks, 1 do
            local nm = optionalSysCallbacks[i]
            _G[nm] = nil
        end
        sysCall_userConfig = nil
    end
end

function sysCall_cleanup(...)
    if subprocess ~= nil then
        inCleanup = true
        callRemoteFunction("sysCall_cleanup", {...})
    end

    cleanupPython()
    simZMQ.close(replySocket)
    simZMQ.ctx_term(context)
end

function coroutineMain()
    callRemoteFunction("sysCall_thread", {})
end

function sysCall_ext(funcName, ...)
    local args = {...}
    local lang = -1 -- undef

    if funcName:sub(-4) == '@lua' then
        lang = 0
        funcName = funcName:sub(1, -4 - 1)
    elseif funcName:sub(-7) == '@python' then
        lang = 1
        funcName = funcName:sub(1, -7 - 1)
    end

    if lang == 1 or lang == -1 then -- Python takes precedence on Lua, if lang not specified
        -- Python
        if subprocess then
            if pythonFuncs['sysCall_ext'] then
                return callRemoteFunction('sysCall_ext', {funcName, args})
            else
                if pythonFuncs[funcName] then
                    return callRemoteFunction(funcName, args, true, false)
                end
            end
        end
    end

    if lang == 0 or lang == -1 then
        -- Lua
        local f = _G
        if string.find(funcName, "%.") then
            for w in funcName:gmatch("[^%.]+") do -- handle cases like sim.func or similar too
                if f[w] then f = f[w] end
            end
        else
            f = f[funcName]
        end
        if type(f) == 'function' then
            local status, retvals = pcall(f, table.unpack(args))
            if status == false then
                return "_*runtimeError*_" -- ..retVals
            else
                return retvals
            end
        end
    end

    return "_*funcNotFound*_"
end

function resumeCoroutine()
    if coroutine.status(corout) ~= 'dead' then
        protectedCallDepth = protectedCallDepth + 1
        local ok, errorMsg = coroutine.resume(corout)
        protectedCallDepth = protectedCallDepth - 1
        if errorMsg then
            error(debug.traceback(corout, errorMsg), 2) -- this error is very certainly linked to the Python wrapper itself
        end
        checkPythonError()
    end
end

function sysCall_nonSimulation(...)
    if subprocess then
        if pythonFuncs['sysCall_thread'] then resumeCoroutine() end
        return callRemoteFunction("sysCall_nonSimulation", {...})
    end
end

function sysCall_actuation(...)
    if subprocess then
        if pythonFuncs['sysCall_thread'] then resumeCoroutine() end
        return callRemoteFunction("sysCall_actuation", {...})
    end
end

function sysCall_beforeMainScript(...)
    return callRemoteFunction("sysCall_beforeMainScript", {...})
end

function sysCall_suspended(...)
    return callRemoteFunction("sysCall_suspended", {...})
end

function sysCall_sensing(...)
    return callRemoteFunction("sysCall_sensing", {...})
end

function sysCall_beforeSimulation(...)
    return callRemoteFunction("sysCall_beforeSimulation", {...})
end

function sysCall_afterSimulation(...)
    return callRemoteFunction("sysCall_afterSimulation", {...})
end

function sysCall_suspend(...)
    return callRemoteFunction("sysCall_suspend", {...})
end

function sysCall_resume(...)
    return callRemoteFunction("sysCall_resume", {...})
end

function sysCall_realTimeIdle(...)
    return callRemoteFunction("sysCall_realTimeIdle", {...})
end

function sysCall_beforeInstanceSwitch(...)
    return callRemoteFunction("sysCall_beforeInstanceSwitch", {...})
end

function sysCall_afterInstanceSwitch(...)
    return callRemoteFunction("sysCall_afterInstanceSwitch", {...})
end

function sysCall_beforeSave(...)
    return callRemoteFunction("sysCall_beforeSave", {...})
end

function sysCall_afterSave(...)
    return callRemoteFunction("sysCall_afterSave", {...})
end

function sysCall_beforeCopy(...)
    return callRemoteFunction("sysCall_beforeCopy", {...})
end

function sysCall_afterCopy(...)
    return callRemoteFunction("sysCall_afterCopy", {...})
end

function sysCall_afterCreate(...)
    return callRemoteFunction("sysCall_afterCreate", {...})
end

function sysCall_beforeDelete(...)
    return callRemoteFunction("sysCall_beforeDelete", {...})
end

function sysCall_afterDelete(...)
    return callRemoteFunction("sysCall_afterDelete", {...})
end

function sysCall_addOnScriptSuspend(...)
    return callRemoteFunction("sysCall_addOnScriptSuspend", {...})
end

function sysCall_addOnScriptResume(...)
    return callRemoteFunction("sysCall_addOnScriptResume", {...})
end

if dynCallback then
    -- Needs to be explicitly enabled (drastic slowdown)
    function sysCall_dyn(...)
        return callRemoteFunction("sysCall_dyn", {...})
    end
end

function sysCall_joint(...)
    return callRemoteFunction("sysCall_joint", {...})
end

if contactCallback then
    -- Needs to be explicitly enabled (drastic slowdown)
    function sysCall_contact(...)
        return callRemoteFunction("sysCall_contact", {...})
    end
end

function sysCall_vision(...)
    return callRemoteFunction("sysCall_vision", {...})
end

function sysCall_trigger(...)
    return callRemoteFunction("sysCall_trigger", {...})
end

function _sysCall_userConfig(...) -- special
    return callRemoteFunction("sysCall_userConfig", {...})
end

function sysCall_moduleEntry(...)
    return callRemoteFunction("sysCall_moduleEntry", {...})
end

function sysCall_msg(...)
    return callRemoteFunction("sysCall_msg", {...})
end

if eventCallback then
    -- Needs to be explicitly enabled (drastic slowdown)
    function sysCall_event(...)
        return callRemoteFunction("sysCall_event", {...})
    end
end

function pythonCallback1(...)
    return callRemoteFunction(pythonCallbackStrs[1], {...}, false, true)
end

function pythonCallback2(...)
    return callRemoteFunction(pythonCallbackStrs[2], {...}, false, true)
end

function pythonCallback3(...)
    return callRemoteFunction(pythonCallbackStrs[3], {...}, false, true)
end

function sim.testCB(a, cb, b)
    for i = 1, 99, 1 do cb(a, b) end
    return cb(a, b)
end

function __require__(name)
    _G[name] = require(name)
    parseFuncsReturnTypes(name)
end

function setPythonFuncs(data)
    pythonFuncs = data
end

function __print__(str)
    print(str)
end

function pyTr() -- Dummy function called by Python trace on a regular basis if in freeMode and no interaction with CoppeliaSim since a while - Allows for callbacks to be sent
end

function __getApi__(nameSpace)
    str = {}
    for k, v in pairs(_G) do
        if type(v) == 'table' and k:find(nameSpace, 1, true) == 1 then str[#str + 1] = k end
    end
    return str
end

function parseFuncsReturnTypes(nameSpace)
    local funcs = sim.getApiFunc(-1, '+' .. nameSpace .. '.')
    for i = 1, #funcs, 1 do
        local func = funcs[i]
        local inf = sim.getApiInfo(-1, func)
        local p = string.find(inf, '(', 1, true)
        if p then
            inf = string.sub(inf, 1, p - 1)
            p = string.find(inf, '=')
            if p then
                inf = string.sub(inf, 1, p - 1)
                local t = {}
                local i = 1
                for token in (inf .. ","):gmatch("([^,]*),") do
                    p = string.find(token, ' ')
                    if p then
                        token = string.sub(token, 1, p - 1)
                        if token == 'string' then
                            t[i] = 1
                        elseif token == 'buffer' then
                            t[i] = 2
                        elseif token == 'map' then
                            t[i] = 3
                        else
                            t[i] = 0
                        end
                    else
                        t[i] = 0
                    end
                    i = i + 1
                end
                returnTypes[func] = t
            else
                returnTypes[func] = {}
            end
        end
    end
end

function handleRequest(req)
    local resp = {}
    if req['func'] ~= nil and req['func'] ~= '' then
        local func = _getField(req['func'])
        local args = req['args'] or {}
        if not func then
            if not protectedCalls then
                pythonMustHaveRaisedError = true -- actually not just yet, we still need to send a reply tp Python
            end
            resp['err'] = 'No such function: ' .. req['func']
        else
            if func == sim.setThreadAutomaticSwitch then
                -- For backward compatibility with pythonWrapperV1
                func = sim.setStepping
                if #args > 0 then
                    if not isnumber(args[1]) then args[1] = not args[1] end
                end
            end

            currentFunction = func

            -- Handle function arguments:
            local cbi = 1
            for i = 1, #args, 1 do
                if type(args[i]) == 'string' then
                    if args[i]:sub(-5) == "@func" then
                        local nm = args[i]:sub(1, -6)
                        args[i] = pythonCallbacks[cbi]
                        pythonCallbackStrs[cbi] = nm
                        cbi = cbi + 1
                    end
                end
            end

            local function errHandler(err)
                local trace = debug.traceback(err)
                local p = string.find(trace, "\nstack traceback:")
                if p then
                    trace = trace:sub(1, p - 1) -- strip traceback from xpcall
                end
                -- Make sure the string survives the passage to Python unmodified:
                trace = string.gsub(trace, "\n", "_=NL=_")
                trace = string.gsub(trace, "\t", "_=TB=_")
                return trace
            end

            protectedCallDepth = protectedCallDepth + 1
            doNotInterruptCommLevel = doNotInterruptCommLevel + 1
            local status, retvals = xpcall(
                                        function()
                    local ret = {func(unpack(args, 1, req.argsL))}
                    -- Try to assign correct types to text/buffers and arrays/maps:
                    local args = returnTypes[req['func']]
                    if args then
                        local cnt = math.min(#ret, #args)
                        for i = 1, cnt, 1 do
                            if args[i] == 1 then
                                ret[i] = totxt(ret[i])
                            elseif args[i] == 2 then
                                ret[i] = tobin(ret[i])
                            else
                                if type(ret[i]) == 'table' and next(ret[i]) == nil then
                                    if args[i] == 3 then
                                        ret[i] = tomap(ret[i])
                                    else
                                        ret[i] = toarray(ret[i])
                                    end
                                end
                            end
                        end
                    end
                    return ret
                end, errHandler
                                    )
            doNotInterruptCommLevel = doNotInterruptCommLevel - 1
            protectedCallDepth = protectedCallDepth - 1

            if status == false then
                if not protectedCalls then
                    pythonMustHaveRaisedError = true -- actually not just yet, we still need to send a reply tp Python
                end
            end
            resp[status and 'ret' or 'err'] = retvals
        end
        currentFunction = nil
    elseif req['eval'] ~= nil and req['eval'] ~= '' then
        local status, retvals = pcall(
                                    function()
                -- cannot prefix 'return ' here, otherwise non-trivial code breaks
                -- local ret={loadstring('return '..req['eval'])()}
                local ret = {loadstring(req['eval'])()}
                return ret
            end
                                )
        if status == false then
            if not protectedCalls then
                pythonMustHaveRaisedError = true -- actually not just yet, we still need to send a reply tp Python
            end
        end
        resp[status and 'ret' or 'err'] = retvals
    end
    return resp
end

function __info__(obj)
    if type(obj) == 'string' then obj = _getField(obj) end
    if type(obj) ~= 'table' then return obj end
    local ret = {}
    for k, v in pairs(obj) do
        if type(v) == 'table' then
            ret[k] = __info__(v)
        elseif type(v) == 'function' then
            ret[k] = {func = {}}
        elseif type(v) ~= 'function' then
            ret[k] = {const = v}
        end
    end
    return ret
end

function _getField(f)
    local v = _G
    for w in string.gmatch(f, '[%w_]+') do
        v = v[w]
        if not v then return nil end
    end
    return v
end

function receive()
    -- blocking, but can switch thread
    if receiveIsNext then
        while simZMQ.poll({replySocket}, {simZMQ.POLLIN}, 0) <= 0 do
            if threadSwitchTiming > 0 then
                if sim.getSystemTime() - threadLastSwitchTime >= threadSwitchTiming or threadBusyCnt ==
                    0 then
                    if checkPythonError() then
                        return -- unwind xpcalls
                    end
                    yieldIfAllowed()
                    -- We still want to set following if not yielded:
                    threadLastSwitchTime = sim.getSystemTime()
                    threadBusyCnt = 0 -- after a switch, if the socket is idle, we switch immediately again. Otherwise we wait max. threadSwitchTiming
                end
            end
        end
        threadBusyCnt = threadBusyCnt + 1

        local rc, dat = simZMQ.recv(replySocket, 0)
        receiveIsNext = false
        local status, req = pcall(cbor.decode, dat)
        if not status then
            error(req .. "\n" .. sim.transformBuffer(dat, sim.buffer_uint8, 1, 0, sim.buffer_base64))
        end

        -- Handle non-serializable data:
        if req.args and (type(req.args) == 'string') and req.args:match('^_%*baddata%*_') then
            req.args = string.gsub(req.args, '_%*baddata%*_', '')
            sim.addLog(sim.verbosity_warnings, "Received non-serializable data: " .. req.args)
        end

        return req
    else
        error('Trying to receive data from Python where a send is expected')
    end
end

function send(reply)
    if not receiveIsNext then
        local dat = reply
        status, reply = pcall(cbor.encode, reply)
        if not status then error(reply .. "\n" .. getAsString(dat)) end
        simZMQ.send(replySocket, reply, 0)
        receiveIsNext = true
    else
        error('Trying to send data to Python where a receive is expected')
    end
end

function handleRequestsUntilExecutedReceived()
    -- Handle requests from Python, until we get a _*executed*_ message. Func is reentrant
    while true do
        local req = receive() -- blocking (but can switch thread (i.e. happens only with sysCall_thread))

        if req == nil then
            return -- unwind xpcalls
        end

        -- Handle buffered callbacks:
        if bufferedCallbacks and #bufferedCallbacks > 0 then
            local tmp = bufferedCallbacks
            bufferedCallbacks = {}
            for i = 1, #tmp, 1 do
                callRemoteFunction(tmp[i].func, tmp[i].args)
                if checkPythonError() then
                    return -- unwind xpcalls
                end
            end
        end

        if req['func'] == '_*executed*_' then return req.args end

        -- print(req)
        local resp = handleRequest(req)

        if pythonMustHaveRaisedError then
            if protectedCallErrorDepth == 0 then send(resp) end
            protectedCallErrorDepth = protectedCallErrorDepth - 1
        else
            if checkPythonError() then
                return -- unwind xpcalls
            end
            send(resp)
        end
    end
end

function callRemoteFunction(callbackFunc, callbackArgs, canCallAsync, possiblyLocalFunction)
    -- Func is reentrant
    local retVal
    if checkPythonError() then
        return -- unwind xpcalls
    end

    if pythonFuncs and pythonFuncs[callbackFunc] or possiblyLocalFunction then
        if not receiveIsNext then
            -- First handle buffered, async callbacks:
            if bufferedCallbacks and #bufferedCallbacks > 0 then
                local tmp = bufferedCallbacks
                bufferedCallbacks = {}
                for i = 1, #tmp, 1 do
                    callRemoteFunction(tmp[i].func, tmp[i].args)
                    if checkPythonError() then
                        return -- unwind xpcalls
                    end
                end
            end

            -- Tell Python to run a function:
            if callbackFunc ~= 'sysCall_thread' then
                doNotInterruptCommLevel = doNotInterruptCommLevel + 1
            end
            send({func = callbackFunc, args = callbackArgs})

            -- Wait for the reply from Python
            retVal = handleRequestsUntilExecutedReceived()
            if callbackFunc ~= 'sysCall_thread' then
                doNotInterruptCommLevel = doNotInterruptCommLevel - 1
            end
        else
            if canCallAsync then
                if bufferedCallbacks == nil then bufferedCallbacks = {} end
                bufferedCallbacks[#bufferedCallbacks + 1] = {
                    func = callbackFunc,
                    args = callbackArgs,
                }
            end
        end
    end
    return retVal
end

function checkPythonError()
    if subprocess then
        if simSubprocess.isRunning(subprocess) then
            while pythonErrorMsg == nil do
                local r, rep = simZMQ.__noError.recv(pySocket, simZMQ.DONTWAIT)
                if r >= 0 then
                    local rep, o, t = cbor.decode(rep)
                    if rep.err then
                        -- print(getAsString(rep.err))
                        local msg = getCleanErrorMsg(rep.err)
                        msg = '__[[__' .. msg .. '__]]__'
                        -- print(getAsString(msg))
                        pythonErrorMsg = msg
                    end
                else
                    if not pythonMustHaveRaisedError then -- pythonMustHaveRaisedError: the error happened here and was transmitted to Python to raise an error there
                        break
                    end
                end
            end

            if pythonErrorMsg then
                if protectedCallDepth == 0 then
                    local errMsg = pythonErrorMsg
                    if not inCleanup then
                        simZMQ.close(replySocket)
                        replySocket = simZMQ.socket(context, simZMQ.REP)
                        simZMQ.bind(replySocket, replyPortStr)
                        pythonErrorMsg = nil
                        protectedCallDepth = 0
                        protectedCallErrorDepth = 0
                        pythonMustHaveRaisedError = false
                        steppingLevel = 0
                        holdCalls = 0
                        doNotInterruptCommLevel = 0
                        receiveIsNext = true
                        simZMQ.send(
                            pySocket, cbor.encode(
                                {cmd = 'callFunc', func = '__restartClientScript__', args = {}}
                            ), 0
                        )
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
    local tmpContext = simZMQ.ctx_new()
    local tmpSocket = simZMQ.socket(tmpContext, simZMQ.REP)
    local p = 23259
    while true do
        if simZMQ.__noError.bind(tmpSocket, string.format('tcp://127.0.0.1:%d', p)) == 0 then
            break
        end
        p = p + 1
    end
    simZMQ.close(tmpSocket)
    simZMQ.ctx_term(tmpContext)
    return string.format('tcp://127.0.0.1:%d', p)
end

function initPython(prog)
    local pyth = sim.getStringParam(sim.stringparam_defaultpython)
    local pyth2 = sim.getNamedStringParam("python")
    if pyth2 then pyth = pyth2 end
    if pyth == nil or #pyth == 0 then
        local p = sim.getInt32Param(sim.intparam_platform)
        if p == 0 then
            pyth = 'py'
        else
            pyth = 'python3'
        end
    end
    local errMsg
    if pyth and #pyth > 0 then
        subprocess, controlPort = startPythonClientSubprocess(pyth)
        if controlPort then
            pyContext = simZMQ.ctx_new()
            pySocket = simZMQ.socket(pyContext, simZMQ.REQ)
            simZMQ.setsockopt(pySocket, simZMQ.LINGER, sim.packUInt32Table {0})
            simZMQ.connect(pySocket, controlPort)
            virtualPythonFilename = sim.getStringParam(sim.stringparam_scene_path_and_name)
            if virtualPythonFilename == '' then
                virtualPythonFilename = 'CoppeliaSim_newScene'
            else
                virtualPythonFilename = 'CoppeliaSim_' .. virtualPythonFilename
            end
            virtualPythonFilename = virtualPythonFilename .. '_' ..
                                        tostring(sim.getInt32Param(sim.intparam_scene_unique_id))
            virtualPythonFilename = virtualPythonFilename ..
                                        sim.getScriptStringParam(
                                            sim.handle_self, sim.scriptstringparam_nameext
                                        )
            if sim.getInt32Param(sim.intparam_platform) == 0 then
                virtualPythonFilename = "z:\\" .. virtualPythonFilename
            else
                virtualPythonFilename = "//" .. virtualPythonFilename
            end
            virtualPythonFilename = virtualPythonFilename ..
                                        tostring(simSubprocess.getpid(subprocess)) .. ".py"
            simZMQ.send(
                pySocket,
                cbor.encode({cmd = 'loadCode', code = prog, info = virtualPythonFilename}), 0
            )
            local st = sim.getSystemTime()
            local r, rep
            while sim.getSystemTime() - st < startTimeout or simSubprocess.isRunning(subprocess) do
                simSubprocess.wait(subprocess, 0.1)
                r, rep = simZMQ.__noError.recv(pySocket, simZMQ.DONTWAIT)
                if r >= 0 then break end
            end
            if r >= 0 then
                local rep, o, t = cbor.decode(rep)
                if rep.err then
                    errMsg = rep.err
                    errMsg = getCleanErrorMsg(errMsg)
                    simSubprocess.wait(subprocess, 0.1)
                    if simSubprocess.isRunning(subprocess) then
                        simSubprocess.kill(subprocess)
                    end
                    subprocess = nil
                else
                    simZMQ.send(
                        pySocket,
                        cbor.encode({cmd = 'callFunc', func = '__startClientScript__', args = {}}),
                        0
                    )
                end
            else
                errMsg =
                    "The Python interpreter could not handle the wrapper script (or communication between the launched subprocess and CoppeliaSim could not be established via sockets). Make sure that the Python modules 'cbor' and 'zmq' are properly installed, e.g. via: $ "
                errMsg = errMsg .. pyth ..
                             " -m pip install pyzmq cbor. Additionally, you can try adjusting the value of startTimeout in lua/pythonWrapperV2.lua, at the top of the file"
                simSubprocess.wait(subprocess, 0.1)
                if simSubprocess.isRunning(subprocess) then
                    simSubprocess.kill(subprocess)
                end
                subprocess = nil
            end
        else
            errMsg = subprocess
            subprocess = nil
        end
    else
        local usrSysLoc = sim.getStringParam(sim.stringparam_usersettingsdir)
        errMsg = "The Python interpreter was not set. Specify it in " .. usrSysLoc ..
                     "/usrset.txt with 'defaultPython', or via the named string parameter 'python' from the command line"
    end
    if errMsg then
        if sim.getScriptInt32Param(sim.handle_self, sim.scriptintparam_type) ==
            sim.scripttype_sandboxscript then
            sim.setNamedBoolParam("pythonSandboxInitFailed", true)
        end
        if pythonFailWarnOnly then
            sim.setNamedStringParam("pythonSandboxInitFailMsg", errMsg)
            sim.addLog(sim.verbosity_scripterrors, errMsg)
        else
            error('__[[__' .. errMsg .. '__]]__')
        end
    end
end

-- For Python, we should always return a string:
_S.readCustomDataBlock = sim.readCustomDataBlock
function sim.readCustomDataBlock(obj, tag)
    local retVal = _S.readCustomDataBlock(obj, tag)
    if retVal == nil then retVal = '' end
    return retVal
end

function startPythonClientSubprocess(pythonExec)
    local subprocess
    local controlPort = getFreePortStr()
    local res, ret = pcall(
                         function()
            return simSubprocess.execAsync(
                       pythonExec, {
                    sim.getStringParam(sim.stringparam_pythondir) .. '/pythonLauncher.py',
                    controlPort,
                }, {useSearchPath = true, openNewConsole = false}
                   )
        end
                     )
    if res then
        subprocess = ret
    else
        local usrSysLoc = sim.getStringParam(sim.stringparam_usersettingsdir)
        subprocess = "The Python interpreter could not be called. It is currently set as: '" ..
                         pythonExec .. "'. You can specify it in " .. usrSysLoc ..
                         "/usrset.txt with 'defaultPython', or via the named string parameter 'python' from the command line"
        controlPort = nil
    end
    return subprocess, controlPort
end

function cleanupPython()
    if subprocess then
        simSubprocess.wait(subprocess, 0.1)
        if simSubprocess.isRunning(subprocess) then simSubprocess.kill(subprocess) end
    end
    if pySocket then
        simZMQ.close(pySocket)
        simZMQ.ctx_term(pyContext)
    end
end

function getCleanErrorMsg(inMsg)
    local msg = inMsg
    if msg and #msg > 0 and not nakedErrors then
        msg = string.gsub(msg, "_=NL=_", "\n")
        msg = string.gsub(msg, "_=TB=_", "\t")
        local tg = "#__EXCEPTION__\n"
        local p = string.find(msg, tg)
        if p then
            msg = msg:sub(p + #tg)
            msg = "Traceback (most recent call last):\n" .. msg
        end
        local _, boilerplateLines = string.gsub(pythonBoilerplate, '\n', '')
        local _, userCodeLines = string.gsub(pythonUserCode, '\n', '')
        userCodeLines = userCodeLines + 1
        local p1 = 0, p2, p3
        local tstr = '@_script_@'
        local sstr = 'File "' .. virtualPythonFilename .. '"'
        function escapePattern(str)
            return string.gsub(str, "([%^%$%(%)%%%.%[%]%*%+%-%?%:])", "%%%1")
        end
        msg = string.gsub(msg, escapePattern(sstr), tstr)
        while true do
            p2, p3 = string.find(msg, '[^\n]*@_script_@, line %d+[^\n]*\n', p1 + 1)
            if p2 then
                local sn, en = string.find(msg, '%d+', p2)
                local lineNb = tonumber(string.sub(msg, sn, en))
                if lineNb <= boilerplateLines then
                    -- Relates to boiler plate lines
                    msg = string.sub(msg, 1, p2 - 1) .. string.sub(msg, p3 + 1)
                    --[[
                    local sp, ep = string.find(msg, "@_script_@", p2)
                    if sp then
                        msg = msg:sub(1, sp-1) .. "boilerplatescript" .. msg:sub(ep+1)
                    end
                    p1=sn
                    --]]
                elseif lineNb <= boilerplateLines + userCodeLines then
                    -- Relates to user code lines
                    local off = 0
                    if externalFile then off = -1 end
                    msg = msg:sub(1, sn - 1) .. tostring(lineNb - boilerplateLines + off) ..
                              msg:sub(en + 1)
                    p1 = sn
                else
                    -- Relates to other code lines
                    msg = string.sub(msg, 1, p2 - 1) .. string.sub(msg, p3 + 1)
                    -- p1=sn
                end
            else
                break
            end
        end
        if externalFile then
            msg = string.gsub(msg, tstr, 'File "' .. externalFile .. '"')
        else
            msg = string.gsub(msg, tstr, 'script')
        end
        msg = string.gsub(msg, "Exception: %d+:", "Exception")
    end
    return msg
end

function loadExternalFile(file)
    externalFile = file
    local f
    local absPath
    if sim.getInt32Param(sim.intparam_platform) == 0 then
        absPath = ((file:sub(1, 1) == '/') or (file:sub(1, 1) == '\\') or (file:sub(2, 2) == ':'))
    else
        absPath = (file:sub(1, 1) == '/')
    end
    if absPath then
        f = io.open(file, 'rb')
    else
        local b = {
            sim.getStringParam(sim.stringparam_application_path),
            sim.getStringParam(sim.stringparam_application_path) .. '/python',
            sim.getStringParam(sim.stringparam_scene_path),
            sim.getStringParam(sim.stringparam_additionalpythonpath),
        }
        if additionalIncludePaths and #additionalIncludePaths > 0 then
            for i = 1, #additionalIncludePaths, 1 do
                b[#b + 1] = additionalIncludePaths[i]
            end
        end
        for i = 1, #b, 1 do
            if b[i] ~= '' then
                f = io.open(b[i] .. '/' .. file, 'rb')
                if f then
                    file = b[i] .. '/' .. file
                    break
                end
            end
        end
    end
    if f == nil then error("include file '" .. file .. "' not found") end
    if not pythonUserCode then pythonUserCode = '' end
    pythonUserCode = f:read('*all') .. pythonUserCode
    f:close()
    while #file > 0 do
        local c = file:sub(#file, #file)
        if c ~= '/' and c ~= '\\' then
            file = file:sub(1, #file - 1)
        else
            break
        end
    end
    _additionalPaths = {file}
end

pythonBoilerplate = [=[

import time
import sys
import os
import cbor
import zmq
import re

XXXadditionalPathsXXX


class RemoteAPIMethod:
    def __init__(self, client, obj, met):
        self.client = client
        self.obj = obj
        self.met = met

    def __str__(self):
        return f'{self.obj}.{self.met}'

    def __repr__(self):
        return f'<{self.__class__.__name__} {self!s}>'

    def __call__(self, *args):
        return self.client.call(str(self), args)

    def __getattribute__(self, k):
        if k == '__doc__':
            return self.client.call('sim.getApiInfo', [-1, str(self)])
        return object.__getattribute__(self, k)


class RemoteAPIClient:
    def __init__(self):
        self.context = zmq.Context()
        self.socket = self.context.socket(zmq.REQ)
        self.socket.connect(f'XXXconnectionAddress1XXX')
        self.callbackFuncs = {}
        self.requiredItems = {}

    def __del__(self):
        # Disconnect and destroy client
        self.socket.close()
        self.context.term()

    def _send(self, req):
        # convert a possible function to string:
        if 'args' in req and req['args']!=None and (isinstance(req['args'],tuple) or isinstance(req['args'],list)):
            req['args'] = list(req['args'])
            for i in range(len(req['args'])):
                if callable(req['args'][i]):
                    funcStr = str(req['args'][i])
                    m = re.search(r"<function (.+) at ", funcStr)
                    if m:
                        funcStr = m.group(1)
                        self.callbackFuncs[funcStr] = req['args'][i]
                        req['args'][i] = funcStr + "@func"
            req['argsL'] = len(req['args'])

        # pack and send:
        try:
            rawReq = cbor.dumps(req)
        except Exception as err:
            req['args'] = '_*baddata*_' + str(req['args'])
            rawReq = cbor.dumps(req)
            #raise Exception("illegal argument " + str(err)) #__EXCEPTION__
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
                if reply['func'] in self.callbackFuncs:
                    args=self.callbackFuncs[reply['func']](*reply['args'])
                else:
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
                setattr(ret, k, RemoteAPIMethod(self, name, k))
            elif len(v) == 1 and 'const' in v:
                setattr(ret, k, v['const'])
            else:
                setattr(ret, k, self.getObject(f'{name}.{k}', _info=v))

        if name == 'sim':
            ret.getScriptFunctions = self.getScriptFunctions

        return ret

    def require(self, name):
        if name in self.requiredItems:
            ret = self.requiredItems[name]
        else:
            self.call('__require__', [name])
            ret = self.getObject(name)
            allApiFuncs = self.call('__getApi__', [name])
            for a in allApiFuncs:
                globals()[a] = self.getObject(name)
            self.requiredItems[name] = ret
        return ret

    def getScriptFunctions(self, scriptHandle):
        return type('', (object,), {
            '__getattr__':
                lambda self, func:
                    lambda *args:
                        sim.callScriptFunction(func, scriptHandle, *args)
        })()

def _evalExec(theStr):
    sim.protectedCalls(True)
    try:
        global H, SEL, SEL1
        if sim.getNamedBoolParam('simCmd.setConvenienceVars') is not False:
            H = sim.getObject
            SEL = sim.getObjectSel()
            SEL1 = SEL[-1] if SEL else None

        try:
            ret = eval(theStr, globals())
            if ret is not None:
                print(repr(ret))
        except SyntaxError:
            try:
                exec(theStr, globals())
            except Exception as e:
                sim.addLog(sim.verbosity_scripterrors | sim.verbosity_undecorated, f"Error: {e}")
        except Exception as e:
            sim.addLog(sim.verbosity_scripterrors | sim.verbosity_undecorated, f"Error: {e}")

        if sim.getNamedBoolParam('simCmd.setConvenienceVars') is not False:
            if H != sim.getObject:
                sim.addLog(sim.verbosity_scriptwarnings | sim.verbosity_undecorated, "cannot change 'H' variable")

            H = sim.getObject
            SEL = sim.getObjectSel()
            SEL1 = SEL[-1] if SEL else None
    except Exception as e:
        pass

    sim.protectedCalls(False)

def _evalExecRet(theStr):
    sim.protectedCalls(True)
    try:
        reply = "_*empty*_"
        try:
            reply = eval(theStr,globals())
        except SyntaxError:
            try:
                exec(theStr,globals())
            except Exception as e:
                reply = f"Error: {e}"
        except Exception as e:
            reply = f"Error: {e}"
    except Exception as e:
        pass
    sim.protectedCalls(False)
    return reply

def _getFuncIfExists(name):
    method=None
    try:
        method=globals()[name]
    except BaseException as err:
        pass
    return method

def _getCompletion(input, pos):
    import functools, re
    ret = []
    if pos == len(input):
        if m := re.search(r'[_\w][_\w\.]*$', input):
            *parts, last = m.group().split('.')
            obj = functools.reduce(lambda o, k: None if o is None else globals().get(k) if o == globals() else getattr(o, k, None), parts, globals())
            for k in ([] if obj is None else globals() if obj == globals() else dir(obj)):
                if k.startswith(last) and len(k) > len(last):
                    ret.append(k[len(last):])
    return ret

def _getCalltip(input, pos):
    def getCallContexts(code, pos):
        from io import BytesIO
        from tokenize import tokenize, TokenInfo, TokenError
        import tokenize as T

        def lpos(code, row, col):
            if row > 1:
                i = code.index('\n')
                return i + 1 + lpos(code[i+1:], row-1, col)
            else:
                return col

        tokens = []
        try:
            for t in tokenize(BytesIO(code.encode('utf-8')).readline):
                tokens.append(t)
        except TokenError:
            pass

        def merge_namedotname(tokens):
            for i, (t1, t2, t3) in enumerate(zip(tokens, tokens[1:], tokens[2:])):
                if t1.type == T.NAME and t2.type == T.OP and t2.string == '.' and t3.type == T.NAME:
                    merged = TokenInfo(T.NAME, t1.string + '.' + t3.string, t1.start, t3.end, t1.line + t2.line + t3.line)
                    return merge_namedotname(tokens[:i] + [merged] + tokens[i+3:])
            return tokens
        tokens = merge_namedotname(tokens)

        tokens = list(filter(lambda t: t.type == T.NAME or (t.type == T.OP and t.string in '()'), tokens))

        ranges = {}
        stack = []
        last_name = None
        for t in tokens:
            if t.string == '(':
                stack.append(last_name)
            elif t.string == ')':
                if not stack: return []
                tstart = stack.pop()
                ranges[tstart.string] = (lpos(code, *tstart.start), lpos(code, *t.end))
            else:
                last_name = t
        # flush stack:
        end = len(code)
        while stack:
            tstart = stack.pop()
            ranges[tstart.string] = (lpos(code, *tstart.start), end)

        ret = []
        for name, (start, end) in ranges.items():
            if start <= pos <= end:
                ret.append(name)
        return ret

    cc = getCallContexts(input, pos)
    if cc:
        return sim.getApiInfo(-1, cc[0])
    else:
        return ''

def require(a):
    return client.require(a)

def print(*a):
    client.call('__print__', [', '.join(map(str, a))])

def quit():
    client.call('quit', [])

def help(what=None):
    if what:
        print(getattr(what, '__doc__', 'No documentation available.'))
    else:
        simCmd = require('simCmd')
        simCmd.help()

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

# convenience global var to emulate OOP in scripts:
self = type('', (object,), {})()

]=]
