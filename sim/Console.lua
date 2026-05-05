local CustomClass = require 'sim.CustomClass'

local Console = CustomClass 'console'

Console:setColorProperty('background', Color 'white')
Console:setColorProperty('defaultColor', Color 'black')
Console:setBoolProperty('hiddenInSimulation', false)
Console:setBoolProperty('visible', true)
Console:setStringProperty('ui', '')
Console:setStringProperty('title', 'console')
Console:setIntProperty('size.width', 800)
Console:setIntProperty('size.height', 600)
Console:setIntProperty('position.x', 50)
Console:setIntProperty('position.y', 50)
Console:setBoolProperty('closeable', true)
Console:setBoolProperty('resizable', true)
Console:setIntProperty('fontSize', 12)
Console:setIntProperty('sceneUid', -1)
Console:setStringProperty('text', '')
Console:setStringProperty('html', '')

function Console:init()
    local xml = string.renderxml{
        tag = 'ui',
        attrs = {
            title = self.title,
            closeable = self.closeable,
            resizable = self.resizable,
            ['on-close'] = self.handle .. ':onClose',
            placement = 'relative',
            position = self.position.x .. ',' .. self.position.y,
            width = self.size.width,
            height = self.size.height,
            activate = false,
        },
        children = {
            {
                tag = 'text-browser',
                attrs = {
                    id = 1,
                    style = ''
                        .. 'font-family: "Courier New", "Consolas", "Liberation Mono", "DejaVu Sans Mono"; '
                        .. 'font-size: ' .. self.fontSize .. 'pt; '
                        .. 'background-color: ' .. self.background:html() .. '; '
                        .. 'color: ' .. self.defaultColor:html() .. ';',
                    ['read-only'] = true,
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

function Console:onClose(ui)
    self:remove()
end

function Console:visible_get_(pname, currentValue)
    local simUI = require 'simUI'
    return simUI.isVisible(self.ui)
end

function Console:visible_set_(pname, setValue)
    local simUI = require 'simUI'
    if setValue then
        simUI.show(self.ui)
    else
        simUI.hide(self.ui)
    end
    return setValue
end

function Console:beforeInstanceSwitch()
    if self.sceneUid ~= -1 then
        self.visible = false
    end
end

function Console:afterInstanceSwitch()
    local sim = require 'sim-2'
    if self.sceneUid ~= -1 and sim.scene.uid == self.sceneUid then
        self.visible = true
    end
end

function Console:beforeSimulation()
    if self.hiddenInSimulation then
        self.visible = false
    end
end

function Console:afterSimulation()
    if self.hiddenInSimulation then
        self.visible = true
    end
end

function Console:print(text, color)
    assert(self.ui ~= '')

    local simUI = require 'simUI'

    self.text = self.text .. text

    self.html = self.html .. string.format(
        '<span style="color: %s;">%s</span>',
        Color:tocolor(color or self.defaultColor):html(),
        string.escapehtml(text):gsub("\n", "<br>")
    )

    simUI.setText(self.ui, 1, self.html)
end

function Console:clear()
    assert(self.ui ~= '')

    local simUI = require 'simUI'

    self.text = ''
    self.html = ''
    simUI.setText(self.ui, 1, "")
end

function Console:cleanup()
    assert(self.ui ~= '')

    local simUI = require 'simUI'

    simUI.destroy(self.ui)
    self.ui = ''

    sim.self:removeFunctionHook('sysCall_beforeInstanceSwitch', self.handle .. ':beforeInstanceSwitch', false)
    sim.self:removeFunctionHook('sysCall_afterInstanceSwitch', self.handle .. ':afterInstanceSwitch', false)

    if sim.self.scriptType ~= sim.scripttype_simulation and sim.self.scriptType ~= sim.scripttype_main then
        sim.self:removeFunctionHook('sysCall_beforeSimulation', self.handle .. ':beforeSimulation', false)
        sim.self:removeFunctionHook('sysCall_afterSimulation', self.handle .. ':afterSimulation', false)
    end
end

return Console
