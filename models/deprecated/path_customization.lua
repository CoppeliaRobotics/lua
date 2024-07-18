sim = require 'sim'

function sysCall_init()
    _S.path.init()
end

function sysCall_cleanup()
    _S.path.cleanup()
end

function sysCall_nonSimulation()
    _S.path.nonSimulation()
end

function sysCall_afterSimulation()
    _S.path.afterSimulation()
end

function sysCall_beforeSimulation()
    _S.path.beforeSimulation()
end

function sysCall_beforeInstanceSwitch()
    _S.path.beforeInstanceSwitch()
end

function sysCall_afterInstanceSwitch()
    _S.path.afterInstanceSwitch()
end

function sysCall_userConfig()
    if sim.getSimulationState() == sim.simulation_stopped then _S.path.openUserConfigDlg() end
end

function sysCall_beforeCopy(inData)
    for key, value in pairs(inData.objectHandles) do
        if _S.path.ctrlPtsMap[key] then
            -- This ctrl point will be copied, append some temp data:
            local dat = sim.readCustomBufferData(key, _S.path.ctrlPtsTag)
            dat = sim.unpackTable(dat)
            dat.pasteTo = _S.path.uniqueId
            sim.writeCustomBufferData(key, _S.path.ctrlPtsTag, sim.packTable(dat))
        end
    end
end

function sysCall_afterCopy(inData)
    for key, value in pairs(inData.objectHandles) do
        if _S.path.ctrlPtsMap[key] then
            -- This ctrl point was copied. Remove the temp data previously added:
            local dat = sim.readCustomBufferData(key, _S.path.ctrlPtsTag)
            dat = sim.unpackTable(dat)
            dat.pasteTo = nil
            sim.writeCustomBufferData(key, _S.path.ctrlPtsTag, sim.packTable(dat))
        end
    end
end

function sysCall_afterCreate(inData)
    local pts = {}
    for i = 1, #inData.objectHandles, 1 do
        local h = inData.objectHandles[i]
        if sim.getObjectParent(h) == -1 then
            local dat = sim.readCustomBufferData(h, _S.path.ctrlPtsTag)
            if dat and #dat > 0 then
                dat = sim.unpackTable(dat)
                if dat.pasteTo == _S.path.uniqueId then
                    dat.pasteTo = nil
                    pts[#pts + 1] = dat
                    dat.handle = h
                end
            end
        end
    end
    if #pts > 0 then
        table.sort(
            pts, function(a, b)
                return a.index < b.index
            end
        )
        local highIndex = pts[#pts].index
        for i = 1, #pts, 1 do
            pts[i].index = highIndex + (pts[i].index / 100000)
            sim.writeCustomBufferData(pts[i].handle, _S.path.ctrlPtsTag, sim.packTable(pts[i]))
            sim.setObjectParent(pts[i].handle, _S.path.model, true)
        end
        _S.path.setup()
    end
end

function sysCall_afterDelete(inData)
    local update = false
    for key, value in pairs(inData.objectHandles) do
        if _S.path.ctrlPtsMap[key] then
            -- This ctrl point was erased. Update the path
            update = true
            break
        end
    end
    if update then _S.path.setup() end
end

_S.path = {}

function _S.path.init()
    _S.path.ctrlPtsTag = 'ABC_PATHCTRLPT'
    _S.path.pathObjectTag = 'ABC_PATH_INFO'
    _S.path.pathCreationTag = 'ABC_PATH_CREATION'
    _S.path.shapeTag = 'ABC_PATHSHAPE_INFO'
    _S.path.childTag = 'PATH_CHILD' -- old: childTag not used anymore
    _S.path.model = sim.getObject('.')
    _S.path.uniqueId = sim.getStringParam(sim.stringparam_uniqueid)
    _S.path.refreshDelay = 0.2
    _S.path.lastRefreshTime = sim.getSystemTime()
    _S.path.lineCont = {-1, -1}
    _S.path.tickCont = {-1, -1, -1}
    _S.path.createNewIfNeeded()
    _S.path.forceFullRebuild = true
    return _S.path.setup()
end

function _S.path.beforeInstanceSwitch()
    _S.path.hideCtrlPtDlg()
    _S.path.closeToReopenUserConfigDlg()
end

function _S.path.afterInstanceSwitch()
    _S.path.reopenUserConfigDlg()
end

function _S.path.reopenUserConfigDlg()
    if _S.path.reopenUserConfDlg then _S.path.openUserConfigDlg() end
end

function _S.path.openUserConfigDlg()
    if _S.path.ui == nil then
        simUI = require 'simUI'
        _S.path.reopenUserConfDlg = nil
        local pos = ' placement="relative" position="-50,50" '
        if _S.path.pathDlgPos then
            pos = ' placement="absolute" position="' .. _S.path.pathDlgPos[1] .. ',' ..
                      _S.path.pathDlgPos[2] .. '" '
        end
        local xml = '<ui title="' .. sim.getObjectAlias(_S.path.model, 1) ..
                        '" closeable="true" on-close="_S.path.closeUserConfigDlg" modal="false" ' ..
                        pos .. [[>
            <label text="Main properties:" style="* {font-weight: bold;}"/>
            <group layout="form" flat="true">

            <checkbox text="Path is closed" on-change="_S.path.closed_callback" id="1" />
            <label text=""/>

            <checkbox text="Generate extruded shape" on-change="_S.path.generateShape_callback" id="3" />
            <label text=""/>

            <checkbox text="Hidden path during simulation" on-change="_S.path.hideDuringSimulation_callback" id="2" />
            <label text=""/>

            <checkbox text="Path && ctrl points always hidden" on-change="_S.path.alwaysHide_callback" id="16" />
            <label text=""/>

            <checkbox text="Show orientation frames" on-change="_S.path.showOrientation_callback" id="14" />
            <label text=""/>

            <checkbox text="Show control point dialog" on-change="_S.path.noCtrlPtDlg_callback" id="17" />
            <label text=""/>

            <label text="Smoothness"/>
            <edit on-editing-finished="_S.path.smoothness_callback" id="4" />

            <label text="Subdivisions"/>
            <edit on-editing-finished="_S.path.pointCnt_callback" id="5" />
            </group>

            <checkbox text="Automatic path orientation:" style="* {font-weight: bold;}" on-change="_S.path.autoOrient_callback" id="6"/>
            <group layout="form" flat="true" id="15">

            <radiobutton text="X axis along path, Y axis up" on-click="_S.path.align_callback" id="7"/>
            <label text=""/>

            <radiobutton text="X axis along path, Z axis up" on-click="_S.path.align_callback" id="8"/>
            <label text=""/>

            <radiobutton text="Y axis along path, X axis up" on-click="_S.path.align_callback" id="9"/>
            <label text=""/>

            <radiobutton text="Y axis along path, Z axis up" on-click="_S.path.align_callback" id="10"/>
            <label text=""/>

            <radiobutton text="Z axis along path, X axis up" on-click="_S.path.align_callback" id="11"/>
            <label text=""/>

            <radiobutton text="Z axis along path, Y axis up" on-click="_S.path.align_callback" id="12"/>
            <label text=""/>

            <label text="Up vector"/>
            <edit on-editing-finished="_S.path.upVector_callback" id="13" />

            </group>

            <label text="Initialize path from ctrl point data:" style="* {font-weight: bold;}"/>
            <group layout="vbox" flat="true">

            <edit id="20" />
            <button text="ctrl points as position data, i.e. x,y,z,..." on-click="_S.path.generate_callback" id="21"/>
            <button text="ctrl points as pose data, i.e. x,y,z,qx,qy,qz,qw,..." on-click="_S.path.generate_callback" id="22"/>
            </group>

            <label text="Output path data:" style="* {font-weight: bold;}"/>
            <group layout="vbox" flat="true">
            <button text="Copy to status bar" on-click="_S.path.output_callback" id="31"/>
            </group>
        </ui>]]
        _S.path.ui = simUI.create(xml)
        _S.path.setDlgItemContent()
    end
end

function _S.path.createNewIfNeeded()
    local data = sim.readCustomBufferData(_S.path.model, _S.path.pathCreationTag)
    if data and #data > 0 then
        data = sim.unpackTable(data)
        sim.writeCustomBufferData(_S.path.model, _S.path.pathCreationTag, '')
        _S.path.createNew(data[1], false, data[2], data[3], data[4], data[5], data[6])
    end
end

function _S.path.createNew(ctrlPts, onlyPosData, options, pointCount, smoothing,
                           autoOrientationMode, upVector)
    local c = _S.path.readInfo()
    c.bitCoded = options
    c.pointCnt = pointCount
    c.smoothing = smoothing
    c.autoOrientation = autoOrientationMode
    c.upVector = upVector
    _S.path.writeInfo(c)
    local tmp1 = sysCall_beforeCopy
    sysCall_beforeCopy = nil
    local tmp2 = sysCall_afterCopy
    sysCall_afterCopy = nil
    local tmp3 = sysCall_afterCreate
    sysCall_afterCreate = nil
    local tmp4 = sysCall_afterDelete
    sysCall_afterDelete = nil

    local children = sim.getObjectsInTree(_S.path.model, sim.sceneobject_dummy, 1)
    sim.removeObjects(children)
    
    local dof = 7
    if onlyPosData then dof = 3 end
    local function fp(p, i)
        return {p[dof * (i - 1) + 1], p[dof * (i - 1) + 2], p[dof * (i - 1) + 3]}
    end
    local function fq(p, i)
        return {p[7 * (i - 1) + 4], p[7 * (i - 1) + 5], p[7 * (i - 1) + 6], p[7 * (i - 1) + 7]}
    end
    for i = 1, #ctrlPts // dof, 1 do
        ctrlPt = sim.createDummy(0.01, {0, 0.96, 0.66, 0, 0, 0, 0, 0, 0, 0, 0, 0})
        sim.setObjectParent(ctrlPt, _S.path.model, true)
        sim.setObjectPosition(ctrlPt, fp(ctrlPts, i), _S.path.model)
        sim.setObjectAlias(ctrlPt, 'ctrlPt')
        if onlyPosData then
            sim.setObjectQuaternion(ctrlPt, {0, 0, 0, 1}, _S.path.model)
        else
            sim.setObjectQuaternion(ctrlPt, fq(ctrlPts, i), _S.path.model)
        end
        sim.writeCustomBufferData(ctrlPt, _S.path.ctrlPtsTag, sim.packTable({index = i}))
    end

    sysCall_afterDelete = tmp4
    sysCall_afterCreate = tmp3
    sysCall_afterCopy = tmp2
    sysCall_beforeCopy = tmp1
end

function _S.path.cleanup()
    _S.path.hideCtrlPtDlg()
    _S.path.closeUserConfigDlg()
    -- Untag path dummies that are not part of the control pts (e.g. from another path):
    local d = sim.getObjectsInTree(_S.path.model, sim.sceneobject_dummy, 1)
    for i = 1, #d, 1 do
        local h = d[i]
        local dat = sim.readCustomBufferData(h, _S.path.ctrlPtsTag)
        if dat and #dat > 0 and _S.path.ctrlPtsMap[h] == nil then
            sim.writeCustomBufferData(h, _S.path.ctrlPtsTag, '')
            sim.writeCustomStringData(h, _S.path.childTag, '') -- old: childTag not used anymore
        end
    end
end

function _S.path.nonSimulation()
    if not _S.path.refresh then
        if _S.path.getCtrlPtsPoseId() ~= _S.path.ctrlPtsPoseId then _S.path.refresh = true end
    end
    if _S.path.refresh and sim.getSystemTime() - _S.path.lastRefreshTime > _S.path.refreshDelay then
        _S.path.setup()
    end
    local c = _S.path.readInfo()
    local selectedCtrlPts = {}
    if (c.bitCoded & 64) ~= 0 then
        -- Maybe open the ctrl pt dialog
        local s = sim.getObjectSel()
        if #s > 0 then
            selectedCtrlPts = s
            for i = 1, #s, 1 do
                if _S.path.ctrlPtsMap[s[i]] == nil then
                    selectedCtrlPts = {}
                    break
                end
            end
        end
    end
    if #selectedCtrlPts > 0 then
        _S.path.showCtrlPtDlg(selectedCtrlPts)
    else
        _S.path.hideCtrlPtDlg()
    end

    -- Check if we need to display the insert ctrl pt dialog:
    local s = sim.getObjectSel()
    local insert = #s > 1
    for i = 1, #s, 1 do
        if sim.getObjectType(s[i]) ~= sim.sceneobject_dummy then
            insert = false
            break
        end
        if i == #s then
            if _S.path.ctrlPtsMap[s[i]] == nil then
                insert = false
                break
            end
        else
            if _S.path.ctrlPtsMap[s[i]] ~= nil then
                insert = false
                break
            end
        end
    end
    if insert then
        _S.path.showInsertCtrlPtDlg()
    else
        _S.path.hideInsertCtrlPtDlg()
    end
end

function _S.path.afterSimulation()
    local c = _S.path.readInfo()
    _S.path.displayLine(1)
    _S.path.displayLine(2)
    local v = 4
    if (c.bitCoded & 32) ~= 0 then v = 0 end
    for i = 1, #_S.path.ctrlPts, 1 do
        local h = _S.path.ctrlPts[i].handle
        sim.setObjectInt32Param(h, sim.objintparam_visibility_layer, v)
    end
    _S.path.reopenUserConfigDlg()
end

function _S.path.beforeSimulation()
    _S.path.hideCtrlPtDlg()
    _S.path.hideInsertCtrlPtDlg()
    _S.path.removeLine(1)
    local c = _S.path.readInfo()
    if c.bitCoded & 1 ~= 0 then _S.path.removeLine(2) end
    for i = 1, #_S.path.ctrlPts, 1 do
        local h = _S.path.ctrlPts[i].handle
        sim.setObjectInt32Param(h, sim.objintparam_visibility_layer, 0)
    end
    _S.path.closeToReopenUserConfigDlg()
end

function _S.path.getCtrlPtsPoseId()
    local p = {}
    for i = 1, #_S.path.ctrlPts, 1 do
        local h = _S.path.ctrlPts[i].handle
        p[2 * (i - 1) + 1] = sim.getObjectPosition(h, sim.handle_parent)
        p[2 * (i - 1) + 2] = sim.getObjectQuaternion(h, sim.handle_parent)
    end
    return sim.packTable(p)
end

function _S.path.computeFingerPrint()
    local p = {}
    local p1 = {}
    for i = 1, #_S.path.ctrlPts, 1 do
        local pp = sim.getObjectPose(_S.path.ctrlPts[i].handle, sim.handle_parent)
        for j = 1, 7, 1 do p1[#p1 + 1] = pp[j] end
    end
    return {sim.packFloatTable(p1), sim.packTable(_S.path.readInfo())}
end

function _S.path.areFingerPrintSame(fp1, fp2)
    if #fp1 == 0 or #fp2 == 0 or #fp1[1] ~= #fp2[1] or fp1[2] ~= fp2[2] then return false end
    local p1 = sim.unpackFloatTable(fp1[1])
    local p2 = sim.unpackFloatTable(fp2[1])
    for i = 1, #p1, 1 do if math.abs(p1[i] - p2[i]) > 0.0001 then return false end end
    return true
end

function _S.path.setPathShape(shape)
    local shapes = sim.getObjectsInTree(_S.path.model, sim.sceneobject_shape, 1 + 2)
    for i = 1, #shapes, 1 do
        local dat = sim.readCustomStringData(shapes[i], _S.path.shapeTag)
        if dat and #dat > 0 then sim.removeObjects({shapes[i]}) end
    end
    if sim.isHandle(shape) then
        sim.writeCustomStringData(shape, _S.path.shapeTag, "a")
        sim.setObjectParent(shape, _S.path.model, false)
        local p = sim.getObjectProperty(shape)
        sim.setObjectProperty(
            shape, p | sim.objectproperty_selectmodelbaseinstead |
                sim.objectproperty_dontshowasinsidemodel
        )
        sim.setObjectAlias(shape, 'shape')
        sim.writeCustomStringData(shape, _S.path.childTag, '') -- old: childTag not used anymore
    end
end

function _S.path.getPathShapeColor()
    local shapes = sim.getObjectsInTree(_S.path.model, sim.sceneobject_shape, 1 + 2)
    for i = 1, #shapes, 1 do
        local dat = sim.readCustomStringData(shapes[i], _S.path.shapeTag)
        if dat and #dat > 0 then
            local r, col = sim.getShapeColor(shapes[i], '', sim.colorcomponent_ambient_diffuse)
            return col
        end
    end
end

function _S.path.setup()
    local ctrlPtsHandles = _S.path.getCtrlPts()
    _S.path.removeLine(1)
    _S.path.removeLine(2)
    if #_S.path.ctrlPts > 1 then
        local fingerPrint = _S.path.computeFingerPrint()
        local ffp = sim.readCustomTableData(_S.path.model, '__pathFingerPrint__')
        local c = _S.path.readInfo()
        _S.path.paths = {}
        if not _S.path.areFingerPrintSame(fingerPrint, ffp) or _S.path.forceFullRebuild then
            _S.path.forceFullRebuild = nil
            sim.writeCustomTableData(_S.path.model, '__pathFingerPrint__', fingerPrint)
            _S.path.paths[1], _S.path.paths[2], _S.path.paths[3], _S.path.paths[4] = _S.path
                                                                                         .computePaths()
            if (c.bitCoded & 2) ~= 0 then -- path is closed. First and last pts are duplicate
                sim.writeCustomBufferData(
                    _S.path.model, 'PATHCTRLPTS',
                    sim.packDoubleTable(_S.path.paths[1], 0, #_S.path.paths[1] - 7)
                )
                sim.writeCustomBufferData(
                    _S.path.model, 'PATHCTRLPTS_X',
                    sim.packDoubleTable(_S.path.paths[3], 0, #_S.path.paths[3] - 5)
                )
            else
                sim.writeCustomBufferData(
                    _S.path.model, 'PATHCTRLPTS', sim.packDoubleTable(_S.path.paths[1])
                )
                sim.writeCustomBufferData(
                    _S.path.model, 'PATHCTRLPTS_X', sim.packDoubleTable(_S.path.paths[3])
                )
            end
            sim.writeCustomBufferData(_S.path.model, 'PATH', sim.packDoubleTable(_S.path.paths[2]))
            sim.writeCustomBufferData(_S.path.model, 'PATH_X', sim.packDoubleTable(_S.path.paths[4]))

            local prevColor = _S.path.getPathShapeColor()
            _S.path.setPathShape(-1)
            if _S.path.shaping and (c.bitCoded & 4) ~= 0 then
                local s = _S.path.shaping(_S.path.paths[2], (c.bitCoded & 2) ~= 0, c.upVector)
                _S.path.setPathShape(s)
                if prevColor then
                    sim.setShapeColor(s, '', sim.colorcomponent_ambient_diffuse, prevColor)
                end
            end

            if _S.path.refreshTrigger then
                _S.path.refreshTrigger(ctrlPtsHandles, _S.path.paths[2], c)
            end
        else
            _S.path.paths[1] = sim.unpackDoubleTable(
                                   sim.readCustomBufferData(
                                       _S.path.model, 'PATHCTRLPTS'
                                   )
                               )
            _S.path.paths[2] = sim.unpackDoubleTable(sim.readCustomBufferData(_S.path.model, 'PATH'))
            _S.path.paths[3] = sim.unpackDoubleTable(
                                   sim.readCustomBufferData(
                                       _S.path.model, 'PATHCTRLPTS_X'
                                   )
                               )
            _S.path.paths[4] = sim.unpackDoubleTable(
                                   sim.readCustomBufferData(_S.path.model, 'PATH_X')
                               )
            if (c.bitCoded & 2) ~= 0 then -- path is closed. First and last pts are duplicate
                for i = 1, 7, 1 do
                    _S.path.paths[1][#_S.path.paths[1] + 1] = _S.path.paths[1][i]
                end
                for i = 1, 5, 1 do
                    _S.path.paths[3][#_S.path.paths[3] + 1] = _S.path.paths[3][i]
                end
            end
        end
        _S.path.displayLine(1)
        _S.path.displayLine(2)
        _S.path.refresh = false
        _S.path.lastRefreshTime = sim.getSystemTime()
    else
        sysCall_afterDelete = nil
        sysCall_beforeCopy = nil
        sysCall_afterCopy = nil
        sysCall_afterCreate = nil
        sim.removeModel(_S.path.model)
    end
    if sim.getSimulationState() ~= sim.simulation_stopped then _S.path.beforeSimulation() end
    return ctrlPtsHandles, _S.path.paths[2]
end

function _S.path.computePaths()
    local c = _S.path.readInfo()
    local handles = {}
    for i = 1, #_S.path.ctrlPts, 1 do handles[i] = _S.path.ctrlPts[i].handle end
    if (c.bitCoded & 2) ~= 0 then handles[#handles + 1] = handles[1] end

    local path = {}
    for i = 1, #handles, 1 do
        local p = sim.getObjectPosition(handles[i], _S.path.model)
        path[#path + 1] = p[1]
        path[#path + 1] = p[2]
        path[#path + 1] = p[3]
        local q = sim.getObjectQuaternion(handles[i], _S.path.model)
        path[#path + 1] = q[1]
        path[#path + 1] = q[2]
        path[#path + 1] = q[3]
        path[#path + 1] = q[4]
        local data = sim.readCustomBufferData(handles[i], _S.path.ctrlPtsTag)
        data = sim.unpackTable(data)
        local auxDat = {0, 0, 0, 0, 0}
        if data.virtualDist then auxDat[1] = data.virtualDist end
        if data.auxChannels then for j = 1, 4, 1 do auxDat[1 + j] = data.auxChannels[j] end end
        for j = 1, 5, 1 do path[#path + 1] = auxDat[j] end
    end

    local function cb(a, b)
        return sim.getConfigDistance(a, b, {1, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0})
    end

    local lengths1, totL = sim.getPathLengths(path, 12, cb)

    local interpolatedPath1 = {}

    if c.smoothing ~= 0 then
        local ptCnt = c.pointCnt * 2
        for i = 1, ptCnt, 1 do
            local pp
            local t = (i - 1) * totL / (ptCnt - 1)
            pp = sim.getPathInterpolatedConfig(
                     path, lengths1, t,
                     {type = 'quadraticBezier', forceOpen = false, strength = c.smoothing},
                     {0, 0, 0, 2, 2, 2, 2, 0, 0, 0, 0, 0}
                 )
            for j = 1, #pp, 1 do interpolatedPath1[(i - 1) * 12 + j] = pp[j] end
        end
    else
        interpolatedPath1 = path
    end

    local interpolatedPath2 = {}
    local lengths2, totL = sim.getPathLengths(interpolatedPath1, 12, cb)
    local ptCnt = c.pointCnt
    for i = 1, ptCnt, 1 do
        local t = (i - 1) * totL / (ptCnt - 1)
        local pp = sim.getPathInterpolatedConfig(
                       interpolatedPath1, lengths2, t, nil, {0, 0, 0, 2, 2, 2, 2, 0, 0, 0, 0, 0}
                   )
        for j = 1, #pp, 1 do interpolatedPath2[(i - 1) * 12 + j] = pp[j] end
    end
    local mPath = Matrix(#path // 12, 12, path)
    local mInterpPath = Matrix(#interpolatedPath2 // 12, 12, interpolatedPath2)

    interpolatedPath2 = _S.path.recomputeOrientations(
                            mInterpPath:slice(1, 1, mInterpPath:rows(), 7):data()
                        )

    return mPath:slice(1, 1, mPath:rows(), 7):data(), interpolatedPath2,
           mPath:slice(1, 8, mPath:rows(), mPath:cols()):data(),
           mInterpPath:slice(1, 8, mInterpPath:rows(), mInterpPath:cols()):data()
end

function _S.path.displayLine(index)
    _S.path.removeLine(index)
    local c = _S.path.readInfo()
    local p = sim.getModelProperty(_S.path.model)
    if (p & sim.modelproperty_not_visible) == 0 and (c.bitCoded & 32) == 0 then
        local m = sim.getObjectMatrix(_S.path.model)
        local path = _S.path.paths[index]
        local dr, col, s
        if index == 1 then
            col = {c.line.color[1] * 1.2, c.line.color[2] * 1.2, c.line.color[3] * 1.2}
            s = 1
        else
            col = c.line.color
            s = c.line.thickness
        end
        _S.path.lineCont[index] = sim.addDrawingObject(
                                      sim.drawing_lines, s, 0, _S.path.model, 9999, col
                                  )
        local cont = _S.path.lineCont[index]
        for i = 0, (#path / 7) - 2, 1 do
            local p1 = {path[i * 7 + 1], path[i * 7 + 2], path[i * 7 + 3]}
            local p2 = {path[(i + 1) * 7 + 1], path[(i + 1) * 7 + 2], path[(i + 1) * 7 + 3]}
            p1 = sim.multiplyVector(m, p1)
            p2 = sim.multiplyVector(m, p2)
            local l = {p1[1], p1[2], p1[3], p2[1], p2[2], p2[3]}
            sim.addDrawingObjectItem(cont, l)
        end
        if index == 2 and (c.bitCoded & 8) ~= 0 then
            _S.path.tickCont[1] = sim.addDrawingObject(
                                      sim.drawing_lines, 1, 0, _S.path.model, 9999, {1, 0, 0}
                                  )
            _S.path.tickCont[2] = sim.addDrawingObject(
                                      sim.drawing_lines, 1, 0, _S.path.model, 9999, {0, 1, 0}
                                  )
            _S.path.tickCont[3] = sim.addDrawingObject(
                                      sim.drawing_lines, 1, 0, _S.path.model, 9999, {0, 0, 1}
                                  )
            local p = sim.getObjectPosition(_S.path.model)
            local q = sim.getObjectQuaternion(_S.path.model)
            local m = Matrix4x4:frompose({p[1], p[2], p[3], q[1], q[2], q[3], q[4]})
            for i = 0, (#path / 7) - 1, 1 do
                local m0 = Matrix4x4:frompose(
                               {
                        path[i * 7 + 1], path[i * 7 + 2], path[i * 7 + 3], path[i * 7 + 4],
                        path[i * 7 + 5], path[i * 7 + 6], path[i * 7 + 7],
                    }
                           )
                m0 = m * m0
                local p2 = m0 * Vector({_S.path.ctrlPtsSize, 0, 0, 1})
                local l = {m0[1][4], m0[2][4], m0[3][4], p2[1], p2[2], p2[3]}
                sim.addDrawingObjectItem(_S.path.tickCont[1], l)
                local p2 = m0 * Vector({0, _S.path.ctrlPtsSize, 0, 1})
                local l = {m0[1][4], m0[2][4], m0[3][4], p2[1], p2[2], p2[3]}
                sim.addDrawingObjectItem(_S.path.tickCont[2], l)
                local p2 = m0 * Vector({0, 0, _S.path.ctrlPtsSize, 1})
                local l = {m0[1][4], m0[2][4], m0[3][4], p2[1], p2[2], p2[3]}
                sim.addDrawingObjectItem(_S.path.tickCont[3], l)
            end
        end
    end
end

function _S.path.removeLine(index)
    if _S.path.lineCont and _S.path.lineCont[index] ~= -1 then
        sim.removeDrawingObject(_S.path.lineCont[index])
        _S.path.lineCont[index] = -1
        if index == 2 and _S.path.tickCont[1] ~= -1 then
            for i = 1, 3, 1 do
                sim.removeDrawingObject(_S.path.tickCont[i])
                _S.path.tickCont[i] = -1
            end
        end
    end
end

function _S.path.fixCtrlPtOrder()
    --[[
    breaks things
    local handles,poses={},{}
    local i=0
    while true do
        local h1=sim.getObject('./ctrlPt',{index=i,proxy=_S.path.model,noError=true})
        if h1==-1 then break end
        table.insert(handles,h1)
        i=i+1
        local d=sim.readCustomTableData(h1,'ABC_PATHCTRLPT')
        if next(d) then
            poses[d.index]=sim.getObjectPose(h1,_S.path.model)
        end
    end
    for i,pose in ipairs(poses) do
        local h1=handles[i]
        sim.setObjectPose(h1,pose,_S.path.model)
        local d=sim.readCustomTableData(h1,'ABC_PATHCTRLPT')
        d.index=i
        sim.writeCustomTableData(h1,'ABC_PATHCTRLPT',d)
    end
    --]]
end

function _S.path.getCtrlPts()
    local config = _S.path.readInfo()
    _S.path.fixCtrlPtOrder()
    local d = sim.getObjectsInTree(_S.path.model, sim.sceneobject_dummy, 1)
    local pts = {}
    local map = {}
    for i = 1, #d, 1 do
        local h = d[i]
        local dat = sim.readCustomBufferData(h, _S.path.ctrlPtsTag)
        if dat and #dat > 0 then
            dat = sim.unpackTable(dat)
            dat.handle = h
            sim.writeCustomStringData(h, _S.path.childTag, '') -- old: childTag not used anymore
        end
        if dat then
            pts[#pts + 1] = dat
            map[dat.handle] = true
        end
    end
    table.sort(
        pts, function(a, b)
            return a.index < b.index
        end
    )

    local v = 4
    if (config.bitCoded & 32) ~= 0 then v = 0 end

    local _max = {-999, -999, -999}
    local _min = {999, 999, 999}
    for i = 1, #pts, 1 do
        pts[i].index = i -- indices could be fractions and/or not contiguous
        sim.writeCustomBufferData(pts[i].handle, _S.path.ctrlPtsTag, sim.packTable(pts[i]))
        sim.setObjectInt32Param(pts[i].handle, sim.objintparam_visibility_layer, v)
        local p = sim.getObjectPosition(pts[i].handle, _S.path.model)
        for j = 1, 3, 1 do
            _max[j] = math.max(_max[j], p[j])
            _min[j] = math.min(_min[j], p[j])
        end
    end
    _S.path.ctrlPtsSize =
        math.max(_max[1] - _min[1], math.max(_max[2] - _min[2], _max[3] - _min[3])) / 75
    local handles = {}
    for i = 1, #pts, 1 do
        if not config.ctrlPtFixedSize then
            sim.setObjectFloatParam(pts[i].handle, sim.dummyfloatparam_size, _S.path.ctrlPtsSize)
        end
        handles[i] = pts[i].handle
    end
    _S.path.ctrlPts = pts
    _S.path.ctrlPtsMap = map
    _S.path.ctrlPtsPoseId = _S.path.getCtrlPtsPoseId()
    return handles
end

function _S.path.closeToReopenUserConfigDlg()
    _S.path.reopenUserConfDlg = _S.path.closeUserConfigDlg()
end

function _S.path.closeUserConfigDlg()
    if _S.path.ui then
        local x, y = simUI.getPosition(_S.path.ui)
        _S.path.pathDlgPos = {x, y}
        simUI.destroy(_S.path.ui)
        _S.path.ui = nil
        return true
    end
end

function _S.path.setDlgItemContent()
    if _S.path.ui then
        local config = _S.path.readInfo()
        local sel = simUI.getCurrentEditWidget(_S.path.ui)
        simUI.setCheckboxValue(_S.path.ui, 1, ((config.bitCoded & 2) == 0 and 0 or 2))
        simUI.setCheckboxValue(_S.path.ui, 2, ((config.bitCoded & 1) == 0 and 0 or 2))
        simUI.setCheckboxValue(_S.path.ui, 3, ((config.bitCoded & 4) == 0 and 0 or 2))
        simUI.setCheckboxValue(_S.path.ui, 14, ((config.bitCoded & 8) == 0 and 0 or 2))
        simUI.setCheckboxValue(_S.path.ui, 16, ((config.bitCoded & 32) == 0 and 0 or 2))
        simUI.setCheckboxValue(_S.path.ui, 17, ((config.bitCoded & 64) == 0 and 0 or 2))
        simUI.setEditValue(_S.path.ui, 4, string.format("%.2f", config.smoothing), true)
        simUI.setEditValue(_S.path.ui, 5, tostring(config.pointCnt), true)

        simUI.setCheckboxValue(_S.path.ui, 6, ((config.bitCoded & 16) == 0 and 0 or 2))
        simUI.setEnabled(_S.path.ui, 15, (config.bitCoded & 16) ~= 0)
        simUI.setRadiobuttonValue(_S.path.ui, 7, (config.autoOrientation == 0 and 1 or 0))
        simUI.setRadiobuttonValue(_S.path.ui, 8, (config.autoOrientation == 1 and 1 or 0))
        simUI.setRadiobuttonValue(_S.path.ui, 9, (config.autoOrientation == 2 and 1 or 0))
        simUI.setRadiobuttonValue(_S.path.ui, 10, (config.autoOrientation == 3 and 1 or 0))
        simUI.setRadiobuttonValue(_S.path.ui, 11, (config.autoOrientation == 4 and 1 or 0))
        simUI.setRadiobuttonValue(_S.path.ui, 12, (config.autoOrientation == 5 and 1 or 0))
        simUI.setEditValue(
            _S.path.ui, 13, string.format(
                "%.2f, %.2f, %.2f", config.upVector[1], config.upVector[2], config.upVector[3]
            ), true
        )
        simUI.setCurrentEditWidget(_S.path.ui, sel)
    end
end

function _S.path.getDefaultInfoForNonExistingFields(info)
    if not info.bitCoded then
        info.bitCoded = 1 -- 1=show line during simulation, 2=closed, 4=generate shape, 8=show orientation frames, 16=auto orientation, 32 always hide path & ctrl pts, 64 show ctrl pt dialog
    end
    if not info.autoOrientation then
        info.autoOrientation = 0 -- 0=x along path, y up, 1=x along path, z up, 2=y along path, x up, etc.
    end
    if not info.pointCnt then info.pointCnt = 200 end
    if not info.ctrlPtFixedSize then info.ctrlPtFixedSize = false end
    if not info.smoothing then info.smoothing = 1 end
    if not info.line then info.line = {} end
    if not info.line.color then info.line.color = {0, 0.96, 0.66} end
    if not info.line.thickness then info.line.thickness = 3 end
    if not info.upVector then info.upVector = {0, 0, 1} end
end

function _S.path.readInfo()
    local data = sim.readCustomBufferData(_S.path.model, _S.path.pathObjectTag)
    if data and #data > 0 then
        data = sim.unpackTable(data)
    else
        data = {}
    end
    _S.path.getDefaultInfoForNonExistingFields(data)
    return data
end

function _S.path.writeInfo(data)
    if data then
        sim.writeCustomBufferData(_S.path.model, _S.path.pathObjectTag, sim.packTable(data))
    else
        sim.writeCustomBufferData(_S.path.model, _S.path.pathObjectTag, '')
    end
end

function _S.path.closed_callback(ui, id, newVal)
    local c = _S.path.readInfo()
    c.bitCoded = (c.bitCoded | 2)
    if newVal == 0 then c.bitCoded = c.bitCoded - 2 end
    _S.path.writeInfo(c)
    _S.path.setup()
    sim.announceSceneContentChange()
end

function _S.path.generateShape_callback(ui, id, newVal)
    local c = _S.path.readInfo()
    c.bitCoded = (c.bitCoded | 4)
    if newVal == 0 then c.bitCoded = c.bitCoded - 4 end
    _S.path.writeInfo(c)
    _S.path.setup()
    sim.announceSceneContentChange()
end

function _S.path.hideDuringSimulation_callback(ui, id, newVal)
    local c = _S.path.readInfo()
    c.bitCoded = (c.bitCoded | 1)
    if newVal == 0 then c.bitCoded = c.bitCoded - 1 end
    _S.path.writeInfo(c)
    sim.announceSceneContentChange()
end

function _S.path.alwaysHide_callback(ui, id, newVal)
    local c = _S.path.readInfo()
    c.bitCoded = (c.bitCoded | 32)
    if newVal == 0 then c.bitCoded = c.bitCoded - 32 end
    _S.path.writeInfo(c)
    _S.path.setup()
    sim.announceSceneContentChange()
end

function _S.path.showOrientation_callback(ui, id, newVal)
    local c = _S.path.readInfo()
    c.bitCoded = (c.bitCoded | 8)
    if newVal == 0 then c.bitCoded = c.bitCoded - 8 end
    _S.path.writeInfo(c)
    _S.path.setup()
    sim.announceSceneContentChange()
end

function _S.path.noCtrlPtDlg_callback(ui, id, newVal)
    local c = _S.path.readInfo()
    c.bitCoded = (c.bitCoded | 64)
    if newVal == 0 then c.bitCoded = c.bitCoded - 64 end
    _S.path.writeInfo(c)
    _S.path.hideCtrlPtDlg()
    sim.announceSceneContentChange()
end

function _S.path.smoothness_callback(ui, id, newVal)
    local c = _S.path.readInfo()
    local l = tonumber(newVal)
    if l then
        if l < 0.05 then l = 0 end
        if l > 1 then l = 1 end
        if l ~= c.smoothing then
            c.smoothing = l
            _S.path.writeInfo(c)
            _S.path.setup()
            sim.announceSceneContentChange()
        end
    end
    _S.path.setDlgItemContent()
end

function _S.path.pointCnt_callback(ui, id, newVal)
    local c = _S.path.readInfo()
    local l = tonumber(newVal)
    if l then
        if l < 10 then l = 10 end
        if l > 1000 then l = 1000 end
        if l ~= c.pointCnt then
            c.pointCnt = l
            _S.path.writeInfo(c)
            _S.path.setup()
            sim.announceSceneContentChange()
        end
    end
    _S.path.setDlgItemContent()
end

function _S.path.upVector_callback(ui, id, newVal)
    local c = _S.path.readInfo()
    local i = 1
    local t = {0, 0, 0}
    for token in (newVal .. ","):gmatch("([^,]*),") do
        t[i] = tonumber(token)
        if t[i] == nil then t[i] = 0 end
        i = i + 1
    end
    if t[1] ~= 0 or t[2] ~= 0 or t[3] ~= 0 then
        t = Vector(t):normalized():data()
        c.upVector = t
        _S.path.writeInfo(c)
        _S.path.setup()
        sim.announceSceneContentChange()
    end
    _S.path.setDlgItemContent()
end

function _S.path.autoOrient_callback(ui, id, newVal)
    local c = _S.path.readInfo()
    c.bitCoded = (c.bitCoded | 16)
    if newVal == 0 then c.bitCoded = c.bitCoded - 16 end
    _S.path.writeInfo(c)
    _S.path.setDlgItemContent()
    _S.path.setup()
    sim.announceSceneContentChange()
end

function _S.path.align_callback(ui, id, newVal)
    local c = _S.path.readInfo()
    local zvect = Vector3(c.upVector)
    c.autoOrientation = id - 7
    _S.path.writeInfo(c)
    _S.path.setDlgItemContent()
    _S.path.setup()
    sim.announceSceneContentChange()
end

function _S.path.output_callback(ui, id, newVal)
    local c = _S.path.readInfo()
    local ctrlPts = Matrix(#_S.path.paths[1] // 7, 7, _S.path.paths[1])
    local pts = Matrix(#_S.path.paths[2] // 7, 7, _S.path.paths[2])
    if (c.bitCoded & 2) ~= 0 then -- path is closed. First and last pts are duplicate
        ctrlPts = ctrlPts:droprow(ctrlPts:rows())
        pts = pts:droprow(pts:rows())
    end
    local pathM = Matrix4x4:frompose(sim.getObjectPose(_S.path.model))
    local relPts = 'relCtrlPts={'
    local absPts = 'absCtrlPts={'
    local pos = ctrlPts:slice(1, 1, ctrlPts:rows(), 3):data()
    local quat = ctrlPts:slice(1, 4, ctrlPts:rows(), 7):data()
    for i = 1, ctrlPts:rows(), 1 do
        local relData = ctrlPts[i]:data()
        local tr = Matrix4x4:frompose(ctrlPts[i])
        local absData = Matrix4x4:topose(pathM * tr)
        for j = 1, 7, 1 do
            relPts = relPts .. string.format("%.4e", relData[j])
            absPts = absPts .. string.format("%.4e", absData[j])
            if (j ~= 7) or (i ~= ctrlPts:rows()) then
                relPts = relPts .. ','
                absPts = absPts .. ','
            end
        end
    end
    relPts = relPts .. '}'
    absPts = absPts .. '}'
    sim.addLog(sim.verbosity_scriptinfos, relPts)
    sim.addLog(sim.verbosity_scriptinfos, absPts)
    local relPts = 'relPts={'
    local absPts = 'absPts={'
    local pos = pts:slice(1, 1, pts:rows(), 3):data()
    local quat = pts:slice(1, 4, pts:rows(), 7):data()
    for i = 1, pts:rows(), 1 do
        local relData = pts[i]:data()
        local tr = Matrix4x4:frompose(pts[i])
        local absData = Matrix4x4:topose(pathM * tr)
        for j = 1, 7, 1 do
            relPts = relPts .. string.format("%.4e", relData[j])
            absPts = absPts .. string.format("%.4e", absData[j])
            if (j ~= 7) or (i ~= pts:rows()) then
                relPts = relPts .. ','
                absPts = absPts .. ','
            end
        end
    end
    relPts = relPts .. '}'
    absPts = absPts .. '}'
    sim.addLog(sim.verbosity_scriptinfos, relPts)
    sim.addLog(sim.verbosity_scriptinfos, absPts)
end

function _S.path.generate_callback(ui, id, newVal)
    local txt = simUI.getEditValue(ui, 20)
    local v = {}
    local i = 1
    local err = false
    for token in (txt .. ","):gmatch("([^,]*),") do
        v[i] = tonumber(token)
        if v[i] == nil then
            err = true
            break
        end
        i = i + 1
    end
    if not err then
        local c = _S.path.readInfo()
        if id == 21 then
            if #v >= 6 and 3 * #v // 3 == #v then
                _S.path.createNew(
                    v, true, c.bitCoded, c.pointCnt, c.smoothing, c.autoOrientation, c.upVector
                )
                _S.path.setup()
            else
                sim.addLog(sim.verbosity_scriptwarnings, 'Provided value count is invalid')
            end
        else
            if #v >= 14 and 7 * #v // 7 == #v then
                _S.path.createNew(
                    v, false, c.bitCoded, c.pointCnt, c.smoothing, c.autoOrientation, c.upVector
                )
                _S.path.setup()
            else
                sim.addLog(sim.verbosity_scriptwarnings, 'Provided value count is invalid')
            end
        end
    else
        sim.addLog(sim.verbosity_scriptwarnings, 'Provided data is invalid')
    end
end

function _S.path.recomputeOrientations(path)
    local c = _S.path.readInfo()

    function getPreviousPt(mpath, index)
        local retVal, nIndex
        if index ~= 1 then
            nIndex = index - 1
            retVal = Vector3(mpath[nIndex])
        else
            if (c.bitCoded & 2) ~= 0 then
                nIndex = mpath:rows() - 1
                retVal = Vector3(mpath[nIndex])
            end
        end
        return retVal, nIndex
    end

    function getNextPt(mpath, index)
        local retVal, nIndex
        if index ~= mpath:rows() then
            nIndex = index + 1
            retVal = Vector3(mpath[nIndex])
        else
            if (c.bitCoded & 2) ~= 0 then
                nIndex = 2
                retVal = Vector3(mpath[nIndex])
            end
        end
        return retVal, nIndex
    end

    if (c.bitCoded & 16) ~= 0 then
        local zvect = Vector3(c.upVector)
        local mppath = Matrix(#path // 7, 7, path)
        mppath = mppath:slice(1, 1, mppath:rows(), 3)
        local retPath = Matrix(mppath:rows(), 7)
        local prevPose
        for i = 1, mppath:rows(), 1 do
            local p1 = Vector3(mppath[i])
            local p0, ni0 = getPreviousPt(mppath, i)
            if p0 and (p1 - p0):norm() < 0.0001 then
                -- Prev pt is coincident
                if prevPose then
                    p1 = nil -- means: use prevPose
                else
                    -- this is the first pt of a closed path
                    while (p1 - p0):norm() < 0.0001 do
                        p0, ni0 = getPreviousPt(mppath, ni0)
                    end
                end
            end
            if p1 then
                local p2, ni2 = getNextPt(mppath, i)
                while p2 and (p1 - p2):norm() < 0.0001 do
                    -- Next pt is coincident
                    p2, ni2 = getNextPt(mppath, ni2)
                end

                local vf
                if p0 and p2 then
                    vf = (p1 - p0) + (p2 - p1)
                else
                    -- open path
                    if i == 1 then
                        -- first pt
                        vf = (p2 - p1)
                    else
                        -- last pt
                        vf = (p1 - p0)
                    end
                end
                vf = vf / vf:norm()
                local vr = vf:cross(zvect)
                vr = vr / vr:norm()

                local m
                if c.autoOrientation == 0 then
                    m = vf
                    m = m:horzcat(vr:cross(vf))
                    m = m:horzcat(vr)
                end
                if c.autoOrientation == 1 then
                    m = vf
                    m = m:horzcat(vr * -1)
                    m = m:horzcat(vf:cross(vr * -1))
                end
                if c.autoOrientation == 2 then
                    m = vr:cross(vf)
                    m = m:horzcat(vf)
                    m = m:horzcat(vr * -1)
                end
                if c.autoOrientation == 3 then
                    m = vr
                    m = m:horzcat(vf)
                    m = m:horzcat(vr:cross(vf))
                end
                if c.autoOrientation == 4 then
                    m = vr:cross(vf)
                    m = m:horzcat(vr)
                    m = m:horzcat(vf)
                end
                if c.autoOrientation == 5 then
                    m = vr * -1
                    m = m:horzcat(vr:cross(vf))
                    m = m:horzcat(vf)
                end
                m = Matrix4x4:fromrotation(m)
                m[1][4] = p1[1]
                m[2][4] = p1[2]
                m[3][4] = p1[3]
                prevPose = Matrix4x4:topose(m)
            end
            retPath[i] = prevPose
        end
        path = retPath:data()
    end
    return path
end

function _S.path.showCtrlPtDlg(selectedCtrlPtHandles)
    if not _S.path.ctrlPtUi then
        simUI = require 'simUI'
        local pos = 'position="-50,-50"'
        if _S.path.ctrlPtDlgPos then
            pos = 'position="' .. _S.path.ctrlPtDlgPos[1] .. ',' .. _S.path.ctrlPtDlgPos[2] .. '"'
        end
        local xml =
            '<ui title="Control point properties" activate="false" closeable="true" on-close="_S.path.ctrlPtClose_callback" placement="relative" layout="form" ' ..
                pos .. [[>
                <label text="virtual distance"/>
                <edit value="xx" id="11" on-editing-finished="_S.path.ctrlPtVdist_callback"/>

                <label text="aux. channel 1"/>
                <edit value="xx" id="1" on-editing-finished="_S.path.ctrlPtChannel_callback"/>
                <label text="aux. channel 2"/>
                <edit value="xx" id="2" on-editing-finished="_S.path.ctrlPtChannel_callback"/>
                <label text="aux. channel 3"/>
                <edit value="xx" id="3" on-editing-finished="_S.path.ctrlPtChannel_callback"/>
                <label text="aux. channel 4"/>
                <edit value="xx" id="4" on-editing-finished="_S.path.ctrlPtChannel_callback"/>
        </ui>]]
        _S.path.ctrlPtUi = simUI.create(xml)
    end
    if _S.path.selectedCtrlPtHandles == nil or sim.packInt32Table(_S.path.selectedCtrlPtHandles) ~=
        sim.packInt32Table(selectedCtrlPtHandles) then
        _S.path.selectedCtrlPtHandles = selectedCtrlPtHandles
        _S.path.updateCtrlPtUi()
    end
end

function _S.path.updateCtrlPtUi()
    local vals
    for i = 1, #_S.path.selectedCtrlPtHandles, 1 do
        local h = _S.path.selectedCtrlPtHandles[i]
        local data = sim.readCustomBufferData(h, _S.path.ctrlPtsTag)
        data = sim.unpackTable(data)
        local v = {0, 0, 0, 0, 0}
        if data.virtualDist then v[1] = data.virtualDist end
        if data.auxChannels then for j = 1, 4, 1 do v[1 + j] = data.auxChannels[j] end end
        if i == 1 then
            vals = v
        else
            for j = 1, 5, 1 do if vals[j] ~= v[j] then vals[j] = '' end end
        end
    end
    for j = 1, 5, 1 do
        local n = tonumber(vals[j])
        if n then vals[j] = string.format("%.4f", n) end
    end

    local sel = simUI.getCurrentEditWidget(_S.path.ctrlPtUi)
    simUI.setEditValue(_S.path.ctrlPtUi, 11, vals[1])
    for i = 1, 4, 1 do simUI.setEditValue(_S.path.ctrlPtUi, i, vals[1 + i]) end
    simUI.setCurrentEditWidget(_S.path.ctrlPtUi, sel)
end

function _S.path.hideCtrlPtDlg()
    if _S.path.ctrlPtUi then
        _S.path.ctrlPtDlgPos = {}
        _S.path.ctrlPtDlgPos[1], _S.path.ctrlPtDlgPos[2] = simUI.getPosition(_S.path.ctrlPtUi)
        simUI.destroy(_S.path.ctrlPtUi)
        _S.path.ctrlPtUi = nil
    end
    _S.path.selectedCtrlPtHandles = nil
end

function _S.path.ctrlPtClose_callback()
    _S.path.hideCtrlPtDlg()
    local c = _S.path.readInfo()
    c.bitCoded = (c.bitCoded | 64) - 64
    _S.path.writeInfo(c)
end

function _S.path.ctrlPtVdist_callback(ui, id, v)
    v = tonumber(v)
    if v then
        for i = 1, #_S.path.selectedCtrlPtHandles, 1 do
            local h = _S.path.selectedCtrlPtHandles[i]
            local data = sim.readCustomBufferData(h, _S.path.ctrlPtsTag)
            data = sim.unpackTable(data)
            data.virtualDist = v
            sim.writeCustomBufferData(h, _S.path.ctrlPtsTag, sim.packTable(data))
        end
        _S.path.setup()
        sim.announceSceneContentChange()
    end
    _S.path.updateCtrlPtUi()
end

function _S.path.ctrlPtChannel_callback(ui, id, v)
    v = tonumber(v)
    if v then
        for i = 1, #_S.path.selectedCtrlPtHandles, 1 do
            local h = _S.path.selectedCtrlPtHandles[i]
            local data = sim.readCustomBufferData(h, _S.path.ctrlPtsTag)
            data = sim.unpackTable(data)
            if not data.auxChannels then data.auxChannels = {0, 0, 0, 0} end
            data.auxChannels[id] = v
            sim.writeCustomBufferData(h, _S.path.ctrlPtsTag, sim.packTable(data))
        end
        _S.path.setup()
        sim.announceSceneContentChange()
    end
    _S.path.updateCtrlPtUi()
end

function _S.path.showInsertCtrlPtDlg()
    if not _S.path.insertCtrlPtUi then
        simUI = require 'simUI'
        local pos = 'position="-50,-50"'
        if _S.path.insertCtrlPtDlgPos then
            pos = 'position="' .. _S.path.insertCtrlPtDlgPos[1] .. ',' ..
                      _S.path.insertCtrlPtDlgPos[2] .. '"'
        end
        local xml =
            '<ui title="Insert control points" activate="false" closeable="false" placement="relative" ' ..
                pos .. [[>
            <button text="insert before" on-click="_S.path.insertExtDummy_callback" id="1"/>
            <button text="insert after" on-click="_S.path.insertExtDummy_callback" id="2"/>
        </ui>]]
        _S.path.insertCtrlPtUi = simUI.create(xml)
    end
end

function _S.path.hideInsertCtrlPtDlg()
    if _S.path.insertCtrlPtUi then
        _S.path.insertCtrlPtDlgPos = {}
        _S.path.insertCtrlPtDlgPos[1], _S.path.insertCtrlPtDlgPos[2] = simUI.getPosition(
                                                                           _S.path.insertCtrlPtUi
                                                                       )
        simUI.destroy(_S.path.insertCtrlPtUi)
        _S.path.insertCtrlPtUi = nil
    end
end

function _S.path.insertExtDummy_callback(ui, id)
    local s = sim.getObjectSel()
    local newCtrlPts = {}
    local dh = s[#s]
    for i = 1, #s - 1, 1 do
        local nd = sim.copyPasteObjects({dh})[1]
        newCtrlPts[#newCtrlPts + 1] = nd
        dh = nd
    end
    if id == 1 then
        table.insert(newCtrlPts, 1, s[#s]) -- we want to insert dummies before
    end
    for i = 1, #s - 1, 1 do sim.setObjectPose(newCtrlPts[i], {0, 0, 0, 0, 0, 0, 1}, s[i]) end
    s[#s] = nil
    sim.removeObjects(s)
end

return _S.path
