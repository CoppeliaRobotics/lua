import 'sim-2'
import 'sim.ZMQRemoteAPI-2'
import 'simSubprocess'

sysCalls = {
    'sysCall_actuation',
    'sysCall_addOnScriptResume',
    'sysCall_addOnScriptSuspend',
    'sysCall_afterCopy',
    'sysCall_afterCreate',
    'sysCall_afterDelete',
    'sysCall_afterInstanceSwitch',
    'sysCall_afterLoad',
    'sysCall_afterSave',
    'sysCall_afterSimulation',
    'sysCall_beforeCopy',
    'sysCall_beforeDelete',
    'sysCall_beforeInstanceSwitch',
    'sysCall_beforeMainScript',
    'sysCall_beforeSave',
    'sysCall_beforeSimulation',
    'sysCall_cleanup',
    'sysCall_contact',
    'sysCall_contactCallback',
    'sysCall_data',
    'sysCall_dyn',
    'sysCall_dynCallback',
    'sysCall_event',
    'sysCall_ext',
    'sysCall_info',
    'sysCall_init',
    'sysCall_joint',
    'sysCall_jointCallback',
    'sysCall_moduleEntry',
    'sysCall_msg',
    'sysCall_nonSimulation',
    'sysCall_realTimeIdle',
    'sysCall_resume',
    'sysCall_selChange',
    'sysCall_sensing',
    'sysCall_suspend',
    'sysCall_suspended',
    'sysCall_thread',
    'sysCall_trigger',
    'sysCall_userConfig',
    'sysCall_vision',
}

function __pythonWrapper_init()
    local port = __pythonWrapper_getFreePort()

    rapi = sim.ZMQRemoteAPI{
        name = 'pythonWrapper-lua-' .. port .. '-' .. sim.self.handle,
        port = port,
        server = true,
        verbose = verbose or 0,
    }
    rapi.callMethod = sim.callMethod
    if barePrint then
        rapi.print = printToConsole
    end

    local ready = false
    rapi:registerCallback('__ready', function() ready = true end)
    rapi:registerCallback('__print', print)

    code = [[
def __init():
    global __init
    del __init

    import sys
    import json
    __args = json.loads(sys.argv[1])
    sys.path.insert(0, __args["pythonPath"])

    global __pythonWrapper
    from sim.zmqremoteapi import PythonWrapper
    __pythonWrapper = PythonWrapper(globals(), **__args)

    global print
    print = __pythonWrapper.rapi.print

    __pythonWrapper.registerCmdInterface()


def __postInit():
    global __postInit
    del __postInit

    __pythonWrapper.registerSysCalls()

    import inspect
    if inspect.iscoroutinefunction(f := __pythonWrapper._g.get('sysCall_thread')):
        t = __pythonWrapper.registerThread(f)
        global step
        step = t.step
        #global sim_sleep
        #sim_sleep = t.sim_sleep

    __pythonWrapper.spin()


__init()

]] .. (pythonUserCode or '') .. [[

__postInit()
]]
    local json = require 'dkjson'
    local args = json.encode{
        pythonPath = sim.app.paths.python,
        port = port,
        client_id = sim.self.handle,
        sysCalls = sysCalls,
        verbose = rapi.verbose,
        barePrint = not not barePrint,
    }
    local pyInterp = pythonExecutable or sim.app.defaultPython
    procHandle = simSubprocess.execAsync(pyInterp, {'-c', code, args})

    rapi:log(1, 'waiting for python subprocess to be ready...')
    while not ready do
        rapi:spinSome()
        sim.self:yield()
    end
    rapi:log(1, 'python subprocess is ready')

    for _, sysCall in ipairs(sysCalls) do
        local funcName = '__pythonWrapper_call_' .. sysCall
        _G[funcName] = function(...)
            if not rapi._callables[sysCall] then return end
            return rapi:call(nil, sysCall, ...)
        end
        if rapi._callables[sysCall] then
            local opts = {when = sysCall == 'sysCall_cleanup' and 'before' or 'after'}
            sim.self:registerFunctionHook(sysCall, funcName, opts)
        end
    end

    -- setup also hooks for thread executor:
    for name, sysCall in pairs{
        init = 'sysCall_init',
        tick = 'sysCall_actuation',
        cleanup = 'sysCall_cleanup',
    } do
        local funcName = '__pythonWrapper_threadExec_' .. name
        local cbName = '_sysCall_thread_' .. name
        _G[funcName] = function(...)
            if not rapi._callables[cbName] then return end
            return rapi:call(nil, cbName, ...)
        end
        if rapi._callables[cbName] then
            local opts = {when = sysCall == 'sysCall_cleanup' and 'before' or 'after'}
            sim.self:registerFunctionHook(sysCall, funcName, opts)
        end
    end
end

function __pythonWrapper_tick()
    if rapi:isRemoteAlive() then
        rapi:spinSome()
    else
        rapi:log(1, 'terminating script (handle=' .. sim.self.handle ..') because of inactivity')
        sim.self:remove()
    end
end

function __pythonWrapper_actuation()
    return __pythonWrapper_tick()
end

function __pythonWrapper_nonSimulation()
    return __pythonWrapper_tick()
end

function __pythonWrapper_cleanup()
    rapi:log(1, 'terminating script (handle=' .. sim.self.handle ..') [cleanup]')

    rapi:cleanup()
    rapi = nil

    if procHandle then
        if simSubprocess.isRunning(procHandle) then
            simSubprocess.kill(procHandle)
        end
        procHandle = nil
    end
end

function __pythonWrapper_getFreePort()
    local simZMQ = require 'simZMQ'
    while true do
        sim.app:systemLock('pythonWrapper-3', true)
        local n = 'signal.zmqRemoteApi2.embeddedScriptNextPort'
        local port = sim.app[n] or 43210
        sim.app.sandboxLua:callMethod(sim.app, 'setIntProperty', n, port + 1)
        sim.app:systemLock('pythonWrapper-3', false)

        local ctx = simZMQ.ctx_new()
        local sock = simZMQ.socket(ctx, simZMQ.REP)
        if simZMQ.__noError.bind(sock, string.format('tcp://127.0.0.1:%d', port)) == 0 then
            simZMQ.close(sock)
            simZMQ.ctx_term(ctx)
            return port
        end
    end
end

sim.self:registerFunctionHook('sysCall_init', '__pythonWrapper_init', {when = 'before'})
sim.self:registerFunctionHook('sysCall_actuation', '__pythonWrapper_actuation', {when = 'before'})
sim.self:registerFunctionHook('sysCall_nonSimulation', '__pythonWrapper_nonSimulation', {when = 'before'})
sim.self:registerFunctionHook('sysCall_cleanup', '__pythonWrapper_cleanup', {when = 'after'})

function _evalExec(...)
    rapi:call(nil, '__pythonWrapper_evalExec', ...)
end

function _evalExecRet(...)
    rapi:call(nil, '__pythonWrapper_evalExecRet', ...)
end

function _getCompletion(...)
    rapi:call(nil, '__pythonWrapper_getCompletion', ...)
end

function _getCalltip(...)
    rapi:call(nil, '__pythonWrapper_getCalltip', ...)
end
