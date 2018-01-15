local simB0={}

--@fun spin Call spinOnce() continuously
--@arg string handle the node handle
function simB0.spin(handle)
    while sim.getSimulationState()~=sim.simulation_advancing_abouttostop do
        simB0.spinOnce(handle)
        sim.switchThread()
    end
end

--@fun pingResolver Check if resolver node is reachable
function simB0.pingResolver()
    local dummyNode=simB0.create('dummyNode')
    simB0.setAnnounceTimeout(dummyNode, 2000) -- 2 seconds timeout
    local running=pcall(function() simB0.init(dummyNode) end)
    if running then simB0.cleanup(dummyNode) end
    simB0.destroy(dummyNode)
    return running
end

return simB0
