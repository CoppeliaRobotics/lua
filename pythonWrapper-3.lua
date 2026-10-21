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

function __callSysCall(sysCall)
    if not rapi._callables[sysCall] then return end
    return rapi:call(nil, sysCall)
end

function sysCall_init()
    local port = getFreePort()

    rapi = sim.ZMQRemoteAPI{
        name = 'worker-' .. port,
        port = port,
        server = true,
        verbose = 0,
    }
    rapi.callMethod = sim.callMethod

    local ready = false
    rapi:registerCallback('__ready', function() ready = true end)
    rapi:registerCallback('__print', print)

    code = [[
import sys
import json
args = json.loads(sys.argv[1])
sys.path.insert(0, args["PYTHON_PATH"])
import sim
from sim.zmqremoteapi import ZMQRemoteAPI

rapi = ZMQRemoteAPI({
    'name': f'client-{args["SCRIPT_ID"]}',
    'server': False,
    'port': args["WORKER_PORT"],
    'verbose': 1,
})
sim.Object._callMethod = rapi.call

def print(*args):
    rapi.call(None, '__print', *args)

]] .. (pythonUserCode or '') .. [[

for name in args["SYSCALLS"]:
    if callable(func := globals().get(name)):
        rapi.registerCallback(name, func, False)

rapi.call(None, '__ready')

while 1: rapi.spinSome()
]]
    local json = require 'dkjson'
    local args = json.encode{
        PYTHON_PATH = sim.app.paths.python,
        WORKER_PORT = port,
        SCRIPT_ID = sim.self.handle,
        SYSCALLS = sysCalls,
    }
    local pyInterp = pythonExecutable or sim.app.defaultPython
    procHandle = simSubprocess.execAsync(pyInterp, {'-c', code, args})

    rapi:log(1, 'waiting for python subprocess to be ready...')
    while not ready do
        rapi:spinSome()
        sim.self:yield()
    end
    rapi:log(1, 'python subprocess is ready')

    local excludeSysCalls = {
        sysCall_init = true,
        sysCall_thread = true,
        sysCall_cleanup = true,
    }
    for _, sysCall in ipairs(sysCalls) do
        if not excludeSysCalls[sysCall] and rapi._callables[sysCall] then
            _G[sysCall] = function()
                return __callSysCall(sysCall)
            end
        end
    end

    return __callSysCall('sysCall_init')
end

function sysCall_thread()
    rapi:log(1, 'thread running')
    while rapi:isRemoteAlive() do
        rapi:spinSome()
        sim.self:yield()
    end
    rapi:log(1, 'terminating script (handle=' .. sim.self.handle ..') because of inactivity')
    sim.self:remove()
end

function sysCall_cleanup()
    rapi:log(1, 'terminating script (handle=' .. sim.self.handle ..') [cleanup]')

    __callSysCall('sysCall_cleanup')
    rapi:cleanup()
    rapi = nil

    if procHandle then
        if simSubprocess.isRunning(procHandle) then
            simSubprocess.kill(procHandle)
        end
        procHandle = nil
    end
end

function getFreePort()
    local simZMQ = require 'simZMQ'
    local function nextPort(v)
        local k = 'zmqRemoteApi2.embeddedScriptNextPort'
        if v == nil then return sim.app.signal[k] end
        sim.app.sandbox:executeString("require('sim-2').app.signal['" .. k .. "']=" .. v)
    end
    while true do
        sim.app:systemLock('pythonWrapper-3', true)
        local port = nextPort() or 43210
        nextPort(port + 1)
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
