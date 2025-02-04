local codeEditorInfos = [[
string info = sim.getLastInfo()
int prevStepLevel = sim.setStepping(bool enabled)
sim.systemSemaphore(string key, bool acquire)
sim.addLog(int verbosityLevel, string logMessage)
int drawingObjectHandle = sim.addDrawingObject(int objectType, float size, float duplicateTolerance, int parentObjectHandle, int maxItemCount, float[3] color=nil)
int result = sim.addDrawingObjectItem(int drawingObjectHandle, float[] itemData)
sim.addForce(int shapeHandle, float[3] position, float[3] force)
sim.addForceAndTorque(int shapeHandle, float[3] force=nil, float[3] torque=nil)
int curveId = sim.addGraphCurve(int graphHandle, string curveName, int dim, int[2..3] streamIds, float[2..3] defaultValues, string unitStr, int options=0, float[3] color={1, 1, 0}, int curveWidth=2)
int streamId = sim.addGraphStream(int graphHandle, string streamName, string unit, int options=0, float[3] color={1, 0, 0}, float cyclicRange=pi)
sim.addItemToCollection(int collectionHandle, int what, int objectHandle, int options)
int particleObjectHandle = sim.addParticleObject(int objectType, float size, float density, float[] params, float lifeTime, int maxItemCount, float[3] color=nil)
sim.addParticleObjectItem(int objectHandle, float[] itemData)
sim.addReferencedHandle(int objectHandle, int referencedHandle, string tag='', map opts={})
int res = sim.adjustView(int viewHandleOrIndex, int objectHandle, int options, string viewLabel=nil)
int result = sim.alignShapeBB(int shapeHandle, float[7] pose)
float yawAngle, float pitchAngle, float rollAngle = sim.alphaBetaGammaToYawPitchRoll(float alphaAngle, float betaAngle, float gammaAngle)
int result = sim.announceSceneContentChange()
int result = sim.auxiliaryConsoleClose(int consoleHandle)
int consoleHandle = sim.auxiliaryConsoleOpen(string title, int maxLines, int mode, int[2] position=nil, int[2] size=nil, float[3] textColor=nil, float[3] backgroundColor=nil)
int result = sim.auxiliaryConsolePrint(int consoleHandle, string text)
int result = sim.auxiliaryConsoleShow(int consoleHandle, bool showState)
sim.broadcastMsg(map message, int options=0)
float[12] matrix = sim.buildIdentityMatrix()
float[12] matrix = sim.buildMatrix(float[3] position, float[3] eulerAngles)
float[7] pose = sim.buildPose(float[3] position, float[3] eulerAnglesOrAxis, int mode=0, float[3] axis2=nil)
... = sim.callScriptFunction(string functionName, int scriptHandle, ...)
int result = sim.cameraFitToView(int viewHandleOrIndex, int[] objectHandles=nil, int options=0, float scaling=1.0)
bool canceled = sim.cancelScheduledExecution(int id)
map[] originalColorData = sim.changeEntityColor(int entityHandle, float[3] newColor, int colorComponent=sim.colorcomponent_ambient_diffuse)
int result, int[2] collidingObjects = sim.checkCollision(int entity1Handle, int entity2Handle)
int segmentCount, float[6..*] segmentData = sim.checkCollisionEx(int entity1Handle, int entity2Handle)
int result, float[7] distanceData, int[2] objectHandlePair = sim.checkDistance(int entity1Handle, int entity2Handle, float threshold=0.0)
int result, int tag, int locationLow, int locationHigh = sim.checkOctreePointOccupancy(int octreeHandle, int options, float[] points)
int result, float distance, float[3] detectedPoint, int detectedObjectHandle, float[3] normalVector = sim.checkProximitySensor(int sensorHandle, int entityHandle)
int result, float distance, float[3] detectedPoint, int detectedObjectHandle, float[3] normalVector = sim.checkProximitySensorEx(int sensorHandle, int entityHandle, int mode, float threshold, float maxAngle)
int result, float distance, float[3] detectedPoint, float[3] normalVector = sim.checkProximitySensorEx2(int sensorHandle, float[3..*] vertices, int itemType, int itemCount, int mode, float threshold, float maxAngle)
int result, float[] auxPacket1, float[] auxPacket2 = sim.checkVisionSensor(int sensorHandle, int entityHandle)
float[] theBuffer = sim.checkVisionSensorEx(int sensorHandle, int entityHandle, bool returnImage)
buffer theBuffer = sim.checkVisionSensorEx(int sensorHandle, int entityHandle, bool returnImage)
int result = sim.closeScene()
buffer outImg = sim.combineRgbImages(buffer img1, int[2] img1Res, buffer img2, int[2] img2Res, int operation)
int result = sim.computeMassAndInertia(int shapeHandle, float density)
int[1..*] copiedObjectHandles = sim.copyPasteObjects(int[1..*] objectHandles, int options=0)
any[] copy = sim.copyTable(any[] original)
map copy = sim.copyTable(map original)
int collectionHandle = sim.createCollection(int options=0)
int dummyHandle = sim.createDummy(float size)
int scriptHandle = sim.createScript(int scriptType, string scriptString, int options = 0, string lang = '')
int sensorHandle = sim.createForceSensor(int options, int[5] intParams, float[5] floatParams)
int shapeHandle = sim.createHeightfieldShape(int options, float shadingAngle, int xPointCount, int yPointCount, float xSize, float[] heights)
int jointHandle = sim.createJoint(int jointType, int jointMode, int options, float[2] sizes=nil)
int handle = sim.createOctree(float voxelSize, int options, float pointSize)
int pathHandle = sim.createPath(float[] ctrlPts, int options=0, int subdiv=100, float smoothness=1.0, int orientationMode=0, float[3] upVector={0, 0, 1})
int handle = sim.createPointCloud(float maxVoxelSize, int maxPtCntPerVoxel, int options, float pointSize)
int shapeHandle = sim.createPrimitiveShape(int primitiveType, float[3] sizes, int options=0)
int sensorHandle = sim.createProximitySensor(int sensorType, int subType, int options, int[8] intParams, float[15] floatParams)
int shapeHandle = sim.createShape(int options, float shadingAngle, float[] vertices, int[] indices, float[] normals, float[] textureCoordinates, buffer texture, int[2] textureResolution)
int shapeHandle, int textureId, int[2] resolution = sim.createTexture(string fileName, int options, float[2] planeSizes=nil, float[2] scalingUV=nil, float[2] xy_g=nil, int fixedResolution=0, int[2] resolution=nil)
int sensorHandle = sim.createVisionSensor(int options, int[4] intParams, float[11] floatParams)
int order, int totalSiblingsCount = sim.getObjectHierarchyOrder(int objectHandle)
sim.setObjectHierarchyOrder(int objectHandle, int order)
sim.destroyCollection(int collectionHandle)
sim.destroyGraphCurve(int graphHandle, int curveId)
int curveId = sim.duplicateGraphCurveToStatic(int graphHandle, int curveId, string curveName='')
int result, any value = sim.executeScriptString(string stringToExecute, int scriptHandle)
sim.exportMesh(int fileformat, string pathAndFilename, int options, float scalingFactor, float[1..*] vertices, int[1..*] indices)
int floatingViewHandle = sim.floatingViewAdd(float posX, float posY, float sizeX, float sizeY, int options)
int result = sim.floatingViewRemove(int floatingViewHandle)
int shapeHandle = sim.generateShapeFromPath(float[] path, float[] section, int options=0, float[3] upVector={0.0, 0.0, 1.0})
int modelHandle = sim.generateTextShape(string txt, float[3] color={1, 1, 1}, float height=0.1, bool centered=false, string alphabetLocation=nil)
float[] path, float[] times = sim.generateTimeOptimalTrajectory(float[] path, float[] pathLengths, float[] minMaxVel, float[] minMaxAccel, int trajPtSamples=1000, string boundaryCondition='not-a-knot', float timeout=5)
float[] configs = sim.getAlternateConfigs(int[] jointHandles, float[] inputConfig, int tipHandle=-1, float[] lowLimits=nil, float[] ranges=nil)
string[] funcsAndVars = sim.getApiFunc(int scriptHandle, string apiWord)
string info = sim.getApiInfo(int scriptHandle, string apiWord)
float posAlongPath = sim.getClosestPosOnPath(float[] path, float[] pathLengths, float[3] absPt)
int[] objectHandles = sim.getCollectionObjects(int collectionHandle)
float distance = sim.getConfigDistance(float[] configA, float[] configB, float[] metric=nil, int[] types=nil)
int[2] collidingObjects, float[3] collisionPoint, float[3] reactionForce, float[3] normalVector = sim.getContactInfo(int dynamicPass, int objectHandle, int index)
float[3] eulerAngles = sim.getEulerAnglesFromMatrix(float[12] matrix)
int explicitHandlingFlags = sim.getExplicitHandling(int objectHandle)
string theString = sim.getExtensionString(int objectHandle, int index, string key=nil)
map[] events = sim.getGenesisEvents()
buffer events = sim.getGenesisEvents()
string label, int attributes, float[3] curveColor, float[] xData, float[] yData, float[6] minMax, int curveId, int curveWidth = sim.getGraphCurve(int graphHandle, int graphType, int curveIndex)
int bitCoded, float[3] bgColor, float[3] fgColor = sim.getGraphInfo(int graphHandle)
bool result = sim.getRealTimeSimulation()
int result = sim.getIsRealTimeSimulation()
int masterJointHandle, float offset, float multCoeff = sim.getJointDependency(int jointHandle)
float forceOrTorque = sim.getJointForce(int jointHandle)
bool cyclic, float[2] interval = sim.getJointInterval(int objectHandle)
int jointMode, int options = sim.getJointMode(int jointHandle)
float position = sim.getJointPosition(int objectHandle)
float forceOrTorque = sim.getJointTargetForce(int jointHandle)
float targetPosition = sim.getJointTargetPosition(int objectHandle)
float targetVelocity = sim.getJointTargetVelocity(int objectHandle)
int jointType = sim.getJointType(int objectHandle)
float velocity = sim.getJointVelocity(int jointHandle)
int state, float[3] zero, float[3] diffusePart, float[3] specular = sim.getLightParameters(int lightHandle)
int linkDummyHandle = sim.getLinkDummy(int dummyHandle)
float[12] matrix = sim.getMatrixInverse(float[12] matrix)
int navigationMode = sim.getNavigationMode()
int objectHandle = sim.getObject(string path, map options={})
string objectAlias = sim.getObjectAlias(int objectHandle, int options=-1)
string alias = sim.getObjectAliasRelative(int handle, int baseHandle, int options=-1)
int childObjectHandle = sim.getObjectChild(int objectHandle, int index)
float[7] pose = sim.getObjectChildPose(int objectHandle)
float[3] rgbData = sim.getObjectColor(int objectHandle, int index, int colorComponent)
sim.getObjectFromUid(int uid, map options={})
float[12] matrix = sim.getObjectMatrix(int objectHandle, int relativeToObjectHandle=sim.handle_world)
float[3] eulerAngles = sim.getObjectOrientation(int objectHandle, int relativeToObjectHandle=sim.handle_world)
int parentObjectHandle = sim.getObjectParent(int objectHandle)
float[7] pose = sim.getObjectPose(int objectHandle, int relativeToObjectHandle=sim.handle_world)
float[3] position = sim.getObjectPosition(int objectHandle, int relativeToObjectHandle=sim.handle_world)
float[4] quaternion = sim.getObjectQuaternion(int objectHandle, int relativeToObjectHandle=sim.handle_world)
int[] objectHandles = sim.getObjectSel()
float sizeFactor = sim.getObjectSizeFactor(int ObjectHandle)
int objectType = sim.getObjectType(int objectHandle)
int uid = sim.getObjectUid(int objectHandle)
float[3] linearVelocity, float[3] angularVelocity = sim.getObjectVelocity(int objectHandle)
int objectHandle = sim.getObjects(int index, int objectType)
int[] objects = sim.getObjectsInTree(int treeBaseHandle, int objectType=sim.handle_all, int options=0)
float[] voxels = sim.getOctreeVoxels(int octreeHandle)
int pageIndex = sim.getPage()
float[] config = sim.getPathInterpolatedConfig(float[] path, float[] pathLengths, float t, map method={type='linear', strength=1.0, forceOpen=false}, int[] types=nil)
float[] pathLengths, float totalLength = sim.getPathLengths(float[] path, int dof, func distCallback=nil)
float maxVoxelSize, int maxPtCntPerVoxel, int options, float pointSize = sim.getPointCloudOptions(int pointCloudHandle)
float[] points = sim.getPointCloudPoints(int pointCloudHandle)
float[7] pose = sim.getPoseInverse(float[7] pose)
float randomNumber = sim.getRandom(int seed=nil)
int[] referencedHandles = sim.getReferencedHandles(int objectHandle, string tag='')
int referencedHandle = sim.getReferencedHandle(int objectHandle, string tag='')
string[] tags = sim.getReferencedHandlesTags(int objectHandle)
float[3] axis, float angle = sim.getRotationAxis(float[12] matrixStart, float[12] matrixGoal)
float[3] axis, float angle = sim.getRotationAxis(float[7] poseStart, float[7] poseGoal)
buffer imageOut, int[2] effectiveResolutionOut = sim.getScaledImage(buffer imageIn, int[2] resolutionIn, int[2] desiredResolutionOut, int options)
int scriptHandle = sim.getScript(int scriptType, string scriptName='')
map wrapper = sim.getScriptFunctions(int scriptHandle)
float[3] size, float[7] pose = sim.getShapeBB(int shapeHandle)
int result, float[] rgbData = sim.getShapeColor(int shapeHandle, string colorName, int colorComponent)
int result, int pureType, float[4] dimensions = sim.getShapeGeomInfo(int shapeHandle)
float[9] inertiaMatrix, float[12] comMatrix = sim.getShapeInertia(int shapeHandle)
float mass = sim.getShapeMass(int shapeHandle)
float[] vertices, int[] indices, float[] normals = sim.getShapeMesh(int shapeHandle)
int textureId = sim.getShapeTextureId(int shapeHandle)
map data = sim.getShapeViz(int shapeHandle, int itemIndex)
string signalName = sim.getSignalName(int signalIndex, int signalType)
int simulationState = sim.getSimulationState()
float simulationTime = sim.getSimulationTime()
float timeStep = sim.getSimulationTimeStep()
int messageID, int[4] auxiliaryData, int[1..*] auxiliaryData2 = sim.getSimulatorMessage()
string stacktraceback = sim.getStackTraceback(int scriptHandle=sim.handle_self)
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
int calledScripts = sim.handleSimulationScripts(int callType)
int result = sim.handleDynamics(float deltaTime)
int calledScripts = sim.handleEmbeddedScripts(int callType)
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
sim.initScript(int scriptHandle)
int result = sim.registerScriptFuncHook(string funcToHook, func userFunc, bool execBefore)
int totalVoxelCnt = sim.insertObjectIntoOctree(int octreeHandle, int objectHandle, int options, float[] color=nil, int tag=0)
int totalPointCnt = sim.insertObjectIntoPointCloud(int pointCloudHandle, int objectHandle, int options, float gridSize, float[] color=nil, float duplicateTolerance=nil)
int totalPointCnt = sim.insertPointsIntoPointCloud(int pointCloudHandle, int options, float[] points, float[] color=nil, float duplicateTolerance=nil)
int totalVoxelCnt = sim.insertVoxelsIntoOctree(int octreeHandle, int options, float[] points, float[] color=nil, int[] tag=nil)
float[12] resultMatrix = sim.interpolateMatrices(float[12] matrixIn1, float[12] matrixIn2, float interpolFactor)
float[7] resultPose = sim.interpolatePoses(float[7] poseIn1, float[7] poseIn2, float interpolFactor)
int totalPointCnt = sim.intersectPointsWithPointCloud(int pointCloudHandle, int options, float[] points, float tolerance)
int result = sim.isDeprecated(string funcOrConst)
bool enabled = sim.isDynamicallyEnabled(int objectHandle)
bool result = sim.isHandle(int objectHandle)
sim.launchExecutable(string filename, string parameters='', int showStatus=1)
buffer image, int[2] resolution = sim.loadImage(int options, string filename)
buffer image, int[2] resolution = sim.loadImage(int options, buffer serializedImage)
int objectHandle = sim.loadModel(string filename)
int objectHandle = sim.loadModel(buffer serializedModel)
sim.loadScene(string filename)
sim.loadScene(buffer serializedScene)
float[7] pose = sim.matrixToPose(float[12] matrix)
int handle = sim.moduleEntry(int handle, string label=nil, int state=-1)
map data = sim.moveToConfig(map params)
map motionObject = sim.moveToConfig_init(map params)
int res, map data = sim.moveToConfig_step(map motionObject)
sim.moveToConfig_cleanup(map motionObject)
map data = sim.moveToPose(map params)
map motionObject = sim.moveToPose_init(map params)
int res, map data = sim.moveToPose_step(map motionObject)
sim.moveToPose_cleanup(map motionObject)
float[12] resultMatrix = sim.multiplyMatrices(float[12] matrixIn1, float[12] matrixIn2)
float[7] resultPose = sim.multiplyPoses(float[7] poseIn1, float[7] poseIn2)
float[] resultVectors = sim.multiplyVector(float[12] matrix, float[] inVectors)
float[] resultVectors = sim.multiplyVector(float[7] pose, float[] inVectors)
buffer data = sim.packDoubleTable(float[] doubleNumbers, int startDoubleIndex=0, int doubleCount=0)
buffer data = sim.packFloatTable(float[] floatNumbers, int startFloatIndex=0, int floatCount=0)
buffer data = sim.packInt32Table(int[] int32Numbers, int startInt32Index=0, int int32Count=0)
buffer data = sim.packTable(any[] aTable, int scheme=0)
buffer data = sim.packTable(map aTable, int scheme=0)
buffer data = sim.packUInt16Table(int[] uint16Numbers, int startUint16Index=0, int uint16Count=0)
buffer data = sim.packUInt32Table(int[] uint32Numbers, int startUInt32Index=0, int uint32Count=0)
buffer data = sim.packUInt8Table(int[] uint8Numbers, int startUint8Index=0, int uint8count=0)
sim.pauseSimulation()
float[12] matrix = sim.poseToMatrix(float[7] pose)
sim.pushUserEvent(string event, int handle, int uid, map eventData, int options=0)
sim.quitSimulator()
int result, float[3] forceVector, float[3] torqueVector = sim.readForceSensor(int objectHandle)
int result, float distance, float[3] detectedPoint, int detectedObjectHandle, float[3] normalVector = sim.readProximitySensor(int sensorHandle)
buffer textureData = sim.readTexture(int textureId, int options, int posX=0, int posY=0, int sizeX=0, int sizeY=0)
int result, float[] auxPacket1, float[] auxPacket2 = sim.readVisionSensor(int sensorHandle)
int result = sim.refreshDialogs(int refreshDegree)
int result = sim.relocateShapeFrame(int shapeHandle, float[7] pose)
sim.removeDrawingObject(int drawingObjectHandle)
int objectCount = sim.removeModel(int objectHandle, bool delayedRemoval = false)
sim.removeObjects(int[1..*] objectHandles, bool delayedRemoval = false)
sim.removeParticleObject(int particleObjectHandle)
int totalPointCnt = sim.removePointsFromPointCloud(int pointCloudHandle, int options, float[] points, float tolerance)
sim.removeReferencedObjects(int objectHandle, string tag='')
int totalVoxelCnt = sim.removeVoxelsFromOctree(int octreeHandle, int options, float[] points)
float[] path = sim.resamplePath(float[] path, float[] pathLengths, int finalConfigCnt, map method={type='linear', strength=1.0, forceOpen=false}, int[] types=nil)
sim.resetDynamicObject(int objectHandle)
sim.resetGraph(int objectHandle)
sim.resetProximitySensor(int objectHandle)
sim.resetVisionSensor(int sensorHandle)
sim.restoreEntityColor(map[] originalColorData)
float[12] matrixOut = sim.rotateAroundAxis(float[12] matrixIn, float[3] axis, float[3] axisPos, float angle)
float[7] poseOut = sim.rotateAroundAxis(float[7] poseIn, float[3] axis, float[3] axisPos, float angle)
int handle = sim.ruckigPos(int dofs, float baseCycleTime, int flags, float[] currentPosVelAccel, float[] maxVelAccelJerk, int[] selection, float[] targetPosVel)
sim.ruckigRemove(int handle)
int result, float[] newPosVelAccel, float synchronizationTime = sim.ruckigStep(int handle, float cycleTime)
int handle = sim.ruckigVel(int dofs, float baseCycleTime, int flags, float[] currentPosVelAccel, float[] maxAccelJerk, int[] selection, float[] targetVel)
buffer serializedImage = sim.saveImage(buffer image, int[2] resolution, int options, string filename, int quality)
sim.saveModel(int modelBaseHandle, string filename)
buffer serializedModel = sim.saveModel(int modelBaseHandle)
sim.saveScene(string filename)
buffer serializedScene = sim.saveScene()
sim.scaleObject(int objectHandle, float xScale, float yScale, float zScale, int options=0)
sim.scaleObjects(int[1..*] objectHandles, float scalingFactor, bool scalePositionsToo)
int id = sim.scheduleExecution(func f, any[] args, float timePoint, bool simTime=false)
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
sim.setJointMode(int jointHandle, int jointMode, int options)
sim.setJointPosition(int objectHandle, float position)
sim.setJointTargetForce(int objectHandle, float forceOrTorque, bool signedValue=true)
sim.setJointTargetPosition(int objectHandle, float targetPosition, float[] motionParams={})
sim.setJointTargetVelocity(int objectHandle, float targetVelocity, float[] motionParams={})
sim.setLinkDummy(int dummyHandle, int linkDummyHandle)
string pluginName = sim.getPluginName(int index)
string info = sim.getPluginInfo(string pluginName, int infoType)
sim.setPluginInfo(string pluginName, int infoType, string info)
sim.setPluginInfo(string pluginName, int infoType, int info)
sim.setNavigationMode(int navigationMode)
sim.setObjectAlias(int objectHandle, string objectAlias)
sim.setObjectChildPose(int objectHandle, float[7] pose)
bool result = sim.setObjectColor(int objectHandle, int index, int colorComponent, float[3] rgbData)
sim.setObjectMatrix(int objectHandle, float[12] matrix, int relativeToObjectHandle = sim.handle_world)
sim.setObjectOrientation(int objectHandle, float[3] eulerAngles, int relativeToObjectHandle = sim.handle_world)
sim.setObjectParent(int objectHandle, int parentObjectHandle, bool keepInPlace=true)
sim.setObjectPose(int objectHandle, float[7] pose, int relativeToObjectHandle = sim.handle_world)
sim.setObjectPosition(int objectHandle, float[3] position, int relativeToObjectHandle = sim.handle_world)
sim.setObjectQuaternion(int objectHandle, float[4] quaternion, int relativeToObjectHandle = sim.handle_world)
sim.setObjectSel(int[] objectHandles)
sim.setPage(int pageIndex)
sim.setPointCloudOptions(int pointCloudHandle, float maxVoxelSize, int maxPtCntPerVoxel, int options, float pointSize)
sim.setReferencedHandles(int objectHandle, int[] referencedHandles, string tag='')
sim.setShapeBB(int shapeHandle, float[3] size)
sim.setShapeColor(int shapeHandle, string colorName, int colorComponent, float[3] rgbData)
sim.setShapeInertia(int shapeHandle, float[9] inertiaMatrix, float[12] comMatrix)
sim.setShapeMass(int shapeHandle, float mass)
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
sim.transformImage(buffer image, int[2] resolution, int options)
int[] simpleShapeHandles = sim.ungroupShape(int shapeHandle)
float[] doubleNumbers = sim.unpackDoubleTable(buffer data, int startDoubleIndex=0, int doubleCount=0, int additionalByteOffset=0)
float[] floatNumbers = sim.unpackFloatTable(buffer data, int startFloatIndex=0, int floatCount=0, int additionalByteOffset=0)
int[] int32Numbers = sim.unpackInt32Table(buffer data, int startInt32Index=0, int int32Count=0, int additionalByteOffset=0)
any aTable = sim.unpackTable(buffer buffer)
int[] uint16Numbers = sim.unpackUInt16Table(buffer data, int startUint16Index=0, int uint16Count=0, int additionalByteOffset=0)
int[] uint32Numbers = sim.unpackUInt32Table(buffer data, int startUint32Index=0, int uint32Count=0, int additionalByteOffset=0)
int[] uint8Numbers = sim.unpackUInt8Table(buffer data, int startUint8Index=0, int uint8count=0)
sim.visitTree(int rootHandle, func visitorFunc, map options={})
float timeLeft = sim.wait(float dt, bool simulationTime=true)
sim.writeTexture(int textureId, int options, buffer textureData, int posX=0, int posY=0, int sizeX=0, int sizeY=0, float interpol=0.0)
float alphaAngle, float betaAngle, float gammaAngle = sim.yawPitchRollToAlphaBetaGamma(float yawAngle, float pitchAngle, float rollAngle)
int ret = sim.testCB(int a, func cb, int b)
map savedData = sim.getShapeAppearance(int handle, map opts={})
int handle = sim.setShapeAppearance(int handle, map savedData, map opts={})
sim.setBoolProperty(int target, string pName, bool pValue, map options={})
bool pValue = sim.getBoolProperty(int target, string pName, map options={})
sim.setIntProperty(int target, string pName, int pValue, map options={})
int pValue = sim.getIntProperty(int target, string pName, map options={})
sim.setLongProperty(int target, string pName, int pValue, map options={})
int pValue = sim.getLongProperty(int target, string pName, map options={})
sim.setFloatProperty(int target, string pName, float pValue, map options={})
float pValue = sim.getFloatProperty(int target, string pName, map options={})
sim.setStringProperty(int target, string pName, string pValue, map options={})
string pValue = sim.getStringProperty(int target, string pName, map options={})
sim.setBufferProperty(int target, string pName, buffer pValue, map options={})
buffer pValue = sim.getBufferProperty(int target, string pName, map options={})
sim.setTableProperty(int target, string pName, map pValue, map options={})
map pValue = sim.getTableProperty(int target, string pName, map options={})
sim.setIntArray2Property(int target, string pName, int[2] pValue, map options={})
int[2] pValue = sim.getIntArray2Property(int target, string pName, map options={})
sim.setVector2Property(int target, string pName, float[2] pValue, map options={})
float[2] pValue = sim.getVector2Property(int target, string pName, map options={})
sim.setVector3Property(int target, string pName, float[3] pValue, map options={})
float[3] pValue = sim.getVector3Property(int target, string pName, map options={})
sim.setQuaternionProperty(int target, string pName, float[4] pValue, map options={})
float[4] pValue = sim.getQuaternionProperty(int target, string pName, map options={})
sim.setPoseProperty(int target, string pName, float[7] pValue, map options={})
float[7] pValue = sim.getPoseProperty(int target, string pName, map options={})
sim.setColorProperty(int target, string pName, float[3] pValue, map options={})
float[3] pValue = sim.getColorProperty(int target, string pName, map options={})
sim.setFloatArrayProperty(int target, string pName, float[] pValue, map options={})
float[] pValue = sim.getFloatArrayProperty(int target, string pName, map options={})
sim.setIntArrayProperty(int target, string pName, int[] pValue, map options={})
int[] pValue = sim.getIntArrayProperty(int target, string pName, map options={})
sim.removeProperty(int target, string pName, map options={})
string pName, string appartenance = sim.getPropertyName(int target, int index, map options={})
int pType, int pFlags, string description = sim.getPropertyInfo(int target, string pName, map options={})
sim.setEventFilters(map filters={})
any pValue = sim.getProperty(int target, string pName, map options={})
sim.setProperty(int target, string pName, any pValue, int pType=nil)
string pTypeStr = sim.getPropertyTypeString(int pType)
map values = sim.getProperties(int target, map opts={})
sim.setProperties(int target, map props)
map infos = sim.getPropertiesInfos(int target, map opts={})
map object = sim.Object(int handle)
map object = sim.Object(string path)

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
sim.propertytype_color
sim.propertytype_floatarray
sim.propertytype_intarray
sim.propertytype_table
sim.propertyinfo_notwritable
sim.propertyinfo_notreadable
sim.propertyinfo_removable
sim.propertyinfo_largedata

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
sim.simulation_advancing_abouttostop
sim.simulation_advancing_firstafterpause
sim.simulation_advancing_firstafterstop
sim.simulation_advancing_lastbeforepause
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

-- When removing following, do not forget to add it to zmqRemoteApi/clients/cpp/sim-deprecated.* for backward compatibility!
local toDeprecateSoon = [[
sim.clearFloatSignal(string signalName)
sim.clearInt32Signal(string signalName)
sim.clearStringSignal(string signalName)
sim.clearBufferSignal(string signalName)
float[3] arrayOfValues = sim.getArrayParam(int parameter)
bool boolState = sim.getBoolParam(int parameter)
bool boolParam = sim.getEngineBoolParam(int paramId, int objectHandle)
float floatParam = sim.getEngineFloatParam(int paramId, int objectHandle)
int int32Param = sim.getEngineInt32Param(int paramId, int objectHandle)
float floatState = sim.getFloatParam(int parameter)
float signalValue = sim.getFloatSignal(string signalName)
int intState = sim.getInt32Param(int parameter)
int signalValue = sim.getInt32Signal(string signalName)
bool value = sim.getNamedBoolParam(string name)
float value = sim.getNamedFloatParam(string name)
int value = sim.getNamedInt32Param(string name)
buffer stringParam = sim.getNamedStringParam(string paramName)
float[] params = sim.getObjectFloatArrayParam(int objectHandle, int parameterID)
float parameter = sim.getObjectFloatParam(int objectHandle, int parameterID)
int parameter = sim.getObjectInt32Param(int objectHandle, int parameterID)
buffer parameter = sim.getObjectStringParam(int objectHandle, int parameterID)
bool value = sim.getSettingBool(string key)
float value = sim.getSettingFloat(string key)
int value = sim.getSettingInt32(string key)
string value = sim.getSettingString(string key)
string stringState = sim.getStringParam(int parameter)
string signalValue = sim.getStringSignal(string signalName)
buffer signalValue = sim.getBufferSignal(string signalName)
string data = sim.readCustomStringData(int objectHandle, string tagName)
buffer data = sim.readCustomBufferData(int objectHandle, string tagName)
map data = sim.readCustomTableData(int handle, string tagName, map options={})
string[] tags = sim.readCustomDataTags(int objectHandle)
sim.setArrayParam(int parameter, float[3] arrayOfValues)
sim.setBoolParam(int parameter, bool boolState)
sim.setEngineBoolParam(int paramId, int objectHandle, bool boolParam)
sim.setEngineFloatParam(int paramId, int objectHandle, float floatParam)
sim.setEngineInt32Param(int paramId, int objectHandle, int int32Param)
sim.setFloatParam(int parameter, float floatState)
sim.setFloatSignal(string signalName, float signalValue)
sim.setLightParameters(int lightHandle, int state, float[3] reserved, float[3] diffusePart, float[3] specularPart)
sim.setNamedBoolParam(string name, bool value)
sim.setNamedFloatParam(string name, float value)
sim.setNamedInt32Param(string name, int value)
sim.setNamedStringParam(string paramName, buffer stringParam)
sim.setObjectFloatArrayParam(int objectHandle, int parameterID, float[] params)
sim.setObjectFloatParam(int objectHandle, int parameterID, float parameter)
sim.setObjectInt32Param(int objectHandle, int parameterID, int parameter)
sim.setObjectStringParam(int objectHandle, int parameterID, buffer parameter)
sim.setStringParam(int parameter, string stringState)
sim.setStringSignal(string signalName, string signalValue)
sim.setBufferSignal(string signalName, buffer signalValue)
any sigVal = sim.waitForSignal(int target, string sigName)
sim.writeCustomStringData(int objectHandle, string tagName, string data)
sim.writeCustomBufferData(int objectHandle, string tagName, buffer data)
sim.writeCustomTableData(int handle, string tagName, map theTable, map options={})
sim.setObjectProperty(int objectHandle, int property)
sim.setObjectSpecialProperty(int objectHandle, int property)
int property = sim.getObjectProperty(int objectHandle)
int property = sim.getObjectSpecialProperty(int objectHandle)
int property = sim.getModelProperty(int objectHandle)
sim.setModelProperty(int objectHandle, int property)

sim.objectspecialproperty_collidable
sim.objectspecialproperty_detectable
sim.objectspecialproperty_measurable
sim.modelproperty_not_collidable
sim.modelproperty_not_detectable
sim.modelproperty_not_dynamic
sim.modelproperty_not_measurable
sim.modelproperty_not_model
sim.modelproperty_not_reset
sim.modelproperty_not_respondable
sim.modelproperty_not_showasinsidemodel
sim.modelproperty_not_visible
sim.modelproperty_scripts_inactive
sim.objectproperty_cannotdelete
sim.objectproperty_cannotdeleteduringsim
sim.objectproperty_collapsed
sim.objectproperty_depthinvisible
sim.objectproperty_dontshowasinsidemodel
sim.objectproperty_ignoreviewfitting
sim.objectproperty_selectable
sim.objectproperty_selectinvisible
sim.objectproperty_selectmodelbaseinstead
sim.objectproperty_hiddenforsimulation
sim.objfloatparam_abs_rot_velocity
sim.objfloatparam_abs_x_velocity
sim.objfloatparam_abs_y_velocity
sim.objfloatparam_abs_z_velocity
sim.objfloatparam_modelbbox_max_x
sim.objfloatparam_modelbbox_max_y
sim.objfloatparam_modelbbox_max_z
sim.objfloatparam_modelbbox_min_x
sim.objfloatparam_modelbbox_min_y
sim.objfloatparam_modelbbox_min_z
sim.objfloatparam_objbbox_max_x
sim.objfloatparam_objbbox_max_y
sim.objfloatparam_objbbox_max_z
sim.objfloatparam_objbbox_min_x
sim.objfloatparam_objbbox_min_y
sim.objfloatparam_objbbox_min_z
sim.objfloatparam_size_factor
sim.objfloatparam_transparency_offset
sim.objintparam_child_role
sim.objintparam_collection_self_collision_indicator
sim.objintparam_illumination_handle
sim.objintparam_manipulation_permissions
sim.objintparam_parent_role
sim.objintparam_unique_id
sim.objintparam_visibility_layer
sim.objintparam_hierarchycolor
sim.objintparam_visible
sim.objstringparam_dna
sim.objstringparam_unique_id
sim.ode_body_angulardamping
sim.ode_body_friction
sim.ode_body_lineardamping
sim.ode_body_maxcontacts
sim.ode_body_softcfm
sim.ode_body_softerp
sim.ode_global_bitcoded
sim.ode_global_cfm
sim.ode_global_computeinertias
sim.ode_global_constraintsolvingiterations
sim.ode_global_erp
sim.ode_global_fullinternalscaling
sim.ode_global_internalscalingfactor
sim.ode_global_quickstep
sim.ode_global_randomseed
sim.ode_joint_bounce
sim.ode_joint_fudgefactor
sim.ode_joint_normalcfm
sim.ode_joint_pospid1
sim.ode_joint_pospid2
sim.ode_joint_pospid3
sim.ode_joint_stopcfm
sim.ode_joint_stoperp
sim.proxintparam_entity_to_detect
sim.proxintparam_ray_invisibility
sim.proxintparam_volume_type
sim.scriptintparam_enabled
sim.scriptintparam_execcount
sim.scriptintparam_execorder
sim.scriptintparam_type
sim.scriptintparam_autorestartonerror
sim.scriptstringparam_description
sim.scriptstringparam_name
sim.scriptstringparam_nameext
sim.scriptstringparam_text
sim.shapefloatparam_edge_angle
sim.shapefloatparam_init_ang_velocity_x
sim.shapefloatparam_init_ang_velocity_y
sim.shapefloatparam_init_ang_velocity_z
sim.shapefloatparam_init_velocity_x
sim.shapefloatparam_init_velocity_y
sim.shapefloatparam_init_velocity_z
sim.shapefloatparam_mass
sim.shapefloatparam_shading_angle
sim.shapefloatparam_texture_a
sim.shapefloatparam_texture_b
sim.shapefloatparam_texture_g
sim.shapefloatparam_texture_scaling_x
sim.shapefloatparam_texture_scaling_y
sim.shapefloatparam_texture_x
sim.shapefloatparam_texture_y
sim.shapefloatparam_texture_z
sim.shapeintparam_component_cnt
sim.shapeintparam_compound
sim.shapeintparam_convex
sim.shapeintparam_convex_check
sim.shapeintparam_culling
sim.shapeintparam_edge_borders_hidden
sim.shapeintparam_edge_visibility
sim.shapeintparam_kinematic
sim.shapeintparam_respondable
sim.shapeintparam_respondable_mask
sim.shapeintparam_respondablesuspendcnt
sim.shapeintparam_sleepmodestart
sim.shapeintparam_static
sim.shapeintparam_wireframe
sim.shapestringparam_colorname
sim.stringparam_additionalpythonpath
sim.stringparam_addonpath
sim.stringparam_app_arg1
sim.stringparam_app_arg2
sim.stringparam_app_arg3
sim.stringparam_app_arg4
sim.stringparam_app_arg5
sim.stringparam_app_arg6
sim.stringparam_app_arg7
sim.stringparam_app_arg8
sim.stringparam_app_arg9
sim.stringparam_application_path
sim.stringparam_datadir
sim.stringparam_defaultpython
sim.stringparam_dlgverbosity
sim.stringparam_importexportdir
sim.stringparam_logfilter
sim.stringparam_luadir
sim.stringparam_machine_id
sim.stringparam_machine_id_legacy
sim.stringparam_modeldefaultdir
sim.stringparam_mujocodir
sim.stringparam_pythondir
sim.stringparam_remoteapi_temp_file_dir
sim.stringparam_resourcesdir
sim.stringparam_scene_name
sim.stringparam_scene_path
sim.stringparam_scene_path_and_name
sim.stringparam_scene_unique_id
sim.stringparam_scenedefaultdir
sim.stringparam_statusbarverbosity
sim.stringparam_systemdir
sim.stringparam_tempdir
sim.stringparam_tempscenedir
sim.stringparam_uniqueid
sim.stringparam_usersettingsdir
sim.stringparam_verbosity
sim.stringparam_video_filename
sim.stringparam_addondir
sim.stringparam_sandboxlang
sim.visionfarrayparam_viewfrustum
sim.visionfloatparam_far_clipping
sim.visionfloatparam_near_clipping
sim.visionfloatparam_ortho_size
sim.visionfloatparam_perspective_angle
sim.visionfloatparam_pov_aperture
sim.visionfloatparam_pov_blur_distance
sim.visionintparam_disabled_light_components
sim.visionintparam_entity_to_render
sim.visionintparam_perspective_operation
sim.visionintparam_pov_blur_sampled
sim.visionintparam_pov_focal_blur
sim.visionintparam_render_mode
sim.visionintparam_rendering_attributes
sim.visionintparam_resolution_x
sim.visionintparam_resolution_y
sim.visionintparam_windowed_pos_x
sim.visionintparam_windowed_pos_y
sim.visionintparam_windowed_size_x
sim.visionintparam_windowed_size_y
sim.visionintparam_depthignored
sim.visionintparam_rgbignored
sim.vortex_body_adhesiveforce
sim.vortex_body_angularvelocitydamping
sim.vortex_body_autoangulardamping
sim.vortex_body_autoangulardampingtensionratio
sim.vortex_body_autosleepangularaccelthreshold
sim.vortex_body_autosleepangularspeedthreshold
sim.vortex_body_autosleeplinearaccelthreshold
sim.vortex_body_autosleeplinearspeedthreshold
sim.vortex_body_autosleepsteplivethreshold
sim.vortex_body_autoslip
sim.vortex_body_bitcoded
sim.vortex_body_compliance
sim.vortex_body_convexshapesasrandom
sim.vortex_body_damping
sim.vortex_body_fastmoving
sim.vortex_body_linearvelocitydamping
sim.vortex_body_materialuniqueid
sim.vortex_body_normalangularaxisfriction
sim.vortex_body_normalangularaxisfrictionmodel
sim.vortex_body_normalangularaxisslide
sim.vortex_body_normalangularaxisslip
sim.vortex_body_normalangularaxisstaticfrictionscale
sim.vortex_body_normangaxissameasprimangaxis
sim.vortex_body_primangulararaxisfrictionmodel
sim.vortex_body_primangularaxisfriction
sim.vortex_body_primangularaxisslide
sim.vortex_body_primangularaxisslip
sim.vortex_body_primangularaxisstaticfrictionscale
sim.vortex_body_primaxisvectorx
sim.vortex_body_primaxisvectory
sim.vortex_body_primaxisvectorz
sim.vortex_body_primlinearaxisfriction
sim.vortex_body_primlinearaxisfrictionmodel
sim.vortex_body_primlinearaxisslide
sim.vortex_body_primlinearaxisslip
sim.vortex_body_primlinearaxisstaticfrictionscale
sim.vortex_body_pureshapesasconvex
sim.vortex_body_randomshapesasterrain
sim.vortex_body_restitution
sim.vortex_body_restitutionthreshold
sim.vortex_body_secangaxissameasprimangaxis
sim.vortex_body_secangularaxisfriction
sim.vortex_body_secangularaxisfrictionmodel
sim.vortex_body_secangularaxisslide
sim.vortex_body_secangularaxisslip
sim.vortex_body_secangularaxisstaticfrictionscale
sim.vortex_body_seclinaxissameasprimlinaxis
sim.vortex_body_seclinearaxisfriction
sim.vortex_body_seclinearaxisfrictionmodel
sim.vortex_body_seclinearaxisslide
sim.vortex_body_seclinearaxisslip
sim.vortex_body_seclinearaxisstaticfrictionscale
sim.vortex_body_skinthickness
sim.vortex_bodyfrictionmodel_box
sim.vortex_bodyfrictionmodel_neutral
sim.vortex_bodyfrictionmodel_none
sim.vortex_bodyfrictionmodel_prophigh
sim.vortex_bodyfrictionmodel_proplow
sim.vortex_bodyfrictionmodel_scaledbox
sim.vortex_bodyfrictionmodel_scaledboxfast
sim.vortex_global_autosleep
sim.vortex_global_bitcoded
sim.vortex_global_computeinertias
sim.vortex_global_constraintangularcompliance
sim.vortex_global_constraintangulardamping
sim.vortex_global_constraintangularkineticloss
sim.vortex_global_constraintlinearcompliance
sim.vortex_global_constraintlineardamping
sim.vortex_global_constraintlinearkineticloss
sim.vortex_global_contacttolerance
sim.vortex_global_internalscalingfactor
sim.vortex_global_multithreading
sim.vortex_joint_a0damping
sim.vortex_joint_a0frictioncoeff
sim.vortex_joint_a0frictionloss
sim.vortex_joint_a0frictionmaxforce
sim.vortex_joint_a0loss
sim.vortex_joint_a0stiffness
sim.vortex_joint_a1damping
sim.vortex_joint_a1frictioncoeff
sim.vortex_joint_a1frictionloss
sim.vortex_joint_a1frictionmaxforce
sim.vortex_joint_a1loss
sim.vortex_joint_a1stiffness
sim.vortex_joint_a2damping
sim.vortex_joint_a2frictioncoeff
sim.vortex_joint_a2frictionloss
sim.vortex_joint_a2frictionmaxforce
sim.vortex_joint_a2loss
sim.vortex_joint_a2stiffness
sim.vortex_joint_bitcoded
sim.vortex_joint_dependencyfactor
sim.vortex_joint_dependencyoffset
sim.vortex_joint_dependentobjectid
sim.vortex_joint_frictionenabledbc
sim.vortex_joint_frictionproportionalbc
sim.vortex_joint_lowerlimitdamping
sim.vortex_joint_lowerlimitmaxforce
sim.vortex_joint_lowerlimitrestitution
sim.vortex_joint_lowerlimitstiffness
sim.vortex_joint_motorconstraintfrictioncoeff
sim.vortex_joint_motorconstraintfrictionloss
sim.vortex_joint_motorconstraintfrictionmaxforce
sim.vortex_joint_motorfrictionenabled
sim.vortex_joint_objectid
sim.vortex_joint_p0damping
sim.vortex_joint_p0frictioncoeff
sim.vortex_joint_p0frictionloss
sim.vortex_joint_p0frictionmaxforce
sim.vortex_joint_p0loss
sim.vortex_joint_p0stiffness
sim.vortex_joint_p1damping
sim.vortex_joint_p1frictioncoeff
sim.vortex_joint_p1frictionloss
sim.vortex_joint_p1frictionmaxforce
sim.vortex_joint_p1loss
sim.vortex_joint_p1stiffness
sim.vortex_joint_p2damping
sim.vortex_joint_p2frictioncoeff
sim.vortex_joint_p2frictionloss
sim.vortex_joint_p2frictionmaxforce
sim.vortex_joint_p2loss
sim.vortex_joint_p2stiffness
sim.vortex_joint_pospid1
sim.vortex_joint_pospid2
sim.vortex_joint_pospid3
sim.vortex_joint_proportionalmotorfriction
sim.vortex_joint_relaxationenabledbc
sim.vortex_joint_upperlimitdamping
sim.vortex_joint_upperlimitmaxforce
sim.vortex_joint_upperlimitrestitution
sim.vortex_joint_upperlimitstiffness
sim.arrayparam_ambient_light
sim.arrayparam_background_color1
sim.arrayparam_background_color2
sim.arrayparam_fog
sim.arrayparam_fog_color
sim.arrayparam_gravity
sim.arrayparam_random_euler
sim.arrayparam_raydirection
sim.arrayparam_rayorigin
sim.boolparam_aux_clip_planes_enabled
sim.boolparam_browser_toolbarbutton_enabled
sim.boolparam_browser_visible
sim.boolparam_calcmodules_toolbarbutton_enabled
sim.boolparam_console_visible
sim.boolparam_display_enabled
sim.boolparam_dynamics_handling_enabled
sim.boolparam_exit_request
sim.boolparam_fog_enabled
sim.boolparam_force_calcstruct_all
sim.boolparam_force_calcstruct_all_visible
sim.boolparam_full_model_copy_from_api
sim.boolparam_fullscreen
sim.boolparam_headless
sim.boolparam_cansave
sim.boolparam_hierarchy_toolbarbutton_enabled
sim.boolparam_hierarchy_visible
sim.boolparam_infotext_visible
sim.boolparam_mirrors_enabled
sim.boolparam_objectrotate_toolbarbutton_enabled
sim.boolparam_objectshift_toolbarbutton_enabled
sim.boolparam_objproperties_toolbarbutton_enabled
sim.boolparam_pause_toolbarbutton_enabled
sim.boolparam_play_toolbarbutton_enabled
sim.boolparam_rayvalid
sim.boolparam_realtime_simulation
sim.boolparam_rosinterface_donotrunmainscript
sim.boolparam_scene_and_model_load_messages
sim.boolparam_scene_closing
sim.boolparam_shape_textures_are_visible
sim.boolparam_statustext_open
sim.boolparam_stop_toolbarbutton_enabled
sim.boolparam_use_glfinish_cmd
sim.boolparam_video_recording_triggered
sim.boolparam_waiting_for_trigger
sim.boolparam_execunsafe
sim.boolparam_execunsafeext
sim.camerafarrayparam_viewfrustum
sim.camerafloatparam_far_clipping
sim.camerafloatparam_near_clipping
sim.camerafloatparam_ortho_size
sim.camerafloatparam_perspective_angle
sim.camerafloatparam_pov_aperture
sim.camerafloatparam_pov_blur_distance
sim.cameraintparam_disabled_light_components
sim.cameraintparam_perspective_operation
sim.cameraintparam_pov_blur_samples
sim.cameraintparam_pov_focal_blur
sim.cameraintparam_remotecameramode
sim.cameraintparam_rendering_attributes
sim.cameraintparam_trackedobject
sim.octreefloatparam_voxelsize
sim.dummyfloatparam_size
sim.dummyintparam_dummytype
sim.dummystringparam_assemblytag
sim.dynmat_default
sim.dynmat_floor
sim.dynmat_foot
sim.dynmat_gripper
sim.dynmat_highfriction
sim.dynmat_lowfriction
sim.dynmat_nofriction
sim.dynmat_reststackgrasp
sim.dynmat_wheel
sim.filtercomponent_3x3filter
sim.filtercomponent_5x5filter
sim.filtercomponent_addbuffer1
sim.filtercomponent_addtobuffer1
sim.filtercomponent_binary
sim.filtercomponent_blobextraction
sim.filtercomponent_circularcut
sim.filtercomponent_colorsegmentation
sim.filtercomponent_correlationwithbuffer1
sim.filtercomponent_customized
sim.filtercomponent_edge
sim.filtercomponent_frombuffer1
sim.filtercomponent_frombuffer2
sim.filtercomponent_horizontalflip
sim.filtercomponent_imagetocoord
sim.filtercomponent_intensityscale
sim.filtercomponent_keeporremovecolors
sim.filtercomponent_multiplywithbuffer1
sim.filtercomponent_normalize
sim.filtercomponent_originaldepth
sim.filtercomponent_originalimage
sim.filtercomponent_pixelchange
sim.filtercomponent_rectangularcut
sim.filtercomponent_resize
sim.filtercomponent_rotate
sim.filtercomponent_scaleandoffsetcolors
sim.filtercomponent_sharpen
sim.filtercomponent_shift
sim.filtercomponent_subtractbuffer1
sim.filtercomponent_subtractfrombuffer1
sim.filtercomponent_swapbuffers
sim.filtercomponent_swapwithbuffer1
sim.filtercomponent_tobuffer1
sim.filtercomponent_tobuffer2
sim.filtercomponent_todepthoutput
sim.filtercomponent_tooutput
sim.filtercomponent_uniformimage
sim.filtercomponent_velodyne
sim.filtercomponent_verticalflip
sim.floatparam_dynamic_step_size
sim.floatparam_maxtrisizeabs
sim.floatparam_mintrisizerel
sim.floatparam_mouse_wheel_zoom_factor
sim.floatparam_physicstimestep
sim.floatparam_rand
sim.floatparam_simulation_time_step
sim.floatparam_stereo_distance
sim.forcefloatparam_error_a
sim.forcefloatparam_error_angle
sim.forcefloatparam_error_b
sim.forcefloatparam_error_g
sim.forcefloatparam_error_pos
sim.forcefloatparam_error_x
sim.forcefloatparam_error_y
sim.forcefloatparam_error_z
sim.graphintparam_needs_refresh
sim.intparam_compilation_version
sim.intparam_core_count
sim.intparam_current_page
sim.intparam_dlgverbosity
sim.intparam_dynamic_engine
sim.intparam_dynamic_iteration_count
sim.intparam_dynamic_step_divider
sim.intparam_dynamic_warning_disabled_mask
sim.intparam_notifydeprecated
sim.intparam_processid
sim.intparam_processcnt
sim.intparam_edit_mode_type
sim.intparam_error_report_mode
sim.intparam_exitcode
sim.intparam_flymode_camera_handle
sim.intparam_hierarchychangecounter
sim.intparam_idle_fps
sim.intparam_infotext_style
sim.intparam_motionplanning_seed
sim.intparam_mouse_buttons
sim.intparam_mouse_x
sim.intparam_mouse_y
sim.intparam_mouseclickcounterdown
sim.intparam_mouseclickcounterup
sim.intparam_objectcreationcounter
sim.intparam_objectdestructioncounter
sim.intparam_platform
sim.intparam_program_full_version
sim.intparam_program_revision
sim.intparam_program_version
sim.intparam_prox_sensor_select_down
sim.intparam_prox_sensor_select_up
sim.intparam_qt_version
sim.intparam_scene_index
sim.intparam_scene_unique_id
sim.intparam_server_port_next
sim.intparam_server_port_range
sim.intparam_server_port_start
sim.intparam_settings
sim.intparam_speedmodifier
sim.intparam_statusbarverbosity
sim.intparam_stop_request_counter
sim.intparam_verbosity
sim.intparam_videoencoderindex
sim.intparam_visible_layers
sim.intparam_work_thread_calc_time_ms
sim.intparam_work_thread_count
sim.jointfloatparam_error_a
sim.jointfloatparam_error_angle
sim.jointfloatparam_error_b
sim.jointfloatparam_error_g
sim.jointfloatparam_error_pos
sim.jointfloatparam_error_x
sim.jointfloatparam_error_y
sim.jointfloatparam_error_z
sim.jointfloatparam_intrinsic_qw
sim.jointfloatparam_intrinsic_qx
sim.jointfloatparam_intrinsic_qy
sim.jointfloatparam_intrinsic_qz
sim.jointfloatparam_intrinsic_x
sim.jointfloatparam_intrinsic_y
sim.jointfloatparam_intrinsic_z
sim.jointfloatparam_kc_c
sim.jointfloatparam_kc_k
sim.jointfloatparam_maxaccel
sim.jointfloatparam_maxjerk
sim.jointfloatparam_maxvel
sim.jointfloatparam_screwlead
sim.jointfloatparam_spherical_qw
sim.jointfloatparam_spherical_qx
sim.jointfloatparam_spherical_qy
sim.jointfloatparam_spherical_qz
sim.jointfloatparam_velocity
sim.jointfloatparam_vortex_dep_multiplication
sim.jointfloatparam_vortex_dep_offset
sim.jointintparam_ctrl_enabled
sim.jointintparam_dynctrlmode
sim.jointintparam_dynposctrltype
sim.jointintparam_dynvelctrltype
sim.jointintparam_motor_enabled
sim.jointintparam_velocity_lock
sim.jointintparam_vortex_dep_handle
sim.lightfloatparam_const_attenuation
sim.lightfloatparam_lin_attenuation
sim.lightfloatparam_quad_attenuation
sim.lightfloatparam_spot_cutoff
sim.lightfloatparam_spot_exponent
sim.lightintparam_pov_casts_shadows
sim.millintparam_volume_type
sim.mirrorfloatparam_height
sim.mirrorfloatparam_reflectance
sim.mirrorfloatparam_width
sim.mirrorintparam_enable
sim.mujoco_body_condim
sim.mujoco_body_friction1
sim.mujoco_body_friction2
sim.mujoco_body_friction3
sim.mujoco_body_margin
sim.mujoco_body_priority
sim.mujoco_body_solimp1
sim.mujoco_body_solimp2
sim.mujoco_body_solimp3
sim.mujoco_body_solimp4
sim.mujoco_body_solimp5
sim.mujoco_body_solmix
sim.mujoco_body_solref1
sim.mujoco_body_solref2
sim.mujoco_dummy_bitcoded
sim.mujoco_dummy_damping
sim.mujoco_dummy_limited
sim.mujoco_dummy_margin
sim.mujoco_dummy_proxyjointid
sim.mujoco_dummy_range1
sim.mujoco_dummy_range2
sim.mujoco_dummy_solimplimit1
sim.mujoco_dummy_solimplimit2
sim.mujoco_dummy_solimplimit3
sim.mujoco_dummy_solimplimit4
sim.mujoco_dummy_solimplimit5
sim.mujoco_dummy_solreflimit1
sim.mujoco_dummy_solreflimit2
sim.mujoco_dummy_springlength
sim.mujoco_dummy_stiffness
sim.mujoco_global_balanceinertias
sim.mujoco_global_bitcoded
sim.mujoco_global_boundinertia
sim.mujoco_global_boundmass
sim.mujoco_global_computeinertias
sim.mujoco_global_cone
sim.mujoco_global_density
sim.mujoco_global_impratio
sim.mujoco_global_integrator
sim.mujoco_global_iterations
sim.mujoco_global_kininertia
sim.mujoco_global_kinmass
sim.mujoco_global_multiccd
sim.mujoco_global_multithreaded
sim.mujoco_global_nconmax
sim.mujoco_global_njmax
sim.mujoco_global_nstack
sim.mujoco_global_overridecontacts
sim.mujoco_global_overridekin
sim.mujoco_global_overridemargin
sim.mujoco_global_overridesolimp1
sim.mujoco_global_overridesolimp2
sim.mujoco_global_overridesolimp3
sim.mujoco_global_overridesolimp4
sim.mujoco_global_overridesolimp5
sim.mujoco_global_overridesolref1
sim.mujoco_global_overridesolref2
sim.mujoco_global_rebuildtrigger
sim.mujoco_global_solver
sim.mujoco_global_viscosity
sim.mujoco_global_wind1
sim.mujoco_global_wind2
sim.mujoco_global_wind3
sim.mujoco_joint_armature
sim.mujoco_joint_damping
sim.mujoco_joint_dependentobjectid
sim.mujoco_joint_frictionloss
sim.mujoco_joint_margin
sim.mujoco_joint_polycoef1
sim.mujoco_joint_polycoef2
sim.mujoco_joint_polycoef3
sim.mujoco_joint_polycoef4
sim.mujoco_joint_polycoef5
sim.mujoco_joint_pospid1
sim.mujoco_joint_pospid2
sim.mujoco_joint_pospid3
sim.mujoco_joint_solimpfriction1
sim.mujoco_joint_solimpfriction2
sim.mujoco_joint_solimpfriction3
sim.mujoco_joint_solimpfriction4
sim.mujoco_joint_solimpfriction5
sim.mujoco_joint_solimplimit1
sim.mujoco_joint_solimplimit2
sim.mujoco_joint_solimplimit3
sim.mujoco_joint_solimplimit4
sim.mujoco_joint_solimplimit5
sim.mujoco_joint_solreffriction1
sim.mujoco_joint_solreffriction2
sim.mujoco_joint_solreflimit1
sim.mujoco_joint_solreflimit2
sim.mujoco_joint_springdamper1
sim.mujoco_joint_springdamper2
sim.mujoco_joint_springref
sim.mujoco_joint_stiffness
sim.newton_body_angulardrag
sim.newton_body_bitcoded
sim.newton_body_fastmoving
sim.newton_body_kineticfriction
sim.newton_body_lineardrag
sim.newton_body_restitution
sim.newton_body_staticfriction
sim.newton_global_bitcoded
sim.newton_global_computeinertias
sim.newton_global_constraintsolvingiterations
sim.newton_global_contactmergetolerance
sim.newton_global_exactsolver
sim.newton_global_highjointaccuracy
sim.newton_global_multithreading
sim.newton_joint_dependencyfactor
sim.newton_joint_dependencyoffset
sim.newton_joint_dependentobjectid
sim.newton_joint_objectid
sim.newton_joint_pospid1
sim.newton_joint_pospid2
sim.newton_joint_pospid3
]]

registerCodeEditorInfos("sim", codeEditorInfos .. toDeprecateSoon)
