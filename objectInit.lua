local sim = require 'sim-2'
local checkargs = require('checkargs-2')

local objInit = {}

function objInit.extractValueOrDefault(key, default, map)
    map = map or objInit.p
    local v = default
    if map[key] ~= nil then
        v = map[key]
        map[key] = nil
    end
    return v
end

local function v(intValue, booleanValue)
    if booleanValue then return intValue else return 0 end
end

function objInit.init(methodName, initialProperties)
    local retVal = nil
    local saved = objInit.p
    objInit.p = table.clone(initialProperties or {})
    checkargs.checkfields({funcName = methodName}, {
        {name = 'objectType', type = 'string'},
    }, objInit.p)
    local objectType = objInit.extractValueOrDefault('objectType')
    if objectType then
        if objInit[objectType] then
            retVal = objInit[objectType](methodName)
        elseif table.find(sim.app.customClasses, objectType) or table.find(sim.scene.customClasses, objectType) then
            retVal = sim.Object(sim.app:createCustomObject(objectType))
            retVal:setProperties(objInit.p)
            if retVal:getPropertyInfo('init', {noError = true}) == sim.propertytype_method then
                retVal:getMethodProperty('init')(retVal)
            end
        else
            error('unknown type: ' .. objectType)
        end
    end
    objInit.p = saved
    return retVal
end

function objInit.collection(methodName)
    checkargs.checkfields({funcName = methodName}, {
        {name = 'override', type = 'bool', default = false},
    }, objInit.p)
    local opts = 0
    if objInit.extractValueOrDefault('override') then
        opts = 1
    end
    local retVal = sim.Object(sim.createCollectionEx(opts))
    retVal:setProperties(objInit.p)
    return retVal
end

--[[
function objInit.console(methodName)
    checkargs.checkfields({funcName = methodName}, {
        {name = 'title', type = 'string', default = "Console"},
        {name = 'size', type = 'table', item_type = 'int', size = 2, default = {800, 600}},
        {name = 'position', type = 'table', item_type = 'int', size = 2, default = {50, 50}},
        {name = 'fontSize', type = 'int', default = 12},
        {name = 'closeable', type = 'bool', default = true},
        {name = 'hiddenInSimulation', type = 'bool', default = false},
        {name = 'resizable', type = 'bool', default = true},
        {name = 'style', type = 'string', nullable = true},
        {name = 'color', type = 'color', default = Color:rgb(0.0, 0.0, 0.0)},
        {name = 'background', type = 'color', default = Color:rgb(1.0, 1.0, 1.0)},
    }, objInit.p)
    local Console = require'Console'
    local retVal = Console(p)
    -- retVal:setProperties(objInit.p)
    return retVal
end
]]--

function objInit.detachedScript(methodName)
    checkargs.checkfields({funcName = methodName}, {
        {name = 'scriptType', type = 'int', default = sim.scripttype_addon},
        {name = 'code', type = 'string', default = "local sim = require 'sim-2' function sysCall_init() print('Hello from sysCall_init') end"},
        {name = 'lang', type = 'string', default = 'lua'},
    }, objInit.p)
    local tp = objInit.extractValueOrDefault('scriptType')
    local code = objInit.extractValueOrDefault('code')
    local lang = objInit.extractValueOrDefault('lang')
    local retVal = sim.Object(sim.createDetachedScript(tp, code, lang))
    retVal:setProperties(objInit.p)
    return retVal
end

function objInit.drawingObject(methodName)
    checkargs.checkfields({funcName = methodName}, {
        {name = 'itemType', type = 'int', default = sim.drawing_spherepts},
        {name = 'cyclic', type = 'bool', nullable = true},
        {name = 'local', type = 'bool', nullable = true},
        {name = 'paint', type = 'bool', nullable = true},
        {name = 'overlay', type = 'bool', nullable = true},
        {name = 'itemSize', type = 'float', default = 0.005},
        {name = 'duplicateTolerance', type = 'float', default = 0.0},
        {name = 'parentObject', type = 'handle', nullable = true},
        {name = 'itemCnt', type = 'int', default = 0},
        {name = 'color', type = 'color', default = Color:rgb(1.0, 1.0, 0.0)},
    }, objInit.p)
    local itemType = objInit.extractValueOrDefault('itemType')
    if objInit.extractValueOrDefault('cyclic') then
        itemType = itemType | sim.drawing_cyclic
    end
    if objInit.extractValueOrDefault('local') then
        itemType = itemType | sim.drawing_local
    end
    if objInit.extractValueOrDefault('paint') then
        itemType = itemType | sim.drawing_painttag
    end
    if objInit.extractValueOrDefault('overlay') then
        itemType = itemType | sim.drawing_overlay
    end
    local size = objInit.extractValueOrDefault('itemSize')
    local duplicateTol = objInit.extractValueOrDefault('duplicateTolerance')
    local parentObject = objInit.extractValueOrDefault('parentObject', -1)
    if parentObject ~= -1 then
        parentObject = parentObject.handle
    end
    local cnt = objInit.extractValueOrDefault('itemCnt')
    local col = objInit.extractValueOrDefault('color')
    local retVal = sim.Object(sim.createDrawingObject(itemType, size, duplicateTol, parentObject, cnt, col:data()))
    retVal:setProperties(objInit.p)
    return retVal
end

function objInit.marker(methodName)
    local simEigen = require 'simEigen'
    checkargs.checkfields({funcName = methodName}, {
        {name = 'itemType', type = 'int', default = sim.markertype_spheres},
        {name = 'cyclic', type = 'bool', nullable = true},
        {name = 'local', type = 'bool', nullable = true},
        {name = 'overlay', type = 'bool', nullable = true},
        {name = 'itemSize', type = 'vector3', default = simEigen.Vector({0.005, 0.005, 0.005})},
        {name = 'itemColor', type = 'color', default = Color:rgb(1.0, 1.0, 0.0)},
        {name = 'duplicateTolerance', type = 'float', default = 0.0},
        {name = 'itemCnt', type = 'int', default = 0},
    }, objInit.p)
    local itemType = objInit.extractValueOrDefault('itemType')
    local options = 0
    if objInit.extractValueOrDefault('cyclic') then
        options = options | sim.markeropts_cyclic
    end
    if objInit.extractValueOrDefault('local') then
        options = options | sim.markeropts_local
    end
    if objInit.extractValueOrDefault('overlay') then
        options = options | sim.markeropts_overlay
    end
    local size = objInit.extractValueOrDefault('itemSize')
    local col = objInit.extractValueOrDefault('itemColor')
    local duplicateTol = objInit.extractValueOrDefault('duplicateTolerance')
    local cnt = objInit.extractValueOrDefault('itemCnt')
    local vertices, indices, normals
    if itemType == sim.markertype_custom then
        local mesh = objInit.extractValueOrDefault('mesh')
        if type(mesh) ~= 'table' then
            mesh = {}
        end
        if simEigen.Matrix:ismatrix(mesh.vertices) and mesh.vertices:rows() == 3 then
            mesh.vertices = mesh.vertices.T:data()
        end
        if type(mesh.vertices) ~= 'table' or type(mesh.indices) ~= 'table' then
            mesh.vertices = nil
            mesh.indices = nil
            mesh.normals = nil
        else
            if simEigen.Matrix:ismatrix(mesh.normals) and mesh.normals:rows() == 3 then
                mesh.normals = mesh.normals.T:data()
            end
            if type(mesh.normals) ~= 'table' then
                mesh.normals = nil
            end
        end
        vertices = mesh.vertices
        indices = mesh.indices
        normals = mesh.normals
    end
    objInit.p.mesh = nil
    local retVal = sim.Object(sim.createMarker(itemType, col:data(), size:data(), cnt, options, duplicateTol, vertices, indices, normals))
    retVal:setProperties(objInit.p)
    return retVal
end

function objInit.dummy(methodName)
    checkargs.checkfields({funcName = methodName}, {
        {name = 'dummySize', type = 'float', default = 0.01},
    }, objInit.p)
    local retVal = sim.Object(sim.createDummy(objInit.extractValueOrDefault('dummySize')))
    retVal:setProperties(objInit.p)
    return retVal
end

function objInit.forceSensor(methodName)
    checkargs.checkfields({funcName = methodName}, {
        {name = 'filterType', type = 'int', default = 0},
        {name = 'filterSampleSize', type = 'int', default = 1},
        {name = 'consecutiveViolationsToTrigger', type = 'int', default = 1},
        {name = 'sensorSize', type = 'float', default = 0.01},
        {name = 'forceThreshold', type = 'float', default = 5.0},
        {name = 'torqueThreshold', type = 'float', default = 5.0},
    }, objInit.p)
    local options = 0
    if objInit.p.forceThreshold then options = options + 1 end
    if objInit.p.torqueThreshold then options = options + 2 end
    local intParams = table.rep(0, 5)
    intParams[1] = objInit.extractValueOrDefault('filterType')
    intParams[2] = objInit.extractValueOrDefault('filterSampleSize')
    intParams[3] = objInit.extractValueOrDefault('consecutiveViolationsToTrigger')
    local floatParams = table.rep(0., 5)
    floatParams[1] = objInit.extractValueOrDefault('sensorSize')
    floatParams[2] = objInit.extractValueOrDefault('forceThreshold')
    floatParams[3] = objInit.extractValueOrDefault('torqueThreshold')
    local retVal = sim.Object(sim.createForceSensor(options, intParams, floatParams))
    retVal:setProperties(objInit.p)
    return retVal
end

function objInit.joint(methodName)
    checkargs.checkfields({funcName = methodName}, {
        {name = 'jointType', type = 'int', default = sim.joint_revolute},
        {name = 'jointMode', type = 'int', default = sim.jointmode_dynamic},
        {name = 'jointLength', type = 'float', default = 0.15},
        {name = 'jointDiameter', type = 'float', default = 0.02},
        {name = 'interval', type = 'table', item_type = 'float', size = 2, nullable = true},
        {name = 'cyclic', type = 'bool', nullable = true},
        {name = 'screwLead', type = 'float', nullable = true},
        {name = 'dynCtrlMode', type = 'int', nullable = true},
    }, objInit.p)
    local jointType = objInit.extractValueOrDefault('jointType')
    local jointMode = objInit.extractValueOrDefault('jointMode')
    local jointSize = {
        objInit.extractValueOrDefault('jointLength'),
        objInit.extractValueOrDefault('jointDiameter'),
    }
    local retVal = sim.Object(sim.createJoint(jointType, jointMode, 0, jointSize))
    local interval = objInit.extractValueOrDefault('interval')
    if interval then
        retVal.interval = interval
    end
    local cyclic = objInit.extractValueOrDefault('cyclic')
    if cyclic ~= nil then
        retVal.cyclic = cyclic
    end
    local screwLead = objInit.extractValueOrDefault('screwLead')
    if screwLead then
        retVal.screwLead = screwLead
    end
    local dynCtrlMode = objInit.extractValueOrDefault('dynCtrlMode')
    if dynCtrlMode then
        retVal.dynCtrlMode = dynCtrlMode
    end
    retVal:setProperties(objInit.p)
    return retVal
end

function objInit.ocTree(methodName)
    checkargs.checkfields({funcName = methodName}, {
        {name = 'voxelSize', type = 'float', default = 0.01},
        {name = 'pointSize', type = 'int', default = 1},
        {name = 'showPoints', type = 'bool', default = false},
    }, objInit.p)
    local voxelSize = objInit.extractValueOrDefault('voxelSize')
    local pointSize = objInit.extractValueOrDefault('pointSize')
    local options = 0
        + v(1, objInit.extractValueOrDefault('showPoints'))
    local retVal = sim.Object(sim.createOctree(voxelSize, options, pointSize))
    retVal:setProperties(objInit.p)
    return retVal
end

function objInit.path(methodName)
    local simEigen = require 'simEigen'
    checkargs.checkfields({funcName = methodName}, {
        {name = 'ctrlPts', type = 'matrix', cols = 7, default = simEigen.Matrix(2, 7, {-0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0})},
        {name = 'hiddenDuringSim', type = 'bool', default = false},
        {name = 'closed', type = 'bool', default = false},
        {name = 'subdiv', type = 'int', default = 100},
        {name = 'smoothness', type = 'float', default = 1.0},
        {name = 'orientationMode', type = 'int', nullable = true},
        {name = 'upVector', type = 'vector3', default = simEigen.Vector({0.0, 0.0, 1.0})},
    }, objInit.p)
    local ctrlPts = objInit.extractValueOrDefault('ctrlPts')
    local options = 0
        + v(1, objInit.extractValueOrDefault('hiddenDuringSim'))
        + v(2, objInit.extractValueOrDefault('closed'))
    local subdiv = objInit.extractValueOrDefault('subdiv')
    local smoothness = objInit.extractValueOrDefault('smoothness')
    local orientationMode = objInit.extractValueOrDefault('orientationMode')
    local upVector = objInit.extractValueOrDefault('upVector')
    if orientationMode then
        options = options | 16
    else
        orientationMode = 0
    end
    --h = sim.Object(sim.createPath(ctrlPts:data(), options, subdiv, smoothness, orientationMode, upVector:data()))
    local fl = setYieldAllowed(false)
    local code = [[function path.shaping(path,pathIsClosed,upVector)
    local section={0.02,-0.02,0.02,0.02,-0.02,0.02,-0.02,-0.02,0.02,-0.02}
    local color={0.7,0.9,0.9}
    local options=0
    if pathIsClosed then
        options=options|4
    end
    local shape=sim.generateShapeFromPath(path,section,options,upVector)
    sim.setShapeColor(shape,nil,sim.colorcomponent_ambient_diffuse,color)
    return shape
end]]
    code = "path = require('models.path_customization-2')\n\n" .. code

    local retVal = objInit.init(methodName, {objectType = 'dummy', dummySize = 0.04, ['color.diffuse'] = {0.0, 0.68, 0.47}})
    retVal.name = 'Path'
    local script = objInit.init(methodName, {objectType = 'script', scriptType = sim.scripttype_customization, code = code})
    script:setParent(retVal)
    retVal.model.propertyFlags = (retVal.model.propertyFlags | sim.modelproperty_not_model) - sim.modelproperty_not_model
    retVal.objectPropertyFlags = retVal.objectPropertyFlags | sim.objectproperty_collapsed
    local data = sim.app:packTable({ctrlPts:data(), options, subdiv, smoothness, orientationMode, upVector})
    retVal:setBufferProperty("customData.ABC_PATH_CREATION", data)
    script.detachedScript:init()
    setYieldAllowed(fl)
    retVal:setProperties(objInit.p)
    return retVal
end

function objInit.script(methodName)
    checkargs.checkfields({funcName = methodName}, {
        {name = 'scriptType', type = 'int', default = sim.scripttype_simulation},
        {name = 'code', type = 'string', default = ''},
        {name = 'language', type = 'string', default = 'lua'},
        {name = 'scriptDisabled', type = 'bool', default = false},
    }, objInit.p)
    local scriptType = objInit.extractValueOrDefault('scriptType')
    local scriptText = objInit.extractValueOrDefault('code')
    local options = 0
        + v(1, objInit.extractValueOrDefault('scriptDisabled'))
    local lang = objInit.extractValueOrDefault('language')
    local retVal = sim.Object(sim.createScript(scriptType, scriptText, options, lang))
    retVal:setProperties(objInit.p)
    return retVal
end

function objInit.pointCloud(methodName)
    checkargs.checkfields({funcName = methodName}, {
        {name = 'cellSize', type = 'float', default = 0.02},
        {name = 'maxPointsInCell', type = 'int', default = 20},
        {name = 'pointSize', type = 'int', default = 2},
    }, objInit.p)
    local maxVoxelSize = objInit.extractValueOrDefault('cellSize')
    local maxPtCntPerVoxel = objInit.extractValueOrDefault('maxPointsInCell')
    local options = 0
    local pointSize = objInit.extractValueOrDefault('pointSize')
    local retVal = sim.Object(sim.createPointCloud(maxVoxelSize, maxPtCntPerVoxel, options, pointSize))
    retVal:setProperties(objInit.p)
    return retVal
end

function objInit.proximitySensor(methodName)
    checkargs.checkfields({funcName = methodName}, {
        {name = 'sensorType', type = 'int', default = sim.proximitysensor_cone},
        {name = 'explicitHandling', type = 'bool', default = false},
        {name = 'showVolume', type = 'bool', default = true},
        {name = 'frontFaceDetection', type = 'bool', default = true},
        {name = 'backFaceDetection', type = 'bool', default = true},
        {name = 'exactMode', type = 'bool', default = true},
        {name = 'randomizedDetection', type = 'bool', default = false},
        {name = 'volume_faces', type = 'table', item_type = 'int', size = 2, default = {32, 1}},
        {name = 'volume_subdivisions', type = 'table', item_type = 'int', size = 2, default = {1, 16}},
        {name = 'volume_offset', type = 'float', default = 0.0},
        {name = 'volume_range', type = 'float', default = 0.2},
        {name = 'volume_angle', type = 'float', default = 90.0 * math.pi / 180.0},
        {name = 'sensorPointSize', type = 'float', default = 0.005},
        {name = 'angleThreshold', type = 'float', nullable = true},
        {name = 'closeThreshold', type = 'float', nullable = true},
        {name = 'volume_xSize', type = 'table', item_type = 'float', size = 2, default = {0.2, 0.4}},
        {name = 'volume_ySize', type = 'table', item_type = 'float', size = 2, default = {0.1, 0.2}},
        {name = 'volume_radius', type = 'table', item_type = 'float', size = 2, default = {0.1, 0.2}},
    }, objInit.p)
    local sensorType = objInit.extractValueOrDefault('sensorType')
    local options = 0
        + v(1, objInit.extractValueOrDefault('explicitHandling'))
        + v(2, false) -- deprecated, set to 0
        + v(4, not objInit.extractValueOrDefault('showVolume'))
        + v(8, not objInit.extractValueOrDefault('frontFaceDetection'))
        + v(16, not objInit.extractValueOrDefault('backFaceDetection'))
        + v(32, not objInit.extractValueOrDefault('exactMode'))
        + v(512, objInit.extractValueOrDefault('randomizedDetection'))
    local intParams = table.rep(0, 8)
    local volume_faces = objInit.extractValueOrDefault('volume_faces')
    intParams[1] = volume_faces[1]
    intParams[2] = volume_faces[2]
    local volume_subdivisions = objInit.extractValueOrDefault('volume_subdivisions')
    intParams[3] = volume_subdivisions[1]
    intParams[4] = volume_subdivisions[2]
    intParams[5] = 1
    intParams[6] = 1
    local floatParams = table.rep(0., 15)
    floatParams[1] = objInit.extractValueOrDefault('volume_offset')
    floatParams[2] = objInit.extractValueOrDefault('volume_range')
    local xSize = objInit.extractValueOrDefault('volume_xSize')
    local ySize = objInit.extractValueOrDefault('volume_ySize')
    floatParams[3] =  xSize[1]
    floatParams[4] =  ySize[1]
    floatParams[5] =  xSize[2]
    floatParams[6] =  ySize[2]
    local radius = objInit.extractValueOrDefault('volume_radius')
    floatParams[8] = radius[1]
    floatParams[9] = radius[2]
    floatParams[10] = objInit.extractValueOrDefault('volume_angle')
    floatParams[11] = objInit.extractValueOrDefault('angleThreshold', nil)
    if floatParams[11] then
        options = options + 64
    else
        floatParams[11] = 0.0
    end
    floatParams[12] = objInit.extractValueOrDefault('closeThreshold', nil)
    if floatParams[12] then
        options = options + 256
    else
        floatParams[12] = 0.0
    end
    floatParams[13] = objInit.extractValueOrDefault('sensorPointSize')
    local retVal = sim.Object(sim.createProximitySensor(sensorType, 16, options, intParams, floatParams))
    retVal:setProperties(objInit.p)
    return retVal
end

function objInit.visionSensor(methodName)
    checkargs.checkfields({funcName = methodName}, {
        {name = 'explicitHandling', type = 'bool', default = false},
        {name = 'showFrustum', type = 'bool', default = false},
        {name = 'useExtImage', type = 'bool', default = false},
        {name = 'resolution', type = 'table', item_type = 'int', size = 2, default = {256, 256}},
        {name = 'clippingPlanes', type = 'table', item_type = 'float', size = 2, default = {0.01, 10.0}},
        {name = 'sensorSize', type = 'float', default = 0.01},
        {name = 'viewAngle', type = 'float', nullable = true},
        {name = 'viewSize', type = 'float', nullable = true},
        {name = 'backgroundColor', type = 'color', nullable = true},
    }, objInit.p)
    local viewAngle = objInit.extractValueOrDefault('viewAngle')
    local viewSize = objInit.extractValueOrDefault('viewSize')
    local perspective = true
    if viewAngle or viewSize == nil then
        if viewAngle == nil then
            viewAngle = 60.0 * math.pi / 180.0
        end
    else
        perspective = false;
    end
    local bgCol = objInit.extractValueOrDefault('backgroundColor')
    local options = 0
        + v(1, objInit.extractValueOrDefault('explicitHandling'))
        + v(2, perspective)
        + v(4, objInit.extractValueOrDefault('showFrustum'))
        -- bit 3 set (8): reserved. Set to 0
        + v(16, objInit.extractValueOrDefault('useExtImage'))
        + v(128, bgCol)
    local intParams = table.rep(0, 4)
    local res = objInit.extractValueOrDefault('resolution')
    intParams[1] = res[1]
    intParams[2] = res[2]
    local clipPlanes = objInit.extractValueOrDefault('clippingPlanes')
    local floatParams = table.rep(0., 11)
    floatParams[1] = clipPlanes[1]
    floatParams[2] = clipPlanes[2]
    if (options & 2) > 0 then
        floatParams[3] = viewAngle
    else
        floatParams[3] = viewSize
    end
    floatParams[4] = objInit.extractValueOrDefault('sensorSize')
    if bgCol then
        bgCol = bgCol:data()
        floatParams[7] = bgCol[1]
        floatParams[8] = bgCol[2]
        floatParams[9] = bgCol[3]
    end
    local retVal = sim.Object(sim.createVisionSensor(options, intParams, floatParams))
    retVal:setProperties(objInit.p)
    return retVal
end

function objInit.camera(methodName)
    local retVal = callMethod(sim.scene, 'createCamera', objInit.p)
    objInit.p.clippingPlanes = nil
    objInit.p.viewAngle = nil
    objInit.p.viewSize = nil
    retVal:setProperties(objInit.p)
    return retVal
end

function objInit.light(methodName)
    local retVal = callMethod(sim.scene, 'createLight', objInit.p)
    objInit.p.lightType = nil
    retVal:setProperties(objInit.p)
    return retVal
end

function objInit.graph(methodName)
    local retVal = callMethod(sim.scene, 'createGraph', objInit.p)
    objInit.p.backgroundColor = nil
    objInit.p.foregroundColor = nil
    retVal:setProperties(objInit.p)
    return retVal
end

function objInit.shape(methodName)
    local simEigen = require 'simEigen'
    local retVal = nil
    checkargs.checkfields({funcName = methodName}, {
        {name = 'mesh', type = 'table', nullable = true},
        {name = 'heightField', type = 'table', nullable = true},
        {name = 'plane', type = 'table', nullable = true},
        {name = 'disc', type = 'table', nullable = true},
        {name = 'cuboid', type = 'table', nullable = true},
        {name = 'spheroid', type = 'table', nullable = true},
        {name = 'cylinder', type = 'table', nullable = true},
        {name = 'cone', type = 'table', nullable = true},
        {name = 'capsule', type = 'table', nullable = true},
        {name = 'text', type = 'table', nullable = true},
        {name = 'shadingAngle', type = 'float', default = 0.0},
        {name = 'culling', type = 'bool', default = false},
        {name = 'dynamic', type = 'bool', default = false},
        {name = 'showEdges', type = 'bool', default = false},
        {name = 'color.diffuse', type = 'color', default = Color:rgb(1.0, 1.0, 1.0)},
        {name = 'color.specular', type = 'color', default = Color:rgb(0.2, 0.2, 0.2)},
        {name = 'color.emission', type = 'color', default = Color:rgb(0.0, 0.0, 0.0)},
    }, objInit.p)
    if objInit.p.mesh then
        checkargs.checkfields({funcName = methodName .. ' (mesh field)'}, {
            {name = 'vertices', type = 'matrix', rows = 3, default = simEigen.Matrix(3, 3, {0.0, 0.0, 0.005, 0.1, 0.0, 0.005, 0.2, 0.1, 0.005}).T},
            {name = 'indices', type = 'table', item_type = 'int', size = '3..*', default = {0, 1, 2}},
            {name = 'boundingBoxQuaternion', type = 'quaternion', nullable = true},
            {name = 'frameOrigin', type = 'pose', nullable = true},
        }, objInit.p.mesh)
        checkargs.checkfields({funcName = methodName .. ' (mesh field)'}, {
            {name = 'normals', type = 'matrix', cols = #objInit.p.mesh.indices, rows = 3, nullable = true},
        }, objInit.p.mesh)
        local texture_interpolate = true
        local texture_decal = false
        local texture_rgba = false
        local texture_horizFlip = false
        local texture_vertFlip = false
        local texture_res = nil
        local texture_coord = nil
        local texture_img = nil
        if type(objInit.p.mesh.texture) == 'table' then
            checkargs.checkfields({funcName = methodName .. ' (mesh.texture field)'}, {
                {name = 'interpolate', type = 'bool', default = true},
                {name = 'decal', type = 'bool', default = false},
                {name = 'rgba', type = 'bool', default = false},
                {name = 'horizFlip', type = 'bool', default = false},
                {name = 'vertFlip', type = 'bool', default = false},
            }, objInit.p.mesh.texture)
            local vals = 3
            if objInit.p.mesh.texture.rgba then
                vals = 4
            end
            checkargs.checkfields({funcName = methodName .. ' (mesh.texture field)'}, {
                {name = 'resolution', type = 'table', item_type = 'int', size = 2},
                {name = 'image', type = 'buffer', size = vals * objInit.p.mesh.texture.resolution[1] * objInit.p.mesh.texture.resolution[2]},
                {name = 'coordinates', type = 'matrix', cols = #objInit.p.mesh.indices, rows = 2, nullable = true},
            }, objInit.p.mesh.texture)

            texture_interpolate = objInit.extractValueOrDefault('interpolate', true, objInit.p.mesh.texture)
            texture_decal = objInit.extractValueOrDefault('decal', false, objInit.p.mesh.texture)
            texture_rgba = objInit.extractValueOrDefault('rgba', false, objInit.p.mesh.texture)
            texture_horizFlip = objInit.extractValueOrDefault('horizFlip', false, objInit.p.mesh.texture)
            texture_vertFlip = objInit.extractValueOrDefault('vertFlip', false, objInit.p.mesh.texture)
            texture_res = objInit.extractValueOrDefault('resolution', nil, objInit.p.mesh.texture)
            texture_coord = objInit.extractValueOrDefault('coordinates', nil, objInit.p.mesh.texture)
            texture_img = objInit.extractValueOrDefault('image', nil, objInit.p.mesh.texture)
        end
        local options = 0
            + v(1, objInit.extractValueOrDefault('culling'))
            + v(2, objInit.extractValueOrDefault('showEdges'))
            + v(4, not texture_interpolate)
            + v(8, texture_decal)
            + v(16, texture_rgba)
            + v(32, texture_horizFlip)
            + v(64, texture_vertFlip)
        local shadingAngle = objInit.extractValueOrDefault('shadingAngle')
        local vertices = objInit.extractValueOrDefault('vertices', nil, objInit.p.mesh)
        local indices = objInit.extractValueOrDefault('indices', nil, objInit.p.mesh)
        local normals = objInit.extractValueOrDefault('normals', nil, objInit.p.mesh)
        if normals then
            normals = normals.T:data()
        end
        retVal = sim.Object(sim.createShape(options, shadingAngle, vertices.T:data(), indices, normals, texture_coord, texture_img, texture_res))
        local bbQuat = objInit.extractValueOrDefault('boundingBoxQuaternion', nil, objInit.p.mesh)
        if bbQuat then
            retVal:alignBoundingBox(bbQuat)
        else
            retVal:alignBoundingBox({0.0, 0.0, 0.0, 0.0}) -- to encompass shape closest
        end
        local frameOrigin = objInit.extractValueOrDefault('frameOrigin', nil, objInit.p.mesh)
        if frameOrigin then
            retVal:relocateFrame(frameOrigin)
        else
            retVal:relocateFrame({0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0}) -- to center of shape's BB
        end
        objInit.p.mesh = nil
    elseif objInit.p.heightField then
        checkargs.checkfields({funcName = methodName .. ' (heightField field)'}, {
            {name = 'heights', type = 'matrix', default = simEigen.Matrix(3, 3, {0.0, 0.05, 0.025, 0.03, 0.06, 0.08, 0.01, 0.01, 0.01})},
            {name = 'cellSize', type = 'float', default = 0.5},
            {name = 'rawMesh', type = 'bool', default = false},
        }, objInit.p.heightField)
        local options = 0
            + v(1, objInit.extractValueOrDefault('culling'))
            + v(2, objInit.extractValueOrDefault('showEdges'))
            + v(4, objInit.extractValueOrDefault('rawMesh', false, objInit.p.heightField))
        local shadingAngle = objInit.extractValueOrDefault('shadingAngle')
        local heights = objInit.extractValueOrDefault('heights', nil, objInit.p.heightField)
        local cellSize = objInit.extractValueOrDefault('cellSize', nil, objInit.p.heightField)
        retVal = sim.Object(sim.createHeightfieldShape(options, shadingAngle, heights:cols(), heights:rows(), cellSize * (heights:cols() - 1), heights:data()))
        objInit.p.heightField = nil
    elseif objInit.p.string then
        checkargs.checkfields({funcName = methodName .. ' (text field)'}, {
            {name = 'text', type = 'string', default = 'Hello'},
            {name = 'height', type = 'float', default = 0.5},
            {name = 'center', type = 'bool', default = true},
        }, objInit.p.string)
        local text = objInit.extractValueOrDefault('text', nil, objInit.p.string)
        local height = objInit.extractValueOrDefault('height', nil, objInit.p.string)
        local center = objInit.extractValueOrDefault('center', nil, objInit.p.string)
        local culling = objInit.extractValueOrDefault('culling')
        objInit.extractValueOrDefault('shadingAngle')
        local textUtils = require('textUtils')
        retVal = sim.Object(textUtils.generateTextShape(text, nil, height, center, nil, nil, true))
        retVal.applyCulling = culling
        objInit.p.string = nil
    else
        local pt, size, open
        local ff
        if objInit.p.plane then
            ff = objInit.p.plane
            objInit.p.plane = nil
            checkargs.checkfields({funcName = methodName .. ' (plane field)'}, {
                {name = 'size', type = 'table', item_type = 'float', size = 2, default = {0.1, 0.1}},
            }, ff)
            pt = sim.primitiveshape_plane
            local s = objInit.extractValueOrDefault('size', nil, ff)
            size = {s[1], s[2], 0.0}
        elseif objInit.p.disc then
            ff = objInit.p.disc
            objInit.p.disc = nil
            checkargs.checkfields({funcName = methodName .. ' (disc field)'}, {
                {name = 'radius', type = 'float', default = 0.1},
            }, ff)
            pt = sim.primitiveshape_disc
            local r = objInit.extractValueOrDefault('radius', nil, ff)
            size = {r * 2.0, r * 2.0, 0.0}
        elseif objInit.p.sphere then
            ff = objInit.p.sphere
            objInit.p.sphere = nil
            checkargs.checkfields({funcName = methodName .. ' (sphere field)'}, {
                {name = 'radius', type = 'float', default = 0.1},
            }, ff)
            pt = sim.primitiveshape_spheroid
            local r = objInit.extractValueOrDefault('radius', nil, ff)
            size = {r * 2.0, r * 2.0, r * 2.0}
        elseif objInit.p.cylinder then
            ff = objInit.p.cylinder
            objInit.p.cylinder = nil
            checkargs.checkfields({funcName = methodName .. ' (cylinder field)'}, {
                {name = 'radius', type = 'float', default = 0.1},
                {name = 'length', type = 'float', default = 0.1},
                {name = 'open', type = 'bool', default = false},
            }, ff)
            pt = sim.primitiveshape_cylinder
            local r = objInit.extractValueOrDefault('radius', nil, ff)
            local l = objInit.extractValueOrDefault('length', nil, ff)
            size = {r * 2.0, r * 2.0, l}
            open = objInit.extractValueOrDefault('open', nil, ff)
        elseif objInit.p.cone then
            ff = objInit.p.cone
            objInit.p.cone = nil
            checkargs.checkfields({funcName = methodName .. ' (cone field)'}, {
                {name = 'radius', type = 'float', default = 0.1},
                {name = 'height', type = 'float', default = 0.1},
                {name = 'open', type = 'bool', default = false},
            }, ff)
            pt = sim.primitiveshape_cone
            local r = objInit.extractValueOrDefault('radius', nil, ff)
            local l = objInit.extractValueOrDefault('height', nil, ff)
            size = {r * 2.0, r * 2.0, l}
            open = objInit.extractValueOrDefault('open', nil, ff)
        elseif objInit.p.capsule then
            ff = objInit.p.capsule
            objInit.p.capsule = nil
            checkargs.checkfields({funcName = methodName .. ' (capsule field)'}, {
                {name = 'radius', type = 'float', default = 0.025},
                {name = 'length', type = 'float', default = 0.1},
            }, ff)
            pt = sim.primitiveshape_capsule
            local r = objInit.extractValueOrDefault('radius', nil, ff)
            local l = objInit.extractValueOrDefault('length', nil, ff)
            size = {r * 2.0, r * 2.0, math.max(l, r * 2.0)}
        else
            if objInit.p.cube == nil then
                objInit.p.cube = {}
            end
            ff = objInit.p.cube
            objInit.p.cube = nil
            checkargs.checkfields({funcName = methodName .. ' (cube field)'}, {
                {name = 'size', type = 'table', item_type = 'float', size = 3, default = {0.1, 0.1, 0.1}},
            }, ff)
            pt = sim.primitiveshape_cuboid
            size = objInit.extractValueOrDefault('size', nil, ff)
        end
        local options = 2
            + v(1, objInit.extractValueOrDefault('culling'))
            + v(4, open)
            + v(8, objInit.extractValueOrDefault('rawMesh', ff))
        retVal = sim.Object(sim.createPrimitiveShape(pt, size, options))
        local shadingAngle = objInit.extractValueOrDefault('shadingAngle')
        sim.setFloatProperty(retVal, 'applyShadingAngle', shadingAngle)
    end
    retVal.dynamic = objInit.extractValueOrDefault('dynamic', false)
    if objInit.extractValueOrDefault('showEdges') then
        retVal:applyShowEdges(true)
    end
    retVal.applyColor.diffuse = objInit.extractValueOrDefault('color.diffuse')
    retVal.applyColor.specular = objInit.extractValueOrDefault('color.specular')
    retVal.applyColor.emission = objInit.extractValueOrDefault('color.emission')
    retVal:setProperties(objInit.p)
    return retVal
end

return objInit
