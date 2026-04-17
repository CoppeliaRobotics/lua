local CustomClass = require 'sim.CustomClass'

local Console = CustomClass('console', function(cls)
    cls:setColorProperty('background', Color 'white')
    cls:setColorProperty('defaultColor', Color 'black')
    cls:setBoolProperty('hiddenInSimulation', false)
    cls:setBoolProperty('visible', true)
    cls:setStringProperty('ui', '')
    cls:setStringProperty('title', 'console')
    cls:setIntProperty('size.width', 800)
    cls:setIntProperty('size.height', 600)
    cls:setIntProperty('position.x', 50)
    cls:setIntProperty('position.y', 50)
    cls:setBoolProperty('closeable', true)
    cls:setBoolProperty('resizable', true)
    cls:setIntProperty('fontSize', 12)
    cls:setIntProperty('sceneUid', -1)
    --cls:setIntProperty('notVisible', 0)
    cls:setStringProperty('text', '')
    cls:setStringProperty('html', '')
end)

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

    if sim.self.scriptType ~= sim.scripttype_simulation and sim.self.scriptType ~= sim.scripttype_main then
        sim.self:registerFunctionHook('sysCall_beforeSimulation', self.handle .. ':beforeSimulation', false)
        sim.self:registerFunctionHook('sysCall_afterSimulation', self.handle .. ':afterSimulation', false)
    end
end

function Console:onClose(ui)
    self:remove()
end

function Console:setVisible(v)
    local simUI = require 'simUI'
    self.visible = v
    if self.visible then
        simUI.show(self.ui)
    else
        simUI.hide(self.ui)
    end
end

function Console:beforeInstanceSwitch()
    if self.sceneUid ~= -1 then
        self:setVisible(false)
    end
end

function Console:afterInstanceSwitch()
    local sim = require 'sim-2'
    if self.sceneUid ~= -1 and sim.scene.sceneUid == self.sceneUid then
        self:setVisible(true)
    end
end

function Console:beforeSimulation()
    if self.hiddenInSimulation then
        self:setVisible(false)
    end
end

function Console:afterSimulation()
    if self.hiddenInSimulation then
        self:setVisible(true)
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

function Console:remove()
    assert(self.ui ~= '')

    local simUI = require 'simUI'

    simUI.destroy(self.ui)
    self.ui = ''

    sim.app:removeCustomObject(self.handle)
end

--[[
function Console:__gc()
    if self.ui ~= '' then
        -- Log a warning: this means someone forgot to call :remove()
        io.stderr:write("WARNING: Console garbage collected without being closed!\n")
        self:remove()
    end
end

-- Ensure __gc is in the metatable early (Lua 5.2+)
Console.__instanceDict.__gc = Console.__instanceDict.__gc or function() end
]]

return Console
