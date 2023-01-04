require'configUi'

function sysCall_init()
    self=sim.getObject'.'
    states=sim.readCustomTableData(self,'path')
    state=ObjectProxy'./State'
    speed=speed or 1
    configUi=ConfigUI('robotConfigPath',{
        show={name='Show state',type='bool',ui={order=1,},},
        state={name='State index',type='int',minimum=1,maximum=#states,ui={order=2,},},
    },function(config)
        if config.show and not state:hasModelClone() then
            state:createModelClone()
        elseif not config.show and state:hasModelClone() then
            state:removeModelClone()
        end
        if state:hasModelClone() then
            state:setConfig(states[config.state])
        end
    end)
end

-- for some reason, this is required to make configUi function normally:
function sysCall_nonSimulation()
end

function ObjectProxy(p,t)
    t=t or sim.scripttype_customizationscript
    return sim.getScriptFunctions(sim.getScript(t,sim.getObject(p)))
end
