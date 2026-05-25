local class = require 'middleclass'
local sim = require 'sim-2'
local simCBOR = require 'simCBOR'
local simZMQ = require 'simZMQ'
local uuid = require 'uuid'
simZMQ.__raiseErrors()

local ZMQRemoteAPI = class 'sim.ZMQRemoteAPI'

function ZMQRemoteAPI:initialize(opts)
    opts = opts or {}
    self.name = opts.name
    self.server = not not opts.server
    self.verbose = tonumber(opts.verbose or 0)

    self.clientID = math.random(1 << 10, 1 << 24)
    self.pendingRequests = {}
    local ctx = simZMQ.ctx_singleton()
    local host = opts.host or '127.0.0.1'
    local port = opts.port or 24020
    self.socket = simZMQ.socket(ctx, simZMQ[opts.socketType or 'DEALER'])
    if opts.server then
        simZMQ.bind(self.socket, 'tcp://*:' .. port)
    else
        simZMQ.connect(self.socket, 'tcp://' .. host .. ':' .. port)
    end
end

function ZMQRemoteAPI:__gc()
    if self.socket then
        simZMQ.close(self.socket)
        self.socket = nil
    end
end

function ZMQRemoteAPI:log(level, ...)
    if level <= self.verbose then
        local id = string.format('ZMQRemoteAPI[%s%sid=%d]', self.name or '', self.name and ', ' or '', self.clientID)
        print(id, ...)
    end
end

function ZMQRemoteAPI:generateRequestID()
    local id = self.nextRequestID or 1000
    self.nextRequestID = id + 1
    return id
end

function ZMQRemoteAPI:callLocal(funcName, args, successCallback, errorCallback)
    local ok, result = pcall(function()
        assert(type(funcName) == 'string', 'invalid function name')
        local func = _G[funcName]
        assert(func, 'no such function: ' .. funcName)
        assert(type(func) == 'function', 'not a function: ' .. funcName)
        args = args or {}
        assert(type(args) == 'table', 'invalid args')
        return table.pack(func(table.unpack(args or {})))
    end)
    if ok then
        successCallback(result)
    else
        errorCallback(result)
    end
end

function ZMQRemoteAPI:callRemote(funcName, args, successCallback, errorCallback)
    local id = self:generateRequestID()
    self.pendingRequests[id] = {
        successCallback = successCallback,
        errorCallback = errorCallback,
    }
    self:send{
        client_id = self.clientID,
        req_id = id,
        msg = 'call',
        func = funcName,
        args = args,
    }
end

function ZMQRemoteAPI:registerCallbackLocal(funcName)
    assert(type(funcName) == 'string', 'invalid function name')
    _G[funcName] = function(...)
        self:callLocal(funcName, ...)
    end
end

function ZMQRemoteAPI:registerCallbackRemote(funcName)
    self:send{
        client_id = self.clientID,
        msg = 'registerCallback',
        func = funcName,
    }
end

function ZMQRemoteAPI:handleRequest(req)
    assert(type(req.msg) == 'string', 'malformed request')
    assert(math.type(req.client_id) == 'integer', 'malformed request')
    if req.msg == 'call' then
        assert(math.type(req.req_id) == 'integer', 'malformed request')
        self:callLocal(req.func, req.args,
            function(result)
                self:send{
                    msg = 'result',
                    client_id = req.client_id,
                    req_id = req.req_id,
                    error = false,
                    result = result,
                }
            end,
            function(err)
                self:send{
                    msg = 'result',
                    client_id = req.client_id,
                    req_id = req.req_id,
                    error = true,
                    result = err,
                }
            end
        )
    elseif req.msg == 'registerCallback' then
        self:registerCallbackLocal(req.func)
    elseif req.msg == 'result' then
        if self.pendingRequests[req.req_id] then
            if req.error then
                self.pendingRequests[req.req_id].errorCallback(req.result)
            else
                self.pendingRequests[req.req_id].successCallback(req.result)
            end
            self.pendingRequests[req.req_id] = nil
        else
            self:log(1, 'got result without matching request id ' .. req.req_id)
        end
    else
        self:log(1, 'unsupported message:', req.msg)
    end
end

function ZMQRemoteAPI:handleRequests()
    while true do
        local req = self:recv()
        if not req then break end
        self:handleRequest(req)
    end
end

function ZMQRemoteAPI:send(msg)
    assert(type(msg) == 'table', 'bad type')
    self:log(2, 'sending:', msg)
    local data = simCBOR.encode(msg)
    simZMQ.send(self.socket, data, 0)
end

function ZMQRemoteAPI:recv()
    local r, data = simZMQ.__noError.recv(self.socket, simZMQ.NOBLOCK)
    if r == -1 then return end
    local ok, req = pcall(simCBOR.decode, data)
    if ok then
        self:log(2, 'received:', req)
        return req
    else
        self:log(1, 'invalid request CBOR data')
    end
end

return ZMQRemoteAPI
