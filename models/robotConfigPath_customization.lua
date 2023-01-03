function sysCall_init()
    self=sim.getObject'.'
    states=sim.readCustomTableData(self,'path')
    state=ObjectProxy'./State'
    speed=speed or 1
end

function sysCall_userConfig()
    if corout then
        corout=nil
        fastIdleLoop(false)
    else
        corout=coroutine.create(function()
            fastIdleLoop(true)
            state:createModelClone()
            for i=1,#states,speed do
                state:setConfig(states[i])
                sim.switchThread()
                sim.wait(0.001,false)
            end
            state:removeModelClone()
            fastIdleLoop(false)
            corout=nil
        end)
    end
end

function sysCall_nonSimulation()
    if not corout then return end
    if coroutine.status(corout)~='dead' then
        local ok,errorMsg=coroutine.resume(corout)
        if errorMsg then
            error(debug.traceback(corout,errorMsg),2)
        end
    end
end

function ObjectProxy(p,t)
    t=t or sim.scripttype_customizationscript
    return sim.getScriptFunctions(sim.getScript(t,sim.getObject(p)))
end

function fastIdleLoop(enable)
    if fast and not enable then
        fast=false
        sim.setThreadAutomaticSwitch(tas)
        sim.fastIdleLoop(false)
    elseif not fast and enable then
        fast=true
        tas=sim.setThreadAutomaticSwitch(false)
        sim.fastIdleLoop(true)
    end
end
