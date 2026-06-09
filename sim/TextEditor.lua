local CustomClass = require 'sim.CustomClass'

local TextEditor = CustomClass 'textEditor'

TextEditor:setColorProperty('background', Color 'white')
TextEditor:setColorProperty('defaultColor', Color 'black')
TextEditor:setBoolProperty('hiddenInSimulation', false)
TextEditor:setBoolProperty('visible', true)
TextEditor:setStringProperty('ui', '')
TextEditor:setStringProperty('title', 'editor')
TextEditor:setIntProperty('size.width', 800)
TextEditor:setIntProperty('size.height', 600)
TextEditor:setIntProperty('position.x', 50)
TextEditor:setIntProperty('position.y', 50)
TextEditor:setBoolProperty('closeable', true)
TextEditor:setBoolProperty('resizable', true)
TextEditor:setIntProperty('fontSize', 12)
if sim.self.type == sim.scripttype_sandbox or sim.self.type == sim.scripttype_addon then
    TextEditor:setIntProperty('sceneUid', -1)
else
    TextEditor:setIntProperty('sceneUid', sim.scene.uid)
end
TextEditor:setStringProperty('text', '')

function TextEditor:init()
    local xml = string.renderxml{
        tag = 'ui',
        attrs = {
            title = self.title,
            closeable = self.closeable,
            resizable = self.resizable,
            ['on-close'] = self.handle .. ':onClose',
            placement = 'relative',
            position = self.position.x .. ',' .. self.position.y,
            size = self.size.width .. ',' .. self.size.height,
            activate = false,
        },
        children = {
            {
                tag = 'text-browser',
                attrs = {
                    id = 1,
                    type = 'plain',
                    style = ''
                        .. 'font-family: "Courier New", "Consolas", "Liberation Mono", "DejaVu Sans Mono"; '
                        .. 'font-size: ' .. self.fontSize .. 'pt; '
                        .. 'background-color: ' .. self.background:html() .. '; '
                        .. 'color: ' .. self.defaultColor:html() .. ';',
                    ['read-only'] = false,
                    ['on-change'] = self.handle .. ':onChange',
                }
            },
        },
    }
    local simUI = require 'simUI'
    self.ui = simUI.create(xml)

    local sim = require 'sim-2'
    sim.self:registerFunctionHook('sysCall_beforeInstanceSwitch', self.handle .. ':beforeInstanceSwitch', false)
    sim.self:registerFunctionHook('sysCall_afterInstanceSwitch', self.handle .. ':afterInstanceSwitch', false)

    if sim.self.type ~= sim.scripttype_simulation and sim.self.type ~= sim.scripttype_main then
        sim.self:registerFunctionHook('sysCall_beforeSimulation', self.handle .. ':beforeSimulation', false)
        sim.self:registerFunctionHook('sysCall_afterSimulation', self.handle .. ':afterSimulation', false)
    end
end

function TextEditor:onClose(ui)
    self:remove()
end

function TextEditor:onChange(ui, id, newText)
    self.text = newText
end

function TextEditor:visible_get_(pname, currentValue)
    local simUI = require 'simUI'
    return simUI.isVisible(self.ui)
end

function TextEditor:visible_set_(pname, setValue)
    local simUI = require 'simUI'
    if setValue then
        simUI.show(self.ui)
    else
        simUI.hide(self.ui)
    end
    return setValue
end

function TextEditor:beforeInstanceSwitch()
    if self.sceneUid ~= -1 then
        self.visible = false
    end
end

function TextEditor:afterInstanceSwitch()
    local sim = require 'sim-2'
    if self.sceneUid ~= -1 and sim.scene.uid == self.sceneUid then
        self.visible = true
    end
end

function TextEditor:beforeSimulation()
    if self.hiddenInSimulation then
        self.visible = false
    end
end

function TextEditor:afterSimulation()
    if self.hiddenInSimulation then
        self.visible = true
    end
end

function TextEditor:cleanup()
    assert(self.ui ~= '')

    local simUI = require 'simUI'

    simUI.destroy(self.ui)
    self.ui = ''

    sim.self:removeFunctionHook('sysCall_beforeInstanceSwitch', self.handle .. ':beforeInstanceSwitch', false)
    sim.self:removeFunctionHook('sysCall_afterInstanceSwitch', self.handle .. ':afterInstanceSwitch', false)

    if sim.self.type ~= sim.scripttype_simulation and sim.self.type ~= sim.scripttype_main then
        sim.self:removeFunctionHook('sysCall_beforeSimulation', self.handle .. ':beforeSimulation', false)
        sim.self:removeFunctionHook('sysCall_afterSimulation', self.handle .. ':afterSimulation', false)
    end
end

return TextEditor
