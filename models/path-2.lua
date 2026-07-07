local sim = require'sim-2'
local Path = require'Path'
local simEigen = require'simEigen'
local pathModel = {}

function pathModel.sysCall_init()
    pathModel.modelRoot = sim.self:getObject('.')
    pathModel.pathObjectTempId = sim.app.randomString
    pathModel.start()
end

function pathModel.start()    
    local opt = {}
    opt.ctrlPoints = {}
    opt.ctrlPoints.pointType = 'none'
    opt.ctrlPoints.lineType = 'line'
    opt.ctrlPoints.lineColor = Color'#00ffa0'
    opt.ctrlPoints.showAxes = false
    opt.ctrlPoints.duplicateThreshold = 0.01
    opt.ctrlPoints.linearityTolerance = 0.01
    opt.pathPoints = {}
    opt.pathPoints.pointType = 'none'
    opt.pathPoints.lineType = 'line'
    opt.pathPoints.lineColor = Color'#00dd00'
    opt.pathPoints.showAxes = false
    opt.pathPoints.type = 'quadraticBezier'
    opt.pathPoints.bezierSmoothing = 1.0
    opt.pathPoints.samplingDistance = 0.02
    opt.closed = false
    opt.extrusion = {}
    opt.extrusion.section = nil
    opt.extrusion.color = Color'#ffffff'
    opt.extrusion.selectable = false
    opt.extrusion.upVector = nil
    opt.dummy = {}
    opt.dummy.size = 0.01
    opt.dummy.color = Color'#00ccff'
    opt.dummy.visible = true

    pathModel.opt = opt
    if pathModel.modelRoot.customData.pathOpt then
        pathModel.opt = sim.app:unpack(pathModel.modelRoot.customData.pathOpt)
    else
        pathModel.modelRoot.customData.pathOpt = sim.app:pack(pathModel.opt)
    end
    pathModel.path = nil
    pathModel.ctrlDummyList = {}
    pathModel.ctrlDummyMap = {}
    
    -- Remove children, except for control point dummies:
    local obj = pathModel.modelRoot:getDescendants({depth = 1})
    for i = 1, #obj do
        local ob = obj[i]
        if ob.customData.ctrlPtInfo == nil then
            ob:remove()
        end
    end

    -- Fetch control point dummies (in the right order):
    pathModel.ctrlDummyList, pathModel.ctrlDummyMap = pathModel.getCtrlPointDummies()
    pathModel.ctrlPointConfig = pathModel.getCtrlPointConfig()

    -- Fetch control point poses:
    local pts = pathModel.getCtrlPointMatrix(pathModel.ctrlDummyList)

    -- Create path:
    local l = 0
    if pathModel.opt.dummy.visible then
        l = 4
    end
    for i = 1, #pathModel.ctrlDummyList do
        pathModel.ctrlDummyList[i].size = pathModel.opt.dummy.size
        pathModel.ctrlDummyList[i].color.diffuse = pathModel.opt.dummy.color
        pathModel.ctrlDummyList[i].layer = l
    end
    
    local dat = pathModel.modelRoot.customData.pathInfo
    if dat == nil then
        local dat2 = pathModel.modelRoot.customData.pathCreationInfo
        if dat2 then
            pathModel.modelRoot:removeProperty('customData.pathCreationInfo')
            dat2 = sim.app:unpack(dat2)
            pathModel.opt = dat2
        end
        if pathModel.opt.orientationMetric then
            pathModel.opt.metric = {1.0, 1.0, 1.0, pathModel.opt.orientationMetric, pathModel.opt.orientationMetric, pathModel.opt.orientationMetric, pathModel.opt.orientationMetric}
            pathModel.opt.orientationMetric = nil
        end
        pathModel.path = Path(pts, pathModel.opt)
        pathModel.modelRoot.customData.pathInfo = pathModel.path:toBuffer()
    else
        pathModel.path = Path.fromBuffer(dat)
    end
    pathModel.createExtrusionShape()
    
    -- Create and handle markers:
    markers = pathModel.path:createMarkers()
    for k, v in pairs(markers.ctrlPointMarkers) do
        v.parent = pathModel.modelRoot
    end
    for k, v in pairs(markers.pathPointMarkers) do
        v.parent = pathModel.modelRoot
    end
end

function pathModel.sysCall_cleanup()
    pathModel.path:removeMarkers()
    pathModel.removeExtrusionShape()
end

function pathModel.getCtrlPointDummies()
    -- Returns ordered control point dummies. Sequentially enumerate them again
    local obj = pathModel.modelRoot:getDescendants({type = 'dummy', depth = 1})
    local pts = {}
    for i = 1, #obj do
        local ob = obj[i]
        if ob.customData.ctrlPtInfo then
            local dat = sim.app:unpack(ob.customData.ctrlPtInfo)
            if dat.index then
                dat.object = ob
                pts[#pts + 1] = dat
            end
        end
    end
    local retVal = {}
    local mapRetVal = {}
    if #pts > 0 then
        table.sort(
            pts, function(a, b)
                return a.index < b.index
            end
        )
        for i = 1, #pts do
            retVal[i] = pts[i].object
            retVal[i].customData.ctrlPtInfo = sim.app:pack({index = i})
            mapRetVal[pts[i].object.handle] = i
        end
    end
    return retVal, mapRetVal
end

function pathModel.getCtrlPointMatrix(dummies)
    local poses = {}
    for i = 1, #dummies do
        poses[i] = dummies[i].pose:data()
    end
    return simEigen.Matrix(poses).T
end

function pathModel.removeExtrusionShape()
    if pathModel.extrusionShape then
        pathModel.extrusionShape:remove()
        pathModel.extrusionShape = nil
    end
end

function pathModel.update(opt)
    pathModel.removeExtrusionShape()
    pathModel.ctrlDummyList, pathModel.ctrlDummyMap = pathModel.getCtrlPointDummies()
    local pts = pathModel.getCtrlPointMatrix(pathModel.ctrlDummyList)
    if opt then
        -- Rebuild all: Path, markers, etc.
        pathModel.path:removeMarkers()
        pathModel.modelRoot.customData.pathOpt = sim.app:pack(opt)
        pathModel.modelRoot:removeProperty('customData.pathInfo')
        pathModel.start()
    else
        -- Do not rebuild Path and markers
        pathModel.path:setPoints(pts)
        pathModel.modelRoot.customData.pathInfo = pathModel.path:toBuffer()
        pathModel.ctrlPointConfig = pathModel.getCtrlPointConfig()
        pathModel.createExtrusionShape()
    end
end

function pathModel.createExtrusionShape()
    if pathModel.opt.extrusion.section then
        local o = {section = pathModel.opt.extrusion.section, upVector = pathModel.opt.extrusion.upVector, axis = pathModel.opt.extrusion.axis}
        pathModel.extrusionShape = pathModel.path:createShape(o)
        pathModel.extrusionShape.parent = pathModel.modelRoot
        pathModel.extrusionShape.applyColor.diffuse = pathModel.opt.extrusion.color
        pathModel.extrusionShape.selectable = pathModel.opt.extrusion.selectable
    end
end

function pathModel.sysCall_beforeCopy(inData)
    for i = 1, #inData.objectList do
        local obj = inData.objectList[i]
        if (obj.parent == pathModel.modelRoot) and (obj.customData.ctrlPtInfo) then
            local dat = sim.app:unpack(obj.customData.ctrlPtInfo)
            dat.pasteTo = pathModel.pathObjectTempId
            obj.customData.ctrlPtInfo = sim.app:pack(dat)
        end
    end
end

function pathModel.sysCall_afterCopy(inData)
    for i = 1, #inData.objectList do
        local obj = inData.objectList[i]
        if (obj.parent == pathModel.modelRoot) and (obj.customData.ctrlPtInfo) then
            local dat = sim.app:unpack(obj.customData.ctrlPtInfo)
            dat.pasteTo = nil
            obj.customData.ctrlPtInfo = sim.app:pack(dat)
        end
    end
end

function pathModel.sysCall_afterCreate(inData)
    local pts = {}
    for i = 1, #inData.objectList do
        local obj = inData.objectList[i]
        if (obj.parent == nil) and (obj.customData.ctrlPtInfo) then
            local dat = sim.app:unpack(obj.customData.ctrlPtInfo)
            if dat.pasteTo == pathModel.pathObjectTempId then
                dat.pasteTo = nil
                pts[#pts + 1] = dat
                dat.object = obj
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
        for i = 1, #pts do
            pts[i].index = highIndex + (pts[i].index / 100000)
            local obj = pts[i].object
            pts[i].object = nil
            obj.customData.ctrlPtInfo = sim.app:pack(pts[i])
            obj:setParent(pathModel.modelRoot)
        end
        pathModel.update()
    end
end

function pathModel.sysCall_afterDelete(inData)
    for i = 1, #inData.objectList do
        local objHandle = inData.objectList[i]
        if pathModel.ctrlDummyMap[objHandle] then
            pathModel.update()
            break
        end
    end
end

function pathModel.sysCall_nonSimulation()
    local r = pathModel.getCtrlPointConfig()
    if pathModel.ctrlPointConfig ~= r then
        pathModel.ctrlPointConfig = r
        pathModel.update()
    end
end

function pathModel.sysCall_beforeSimulation()
    if pathModel.opt.hiddenDuringSim then
        for k, v in pairs(markers.ctrlPointMarkers) do
            v.layer = 0
        end
        for k, v in pairs(markers.pathPointMarkers) do
            v.layer = 0
        end
        for i = 1, #pathModel.ctrlDummyList do
            pathModel.ctrlDummyList[i].layer = 0
        end
    end
end

function pathModel.sysCall_afterSimulation()
    if pathModel.opt.hiddenDuringSim then
        for k, v in pairs(markers.ctrlPointMarkers) do
            v.layer = 32
        end
        for k, v in pairs(markers.pathPointMarkers) do
            v.layer = 32
        end
        for i = 1, #pathModel.ctrlDummyList do
            pathModel.ctrlDummyList[i].layer = 4
        end
    end
end

function pathModel.getCtrlPointConfig()
    local retVal = {}
    for i = 1, #pathModel.ctrlDummyList do
        retVal[i] = pathModel.ctrlDummyList[i].pose
    end
    retVal = sim.app:pack(retVal)
    return retVal
end

sim.self:registerFunctionHook('sysCall_init', pathModel.sysCall_init, true)
sim.self:registerFunctionHook('sysCall_cleanup', pathModel.sysCall_cleanup, true)
sim.self:registerFunctionHook('sysCall_beforeCopy', pathModel.sysCall_beforeCopy, true)
sim.self:registerFunctionHook('sysCall_afterCopy', pathModel.sysCall_afterCopy, true)
sim.self:registerFunctionHook('sysCall_afterCreate', pathModel.sysCall_afterCreate, true)
sim.self:registerFunctionHook('sysCall_afterDelete', pathModel.sysCall_afterDelete, true)
sim.self:registerFunctionHook('sysCall_nonSimulation', pathModel.sysCall_nonSimulation, true)
sim.self:registerFunctionHook('sysCall_beforeSimulation', pathModel.sysCall_beforeSimulation, true)
sim.self:registerFunctionHook('sysCall_afterSimulation', pathModel.sysCall_afterSimulation, true)

return pathModel





