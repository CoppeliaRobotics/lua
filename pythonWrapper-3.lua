import 'sim-2'
import 'sim.ZMQRemoteAPI-2'
import 'simSubprocess'

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

for name in (
    'sysCall_init',
    'sysCall_sensing',
    'sysCall_actuation',
    'sysCall_cleanup',
):
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
    }
    local pyInterp = pythonExecutable or sim.app.defaultPython
    procHandle = simSubprocess.execAsync(pyInterp, {'-c', code, args})

    rapi:log(1, 'waiting for python subprocess to be ready...')
    while not ready do
        rapi:spinSome()
        sim.self:yield()
    end
    rapi:log(1, 'python subprocess is ready')

    rapi:call(nil, 'sysCall_init')
end

function sysCall_sensing()
    rapi:call(nil, 'sysCall_sensing')
end

function sysCall_actuation()
    rapi:call(nil, 'sysCall_actuation')
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

    rapi:call(nil, 'sysCall_cleanup')

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
