require'configUi'

function sysCall_init()
    self=sim.getObject'.'
    states=sim.readCustomTableData(self,'path')
    state=ObjectProxy'./State'
    configUi=ConfigUI('robotConfigPath',{
        showState={
            name='Show state',
            type='bool',
            ui={order=10,col=1,},
        },
        stateIndex={
            name='State index',
            type='int',
            minimum=1,
            maximum=#states,
            ui={order=12,col=2,},
        },
    },function(config)
        if config.showState and not state:hasModelClone() then
            state:createModelClone()
        elseif not config.showState and state:hasModelClone() then
            state:removeModelClone()
        end
        if state:hasModelClone() then
            state:setConfig(states[config.stateIndex])
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
