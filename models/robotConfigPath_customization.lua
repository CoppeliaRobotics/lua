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
        showTipPath={
            name='Show tip path (cartesian)',
            type='bool',
            ui={order=20,col=1,group=2,},
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

        if config.showTipPath and not tipPathDwo then
            local del=not state:hasModelClone()
            tipPathDwo=sim.addDrawingObject(sim.drawing_linestrip,3,0,-1,999999,{0,1,1})
            local origCfg=nil
            if del then
                state:createModelClone()
            else
                origCfg=state:getConfig()
            end
            local tip=-1
            sim.visitTree(self,function(handle)
                if sim.readCustomDataBlock(handle,'ikTip') then
                    tip=handle
                    return false
                end
            end)
            for i=1,#states do
                state:setConfig(states[i])
                sim.addDrawingObjectItem(tipPathDwo,sim.getObjectPosition(tip,-1))
            end
            if del then
                state:removeModelClone()
            else
                state:setConfig(origCfg)
            end
        elseif not config.showTipPath and tipPathDwo then
            sim.removeDrawingObject(tipPathDwo)
            tipPathDwo=nil
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
