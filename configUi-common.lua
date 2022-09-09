ConfigUI={}

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

function ConfigUI:readInfo()
    self.info={}
    local info=sim.readCustomTableData(sim.getObject'.',self.dataBlockName.info)
    for k,v in pairs(info) do
        self.info[k]=v
    end
end

function ConfigUI:writeInfo()
    sim.writeCustomTableData(sim.getObject'.',self.dataBlockName.info,self.info)
end

function ConfigUI:readSchema()
    local schema=sim.readCustomTableData(sim.getObject'.',self.dataBlockName.schema)
    if next(schema)~=nil then
        self.schema={}
        for k,v in pairs(schema) do
            self.schema[k]=v
        end
    elseif self.schema==nil then
        error('schema not provided, and not found in the custom data block '..self.dataBlockName.schema)
    end
end

function ConfigUI:defaultConfig()
    local ret={}
    for k,v in pairs(self.schema) do ret[k]=v.default end
    return ret
end

function ConfigUI:readConfig()
    if self.schema==nil then error('readConfig() requires schema') end
    self.config=self:defaultConfig()
    local config=sim.readCustomTableData(sim.getObject'.',self.dataBlockName.config)
    for k,v in pairs(config) do
        if self.schema[k] then self.config[k]=v end
    end
end

function ConfigUI:writeConfig()
    sim.writeCustomTableData(sim.getObject'.',self.dataBlockName.config,self.config)
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

function ConfigUI_event(ui,id)
    local self=ConfigUI.handleMap[ui]
    if self then
        local elemName=self.eventMap[id]
        self:uiEvent(elemName)
    end
end

function ConfigUI:uiEvent(elemName)
    local elemSchema=self.schema[elemName]
    local controlFuncs=ConfigUI.Controls[elemSchema.ui.control]
    if controlFuncs.onEvent then
        controlFuncs.onEvent(self,elemSchema)
    end
end

function ConfigUI:uiClosed()
    self:closeUi(true)
end

function ConfigUI:sysCall_init()
    self:readSchema()
    self:validateSchema()
    self:readInfo()
    self.info.modelType=self.modelType
    self:writeInfo()
    self:readConfig()
    self:writeConfig()
    self:generate()

    -- read a saved uistate here if any (see ConfigUI:sysCall_cleanup):
    self.uistate=self.uistate or {}
    local uistate=sim.readCustomTableData(sim.getObject'.','@tmp/uistate')
    sim.writeCustomTableData(sim.getObject'.','@tmp/uistate',{})
    for k,v in pairs(uistate) do
        self.uistate[k]=v
    end
    if self.uistate.open then self:showUi() end
end

function ConfigUI:sysCall_cleanup()
    self:closeUi(false)
    -- save uistate here so it can persist a script restart:
    sim.writeCustomTableData(sim.getObject'.','@tmp/uistate',self.uistate)
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
    local newConfig=sim.readCustomTableData(sim.getObject'.',self.dataBlockName.config)
    if sim.packTable(newConfig)~=sim.packTable(self.config) then
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
    self:sysCall_nonSimulation()
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
            schema='__schema__',
        },
        modelType=modelType,
        schema=schema,
        generatePending=false,
    },meta)
    self:setGenerateCallback(genCb)
    sim.registerScriptFuncHook('sysCall_init',function() self:sysCall_init() end)
    sim.registerScriptFuncHook('sysCall_cleanup',function() self:sysCall_cleanup() end)
    sim.registerScriptFuncHook('sysCall_userConfig',function() self:sysCall_userConfig() end)
    sim.registerScriptFuncHook('sysCall_nonSimulation',function() self:sysCall_nonSimulation() end)
    sim.registerScriptFuncHook('sysCall_beforeSimulation',function() self:sysCall_beforeSimulation() end)
    sim.registerScriptFuncHook('sysCall_sensing',function() self:sysCall_sensing() end)
    sim.registerScriptFuncHook('sysCall_afterSimulation',function() self:sysCall_afterSimulation() end)
    return self
end})

---------------------------------------------------------

ConfigUI.Controls={}
