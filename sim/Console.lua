local CustomClass = require 'sim.CustomClass'

local Console = CustomClass('console', {
    background = Color 'white',
    defaultColor = Color 'black',
    hiddenInSimulation = false,
    visible = true,
    ui = '',
    title = 'console',
    ['size.width'] = 800,
    ['size.height'] = 600,
    ['position.x'] = 50,
    ['position.y'] = 50,
    closeable = true,
    resizable = true,
    fontSize = 12,
    --notVisible = 0,
    text = '',
    html = '',
})

if not __2.consoles then
    __2.consoles = {}
end

function Console:init()
    local style = string.format(
        "font-family: 'Courier New', 'Consolas', 'Liberation Mono', 'DejaVu Sans Mono'; " ..
        "font-size: %dpt; " ..
        "background-color: %s; " ..
        "color: %s;",
        self.fontSize,
        self.background:html(),
        self.defaultColor:html())
    local xml = string.format(
        [[<ui
                title="%s"
                closeable="%s"
                resizable="%s"
                on-close="__2.consoles.onClose"
                placement="relative"
                position="%d,%d"
                width="%d"
                height="%d"
                activate="false"
        >
            <text-browser id="1" style="%s" read-only="true" />
        </ui>]],
        self.title,
        tostring(self.closeable),
        tostring(self.resizable),
        self.position.x, self.position.y,
        self.size.width, self.size.height,
        style
    )
    local simUI = require 'simUI'
    self.ui = simUI.create(xml)

    local sim = require 'sim-2'
    sim.self:registerFunctionHook('sysCall_beforeInstanceSwitch', '__2.consoles.beforeInstanceSwitch', false)
    sim.self:registerFunctionHook('sysCall_afterInstanceSwitch', '__2.consoles.afterInstanceSwitch', false)

    if sim.self.scriptType ~= sim.scripttype_simulation and sim.self.scriptType ~= sim.scripttype_main then
        sim.self:registerFunctionHook('sysCall_beforeSimulation', '__2.consoles.beforeSimulation', false)
        sim.self:registerFunctionHook('sysCall_afterSimulation', '__2.consoles.afterSimulation', false)
    end
end

function __2.consoles.onClose(ui)
    local sim = require 'sim-2'
    for _, o in ipairs(sim.app.customObjects) do
        if o.objectType == 'console' and o.ui == ui then
            o:remove()
        end
    end
end

--[[
function Console:setVisible(v)
    if v then
        if self.notVisible > 0 then
            self.notVisible = self.notVisible - 1
            if self.notVisible == 0 then
                simUI.show(self.ui)
            end
        end
    else
        self.notVisible = self.notVisible + 1
        if self.notVisible == 1 then
            simUI.hide(self.ui)
        end
    end
end
]]

function Console:setVisible(v)
    local simUI = require 'simUI'
    self.visible = v
    if self.visible then
        simUI.show(self.ui)
    else
        simUI.hide(self.ui)
    end
end

function __2.consoles.beforeInstanceSwitch()
    if sim.self.scriptType == sim.scripttype_customization then
        for _, o in ipairs(sim.app.customObjects) do
            if o.objectType == 'console' then
                o:setVisible(false)
            end
        end
    end
end

function __2.consoles.afterInstanceSwitch()
    if sim.self.scriptType == sim.scripttype_customization then
        for _, o in ipairs(sim.app.customObjects) do
            if o.objectType == 'console' then
                o:setVisible(true)
            end
        end
    end
end

function __2.consoles.beforeSimulation()
    for _, o in ipairs(sim.app.customObjects) do
        if o.objectType == 'console' and o.hiddenInSimulation then
            o:setVisible(false)
        end
    end
end

function __2.consoles.afterSimulation()
    for _, o in ipairs(sim.app.customObjects) do
        if o.objectType == 'console' and o.hiddenInSimulation then
            o:setVisible(true)
        end
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
