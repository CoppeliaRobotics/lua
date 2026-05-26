local class = require 'middleclass'
local sim = require 'sim-2'
local simCBOR = require 'simCBOR'
local simZMQ = require 'simZMQ'
simZMQ.__raiseErrors()
local uuid = require 'uuid'
uuid.set_rng(uuid.rng.math_random())

local ZMQRemoteAPI = class 'sim.ZMQRemoteAPI'

function ZMQRemoteAPI:initialize(opts)
    opts = opts or {}
    self.name = opts.name
    self.server = not not opts.server
    self.verbose = tonumber(opts.verbose or 0)
    self.clientID = opts.clientID or uuid.v4()
    local ctx = simZMQ.ctx_singleton()
    local host = opts.host or '127.0.0.1'
    local port = opts.port or 24020
    local socketType = self.server and 'REP' or 'REQ'
    self.socket = simZMQ.socket(ctx, simZMQ[socketType])
    if opts.server then
        simZMQ.bind(self.socket, 'tcp://*:' .. port)
    else
        simZMQ.connect(self.socket, 'tcp://' .. host .. ':' .. port)
    end
end

function ZMQRemoteAPI:cleanup()
    if self.socket then
        simZMQ.close(self.socket)
        self.socket = nil
    end
end

function ZMQRemoteAPI:__gc()
    self:cleanup()
end

function ZMQRemoteAPI:log(level, ...)
    if level <= self.verbose then
        local id = 'ZMQRemoteAPI'
        if self.name then id = id .. '[' .. self.name .. ']' end
        print(id, ...)
    end
end

function ZMQRemoteAPI:callLocal(funcName, args, successCallback, errorCallback)
    assert(type(funcName) == 'string', 'invalid function name')
    local func = _G[funcName]
    assert(func, 'no such function: ' .. funcName)
    assert(type(func) == 'function', 'not a function: ' .. funcName)
    args = args or {}
    assert(type(args) == 'table', 'invalid args')
    return table.pack(func(table.unpack(args or {})))
end

function ZMQRemoteAPI:call(funcName, ...)
    assert(type(funcName) == 'string', 'invalid function name')
    local args = table.pack(...)
    self:send{msg = 'call', func = funcName, args = args}
    while true do
        local rep = self:recv(true)
        if rep.msg == 'result' then
            if rep.error then
                error(rep.result)
            else
                return table.unpack(rep.result)
            end
        else
            self:handleRequest(rep)
        end
    end
end

function ZMQRemoteAPI:registerCallbackLocal(funcName)
    assert(type(funcName) == 'string', 'invalid function name')
    _G[funcName] = function(...)
        return self:call(funcName, ...)
    end
end

function ZMQRemoteAPI:registerCallback(funcName)
    self:send{msg = 'registerCallback', func = funcName}
    local rep = self:recv(true)
    assert(rep.msg == 'result', 'invalid server reply')
    assert(not rep.error, 'registerCallback failed')
end

function ZMQRemoteAPI:handleRequest(req)
    assert(type(req.msg) == 'string', 'malformed request')
    if req.msg == 'call' then
        local ok, result = pcall(self.callLocal, self, req.func, req.args)
        self:send{msg = 'result', error = not ok, result = result}
    elseif req.msg == 'registerCallback' then
        local ok, result = pcall(self.registerCallbackLocal, self, req.func)
        self:send{msg = 'result', error = not ok, result = result}
    else
        self:log(1, 'unsupported message:', req.msg)
    end
end

function ZMQRemoteAPI:handleRequests()
    assert(self.server, 'handleRequests should be called only from server')
    while true do
        local req = self:recv()
        if not req then break end
        self:handleRequest(req)
    end
end

function ZMQRemoteAPI:send(msg)
    assert(self.socket)
    assert(type(msg) == 'table', 'bad type')
    self:log(2, 'sending:', msg)
    local data = simCBOR.encode(msg)
    simZMQ.send(self.socket, data, 0)
    self:log(2, 'sent')
end

function ZMQRemoteAPI:recv(block)
    assert(self.socket)
    if block then
        self:log(2, 'receiving... (block)')
    end
    local r, data = simZMQ.recv(self.socket, block and 0 or simZMQ.NOBLOCK)
    if r == -1 then return end
    local ok, req = pcall(simCBOR.decode, data)
    if not ok then
        self:log(1, 'invalid request CBOR data')
        return
    end
    self:log(2, 'received:', req)
    return req
end

return ZMQRemoteAPI
