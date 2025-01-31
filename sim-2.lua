local sim = {}

-- API functions with a properties counterpart:
sim.setObjectInt32Param = {}
sim.changeEntityColor = {}
sim.getObjectHierarchyOrder = {}
sim.setObjectHierarchyOrder = {}
sim.getExplicitHandling = {}
sim.getRealTimeSimulation = {}
sim.getIsRealTimeSimulation = {}
sim.getJointDependency = {}
sim.getJointForce = {}
sim.getJointInterval = {}
sim.getJointMode = {}
sim.getJointPosition = {}
sim.getJointTargetForce = {}
sim.getJointTargetPosition = {}
sim.getJointTargetVelocity = {}
sim.getJointType = {}
sim.getJointVelocity = {}
sim.getLightParameters = {}
sim.getLinkDummy = {}
sim.getObjectAlias = {}
sim.getObjectChildPose = {}
sim.getObjectColor = {}
sim.getObjectParent = {}
sim.getObjectSel = {}
sim.getObjectSizeFactor = {}
sim.getObjectType = {}
sim.getObjectUid = {}
sim.getObjectVelocity = {}
sim.getPointCloudOptions = {}
sim.getOctreeVoxels = {}
sim.getPointCloudPoints = {}
sim.getShapeColor = {}
sim.getShapeGeomInfo = {}
sim.getShapeInertia = {}
sim.getShapeMass = {}
sim.getShapeMesh = {}
sim.getShapeTextureId = {}
sim.getShapeViz = {}
sim.getSignalName = {}
sim.getSimulationState = {}
sim.getSimulationTime = {}
sim.getSimulationTimeStep = {}
--sim.getSystemTime --doesn't have, but could be added
sim.getSimulationStopping = {}
sim.getVelocity = {}
sim.getVisionSensorDepth = {}
sim.getVisionSensorImg = {}
sim.getVisionSensorRes = {}
sim.isDynamicallyEnabled = {}
sim.readForceSensor = {}
sim.readProximitySensor = {}
sim.setExplicitHandling = {}
sim.setGraphStreamTransformation = {}
sim.setGraphStreamValue = {}
sim.setInt32Param = {}
sim.setInt32Signal = {}
sim.setJointDependency = {}
sim.setJointInterval = {}
sim.setJointMode = {}
sim.setJointPosition = {}
sim.setJointTargetForce = {}
sim.setJointTargetPosition = {}
sim.setJointTargetVelocity = {}
sim.setLinkDummy = {}
sim.setObjectAlias = {}
sim.setObjectChildPose = {}
sim.setObjectColor = {}
sim.setObjectParent = {}
sim.setObjectSel = {}
sim.setPointCloudOptions = {}
sim.setShapeColor = {}
sim.setShapeInertia = {}
sim.setShapeMass = {}
sim.setShapeMaterial = {}
sim.setShapeTexture = {}
sim.setVisionSensorImg = {}
sim.writeTexture = {}
-- from this point on, found in toDeprecateSoon:
sim.clearFloatSignal = {}
sim.clearInt32Signal = {}
sim.clearStringSignal = {}
sim.clearBufferSignal = {}
sim.getArrayParam = {}
sim.getBoolParam = {}
sim.getEngineBoolParam = {}
sim.getEngineFloatParam = {}
sim.getEngineInt32Param = {}
sim.getFloatParam = {}
sim.getFloatSignal = {}
sim.getInt32Param = {}
sim.getInt32Signal = {}
sim.getNamedBoolParam = {}
sim.getNamedFloatParam = {}
sim.getNamedInt32Param = {}
sim.getNamedStringParam = {}
sim.getObjectFloatArrayParam = {}
sim.getObjectFloatParam = {}
sim.getObjectInt32Param = {}
sim.getObjectStringParam = {}
sim.getSettingBool = {}
sim.getSettingFloat = {}
sim.getSettingInt32 = {}
sim.getSettingString = {}
sim.getStringParam = {}
sim.getStringSignal = {}
sim.getBufferSignal = {}
sim.readCustomStringData = {}
sim.readCustomBufferData = {}
sim.readCustomTableData = {}
sim.readCustomDataTags = {}
sim.setArrayParam = {}
sim.setBoolParam = {}
sim.setEngineBoolParam = {}
sim.setEngineFloatParam = {}
sim.setEngineInt32Param = {}
sim.setFloatParam = {}
sim.setFloatSignal = {}
sim.setLightParameters = {}
sim.setNamedBoolParam = {}
sim.setNamedFloatParam = {}
sim.setNamedInt32Param = {}
sim.setNamedStringParam = {}
sim.setObjectFloatArrayParam = {}
sim.setObjectFloatParam = {}
sim.setObjectInt32Param = {}
sim.setObjectStringParam = {}
sim.setStringParam = {}
sim.setStringSignal = {}
sim.setBufferSignal = {}
sim.waitForSignal = {}
sim.writeCustomStringData = {}
sim.writeCustomBufferData = {}
sim.writeCustomTableData = {}
sim.setObjectProperty = {}
sim.setObjectSpecialProperty = {}
sim.getObjectProperty = {}
sim.getObjectSpecialProperty = {}
sim.getModelProperty = {}
sim.setModelProperty = {}

local fn_properties, sim = sim, {}

-- API functions that will be methods of sim.Object:
-- (some will need to be present only for certain object types?)
sim.addForce = {}
sim.addItemToCollection = {}
sim.addReferencedHandle = {}
sim.alignShapeBB = {}
sim.checkCollision = {}
sim.checkCollisionEx = {}
sim.checkCollisionEx = {}
sim.checkOctreePointOccupancy = {}
sim.checkProximitySensor = {}
sim.checkProximitySensorEx = {}
sim.checkProximitySensorEx2 = {}
sim.checkVisionSensor = {}
sim.checkVisionSensorEx = {}
sim.computeMassAndInertia = {}
sim.executeScriptString = {}
sim.getApiFunc = {}
sim.getApiInfo = {}
sim.getExtensionString = {}
sim.getObject = {}
sim.getObjectMatrix = {}
sim.getObjectOrientation = {}
sim.getObjectPose = {}
sim.getObjectPosition = {}
sim.getObjectQuaternion = {}
sim.getObjectsInTree = {}
sim.getReferencedHandles = {}
sim.getReferencedHandle = {}
sim.getReferencedHandlesTags = {}
sim.getScriptFunctions = {}
sim.getStackTraceback = {}
sim.initScript = {}
sim.insertObjectIntoOctree = {}
sim.insertObjectIntoPointCloud = {}
sim.insertPointsIntoPointCloud = {}
sim.insertVoxelsIntoOctree = {}
sim.intersectPointsWithPointCloud = {}
sim.loadScene = {}
sim.readVisionSensor = {}
sim.relocateShapeFrame = {}
sim.removeModel = {}
sim.removePointsFromPointCloud = {}
sim.removeReferencedObjects = {}
sim.removeVoxelsFromOctree = {}
sim.resetDynamicObject = {}
sim.resetGraph = {}
sim.resetProximitySensor = {}
sim.resetVisionSensor = {}
sim.saveModel = {}
sim.saveScene = {}
sim.scaleObject = {}
sim.setObjectMatrix = {}
sim.setObjectOrientation = {}
sim.setObjectPose = {}
sim.setObjectPosition = {}
sim.setObjectQuaternion = {}
sim.setReferencedHandles = {}
sim.setShapeBB = {}
sim.subtractObjectFromOctree = {}
sim.subtractObjectFromPointCloud = {}
sim.ungroupShape = {}
sim.visitTree = {}
sim.getShapeAppearance = {}
sim.setShapeAppearance = {}
sim.setBoolProperty = {}
sim.getBoolProperty = {}
sim.setIntProperty = {}
sim.getIntProperty = {}
sim.setLongProperty = {}
sim.getLongProperty = {}
sim.setFloatProperty = {}
sim.getFloatProperty = {}
sim.setStringProperty = {}
sim.getStringProperty = {}
sim.setBufferProperty = {}
sim.getBufferProperty = {}
sim.setTableProperty = {}
sim.getTableProperty = {}
sim.setIntArray2Property = {}
sim.getIntArray2Property = {}
sim.setVector2Property = {}
sim.getVector2Property = {}
sim.setVector3Property = {}
sim.getVector3Property = {}
sim.setQuaternionProperty = {}
sim.getQuaternionProperty = {}
sim.setPoseProperty = {}
sim.getPoseProperty = {}
sim.setColorProperty = {}
sim.getColorProperty = {}
sim.setFloatArrayProperty = {}
sim.getFloatArrayProperty = {}
sim.setIntArrayProperty = {}
sim.getIntArrayProperty = {}
sim.removeProperty = {}
sim.getPropertyName = {}
sim.getPropertyInfo = {}
sim.setEventFilters = {}
sim.getProperty = {}
sim.setProperty = {}
sim.getPropertyTypeString = {}
sim.getProperties = {}
sim.setProperties = {}
sim.getPropertiesInfos = {}

local fn_obj_methods, sim = sim, {}

-- API functions that could be wrapped to accept and return sim.Object instances:
sim.copyPasteObjects = {}
sim.groupShapes = {}
sim.importShape = {}
sim.loadModel = {}
sim.removeObjects = {}
sim.scaleObjects = {}

local fn_to_wrap, sim = sim, {}

-- [re]move above functions:
local sim = require 'sim'
_S.removedApis = {sim = {}}
for n, opts in ipairs(
    table.add(
        table.keys(fn_properties),
        table.keys(fn_obj_methods),
        table.keys(fn_properties)
    )
) do
    _S.removedApis.sim[n] = sim[n]
    sim[n] = nil
end

return sim
