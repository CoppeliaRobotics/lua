sim = require 'sim'
require 'configUi'

function sysCall_init()
    self = sim.getObject '.'
    states = sim.readCustomTableData(self, 'path')
    state = ObjectProxy './State'
    configUi = ConfigUI(
        'robotConfigPath',
        {
            showState = {
                name = 'Show state',
                type = 'bool',
                ui = {order = 10, col = 1}
            },
            stateIndex = {
                name = 'State index',
                type = 'int',
                minimum = 1,
                maximum = #states,
                ui = {order = 12, col = 2},
            },
            showTipPath = {
                name = 'Show tip path (cartesian)',
                type = 'bool',
                ui = {order = 20, col = 1, group = 2},
            },
            createVolumeSweepOctree = {
                name = 'Create volume sweep (octree)',
                default = '',
                callback = function()
                    local del = not state:hasModelClone()
                    local octree = sim.createOctree(0.02, 0, 0)
                    if del then
                        state:createModelClone()
                    else
                        origCfg = state:getConfig()
                    end
                    for i = 1, #states do
                        state:setConfig(states[i])
                        sim.visitTree(
                            sim.getObject './State', function(h)
                                sim.insertObjectIntoOctree(octree, h, 0)
                            end
                        )
                    end
                    if del then
                        state:removeModelClone()
                    else
                        state:setConfig(origCfg)
                    end
                end,
                ui = {order = 30, group = 3},
            },
            createVolumeSweepIGL = {
                name = 'Create volume sweep (IGL)',
                default = '',
                callback = function()
                    simIGL = require 'simIGL'
                    local del = not state:hasModelClone()
                    if del then
                        state:createModelClone()
                    else
                        origCfg = state:getConfig()
                    end
                    local shapes = {}
                    for i = 1, #states do
                        state:setConfig(states[i])
                        sim.visitTree(
                            sim.getObject './State', function(h)
                                if sim.getObjectType(h) ~= sim.sceneobject_shape then
                                    return
                                end
                                local v = sim.getObjectInt32Param(
                                              h, sim.objintparam_visibility_layer
                                          )
                                if v & 15 == 0 then return end
                                shapes[h] = shapes[h] or {}
                                shapes[h][i] = sim.getObjectMatrix(h)
                            end
                        )
                    end
                    local sweptShapes = {}
                    for shape, transforms in pairs(shapes) do
                        local v, i, n = sim.getShapeMesh(shape)
                        local mesh = {vertices = v, indices = i}
                        function transform(t)
                            t = math.floor(1 + t * (#states - 1) + 0.5)
                            return transforms[t]
                        end
                        local sweptMesh = simIGL.sweptVolume(mesh, 'transform', #states, 40)
                        local newShape = sim.createShape(
                                             3, math.pi / 4, sweptMesh.vertices, sweptMesh.indices
                                         )
                        table.insert(sweptShapes, newShape)
                    end
                    sim.setObjectAlias(sim.groupShapes(sweptShapes), 'VolumeSweep')
                    if del then
                        state:removeModelClone()
                    else
                        state:setConfig(origCfg)
                    end
                end,
                ui = {order = 40, group = 3},
            },
        },
        function(config)
            if config.showState and not state:hasModelClone() then
                state:createModelClone()
            elseif not config.showState and state:hasModelClone() then
                state:removeModelClone()
            end
            if state:hasModelClone() then state:setConfig(states[config.stateIndex]) end

            if config.showTipPath and not tipPathDwo then
                local del = not state:hasModelClone()
                tipPathDwo = sim.addDrawingObject(sim.drawing_linestrip, 3, 0, -1, 999999, {0, 1, 1})
                local origCfg = nil
                if del then
                    state:createModelClone()
                else
                    origCfg = state:getConfig()
                end
                local tip = -1
                sim.visitTree(
                    self, function(handle)
                        local _dat = sim.readCustomStringData(handle, 'ikTip')
                        if _dat and #_dat > 0 then
                            tip = handle
                            return false
                        end
                    end
                )
                for i = 1, #states do
                    state:setConfig(states[i])
                    sim.addDrawingObjectItem(tipPathDwo, sim.getObjectPosition(tip))
                end
                if del then
                    state:removeModelClone()
                else
                    state:setConfig(origCfg)
                end
            elseif not config.showTipPath and tipPathDwo then
                sim.removeDrawingObject(tipPathDwo)
                tipPathDwo = nil
            end
        end
    )
end

function getPath()
    return states
end

-- for some reason, this is required to make configUi function normally:
function sysCall_nonSimulation()
end

function ObjectProxy(p, t)
    t = t or sim.scripttype_customization
    return sim.getScriptFunctions(sim.getScript(t, sim.getObject(p)))
end
