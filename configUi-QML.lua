ConfigUI={}

local json=require'dkjson'

function ConfigUI:validateElemSchema(elemName,elemSchema)
    -- try to fix what is possible to fix:
    --   - infer missing information
    --   - migrate deprecated notations to current
    -- anything else -> error()

    elemSchema.key=elemSchema.key or elemName

    elemSchema.name=elemSchema.name or elemName

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

    -- standard default value if not given:
    if elemSchema.default==nil then
        if elemSchema.type=='string' then
            elemSchema.default=''
        elseif elemSchema.type=='int' or elemSchema.type=='float' then
            elemSchema.default=0
        elseif elemSchema.type=='color' then
            elemSchema.default={0.85,0.85,1.0}
        elseif elemSchema.type=='bool' then
            elemSchema.default=false
        end
    end

    if elemSchema.default==nil then
        error('missing "default" for key "'..elemName..'"')
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
end

function ConfigUI:validateSchema()
    for elemName,elemSchema in pairs(self.schema) do
        local success,errorMessage=pcall(function()
            self:validateElemSchema(elemName,elemSchema)
        end)
        if not success then
            error('element "'..elemName..'": '..errorMessage)
        end
    end
end

function ConfigUI:getObjectName()
    if self.getObjectNameCallback then
        return self:getObjectNameCallback()
    end
    local objectHandle=sim.getObject('.')
    return sim.getObjectAlias(objectHandle,1)
end

function ConfigUI:readBlock(name)
    if self.readBlockCallback then
        return self:readBlockCallback(name)
    end
    local objectHandle=sim.getObject('.')
    local data=sim.readCustomDataBlock(objectHandle,name)
    return data
end

function ConfigUI:writeBlock(name,data)
    if self.writeBlockCallback then
        return self:writeBlockCallback(name,data)
    end
    local objectHandle=sim.getObject('.')
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
    if not self.qmlEngine then
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
    local controlFuncs=ConfigUI.Controls[elemSchema.ui.control]
    if (controlFuncs.hasLabel or function() return true end)(self,elemSchema) then
        if not elemSchema.ui.idLabel then
            elemSchema.ui.idLabel=configUi:uiElementNextID()
        end
        xml=xml..string.format('Label { id: id%d; text: "%s:" }\n',elemSchema.ui.idLabel,elemSchema.name)
    end
    local xml2=controlFuncs.create(self,elemSchema)
    if xml2~=nil then xml=xml..xml2..'\n' end
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

function ConfigUI:splitElemsByKey(uiElemsOrdered,key,defaultValue)
    local keyNames,seenKey={},{}
    for _,elemName in ipairs(uiElemsOrdered) do
        if self.schema[elemName]==nil then error('element "'..elemName..'" not present in schema') end
        local elemSchema=self.schema[elemName]
        local value=elemSchema.ui[key] or defaultValue
        if not seenKey[value] then
            seenKey[value]=true
            table.insert(keyNames,value)
        end
    end
    local elemsSplitByKey={}
    for _,value in ipairs(keyNames) do
        local elemsInCurrentKey={}
        for _,elemName in ipairs(uiElemsOrdered) do
            local elemSchema=self.schema[elemName]
            if (elemSchema.ui[key] or defaultValue)==value then
                table.insert(elemsInCurrentKey,elemName)
            end
        end
        table.insert(elemsSplitByKey,elemsInCurrentKey)
    end
    return keyNames,elemsSplitByKey
end

function ConfigUI:splitElems()
    -- first order ui elements by 'order' key:
    local uiElemsOrdered={}
    for elemName,elemSchema in pairs(self.schema) do
        elemSchema.ui=elemSchema.ui or {}
        elemSchema.ui.order=elemSchema.ui.order or 0
        table.insert(uiElemsOrdered,elemName)
    end
    table.sort(uiElemsOrdered,function(a,b) return self.schema[a].ui.order<self.schema[b].ui.order end)

    -- split uiElemsOrdered by 'tab', then by 'group', then by 'col':
    local uiElemsSplit={}
    local tabNames,uiElemsSplitByTab=self:splitElemsByKey(uiElemsOrdered,'tab','')
    for tabIndex,elems in ipairs(uiElemsSplitByTab) do
        local groupNames,uiElemsSplitByGroup=self:splitElemsByKey(elems,'group',1)
        uiElemsSplit[tabIndex]=uiElemsSplitByGroup
        for groupIndex,elems in ipairs(uiElemsSplit[tabIndex]) do
            local columnNames,uiElemsSplitByCol=self:splitElemsByKey(elems,'col',1)
            uiElemsSplit[tabIndex][groupIndex]=uiElemsSplitByCol
        end
    end

    return uiElemsSplit,tabNames
end

function ConfigUI:createUi()
    if self.qmlEngine then return end
    self.uiNextID=1
    if not self.uiTabsID then
        self.uiTabsID=self:uiElementNextID()
    end
    local uiElemsSplit,tabNames=self:splitElems()
    local xml=''
    xml=xml..'import QtQuick 2.15\n'
    xml=xml..'import QtQuick.Window 2.15\n'
    xml=xml..'import QtQuick.Controls 2.12\n'
    xml=xml..'import QtQuick.Layouts 1.12\n'
    xml=xml..'import QtQuick.Dialogs 1.3\n'
    xml=xml..'import CoppeliaSimPlugin 1.0\n'
    xml=xml..'\n'
    xml=xml..'PluginWindow {\n'
    xml=xml..'    id: window\n'
    xml=xml..'    property bool suppressEvents: false\n'
    xml=xml..'    onSuppressEventsChanged: console.log("window.suppressEvents: ", suppressEvents)\n'
    xml=xml..'    width: 320\n'
    xml=xml..'    height: 480\n'
    --if self.uistate.pos then
    --    xml=xml..string.format(' placement="absolute" position="%d,%d" ',self.uistate.pos[1],self.uistate.pos[2])
    --else
    --    xml=xml..' placement="relative" position="-30,100" '
    --end
    --xml=xml..' closeable="true" on-close="ConfigUI_close"'
    xml=xml..'    visible: true\n'
    xml=xml..'    title: "'..self:getObjectName()..' config"\n'
    xml=xml..'    onXChanged: saveUIState()\n'
    xml=xml..'    onYChanged: saveUIState()\n'
    xml=xml..'    onClosing: saveUIState()\n'
    xml=xml..'    function saveUIState() {\n'
    xml=xml..'        simBridge.sendEvent("saveUIState", {x: x, y: y, open: true})\n'
    xml=xml..'    }\n'
    xml=xml..'\n'
    if #tabNames>1 then
        xml=xml..'    TabBar {\n'
        xml=xml..'        id: id'..self.uiTabsID..'\n'
        xml=xml..'        width: parent.width\n'
        for tabIndex,tabName in ipairs(tabNames) do
            xml=xml..'        TabButton { text: qsTr("'..tabName..'") }\n'
        end
        xml=xml..'    }\n'
        xml=xml..'\n'
    end
    xml=xml..'    StackLayout {\n'
    xml=xml..'        anchors.fill: parent\n'
    if #tabNames>1 then
        xml=xml..'        anchors.topMargin: id'..self.uiTabsID..'.height\n'
        xml=xml..'        currentIndex: id'..self.uiTabsID..'.currentIndex\n'
    end
    for tabIndex,tabName in ipairs(tabNames) do
        xml=xml..'        Item { // tab '..tabName..'\n'
        xml=xml..'            ColumnLayout { // tab '..tabName..' column layout\n'
        xml=xml..'                anchors.fill: parent\n'
        xml=xml..'                anchors.margins: 10\n'
        xml=xml..'                spacing: 10\n'
        for groupIndex,groupElems in ipairs(uiElemsSplit[tabIndex]) do
            xml=xml..'\n'
            xml=xml..'                RowLayout { // group '..groupIndex..'\n'
            xml=xml..'                    spacing: 10\n'
            xml=xml..'                    Layout.fillWidth: true\n'
            xml=xml..'                    Layout.fillHeight: true\n'
            xml=xml..'                    Layout.alignment: Qt.AlignTop\n'
            for colIndex,colElems in ipairs(groupElems) do
                xml=xml..'\n'
                xml=xml..'                    ColumnLayout { // group '..groupIndex..', col '..colIndex..'\n'
                xml=xml..'                        Layout.alignment: Qt.AlignTop\n'
                for _,elemName in ipairs(colElems) do
                    xml=xml..'\n'
                    xml=xml..self:uiElementXML(elemName,self.schema[elemName])
                end
                xml=xml..'                    } // group '..groupIndex..', col '..colIndex..'\n'
            end
            xml=xml..'                } // group '..groupIndex..'\n'
        end
        xml=xml..'            } // tab '..tabName..' column layout\n'
        xml=xml..'        } // tab '..tabName..'\n'
    end
    xml=xml..'    } // stack layout\n'
    xml=xml..'\n'
    xml=xml..'    function getConfig() {\n'
    xml=xml..'        var data={}\n'
    for elemName,elemSchema in pairs(self.schema) do
        xml=xml..'        data.'..elemName..' = id'..elemSchema.ui.id..'.getConfig()\n'
    end
    xml=xml..'        return data\n'
    xml=xml..'    }\n'
    xml=xml..'    function sendConfig() {\n'
    xml=xml..'        if(window.suppressEvents) return\n'
    xml=xml..'        simBridge.sendEvent("print","sendConfig()")\n'
    xml=xml..'        simBridge.sendEvent("uiChanged",getConfig())\n'
    xml=xml..'    }\n'
    xml=xml..'    function setConfig(data) {\n'
    xml=xml..'        var oldSuppressEvents = window.suppressEvents\n'
    xml=xml..'        window.suppressEvents = true\n'
    for elemName,elemSchema in pairs(self.schema) do
        xml=xml..'        id'..elemSchema.ui.id..'.setConfig(data.'..elemName..')\n'
    end
    xml=xml..'        window.suppressEvents = oldSuppressEvents\n'
    xml=xml..'    }\n'
    xml=xml..'} // window\n'
    self.uiXML=xml
    self.qmlEngine=simQML.createEngine()
    ConfigUI_QML_ENGINE_MAP=ConfigUI_QML_ENGINE_MAP or {}
    ConfigUI_QML_ENGINE_MAP[self.qmlEngine]=self
    simQML.setEventHandler(self.qmlEngine,'ConfigUI_QML_EVENT_HANDLER')
    simQML.loadData(self.qmlEngine,xml)
    self:configChanged() -- will call QML's setConfig() above
end

function ConfigUI_QML_EVENT_HANDLER(engineHandle,eventName,eventData)
    local self=ConfigUI_QML_ENGINE_MAP[engineHandle]
    if self~=nil then
        self[eventName](self,eventData)
    end
end

function ConfigUI:saveUIState(data)
    --called by QML
end

function ConfigUI:print(what)
    print('QML:',what)
end

function ConfigUI:closeUi(user)
    if self.qmlEngine~=nil then
        self:saveUIPos()
        if user==true then -- closed by user -> remember uistate
            self.uistate.open=false
        end
        simQML.destroyEngine(self.qmlEngine)
        self.qmlEngine=nil
        if user==false then -- has been closed programmatically, e.g. from cleanup
            self.uistate.open=true
        end
    end
end

function ConfigUI_event(ui,id)
    local self=ConfigUI.handleMap[ui]
    if self then
        local elemName=self.eventMap[id]
        self:uiEvent(elemName)
    end
end

function ConfigUI:updateEnabledFlag()
    if not self.qmlEngine then return end
    local function setEnabled(e,i,b)
        if self.hideDisabledWidgets then
            --.setWidgetVisibility...
        else
            --.setEnabled...
        end
    end
    for elemName,elemSchema in pairs(self.schema) do
        local enabled=elemSchema.ui.enabled
        if enabled==nil then enabled=true end
        if type(enabled)=='function' then enabled=enabled(self,self.config) end
        if type(elemSchema.ui.id)=='table' then
            for _,id in pairs(elemSchema.ui.id) do
                setEnabled(self.qmlEngine,id,enabled)
            end
        else
            setEnabled(self.qmlEngine,elemSchema.ui.id,enabled)
        end
        if elemSchema.ui.idLabel then
            setEnabled(self.qmlEngine,elemSchema.ui.idLabel,enabled)
        end
    end
end

function ConfigUI:configChanged()
    print('configChanged',self.config)
    if not self.qmlEngine then return end
    local uiConfig={}
    for elemName,elemSchema in pairs(self.schema) do
        local v=self.config[elemName]
        if elemSchema.ui.toUiValue then
            v=elemSchema.ui.toUiValue(v)
        end
        uiConfig[elemName]=v
    end
    simQML.sendEvent(self.qmlEngine,'setConfig',uiConfig)
    self:updateEnabledFlag()
end

function ConfigUI:uiChanged(newConfig)
    print('uiChanged',newConfig)
    for elemName,newValue in pairs(newConfig) do
        local elemSchema=self.schema[elemName]
        if elemSchema.ui.fromUiValue then
            newValue=elemSchema.ui.fromUiValue(newValue)
        end
        if elemSchema.type=='int' then
            newValue=math.floor(newValue)
        end
        self.config[elemName]=newValue
    end
    print('uiChanged',self.config)
    self:writeConfig()
    self:generate()
    self:updateEnabledFlag()
end

function ConfigUI:uiEvent(elemName)
    local elemSchema=self.schema[elemName]
    local controlFuncs=ConfigUI.Controls[elemSchema.ui.control]
    if controlFuncs.onEvent then
        controlFuncs.onEvent(self,elemSchema)
    end
end

function ConfigUI:saveUIPos()
    if self.qmlEngine then
        --local x,y=.getPosition(...)
        --self.uistate.pos={x,y}
        --if self.uiTabsID then
            --self.uistate.currentTab=.getCurrentTab(...)
        --end
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
    self:validateSchema()
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
    if sim.getSimulationState()==sim.simulation_stopped then
        self:showUi()
    end
end

function ConfigUI:sysCall_nonSimulation()
    if self.generatePending then --and (self.generatePending+self.generationTime)<sim.getSystemTime() then
        self.generatePending=false
        self.generateCallback(self.config)
        -- sim.announceSceneContentChange() leave this out for now
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
    xml=xml..'TextField {\n'
    xml=xml..'    id: id'..elemSchema.ui.id..'\n'
    xml=xml..'    Connections {\n'
    xml=xml..'        enabled: !window.suppressEvents\n'
    xml=xml..'        target: id'..elemSchema.ui.id..'\n'
    xml=xml..'        function onTextChanged() {\n'
    xml=xml..'            window.sendConfig()\n'
    xml=xml..'        }\n'
    xml=xml..'    }\n'
    xml=xml..'    function getConfig() {\n'
    xml=xml..'        return text\n'
    xml=xml..'    }\n'
    xml=xml..'    function setConfig(data) {\n'
    xml=xml..'        text=data\n'
    xml=xml..'    }\n'
    xml=xml..'}\n'
    return xml
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
    xml=xml..'Slider {\n'
    xml=xml..'    id: id'..elemSchema.ui.id..'\n'
    --if elemSchema.ui.minimum then
    --    xml=xml..' minimum="'..math.floor(elemSchema.ui.minimum)..'"'
    --elseif elemSchema.minimum then
    --    xml=xml..' minimum="'..math.floor(elemSchema.minimum)..'"'
    --end
    --if elemSchema.ui.maximum then
    --    xml=xml..' maximum="'..math.floor(elemSchema.ui.maximum)..'"'
    --elseif elemSchema.maximum then
    --    xml=xml..' maximum="'..math.floor(elemSchema.maximum)..'"'
    --end
    --xml=xml..' on-change="ConfigUI_changed"'
    xml=xml..'    Connections {\n'
    xml=xml..'        enabled: !window.suppressEvents\n'
    xml=xml..'        target: id'..elemSchema.ui.id..'\n'
    xml=xml..'        function onValueChanged() {\n'
    xml=xml..'            window.sendConfig()\n'
    xml=xml..'        }\n'
    xml=xml..'    }\n'
    xml=xml..'    function getConfig() {\n'
    xml=xml..'        return value\n'
    xml=xml..'    }\n'
    xml=xml..'    function setConfig(data) {\n'
    xml=xml..'        value=data\n'
    xml=xml..'    }\n'
    xml=xml..'}\n'
    return xml
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
    xml=xml..'ComboBox {\n'
    xml=xml..'    id: id'..elemSchema.ui.id..'\n'
    xml=xml..'    model: ['
    local sep=''
    for _,val in ipairs(elemSchema.ui.items) do
        xml=xml..sep..'"'..choices[val]..'"'
        sep=', '
    end
    xml=xml..'];\n'
    xml=xml..'    Connections {\n'
    xml=xml..'        enabled: !window.suppressEvents\n'
    xml=xml..'        target: id'..elemSchema.ui.id..'\n'
    xml=xml..'        function onCurrentIndexChanged() {\n'
    xml=xml..'            window.sendConfig()\n'
    xml=xml..'        }\n'
    xml=xml..'    }\n'
    xml=xml..'    function getConfig() {\n'
    xml=xml..'        return model[currentIndex]\n'
    xml=xml..'    }\n'
    xml=xml..'    function setConfig(data) {\n'
    xml=xml..'        for(var i = 0; i < model.length; i++)\n'
    xml=xml..'            if(model[i] == data)\n'
    xml=xml..'                currentIndex = i;\n'
    xml=xml..'    }\n'
    xml=xml..'}'
    return xml
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
        elemSchema.ui.id=configUi:uiElementNextID()
        elemSchema.ui.ids={}
        for _,val in ipairs(vals) do
            elemSchema.ui.ids[val]=configUi:uiElementNextID()
        end
    end
    xml=xml..'ButtonGroup {\n'
    xml=xml..'    id: id'..elemSchema.ui.id..'\n'
    xml=xml..'    property string value: "'..elemSchema.default..'"\n'
    xml=xml..'    Connections {\n'
    xml=xml..'        enabled: !window.suppressEvents\n'
    xml=xml..'        target: id'..elemSchema.ui.id..'\n'
    xml=xml..'        function onValueChanged() {\n'
    xml=xml..'            window.sendConfig()\n'
    xml=xml..'        }\n'
    xml=xml..'    }\n'
    xml=xml..'    function getConfig() {\n'
    xml=xml..'        return value\n'
    xml=xml..'    }\n'
    xml=xml..'    function setConfig(data) {\n'
    xml=xml..'        value=data\n'
    xml=xml..'    }\n'
    xml=xml..'}\n'
    for _,val in ipairs(vals) do
        xml=xml..'RadioButton {\n'
        xml=xml..'    id: id'..elemSchema.ui.ids[val]..'\n'
        xml=xml..'    ButtonGroup.group: id'..elemSchema.ui.id..'\n'
        xml=xml..'    text: "'..val..'"\n'
        xml=xml..'    onCheckedChanged: if(checked) id'..elemSchema.ui.id..'.value = "'..val..'"\n'
        xml=xml..'}\n'
    end
    return xml
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
    xml=xml..'CheckBox {\n'
    xml=xml..'    id: id'..elemSchema.ui.id..'\n'
    xml=xml..'    text: "'..elemSchema.name..'"\n'
    xml=xml..'    Connections {\n'
    xml=xml..'        enabled: !window.suppressEvents\n'
    xml=xml..'        target: id'..elemSchema.ui.id..'\n'
    xml=xml..'        function onCheckedChanged() {\n'
    xml=xml..'            window.sendConfig()\n'
    xml=xml..'        }\n'
    xml=xml..'    }\n'
    xml=xml..'    function getConfig() {\n'
    xml=xml..'        return checked\n'
    xml=xml..'    }\n'
    xml=xml..'    function setConfig(data) {\n'
    xml=xml..'        checked=data\n'
    xml=xml..'    }\n'
    xml=xml..'}\n'
    return xml
end

ConfigUI.Controls.spinbox={}

function ConfigUI.Controls.spinbox.create(configUi,elemSchema)
    local xml=''
    assert(elemSchema.type=='float' or elemSchema.type=='int','unsupported type for spinbox: '..elemSchema.type)
    if not elemSchema.ui.id then
        elemSchema.ui.id=configUi:uiElementNextID()
    end
    xml=xml..'SpinBox {\n'
    xml=xml..'    id: id'..elemSchema.ui.id..'\n'
    local min,max,step,decimals
    if elemSchema.ui.minimum then
        min=elemSchema.ui.minimum
    elseif elemSchema.minimum then
        min=elemSchema.minimum
    end
    if elemSchema.ui.maximum then
        max=elemSchema.ui.maximum
    elseif elemSchema.maximum then
        max=elemSchema.maximum
    end
    if elemSchema.ui.step then
        step=elemSchema.ui.step
    elseif elemSchema.step then
        step=elemSchema.step
    elseif elemSchema.type=='float' then
        step=0.001
    else
        step=1
    end
    if elemSchema.ui.decimals then
        decimals=elemSchema.ui.decimals
    else
        decimals=math.max(0,math.floor(-math.log10(step)))
    end
    xml=xml..'    property int decimals: '..decimals..'\n'
    xml=xml..'    property int multiplier: Math.pow(10, decimals)\n'
    xml=xml..'    property real realValue: value / multiplier\n'
    xml=xml..'    from:     Math.floor(multiplier * '..min..')\n'
    xml=xml..'    to:       Math.floor(multiplier * '..max..')\n'
    xml=xml..'    stepSize: Math.floor(multiplier * '..step..')\n'
    xml=xml..'    validator: DoubleValidator {\n'
    xml=xml..'        bottom: Math.min(id'..elemSchema.ui.id..'.from, id'..elemSchema.ui.id..'.to)\n'
    xml=xml..'        top:    Math.max(id'..elemSchema.ui.id..'.from, id'..elemSchema.ui.id..'.to)\n'
    xml=xml..'    }\n'
    xml=xml..'    textFromValue: function(value, locale) {\n'
    xml=xml..'        return Number(value / id'..elemSchema.ui.id..'.multiplier).toLocaleString(locale, "f", id'..elemSchema.ui.id..'.decimals)\n'
    xml=xml..'    }\n'
    xml=xml..'    valueFromText: function(text, locale) {\n'
    xml=xml..'        return Number.fromLocaleString(locale, text) * id'..elemSchema.ui.id..'.multiplier\n'
    xml=xml..'    }\n'
    --xml=xml..' float="'..(elemSchema.type=='float' and 'true' or 'false')..'"'
    xml=xml..'    Connections {\n'
    xml=xml..'        enabled: !window.suppressEvents\n'
    xml=xml..'        target: id'..elemSchema.ui.id..'\n'
    xml=xml..'        function onValueChanged() {\n'
    xml=xml..'            window.sendConfig()\n'
    xml=xml..'        }\n'
    xml=xml..'    }\n'
    xml=xml..'    function getConfig() {\n'
    xml=xml..'        return realValue\n'
    xml=xml..'    }\n'
    xml=xml..'    function setConfig(data) {\n'
    xml=xml..'        value=data * multiplier\n'
    xml=xml..'    }\n'
    xml=xml..'}\n'
    return xml
end

ConfigUI.Controls.color={}

function ConfigUI.Controls.color.create(configUi,elemSchema)
    local xml=''
    assert(elemSchema.type=='color','unsupported type for color: '..elemSchema.type)
    if not elemSchema.ui.id then
        elemSchema.ui.id=configUi:uiElementNextID()
    end
    xml=xml..'Button {\n'
    xml=xml..'    id: id'..elemSchema.ui.id..'\n'
    xml=xml..'    text: "..."\n'
    xml=xml..'    property color color: "#000"\n'
    xml=xml..'    background: Rectangle {\n'
    xml=xml..'        anchors.fill: parent\n'
    xml=xml..'        color: parent.color\n'
    xml=xml..'    }\n'
    xml=xml..'    ColorDialog {\n'
    xml=xml..'        id: id'..elemSchema.ui.id..'_colorDialog\n'
    xml=xml..'        color: id'..elemSchema.ui.id..'.color\n'
    xml=xml..'        onAccepted: id'..elemSchema.ui.id..'.color = color\n'
    xml=xml..'    }\n'
    xml=xml..'    onClicked: {\n'
    xml=xml..'        id'..elemSchema.ui.id..'_colorDialog.open()\n'
    xml=xml..'    }\n'
    xml=xml..'    Connections {\n'
    xml=xml..'        enabled: !window.suppressEvents\n'
    xml=xml..'        target: id'..elemSchema.ui.id..'\n'
    xml=xml..'        function onColorChanged() {\n'
    xml=xml..'            window.sendConfig()\n'
    xml=xml..'        }\n'
    xml=xml..'    }\n'
    xml=xml..'    function getConfig() {\n'
    xml=xml..'        return [color.r, color.g, color.b]\n'
    xml=xml..'    }\n'
    xml=xml..'    function setConfig(data) {\n'
    xml=xml..'        color=Qt.rgba(data[0], data[1], data[2], 1)\n'
    xml=xml..'    }\n'
    xml=xml..'}\n'
    return xml
end

ConfigUI.Controls.button={}

function ConfigUI.Controls.button.create(configUi,elemSchema)
    local xml=''
    assert(elemSchema.type=='callback','unsupported type for button: '..elemSchema.type)
    if not elemSchema.ui.id then
        elemSchema.ui.id=configUi:uiElementNextID()
    end
    xml=xml..'Button {\n'
    xml=xml..'    id: id'..elemSchema.ui.id..'\n'
    xml=xml..'    property string value: "..."\n'
    xml=xml..'    text: value\n'
    xml=xml..'    onClicked: {\n'
    xml=xml..'        simBridge.sendEvent("uiEvent","'..elemSchema.name..'")\n'
    xml=xml..'    }\n'
    xml=xml..'    Connections {\n'
    xml=xml..'        enabled: !window.suppressEvents\n'
    xml=xml..'        target: id'..elemSchema.ui.id..'\n'
    xml=xml..'        function onValueChanged() {\n'
    xml=xml..'            window.sendConfig()\n'
    xml=xml..'        }\n'
    xml=xml..'    }\n'
    xml=xml..'    function getConfig() {\n'
    xml=xml..'        return value\n'
    xml=xml..'    }\n'
    xml=xml..'    function setConfig(data) {\n'
    xml=xml..'        value=data\n'
    xml=xml..'    }\n'
    xml=xml..'}\n'
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
    --.setButtonText(configUi.uiHandle,elemSchema.ui.id,value)
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
