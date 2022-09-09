function ConfigUI:uiElementXML(elemName,elemSchema)
    local xml=''
    local controlFuncs=ConfigUI.Controls[elemSchema.ui.control]
    if (controlFuncs.hasLabel or function() return true end)(self,elemSchema) then
        if not elemSchema.ui.idLabel then
            elemSchema.ui.idLabel=self:uiElementNextID()
        end
        xml=xml..string.format('<label id="%d" text="%s:" style="margin-top: 5px;" /><br/>\n',elemSchema.ui.idLabel,elemSchema.name)
    end
    local xml2=controlFuncs.create(self,elemSchema)
    if xml2~=nil then xml=xml..xml2..'<br/>\n' end
    if elemSchema.ui.id then
        self.eventMap=self.eventMap or {}
        if type(elemSchema.ui.id)=='table' then
            for val,id in ipairs(elemSchema.ui.id) do self.eventMap[id]=elemName end
        else
            self.eventMap[elemSchema.ui.id]=elemName
        end
    end
    return xml
end

function ConfigUI:createUi()
    if self.uiHandle then return end
    self.uiNextID=1
    local xml='<ui'
    xml=xml..string.format(' title="%s config"',self:getObjectName())
    if self.uistate.pos then
        xml=xml..string.format(' placement="absolute" position="%d,%d" ',self.uistate.pos[1],self.uistate.pos[2])
    else
        xml=xml..' placement="relative" position="-30,100" '
    end
    xml=xml..' closeable="true" on-close="ConfigUI_close"'
    xml=xml..' layout="vbox"'
    xml=xml..' content-margins="0,0,0,0"'
    xml=xml..'>\n'
    local uiElemsSplit,tabNames=self:splitElems()
    if #tabNames>1 then
        if not self.uiTabsID then
            self.uiTabsID=self:uiElementNextID()
        end
        xml=xml..'<tabs id="'..self.uiTabsID..'">\n'
    end
    for tabIndex,tabName in ipairs(tabNames) do
        if #tabNames>1 then
            xml=xml..'<tab title="'..tabName..'" layout="vbox" content-margins="0,0,0,0">\n'
        end
        for groupIndex,groupElems in ipairs(uiElemsSplit[tabIndex]) do
            xml=xml..'<group flat="'..(#uiElemsSplit[tabIndex]>0 and 'false' or 'true')..'" layout="hbox" content-margins="0,0,0,0"><!-- group '..groupIndex..' -->\n'
            for colIndex,colElems in ipairs(groupElems) do
                xml=xml..'<group flat="true" layout="grid" content-margins="0,0,0,0"><!-- group '..groupIndex..', col '..colIndex..' -->\n'
                for _,elemName in ipairs(colElems) do
                    xml=xml..self:uiElementXML(elemName,self.schema[elemName])
                end
                xml=xml..'<group flat="true" layout="vbox" content-margins="0,0,0,0"><stretch/></group><!-- column vertical fill -->\n'
                xml=xml..'</group>\n'
            end
            xml=xml..'</group>\n'
        end
        if #tabNames>1 then
            xml=xml..'<stretch/><!-- tab vertical fill -->\n'
            xml=xml..'</tab>\n'
        end
    end
    if #tabNames>1 then
        xml=xml..'</tabs>\n'
    end
    xml=xml..'</ui>'
    self.uiXML=xml
    self.uiHandle=simUI.create(xml)
    if self.uiTabsID and self.uistate.currentTab then
        simUI.setCurrentTab(self.uiHandle,self.uiTabsID,self.uistate.currentTab)
    end
    ConfigUI.handleMap=ConfigUI.handleMap or {}
    ConfigUI.handleMap[self.uiHandle]=self
    self:configChanged()
end

function ConfigUI:closeUi(user)
    if self.uiHandle then
        self:saveUIPos()
        if user==true then -- closed by user -> remember uistate
            self.uistate.open=false
        end
        simUI.destroy(self.uiHandle)
        self.uiHandle=nil
        if user==false then -- has been closed programmatically, e.g. from cleanup
            self.uistate.open=true
        end
    end
end

function ConfigUI_changed(ui)
    local self=ConfigUI.handleMap[ui]
    if self then self:uiChanged() end
end

function ConfigUI_close(ui)
    local self=ConfigUI.handleMap[ui]
    if self then self:uiClosed() end
end

function ConfigUI:updateEnabledFlag()
    if not self.uiHandle then return end
    local setEnabled=self.hideDisabledWidgets and simUI.setWidgetVisibility or simUI.setEnabled
    for elemName,elemSchema in pairs(self.schema) do
        local enabled=elemSchema.ui.enabled
        if enabled==nil then enabled=true end
        if type(enabled)=='function' then enabled=enabled(self,self.config) end
        if type(elemSchema.ui.id)=='table' then
            for _,id in pairs(elemSchema.ui.id) do
                setEnabled(self.uiHandle,id,enabled)
            end
        else
            setEnabled(self.uiHandle,elemSchema.ui.id,enabled)
        end
        if elemSchema.ui.idLabel then
            setEnabled(self.uiHandle,elemSchema.ui.idLabel,enabled)
        end
    end
end

function ConfigUI:configChanged()
    if not self.uiHandle then return end
    for elemName,elemSchema in pairs(self.schema) do
        local v=self.config[elemName]
        if elemSchema.ui.toUiValue then
            v=elemSchema.ui.toUiValue(v)
        end
        local controlFuncs=ConfigUI.Controls[elemSchema.ui.control]
        if controlFuncs.setValue then
            controlFuncs.setValue(self,elemSchema,v)
        end
    end
    self:updateEnabledFlag()
end

function ConfigUI:uiChanged()
    for elemName,elemSchema in pairs(self.schema) do
        local v=nil
        local controlFuncs=ConfigUI.Controls[elemSchema.ui.control]
        if controlFuncs.getValue then
            v=controlFuncs.getValue(self,elemSchema)
        end
        if v~=nil and elemSchema.ui.fromUiValue then
            v=elemSchema.ui.fromUiValue(v)
        end
        if v~=nil and elemSchema.type=='int' then
            v=math.floor(v)
        end
        if v~=nil then
            self.config[elemName]=v
        end
    end
    self:writeConfig()
    self:generate()
    self:updateEnabledFlag()
end

function ConfigUI:saveUIPos()
    if self.uiHandle then
        local x,y=simUI.getPosition(self.uiHandle)
        self.uistate.pos={x,y}
        if self.uiTabsID then
            self.uistate.currentTab=simUI.getCurrentTab(self.uiHandle,self.uiTabsID)
        end
    end
end

---------------------------------------------------------

ConfigUI.Controls.edit={}

function ConfigUI.Controls.edit.create(configUi,elemSchema)
    local xml=''
    if not elemSchema.ui.id then
        elemSchema.ui.id=configUi:uiElementNextID()
    end
    xml=xml..'<edit'
    xml=xml..' id="'..elemSchema.ui.id..'"'
    xml=xml..' on-change="ConfigUI_changed"'
    xml=xml..'/>'
    return xml
end

function ConfigUI.Controls.edit.setValue(configUi,elemSchema,value)
    simUI.setEditValue(configUi.uiHandle,elemSchema.ui.id,value)
end

function ConfigUI.Controls.edit.getValue(configUi,elemSchema)
    return simUI.getEditValue(configUi.uiHandle,elemSchema.ui.id)
end

function ConfigUI.Controls.edit.onEvent(configUi,elemSchema)
end

ConfigUI.Controls.slider={}

function ConfigUI.Controls.slider.create(configUi,elemSchema)
    local xml=''
    if not elemSchema.ui.id then
        elemSchema.ui.id=configUi:uiElementNextID()
    end
    if elemSchema.type=='float' then
        if not elemSchema.ui.minimum and not elemSchema.ui.maximum then
            elemSchema.ui.minimum=0
            elemSchema.ui.maximum=1000
            elemSchema.ui.fromUiValue=function(x)
                x=(x-elemSchema.ui.minimum)/(elemSchema.ui.maximum-elemSchema.ui.minimum)
                return elemSchema.minimum+x*(elemSchema.maximum-elemSchema.minimum)
            end
            elemSchema.ui.toUiValue=function(x)
                x=(x-elemSchema.minimum)/(elemSchema.maximum-elemSchema.minimum)
                return elemSchema.ui.minimum+x*(elemSchema.ui.maximum-elemSchema.ui.minimum)
            end
        end
    elseif elemSchema.type=='int' then
    else
        error('unsupported type for slider: '..elemSchema.type)
    end
    xml=xml..'<hslider id="'..elemSchema.ui.id..'"'
    if elemSchema.ui.minimum then
        xml=xml..' minimum="'..math.floor(elemSchema.ui.minimum)..'"'
    elseif elemSchema.minimum then
        xml=xml..' minimum="'..math.floor(elemSchema.minimum)..'"'
    end
    if elemSchema.ui.maximum then
        xml=xml..' maximum="'..math.floor(elemSchema.ui.maximum)..'"'
    elseif elemSchema.maximum then
        xml=xml..' maximum="'..math.floor(elemSchema.maximum)..'"'
    end
    xml=xml..' on-change="ConfigUI_changed"'
    xml=xml..'/>'
    return xml
end

function ConfigUI.Controls.slider.setValue(configUi,elemSchema,value)
    simUI.setSliderValue(configUi.uiHandle,elemSchema.ui.id,value)
end

function ConfigUI.Controls.slider.getValue(configUi,elemSchema)
    return simUI.getSliderValue(configUi.uiHandle,elemSchema.ui.id)
end

function ConfigUI.Controls.slider.onEvent(configUi,elemSchema)
end

ConfigUI.Controls.combo={}

function ConfigUI.Controls.combo.create(configUi,elemSchema)
    local xml=''
    assert(elemSchema.type=='choices','unsupported type for combo: '..elemSchema.type)
    assert(elemSchema.choices,'missing "choices"')
    local choices=elemSchema.choices
    if type(choices)=='function' then
        choices=choices(configUi,elemSchema)
    end

    elemSchema.ui.items={}
    for val,name in pairs(choices) do
        table.insert(elemSchema.ui.items,val)
    end
    table.sort(elemSchema.ui.items)

    elemSchema.ui.itemIndex={}
    for index,value in ipairs(elemSchema.ui.items) do
        if elemSchema.ui.itemIndex[value] then
            error(string.format('value "%s" is not unique!',value))
        end
        elemSchema.ui.itemIndex[value]=index
    end

    if not elemSchema.ui.id then
        elemSchema.ui.id=configUi:uiElementNextID()
    end
    xml=xml..'<combobox id="'..elemSchema.ui.id..'" on-change="ConfigUI_changed">'
    for _,val in ipairs(elemSchema.ui.items) do
        xml=xml..'<item>'..choices[val]..'</item>'
    end
    xml=xml..'</combobox>'
    return xml
end

function ConfigUI.Controls.combo.setValue(configUi,elemSchema,value)
    local choices=elemSchema.choices
    if type(choices)=='function' then
        choices=choices(configUi,elemSchema)
    end
    assert(choices[value]~=nil,'invalid value: '..tostring(value))
    simUI.setComboboxSelectedIndex(configUi.uiHandle,elemSchema.ui.id,elemSchema.ui.itemIndex[value]-1)
end

function ConfigUI.Controls.combo.getValue(configUi,elemSchema)
    local index=simUI.getComboboxSelectedIndex(configUi.uiHandle,elemSchema.ui.id)
    if index~=-1 then
        local value=elemSchema.ui.items[index+1]
        return value
    end
end

function ConfigUI.Controls.combo.onEvent(configUi,elemSchema)
end

ConfigUI.Controls.radio={}

function ConfigUI.Controls.radio.create(configUi,elemSchema)
    local xml=''
    assert(elemSchema.type=='choices','unsupported type for radio: '..elemSchema.type)
    assert(elemSchema.choices,'missing "choices"')
    local choices=elemSchema.choices
    if type(choices)=='function' then
        choices=choices(configUi,elemSchema)
    end

    local vals={}
    for val,name in pairs(choices) do table.insert(vals,val) end
    table.sort(vals)
    if not elemSchema.ui.id then
        elemSchema.ui.id={}
        for _,val in ipairs(vals) do
            elemSchema.ui.id[val]=configUi:uiElementNextID()
        end
    end
    xml=xml..'<group flat="true" style="border: 0px;" layout="vbox">'
    for _,val in ipairs(vals) do
        xml=xml..'<radiobutton'
        xml=xml..' id="'..elemSchema.ui.id[val]..'"'
        xml=xml..' text="'..choices[val]..'"'
        xml=xml..' on-click="ConfigUI_changed"'
        xml=xml..'/>'
    end
    xml=xml..'</group>'
    return xml
end

function ConfigUI.Controls.radio.setValue(configUi,elemSchema,value)
    assert(elemSchema.ui.id[value]~=nil,'invalid value: '..tostring(value))
    simUI.setRadiobuttonValue(configUi.uiHandle,elemSchema.ui.id[value],1)
end

function ConfigUI.Controls.radio.getValue(configUi,elemSchema)
    for val,id in pairs(elemSchema.ui.id) do
        if simUI.getRadiobuttonValue(configUi.uiHandle,id)>0 then
            return val
        end
    end
end

function ConfigUI.Controls.radio.onEvent(configUi,elemSchema)
end

ConfigUI.Controls.checkbox={}

function ConfigUI.Controls.checkbox.hasLabel(configUi,elemSchema)
    return false
end

function ConfigUI.Controls.checkbox.create(configUi,elemSchema)
    local xml=''
    assert(elemSchema.type=='bool','unsupported type for checkbox: '..elemSchema.type)
    if not elemSchema.ui.id then
        elemSchema.ui.id=configUi:uiElementNextID()
    end
    label=''
    xml=xml..'<checkbox'
    xml=xml..' id="'..elemSchema.ui.id..'"'
    xml=xml..' text="'..elemSchema.name..'"'
    xml=xml..' on-change="ConfigUI_changed"'
    xml=xml..'/>'
    return xml
end

function ConfigUI.Controls.checkbox.setValue(configUi,elemSchema,value)
    simUI.setCheckboxValue(configUi.uiHandle,elemSchema.ui.id,value and 2 or 0)
end

function ConfigUI.Controls.checkbox.getValue(configUi,elemSchema)
    return simUI.getCheckboxValue(configUi.uiHandle,elemSchema.ui.id)>0
end

function ConfigUI.Controls.checkbox.onEvent(configUi,elemSchema)
end

ConfigUI.Controls.spinbox={}

function ConfigUI.Controls.spinbox.create(configUi,elemSchema)
    local xml=''
    assert(elemSchema.type=='float' or elemSchema.type=='int','unsupported type for spinbox: '..elemSchema.type)
    if not elemSchema.ui.id then
        elemSchema.ui.id=configUi:uiElementNextID()
    end
    xml=xml..'<spinbox'
    xml=xml..' id="'..elemSchema.ui.id..'"'
    if elemSchema.ui.minimum then
        xml=xml..' minimum="'..elemSchema.ui.minimum..'"'
    elseif elemSchema.minimum then
        xml=xml..' minimum="'..elemSchema.minimum..'"'
    end
    if elemSchema.ui.maximum then
        xml=xml..' maximum="'..elemSchema.ui.maximum..'"'
    elseif elemSchema.maximum then
        xml=xml..' maximum="'..elemSchema.maximum..'"'
    end
    if elemSchema.ui.step then
        xml=xml..' step="'..elemSchema.ui.step..'"'
    elseif elemSchema.step then
        xml=xml..' step="'..elemSchema.step..'"'
    elseif elemSchema.type=='float' then
        xml=xml..' step="0.001"'
    end
    if elemSchema.ui.decimals then
        xml=xml..' decimals="'..elemSchema.ui.decimals..'"'
    end
    xml=xml..' float="'..(elemSchema.type=='float' and 'true' or 'false')..'"'
    xml=xml..' on-change="ConfigUI_changed"'
    xml=xml..'/>'
    return xml
end

function ConfigUI.Controls.spinbox.setValue(configUi,elemSchema,value)
    simUI.setSpinboxValue(configUi.uiHandle,elemSchema.ui.id,value)
end

function ConfigUI.Controls.spinbox.getValue(configUi,elemSchema)
    return simUI.getSpinboxValue(configUi.uiHandle,elemSchema.ui.id)
end

function ConfigUI.Controls.spinbox.onEvent(configUi,elemSchema)
end

ConfigUI.Controls.color={}

function ConfigUI.Controls.color.create(configUi,elemSchema)
    local xml=''
    assert(elemSchema.type=='color','unsupported type for color: '..elemSchema.type)
    if not elemSchema.ui.id then
        elemSchema.ui.id=configUi:uiElementNextID()
    end
    xml=xml..'<button'
    xml=xml..' id="'..elemSchema.ui.id..'"'
    xml=xml..' text="..."'
    xml=xml..' on-click="ConfigUI_event"'
    xml=xml..'/>'
    return xml
end

function ConfigUI.Controls.color.setValue(configUi,elemSchema,value)
    assert(type(value)=='table','incorrect type: must be table')
    assert(#value==3,'incorrect length: must be 3')
    local v=sim.unpackTable(sim.packTable(value))
    for i=1,3 do v[i]=math.floor(255*value[i]) end
    local style=string.format('background-color: rgb(%d,%d,%d)',v[1],v[2],v[3])
    simUI.setStyleSheet(configUi.uiHandle,elemSchema.ui.id,style)
end

function ConfigUI.Controls.color.onEvent(configUi,elemSchema)
    local col=simUI.colorDialog(configUi.config[elemSchema.key])
    if col then
        configUi.config[elemSchema.key]=col
        configUi:writeConfig()
        configUi:generate()
        ConfigUI.Controls.color.setValue(configUi,elemSchema,col)
    end
end

ConfigUI.Controls.button={}

function ConfigUI.Controls.button.create(configUi,elemSchema)
    local xml=''
    assert(elemSchema.type=='callback','unsupported type for button: '..elemSchema.type)
    if not elemSchema.ui.id then
        elemSchema.ui.id=configUi:uiElementNextID()
    end
    xml=xml..'<button'
    xml=xml..' id="'..elemSchema.ui.id..'"'
    xml=xml..' text="..."'
    xml=xml..' on-click="ConfigUI_event"'
    xml=xml..'/>'
    return xml
end

function ConfigUI.Controls.button.hasLabel(configUi,elemSchema)
    return elemSchema.display
end

function ConfigUI.Controls.button.setValue(configUi,elemSchema,value)
    if elemSchema.display then
        if type(elemSchema.display=='function') then
            value=elemSchema.display(configUi,elemSchema,value)
        elseif type(elemSchema.display)=='string' or type(elemSchema.display)=='number' then
            value=tostring(elemSchema.display)
        else
            error('invalid type for "display"')
        end
    else
        value=elemSchema.name
    end
    if value==nil then value='' end
    simUI.setButtonText(configUi.uiHandle,elemSchema.ui.id,value)
end

function ConfigUI.Controls.button.onEvent(configUi,elemSchema)
    local oldCfg=sim.packTable(configUi.config)
    elemSchema.callback(configUi)
    local newCfg=sim.packTable(configUi.config)
    if oldCfg~=newCfg then
        configUi:writeConfig()
        ConfigUI.Controls.button.setValue(configUi,elemSchema)
        configUi:generate()
    end
end

---------------------------------------------------------
