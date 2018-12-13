local simB0={}

--@fun spin Call spinOnce() continuously
--@arg string handle the node handle
function simB0.nodeSpin(handle)
    while sim.getSimulationState()~=sim.simulation_advancing_abouttostop do
        simB0.nodeSpinOnce(handle)
        sim.switchThread()
    end
end

--@fun pingResolver Check if resolver node is reachable
function simB0.pingResolver()
    local dummyNode=simB0.nodeCreate('dummyNode')
    simB0.nodeSetAnnounceTimeout(dummyNode, 2000) -- 2 seconds timeout
    local running=pcall(function() simB0.nodeInit(dummyNode) end)
    if running then simB0.nodeCleanup(dummyNode) end
    simB0.nodeDestroy(dummyNode)
    return running
end

return simB0
