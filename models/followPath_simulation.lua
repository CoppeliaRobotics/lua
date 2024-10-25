sim = require 'sim'

function sysCall_init()
    self = sim.getObject '.'
    path = sim.getReferencedHandle(self, 'path')
    jointGroup = sim.getReferencedHandle(path, 'jointGroup')
    path = sim.getScriptFunctions(path)
    jointGroup = sim.getScriptFunctions(jointGroup)
    P = Matrix:fromtable(path:getPath())
    params = params or {}
    params.fkMaxVel = params.fkMaxVel or table.rep(1, P:cols())
    params.fkMaxAccel = params.fkMaxAccel or table.rep(5, P:cols())
end

function setTargetConfig(p)
    jointGroup:setConfig(p)
end

function sysCall_thread()
    local minMaxVel = {}
    local minMaxAccel = {}
    for i = 1, P:cols() do
        for _, k in ipairs{-1, 1} do
            table.insert(minMaxVel, k * params.fkMaxVel[i])
            table.insert(minMaxAccel, k * params.fkMaxAccel[i])
        end
    end
    local pathData = P:data()
    local pathLen = sim.getPathLengths(P:data(), P:cols())

    if followPathScript == nil then
        followPathScript = -1 -- recycle this script in next calls!
    end
    pathPts, times, followPathScript = sim.generateTimeOptimalTrajectory(pathData, pathLen, minMaxVel, minMaxAccel, 1000, 'not-a-knot', 5, followPathScript)

    local st = sim.getSimulationTime()
    local dt = 0
    while dt < times[#times] do
        local p = sim.getPathInterpolatedConfig(pathPts, times, dt)
        setTargetConfig(p)
        sim.step()
        dt = sim.getSimulationTime() - st
    end
    local p = sim.getPathInterpolatedConfig(pathPts, times, times[#times])
    setTargetConfig(p)
end
