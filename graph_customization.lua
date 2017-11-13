local utils=require('utils')

getMinMax=function(minMax1,minMax2)
    if not minMax1 then
        return minMax2
    end
    if not minMax2 then
        return minMax1
    end
    local ret={math.min(minMax1[1],minMax2[1]),math.max(minMax1[2],minMax2[2]),math.min(minMax1[3],minMax2[3]),math.max(minMax1[4],minMax2[4])}
    return(ret)
end

clearCurves=function()
    if plotUi then
        for pl=1,#plots,1 do
            local ii=plots[pl]
            for key,value in pairs(curves[ii]) do
                simUI.clearCurve(plotUi,ii,key)
            end
        end
    end
end

enableMouseInteractions=function(enable)
    if plotUi then
        for pl=1,#plots,1 do
            local ii=plots[pl]
            simUI.setMouseOptions(plotUi,ii,enable,enable,enable,enable)
        end
    end
end

function onclickCurve(ui,id,name,index,x,y)
    local msg=string.format("Point on curve '%s': (%.4f,%.4f)",name,x,y)
    simUI.setLabelText(ui,3,msg)
end

function onCloseModal_callback()
    if modalDlg then
        simUI.destroy(modalDlg)
        modalDlg=nil
    end
    selectedCurve=nil
end

function toClipboardClick_callback()
    sim.auxFunc("curveToClipboard",model,selectedCurve[2],selectedCurve[1])
    onCloseModal_callback()
end

function toStaticClick_callback()
    sim.auxFunc("curveToStatic",model,selectedCurve[2],selectedCurve[1])
    onCloseModal_callback()
    prepareCurves()
end

function removeStaticClick_callback()
    sim.auxFunc("removeStaticCurve",model,selectedCurve[2],selectedCurve[1])
    onCloseModal_callback()
    prepareCurves()
end

function onlegendclick(ui,id,curveName)
    if sim.getSimulationState()==sim.simulation_stopped then
        local c={}
        local i=1
        for token in string.gmatch(curveName,"[^%s]+") do
            c[i]=token
            i=i+1
        end
        selectedCurve={c[1],id-1}
        if c[2]=='(STATIC)' then
            selectedCurve[2]=id+2
        end

        local xml=[[
        <button text="Copy curve to clipboard" onclick="toClipboardClick_callback"/>
                <label text="" style="* {margin-left: 350px;font-size: 1px;}"/>
        ]]
        if c[2]=='(STATIC)' then
            xml=xml..'<button text="Remove static curve" onclick="removeStaticClick_callback"/>'
        else
            xml=xml..'<button text="Duplicate curve to static curve" onclick="toStaticClick_callback"/>'
        end
        modalDlg=utils.createCustomUi(xml,"Operation on Selected Curve","center",true,"onCloseModal_callback",true)
    end
end

updateCurves=function()
    if plotUi then
        for pl=1,#plots,1 do
            local minMax=nil
            local ii=plots[pl]
            local index=0
            while true do
                local label,curveType,curveColor,xData,yData,minMaxT=sim.getGraphCurve(model,ii-1,index)
                if not label then
                    break
                end
                minMax=getMinMax(minMax,minMaxT)
                if curves[ii][label] then
                    simUI.clearCurve(plotUi,ii,label)
                    if ii==1 then
                        simUI.addCurveTimePoints(plotUi,ii,label,xData,yData)
                        if minMaxT and (minMaxT[2]-minMaxT[1]==0 or minMaxT[4]-minMaxT[3]==0) then
                            simUI.addCurveTimePoints(plotUi,ii,label,{xData[#xData]+0.000000001},{yData[#yData]+0.000000001})
                        end
                    else
                        local seq={}
                        for i=1,#xData,1 do
                            seq[i]=i
                        end
                        simUI.addCurveXYPoints(plotUi,ii,label,seq,xData,yData)
                        if minMaxT and (minMaxT[2]-minMaxT[1]==0 or minMaxT[4]-minMaxT[3]==0) then
                            simUI.addCurveXYPoints(plotUi,ii,label,{seq[#seq]+1},{xData[#xData]+0.000000001},{yData[#yData]+0.000000001})
                        end
                    end
                    if curveType<2 then
                        simUI.rescaleAxes(plotUi,ii,label,index~=0,index~=0) -- for non-static curves
                    end
                end
                index=index+1
            end
--            simUI.rescaleAxesAll(plotUi,ii,false,false)
            if minMax then
                local rangeS={minMax[2]-minMax[1],minMax[4]-minMax[3]}
                simUI.growPlotXRange(plotUi,ii,rangeS[1]*0.01,rangeS[1]*0.01)
                simUI.growPlotYRange(plotUi,ii,rangeS[2]*0.01,rangeS[2]*0.01)
            end
            simUI.replot(plotUi,ii)
        end
    end
end

prepareCurves=function()
    if plotUi then
        for pl=1,#plots,1 do
            local minMax=nil
            local ii=plots[pl]
            for key,value in pairs(curves[ii]) do
                simUI.removeCurve(plotUi,ii,key)
            end
            curves[ii]={}
            local index=0
            while true do
                local label,curveType,curveColor,xData,yData,minMaxT=sim.getGraphCurve(model,ii-1,index)
                if not label then
                    break
                end
                local curveStyle
                local scatterShape
                if curveType==0 then
                    -- Non-static line
                    curveStyle=simUI.curve_style.line
                    scatterShape={scatter_shape=simUI.curve_scatter_shape.none,scatter_size=5,line_size=1}
                end
                if curveType==1 then
                    -- Non-static scatter
                    curveStyle=simUI.curve_style.scatter
                    scatterShape={scatter_shape=simUI.curve_scatter_shape.square,scatter_size=4,line_size=1}
                end
                if curveType==2 then
                    -- Static line
                    curveStyle=simUI.curve_style.line
                    scatterShape={scatter_shape=simUI.curve_scatter_shape.none,scatter_size=5,line_size=1,line_style=simUI.line_style.dashed}
                end
                if curveType==3 then
                    -- Static scatter
                    curveStyle=simUI.curve_style.scatter
                    scatterShape={scatter_shape=simUI.curve_scatter_shape.plus,scatter_size=4,line_size=1}
                end
                if ii==1 then
                    simUI.addCurve(plotUi,ii,simUI.curve_type.time,label,{curveColor[1]*255,curveColor[2]*255,curveColor[3]*255},curveStyle,scatterShape)
                else
                    simUI.addCurve(plotUi,ii,simUI.curve_type.xy,label,{curveColor[1]*255,curveColor[2]*255,curveColor[3]*255},curveStyle,scatterShape)
                end
                simUI.setLegendVisibility(plotUi,ii,true)
                curves[ii][label]=true
                index=index+1
            end
        end
    end
    updateCurves()
end

function getDefaultInfoForNonExistingFields(info)
    if not info['bitCoded'] then
        info['bitCoded']=1+2+4+8 -- 1=visible during simulation, 2=visible during non-simul, 4=show time plots, 8=show xy plots, 16=1:1 proportion for xy plots
    end
end

function readInfo()
    local data=sim.readCustomDataBlock(model,'ABC_GRAPH_INFO')
    if data then
        data=sim.unpackTable(data)
    else
        data={}
    end
    getDefaultInfoForNonExistingFields(data)
    return data
end

function writeInfo(data)
    if data then
        sim.writeCustomDataBlock(model,'ABC_GRAPH_INFO',sim.packTable(data))
    else
        sim.writeCustomDataBlock(model,'ABC_GRAPH_INFO','')
    end
end

function setDlgItemContent()
    if ui then
        local config=readInfo()
        local sel=utils.getSelectedEditWidget(ui)
        simUI.setCheckboxValue(ui,1,utils.getCheckboxValFromBool(sim.boolAnd32(config['bitCoded'],2)~=0),true)
        simUI.setCheckboxValue(ui,2,utils.getCheckboxValFromBool(sim.boolAnd32(config['bitCoded'],1)~=0),true)
        simUI.setCheckboxValue(ui,3,utils.getCheckboxValFromBool(sim.boolAnd32(config['bitCoded'],4)~=0),true)
        simUI.setCheckboxValue(ui,4,utils.getCheckboxValFromBool(sim.boolAnd32(config['bitCoded'],8)~=0),true)
        simUI.setCheckboxValue(ui,5,utils.getCheckboxValFromBool(sim.boolAnd32(config['bitCoded'],16)~=0),true)
        utils.setSelectedEditWidget(ui,sel)
    end
end

function updateEnabledDisabledItemsDlg()
end

function visibleDuringSimulation_callback(ui,id,newVal)
    local c=readInfo()
    c['bitCoded']=sim.boolOr32(c['bitCoded'],1)
    if newVal==0 then
        c['bitCoded']=c['bitCoded']-1
    end
    modified=true
    writeInfo(c)
    createOrRemovePlotIfNeeded(false)
    setDlgItemContent()
    updateEnabledDisabledItemsDlg()
end

function visibleDuringNonSimulation_callback(ui,id,newVal)
    local c=readInfo()
    c['bitCoded']=sim.boolOr32(c['bitCoded'],2)
    if newVal==0 then
        c['bitCoded']=c['bitCoded']-2
    end
    modified=true
    writeInfo(c)
    createOrRemovePlotIfNeeded(false)
    setDlgItemContent()
    updateEnabledDisabledItemsDlg()
end

function timeOnly_callback(ui,id,newVal)
    local c=readInfo()
    c['bitCoded']=sim.boolOr32(c['bitCoded'],4)
    if newVal==0 then
        c['bitCoded']=c['bitCoded']-4
        c['bitCoded']=sim.boolOr32(c['bitCoded'],8)
    end
    modified=true
    writeInfo(c)
    removePlot()
    createOrRemovePlotIfNeeded(false)
    setDlgItemContent()
    updateEnabledDisabledItemsDlg()
end

function xyOnly_callback(ui,id,newVal)
    local c=readInfo()
    c['bitCoded']=sim.boolOr32(c['bitCoded'],8)
    if newVal==0 then
        c['bitCoded']=c['bitCoded']-8
        c['bitCoded']=sim.boolOr32(c['bitCoded'],4)
    end
    modified=true
    writeInfo(c)
    removePlot()
    createOrRemovePlotIfNeeded(false)
    setDlgItemContent()
    updateEnabledDisabledItemsDlg()
end

function squareXy_callback(ui,id,newVal)
    local c=readInfo()
    c['bitCoded']=sim.boolOr32(c['bitCoded'],16)
    if newVal==0 then
        c['bitCoded']=c['bitCoded']-16
    end
    modified=true
    writeInfo(c)
    removePlot()
    createOrRemovePlotIfNeeded(false)
    setDlgItemContent()
    updateEnabledDisabledItemsDlg()
end

function createDlg()
    if (not ui) then
        local xml=[[
                <label text="Visible while simulation not running"/>
                <checkbox text="" onchange="visibleDuringNonSimulation_callback" id="1" />

                <label text="Visible while simulation running"/>
                <checkbox text="" onchange="visibleDuringSimulation_callback" id="2" />

                <label text="Show time plots"/>
                <checkbox text="" onchange="timeOnly_callback" id="3" />

                <label text="Show X/Y plots"/>
                <checkbox text="" onchange="xyOnly_callback" id="4" />

                <label text="X/Y plots keep 1:1 aspect ratio"/>
                <checkbox text="" onchange="squareXy_callback" id="5" />
        ]]
        ui=utils.createCustomUi(xml,sim.getObjectName(model),previousDlgPos,false,nil,false,false,false,'layout="form"')
        setDlgItemContent()
        updateEnabledDisabledItemsDlg()
    end
end

function showDlg()
    if not ui then
        createDlg()
    end
end

function removeDlg()
    if ui then
        local x,y=simUI.getPosition(ui)
        previousDlgPos={x,y}
        simUI.destroy(ui)
        ui=nil
    end
end

function removePlot()
    if plotUi then
        local x,y=simUI.getPosition(plotUi)
        previousPlotDlgPos={x,y}
        local x,y=simUI.getSize(plotUi)
        previousPlotDlgSize={x,y}
        plotTabIndex=simUI.getCurrentTab(plotUi,77)
        simUI.destroy(plotUi)
        plotUi=nil
    end
end

function onClosePlot_callback()
    if sim.getSimulationState()==sim.simulation_stopped then
        local c=readInfo()
        c['bitCoded']=sim.boolOr32(c['bitCoded'],2)-2
        writeInfo(c)
        setDlgItemContent()
        updateEnabledDisabledItemsDlg()
    end
    removePlot()
end

function createPlot()
    if not plotUi then
        local c=readInfo()
        plots={}

        local xml='<tabs id="77">'
        if (sim.boolAnd32(c['bitCoded'],4)~=0) then
            xml=xml..[[
            <tab title="Time graph">
            <plot id="1" onclick="onclickCurve" onlegendclick="onlegendclick" max-buffer-size="100000" cyclic-buffer="false" background-color="25,25,25" foreground-color="150,150,150"/>
            </tab>
            ]]
            plots={1}
        end
        if (sim.boolAnd32(c['bitCoded'],8)~=0) then
            local squareAttribute=''
            if (sim.boolAnd32(c['bitCoded'],16)~=0) then
                squareAttribute='square="true"'
            end
            xml=xml..[[
            <tab title="X/Y graph">
            <plot id="2" onclick="onclickCurve" onlegendclick="onlegendclick" max-buffer-size="100000" cyclic-buffer="false" background-color="25,25,25" foreground-color="150,150,150"]]..squareAttribute..[[/>
            </tab>
            ]]
            plots[#plots+1]=2
        end
        xml=xml..[[
        </tabs>
        <br/>
        <label id="3" />
        ]]

        if not previousPlotDlgPos then
            previousPlotDlgPos="bottomRight"
            if graphDlgNumber==2 then
                previousPlotDlgPos="bottomLeft"
            end
        end
        plotUi=utils.createCustomUi(xml,sim.getObjectName(model),previousPlotDlgPos,true,"onClosePlot_callback",false,true,false,'layout="grid"',previousPlotDlgSize)
        if (sim.boolAnd32(c['bitCoded'],4)~=0) then
            simUI.setPlotLabels(plotUi,1,"Time (seconds)","")
        end
        if (sim.boolAnd32(c['bitCoded'],8)~=0) then
            simUI.setPlotLabels(plotUi,2,"X","Y")
        end
        if #plots==1 then
            plotTabIndex=0
        end
        simUI.setCurrentTab(plotUi,77,plotTabIndex,true)

        curves={{},{}}
        prepareCurves()

        local s=sim.getSimulationState()
        enableMouseInteractions( (s==sim.simulation_stopped)or(s==sim.simulation_paused) )
    end
end

createOrRemovePlotIfNeeded=function(forSimulation)
    local c=readInfo()
    if forSimulation then
        if (sim.boolAnd32(c['bitCoded'],1)==0) then
            removePlot()
        else
            createPlot()
        end
    else
        if (sim.boolAnd32(c['bitCoded'],2)==0) then
            removePlot()
        else
            createPlot()
        end
    end
end

showOrHideUiIfNeeded=function()
    local s=sim.getObjectSelection()
    if s and #s>=1 and s[#s]==model then
        showDlg()
    else
        removeDlg()
    end
end

function sysCall_init()
    modified=false
    plotTabIndex=0
    lastT=sim.getSystemTimeInMs(-1)
    model=sim.getObjectAssociatedWithScript(sim.handle_self)
    sim.setScriptAttribute(sim.handle_self,sim.customizationscriptattribute_activeduringsimulation,true)
    previousPlotDlgPos,previousPlotDlgSize,previousDlgPos=utils.readSessionPersistentObjectData(model,"dlgPosAndSize")
    createOrRemovePlotIfNeeded()
end

function sysCall_afterSimulation()
    createOrRemovePlotIfNeeded(false)
    enableMouseInteractions(true)
end

function sysCall_beforeSimulation()
    removeDlg()
    createOrRemovePlotIfNeeded(true)
    prepareCurves()
    clearCurves()
    enableMouseInteractions(false)
end

function sysCall_suspend()
    enableMouseInteractions(true)
end

function sysCall_resume()
    enableMouseInteractions(false)
end

function sysCall_sensing()
    updateCurves()
end


function sysCall_nonSimulation()
    showOrHideUiIfNeeded()
    if sim.getSystemTimeInMs(lastT)>3000 then
        lastT=sim.getSystemTimeInMs(-1)
        if modified then
            sim.announceSceneContentChange() -- to have an undo point
            modified=false
        end
    end
end

function sysCall_beforeInstanceSwitch()
    removeDlg()
    removePlot()
end

function sysCall_afterInstanceSwitch()
    createOrRemovePlotIfNeeded()
end

function sysCall_cleanup()
    removePlot()
    removeDlg()
    utils.writeSessionPersistentObjectData(model,"dlgPosAndSize",previousPlotDlgPos,previousPlotDlgSize,previousDlgPos)
end