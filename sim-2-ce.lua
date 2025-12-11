local remove = [[
sim.setObjectParent(handle objectHandle, handle parentObjectHandle, bool keepInPlace = true)
sim.scaleObject(int objectHandle, float xScale, float yScale, float zScale, int options=0)
sim.scaleObjects(int[1..*] objectHandles, float scalingFactor, bool scalePositionsToo)
handle handle = sim.createObject(map properties)
handle drawingObjectHandle = sim.createDrawingObject(int objectType, float size = 1.0, float duplicateTolerance = 0.0, handle parentObjectHandle = -1, int maxItemCount = 1000, float[3] color = {0.0, 0.0, 0.0})
handle collectionHandle = sim.createCollection(int options = 0)
handle handle = sim.createDummy(float size = 0.005)
handle handle = sim.createForceSensor(int options = 0, int[5] intParams = {0, 1, 10, 0, 0}, float[5] floatParams = {0.05, 100.0, 10.0, 0.0, 0.0})
handle handle = sim.createJoint(int jointType, int jointMode = sim.jointmode_dynamic, int options = 0, float[2] sizes = {0.15, 0.02})
]]

local codeEditorInfos = [[
sim._removeObject(handle dummyArg, handle object, bool delayedRemoval = false)
sim._removeObjects(handle dummyArg, handle[] objects, bool delayedRemoval = false)
sim._removeModel(handle dummyArg, handle objectHandle, bool delayedRemoval = false)
sim.removeObjects(handle[] objects, bool delayedRemoval = false)
sim.removeModel(handle objectHandle, bool delayedRemoval = false)
handle[] descendants = sim._getDescendants(handle object, string[] objectTypes = {'sceneObject'}, int depth = 9999)
handle[] ancestors = sim._getAncestors(handle object, string[] objectTypes = {'sceneObject'}, int cnt = 9999)
handle[] copiedObjects = sim._duplicateObjects(handle dummyArg, handle[] objects, int options = 0)
handle[] copiedObjects = sim.copyPasteObjects(handle[] objects, int options = 0)
handle object = sim.loadModel(string filename)
handle object = sim.loadModelFromBuffer(buffer serializedModel)
buffer thumbnail = sim.loadModelThumbnail(string filename)
buffer thumbnail = sim.loadModelThumbnailFromBuffer(buffer serializedModel)
sim._saveModel(handle modelBase, string filename)
buffer serializedModel = sim._saveModelToBuffer(handle modelBase)
sim.__saveModel(handle dummyArg, handle modelBase, string filename)
buffer serializedModel = sim.__saveModelToBuffer(handle dummyArg, handle modelBase)

handle handle = sim.createScript(int scriptType, string scriptString, int options=0, string lang='')
handle handle = sim.createHeightfieldShape(int options, float shadingAngle, int xPointCount, int yPointCount, float xSize, float[] heights)
handle handle = sim.createOctree(float voxelSize = 0.025, int options = 0, float pointSize = 2.0)
handle handle = sim.createPath(float[] ctrlPts, int options = 0, int subdiv = 100, float smoothness = 1.0, int orientationMode = 0, float[3] upVector = {0, 0, 1})
handle handle = sim.createPointCloud(float maxVoxelSize = 0.02, int maxPtCntPerVoxel = 20, int options = 0, float pointSize = 4.0)
handle handle = sim.createPrimitiveShape(int primitiveType, float[3] sizes, int options=0)
handle handle = sim.createProximitySensor(int sensorType, int subType = 16, int options = 0, int[8] intParams = nil, float[15] floatParams = nil)
handle handle = sim.createShape(int options, float shadingAngle, float[] vertices, int[] indices, float[] normals, float[] textureCoordinates, buffer texture, int[2] textureResolution)
handle handle, int textureId, int[2] resolution = sim.createTexture(string fileName, int options = 0, float[2] planeSizes = {0.1, 0.1}, float[2] scalingUV = nil, float[3] xy_g = {0.0, 0.0, 0.0}, int fixedResolution = 0, int[2] resolution = {512, 512})
handle handle = sim.createVisionSensor(int options = 0, int[4] intParams = nil, float[11] floatParams = nil)

sim.addToCollection(handle collectionHandle, handle objectHandle, int what = sim.handle_single, int options = 0)
sim.removeFromCollection(handle collectionHandle, handle objectHandle, int what = sim.handle_single, int options = 0)
sim.addDrawingObjectItem(handle drawingObjectHandle, float[] itemData = {})
sim.setObjectSel(handle[] objectHandles)
handle[] objectHandles = sim.getObjectSel()
handle particleObjectHandle = sim.addParticleObject(int objectType, float size, float density, float[] params, float lifeTime, int maxItemCount, float[3] color=nil)
sim.addParticleObjectItem(handle objectHandle, float[] itemData)
int res = sim.adjustView(int viewHandleOrIndex, handle objectHandle, int options, string viewLabel=nil)
sim.auxiliaryConsoleClose(handle consoleHandle)
handle consoleHandle = sim.auxiliaryConsoleOpen(string title, int maxLines = 50, int mode = 0, int[2] position = {100, 100}, int[2] size = {640, 200}, float[3] textColor = {0.0, 0.0, 0.0}, float[3] backgroundColor = {1.0, 1.0, 1.0})
sim.auxiliaryConsolePrint(handle consoleHandle, string text = "")
sim.auxiliaryConsoleShow(handle consoleHandle, bool showState)
any outArg = sim.callScriptFunction(handle scriptHandle, string functionName, any inArg)
int result = sim.cameraFitToView(int viewHandleOrIndex, handle[] objectHandles = {}, int options = 0, float scaling = 1.0)
map[] originalColorData = sim.changeEntityColor(handle entityHandle, color newColor = {1.0, 0.0, 0.0}, int colorComponent = sim.colorcomponent_ambient_diffuse)
sim.restoreEntityColor(map[] colorData)
bool result = sim.isHandle(handle objectHandle)
string objectAlias = sim.getObjectAlias(handle objectHandle, int options = -1)


float[] vertices, int[] indices, float[] normals = sim.getShapeMesh(handle shapeHandle)
float mass = sim.getShapeMass(handle shapeHandle)
sim.setShapeMass(handle shapeHandle, float mass)
sim.setShapeInertia(handle shapeHandle, matrix inertiaMatrix, pose comPose)
matrix inertiaMatrix, vector3 com = sim.getShapeInertia(handle shapeHandle)
sim.initScript(handle scriptHandle = sim.handle_self)
sim.addForce(handle shapeHandle, vector3 position, vector3 force)
sim.addForceAndTorque(handle shapeHandle, vector3 force = {0.0, 0.0, 0.0}, vector3 torque = {0.0, 0.0, 0.0})
string info = sim.getLastInfo()
int prevStepLevel = sim.setStepping(bool enabled)
sim.systemSemaphore(string key, bool acquire)
sim.addLog(int verbosityLevel, string logMessage)
int curveId = sim.addGraphCurve(handle graphHandle, string curveName, int dim, int[2..3] streamIds, float[2..3] defaultValues, string unitStr, int options=0, float[3] color={1, 1, 0}, int curveWidth=2)
int streamId = sim.addGraphStream(handle graphHandle, string streamName, string unit, int options=0, float[3] color={1, 0, 0}, float cyclicRange=pi)
sim.addReferencedHandle(handle objectHandle, handle referencedHandle, string tag='', map opts={})
sim.alignShapeBB(handle shapeHandle, pose p)
sim.announceSceneContentChange()
sim.broadcastMsg(map message, int options=0)
bool result, handle[2] collidingObjects = sim.checkCollision(handle entity1Handle, handle entity2Handle = sim.handle_all)
bool result, float dist, vector3 p1, vector3 p2, handle[2] objectHandlePair = sim.checkDistance(handle entity1Handle, handle entity2Handle = sim.handle_all, float threshold = 0.0)
int result, int tag, int locationLow, int locationHigh = sim.checkOctreePointOccupancy(handle octreeHandle, int options, float[] points)
bool result, float distance, vector3 detectedPoint, handle detectedObjectHandle, vector3 normalVector = sim.checkProximitySensor(handle sensorHandle, handle entityHandle, int mode=-1, float threshold=0.0, float maxAngle=0.0)
int result, float[] auxPacket1, float[] auxPacket2 = sim.checkVisionSensor(handle sensorHandle, handle entityHandle)
int result = sim.closeScene()
buffer outImg = sim.combineRgbImages(buffer img1, int[2] img1Res, buffer img2, int[2] img2Res, int operation)
int result = sim.computeMassAndInertia(handle shapeHandle, float density)
int order, int totalSiblingsCount = sim.getObjectHierarchyOrder(handle objectHandle)
sim.setObjectHierarchyOrder(handle objectHandle, int order)
sim.removeCollection(handle collectionHandle)
sim.destroyGraphCurve(handle graphHandle, int curveId)
int curveId = sim.duplicateGraphCurveToStatic(handle graphHandle, int curveId, string curveName='')
int result, any value = sim.executeScriptString(handle scriptHandle, string stringToExecute)
sim.exportMesh(int fileformat, string pathAndFilename, int options, float scalingFactor, float[1..*] vertices, int[1..*] indices)
handle floatingViewHandle = sim.floatingViewAdd(float posX, float posY, float sizeX, float sizeY, int options)
int result = sim.floatingViewRemove(handle floatingViewHandle)
handle shapeHandle = sim.generateShapeFromPath(float[] path, float[] section, int options=0, float[3] upVector={0.0, 0.0, 1.0})
handle modelHandle = sim.generateTextShape(string txt, float[3] color={1, 1, 1}, float height=0.1, bool centered=false, string alphabetLocation=nil)
float[] path, float[] times, handle script = sim.generateTimeOptimalTrajectory(float[] path, float[] pathLengths, float[] minMaxVel, float[] minMaxAccel, int trajPtSamples=1000, string boundaryCondition='not-a-knot', float timeout=5)
string[] funcsAndVars = sim.getApiFunc(handle scriptHandle, string apiWord)
string info = sim.getApiInfo(handle scriptHandle, string apiWord)
float posAlongPath = sim.getClosestPosOnPath(float[] path, float[] pathLengths, float[3] absPt)
float distance = sim.getConfigDistance(float[] configA, float[] configB, float[] metric=nil, int[] types=nil)
int[2] collidingObjects, float[3] collisionPoint, float[3] reactionForce, float[3] normalVector = sim.getContactInfo(int dynamicPass, handle objectHandle, int index)
int explicitHandlingFlags = sim.getExplicitHandling(handle objectHandle)
string theString = sim.getExtensionString(handle objectHandle, int index, string key=nil)
map[] events = sim.getGenesisEvents()
buffer events = sim.getGenesisEvents()
string label, int attributes, float[3] curveColor, float[] xData, float[] yData, float[6] minMax, int curveId, int curveWidth = sim.getGraphCurve(int graphHandle, int graphType, int curveIndex)
int bitCoded, float[3] bgColor, float[3] fgColor = sim.getGraphInfo(int graphHandle)
handle masterJointHandle, float offset, float multCoeff = sim.getJointDependency(handle jointHandle)
float forceOrTorque = sim.getJointForce(handle jointHandle)
bool cyclic, float[2] interval = sim.getJointInterval(handle objectHandle)
int jointMode, int options = sim.getJointMode(handle jointHandle)
float pos = sim.getJointPosition(handle objectHandle)
sim.setJointPosition(handle objectHandle, float pos)
float forceOrTorque = sim.getJointTargetForce(handle jointHandle)
float targetPosition = sim.getJointTargetPosition(handle objectHandle)
float targetVelocity = sim.getJointTargetVelocity(handle objectHandle)
int jointType = sim.getJointType(handle objectHandle)
float velocity = sim.getJointVelocity(handle jointHandle)
int state, float[3] zero, float[3] diffusePart, float[3] specular = sim.getLightParameters(int lightHandle)
int linkDummyHandle = sim.getLinkDummy(handle dummyHandle)
int navigationMode = sim.getNavigationMode()
handle objectHandle = sim.getObject(string path, map options={})
string alias = sim.getObjectAliasRelative(int handle, int baseHandle, int options=-1)
float[7] pose = sim.getObjectChildPose(int objectHandle)
float[3] rgbData = sim.getObjectColor(int objectHandle, int index, int colorComponent)
sim.getObjectFromUid(int uid, map options={})
int handle = sim.getObjectHandle(string path, map options={})
float sizeFactor = sim.getObjectSizeFactor(int ObjectHandle)
int objectType = sim.getObjectType(handle objectHandle)
int uid = sim.getObjectUid(int objectHandle)
float[3] linearVelocity, float[3] angularVelocity = sim.getObjectVelocity(int objectHandle)
int objectHandle = sim.getObjects(int index, int objectType)
handle[] objects = sim.getObjectsInTree(handle treeBaseHandle, int objectType = sim.handle_all, int options = 0)
float[] voxels = sim.getOctreeVoxels(int octreeHandle)
int pageIndex = sim.getPage()
float[] config = sim.getPathInterpolatedConfig(float[] path, float[] pathLengths, float t, map method={type='linear', strength=1.0, forceOpen=false}, int[] types=nil)
float[] pathLengths, float totalLength = sim.getPathLengths(float[] path, int dof, func distCallback=nil)
float maxVoxelSize, int maxPtCntPerVoxel, int options, float pointSize = sim.getPointCloudOptions(int pointCloudHandle)
float[] points = sim.getPointCloudPoints(int pointCloudHandle)
sim.fastIdleLoop(bool enable)
int handle = sim.loadPlugin(string name)
handle[] referencedHandles = sim.getReferencedHandles(handle objectHandle, string tag='')
handle referencedHandle = sim.getReferencedHandle(handle objectHandle, string tag='')
string[] tags = sim.getReferencedHandlesTags(handle objectHandle)
buffer imageOut, int[2] effectiveResolutionOut = sim.getScaledImage(buffer imageIn, int[2] resolutionIn, int[2] desiredResolutionOut, int options)
handle scriptHandle = sim.getScript(int scriptType, string scriptName='')
map wrapper = sim.getScriptFunctions(handle scriptHandle)
float[3] size, float[7] pose = sim.getShapeBB(int shapeHandle)
float[3] size = sim.getModelBB(int handle)
buffer data, string dataType = sim.readCustomDataBlockEx(int handle, string tag, map options={})
sim.writeCustomDataBlockEx(int handle, string tag, buffer data, map options={})
int result, float[] rgbData = sim.getShapeColor(int shapeHandle, string colorName, int colorComponent)
int result, int pureType, float[4] dimensions = sim.getShapeGeomInfo(int shapeHandle)
int textureId = sim.getShapeTextureId(int shapeHandle)
map data = sim.getShapeViz(int shapeHandle, int itemIndex)
string signalName = sim.getSignalName(int signalIndex, int signalType)
int simulationState = sim.getSimulationState()
float simulationTime = sim.getSimulationTime()
float timeStep = sim.getSimulationTimeStep()
int messageID, int[4] auxiliaryData, int[1..*] auxiliaryData2 = sim.getSimulatorMessage()
string stacktraceback = sim.getStackTraceback(handle scriptHandle = sim.handle_self)
float time = sim.getSystemTime()
int textureId, int[2] resolution = sim.getTextureId(string textureName)
bool stopping = sim.getSimulationStopping()
int threadId = sim.getThreadId()
float dt = sim.getAutoYieldDelay()
sim.setAutoYieldDelay(float dt)
string[] variables = sim.getUserVariables()
float[3] linearVelocity, float[3] angularVelocity = sim.getVelocity(int shapeHandle)
buffer depth, int[2] resolution = sim.getVisionSensorDepth(int sensorHandle, int options=0, int[2] pos={0, 0}, int[2] size={0, 0})
buffer image, int[2] resolution = sim.getVisionSensorImg(int sensorHandle, int options=0, float rgbaCutOff=0.0, int[2] pos={0, 0}, int[2] size={0, 0})
sim.getVisionSensorRes(int sensorHandle)
int shapeHandle = sim.groupShapes(int[] shapeHandles, bool merge=false)
int count = sim.handleAddOnScripts(int callType)
int count = sim.handleSimulationScripts(int callType)
int result = sim.handleDynamics(float deltaTime)
int count = sim.handleEmbeddedScripts(int callType)
sim.handleExtCalls()
sim.acquireLock()
sim.releaseLock()
sim.handleGraph(int objectHandle, float simulationTime)
sim.handleJointMotion()
int result, float distance, float[3] detectedPoint, int detectedObjectHandle, float[3] normalVector = sim.handleProximitySensor(int sensorHandle)
sim.handleSandboxScript(int callType)
sim.handleSensingStart()
sim.handleSimulationStart()
int detectionCount, float[] auxPacket1, float[] auxPacket2 = sim.handleVisionSensor(int sensorHandle)
float[1..*] vertices, int[1..*] indices = sim.importMesh(int fileformat, string pathAndFilename, int options, float identicalVerticeTolerance, float scalingFactor)
int shapeHandle = sim.importShape(int fileformat, string pathAndFilename, int options, float identicalVerticeTolerance, float scalingFactor)
int result = sim.registerScriptFuncHook(string funcToHook, string userFunc, bool execBefore)
int totalVoxelCnt = sim.insertObjectIntoOctree(int octreeHandle, int objectHandle, int options, float[] color=nil, int tag=0)
int totalPointCnt = sim.insertObjectIntoPointCloud(int pointCloudHandle, int objectHandle, int options, float gridSize, float[] color=nil, float duplicateTolerance=nil)
int totalPointCnt = sim.insertPointsIntoPointCloud(int pointCloudHandle, int options, float[] points, float[] color=nil, float duplicateTolerance=nil)
int totalVoxelCnt = sim.insertVoxelsIntoOctree(int octreeHandle, int options, float[] points, float[] color=nil, int[] tag=nil)
int totalPointCnt = sim.intersectPointsWithPointCloud(int pointCloudHandle, int options, float[] points, float tolerance)
int result = sim.isDeprecated(string funcOrConst)
bool enabled = sim.isDynamicallyEnabled(int objectHandle)
sim.launchExecutable(string filename, string parameters='', int showStatus=1)
buffer image, int[2] resolution = sim.loadImage(int options, string filename)
buffer image, int[2] resolution = sim.loadImage(int options, buffer serializedImage)
sim.loadScene(string filename)
sim.loadScene(buffer serializedScene)
int handle = sim.moduleEntry(int handle, string label=nil, int state=-1)
map data = sim.moveToConfig(map params)
map motionObject = sim.moveToConfig_init(map params)
int res, map data = sim.moveToConfig_step(map motionObject)
sim.moveToConfig_cleanup(map motionObject)
map data = sim.moveToPose(map params)
map motionObject = sim.moveToPose_init(map params)
int res, map data = sim.moveToPose_step(map motionObject)
sim.moveToPose_cleanup(map motionObject)
buffer data = sim.packDoubleTable(float[] doubleNumbers, int startDoubleIndex=0, int doubleCount=0)
buffer data = sim.packFloatTable(float[] floatNumbers, int startFloatIndex=0, int floatCount=0)
buffer data = sim.packInt32Table(int[] int32Numbers, int startInt32Index=0, int int32Count=0)
buffer data = sim.packTable(any[] aTable, int scheme=0)
buffer data = sim.packTable(map aTable, int scheme=0)
buffer data = sim.packUInt16Table(int[] uint16Numbers, int startUint16Index=0, int uint16Count=0)
buffer data = sim.packUInt32Table(int[] uint32Numbers, int startUInt32Index=0, int uint32Count=0)
buffer data = sim.packUInt8Table(int[] uint8Numbers, int startUint8Index=0, int uint8count=0)
sim.pauseSimulation()
sim.pushUserEvent(string event, int handle, int uid, map eventData, int options=0)
sim.quitSimulator()
buffer textureData = sim.readTexture(int textureId, int options, int posX=0, int posY=0, int sizeX=0, int sizeY=0)
int result = sim.refreshDialogs(int refreshDegree)
int result = sim.relocateShapeFrame(int shapeHandle, float[7] pose)
sim.removeDrawingObject(handle drawingObjectHandle)
sim.removeParticleObject(int particleObjectHandle)
int totalPointCnt = sim.removePointsFromPointCloud(int pointCloudHandle, int options, float[] points, float tolerance)
sim.removeReferencedObjects(handle objectHandle, string tag='')
int totalVoxelCnt = sim.removeVoxelsFromOctree(int octreeHandle, int options, float[] points)
float[] path = sim.resamplePath(float[] path, float[] pathLengths, int finalConfigCnt, map method={type='linear', strength=1.0, forceOpen=false}, int[] types=nil)
sim.resetDynamicObject(int objectHandle)
sim.resetGraph(int objectHandle)
sim.resetProximitySensor(int objectHandle)
sim.resetVisionSensor(int sensorHandle)
int handle = sim.ruckigPos(int dofs, float baseCycleTime, int flags, float[] currentPosVelAccel, float[] maxVelAccelJerk, int[] selection, float[] targetPosVel)
sim.ruckigRemove(int handle)
int result, float[] newPosVelAccel, float synchronizationTime = sim.ruckigStep(int handle, float cycleTime)
int handle = sim.ruckigVel(int dofs, float baseCycleTime, int flags, float[] currentPosVelAccel, float[] maxAccelJerk, int[] selection, float[] targetVel)
buffer serializedImage = sim.saveImage(buffer image, int[2] resolution, int options, string filename, int quality)
sim.saveScene(string filename)
buffer serializedScene = sim.saveScene()
int id = sim.scheduleExecution(func f, any[] args, float timePoint, bool simTime=false)
bool canceled = sim.cancelScheduledExecution(int id)
sim.throttle(float period, func f, ...)
int byteCount = sim.serialCheck(int portHandle)
sim.serialClose(int portHandle)
int portHandle = sim.serialOpen(string portString, int baudrate)
buffer data = sim.serialRead(int portHandle, int dataLengthToRead, bool blockingOperation, buffer closingString='', float timeout=0)
int charsSent = sim.serialSend(int portHandle, buffer data)
sim.setExplicitHandling(int objectHandle, int explicitHandlingFlags)
sim.setGraphStreamTransformation(int graphHandle, int streamId, int trType, float mult=1.0, float off=0.0, int movAvgPeriod=1)
sim.setGraphStreamValue(int graphHandle, int streamId, float value)
sim.setInt32Param(int parameter, int intState)
sim.setInt32Signal(string signalName, int signalValue)
sim.setJointDependency(int jointHandle, int masterJointHandle, float offset, float multCoeff)
sim.setJointInterval(int objectHandle, bool cyclic, float[2] interval)
sim.setJointMode(int jointHandle, int jointMode)
sim.setJointTargetForce(handle objectHandle, float forceOrTorque, bool signedValue = true)
sim.setJointTargetPosition(handle objectHandle, float targetPosition, float[] motionParams={})
sim.setJointTargetVelocity(handle objectHandle, float targetVelocity, float[] motionParams={})
sim.setLinkDummy(handle dummyHandle, handle linkDummyHandle)
string pluginName = sim.getPluginName(int index)
string info = sim.getPluginInfo(string pluginName, int infoType)
sim.setPluginInfo(string pluginName, int infoType, string info)
sim.setPluginInfo(string pluginName, int infoType, int info)
sim.setNavigationMode(int navigationMode)
sim.setObjectAlias(handle objectHandle, string objectAlias)
sim.setObjectChildPose(int objectHandle, float[7] pose)
bool result = sim.setObjectColor(int objectHandle, int index, int colorComponent, float[3] rgbData)
sim.setPage(int pageIndex)
sim.setPointCloudOptions(int pointCloudHandle, float maxVoxelSize, int maxPtCntPerVoxel, int options, float pointSize)
sim.setReferencedHandles(handle objectHandle, handle[] referencedHandles, string tag='')
sim.setShapeBB(int shapeHandle, float[3] size)
sim.setShapeColor(int shapeHandle, string colorName, int colorComponent, float[3] rgbData)
sim.setShapeMaterial(int shapeHandle, int materialIdOrShapeHandle)
sim.setShapeTexture(int shapeHandle, int textureId, int mappingMode, int options, float[2] uvScaling, float[3] position=nil, float[3] orientation=nil)
sim.setVisionSensorImg(int sensorHandle, buffer image, int options=0, int[2] pos={0, 0}, int[2] size={0, 0})
sim.startSimulation()
sim.stopSimulation(bool wait=false)
int totalVoxelCnt = sim.subtractObjectFromOctree(int octreeHandle, int objectHandle, int options)
int totalPointCnt = sim.subtractObjectFromPointCloud(int pointCloudHandle, int objectHandle, int options, float tolerance)
sim.yield()
sim.step()
string text, int[2] pos, int[2] size = sim.textEditorClose(int handle)
string text, int[2] pos, int[2] size, bool visible = sim.textEditorGetInfo(int handle)
int handle = sim.textEditorOpen(string initText, string properties)
sim.textEditorShow(int handle, bool showState)
buffer outBuffer = sim.transformBuffer(buffer inBuffer, int inFormat, float multiplier, float offset, int outFormat)
buffer newImage = sim.transformImage(buffer image, int[2] resolution, int options)
int[] simpleShapeHandles = sim.ungroupShape(int shapeHandle)
float[] doubleNumbers = sim.unpackDoubleTable(buffer data, int startDoubleIndex=0, int doubleCount=0, int additionalByteOffset=0)
float[] floatNumbers = sim.unpackFloatTable(buffer data, int startFloatIndex=0, int floatCount=0, int additionalByteOffset=0)
int[] int32Numbers = sim.unpackInt32Table(buffer data, int startInt32Index=0, int int32Count=0, int additionalByteOffset=0)
any aTable = sim.unpackTable(buffer buffer, int scheme=0)
int[] uint16Numbers = sim.unpackUInt16Table(buffer data, int startUint16Index=0, int uint16Count=0, int additionalByteOffset=0)
int[] uint32Numbers = sim.unpackUInt32Table(buffer data, int startUint32Index=0, int uint32Count=0, int additionalByteOffset=0)
int[] uint8Numbers = sim.unpackUInt8Table(buffer data, int startUint8Index=0, int uint8count=0)
sim.visitTree(int rootHandle, func visitorFunc, map options={})
float timeLeft = sim.wait(float dt, bool simulationTime=true)
sim.writeTexture(int textureId, int options, buffer textureData, int posX=0, int posY=0, int sizeX=0, int sizeY=0, float interpol=0.0)
int ret = sim.testCB(int a, func cb, int b)
map savedData = sim.getShapeAppearance(handle handle, map opts={})
int handle = sim.setShapeAppearance(handle handle, map savedData, map opts={})
sim.setBoolProperty(handle target, string pName, bool pValue, map options={})
bool pValue = sim.getBoolProperty(handle target, string pName, map options={})
sim.setIntProperty(handle target, string pName, int pValue, map options={})
int pValue = sim.getIntProperty(handle target, string pName, map options={})
sim.setLongProperty(handle target, string pName, int pValue, map options={})
int pValue = sim.getLongProperty(handle target, string pName, map options={})
sim.setFloatProperty(handle target, string pName, float pValue, map options={})
float pValue = sim.getFloatProperty(handle target, string pName, map options={})
sim.setStringProperty(handle target, string pName, string pValue, map options={})
string pValue = sim.getStringProperty(handle target, string pName, map options={})
sim.setBufferProperty(handle target, string pName, buffer pValue, map options={})
buffer pValue = sim.getBufferProperty(handle target, string pName, map options={})
sim.setTableProperty(handle target, string pName, map pValue, map options={})
map pValue = sim.getTableProperty(handle target, string pName, map options={})
sim.setIntArray2Property(handle target, string pName, int[2] pValue, map options={})
int[2] pValue = sim.getIntArray2Property(handle target, string pName, map options={})
sim.setVector2Property(handle target, string pName, float[2] pValue, map options={})
float[2] pValue = sim.getVector2Property(handle target, string pName, map options={})
sim.setVector3Property(handle target, string pName, vector3 pValue, map options={})
vector3 pValue = sim.getVector3Property(handle target, string pName, map options={})
sim.setQuaternionProperty(handle target, string pName, quaternion pValue, map options={})
quaternion pValue = sim.getQuaternionProperty(handle target, string pName, map options={})
sim.setPoseProperty(handle target, string pName, pose pValue, map options={})
pose pValue = sim.getPoseProperty(handle target, string pName, map options={})
sim.setColorProperty(handle target, string pName, color pValue, map options={})
color pValue = sim.getColorProperty(handle target, string pName, map options={})
sim.setFloatArrayProperty(handle target, string pName, float[] pValue, map options={})
float[] pValue = sim.getFloatArrayProperty(handle target, string pName, map options={})
sim.setIntArrayProperty(handle target, string pName, int[] pValue, map options={})
int[] pValue = sim.getIntArrayProperty(handle target, string pName, map options={})
sim.setHandleProperty(handle target, string pName, handle pValue, map options={})
handle pValue = sim.getHandleProperty(handle target, string pName, map options={})
sim.setHandleArrayProperty(handle target, string pName, handle[] pValue, map options={})
handle[] pValue = sim.getHandleArrayProperty(handle target, string pName, map options={})
sim.setStringArrayProperty(handle target, string pName, string[] pValue, map options={})
string[] pValue = sim.getStringArrayProperty(handle target, string pName, map options={})
sim.removeProperty(handle target, string pName, map options={})
string pName, string appartenance = sim.getPropertyName(handle target, int index, map options={})
int pType, int pFlags, string description = sim.getPropertyInfo(handle target, string pName, map options={})
sim.setEventFilters(map filters={})
any pValue = sim.getProperty(handle target, string pName, map options={})
sim.setProperty(handle target, string pName, any pValue, int pType=nil)
string pTypeStr = sim.getPropertyTypeString(int pType)
any value = sim.convertPropertyValue(any value, int fromType, int toType)
map values = sim.getProperties(handle target, map opts={})
sim.setProperties(handle target, map props)
map infos = sim.getPropertiesInfos(handle target, map opts={})

sim.propertytype_bool
sim.propertytype_int
sim.propertytype_long
sim.propertytype_float
sim.propertytype_string
sim.propertytype_buffer
sim.propertytype_intarray2
sim.propertytype_vector2
sim.propertytype_vector3
sim.propertytype_quaternion
sim.propertytype_pose
sim.propertytype_matrix3x3
sim.propertytype_matrix4x4
sim.propertytype_matrix
sim.propertytype_array
sim.propertytype_map
sim.propertytype_null
sim.propertytype_color
sim.propertytype_floatarray
sim.propertytype_intarray
sim.propertytype_table
sim.propertyinfo_notwritable
sim.propertyinfo_notreadable
sim.propertyinfo_removable
sim.propertyinfo_largedata
sim.propertyinfo_deprecated
sim.propertyinfo_modelhashexclude

sim.objecttype_sceneobject
sim.objecttype_collection
sim.objecttype_script
sim.objecttype_texture
sim.objecttype_mesh
sim.objecttype_interfacestack

sim.buffer_base64
sim.buffer_clamp
sim.buffer_double
sim.buffer_float
sim.buffer_int16
sim.buffer_int32
sim.buffer_int8
sim.buffer_split
sim.buffer_uint16
sim.buffer_uint32
sim.buffer_uint8
sim.buffer_uint8argb
sim.buffer_uint8bgr
sim.buffer_uint8rgb
sim.buffer_uint8rgba
sim.bullet_body_angulardamping
sim.bullet_body_autoshrinkconvex
sim.bullet_body_bitcoded
sim.bullet_body_friction
sim.bullet_body_lineardamping
sim.bullet_body_nondefaultcollisionmargingfactor
sim.bullet_body_nondefaultcollisionmargingfactorconvex
sim.bullet_body_oldfriction
sim.bullet_body_restitution
sim.bullet_body_sticky
sim.bullet_body_usenondefaultcollisionmargin
sim.bullet_body_usenondefaultcollisionmarginconvex
sim.bullet_constraintsolvertype_dantzig
sim.bullet_constraintsolvertype_nncg
sim.bullet_constraintsolvertype_projectedgaussseidel
sim.bullet_constraintsolvertype_sequentialimpulse
sim.bullet_global_bitcoded
sim.bullet_global_collisionmarginfactor
sim.bullet_global_computeinertias
sim.bullet_global_constraintsolvertype
sim.bullet_global_constraintsolvingiterations
sim.bullet_global_fullinternalscaling
sim.bullet_global_internalscalingfactor
sim.bullet_joint_normalcfm
sim.bullet_joint_pospid1
sim.bullet_joint_pospid2
sim.bullet_joint_pospid3
sim.bullet_joint_stopcfm
sim.bullet_joint_stoperp

sim.colorcomponent_ambient
sim.colorcomponent_ambient_diffuse
sim.colorcomponent_auxiliary
sim.colorcomponent_diffuse
sim.colorcomponent_emission
sim.colorcomponent_specular
sim.colorcomponent_transparency

sim.displayattribute_colorcoded
sim.displayattribute_colorcodedpickpass
sim.displayattribute_colorcodedtriangles
sim.displayattribute_depthpass
sim.displayattribute_dynamiccontentonly
sim.displayattribute_forbidedges
sim.displayattribute_forbidwireframe
sim.displayattribute_forcewireframe
sim.displayattribute_forvisionsensor
sim.displayattribute_ignorelayer
sim.displayattribute_ignorerenderableflag
sim.displayattribute_mainselection
sim.displayattribute_mirror
sim.displayattribute_nodrawingobjects
sim.displayattribute_noghosts
sim.displayattribute_noopenglcallbacks
sim.displayattribute_noparticles
sim.displayattribute_nopointclouds
sim.displayattribute_originalcolors
sim.displayattribute_pickpass
sim.displayattribute_renderpass
sim.displayattribute_selected
sim.displayattribute_thickEdges
sim.displayattribute_trianglewireframe
sim.displayattribute_useauxcomponent

sim.drawing_cubepts
sim.drawing_cyclic
sim.drawing_discpts
sim.drawing_lines
sim.drawing_linestrip
sim.drawing_local
sim.drawing_overlay
sim.drawing_painttag
sim.drawing_points
sim.drawing_quadpts
sim.drawing_spherepts
sim.drawing_trianglepts
sim.drawing_triangles

sim.dummytype_dynloopclosure
sim.dummytype_dyntendon
sim.dummytype_default
sim.dummytype_assembly

sim.handle_all
sim.handle_all_except_explicit
sim.handle_all_except_self
sim.handle_app
sim.handle_appstorage
sim.handle_chain
sim.handle_default
sim.handle_inverse
sim.handle_mainscript
sim.handle_parent
sim.handle_scene
sim.handle_self
sim.handle_single
sim.handle_tree
sim.handle_world
sim.handle_sceneobject
sim.handle_sandbox
sim.handle_mesh

sim.handleflag_abscoords
sim.handleflag_addmultiple
sim.handleflag_altname
sim.handleflag_assembly
sim.handleflag_axis
sim.handleflag_camera
sim.handleflag_codedstring
sim.handleflag_depthbuffer
sim.handleflag_depthbuffermeters
sim.handleflag_extended
sim.handleflag_greyscale
sim.handleflag_keeporiginal
sim.handleflag_model
sim.handleflag_rawvalue
sim.handleflag_reljointbaseframe
sim.handleflag_resetforce
sim.handleflag_resetforcetorque
sim.handleflag_resettorque
sim.handleflag_silenterror
sim.handleflag_togglevisibility
sim.handleflag_wxyzquat

sim.imgcomb_horizontal
sim.imgcomb_vertical

sim.joint_prismatic
sim.joint_revolute
sim.joint_spherical

sim.jointdynctrl_callback
sim.jointdynctrl_force
sim.jointdynctrl_free
sim.jointdynctrl_position
sim.jointdynctrl_spring
sim.jointdynctrl_velocity

sim.jointmode_dependent
sim.jointmode_dynamic
sim.jointmode_kinematic

sim.light_directional
sim.light_omnidirectional
sim.light_spot

sim.message_keypress
sim.message_model_loaded
sim.message_object_selection_changed
sim.message_scene_loaded

sim.plugininfo_builddatestr
sim.plugininfo_extversionint
sim.plugininfo_extversionstr
sim.plugininfo_statusbarverbosity
sim.plugininfo_verbosity

sim.navigation_cameraangle
sim.navigation_camerarotate
sim.navigation_camerarotatemiddlebutton
sim.navigation_camerarotaterightbutton
sim.navigation_camerashift
sim.navigation_camerazoom
sim.navigation_camerazoomwheel
sim.navigation_clickselection
sim.navigation_createpathpoint
sim.navigation_ctrlselection
sim.navigation_objectrotate
sim.navigation_objectshift
sim.navigation_passive
sim.navigation_shiftselection

sim.sceneobject_camera
sim.sceneobject_dummy
sim.sceneobject_script
sim.sceneobject_forcesensor
sim.sceneobject_graph
sim.sceneobject_joint
sim.sceneobject_light
sim.sceneobject_octree
sim.sceneobject_pointcloud
sim.sceneobject_proximitysensor
sim.sceneobject_renderingsensor
sim.sceneobject_shape
sim.sceneobject_visionsensor

sim.particle_cyclic
sim.particle_emissioncolor
sim.particle_ignoresgravity
sim.particle_invisible
sim.particle_itemcolors
sim.particle_itemdensities
sim.particle_itemsizes
sim.particle_painttag
sim.particle_particlerespondable
sim.particle_points1
sim.particle_points2
sim.particle_points4
sim.particle_respondable1to4
sim.particle_respondable5to8
sim.particle_roughspheres
sim.particle_spheres
sim.particle_water

sim.physics_bullet
sim.physics_mujoco
sim.physics_newton
sim.physics_ode
sim.physics_physx
sim.physics_vortex

sim.primitiveshape_capsule
sim.primitiveshape_cone
sim.primitiveshape_cuboid
sim.primitiveshape_cylinder
sim.primitiveshape_disc
sim.primitiveshape_heightfield
sim.primitiveshape_none
sim.primitiveshape_plane
sim.primitiveshape_spheroid

sim.proximitysensor_cone
sim.proximitysensor_cylinder
sim.proximitysensor_disc
sim.proximitysensor_pyramid
sim.proximitysensor_ray

sim.ruckig_minaccel
sim.ruckig_minvel
sim.ruckig_nosync
sim.ruckig_phasesync
sim.ruckig_timesync

sim.scriptexecorder_first
sim.scriptexecorder_last
sim.scriptexecorder_normal

sim.lang_undefined
sim.lang_lua
sim.lang_python

sim.scripttype_addon
sim.scripttype_simulation
sim.scripttype_customization
sim.scripttype_main
sim.scripttype_sandbox
sim.scripttype_passive

sim.shape_compound
sim.shape_simple

sim.simulation_advancing
sim.simulation_advancing_lastbeforestop
sim.simulation_advancing_running
sim.simulation_paused
sim.simulation_stopped

sim.stream_transf_cumulative
sim.stream_transf_derivative
sim.stream_transf_integral
sim.stream_transf_raw

sim.texturemap_cube
sim.texturemap_cylinder
sim.texturemap_plane
sim.texturemap_sphere

sim.verbosity_debug
sim.verbosity_default
sim.verbosity_errors
sim.verbosity_infos
sim.verbosity_loadinfos
sim.verbosity_msgs
sim.verbosity_none
sim.verbosity_onlyterminal
sim.verbosity_questions
sim.verbosity_scripterrors
sim.verbosity_scriptinfos
sim.verbosity_scriptwarnings
sim.verbosity_trace
sim.verbosity_traceall
sim.verbosity_tracelua
sim.verbosity_undecorated
sim.verbosity_useglobal
sim.verbosity_warnings

sim.volume_cone
sim.volume_cylinder
sim.volume_disc
sim.volume_pyramid
sim.volume_randomizedray
sim.volume_ray
]]

registerCodeEditorInfos("sim-2", codeEditorInfos)
