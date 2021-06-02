ConfigUI={}

function ConfigUI:getObjectName()
    if self.getObjectNameCallback then
        return self:getObjectNameCallback()
    end
    local objectHandle=sim.getObjectHandle(sim.handle_self)
    return sim.getObjectName(objectHandle)
end

function ConfigUI:readBlock(name)
    if self.readBlockCallback then
        return self:readBlockCallback(name)
    end
    local objectHandle=sim.getObjectHandle(sim.handle_self)
    local data=sim.readCustomDataBlock(objectHandle,name)
    return data
end

function ConfigUI:writeBlock(name,data)
    if self.writeBlockCallback then
        return self:writeBlockCallback(name,data)
    end
    local objectHandle=sim.getObjectHandle(sim.handle_self)
    sim.writeCustomDataBlock(objectHandle,name,data)
end

function ConfigUI:readInfo()
    self.info={}
    local data=self:readBlock(self.dataBlockName.info)
    if data then
        for k,v in pairs(sim.unpackTable(data)) do
            self.info[k]=v
        end
    end
end

function ConfigUI:writeInfo()
    self:writeBlock(self.dataBlockName.info,sim.packTable(self.info))
end

function ConfigUI:defaultConfig()
    local ret={}
    for k,v in pairs(self.schema) do ret[k]=v.default end
    return ret
end

function ConfigUI:readConfig()
    self.config=self:defaultConfig()
    local data=self:readBlock(self.dataBlockName.config)
    if data then
        for k,v in pairs(sim.unpackTable(data)) do
            self.config[k]=v
        end
    end
end

function ConfigUI:writeConfig()
    self:writeBlock(self.dataBlockName.config,sim.packTable(self.config))
end

function ConfigUI:showUi()
    if not self.uiHandle then
        self:readConfig()
        self:createUi()
    end
end

function ConfigUI:uiElementNextID()
    if not self.uiNextID then self.uiNextID=1 end
    local ret=self.uiNextID
    self.uiNextID=self.uiNextID+1
    return ret
end

function ConfigUI:uiElementXML(elemName,elemSchema)
    local xml=''
    elemSchema.key=elemSchema.key or elemName
    elemSchema.ui=elemSchema.ui or {}
    if elemSchema.ui.fromUiValue or elemSchema.ui.toUiValue then
        assert(elemSchema.ui.fromUiValue and elemSchema.ui.toUiValue,'"fromUiValue" and "toUiValue" must be both set')
        if elemSchema.minimum then
            elemSchema.ui.minimum=elemSchema.ui.toUiValue(elemSchema.minimum)
        end
        if elemSchema.maximum then
            elemSchema.ui.maximum=elemSchema.ui.toUiValue(elemSchema.maximum)
        end
    end
    -- auto-guess type if missing:
    if not elemSchema.type then
        if elemSchema.choices then
            elemSchema.type='choices'
        elseif elemSchema.callback then
            elemSchema.type='callback'
        else
            error('missing type')
        end
    end
    -- auto-guess control if missing:
    if not elemSchema.ui.control then
        if elemSchema.type=='string' then
            elemSchema.ui.control='edit'
        elseif elemSchema.type=='float' and elemSchema.minimum and elemSchema.maximum then
            elemSchema.ui.control='slider'
        elseif elemSchema.type=='int' or elemSchema.type=='float' then
            elemSchema.ui.control='spinbox'
        elseif elemSchema.type=='bool' then
            elemSchema.ui.control='checkbox'
        elseif elemSchema.type=='color' then
            elemSchema.ui.control='color'
        elseif elemSchema.type=='choices' then
            elemSchema.ui.control='radio'
        elseif elemSchema.type=='callback' then
            elemSchema.ui.control='button'
        else
            error('missing "ui.control" and cannot infer it from type')
        end
    end
    local controlFuncs=ConfigUI.Controls[elemSchema.ui.control]
    if controlFuncs==nil then
        error('unknown ui control: "'..elemSchema.ui.control..'"')
    end
    if (controlFuncs.hasLabel or function() return true end)(self,elemSchema) then
        xml=xml..string.format('<label text="%s:" style="margin-top: 5px;" /><br/>\n',elemSchema.name)
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

function ConfigUI:schemaSorted()
    -- first order ui elements by 'order' key:
    local uiElemsOrdered={}
    for elemName,elemSchema in pairs(self.schema) do
        elemSchema.ui=elemSchema.ui or {}
        table.insert(uiElemsOrdered,elemName)
    end
    table.sort(uiElemsOrdered,function(a,b)
        a=self.schema[a].ui.order or 0
        b=self.schema[b].ui.order or 0
        return a<b
    end)

    -- then collect the tabs ('tab' key) in the order they appear:
    local uiTabs,uiTabsOrder={},{}
    for _,elemName in ipairs(uiElemsOrdered) do
        local elemSchema=self.schema[elemName]
        local tabName=elemSchema.ui.tab or ''
        if not uiTabs[tabName] then
            uiTabs[tabName]={}
            table.insert(uiTabsOrder,tabName)
        end
        table.insert(uiTabs[tabName],elemName)
    end

    -- for each tab:
    for tabName,uiElems in pairs(uiTabs) do
        -- split tab's ui elements by column:
        local cols,byCol={},{}
        for _,elemName in ipairs(uiElems) do
            local col=self.schema[elemName].ui.col or 1
            if not byCol[col] then
                byCol[col]={}
                table.insert(cols,col)
            end
            table.insert(byCol[col],elemName)
        end
        table.sort(cols)
        uiTabs[tabName]={}
        for _,col in ipairs(cols) do
            local colContent={}
            for _,elemName in ipairs(byCol[col]) do
                table.insert(colContent,elemName)
            end
            table.insert(uiTabs[tabName],colContent)
        end
    end

    return uiTabs,uiTabsOrder
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
    xml=xml..' layout="grid"'
    xml=xml..'>\n'
    local uiTabs,uiTabsOrder=self:schemaSorted()
    if #uiTabsOrder>1 then
        if not self.uiTabsID then
            self.uiTabsID=self:uiElementNextID()
        end
        xml=xml..'<tabs id="'..self.uiTabsID..'">\n'
    end
    for _,tab in ipairs(uiTabsOrder) do
        if #uiTabsOrder>1 then
            xml=xml..'<tab title="'..tab..'" layout="grid">\n'
        end
        for _,col in ipairs(uiTabs[tab]) do
            xml=xml..'<group flat="true" layout="grid">'
            for _,k in ipairs(col) do
                xml=xml..self:uiElementXML(k,self.schema[k])
            end
            xml=xml..'<br/><group flat="true" layout="vbox"><stretch/></group>\n'
            xml=xml..'</group>'
        end
        if #uiTabsOrder>1 then
            xml=xml..'<br/><group flat="true" layout="vbox"><stretch/></group>\n'
            xml=xml..'</tab>\n'
        end
    end
    if #uiTabsOrder>1 then
        xml=xml..'</tabs>\n'
    end
    xml=xml..'</ui>'
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

function ConfigUI_event(ui,id)
    local self=ConfigUI.handleMap[ui]
    if self then
        local elemName=self.eventMap[id]
        self:uiEvent(elemName)
    end
end

function ConfigUI_close(ui)
    local self=ConfigUI.handleMap[ui]
    if self then self:uiClosed() end
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
        if v~=nil then
            self.config[elemName]=v
        end
    end
    self:writeConfig()
    self:generate()
end

function ConfigUI:uiEvent(elemName)
    local elemSchema=self.schema[elemName]
    local controlFuncs=ConfigUI.Controls[elemSchema.ui.control]
    if controlFuncs.onEvent then
        controlFuncs.onEvent(self,elemSchema)
    end
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

function ConfigUI:uiClosed()
    self:closeUi(true)
end

function ConfigUI:setupSysCall(name,f)
    name='sysCall_'..name
    if _G[name] then
        local oldFn=_G[name]
        _G[name]=function()
            oldFn()
            f()
        end
    else
        _G[name]=f
    end
end

function ConfigUI:sysCall_init()
    self:readInfo()
    self:writeInfo()
    self:readConfig()
    self:writeConfig()
    self:generate()

    -- read a saved uistate here if any (see ConfigUI:sysCall_cleanup):
    self.uistate=self.uistate or {}
    local data=self:readBlock('@tmp/uistate')
    self:writeBlock('@tmp/uistate',nil)
    if data then
        for k,v in pairs(sim.unpackTable(data)) do
            self.uistate[k]=v
        end
    end
    if self.uistate.open then self:showUi() end
end

function ConfigUI:sysCall_cleanup()
    self:closeUi(false)
    -- save uistate here so it can persist a script restart:
    self:writeBlock('@tmp/uistate',sim.packTable(self.uistate))
end

function ConfigUI:sysCall_userConfig()
    self:showUi()
end

function ConfigUI:sysCall_nonSimulation()
    if self.generatePending then --and (self.generatePending+self.generationTime)<sim.getSystemTime() then
        self.generatePending=false
        self.generateCallback(self.config)
        sim.announceSceneContentChange()
    end
    
    -- poll for external config change:
    local data=self:readBlock(self.dataBlockName.config)
    if data and data~=sim.packTable(self.config) then
        self:readConfig()
        self:configChanged() -- updates ui
        self:writeConfig()
        self:generate()
    end
end

function ConfigUI:sysCall_beforeSimulation()
    self:closeUi()
end

function ConfigUI:sysCall_sensing()
    sysCall_nonSimulation()
end

function ConfigUI:sysCall_afterSimulation()
    if self.uistate.open then
        self:showUi()
    end
end

function ConfigUI:setGenerateCallback(f)
    self.generateCallback=f
end

function ConfigUI:generate()
    if self.generateCallback then
        self.generatePending=true
    end
end

function ConfigUI:__index(k)
    return ConfigUI[k]
end

setmetatable(ConfigUI,{__call=function(meta,modelType,schema,genCb)
    local self=setmetatable({
        dataBlockName={
            config='__config__',
            info='__info__',
        },
        modelType=modelType,
        schema=schema,
        generatePending=false,
    },meta)
    self:setGenerateCallback(genCb)
    self:setupSysCall('init',function() self:sysCall_init() end)
    self:setupSysCall('cleanup',function() self:sysCall_cleanup() end)
    self:setupSysCall('userConfig',function() self:sysCall_userConfig() end)
    self:setupSysCall('nonSimulation',function() self:sysCall_nonSimulation() end)
    self:setupSysCall('beforeSimulation',function() self:sysCall_beforeSimulation() end)
    self:setupSysCall('sensing',function() self:sysCall_sensing() end)
    self:setupSysCall('afterSimulation',function() self:sysCall_afterSimulation() end)
    return self
end})

---------------------------------------------------------

ConfigUI.Controls={}

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
    xml=xml..'<combobox id="'..elemSchema.ui.id..'">'
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
