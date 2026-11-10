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

initTimeout = initTimeout or 10
pythonThreadActive = false -- true while Lua is executing Python's sysCall_thread

-- CoppeliaSim routes custom function calls (sim.callFunction, script
-- callbacks, UI callbacks, ...) through the global sysCall_ext when it exists;
-- the original function is then not called automatically, so it is re-dispatched
-- here. External calls go to Python by default; Lua is the explicit opt-in:
--
--   'myFunction'       -> Python 'myFunction'
--   'a.b.c.myFunction' -> Python 'a.b.c.myFunction' (resolved through attributes)
--   'myFunction@lua'   -> Lua 'myFunction'
--   'a.b.c.myFunction@lua' -> Lua 'a.b.c.myFunction' (dotted names)
--
-- (A leading '@' is stripped by the engine itself, which then bypasses this
-- function and calls the Lua function directly.)
local function __extCallLua(funcName, ...)
    local f = _G[funcName]
    if type(f) ~= 'function' then
        local obj = _G
        for part in funcName:gmatch('[^.]+') do
            if type(obj) ~= 'table' then
                obj = nil
                break
            end
            obj = obj[part]
        end
        f = obj
    end
    if type(f) ~= 'function' then
        error('no such function: ' .. tostring(funcName))
    end
    return f(...)
end

function sysCall_ext(funcName, ...)
    local luaName = funcName:match('^(.*)@lua$')
    if luaName then
        return __extCallLua(luaName, ...)
    end
    if not rapi then error('the Python side is not ready') end
    return rapi:call(nil, funcName, ...)
end

function __pythonWrapper_isMainThread()
    local co, isMain = coroutine.running()
    return (co == nil) or (isMain == true)
end

function __pythonWrapper_threadIsActive()
    return pythonThreadActive and __coroutine__ ~= nil and
           coroutine.status(__coroutine__) ~= 'dead'
end

-- Called by the engine when the embedded script starts with an 'include <file>'
-- line (the header parser turns it into externalFile='<file>.py' and calls this
-- after __userCode__ has been set): the file's content is prepended to
-- __userCode__, i.e. it runs in the same namespace as the rest of the script,
-- like a C #include. Its directory is also added to Python's module search path
-- (see `additionalPaths` in __pythonWrapper_init), so imports relative to the
-- included file keep working.
function loadExternalFile(file)
    externalFile = file
    local f
    local absPath
    if sim.app.platform == sim.platform.windows then
        absPath = ((file:sub(1, 1) == '/') or (file:sub(1, 1) == '\\') or (file:sub(2, 2) == ':'))
    else
        absPath = (file:sub(1, 1) == '/')
    end
    if absPath then
        f = io.open(file, 'rb')
    else
        local b = {sim.app.paths.app}
        if sim.app.namedParam.settings.defaultPaths.python then
            table.insert(b, sim.app.namedParam.settings.defaultPaths.python)
        end
        table.insert(b, sim.scene.path)
        if sim.app.namedParam.settings.additionalPaths and sim.app.namedParam.settings.additionalPaths.python then
            table.insert(b, sim.app.namedParam.settings.additionalPaths.python)
        end
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
    if not __userCode__ then __userCode__ = '' end
    __userCode__ = f:read('*all') .. __userCode__
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

function __pythonWrapper_init()
    local port = __pythonWrapper_getFreePort()

    rapi = sim.ZMQRemoteAPI{
        name = 'pythonWrapper-lua-' .. port .. '-' .. sim.self.handle,
        port = port,
        server = true,
        verbose = verbose or 0,
        -- Wait on a blocking zmq_poll and react as soon as Python replies (or
        -- sends another call), instead of polling with timeouts.
        blocking = true,
    }
    rapi.callMethod = sim.callMethod
    -- While a blocking wait has no incoming message for a while, check that the
    -- Python subprocess is still alive (this raises if it terminated).
    rapi.onWaitTimeout = function()
        __pythonWrapper_pollSubprocess()
    end
    -- Do not treat message silence as death: the Lua side can be silent for a
    -- long time (edit modes, modal dialogs, long operations) and Python can
    -- compute for a long time inside sysCall_thread. Liveness is checked on the
    -- subprocess itself instead (onWaitTimeout above, onWaitTick below).
    rapi.remoteSilenceTimeout = 0
    rapi.onWaitTick = function()
        __pythonWrapper_pollSubprocess()
    end
    if barePrint then
        rapi.print = printToConsole
    end

    local ready = false
    rapi:registerCallback('__ready', function() ready = true end)
    rapi:registerCallback('__print', print)

    -- Generic access to CoppeliaSim's Lua modules (simUI, simOMPL, simIK,
    -- simVision, simAssimp, ...) from Python: rapi.module('simUI').create(xml)
    -- forwards to this callable, which loads the module in this Lua state (the
    -- state that has the C plugins) and calls the function. Returns the Lua
    -- multiple return values, as a list.
    rapi:registerCallback('__module', function(moduleName, funcName, args)
        assert(type(moduleName) == 'string' and type(funcName) == 'string',
               'invalid module call')
        local mod = require(moduleName)
        local fn = mod[funcName]
        assert(type(fn) == 'function',
               'no such function: ' .. moduleName .. '.' .. funcName)
        return table.pack(fn(table.unpack(args or {})))
    end)

    -- Module members are not all functions: e.g. simUI.curve_type.xy is a
    -- plain table of constants, Motion.MoveToPose is a *callable table* (a
    -- middleclass class), and calling it returns a Lua object (an instance) whose
    -- methods must be callable too. __moduleMember tells the client what an
    -- attribute is (function / CBOR-representable value / sub-table / Lua object),
    -- __moduleCall calls a function or callable table at an arbitrary (nested)
    -- path, and __moduleObjectMember/__moduleObjectCall give access to the members
    -- of a Lua object, which is kept in a registry and addressed by an integer id.
    local moduleObjects = {}
    local moduleObjectCount = 0

    local function isModuleValue(v)
        local t = type(v)
        if (t == 'number') or (t == 'string') or (t == 'boolean') then return true end
        if t ~= 'table' then return false end
        if getmetatable(v) ~= nil then return false end
        for k, val in pairs(v) do
            if ((type(k) ~= 'number') and (type(k) ~= 'string')) or (not isModuleValue(val)) then
                return false
            end
        end
        return true
    end

    -- functions and callable tables (e.g. a middleclass class)
    local function isModuleCallable(v)
        if type(v) == 'function' then return true end
        if type(v) == 'table' then
            local mt = getmetatable(v)
            return mt ~= nil and mt.__call ~= nil
        end
        return false
    end

    -- Lua objects (e.g. a Motion.MoveToPose instance): have a metatable, but are
    -- neither CBOR-encodable (sim objects/vectors carry __tocbor) nor callable
    local function isModuleObject(v)
        local t = type(v)
        if t == 'userdata' then return true end
        if t ~= 'table' then return false end
        local mt = getmetatable(v)
        return mt ~= nil and mt.__tocbor == nil and mt.__call == nil
    end

    local function encodeModuleValue(v)
        if isModuleObject(v) then
            moduleObjectCount = moduleObjectCount + 1
            moduleObjects[moduleObjectCount] = v
            return {__luaObject = moduleObjectCount}
        end
        return v
    end

    local function decodeModuleValue(v)
        if type(v) == 'table' and v.__luaObject ~= nil then
            return moduleObjects[v.__luaObject]
        end
        return v
    end

    local function decodeModuleArgs(args)
        if type(args) ~= 'table' then return args end
        for i = 1, #args do args[i] = decodeModuleValue(args[i]) end
        return args
    end

    local function packModuleResults(...)
        local n = select('#', ...)
        local res = {}
        for i = 1, n do res[i] = encodeModuleValue(select(i, ...)) end
        res.n = n
        return res
    end

    local function resolveModulePath(moduleName, path)
        local v = require(moduleName)
        for i = 1, #path do v = v[path[i]] end
        return v
    end

    rapi:registerCallback('__moduleMember', function(moduleName, path)
        local v = resolveModulePath(moduleName, path)
        if v == nil then return {kind = 'nil'} end
        if isModuleCallable(v) then return {kind = 'function'} end
        if isModuleObject(v) then
            return {kind = 'object', id = encodeModuleValue(v).__luaObject}
        end
        if isModuleValue(v) then return {kind = 'value', value = v} end
        return {kind = 'table'}
    end)

    rapi:registerCallback('__moduleCall', function(moduleName, path, args)
        local v = resolveModulePath(moduleName, path)
        assert(isModuleCallable(v),
               'not callable: ' .. moduleName .. '.' .. table.concat(path, '.'))
        return packModuleResults(v(table.unpack(decodeModuleArgs(args or {}))))
    end)

    rapi:registerCallback('__moduleObjectMember', function(moduleName, id, name)
        local obj = moduleObjects[id]
        assert(obj ~= nil, 'invalid module object: ' .. tostring(id))
        local v = obj[name]
        if v == nil then return {kind = 'nil'} end
        if isModuleCallable(v) then return {kind = 'function'} end
        if isModuleObject(v) then
            return {kind = 'object', id = encodeModuleValue(v).__luaObject}
        end
        if isModuleValue(v) then return {kind = 'value', value = v} end
        return {kind = 'table'}
    end)

    rapi:registerCallback('__moduleObjectCall', function(moduleName, id, name, args)
        local obj = moduleObjects[id]
        assert(obj ~= nil, 'invalid module object: ' .. tostring(id))
        local fn = obj[name]
        assert(type(fn) == 'function', 'not a method: ' .. tostring(name))
        return packModuleResults(fn(obj, table.unpack(decodeModuleArgs(args or {}))))
    end)

    local json = require 'dkjson'
    local args = {
        pythonPath = sim.app.namedParam.settings.defaultPaths.python,
        port = port,
        client_id = sim.self.handle,
        sysCalls = sysCalls,
        verbose = rapi.verbose,
        barePrint = not not barePrint,
        userCode = __userCode__ or '',
        additionalPaths = _additionalPaths or {},
    }
    local pyInterp = interpreterExecutable
    if (pyInterp == nil) and sim.app.namedParam.settings.defaultInterpreters then
        pyInterp = sim.app.namedParam.settings.defaultInterpreters.python
    end
    local startTimeout = tonumber(initTimeout) or 10
    local ok, err = pcall(function()
        procHandle = simSubprocess.execAsync(pyInterp, {
            sim.app.namedParam.settings.defaultPaths.python .. '/pythonLauncher-3.py',
            -- args provided only for decoration, as already provided via stdin:
            'coppeliaSim.pid=' .. sim.app.pid,
            'tcp.port=' .. port,
            'script.handle=' .. sim.self.handle,
        }, {captureOutput = not barePrint})
    end)
    if not ok then
        local src = 'setting "defaultInterpreters.python" in ' .. sim.app.paths.settings .. '/usrset.txt'
        if interpreterExecutable then src = 'variable "interpreterExecutable"' end
        error('The interpreter ' .. pyInterp .. ' (from ' .. src .. ') could not be called: ' .. err)
    end

    simSubprocess.writeStdIn(procHandle, json.encode(args))
    simSubprocess.closeStdIn(procHandle)

    rapi:log(1, 'waiting for python subprocess to be ready...')
    local startTime = sim.app.systemTime
    while not ready do
        __pythonWrapper_pollSubprocess()
        local elapsed = sim.app.systemTime - startTime
        if elapsed > startTimeout then
            error('The Python interpreter failed to start within ' .. startTimeout .. 's (initTimeout)')
        end
        rapi:spinSome()
        sim.self:yield()
    end
    rapi:log(1, 'python subprocess is ready')

    local function registerHook(sysCall, funcName, cbName, when)
        if cbName == nil then
            cbName = sysCall
        end
        _G[funcName] = function(...)
            if not rapi._callables[cbName] then return end
            return rapi:call(nil, cbName, ...)
        end
        if rapi._callables[cbName] then
            local opts = {when = when}
            if opts.when == nil then
                if sysCall == 'sysCall_cleanup' then
                    opts.when = 'before'
                else
                    opts.when = 'after'
                end
            end
            sim.self:registerFunctionHook(sysCall, funcName, opts)
        end
    end

    -- setup sysCalls:
    for _, sysCall in ipairs(sysCalls) do
        -- sysCall_thread is not invoked by the simulation directly: it is
        -- handled by base.lua's thread coroutine (see below).
        if sysCall ~= 'sysCall_thread' then
            registerHook(sysCall, '__pythonWrapper_call_' .. sysCall)
        end
    end

    -- Some requests coming from Python can only be handled from within the
    -- thread coroutine: step() and yield() suspend the Lua thread, which is
    -- only possible when the coroutine is the current execution context.
    -- Requests received on the main Lua thread are deferred until the
    -- coroutine runs again. `nested` requests (sent while handling a Lua
    -- call) are always answered immediately, to keep re-entrant calls working.
    rapi.shouldDeferRequest = function(req)
        if not __pythonWrapper_threadIsActive() then return false end
        if req.nested then return false end
        if not __pythonWrapper_isMainThread() then return false end
        return (req.msg == 'call') and ((req.func == 'step') or (req.func == 'yield'))
    end

    -- Redirect Lua's sysCall_thread to Python's sysCall_thread.
    --
    -- base.lua wraps a global sysCall_thread function into a coroutine
    -- (in _S.sysCallBase_init, which runs after this hook) and resumes that
    -- coroutine from sysCall_actuation / sysCall_nonSimulation. Running the
    -- Python thread function from inside that coroutine is what gives it the
    -- same behaviour as a Lua thread: when Lua yields, either preemptively
    -- (via the instruction-count hook) or explicitly (sim.self:step()/yield()),
    -- Python stays blocked at the communication interface and gets its reply
    -- in a later simulation step, while Lua can meanwhile keep serving other
    -- calls from Python.
    if rapi._callables['sysCall_thread'] then
        function sysCall_thread()
            pythonThreadActive = true
            local ok, err = xpcall(function()
                -- Yielding wait: Python's thread function can take arbitrarily
                -- long, so this call must be suspended/resumed by Lua's thread
                -- coroutine instead of blocking the simulation.
                rapi:callYielding(nil, 'sysCall_thread')
            end, debug.traceback)
            pythonThreadActive = false
            if not ok then
                error(err, 0)
            end
        end
    end
end

function __pythonWrapper_pollSubprocess()
    local stdOut, stdErr, running, stdOutClosed, stdErrClosed, exitCode = simSubprocess.poll(procHandle)
    for _, line in ipairs(stdOut) do print(line) end
    for _, line in ipairs(stdErr) do print(line) end
    if not running then
        error('The Python interpreter terminated with exit code ' .. exitCode)
    end
end

function __pythonWrapper_tick()
    __pythonWrapper_pollSubprocess()
    if __pythonWrapper_threadIsActive() then
        -- While Python's sysCall_thread is running, calls from Python are
        -- served from within Lua's thread coroutine only: that coroutine is
        -- what provides the preemptive threading (it yields and is resumed
        -- once per simulation step). Serving them here, on the main thread,
        -- would prevent step()/yield() from suspending the thread.
        --
        -- Also do not apply the inactivity timeout here: a thread may
        -- legitimately compute for a long time without exchanging a single
        -- message with Lua (process liveness is checked above).
        --
        -- But do keep the connection alive: while the simulation is paused (or
        -- the thread is simply blocked on a step), Python must not consider Lua
        -- gone, otherwise its blocking wait would abort.
        rapi:_sendKeepAlive()
        return
    end
    -- Do not terminate the script because Python has been silent for a while:
    -- the subprocess is still running (checked above), and it may simply be
    -- busy with a long command while the Lua side could not tick (e.g. while
    -- the application is in an edit mode or in a modal dialog). The script's
    -- lifetime is governed by the simulation, and __pythonWrapper_cleanup()
    -- kills the subprocess.
    if rapi then
        rapi:spinSome()
    end
end

function __pythonWrapper_actuation()
    return __pythonWrapper_tick()
end

function __pythonWrapper_suspended()
    -- Paused: keep the connection alive but do not execute Python's requests;
    -- they are deferred until the simulation runs again (see spinSuspended).
    __pythonWrapper_pollSubprocess()
    if rapi then
        rapi:spinSuspended()
    end
end

function __pythonWrapper_nonSimulation()
    return __pythonWrapper_tick()
end

function __pythonWrapper_cleanup()
    rapi:log(1, 'terminating script (handle=' .. sim.self.handle ..') [cleanup]')

    pythonThreadActive = false
    rapi:cleanup()
    rapi = nil

    if procHandle then
        if simSubprocess.isRunning(procHandle) then
            simSubprocess.killEx(procHandle, 3, 5)
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
        sim.app.luaSandbox:callMethod(sim.app, 'setIntProperty', n, port + 1)
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
sim.self:registerFunctionHook('sysCall_suspended', '__pythonWrapper_suspended', {when = 'before'})
sim.self:registerFunctionHook('sysCall_nonSimulation', '__pythonWrapper_nonSimulation', {when = 'before'})
sim.self:registerFunctionHook('sysCall_cleanup', '__pythonWrapper_cleanup', {when = 'after'})

function _evalExec(...)
    return rapi:call(nil, '__pythonWrapper_evalExec', ...)
end

function _evalExecRet(...)
    return rapi:call(nil, '__pythonWrapper_evalExecRet', ...)
end

function _getCompletion(...)
    return rapi:call(nil, '__pythonWrapper_getCompletion', ...)
end

function _getCalltip(...)
    return rapi:call(nil, '__pythonWrapper_getCalltip', ...)
end
