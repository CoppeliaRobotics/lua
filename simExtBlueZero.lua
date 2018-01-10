local simB0={}

--@fun spin
--@arg string handle the node handle
function simB0.spin(handle)
    while sim.getSimulationState()~=sim.simulation_advancing_abouttostop do
        simB0.spinOnce(handle)
        sim.switchThread()
    end
end

return simB0
