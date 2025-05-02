startTimeout = 10
sim = require('sim') -- keep here, since we have several sim-functions defined/redefined here
simZMQ = require('simZMQ')
simSubprocess = require('simSubprocess')
cbor = require('org.conman.cbor')
_removeLazyLoaders()

function sim.setThreadSwitchTiming(switchTiming)
    -- Shadow the original func
    -- 0=disabled, otherwise switchTiming
    threadSwitchTiming = switchTiming
end

function sim.setThreadAutomaticSwitch()
    -- Shadow the original function
end

sim.setStepping = wrap(sim.setStepping, function(origFunc)
    -- Shadow original function:
    -- When stepping is true, CoppeliaSim ALWAYS blocks while Python runs some code
    -- When stepping is false, CoppeliaSim run concurently to Python, i.e. Python is "free" (until a request from Python comes)
    return function(enabled)
        local retVal = 0
        if currentFunction == 'sim.setStepping' then
            if pythonFuncs['sysCall_thread'] then
                retVal = steppingLevel
                if enabled then
                    steppingLevel = steppingLevel + 1
                else
                    if steppingLevel > 0 then steppingLevel = steppingLevel - 1 end
                end
            end
        else
            retVal = origFunc(enabled)
        end
        return retVal
    end
end)

sim.acquireLock = wrap(sim.acquireLock, function(origFunc)
    return function()
        if currentFunction == 'sim.acquireLock' then
            holdCalls = holdCalls + 1
        else
            origFunc()
        end
    end
end)

sim.releaseLock = wrap(sim.releaseLock, function(origFunc)
    return function()
        if currentFunction == 'sim.releaseLock' then
            if holdCalls > 0 then holdCalls = holdCalls - 1 end
        else
            origFunc()
        end
    end
end)

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

cbornil = {
    __tocbor = function(self)
        return cbor.SIMPLE.null()
    end,
}

function tonil()
    local d = {}
    setmetatable(d, cbornil)
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
            tmp = tmp .. 'sys.path.append("' .. _additionalPaths[i] .. '"); ' -- ';' instead of '\n'! (since that would change the size of the boilerplate code) 
        end
    end
    if additionalPaths then
        for i = 1, #additionalPaths, 1 do
            tmp = tmp .. 'sys.path.append("' .. additionalPaths[i] .. '"); ' -- ';' instead of '\n'! (since that would change the size of the boilerplate code) 
        end
    end
    local additionalPythonPaths = {
        sim.getStringParam(sim.stringparam_application_path),
        sim.getStringParam(sim.stringparam_application_path) .. '/python',
        sim.getStringParam(sim.stringparam_scene_path),
        sim.getStringParam(sim.stringparam_additionalpythonpath)
        }
    for i = 1, #additionalPythonPaths, 1 do
        if additionalPythonPaths[i] ~= '' then
            tmp = tmp .. 'sys.path.append("' .. additionalPythonPaths[i] .. '"); ' -- ';' instead of '\n'! (since that would change the size of the boilerplate code) 
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
        if receiveIsNext then -- condition added on 22.01.2025 to fix Python's sysCall_cleanup randomly not getting called
            receive()
        end
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
        local fun = _G
        if string.find(funcName, "%.") then
            for w in funcName:gmatch("[^%.]+") do -- handle cases like sim.func or similar too
                if fun[w] then fun = fun[w] end
            end
        else
            fun = fun[funcName]
        end
        if type(fun) == 'function' then
            local retVals = {pcall(fun, table.unpack(args))}
            local status = retVals[1]
            table.remove(retVals, 1)
            if status == false then
                return "_*runtimeError*_" -- ..retVals
            else
                return table.unpack(retVals)
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

function sim.testCB(a, cb, b, iterations)
    iterations = iterations or 99
    for i = 1, iterations, 1 do cb(a, b) end
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
        local reqFunc = req['func']
        local func = _getField(reqFunc)
        local args = req['args'] or {}
        if not func then
            if not protectedCalls then
                pythonMustHaveRaisedError = true -- actually not just yet, we still need to send a reply tp Python
            end
            resp['err'] = 'No such function: ' .. reqFunc
        else
            if reqFunc == 'sim.setThreadAutomaticSwitch' then
                -- For backward compatibility with pythonWrapperV1
                func = sim.setStepping
                reqFunc = 'sim.setStepping'
                if #args > 0 then
                    if not isnumber(args[1]) then args[1] = not args[1] end
                end
            end

            currentFunction = reqFunc

            -- Handle function arguments (up to a depth of 2):
            for i = 1, #args, 1 do
                if type(args[i]) == 'string' then
                    -- depth 1
                    if args[i]:sub(-5) == "@func" then
                        local nm = args[i]:sub(1, -6)
                        local fff = function(...) return callRemoteFunction(nm, {...}, false, true) end
                        args[i] = fff
                        if not _S.pythonCallbacks then
                            _S.pythonCallbacks = {}
                        end
                        _S.pythonCallbacks[fff] = true -- so that we can identify a Python callback
                    end
                else
                    if type(args[i]) == 'table' then
                        -- depth 2
                        local cnt = 0
                        for k, v in pairs(args[i]) do
                            if type(v) == 'string' and v:sub(-5) == "@func" then
                                local nm = v:sub(1, -6)
                                v = function(...) return callRemoteFunction(nm, {...}, false, true) end
                                if not _S.pythonCallbacks then
                                    _S.pythonCallbacks = {}
                                end
                                _S.pythonCallbacks[v] = true -- so that we can identify a Python callback
                                args[i][k] = v
                            end
                            cnt = cnt + 1
                            if cnt >= 16 then
                                break -- parse no more than 16 items
                            end
                        end
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
                    local pret = table.pack(func(unpack(args, 1, req.argsL)))
                    local ret = {}
                    for i = 1, pret.n do
                        if pret[i] ~= nil then
                            ret[i] = pret[i]
                        else
                            ret[i] = tonil()
                        end
                    end
                    --local ret = {func(unpack(args, 1, req.argsL))}
                    
                    -- Try to assign correct types to text/buffers and arrays/maps:
                    local args = returnTypes[reqFunc]
                    if args then
                        local cnt = math.min(#ret, #args)
                        for i = 1, cnt do
                            if args[i] == 1 and type(ret[i]) == 'string' then
                                ret[i] = totxt(ret[i])
                            elseif args[i] == 2 and type(ret[i]) == 'string' then
                                ret[i] = tobin(ret[i])
                            elseif type(ret[i]) == 'table' then
                                if (not isbuffer(ret[i])) and (getmetatable(ret[i]) ~= cbornil) then 
                                    if table.isarray(ret[i]) then
                                        ret[i] = toarray(ret[i])
                                    else
                                        ret[i] = tomap(ret[i])
                                    end
                                end
                            end
                        end
                    end

                    return ret
                end, errHandler)
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
        local status, req = pcall(cbor.decode, tostring(dat))
        if not status then
            if #dat < 2000 then
                error(req .. "\n" .. sim.transformBuffer(dat, sim.buffer_uint8, 1, 0, sim.buffer_base64))
            else
                error('Error trying to decode received data:\n' .. req)
            end
        end

        -- Handle non-serializable data:
        if req.args and (type(req.args) == 'string') and req.args:match('^_%*baddata%*_') then
            req.args = string.gsub(req.args, '_%*baddata%*_', '')
            sim.addLog(sim.verbosity_warnings, "Received non-serializable data: " .. req.args)
            if req.cbor_pkg == 'cbor' then
                sim.addLog(sim.verbosity_warnings, "To get better support for some additional types such as numpy, install pip package 'cbor2'.")
            end
        end

        return req
    else
        error('Trying to receive data from Python where a send is expected')
    end
end

function send(reply)
    if not receiveIsNext then
        --[[
        -- Make sure the data does not contain any function. If there is, convert it to string. We do that up to a depth of 2:
        for i = 1, #reply do
            local ob = reply[i]
            if type(ob) == 'function' then
                reply[i] = tostring(ob)
                            print("bli")
            else
                if type(ob) == table and not isBuffer(ob) then
                    local cnt = 0
                    for k, v in pairs(ob) do
                        if type(v) == 'function' then
                            print("bla")
                            ob[k] = tostring(v)
                        end
                        cnt = cnt + 1
                        if cnt > 16 then
                            break
                        end
                    end
                end
            end
        end
        --]]
        local dat = reply
        local status, reply = pcall(cbor.encode, reply)
        if not status then
            local s2, rep2 = pcall(getAsString, dat)
            if s2 then
                error(reply .. "\n" .. rep2)
            else
                error('Error while trying to encode data to send:\n' .. reply)
            end
        end
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
                    local rep, o, t = cbor.decode(tostring(rep))
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
                        --[[
                        simZMQ.close(replySocket)
                        replySocket = simZMQ.socket(context, simZMQ.REP)

                        -- simZMQ.bind(replySocket, replyPortStr) -- takes some time for the address to be free again
                        while true do
                            local bindResult = simZMQ.__noError.bind(replySocket, replyPortStr)
                            if bindResult == 0 then
                                break
                            elseif bindResult == -1 and simZMQ.errnum() == simZMQ.EADDRINUSE then
                                -- address already in use -> retry
                            else
                                simZMQ.__raise()
                            end
                        end
                        --]]
                        
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
    local pythonWrapperPortStart = 23259
    while true do
        sim.systemSemaphore('pythonWrapper', true)
        local dat = sim.readCustomBufferData(sim.handle_appstorage, 'nextPythonWrapperCommPort')
        if dat == nil then
            dat = sim.packInt32Table({pythonWrapperPortStart})
        end
        local p = sim.unpackInt32Table(dat)[1]
        local np = p + 1
        if np >= pythonWrapperPortStart + 800 then
            np = pythonWrapperPortStart
        end
        sim.writeCustomBufferData(sim.handle_appstorage, 'nextPythonWrapperCommPort', sim.packInt32Table({np}))
        sim.systemSemaphore('pythonWrapper', false)
    
        local tmpContext = simZMQ.ctx_new()
        local tmpSocket = simZMQ.socket(tmpContext, simZMQ.REP)
        if simZMQ.__noError.bind(tmpSocket, string.format('tcp://127.0.0.1:%d', p)) == 0 then
            simZMQ.close(tmpSocket)
            simZMQ.ctx_term(tmpContext)
            return string.format('tcp://127.0.0.1:%d', p)
        end
    end
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
    if pythonExecutable then
        pyth = pythonExecutable
    end
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
                                        sim.getObjectStringParam(
                                            sim.getScript(sim.handle_self), sim.scriptstringparam_nameext
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
            while sim.getSystemTime() - st < startTimeout and simSubprocess.isRunning(subprocess) do
                simSubprocess.wait(subprocess, 0.1)
                r, rep = simZMQ.__noError.recv(pySocket, simZMQ.DONTWAIT)
                if r >= 0 then break end
            end
            if r >= 0 then
                local rep, o, t = cbor.decode(tostring(rep))
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
                    "The Python interpreter could not handle the wrapper script (or communication between the launched subprocess and CoppeliaSim could not be established via sockets). Make sure that the Python modules 'cbor2' and 'zmq' are properly installed, e.g. via: $ "
                errMsg = errMsg .. pyth ..
                             " -m pip install pyzmq cbor2. Additionally, you can try adjusting the value of startTimeout in lua/pythonWrapperV2.lua, at the top of the file"
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
        if sim.getObjectInt32Param(sim.getScript(sim.handle_self), sim.scriptintparam_type) ==
            sim.scripttype_sandbox then
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

function sim.readCustomDataBlock(obj, tag)
    -- Backw. comp. For Python, we should always return a string:
    local retVal = sim.readCustomStringData(obj, tag)
    if retVal == nil or #retVal == 0 then retVal = '' end
    return retVal
end

function startPythonClientSubprocess(pythonExec)
    local subprocess
    local controlPort = getFreePortStr()
    local args = string.qsplit(pythonExec, ' ')
    local ex = table.remove(args, 1)
    args[#args + 1] = sim.getStringParam(sim.stringparam_pythondir) .. '/pythonLauncher.py'
    args[#args + 1] = controlPort
    local res, ret = pcall(
                        function()
                            return simSubprocess.execAsync(ex, args, {useSearchPath = true, openNewConsole = false})
                        end)
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
        local tg = "__EXCEPTION__\n"
        local p = string.find(msg, tg)
        if p then
            msg = msg:sub(p + #tg)
            msg = "Traceback (most recent call last):\n" .. msg
        end
        local _, boilerplateLines = string.gsub(pythonBoilerplate, '\n', '')
        local _, userCodeLines = string.gsub(pythonUserCode, '\n', '')
        -- print("boilerplateLines", boilerplateLines)
        -- print("userCodeLines", userCodeLines)
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
                -- print("lineNb", lineNb)
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
import zmq
import re

try:
    import cbor2 as cbor
except ModuleNotFoundError:
    import cbor


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


def cbor_encode_anything(encoder, value):
    if 'numpy' in sys.modules:
        import numpy as np
        if np.issubdtype(type(value), np.floating):
            value = float(value)
        if isinstance(value, np.ndarray):
            value = value.tolist()
    return encoder.encode(value)


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
        def handle_func_arg(arg):
            retArg = arg
            if callable(arg):
                funcStr = str(arg)
                m = re.search(r"<function (.+) at 0x([0-9a-fA-F]+)(.*)", funcStr)
                if m:
                    funcStr = m.group(1) + '_' + m.group(2)
                else:
                    m = re.search(r"<(.*)method (.+) of (.+) at 0x([0-9a-fA-F]+)(.*)", funcStr)
                    if m:
                        funcStr = m.group(2) + '_' + m.group(4)
                    else:
                        funcStr = None
                if funcStr:
                    self.callbackFuncs[funcStr] = arg
                    retArg = funcStr + "@func"
            return retArg 

        # convert a possible function to string (up to a depth of 2):
        if 'args' in req and req['args'] != None and isinstance(req['args'], (tuple, list)):
            req['args'] = list(req['args'])
            for i in range(len(req['args'])):
                req['args'][i] = handle_func_arg(req['args'][i]) # depth 1
                if isinstance(req['args'][i], tuple):
                    req['args'][i] = list(req['args'][i])
                if isinstance(req['args'][i], list) and len(req['args'][i]) <= 16: # parse no more than 16 items
                    for j in range(len(req['args'][i])):
                        req['args'][i][j] = handle_func_arg(req['args'][i][j]) #depth 2
                if isinstance(req['args'][i], dict) and len(req['args'][i]) <= 16:
                    req['args'][i] = {key: handle_func_arg(value) for key, value in req['args'][i].items()} #depth 2
            req['argsL'] = len(req['args'])

        # pack and send:
        try:
            kwargs = {}
            if cbor.__package__ == 'cbor2':
                # only 'cbor2' has a 'default' kwarg:
                kwargs['default'] = cbor_encode_anything
            rawReq = cbor.dumps(req, **kwargs)
        except Exception as err:
            req['args'] = '_*baddata*_' + str(req['args'])
            req['cbor_pkg'] = cbor.__package__
            rawReq = cbor.dumps(req)
            #raise Exception("illegal argument " + str(err)) # __EXCEPTION__
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
                    raise Exception(reply.get('err')) # __EXCEPTION__
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
                raise Exception(reply.get('err')) # __EXCEPTION__
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
            ret.copyTable = self.copyTable
            ret.packUInt8Table = self.packUInt8Table
            ret.unpackUInt8Table = self.unpackUInt8Table
            ret.packUInt16Table = self.packUInt16Table
            ret.unpackUInt16Table = self.unpackUInt16Table
            ret.packUInt32Table = self.packUInt32Table
            ret.unpackUInt32Table = self.unpackUInt32Table
            ret.packInt32Table = self.packInt32Table
            ret.unpackInt32Table = self.unpackInt32Table
            ret.packFloatTable = self.packFloatTable
            ret.unpackFloatTable = self.unpackFloatTable
            ret.packDoubleTable = self.packDoubleTable
            ret.unpackDoubleTable = self.unpackDoubleTable

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
        
    def copyTable(self, table):
        import copy 
        return copy.deepcopy(table)
        
    def _packXTable(self, table, w, start, cnt):
        import array
        if cnt == 0:
            cnt = len(table) - start
        arr = array.array(w, table[start:(start + cnt)])
        return arr.tobytes()

    def _unpackXTable(self, data, w, start, cnt, off):
        import array
        arr = array.array(w)
        start *= arr.itemsize
        start += off
        if cnt == 0:
            cnt =  len(data) - start
        else:
            cnt *= arr.itemsize
        arr.frombytes(data[start:(start + cnt)])
        return list(arr)

    def packUInt8Table(self, table, start=0, cnt=0):
        return self._packXTable(table, 'B', start, cnt)

    def unpackUInt8Table(self, data, start=0, cnt=0, off=0):
        return self._unpackXTable(data, 'B', start, cnt, off)
        
    def packUInt16Table(self, table, start=0, cnt=0):
        return self._packXTable(table, 'H', start, cnt)
        
    def unpackUInt16Table(self, data, start=0, cnt=0, off=0):
        return self._unpackXTable(data, 'H', start, cnt, off)
        
    def packUInt32Table(self, table, start=0, cnt=0):
        return self._packXTable(table, 'L', start, cnt)
        
    def unpackUInt32Table(self, data, start=0, cnt=0, off=0):
        return self._unpackXTable(data, 'L', start, cnt, off)
        
    def packInt32Table(self, table, start=0, cnt=0):
        return self._packXTable(table, 'l', start, cnt)
        
    def unpackInt32Table(self, data, start=0, cnt=0, off=0):
        return self._unpackXTable(data, 'l', start, cnt, off)
        
    def packFloatTable(self, table, start=0, cnt=0):
        return self._packXTable(table, 'f', start, cnt)
        
    def unpackFloatTable(self, data, start=0, cnt=0, off=0):
        return self._unpackXTable(data, 'f', start, cnt, off)
        
    def packDoubleTable(self, table, start=0, cnt=0):
        return self._packXTable(table, 'd', start, cnt)

    def unpackDoubleTable(self, data, start=0, cnt=0, off=0):
        return self._unpackXTable(data, 'd', start, cnt, off)
        
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
