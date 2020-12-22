require 'matrix'

_S=_S or {}

function _S.wrapFunc(funcName,f)
    if not sim[funcName] then
        sim.addLog(sim.verbosity_warnings,'function "'..funcName..'" does not exist')
        return
    end
    _S[funcName]=sim[funcName]
    sim[funcName]=f
end

function _S.table12toMatrix4x4(t)
    return Matrix(3,4,t):vertcat(Matrix(1,4,{0,0,0,1}))
end

-- number bannerID=sim.addBanner(string label,number size,number options,table_6 positionAndEulerAngles=nil,number parentObjectHandle=nil,table_12 labelColors=nil,table_12 backgroundColors=nil)
_S.wrapFunc('addBanner',function(label,size,options,positionAndEulerAngles,parentObjectHandle,labelColors,backgroundColors)
    if getmetatable(positionAndEulerAngles)==Matrix then
        positionAndEulerAngles=positionAndEulerAngles:data()
    end
    if getmetatable(labelColors)==Matrix then
        labelColors=labelColors:data()
    end
    if getmetatable(backgroundColors)==Matrix then
        backgroundColors=backgroundColors:data()
    end
    return _S.addBanner(label,size,options,positionAndEulerAngles,parentObjectHandle,labelColors,backgroundColors)
end)

-- number drawingObjectHandle=sim.addDrawingObject(number objectType,number size,number duplicateTolerance,number parentObjectHandle,number maxItemCount,table_3 ambient_diffuse=nil,nil,table_3 specular=nil,table_3 emission=nil)
_S.wrapFunc('addDrawingObject',function(objectType,size,duplicateTolerance,parentObjectHandle,maxItemCount,ambient_diffuse,_nil,specular,emission)
    if getmetatable(ambient_diffuse)==Matrix then
        ambient_diffuse=ambient_diffuse:data()
    end
    if getmetatable(specular)==Matrix then
        specular=specular:data()
    end
    if getmetatable(emission)==Matrix then
        emission=emission:data()
    end
    return _S.addDrawingObject(objectType,size,duplicateTolerance,parentObjectHandle,maxItemCount,ambient_diffuse,_nil,specular,emission)
end)

-- sim.addForce(number shapeHandle,table_3 position,table_3 force)
_S.wrapFunc('addForce',function(shapeHandle,position,force)
    if getmetatable(position)==Matrix then
        position=position:data()
    end
    if getmetatable(force)==Matrix then
        force=force:data()
    end
    return _S.addForce(shapeHandle,position,force)
end)

-- sim.addForceAndTorque(number shapeHandle,table_3 force,table_3 torque)
_S.wrapFunc('addForceAndTorque',function(shapeHandle,force,torque)
    if getmetatable(force)==Matrix then
        force=force:data()
    end
    if getmetatable(torque)==Matrix then
        torque=torque:data()
    end
    return _S.addForceAndTorque(shapeHandle,force,torque)
end)

-- number ghostId=sim.addGhost(number ghostGroup,number objectHandle,number options,number startTime,number endTime,table_12 color=nil)
_S.wrapFunc('addGhost',function(ghostGroup,objectHandle,options,startTime,endTime,color)
    if getmetatable(color)==Matrix then
        color=color:data()
    end
    return _S.addGhost(ghostGroup,objectHandle,options,startTime,endTime,color)
end)

-- number particleObjectHandle=sim.addParticleObject(number objectType,number size,number density,table parameters,number lifeTime,number maxItemCount,table_3 ambient_diffuse=nil,nil,table_3 specular=nil,table_3 emission=nil)
_S.wrapFunc('addParticleObject',function(objectType,size,density,parameters,lifeTime,maxItemCount,ambient_diffuse,_nil,specular,emission)
    if getmetatable(ambient_diffuse)==Matrix then
        ambient_diffuse=ambient_diffuse:data()
    end
    if getmetatable(specular)==Matrix then
        specular=specular:data()
    end
    if getmetatable(emission)==Matrix then
        emission=emission:data()
    end
    return _S.addParticleObject(objectType,size,density,parameters,lifeTime,maxItemCount,ambient_diffuse,_nil,specular,emission)
end)

-- number consoleHandle=sim.auxiliaryConsoleOpen(string title,number maxLines,number mode,table_2 position=nil,table_2 size=nil,table_3 textColor=nil,table_3 backgroundColor=nil)
_S.wrapFunc('auxiliaryConsoleOpen',function(title,maxLines,mode,position,size,textColor,backgroundColor)
    if getmetatable(position)==Matrix then
        position=position:data()
    end
    if getmetatable(size)==Matrix then
        size=size:data()
    end
    if getmetatable(textColor)==Matrix then
        textColor=textColor:data()
    end
    if getmetatable(backgroundColor)==Matrix then
        backgroundColor=backgroundColor:data()
    end
    return _S.auxiliaryConsoleOpen(title,maxLines,mode,position,size,textColor,backgroundColor)
end)

-- table_12 matrix=sim.buildMatrix(table_3 position,table_3 eulerAngles)
_S.wrapFunc('buildMatrix',function(position,eulerAngles)
    if getmetatable(position)==Matrix then
        position=position:data()
    end
    if getmetatable(eulerAngles)==Matrix then
        eulerAngles=eulerAngles:data()
    end
    return _S.table12toMatrix4x4(_S.buildMatrix(position,eulerAngles))
end)

-- table_12 matrix=sim.buildMatrixQ(table_3 position,table_4 quaternion)
_S.wrapFunc('buildMatrixQ',function(position,quaternion)
    if getmetatable(position)==Matrix then
        position=position:data()
    end
    if getmetatable(quaternion)==Matrix then
        quaternion=quaternion:data()
    end
    return _S.table12toMatrix4x4(_S.buildMatrixQ(position,quaternion))
end)

-- number result,number distance,table_3 detectedPoint=sim.checkProximitySensor(number sensorHandle,number entityHandle)
_S.wrapFunc('checkProximitySensor',function(sensorHandle,entityHandle)
    local result,distance,detectedPoint=_S.checkProximitySensor(sensorHandle,entityHandle)
    detectedPoint=Vector(detectedPoint)
    return result,distance,detectedPoint
end)

-- number result,number distance,table_3 detectedPoint,number detectedObjectHandle, table_3 surfaceNormalVector=sim.checkProximitySensorEx(number sensorHandle,number entityHandle,number detectionMode,number detectionthreshold,number maxAngle)
_S.wrapFunc('checkProximitySensorEx',function(sensorHandle,entityHandle,detectionMode,detectionthreshold,maxAngle)
    local result,distance,detectedPoint,detectedObjectHandle,surfaceNormalVector=_S.checkProximitySensorEx(sensorHandle,entityHandle,detectionMode,detectionthreshold,maxAngle)
    detectedPoint=Vector(detectedPoint)
    surfaceNormalVector=Vector(surfaceNormalVector)
    return result,distance,detectedPoint,detectedObjectHandle,surfaceNormalVector
end)

-- number result,number distance,table_3 detectedPoint,table_3 normalVector=sim.checkProximitySensorEx2(number sensorHandle,table vertices,number itemType,number itemCount,number mode,number threshold,number maxAngle)
_S.wrapFunc('checkProximitySensorEx2',function(sensorHandle,vertices,itemType,itemCount,mode,threshold,maxAngle)
    local result,distance,detectedPoint,normalVector=_S.checkProximitySensorEx2(sensorHandle,vertices,itemType,itemCount,mode,threshold,maxAngle)
    detectedPoint=Vector(detectedPoint)
    normalVector=Vector(normalVector)
    return result,distance,detectedPoint,normalVector
end)

-- number dummyHandle=sim.createDummy(number size,table_12 color=nil)
_S.wrapFunc('createDummy',function(size,color)
    if getmetatable(color)==Matrix then
        color=color:data()
    end
    return _S.createDummy(size,color)
end)

-- number jointHandle=sim.createJoint(number jointType,number jointMode,number options,table_2 sizes=nil,table_12 colorA=nil,table_12 colorB=nil)
_S.wrapFunc('createJoint',function(jointType,jointMode,options,sizes,colorA,colorB)
    if getmetatable(sizes)==Matrix then
        sizes=sizes:data()
    end
    if getmetatable(colorA)==Matrix then
        colorA=colorA:data()
    end
    if getmetatable(colorB)==Matrix then
        colorB=colorB:data()
    end
    return _S.createJoint(jointType,jointMode,options,sizes,colorA,colorB)
end)

-- number pathHandle=sim.createPath(number attributes,table_3 intParams=nil,table_3 floatParams=nil,table_12 color=nil)
_S.wrapFunc('createPath',function(attributes,intParams,floatParams,color)
    if getmetatable(color)==Matrix then
        color=color:data()
    end
    return _S.createPath(attributes,intParams,floatParams,color)
end)

-- number objectHandle=sim.createPureShape(number primitiveType,number options,table_3 sizes,number mass,table_2 precision=nil)
_S.wrapFunc('createPureShape',function(primitiveType,options,sizes,mass,precision)
    if getmetatable(sizes)==Matrix then
        sizes=sizes:data()
    end
    if getmetatable(precision)==Matrix then
        precision=precision:data()
    end
    return _S.createPureShape(primitiveType,options,sizes,mass,precision)
end)

-- number positionOnPath=sim.getClosestPositionOnPath(number pathHandle,table_3 relativePosition)
_S.wrapFunc('getClosestPositionOnPath',function(pathHandle,relativePosition)
    if getmetatable(relativePosition)==Matrix then
        relativePosition=relativePosition:data()
    end
    return _S.getClosestPositionOnPath(pathHandle,relativePosition)
end)

-- table jointPositions=sim.getConfigForTipPose(number ikGroupHandle,table jointHandles,number distanceThreshold,number maxTimeInMs,table_4 metric=nil,table collisionPairs=nil,table jointOptions=nil,table lowLimits=nil,table ranges=nil)
_S.wrapFunc('getConfigForTipPose',function(ikGroupHandle,jointHandles,distanceThreshold,maxTimeInMs,metric,collisionPairs,jointOptions,lowLimits,ranges)
    if getmetatable(metric)==Matrix then
        metric=metric:data()
    end
    if getmetatable(lowLimits)==Matrix then
        lowLimits=lowLimits:data()
    end
    if getmetatable(ranges)==Matrix then
        ranges=ranges:data()
    end
    local jointPositions=_S.getConfigForTipPose(ikGroupHandle,jointHandles,distanceThreshold,maxTimeInMs,metric,collisionPairs,jointOptions,lowLimits,ranges)
    jointPositions=Vector(jointPositions)
    return jointPositions
end)

-- table_2 collidingObjects,table_3 collisionPoint,table_3 reactionForce,table_3 normalVector=sim.getContactInfo(number dynamicPass,number objectHandle,number index)
_S.wrapFunc('getContactInfo',function(dynamicPass,objectHandle,index)
    local collidingObjects,collisionPoint,reactionForce,normalVector=_S.getContactInfo(dynamicPass,objectHandle,index)
    collisionPoint=Vector(collisionPoint)
    reactionForce=Vector(reactionForce)
    normalVector=Vector(normalVector)
    return collidingObjects,collisionPoint,reactionForce,normalVector
end)

-- number auxFlags,table_4 auxChannels=sim.getDataOnPath(number pathHandle,number relativeDistance)
_S.wrapFunc('getDataOnPath',function(pathHandle,relativeDistance)
    local auxFlags,auxChannels=_S.getDataOnPath(pathHandle,relativeDistance)
    auxChannels=Vector(auxChannels)
    return auxFlags,auxChannels
end)

-- table_3 eulerAngles=sim.getEulerAnglesFromMatrix(table_12 matrix)
_S.wrapFunc('getEulerAnglesFromMatrix',function(matrix)
    if getmetatable(matrix)==Matrix then
        matrix=matrix:data()
    end
    local eulerAngles=_S.getEulerAnglesFromMatrix(matrix)
    eulerAngles=Vector(eulerAngles)
    return eulerAngles
end)

-- table_12 matrix=sim.getJointMatrix(number objectHandle)
_S.wrapFunc('getJointMatrix',function(objectHandle)
    return _S.table12toMatrix4x4(_S.getJointMatrix(objectHandle))
end)

-- number state,table_3 zero,table_3 diffusePart,table_3 specularPart=sim.getLightParameters(number objectHandle)
_S.wrapFunc('getLightParameters',function(objectHandle)
    local state,zero,diffusePart,specularPart=_S.getLightParameters(objectHandle)
    zero=Vector(zero)
    diffusePart=Vector(diffusePart)
    specularPart=Vector(specularPart)
    return state,zero,diffusePart,specularPart
end)

-- table_12 matrix=sim.getObjectMatrix(number objectHandle,number relativeToObjectHandle)
_S.wrapFunc('getObjectMatrix',function(objectHandle,relativeToObjectHandle)
    return _S.table12toMatrix4x4(_S.getObjectMatrix(objectHandle,relativeToObjectHandle))
end)

-- table_3 eulerAngles=sim.getObjectOrientation(number objectHandle,number relativeToObjectHandle)
_S.wrapFunc('getObjectOrientation',function(objectHandle,relativeToObjectHandle)
    return Vector(_S.getObjectOrientation(objectHandle,relativeToObjectHandle))
end)

-- table_3 position=sim.getObjectPosition(number objectHandle,number relativeToObjectHandle)
_S.wrapFunc('getObjectPosition',function(objectHandle,relativeToObjectHandle)
    return Vector(_S.getObjectPosition(objectHandle,relativeToObjectHandle))
end)

-- table_4 quaternion=sim.getObjectQuaternion(number objectHandle,number relativeToObjectHandle)
_S.wrapFunc('getObjectQuaternion',function(objectHandle,relativeToObjectHandle)
    return Vector(_S.getObjectQuaternion(objectHandle,relativeToObjectHandle))
end)

-- table_3 sizeValues=sim.getObjectSizeValues(number objectHandle)
_S.wrapFunc('getObjectSizeValues',function(objectHandle)
    return Vector(_S.getObjectSizeValues(objectHandle))
end)

-- table_3 linearVelocity,table_3 angularVelocity=sim.getObjectVelocity(number shapeHandle)
_S.wrapFunc('getObjectVelocity',function(shapeHandle)
    return Vector(_S.getObjectVelocity(shapeHandle))
end)

-- table_3 eulerAngles=sim.getOrientationOnPath (number pathHandle,number relativeDistance)
_S.wrapFunc('getOrientationOnPath ',function(pathHandle,relativeDistance)
    return Vector(_S.getOrientationOnPath(pathHandle,relativeDistance))
end)

-- table_3 position=sim.getPositionOnPath (number pathHandle,number relativeDistance)
_S.wrapFunc('getPositionOnPath ',function(pathHandle,relativeDistance)
    return Vector(_S.getPositionOnPath(pathHandle,relativeDistance))
end)

-- table_4 quaternion=sim.getQuaternionFromMatrix(table_12 matrix)
_S.wrapFunc('getQuaternionFromMatrix',function(matrix)
    if getmetatable(matrix)==Matrix then
        matrix=matrix:data()
    end
    return Vector(_S.getQuaternionFromMatrix(matrix))
end)

-- table_3 axis,number angle=sim.getRotationAxis(table_12 matrixStart,table_12 matrixGoal)
_S.wrapFunc('getRotationAxis',function(matrixStart,matrixGoal)
    if getmetatable(matrixStart)==Matrix then
        matrixStart=matrixStart:data()
    end
    if getmetatable(matrixGoal)==Matrix then
        matrixGoal=matrixGoal:data()
    end
    local axis,angle=_S.getRotationAxis(matrixStart,matrixGoal)
    axis=Vector(axis)
    return axis,angle
end)

-- number result,table_3 rgbData=sim.getShapeColor(number shapeHandle,string colorName,number colorComponent)
_S.wrapFunc('getShapeColor',function(shapeHandle,colorName,colorComponent)
    local result,rgbData=_S.getShapeColor(shapeHandle,colorName,colorComponent)
    rgbData=Vector(rgbData)
    return result,rgbData
end)

-- number result,number pureType,table_4 dimensions=sim.getShapeGeomInfo(number shapeHandle)
_S.wrapFunc('getShapeGeomInfo',function(shapeHandle)
    local result,pureType,dimensions=_S.getShapeGeomInfo(shapeHandle)
    dimensions=Vector(dimensions)
    return result,pureType,dimensions
end)

-- number mass,table_9 inertiaMatrix,table_3 centerOfMass=sim.getShapeMassAndInertia(number shapeHandle,table_12 transformation=nil)
_S.wrapFunc('getShapeMassAndInertia',function(shapeHandle,transformation)
    if getmetatable(transformation)==Matrix then
        transformation=transformation:data()
    end
    local mass,inertiaMatrix,centerOfMass=_S.getShapeMassAndInertia(shapeHandle,transformation)
    inertiaMatrix=Matrix(3,3,inertiaMatrix)
    centerOfMass=Vector(centerOfMass)
    return mass,inertiaMatrix,centerOfMass
end)

-- table_3 linearVelocity,table_3 angularVelocity=sim.getVelocity(number shapeHandle)
_S.wrapFunc('getVelocity',function(shapeHandle)
    local linearVelocity,angularVelocity=_S.getVelocity(shapeHandle)
    linearVelocity=Vector(linearVelocity)
    angularVelocity=Vector(angularVelocity)
    return linearVelocity,angularVelocity
end)

-- number result,number distance,table_3 detectedPoint,number detectedObjectHandle,table_3 detectedSurfaceNormalVector=sim.handleProximitySensor(number sensorHandle)
_S.wrapFunc('handleProximitySensor',function(sensorHandle)
    local result,distance,detectedPoint,detectedObjectHandle,detectedSurfaceNormalVector=_S.handleProximitySensor(sensorHandle)
    detectedPoint=Vector(detectedPoint)
    detectedSurfaceNormalVector=Vector(detectedSurfaceNormalVector)
    return result,distance,detectedPoint,detectedObjectHandle,detectedSurfaceNormalVector
end)

-- table_12 resultMatrix=sim.interpolateMatrices(table_12 matrixIn1,table_12 matrixIn2,number interpolFactor)
_S.wrapFunc('interpolateMatrices',function(matrixIn1,matrixIn2,interpolFactor)
    if getmetatable(matrixIn1)==Matrix then
        matrixIn1=matrixIn1:data()
    end
    if getmetatable(matrixIn2)==Matrix then
        matrixIn2=matrixIn2:data()
    end
    return _S.table12toMatrix4x4(_S.interpolateMatrices(matrixIn1,matrixIn2,interpolFactor))
end)

-- number result, table_3 forceVector,table_3 torqueVector=sim.readForceSensor(number objectHandle)
_S.wrapFunc('readForceSensor',function(objectHandle)
    local result,forceVector,torqueVector=_S.readForceSensor(objectHandle)
    forceVector=Vector(forceVector)
    torqueVector=Vector(torqueVector)
    return result,forceVector,torqueVector
end)

-- number result,number distance,table_3 detectedPoint,number detectedObjectHandle,table_3 detectedSurfaceNormalVector=sim.readProximitySensor(number sensorHandle)
_S.wrapFunc('readProximitySensor',function(sensorHandle)
    local result,distance,detectedPoint,detectedObjectHandle,detectedSurfaceNormalVector=_S.readProximitySensor(sensorHandle)
    detectedPoint=Vector(detectedPoint)
    detectedSurfaceNormalVector=Vector(detectedSurfaceNormalVector)
    return result,distance,detectedPoint,detectedObjectHandle,detectedSurfaceNormalVector
end)

-- table_12 matrixOut=sim.rotateAroundAxis(table_12 matrixIn,table_3 axis,table_3 axisPos,number angle)
_S.wrapFunc('rotateAroundAxis',function(matrixIn,axis,axisPos,angle)
    if getmetatable(matrixIn)==Matrix then
        matrixIn=matrixIn:data()
    end
    if getmetatable(axis)==Matrix then
        axis=axis:data()
    end
    if getmetatable(axisPos)==Matrix then
        axisPos=axisPos:data()
    end
    return _S.table12toMatrix4x4(_S.rotateAroundAxis(matrixIn,axis,axisPos,angle))
end)

-- sim.setLightParameters(number objectHandle,number state,nil,table_3 diffusePart,table_3 specularPart)
_S.wrapFunc('setLightParameters',function(objectHandle,state,_nil,diffusePart,specularPart)
    if getmetatable(diffusePart)==Matrix then
        diffusePart=diffusePart:data()
    end
    if getmetatable(specularPart)==Matrix then
        specularPart=specularPart:data()
    end
    return _S.setLightParameters(objectHandle,state,_nil,diffusePart,specularPart)
end)

-- sim.setObjectMatrix(number objectHandle,number relativeToObjectHandle,table_12 matrix)
_S.wrapFunc('setObjectMatrix',function(objectHandle,relativeToObjectHandle,matrix)
    if getmetatable(matrix)==Matrix then
        matrix=matrix:data()
    end
    return _S.setObjectMatrix(objectHandle,relativeToObjectHandle,matrix)
end)

-- sim.setObjectOrientation(number objectHandle,number relativeToObjectHandle,table_3 eulerAngles)
_S.wrapFunc('setObjectOrientation',function(objectHandle,relativeToObjectHandle,eulerAngles)
    if getmetatable(eulerAngles)==Matrix then
        eulerAngles=eulerAngles:data()
    end
    return _S.setObjectOrientation(objectHandle,relativeToObjectHandle,eulerAngles)
end)

-- sim.setObjectPosition(number objectHandle,number relativeToObjectHandle,table_3 position)
_S.wrapFunc('setObjectPosition',function(objectHandle,relativeToObjectHandle,position)
    if getmetatable(position)==Matrix then
        position=position:data()
    end
    return _S.setObjectPosition(objectHandle,relativeToObjectHandle,position)
end)

-- sim.setObjectQuaternion(number objectHandle,number relativeToObjectHandle,table_4 quaternion)
_S.wrapFunc('setObjectQuaternion',function(objectHandle,relativeToObjectHandle,quaternion)
    if getmetatable(quaternion)==Matrix then
        quaternion=quaternion:data()
    end
    return _S.setObjectQuaternion(objectHandle,relativeToObjectHandle,quaternion)
end)

-- sim.setObjectSizeValues(number objectHandle,table_3 sizeValues)
_S.wrapFunc('setObjectSizeValues',function(objectHandle,sizeValues)
    if getmetatable(sizeValues)==Matrix then
        sizeValues=sizeValues:data()
    end
    return _S.setObjectSizeValues(objectHandle,sizeValues)
end)

-- sim.setShapeColor(number shapeHandle,string colorName,number colorComponent,table_3 rgbData)
_S.wrapFunc('setShapeColor',function(shapeHandle,colorName,colorComponent,rgbData)
    if getmetatable(rgbData)==Matrix then
        rgbData=rgbData:data()
    end
    return _S.setShapeColor(shapeHandle,colorName,colorComponent,rgbData)
end)

-- sim.setShapeMassAndInertia(number shapeHandle,number mass,table_9 inertiaMatrix,table_3 centerOfMass,table_12 transformation=nil)
_S.wrapFunc('setShapeMassAndInertia',function(shapeHandle,mass,inertiaMatrix,centerOfMass,transformation)
    if getmetatable(inertiaMatrix)==Matrix then
        inertiaMatrix=inertiaMatrix:data()
    end
    if getmetatable(centerOfMass)==Matrix then
        centerOfMass=centerOfMass:data()
    end
    if getmetatable(transformation)==Matrix then
        transformation=transformation:data()
    end
    return _S.setShapeMassAndInertia(shapeHandle,mass,inertiaMatrix,centerOfMass,transformation)
end)

-- sim.setShapeTexture(number shapeHandle,number textureId,number mappingMode,number options,table_2 uvScaling,table_3 position=nil,table_3 orientation=nil)
_S.wrapFunc('setShapeTexture',function(shapeHandle,textureId,mappingMode,options,uvScaling,position,orientation)
    if getmetatable(uvScaling)==Matrix then
        uvScaling=uvScaling:data()
    end
    if getmetatable(position)==Matrix then
        position=position:data()
    end
    if getmetatable(orientation)==Matrix then
        orientation=orientation:data()
    end
    return _S.setShapeTexture(shapeHandle,textureId,mappingMode,options,uvScaling,position,orientation)
end)

-- sim.setSphericalJointMatrix(number objectHandle,table_12 matrix)
_S.wrapFunc('setSphericalJointMatrix',function(objectHandle,matrix)
    if getmetatable(matrix)==Matrix then
        matrix=matrix:data()
    end
    return _S.setSphericalJointMatrix(objectHandle,matrix)
end)
