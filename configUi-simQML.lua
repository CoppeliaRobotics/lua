local json=require'dkjson'

function ConfigUI:uiElementXML(elemName,elemSchema)
    local xml=''
    local controlFuncs=ConfigUI.Controls[elemSchema.ui.control]
    if (controlFuncs.hasLabel or function() return true end)(self,elemSchema) then
        if not elemSchema.ui.idLabel then
            elemSchema.ui.idLabel=self:uiElementNextID()
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
    self:writeConfig()
    self:generate()
    self:updateEnabledFlag()
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

---------------------------------------------------------

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
    xml=xml..'    function getConfig() {\n'
    xml=xml..'        return value\n'
    xml=xml..'    }\n'
    xml=xml..'    function setConfig(data) {\n'
    xml=xml..'        value=data\n'
    xml=xml..'    }\n'
    xml=xml..'}\n'
    xml=xml..'Connections {\n'
    xml=xml..'    enabled: !window.suppressEvents\n'
    xml=xml..'    target: id'..elemSchema.ui.id..'\n'
    xml=xml..'    function onValueChanged() {\n'
    xml=xml..'        window.sendConfig()\n'
    xml=xml..'    }\n'
    xml=xml..'}\n'
    for _,val in ipairs(vals) do
        xml=xml..'RadioButton {\n'
        xml=xml..'    id: id'..elemSchema.ui.ids[val]..'\n'
        xml=xml..'    ButtonGroup.group: id'..elemSchema.ui.id..'\n'
        xml=xml..'    text: "'..choices[val]..'"\n'
        xml=xml..'    onCheckedChanged: if(checked) id'..elemSchema.ui.id..'.value = "'..val..'"\n'
        xml=xml..'    checked: id'..elemSchema.ui.id..'.value === "'..val..'"\n'
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
