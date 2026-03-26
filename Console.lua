local class = require 'middleclass'
local sim = require 'sim-2'
local Color = require 'Color'
local simUI = require 'simUI'

local Console = class 'Console'

if not __2.consoles then
    __2.consoles = {}
    __2.consoles.map = {}
end

function Console:initialize(opts)
    opts = opts or {}
    local title = opts.title or "console"
    local size = opts.size or {800, 600}
    local closeable = opts.closeable
    if closeable == nil then closeable = true end
    local position = opts.position or {50, 50}
    self.defaultColor = opts.color or Color({0.0, 0.0, 0.0})
    if not Color:iscolor(self.defaultColor) then
        self.defaultColor = Color(self.defaultColor)
    end
    local background = opts.background or Color({1.0, 1.0, 1.0})
    if not Color:iscolor(background) then
        background = Color(background)
    end
    local style = opts.style
    self.hiddenInSimulation = opts.hiddenInSimulation or false
    local resizable = opts.resizable
    if resizable == nil then resizable = true end
    local fontSize = opts.fontSize or 12
    if style == nil then
        style = string.format("font-family: 'Courier New', 'Consolas', 'Liberation Mono', 'DejaVu Sans Mono'; font-size: %dpt; background-color: %s; color: %s;", fontSize, background:html(), self.defaultColor:html())
    end
    
     local xml = string.format([[
        <ui title="%s" closeable="%s" resizable="%s" on-close="__2.consoles.onClose" placement="relative" position="%d,%d" width="%d" height="%d" activate="false">
            <text-browser id="1" style="%s" read-only="true" />
        </ui>
    ]],
        title,
        tostring(closeable),
        tostring(resizable),
        position[1], position[2],
        size[1], size[2],
        style
    )

    self.notVisible = 0

    self.ui = simUI.create(xml)
    self.text = ''
    self.html = ''

    sim.self:registerFunctionHook('sysCall_beforeInstanceSwitch', '__2.consoles.beforeInstanceSwitch', false)
    sim.self:registerFunctionHook('sysCall_afterInstanceSwitch', '__2.consoles.afterInstanceSwitch', false)
    
    if sim.self.scriptType ~= sim.scripttype_simulation and sim.self.scriptType ~= sim.scripttype_main then
        sim.self:registerFunctionHook('sysCall_beforeSimulation', '__2.consoles.beforeSimulation', false)
        sim.self:registerFunctionHook('sysCall_afterSimulation', '__2.consoles.afterSimulation', false)
    end
    __2.consoles.map[self.ui] = self
end

function __2.consoles.onClose(ui)
    local self = __2.consoles.map[ui]
    if self then
        self:remove()
    end
end

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

function __2.consoles.beforeInstanceSwitch()
    if sim.self.scriptType == sim.scripttype_customization then
        for ui, self in pairs(__2.consoles.map) do
            self:setVisible(false)
        end
    end
end

function __2.consoles.afterInstanceSwitch()
    if sim.self.scriptType == sim.scripttype_customization then
        for ui, self in pairs(__2.consoles.map) do
            self:setVisible(true)
        end
    end
end

function __2.consoles.beforeSimulation()
    for ui, self in pairs(__2.consoles.map) do
        if self.hiddenInSimulation then
            self:setVisible(false)
        end
    end
end

function __2.consoles.afterSimulation()
    for ui, self in pairs(__2.consoles.map) do
        if self.hiddenInSimulation then
            self:setVisible(true)
        end
    end
end

function Console:print(text, color)
    assert(self.ui, "Cannot print to a closed console")
    color = color or self.defaultColor
    if not Color:iscolor(color) then
        color = Color(color)
    end
    
    self.text = self.text .. text

    local escaped = text:gsub("&", "&amp;")
                        :gsub("<", "&lt;")
                        :gsub(">", "&gt;")

    escaped = escaped:gsub("\n", "<br>")

    local html = string.format('<span style="color:%s;">%s</span>', color:html(), escaped)
    self.html = self.html .. html
    simUI.setText(self.ui, 1, self.html)
end

function Console:clear()
    self.text = ''
    self.html = ''
    simUI.setText(self.ui, 1, "")
end

function Console:remove()
    if self.ui then
        simUI.destroy(self.ui)
        __2.consoles.map[self.ui] = nil
        self.ui = nil
    end
end

function Console:__gc()
    if self.ui then
        -- Log a warning: this means someone forgot to call :remove()
        io.stderr:write("WARNING: Console garbage collected without being closed!\n")
        self:remove()
    end
end

-- Ensure __gc is in the metatable early (Lua 5.2+)
Console.__instanceDict.__gc = Console.__instanceDict.__gc or function() end

return Console