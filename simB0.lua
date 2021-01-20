local simB0={}

--@fun nodeSpin Call nodeSpinOnce() continuously
--@arg string handle the node handle
function simB0.nodeSpin(handle)
    while sim.getSimulationState()~=sim.simulation_advancing_abouttostop do
        simB0.nodeSpinOnce(handle)
        sim.switchThread()
    end
end

--@fun pingResolver Check if resolver node is reachable
--@ret bool running true if the resolver node is running and reachable
function simB0.pingResolver()
    local dummyNode=simB0.nodeCreate('dummyNode')
    simB0.nodeSetAnnounceTimeout(dummyNode, 2000) -- 2 seconds timeout
    local running=pcall(function() simB0.nodeInit(dummyNode) end)
    if running then simB0.nodeCleanup(dummyNode) end
    simB0.nodeDestroy(dummyNode)
    return running
end

--@fun serviceClientCallJSON wrap serviceClientCall with JSON encoding/decoding
--@arg string serviceClientHandle the service client handle
--@arg table request a Lua table to be serialized with JSON
--@ret table response a Lua table with the deserialized JSON payload
function simB0.serviceClientCallJSON(serviceClientHandle,request)
    local dkjson=require 'dkjson'
    return dkjson.decode(simB0.serviceClientCall(serviceClientHandle,dkjson.encode(request)))
end

return simB0
