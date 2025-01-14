sim = require 'sim'
simUI = require 'simUI'

ConfigUI = {}

function ConfigUI:validateElemSchema(elemName, elemSchema)
    -- try to fix what is possible to fix:
    --   - infer missing information
    --   - migrate deprecated notations to current
    -- anything else -> error()

    elemSchema.key = elemSchema.key or elemName

    elemSchema.name = elemSchema.name or elemName

    elemSchema.ui = elemSchema.ui or {}

    if elemSchema.ui.fromUiValue or elemSchema.ui.toUiValue then
        assert(
            elemSchema.ui.fromUiValue and elemSchema.ui.toUiValue,
            '"fromUiValue" and "toUiValue" must be both set'
        )
        if elemSchema.minimum then
            elemSchema.ui.minimum = elemSchema.ui.toUiValue(elemSchema.minimum)
        end
        if elemSchema.maximum then
            elemSchema.ui.maximum = elemSchema.ui.toUiValue(elemSchema.maximum)
        end
    end

    -- auto-guess type if missing:
    if not elemSchema.type then
        if elemSchema.choices then
            elemSchema.type = 'choices'
        elseif elemSchema.callback then
            elemSchema.type = 'callback'
        else
            error('missing type')
        end
    end

    -- standard default value if not given:
    if elemSchema.default == nil then
        if elemSchema.type == 'string' then
            elemSchema.default = ''
        elseif elemSchema.type == 'int' or elemSchema.type == 'float' then
            elemSchema.default = 0
        elseif elemSchema.type == 'color' then
            elemSchema.default = {0.85, 0.85, 1.0}
        elseif elemSchema.type == 'bool' then
            elemSchema.default = false
        elseif elemSchema.type == 'callback' then
            elemSchema.default = ''
        end
    end

    if elemSchema.default == nil then error('missing "default" for key "' .. elemName .. '"') end

    -- auto-guess control if missing:
    if not elemSchema.ui.control then
        if elemSchema.type == 'string' then
            elemSchema.ui.control = 'edit'
        elseif elemSchema.type == 'float' and elemSchema.minimum and elemSchema.maximum then
            elemSchema.ui.control = 'slider'
        elseif elemSchema.type == 'int' or elemSchema.type == 'float' then
            elemSchema.ui.control = 'spinbox'
        elseif elemSchema.type == 'bool' then
            elemSchema.ui.control = 'checkbox'
        elseif elemSchema.type == 'color' then
            elemSchema.ui.control = 'color'
        elseif elemSchema.type == 'choices' then
            elemSchema.ui.control = 'radio'
        elseif elemSchema.type == 'callback' then
            elemSchema.ui.control = 'button'
        else
            error('missing "ui.control" and cannot infer it from type')
        end
    end

    local controlFuncs = ConfigUI.Controls[elemSchema.ui.control]
    if controlFuncs == nil then error('unknown ui control: "' .. elemSchema.ui.control .. '"') end
end

function ConfigUI:validateSchema()
    for elemName, elemSchema in pairs(self.schema) do
        local success, errorMessage = pcall(
                                          function()
                self:validateElemSchema(elemName, elemSchema)
            end
                                      )
        if not success then error('element "' .. elemName .. '": ' .. errorMessage) end
    end
end

function ConfigUI:getObject()
    if self.getObjectCallback then
        return self:getObjectCallback()
    end
    return sim.getObject '.'
end

function ConfigUI:getObjectName()
    if self.getObjectNameCallback then return self:getObjectNameCallback() end
    return sim.getObjectAlias(self:getObject(), 1)
end

function ConfigUI:readSchema()
    local schema = sim.getTableProperty(self:getObject(), 'customData.' .. self.propertyName.schema, {noError=true}) or {}
    if next(schema) ~= nil then
        self.schema = {}
        for k, v in pairs(schema) do self.schema[k] = v end
    elseif self.schema == nil then
        error('schema not provided, and not found in the custom data block ' ..  self.propertyName.schema)
    end
end

function ConfigUI:defaultConfig()
    local ret = {}
    for k, v in pairs(self.schema) do ret[k] = v.default end
    return ret
end

function ConfigUI:getConfigProperty(k)
    local nsConfig = self.propertyNamespace.config or ''
    if nsConfig ~= '' then nsConfig = nsConfig .. '.' end
    return 'customData.' .. nsConfig .. k
end

function ConfigUI:readConfigConst()
    if self.schema == nil then error('readConfig() requires schema') end
    local config = self:defaultConfig()
    for k, v in pairs(self.schema) do
        local pv = sim.getProperty(self:getObject(), self:getConfigProperty(k), {noError=true})
        if pv ~= nil then config[k] = pv end
    end
    return config
end

function ConfigUI:readConfig()
    self.config = self:readConfigConst()
end

function ConfigUI:writeConfig()
    for k, v in pairs(self.schema) do
        if self.config[k] ~= nil then
            sim.setProperty(self:getObject(), self:getConfigProperty(k), self.config[k])
        end
    end
end

function ConfigUI:showUi()
    if not self.uiHandle then
        self:readConfig()
        self:createUi()
    end
end

function ConfigUI:uiElementNextID()
    if not self.uiNextID then self.uiNextID = 1 end
    local ret = self.uiNextID
    self.uiNextID = self.uiNextID + 1
    return ret
end

function ConfigUI:splitElemsByKey(uiElemsOrdered, key, defaultValue)
    local keyNames, seenKey = {}, {}
    for _, elemName in ipairs(uiElemsOrdered) do
        if self.schema[elemName] == nil then
            error('element "' .. elemName .. '" not present in schema')
        end
        local elemSchema = self.schema[elemName]
        local value = elemSchema.ui[key] or defaultValue
        if not seenKey[value] then
            seenKey[value] = true
            table.insert(keyNames, value)
        end
    end
    local elemsSplitByKey = {}
    for _, value in ipairs(keyNames) do
        local elemsInCurrentKey = {}
        for _, elemName in ipairs(uiElemsOrdered) do
            local elemSchema = self.schema[elemName]
            if (elemSchema.ui[key] or defaultValue) == value then
                table.insert(elemsInCurrentKey, elemName)
            end
        end
        table.insert(elemsSplitByKey, elemsInCurrentKey)
    end
    return keyNames, elemsSplitByKey
end

function ConfigUI:splitElems()
    -- first order ui elements by 'order' key:
    local uiElemsOrdered = {}
    for elemName, elemSchema in pairs(self.schema) do
        elemSchema.ui = elemSchema.ui or {}
        elemSchema.ui.order = elemSchema.ui.order or 0
        table.insert(uiElemsOrdered, elemName)
    end
    table.sort(
        uiElemsOrdered, function(a, b)
            return self.schema[a].ui.order < self.schema[b].ui.order
        end
    )

    -- split uiElemsOrdered by 'tab', then by 'group', then by 'col':
    local uiElemsSplit = {}
    local tabNames, uiElemsSplitByTab = self:splitElemsByKey(uiElemsOrdered, 'tab', '')
    for tabIndex, elems in ipairs(uiElemsSplitByTab) do
        local groupNames, uiElemsSplitByGroup = self:splitElemsByKey(elems, 'group', 1)
        uiElemsSplit[tabIndex] = uiElemsSplitByGroup
        for groupIndex, elems in ipairs(uiElemsSplit[tabIndex]) do
            local columnNames, uiElemsSplitByCol = self:splitElemsByKey(elems, 'col', 1)
            uiElemsSplit[tabIndex][groupIndex] = uiElemsSplitByCol
        end
    end

    return uiElemsSplit, tabNames
end

function ConfigUI_event(ui, id)
    local self = ConfigUI.handleMap[ui]
    if self then
        local elemName = self.eventMap[id]
        self:uiEvent(elemName)
    end
end

function ConfigUI:uiEvent(elemName)
    local elemSchema = self.schema[elemName]
    local controlFuncs = ConfigUI.Controls[elemSchema.ui.control]
    if controlFuncs.onEvent then controlFuncs.onEvent(self, elemSchema) end
end

function ConfigUI:uiClosed()
    self:closeUi(true)
end

function ConfigUI:sysCall_init()
    self:readSchema()
    self:validateSchema()
    self:readConfig()
    self:writeConfig()
    self:generate()

    -- read a saved uistate here if any (see ConfigUI:sysCall_cleanup):
    self.uistate = self.uistate or {}
    local uistate = sim.getTableProperty(self:getObject(), 'signal.configUi.uistate', {noError=true})
    if uistate then
        sim.removeProperty(self:getObject(), 'signal.configUi.uistate')
        for k, v in pairs(uistate) do
            self.uistate[k] = v
        end
    end
    if self.uistate.open then self:showUi() end
end

function ConfigUI:sysCall_cleanup()
    self:closeUi(false)
    -- save uistate here so it can persist a script restart:
    sim.setTableProperty(self:getObject(), 'signal.configUi.uistate', self.uistate)
end

function ConfigUI:sysCall_userConfig()
    if sim.getSimulationState() == sim.simulation_stopped then self:showUi() end
end

function ConfigUI:sysCall_nonSimulation()
    if self.generatePending then -- and (self.generatePending+self.generationTime)<sim.getSystemTime() then
        self.generatePending = false
        self.generateCallback(self.config)
        -- sim.announceSceneContentChange() leave this out for now
    end

    -- poll for external config change:
    local newConfigPack = sim.packTable(self.config)
    if self.oldConfig and newConfigPack ~= sim.packTable(self.oldConfig) then
        self.oldConfig = sim.unpackTable(newConfigPack)
        self:configChanged() -- updates ui
        self:writeConfig()
        self:generate()
    else
        self.oldConfig = sim.unpackTable(newConfigPack)
        local newConfig = self:readConfigConst()
        if sim.packTable(newConfig) ~= sim.packTable(self.config) then
            self:readConfig()
            self:configChanged() -- updates ui
            self:writeConfig()
            self:generate()
            self.oldConfig = {table.unpack(self.config)}
        end
    end
end

function ConfigUI:sysCall_beforeSimulation()
    self:closeUi()
end

function ConfigUI:sysCall_sensing()
    self:sysCall_nonSimulation()
end

function ConfigUI:sysCall_afterSimulation()
    if self.uistate.open then self:showUi() end
end

function ConfigUI:setGenerateCallback(f)
    self.generateCallback = f
end

function ConfigUI:generate()
    if self.generateCallback then self.generatePending = true end
end

function ConfigUI:__index(k)
    return ConfigUI[k]
end

setmetatable(
    ConfigUI, {
        __call = function(meta, modelType, schema, genCb)
            local self = setmetatable({
                propertyNamespace = {
                    config = '',
                },
                propertyName = {
                    schema = '__schema__',
                },
                modelType = modelType,
                schema = schema,
                generatePending = false,
            }, meta)
            self:setGenerateCallback(genCb)
            sim.registerScriptFuncHook('sysCall_init', function() self:sysCall_init() end)
            sim.registerScriptFuncHook('sysCall_cleanup', function() self:sysCall_cleanup() end)
            sim.registerScriptFuncHook('sysCall_userConfig', function() self:sysCall_userConfig() end)
            sim.registerScriptFuncHook('sysCall_nonSimulation', function() self:sysCall_nonSimulation() end)
            sim.registerScriptFuncHook('sysCall_beforeSimulation', function() self:sysCall_beforeSimulation() end)
            sim.registerScriptFuncHook('sysCall_sensing', function() self:sysCall_sensing() end)
            sim.registerScriptFuncHook('sysCall_afterSimulation', function() self:sysCall_afterSimulation() end)
            return self
        end,
    }
)

function ConfigUI:uiElementXML(elemName, elemSchema)
    local xml = ''
    local controlFuncs = ConfigUI.Controls[elemSchema.ui.control]
    if (controlFuncs.hasLabel or function() return true end)(self, elemSchema) then
        if not elemSchema.ui.idLabel then elemSchema.ui.idLabel = self:uiElementNextID() end
        xml = xml .. string.format(
                  '<label id="%d" text="%s:" style="margin-top: 5px;" /><br/>\n',
                  elemSchema.ui.idLabel, elemSchema.name
              )
    end
    local xml2 = controlFuncs.create(self, elemSchema)
    if xml2 ~= nil then xml = xml .. xml2 .. '<br/>\n' end
    if elemSchema.ui.id then
        self.eventMap = self.eventMap or {}
        if type(elemSchema.ui.id) == 'table' then
            for val, id in ipairs(elemSchema.ui.id) do self.eventMap[id] = elemName end
        else
            self.eventMap[elemSchema.ui.id] = elemName
        end
    end
    return xml
end

function ConfigUI:createUi()
    if self.uiHandle then return end
    self.uiNextID = 1
    local xml = '<ui'
    xml = xml .. string.format(' title="%s config"', self:getObjectName())
    if self.uistate.pos then
        xml = xml ..
                  string.format(
                      ' placement="absolute" position="%d,%d" ', self.uistate.pos[1],
                      self.uistate.pos[2]
                  )
    else
        xml = xml .. ' placement="relative" position="-30,100" '
    end
    xml = xml .. ' closeable="true" on-close="ConfigUI_close"'
    xml = xml .. ' layout="vbox"'
    xml = xml .. ' content-margins="0,0,0,0"'
    xml = xml .. '>\n'
    local uiElemsSplit, tabNames = self:splitElems()
    if #tabNames > 1 then
        if not self.uiTabsID then self.uiTabsID = self:uiElementNextID() end
        xml = xml .. '<tabs id="' .. self.uiTabsID .. '">\n'
    end
    for tabIndex, tabName in ipairs(tabNames) do
        if #tabNames > 1 then
            xml = xml .. '<tab title="' .. tabName .. '" layout="vbox" content-margins="0,0,0,0">\n'
        end
        for groupIndex, groupElems in ipairs(uiElemsSplit[tabIndex]) do
            xml = xml .. '<group flat="' .. (#uiElemsSplit[tabIndex] > 0 and 'false' or 'true') ..
                      '" layout="hbox" content-margins="0,0,0,0"><!-- group ' .. groupIndex ..
                      ' -->\n'
            for colIndex, colElems in ipairs(groupElems) do
                xml = xml ..
                          '<group flat="true" layout="grid" content-margins="0,0,0,0"><!-- group ' ..
                          groupIndex .. ', col ' .. colIndex .. ' -->\n'
                for _, elemName in ipairs(colElems) do
                    xml = xml .. self:uiElementXML(elemName, self.schema[elemName])
                end
                xml = xml ..
                          '<group flat="true" layout="vbox" content-margins="0,0,0,0"><stretch/></group><!-- column vertical fill -->\n'
                xml = xml .. '</group>\n'
            end
            xml = xml .. '</group>\n'
        end
        if #tabNames > 1 then
            xml = xml .. '<stretch/><!-- tab vertical fill -->\n'
            xml = xml .. '</tab>\n'
        end
    end
    if #tabNames > 1 then xml = xml .. '</tabs>\n' end
    xml = xml .. '</ui>'
    self.uiXML = xml
    self.uiHandle = simUI.create(xml)
    if self.uiTabsID and self.uistate.currentTab then
        simUI.setCurrentTab(self.uiHandle, self.uiTabsID, self.uistate.currentTab)
    end
    ConfigUI.handleMap = ConfigUI.handleMap or {}
    ConfigUI.handleMap[self.uiHandle] = self
    self:configChanged()
end

function ConfigUI:closeUi(user)
    if self.uiHandle then
        self:saveUIPos()
        if user == true then -- closed by user -> remember uistate
            self.uistate.open = false
        end
        simUI.destroy(self.uiHandle)
        self.uiHandle = nil
        if user == false then -- has been closed programmatically, e.g. from cleanup
            self.uistate.open = true
        end
    end
end

function ConfigUI_changed(ui)
    local self = ConfigUI.handleMap[ui]
    if self then self:uiChanged() end
end

function ConfigUI_close(ui)
    local self = ConfigUI.handleMap[ui]
    if self then self:uiClosed() end
end

function ConfigUI:updateEnabledFlag()
    if not self.uiHandle then return end
    local setEnabled = self.hideDisabledWidgets and simUI.setWidgetVisibility or simUI.setEnabled
    for elemName, elemSchema in pairs(self.schema) do
        local enabled = elemSchema.ui.enabled
        if enabled == nil then enabled = true end
        if type(enabled) == 'function' then enabled = enabled(self, self.config) end
        if type(elemSchema.ui.id) == 'table' then
            for _, id in pairs(elemSchema.ui.id) do
                setEnabled(self.uiHandle, id, enabled)
            end
        else
            setEnabled(self.uiHandle, elemSchema.ui.id, enabled)
        end
        if elemSchema.ui.idLabel then
            setEnabled(self.uiHandle, elemSchema.ui.idLabel, enabled)
        end
    end
end

function ConfigUI:configChanged()
    if not self.uiHandle then return end
    for elemName, elemSchema in pairs(self.schema) do
        local v = self.config[elemName]
        if elemSchema.ui.toUiValue then v = elemSchema.ui.toUiValue(v) end
        local controlFuncs = ConfigUI.Controls[elemSchema.ui.control]
        if controlFuncs.setValue then controlFuncs.setValue(self, elemSchema, v) end
    end
    self:updateEnabledFlag()
end

function ConfigUI:uiChanged()
    for elemName, elemSchema in pairs(self.schema) do
        local v = nil
        local controlFuncs = ConfigUI.Controls[elemSchema.ui.control]
        if controlFuncs.getValue then v = controlFuncs.getValue(self, elemSchema) end
        if v ~= nil and elemSchema.ui.fromUiValue then v = elemSchema.ui.fromUiValue(v) end
        if v ~= nil and elemSchema.type == 'int' then v = math.floor(v) end
        if v ~= nil then self.config[elemName] = v end
    end
    self:writeConfig()
    self:generate()
    self:updateEnabledFlag()
end

function ConfigUI:saveUIPos()
    if self.uiHandle then
        local x, y = simUI.getPosition(self.uiHandle)
        self.uistate.pos = {x, y}
        if self.uiTabsID then
            self.uistate.currentTab = simUI.getCurrentTab(self.uiHandle, self.uiTabsID)
        end
    end
end

---------------------------------------------------------

ConfigUI.Controls = {}

ConfigUI.Controls.edit = {}

function ConfigUI.Controls.edit.create(configUi, elemSchema)
    local xml = ''
    if not elemSchema.ui.id then elemSchema.ui.id = configUi:uiElementNextID() end
    xml = xml .. '<edit'
    xml = xml .. ' id="' .. elemSchema.ui.id .. '"'
    xml = xml .. ' on-change="ConfigUI_changed"'
    xml = xml .. '/>'
    return xml
end

function ConfigUI.Controls.edit.setValue(configUi, elemSchema, value)
    simUI.setEditValue(configUi.uiHandle, elemSchema.ui.id, value)
end

function ConfigUI.Controls.edit.getValue(configUi, elemSchema)
    return simUI.getEditValue(configUi.uiHandle, elemSchema.ui.id)
end

function ConfigUI.Controls.edit.onEvent(configUi, elemSchema)
end

ConfigUI.Controls.slider = {}

function ConfigUI.Controls.slider.create(configUi, elemSchema)
    local xml = ''
    if not elemSchema.ui.id then elemSchema.ui.id = configUi:uiElementNextID() end
    if elemSchema.type == 'float' then
        if not elemSchema.ui.minimum and not elemSchema.ui.maximum then
            elemSchema.ui.minimum = 0
            elemSchema.ui.maximum = 1000
            elemSchema.ui.fromUiValue = function(x)
                x = (x - elemSchema.ui.minimum) / (elemSchema.ui.maximum - elemSchema.ui.minimum)
                return elemSchema.minimum + x * (elemSchema.maximum - elemSchema.minimum)
            end
            elemSchema.ui.toUiValue = function(x)
                x = (x - elemSchema.minimum) / (elemSchema.maximum - elemSchema.minimum)
                return elemSchema.ui.minimum + x * (elemSchema.ui.maximum - elemSchema.ui.minimum)
            end
        end
    elseif elemSchema.type == 'int' then
    else
        error('unsupported type for slider: ' .. elemSchema.type)
    end
    xml = xml .. '<hslider id="' .. elemSchema.ui.id .. '"'
    if elemSchema.ui.minimum then
        xml = xml .. ' minimum="' .. math.floor(elemSchema.ui.minimum) .. '"'
    elseif elemSchema.minimum then
        xml = xml .. ' minimum="' .. math.floor(elemSchema.minimum) .. '"'
    end
    if elemSchema.ui.maximum then
        xml = xml .. ' maximum="' .. math.floor(elemSchema.ui.maximum) .. '"'
    elseif elemSchema.maximum then
        xml = xml .. ' maximum="' .. math.floor(elemSchema.maximum) .. '"'
    end
    xml = xml .. ' on-change="ConfigUI_changed"'
    xml = xml .. '/>'
    return xml
end

function ConfigUI.Controls.slider.setValue(configUi, elemSchema, value)
    simUI.setSliderValue(configUi.uiHandle, elemSchema.ui.id, value)
end

function ConfigUI.Controls.slider.getValue(configUi, elemSchema)
    return simUI.getSliderValue(configUi.uiHandle, elemSchema.ui.id)
end

function ConfigUI.Controls.slider.onEvent(configUi, elemSchema)
end

ConfigUI.Controls.combo = {}

function ConfigUI.Controls.combo.create(configUi, elemSchema)
    local xml = ''
    assert(elemSchema.type == 'choices', 'unsupported type for combo: ' .. elemSchema.type)
    assert(elemSchema.choices, 'missing "choices"')
    local choices = elemSchema.choices
    if type(choices) == 'function' then choices = choices(configUi, elemSchema) end

    elemSchema.ui.items = {}
    for val, name in pairs(choices) do table.insert(elemSchema.ui.items, val) end
    table.sort(elemSchema.ui.items)

    elemSchema.ui.itemIndex = {}
    for index, value in ipairs(elemSchema.ui.items) do
        if elemSchema.ui.itemIndex[value] then
            error(string.format('value "%s" is not unique!', value))
        end
        elemSchema.ui.itemIndex[value] = index
    end

    if not elemSchema.ui.id then elemSchema.ui.id = configUi:uiElementNextID() end
    xml = xml .. '<combobox id="' .. elemSchema.ui.id .. '" on-change="ConfigUI_changed">'
    for _, val in ipairs(elemSchema.ui.items) do
        xml = xml .. '<item>' .. choices[val] .. '</item>'
    end
    xml = xml .. '</combobox>'
    return xml
end

function ConfigUI.Controls.combo.setValue(configUi, elemSchema, value)
    local choices = elemSchema.choices
    if type(choices) == 'function' then choices = choices(configUi, elemSchema) end
    assert(choices[value] ~= nil, 'invalid value: ' .. tostring(value))
    simUI.setComboboxSelectedIndex(
        configUi.uiHandle, elemSchema.ui.id, elemSchema.ui.itemIndex[value] - 1
    )
end

function ConfigUI.Controls.combo.getValue(configUi, elemSchema)
    local index = simUI.getComboboxSelectedIndex(configUi.uiHandle, elemSchema.ui.id)
    if index ~= -1 then
        local value = elemSchema.ui.items[index + 1]
        return value
    end
end

function ConfigUI.Controls.combo.onEvent(configUi, elemSchema)
end

ConfigUI.Controls.radio = {}

function ConfigUI.Controls.radio.create(configUi, elemSchema)
    local xml = ''
    assert(elemSchema.type == 'choices', 'unsupported type for radio: ' .. elemSchema.type)
    assert(elemSchema.choices, 'missing "choices"')
    local choices = elemSchema.choices
    if type(choices) == 'function' then choices = choices(configUi, elemSchema) end

    local vals = {}
    for val, name in pairs(choices) do table.insert(vals, val) end
    table.sort(vals)
    if not elemSchema.ui.id then
        elemSchema.ui.id = {}
        for _, val in ipairs(vals) do elemSchema.ui.id[val] = configUi:uiElementNextID() end
    end
    xml = xml .. '<group flat="true" style="border: 0px;" layout="vbox">'
    for _, val in ipairs(vals) do
        xml = xml .. '<radiobutton'
        xml = xml .. ' id="' .. elemSchema.ui.id[val] .. '"'
        xml = xml .. ' text="' .. choices[val] .. '"'
        xml = xml .. ' on-click="ConfigUI_changed"'
        xml = xml .. '/>'
    end
    xml = xml .. '</group>'
    return xml
end

function ConfigUI.Controls.radio.setValue(configUi, elemSchema, value)
    assert(elemSchema.ui.id[value] ~= nil, 'invalid value: ' .. tostring(value))
    simUI.setRadiobuttonValue(configUi.uiHandle, elemSchema.ui.id[value], 1)
end

function ConfigUI.Controls.radio.getValue(configUi, elemSchema)
    for val, id in pairs(elemSchema.ui.id) do
        if simUI.getRadiobuttonValue(configUi.uiHandle, id) > 0 then return val end
    end
end

function ConfigUI.Controls.radio.onEvent(configUi, elemSchema)
end

ConfigUI.Controls.checkbox = {}

function ConfigUI.Controls.checkbox.hasLabel(configUi, elemSchema)
    return false
end

function ConfigUI.Controls.checkbox.create(configUi, elemSchema)
    local xml = ''
    assert(elemSchema.type == 'bool', 'unsupported type for checkbox: ' .. elemSchema.type)
    if not elemSchema.ui.id then elemSchema.ui.id = configUi:uiElementNextID() end
    label = ''
    xml = xml .. '<checkbox'
    xml = xml .. ' id="' .. elemSchema.ui.id .. '"'
    xml = xml .. ' text="' .. elemSchema.name .. '"'
    xml = xml .. ' on-change="ConfigUI_changed"'
    xml = xml .. '/>'
    return xml
end

function ConfigUI.Controls.checkbox.setValue(configUi, elemSchema, value)
    simUI.setCheckboxValue(configUi.uiHandle, elemSchema.ui.id, value and 2 or 0)
end

function ConfigUI.Controls.checkbox.getValue(configUi, elemSchema)
    return simUI.getCheckboxValue(configUi.uiHandle, elemSchema.ui.id) > 0
end

function ConfigUI.Controls.checkbox.onEvent(configUi, elemSchema)
end

ConfigUI.Controls.spinbox = {}

function ConfigUI.Controls.spinbox.create(configUi, elemSchema)
    local xml = ''
    assert(
        elemSchema.type == 'float' or elemSchema.type == 'int',
        'unsupported type for spinbox: ' .. elemSchema.type
    )
    if not elemSchema.ui.id then elemSchema.ui.id = configUi:uiElementNextID() end
    xml = xml .. '<spinbox'
    xml = xml .. ' id="' .. elemSchema.ui.id .. '"'
    if elemSchema.ui.minimum then
        xml = xml .. ' minimum="' .. elemSchema.ui.minimum .. '"'
    elseif elemSchema.minimum then
        xml = xml .. ' minimum="' .. elemSchema.minimum .. '"'
    end
    if elemSchema.ui.maximum then
        xml = xml .. ' maximum="' .. elemSchema.ui.maximum .. '"'
    elseif elemSchema.maximum then
        xml = xml .. ' maximum="' .. elemSchema.maximum .. '"'
    end
    if elemSchema.ui.step then
        xml = xml .. ' step="' .. elemSchema.ui.step .. '"'
    elseif elemSchema.step then
        xml = xml .. ' step="' .. elemSchema.step .. '"'
    elseif elemSchema.type == 'float' then
        xml = xml .. ' step="0.001"'
    end
    if elemSchema.ui.decimals then xml = xml .. ' decimals="' .. elemSchema.ui.decimals .. '"' end
    xml = xml .. ' float="' .. (elemSchema.type == 'float' and 'true' or 'false') .. '"'
    xml = xml .. ' on-change="ConfigUI_changed"'
    xml = xml .. '/>'
    return xml
end

function ConfigUI.Controls.spinbox.setValue(configUi, elemSchema, value)
    simUI.setSpinboxValue(configUi.uiHandle, elemSchema.ui.id, value)
end

function ConfigUI.Controls.spinbox.getValue(configUi, elemSchema)
    return simUI.getSpinboxValue(configUi.uiHandle, elemSchema.ui.id)
end

function ConfigUI.Controls.spinbox.onEvent(configUi, elemSchema)
end

ConfigUI.Controls.color = {}

function ConfigUI.Controls.color.create(configUi, elemSchema)
    local xml = ''
    assert(elemSchema.type == 'color', 'unsupported type for color: ' .. elemSchema.type)
    if not elemSchema.ui.id then elemSchema.ui.id = configUi:uiElementNextID() end
    xml = xml .. '<button'
    xml = xml .. ' id="' .. elemSchema.ui.id .. '"'
    xml = xml .. ' text="..."'
    xml = xml .. ' on-click="ConfigUI_event"'
    xml = xml .. '/>'
    return xml
end

function ConfigUI.Controls.color.setValue(configUi, elemSchema, value)
    assert(type(value) == 'table', 'incorrect type: must be table')
    assert(#value == 3, 'incorrect length: must be 3')
    local v = sim.unpackTable(sim.packTable(value))
    for i = 1, 3 do v[i] = math.floor(255 * value[i]) end
    local style = string.format('background-color: rgb(%d,%d,%d)', v[1], v[2], v[3])
    simUI.setStyleSheet(configUi.uiHandle, elemSchema.ui.id, style)
end

function ConfigUI.Controls.color.onEvent(configUi, elemSchema)
    local col = simUI.colorDialog(configUi.config[elemSchema.key])
    if col then
        configUi.config[elemSchema.key] = col
        configUi:writeConfig()
        configUi:generate()
        ConfigUI.Controls.color.setValue(configUi, elemSchema, col)
    end
end

ConfigUI.Controls.button = {}

function ConfigUI.Controls.button.create(configUi, elemSchema)
    local xml = ''
    assert(elemSchema.type == 'callback', 'unsupported type for button: ' .. elemSchema.type)
    if not elemSchema.ui.id then elemSchema.ui.id = configUi:uiElementNextID() end
    xml = xml .. '<button'
    xml = xml .. ' id="' .. elemSchema.ui.id .. '"'
    xml = xml .. ' text="..."'
    xml = xml .. ' on-click="ConfigUI_event"'
    xml = xml .. '/>'
    return xml
end

function ConfigUI.Controls.button.hasLabel(configUi, elemSchema)
    return elemSchema.display
end

function ConfigUI.Controls.button.setValue(configUi, elemSchema, value)
    if elemSchema.display then
        if type(elemSchema.display == 'function') then
            value = elemSchema.display(configUi, elemSchema, value)
        elseif type(elemSchema.display) == 'string' or type(elemSchema.display) == 'number' then
            value = tostring(elemSchema.display)
        else
            error('invalid type for "display"')
        end
    else
        value = elemSchema.name
    end
    if value == nil then value = '' end
    simUI.setButtonText(configUi.uiHandle, elemSchema.ui.id, value)
end

function ConfigUI.Controls.button.onEvent(configUi, elemSchema)
    local oldCfg = sim.packTable(configUi.config)
    elemSchema.callback(configUi)
    local newCfg = sim.packTable(configUi.config)
    if oldCfg ~= newCfg then
        configUi:writeConfig()
        ConfigUI.Controls.button.setValue(configUi, elemSchema)
        configUi:generate()
    end
end

---------------------------------------------------------

