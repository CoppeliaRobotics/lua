sim = require('sim')
simUI = require('simUI')

-- e.g. to record data constantly, i.e. also when simulation is not running:

--[[
graph = require('models.graph_customization-2')

function sysCall_init()
    graphHandle = sim.getObject('..')

    -- Create/update data streams/curves:
    sim.destroyGraphCurve(graphHandle, -1)
    stream1 = sim.addGraphStream(graphHandle, 'Object position X', 'm')
    objectHandle = sim.getObject('../cube')
    startTime = sim.getSystemTime()

    graph.init()
end

function appendMeasurementPts()
    -- append measurement points, e.g. the x-position of an object:
    local p = sim.getObjectPosition(objectHandle)
    sim.setGraphStreamValue(graphHandle, stream1, p[1])

    graph.handle(sim.getSystemTime() - startTime)
    graph.updateCurves()
end

function sysCall_sensing()
    appendMeasurementPts()
end

function sysCall_nonSimulation()
    appendMeasurementPts()
end

function sysCall_suspended()
    appendMeasurementPts()
end

function sysCall_beforeSimulation()
end

function sysCall_afterSimulation()
end

function sysCall_suspend()
end

function sysCall_resume()
end
--]]

function sysCall_init()
    _S.graph.init()
end

function sysCall_cleanup()
    _S.graph.cleanup()
end

function sysCall_sensing()
    _S.graph.handle()
    _S.graph.updateCurves()
end

function sysCall_nonSimulation()
    local upd = sim.getObjectInt32Param(_S.graph.model, sim.graphintparam_needs_refresh)
    if upd == 1 then
        _S.graph.refresh = true
        _S.graph.updateCurves(true)
    end
end

function sysCall_beforeSimulation()
    _S.graph.beforeSimulation()
end

function sysCall_afterSimulation()
    _S.graph.afterSimulation()
end

function sysCall_suspend()
    _S.graph.updateCurves(true)
    _S.graph.enableMouseInteractions(true)
end

function sysCall_resume()
    _S.graph.enableMouseInteractions(false)
    _S.graph.updateCurves(true)
end

function sysCall_beforeInstanceSwitch()
    _S.graph.removePlot()
end

function sysCall_afterInstanceSwitch()
    _S.graph.createOrRemovePlotIfNeeded(false)
    _S.graph.updateCurves(true)
    _S.graph.enableMouseInteractions(true)
end

function sysCall_userConfig()
    local simStopped = sim.getSimulationState() == sim.simulation_stopped
    if not _S.graph.previousDlgPos then
        _S.graph.previousDlgPos = ' placement="relative" position="-50,50">'
    end
    local xml = '<ui title="' .. sim.getObjectAlias(_S.graph.model, 1) ..
                    '" closeable="true" on-close="_S.graph.removeDlg" modal="true" resizable="false" activate="false" layout="form" ' ..
                    _S.graph.previousDlgPos .. ' enabled="' .. tostring(simStopped) .. '" >'
    xml = xml .. [[<label text="Visible while simulation not running"/>
            <checkbox text="" on-change="_S.graph.visibleDuringNonSimulation_callback" id="1" />

            <label text="Visible while simulation running"/>
            <checkbox text="" on-change="_S.graph.visibleDuringSimulation_callback" id="2" />

            <label text="Show time plots"/>
            <checkbox text="" on-change="_S.graph.timeOnly_callback" id="3" />

            <label text="Show X/Y plots"/>
            <checkbox text="" on-change="_S.graph.xyOnly_callback" id="4" />

            <label text="Show 3D curves"/>
            <checkbox text="" on-change="_S.graph.xyzOnly_callback" id="8" />

            <label text="X/Y plots keep 1:1 aspect ratio"/>
            <checkbox text="" on-change="_S.graph.squareXy_callback" id="5" style="* {margin-right: 100px;}"/>

            <label text="Update frequency"/>
            <combobox id="7" on-change="_S.graph.updateFreqChanged_callback"></combobox>

            <label text="Preferred graph position"/>
            <combobox id="6" on-change="_S.graph.graphPosChanged_callback"></combobox></ui>
    ]]
    --    _S.graph.ui=_S.graph.utils.createCustomUi(xml,sim.getObjectAlias(_S.graph.model,1),_S.graph.previousDlgPos,true,'_S.graph.removeDlg',true,false,false,'layout="form" enabled="'..tostring(simStopped)..'"')
    _S.graph.ui = simUI.create(xml)
    _S.graph.setDlgItemContent()
end

_S.graph = {}

function _S.graph.removeDlg()
    local x, y = simUI.getPosition(_S.graph.ui)
    _S.graph.previousDlgPos = ' placement="absolute" position="' .. x .. ',' .. y .. '" '
    simUI.destroy(_S.graph.ui)
    _S.graph.ui = nil
end

function _S.graph.getMinMax(minMax1, minMax2)
    if not minMax1 then return minMax2 end
    if not minMax2 then return minMax1 end
    local ret = {
        math.min(minMax1[1], minMax2[1]), math.max(minMax1[2], minMax2[2]),
        math.min(minMax1[3], minMax2[3]), math.max(minMax1[4], minMax2[4]),
    }
    return (ret)
end

function _S.graph.clearCurves()
    if _S.graph.plotUi then
        for pl = 1, #_S.graph.plots, 1 do
            local ii = _S.graph.plots[pl]
            for key, value in pairs(_S.graph.curves[ii]) do
                simUI.clearCurve(_S.graph.plotUi, ii, key)
            end
        end
    end
end

function _S.graph.enableMouseInteractions(enable)
    if _S.graph.plotUi then
        for pl = 1, #_S.graph.plots, 1 do
            local ii = _S.graph.plots[pl]
            simUI.setMouseOptions(_S.graph.plotUi, ii, enable, enable, enable, enable)
        end
    end
end

function _S.graph.onclickCurve(ui, id, name, index, x, y)
    local msg = string.format("Point on curve '%s': (%.4f,%.4f)", name, x, y)
    simUI.setLabelText(ui, 3, msg)
end

function _S.graph.onCloseModal_callback()
    if _S.graph.modalDlg then
        simUI.destroy(_S.graph.modalDlg)
        _S.graph.modalDlg = nil
    end
    _S.graph.selectedCurve = nil
end

function _S.graph.toClipboardClick_callback()
    sim.auxFunc("curveToClipboard", _S.graph.model, _S.graph.selectedCurve[2], _S.graph.selectedCurve[1])
    _S.graph.onCloseModal_callback()
end

function _S.graph.toStaticClick_callback()
    sim.auxFunc("curveToStatic", _S.graph.model, _S.graph.selectedCurve[2], _S.graph.selectedCurve[1])
    _S.graph.onCloseModal_callback()
    _S.graph.prepareCurves()
end

function _S.graph.removeStaticClick_callback()
    sim.auxFunc("removeStaticCurve", _S.graph.model, _S.graph.selectedCurve[2], _S.graph.selectedCurve[1])
    _S.graph.onCloseModal_callback()
    _S.graph.prepareCurves()
end

function _S.graph.onlegendclick(ui, id, curveName)
    if sim.getSimulationState() == sim.simulation_stopped then
        local c = {}
        local i = 1
        for token in string.gmatch(curveName, "[^%s]+") do
            c[i] = token
            i = i + 1
        end
        _S.graph.selectedCurve = {c[1], id - 1}
        if c[2] == '(STATIC)' or c[2] == '[STATIC]' then _S.graph.selectedCurve[2] = id + 2 end

        local xml =
            [[<ui title="Operation on selected curve" placement="center" closeable="true" on-close="_S.graph.onCloseModal_callback" modal="true">
        <button text="Copy curve to clipboard" on-click="_S.graph.toClipboardClick_callback"/>
                <label text="" style="* {margin-left: 350px;font-size: 1px;}"/>
        ]]
        if c[2] == '(STATIC)' or c[2] == '[STATIC]' then
            xml = xml ..
                      '<button text="Remove static curve" on-click="_S.graph.removeStaticClick_callback"/>'
        else
            xml = xml ..
                      '<button text="Duplicate curve to static curve" on-click="_S.graph.toStaticClick_callback"/>'
        end
        xml = xml .. '</ui>'
        --        _S.graph.modalDlg=_S.graph.utils.createCustomUi(xml,"Operation on Selected Curve","center",true,"_S.graph.onCloseModal_callback",true)
        _S.graph.modalDlg = simUI.create(xml)
    end
end

function _S.graph.updateCurves(forceUpdate)
    _S.graph.updateCnt = _S.graph.updateCnt + 1
    if _S.graph.updateCnt >= _S.graph.updateTick or forceUpdate then
        _S.graph.updateCnt = 0
        local upd = sim.getObjectInt32Param(_S.graph.model, sim.graphintparam_needs_refresh)
        if upd == 1 or _S.graph.refresh then
            _S.graph.refresh = false
            _S.graph.removePlot()
            _S.graph.remove3dCurves()
            _S.graph.createOrRemovePlotIfNeeded(sim.getSimulationState() ~= sim.simulation_stopped)
        end
        
        -- events ---
        ---[[
        local currentCurves = {}
        for ct = 0, 2 do -- 0= time curves, 1= x/y curves, 2= 3D curves
            local index = 0
            while true do
                local label, info, curveColor, dataA, dataB, minMaxT, id, width, uid = sim.getGraphCurve(_S.graph.model, ct, index)
                index = index + 1
                if label then
                    currentCurves[uid] = true
                    local eventName = 'objectAdded'
                    if _S.graph.allIds_event[uid] then
                        eventName = 'objectChanged'
                    else
                        _S.graph.allIds_event[uid] = label
                        _S.graph.allCurves_event[#_S.graph.allCurves_event + 1] = uid
                    end
                    --[=[
                    local data = {}
                    data.objectType = 'graphCurve'
                    data.graph = _S.graph.model
                    data.label = label
                    data.info = info
                    data.color = curveColor
                    data.dataA = dataA
                    data.dataB = dataB
                    data.minMax = minMax
                    data.width = width
                    --]=]
                    local data = {info = 'curve data events disabled as of now. Enable in graph_customization-2.lua'}
                    sim.pushUserEvent(eventName, uid, uid, data, 0)
                else
                    break
                end
            end
            for i = 1, #_S.graph.allCurves_event do
                local uid = _S.graph.allCurves_event[i]
                if currentCurves[uid] == nil then
                    _S.graph.allIds_event[uid] = nil
                    sim.pushUserEvent('objectRemoved', uid, uid, {}, 0)
                end
            end
        end
        --]]
        -------------
        
        if _S.graph.plotUi then
            for pl = 1, #_S.graph.plots, 1 do
                local minMax = nil
                local ii = _S.graph.plots[pl]
                local index = 0
                local flag = false
                while true do
                    local label, curveType, curveColor, xData, yData, minMaxT = sim.getGraphCurve(_S.graph.model, ii - 1, index)
                    if not label then break end
                    local legendVisible = true
                    if (curveType & 4) ~= 0 then
                        legendVisible = false
                        curveType = curveType - 4
                    end
                    if #xData > 0 then
                        minMax = _S.graph.getMinMax(minMax, minMaxT)
                    end

                    if _S.graph.curves[ii][label] then
                        simUI.clearCurve(_S.graph.plotUi, ii, label)
                        if #xData > 0 and #yData > 0 then
                            if ii == 1 then
                                simUI.addCurveTimePoints(_S.graph.plotUi, ii, label, xData, yData)
                                if (minMaxT[2] - minMaxT[1] == 0 or minMaxT[4] - minMaxT[3] == 0) then
                                    simUI.addCurveTimePoints(
                                        _S.graph.plotUi, ii, label, {xData[#xData] + 0.000000001},
                                        {yData[#yData] + 0.000000001}
                                    )
                                end
                            else
                                local seq = {}
                                for i = 1, #xData, 1 do seq[i] = i end
                                simUI.addCurveXYPoints(_S.graph.plotUi, ii, label, seq, xData, yData)
                                if (minMaxT[2] - minMaxT[1] == 0 or minMaxT[4] - minMaxT[3] == 0) then
                                    simUI.addCurveXYPoints(
                                        _S.graph.plotUi, ii, label, {seq[#seq] + 1},
                                        {xData[#xData] + 0.000000001}, {yData[#yData] + 0.000000001}
                                    )
                                end
                            end
                            if (curveType & 2) == 0 then
                                --                                simUI.rescaleAxes(_S.graph.plotUi,ii,label,index~=0,index~=0) -- for non-static curves
                                simUI.rescaleAxes(_S.graph.plotUi, ii, label, flag, flag) -- for non-static curves
                                flag = true
                            end
                        end
                    end
                    index = index + 1
                end
                --            simUI.rescaleAxesAll(_S.graph.plotUi,ii,false,false)
                if minMax then
                    local rangeS = {minMax[2] - minMax[1], minMax[4] - minMax[3]}
                    simUI.growPlotXRange(_S.graph.plotUi, ii, rangeS[1] * 0.01, rangeS[1] * 0.01)
                    simUI.growPlotYRange(_S.graph.plotUi, ii, rangeS[2] * 0.01, rangeS[2] * 0.01)
                end
                simUI.replot(_S.graph.plotUi, ii)
            end
        end

        if _S.graph.xyzCurves ~= nil then
            local index = 0
            while true do
                local label, curveType, curveColor, xyzData, yData, minMaxT, curveId, width =
                    sim.getGraphCurve(
                        _S.graph.model, 2, index
                    )
                if not label then break end
                if _S.graph.xyzCurves[curveId] == nil then
                    if curveType & 2 == 2 then
                        width = 1 -- we have a static curve
                    end
                    _S.graph.xyzCurves[curveId] = sim.addDrawingObject(
                                                      sim.drawing_linestrip, width, 0, -1, 0,
                                                      curveColor, nil, nil, curveColor
                                                  )
                end
                if #xyzData > 5 then
                    sim.addDrawingObjectItem(
                        _S.graph.xyzCurves[curveId] + sim.handleflag_setmultiple, xyzData
                    )
                end
                index = index + 1
            end
        end
    end
end

function _S.graph.prepareCurves()
    if _S.graph.plotUi then
        for pl = 1, #_S.graph.plots, 1 do
            local minMax = nil
            local ii = _S.graph.plots[pl]
            for key, value in pairs(_S.graph.curves[ii]) do
                simUI.removeCurve(_S.graph.plotUi, ii, key)
            end
            _S.graph.curves[ii] = {}
            local index = 0
            local legendVisibleCnt = 0
            while true do
                local label, curveType, curveColor, xData, yData, minMaxT = sim.getGraphCurve(
                                                                                _S.graph.model,
                                                                                ii - 1, index
                                                                            )
                if not label then break end
                local legendVisible = true
                if (curveType & 4) ~= 0 then legendVisible = false end
                local curveStyle
                local curveOptions = {line_size = 1}
                if (curveType & 1) == 1 then
                    curveStyle = simUI.curve_style.scatter
                    curveOptions.scatter_shape = simUI.curve_scatter_shape.square
                    curveOptions.scatter_size = 4
                else
                    -- link points
                    curveStyle = simUI.curve_style.line
                    curveOptions.scatter_shape = simUI.curve_scatter_shape.none
                    curveOptions.scatter_size = 5
                end
                if (curveType & 2) == 2 then
                    -- static
                    if (curveType & 1) == 1 then
                        curveOptions.scatter_shape = simUI.curve_scatter_shape.plus
                    end
                    curveOptions.line_style = simUI.line_style.dashed
                end
                -- if (curveType&8)==8 then
                --    -- helper curves, for good framing
                --    curveStyle=simUI.curve_style.scatter
                --    curveOptions={scatter_size=0}
                -- end
                if legendVisible then
                    legendVisibleCnt = legendVisibleCnt + 1
                else
                    curveOptions.add_to_legend = false
                end
                if ii == 1 then
                    simUI.addCurve(
                        _S.graph.plotUi, ii, simUI.curve_type.time, label,
                        {curveColor[1] * 255, curveColor[2] * 255, curveColor[3] * 255}, curveStyle,
                        curveOptions
                    )
                else
                    simUI.addCurve(
                        _S.graph.plotUi, ii, simUI.curve_type.xy, label,
                        {curveColor[1] * 255, curveColor[2] * 255, curveColor[3] * 255}, curveStyle,
                        curveOptions
                    )
                end
                _S.graph.curves[ii][label] = true
                index = index + 1
            end
            simUI.setLegendVisibility(_S.graph.plotUi, ii, legendVisibleCnt > 0)
        end
    end

    _S.graph.updateCurves(true)
end

function _S.graph.getDefaultInfoForNonExistingFields(info)
    if not info['bitCoded'] then
        info['bitCoded'] = 1 + 2 + 4 + 8 -- 1=visible during simulation, 2=visible during non-simul, 4=show time plots, 8=show xy plots, 16=1:1 proportion for xy plots, 32=do not show 3d curves
    end
    if not info['graphPos'] then
        info['graphPos'] = 0 -- 0=bottom right, 1=top right, 2=top left, 3=bottom left, 4=center
    end
    if not info['updateFreq'] then
        info['updateFreq'] = 2 -- 0=100%, 1=50%, 2=25%, 3=10%, 4=1% of time
    end
end

function _S.graph.readInfo()
    local data = sim.readCustomBufferData(_S.graph.model, 'ABC_GRAPH_INFO')
    if data and #data > 0 then
        data = sim.unpackTable(data)
    else
        data = {}
    end
    _S.graph.getDefaultInfoForNonExistingFields(data)
    return data
end

function _S.graph.writeInfo(data)
    if data then
        sim.writeCustomBufferData(_S.graph.model, 'ABC_GRAPH_INFO', sim.packTable(data))
    else
        sim.writeCustomBufferData(_S.graph.model, 'ABC_GRAPH_INFO', '')
    end
end

function _S.graph.setDlgItemContent()
    if _S.graph.ui then
        local config = _S.graph.readInfo()
        local sel = simUI.getCurrentEditWidget(_S.graph.ui)
        simUI.setCheckboxValue(_S.graph.ui, 1, ((config['bitCoded'] & 2) == 0 and 0 or 2))
        simUI.setCheckboxValue(_S.graph.ui, 2, ((config['bitCoded'] & 1) == 0 and 0 or 2))
        simUI.setCheckboxValue(_S.graph.ui, 3, ((config['bitCoded'] & 4) == 0 and 0 or 2))
        simUI.setCheckboxValue(_S.graph.ui, 4, ((config['bitCoded'] & 8) == 0 and 0 or 2))
        simUI.setCheckboxValue(_S.graph.ui, 5, ((config['bitCoded'] & 16) == 0 and 0 or 2))
        simUI.setCheckboxValue(_S.graph.ui, 8, ((config['bitCoded'] & 32) == 0 and 2 or 0))

        local items = {'bottom right', 'top right', 'top left', 'bottom left', 'center'}
        simUI.setComboboxItems(_S.graph.ui, 6, items, config['graphPos'])

        local items = {'always', '1/2 of time', '1/4 of time', '1/10 of time', '1/100 of time'}
        simUI.setComboboxItems(_S.graph.ui, 7, items, config['updateFreq'])

        simUI.setCurrentEditWidget(_S.graph.ui, sel)
    end
end

function _S.graph.visibleDuringSimulation_callback(ui, id, newVal)
    local c = _S.graph.readInfo()
    c['bitCoded'] = (c['bitCoded'] | 1)
    if newVal == 0 then c['bitCoded'] = c['bitCoded'] - 1 end
    _S.graph.writeInfo(c)
    _S.graph.createOrRemovePlotIfNeeded(false)
    _S.graph.setDlgItemContent()
    sim.announceSceneContentChange()
end

function _S.graph.visibleDuringNonSimulation_callback(ui, id, newVal)
    local c = _S.graph.readInfo()
    c['bitCoded'] = (c['bitCoded'] | 2)
    if newVal == 0 then c['bitCoded'] = c['bitCoded'] - 2 end
    _S.graph.writeInfo(c)
    _S.graph.createOrRemovePlotIfNeeded(false)
    _S.graph.setDlgItemContent()
    sim.announceSceneContentChange()
end

function _S.graph.timeOnly_callback(ui, id, newVal)
    local c = _S.graph.readInfo()
    c['bitCoded'] = (c['bitCoded'] | 4)
    if newVal == 0 then c['bitCoded'] = c['bitCoded'] - 4 end
    _S.graph.writeInfo(c)
    _S.graph.removePlot()
    _S.graph.createOrRemovePlotIfNeeded(false)
    _S.graph.setDlgItemContent()
    sim.announceSceneContentChange()
end

function _S.graph.xyOnly_callback(ui, id, newVal)
    local c = _S.graph.readInfo()
    c['bitCoded'] = (c['bitCoded'] | 8)
    if newVal == 0 then c['bitCoded'] = c['bitCoded'] - 8 end
    _S.graph.writeInfo(c)
    _S.graph.removePlot()
    _S.graph.createOrRemovePlotIfNeeded(false)
    _S.graph.setDlgItemContent()
    sim.announceSceneContentChange()
end

function _S.graph.xyzOnly_callback(ui, id, newVal)
    local c = _S.graph.readInfo()
    c['bitCoded'] = (c['bitCoded'] | 32)
    if newVal ~= 0 then c['bitCoded'] = c['bitCoded'] - 32 end
    _S.graph.writeInfo(c)
    _S.graph.removePlot()
    _S.graph.createOrRemovePlotIfNeeded(false)
    _S.graph.setDlgItemContent()
    sim.announceSceneContentChange()
end

function _S.graph.squareXy_callback(ui, id, newVal)
    local c = _S.graph.readInfo()
    c['bitCoded'] = (c['bitCoded'] | 16)
    if newVal == 0 then c['bitCoded'] = c['bitCoded'] - 16 end
    _S.graph.writeInfo(c)
    _S.graph.removePlot()
    _S.graph.createOrRemovePlotIfNeeded(false)
    _S.graph.setDlgItemContent()
    sim.announceSceneContentChange()
end

function _S.graph.graphPosChanged_callback(ui, id, newIndex)
    local c = _S.graph.readInfo()
    c['graphPos'] = newIndex
    _S.graph.writeInfo(c)
    _S.graph.removePlot()
    _S.graph.previousPlotDlgPos = nil
    _S.graph.previousPlotDlgSize = nil
    _S.graph.createOrRemovePlotIfNeeded(false)
    _S.graph.setDlgItemContent()
    sim.announceSceneContentChange()
end

function _S.graph.updateFreqChanged_callback(ui, id, newIndex)
    local c = _S.graph.readInfo()
    c['updateFreq'] = newIndex
    _S.graph.writeInfo(c)
    _S.graph.updateTick = _S.graph.getUpdateTick(newIndex)
    _S.graph.updateCnt = 0
    sim.announceSceneContentChange()
end

function _S.graph.removePlot()
    if _S.graph.plotUi then
        local x, y = simUI.getPosition(_S.graph.plotUi)
        _S.graph.previousPlotDlgPos = ' placement="absolute" position="' .. x .. ',' .. y .. '" '
        local x, y = simUI.getSize(_S.graph.plotUi)
        _S.graph.previousPlotDlgSize = ' size="' .. x .. ',' .. y .. '" '
        _S.graph.plotTabIndex = #_S.graph.plots > 1 and simUI.getCurrentTab(_S.graph.plotUi, 77) or
                                    0
        simUI.destroy(_S.graph.plotUi)
        _S.graph.plotUi = nil
    end
end

function _S.graph.onClosePlot_callback()
    if sim.getSimulationState() == sim.simulation_stopped then
        local c = _S.graph.readInfo()
        c['bitCoded'] = (c['bitCoded'] | 2) - 2
        _S.graph.writeInfo(c)
        _S.graph.setDlgItemContent()
    end
    _S.graph.removePlot()
end

function _S.graph.createPlot()
    if not _S.graph.plotUi then
        local c = _S.graph.readInfo()
        _S.graph.plots = {}

        local bgCol = '25,25,25'
        local fgCol = '150,150,150'
        local bitCoded, colA, colB = sim.getGraphInfo(_S.graph.model)
        bgCol = (math.floor(colA[1] * 255.1)) .. ',' .. (math.floor(colA[2] * 255.1)) .. ',' ..
                    (math.floor(colA[3] * 255.1))
        fgCol = (math.floor(colB[1] * 255.1)) .. ',' .. (math.floor(colB[2] * 255.1)) .. ',' ..
                    (math.floor(colB[3] * 255.1))

        if ((c['bitCoded'] & 4) ~= 0) then table.insert(_S.graph.plots, 1) end
        if ((c['bitCoded'] & 8) ~= 0) then table.insert(_S.graph.plots, 2) end

        if not _S.graph.previousPlotDlgPos then
            if c['graphPos'] == 0 then
                _S.graph.previousPlotDlgPos = ' placement="relative" position="-50,-50" '
            end
            if c['graphPos'] == 1 then
                _S.graph.previousPlotDlgPos = ' placement="relative" position="-50,50" '
            end
            if c['graphPos'] == 2 then
                _S.graph.previousPlotDlgPos = ' placement="relative" position="50,50" '
            end
            if c['graphPos'] == 3 then
                _S.graph.previousPlotDlgPos = ' placement="relative" position="50,-50" '
            end
            if c['graphPos'] == 4 then
                _S.graph.previousPlotDlgPos = ' placement="center" '
            end
        end

        if not _S.graph.previousPlotDlgSize then _S.graph.previousPlotDlgSize = '' end

        local xml = '<ui title="' .. sim.getObjectAlias(_S.graph.model, 1) ..
                        '" closeable="true" on-close="_S.graph.onClosePlot_callback" resizable="true" activate="false" layout="grid" ' ..
                        _S.graph.previousPlotDlgPos .. _S.graph.previousPlotDlgSize .. '>'
        if #_S.graph.plots > 1 then xml = xml .. '<tabs id="77">' end
        if ((c['bitCoded'] & 4) ~= 0) then
            if #_S.graph.plots > 1 then xml = xml .. '<tab title="Time graph">' end
            xml = xml ..
                      '<plot id="1" on-click="_S.graph.onclickCurve" on-legend-click="_S.graph.onlegendclick" max-buffer-size="100000" cyclic-buffer="false" background-color="' ..
                      bgCol .. '" foreground-color="' .. fgCol .. '"/>'
            if #_S.graph.plots > 1 then xml = xml .. '</tab>' end
        end
        if ((c['bitCoded'] & 8) ~= 0) then
            local squareAttribute = ''
            if ((c['bitCoded'] & 16) ~= 0) then squareAttribute = 'square="true"' end
            if #_S.graph.plots > 1 then xml = xml .. '<tab title="X/Y graph">' end
            xml = xml ..
                      '<plot id="2" on-click="_S.graph.onclickCurve" on-legend-click="_S.graph.onlegendclick" max-buffer-size="100000" cyclic-buffer="false" background-color="' ..
                      bgCol .. '" foreground-color="' .. fgCol .. '" ' .. squareAttribute .. '/>'
            if #_S.graph.plots > 1 then xml = xml .. '</tab>' end
        end
        if #_S.graph.plots > 1 then xml = xml .. '</tabs><br/>' end
        xml = xml .. '<label id="3" /></ui>'

        _S.graph.plotUi = simUI.create(xml)
        -- _S.graph.plotUi=_S.graph.utils.createCustomUi(xml,sim.getObjectAlias(_S.graph.model,1),_S.graph.previousPlotDlgPos,true,"_S.graph.onClosePlot_callback",false,true,false,'layout="grid"',_S.graph.previousPlotDlgSize)
        if ((c['bitCoded'] & 4) ~= 0) then
            simUI.setPlotLabels(_S.graph.plotUi, 1, "Time (seconds)", "")
        end
        if ((c['bitCoded'] & 8) ~= 0) then simUI.setPlotLabels(_S.graph.plotUi, 2, "X", "Y") end
        if #_S.graph.plots == 1 then _S.graph.plotTabIndex = 0 end
        if #_S.graph.plots > 1 then
            xml = xml .. '</tabs><br/>'
            simUI.setCurrentTab(_S.graph.plotUi, 77, _S.graph.plotTabIndex, true)
        end

        _S.graph.curves = {{}, {}}
        _S.graph.prepareCurves()

        local s = sim.getSimulationState()
        _S.graph.enableMouseInteractions(
            (s == sim.simulation_stopped) or (s == sim.simulation_paused)
        )
    end
end

function _S.graph.remove3dCurves()
    if _S.graph.xyzCurves then
        for k, val in pairs(_S.graph.xyzCurves) do sim.removeDrawingObject(val) end
        _S.graph.xyzCurves = nil
    end
end

function _S.graph.createOrRemovePlotIfNeeded(forSimulation)
    local c = _S.graph.readInfo()
    if forSimulation then
        if ((c['bitCoded'] & 1) == 0) or ((c['bitCoded'] & 12) == 0) then
            _S.graph.removePlot()
        else
            _S.graph.createPlot()
        end
        if ((c['bitCoded'] & 1) == 0) or ((c['bitCoded'] & 32) ~= 0) then
            _S.graph.remove3dCurves()
        else
            if _S.graph.xyzCurves == nil then _S.graph.xyzCurves = {} end
        end
    else
        if ((c['bitCoded'] & 2) == 0) or ((c['bitCoded'] & 12) == 0) then
            _S.graph.removePlot()
        else
            _S.graph.createPlot()
        end
        if ((c['bitCoded'] & 2) == 0) or ((c['bitCoded'] & 32) ~= 0) then
            _S.graph.remove3dCurves()
        else
            if _S.graph.xyzCurves == nil then _S.graph.xyzCurves = {} end
        end
    end
end

function _S.graph.getUpdateTick(v)
    if v == 1 then return 2 end
    if v == 2 then return 4 end
    if v == 3 then return 10 end
    if v == 4 then return 100 end
    return 1
end

function _S.graph.init()
    _S.graph.model = sim.getObject('..')
    if sim.getExplicitHandling(_S.graph.model) == 0 then
        sim.setExplicitHandling(_S.graph.model, 1)
    end
    _S.graph.allCurves_event = {}
    _S.graph.allIds_event = {}
    local c = _S.graph.readInfo()
    _S.graph.updateTick = _S.graph.getUpdateTick(c['updateFreq'])
    _S.graph.updateCnt = 0
    _S.graph.plotTabIndex = 0
    _S.graph.createOrRemovePlotIfNeeded()
    _S.graph.updateCurves(true)
end

function _S.graph.cleanup()
    _S.graph.removePlot()
    for i = 1, #_S.graph.allCurves_event do
        local uid = _S.graph.allCurves_event[i]
        sim.pushUserEvent('objectRemoved', uid, uid, {}, 0)
    end
end

function _S.graph.beforeSimulation()
    _S.graph.reset()
end

function _S.graph.afterSimulation()
    _S.graph.createOrRemovePlotIfNeeded(false)
    _S.graph.updateCurves(true)
    _S.graph.enableMouseInteractions(true)
end

function _S.graph.reset()
    -- i.e. reset graph and start recording
    sim.resetGraph(_S.graph.model)
    _S.graph.removePlot()
    _S.graph.createOrRemovePlotIfNeeded(true)
    _S.graph.prepareCurves()
    _S.graph.clearCurves()
    _S.graph.enableMouseInteractions(false)
end

function _S.graph.handle(recordingTime)
    if sim.getSimulationState() ~= sim.simulation_advancing_abouttostop and sim.getSimulationState() ~=
        sim.simulation_advancing_lastbeforestop then
        if recordingTime == nil then
            recordingTime = sim.getSimulationTime() + sim.getSimulationTimeStep()
        end
        sim.handleGraph(_S.graph.model, recordingTime)
    end
end

return _S.graph
