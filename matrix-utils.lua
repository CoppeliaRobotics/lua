require 'matrix'

-- number bannerID=sim.addBanner(string label,number size,number options,table_6 positionAndEulerAngles=nil,number parentObjectHandle=nil,table_12 labelColors=nil,table_12 backgroundColors=nil)
sim.addBanner = wrap(sim.addBanner, function(origFunc)
    return function(label, size, options, positionAndEulerAngles, parentObjectHandle,
                    labelColors, backgroundColors)
        if getmetatable(positionAndEulerAngles) == Matrix then
            positionAndEulerAngles = positionAndEulerAngles:data()
        end
        if getmetatable(labelColors) == Matrix then labelColors = labelColors:data() end
        if getmetatable(backgroundColors) == Matrix then
            backgroundColors = backgroundColors:data()
        end
        return origFunc(
                   label, size, options, positionAndEulerAngles, parentObjectHandle,
                   labelColors, backgroundColors
               )
    end
end)

-- number drawingObjectHandle=sim.addDrawingObject(number objectType,number size,number duplicateTolerance,number parentObjectHandle,number maxItemCount,table_3 ambient_diffuse=nil,nil,table_3 specular=nil,table_3 emission=nil)
sim.addDrawingObject = wrap(sim.addDrawingObject, function(origFunc)
    return function(objectType, size, duplicateTolerance, parentObjectHandle, maxItemCount,
                    ambient_diffuse, _nil, specular, emission)
        if getmetatable(ambient_diffuse) == Matrix then
            ambient_diffuse = ambient_diffuse:data()
        end
        if getmetatable(specular) == Matrix then specular = specular:data() end
        if getmetatable(emission) == Matrix then emission = emission:data() end
        return origFunc(
                   objectType, size, duplicateTolerance, parentObjectHandle, maxItemCount,
                   ambient_diffuse, _nil, specular, emission
               )
    end
end)

-- sim.addForce(number shapeHandle,table_3 position,table_3 force)
sim.addForce = wrap(sim.addForce, function(origFunc)
    return function(shapeHandle, position, force)
        if getmetatable(position) == Matrix then position = position:data() end
        if getmetatable(force) == Matrix then force = force:data() end
        return origFunc(shapeHandle, position, force)
    end
end)

-- sim.addForceAndTorque(number shapeHandle,table_3 force,table_3 torque)
sim.addForceAndTorque = wrap(sim.addForceAndTorque, function(origFunc)
    return function(shapeHandle, force, torque)
        if getmetatable(force) == Matrix then force = force:data() end
        if getmetatable(torque) == Matrix then torque = torque:data() end
        return origFunc(shapeHandle, force, torque)
    end
end)

-- number ghostId=sim.addGhost(number ghostGroup,number objectHandle,number options,number startTime,number endTime,table_12 color=nil)
sim.addGhost = wrap(sim.addGhost, function(origFunc)
    return function(ghostGroup, objectHandle, options, startTime, endTime, color)
        if getmetatable(color) == Matrix then color = color:data() end
        return origFunc(ghostGroup, objectHandle, options, startTime, endTime, color)
    end
end)

-- number particleObjectHandle=sim.addParticleObject(number objectType,number size,number density,table parameters,number lifeTime,number maxItemCount,table_3 ambient_diffuse=nil,nil,table_3 specular=nil,table_3 emission=nil)
sim.addParticleObject = wrap(sim.addParticleObject, function(origFunc)
    return function(objectType, size, density, parameters, lifeTime, maxItemCount,
                    ambient_diffuse, _nil, specular, emission)
        if getmetatable(ambient_diffuse) == Matrix then
            ambient_diffuse = ambient_diffuse:data()
        end
        if getmetatable(specular) == Matrix then specular = specular:data() end
        if getmetatable(emission) == Matrix then emission = emission:data() end
        return origFunc(
                   objectType, size, density, parameters, lifeTime, maxItemCount,
                   ambient_diffuse, _nil, specular, emission
               )
    end
end)

-- number consoleHandle=sim.auxiliaryConsoleOpen(string title,number maxLines,number mode,table_2 position=nil,table_2 size=nil,table_3 textColor=nil,table_3 backgroundColor=nil)
sim.auxiliaryConsoleOpen = wrap(sim.auxiliaryConsoleOpen, function(origFunc)
    return function(title, maxLines, mode, position, size, textColor, backgroundColor)
        if getmetatable(position) == Matrix then position = position:data() end
        if getmetatable(size) == Matrix then size = size:data() end
        if getmetatable(textColor) == Matrix then textColor = textColor:data() end
        if getmetatable(backgroundColor) == Matrix then
            backgroundColor = backgroundColor:data()
        end
        return origFunc(title, maxLines, mode, position, size, textColor, backgroundColor)
    end
end)

-- table_12 matrix=sim.buildMatrix(table_3 position,table_3 eulerAngles)
sim.buildMatrix = wrap(sim.buildMatrix, function(origFunc)
    return function(position, eulerAngles)
        if getmetatable(position) == Matrix then position = position:data() end
        if getmetatable(eulerAngles) == Matrix then eulerAngles = eulerAngles:data() end
        return Matrix4x4(origFunc(position, eulerAngles))
    end
end)

-- table_12 matrix=sim.buildMatrixQ(table_3 position,table_4 quaternion)
sim.buildMatrixQ = wrap(sim.buildMatrixQ, function(origFunc)
    return function(position, quaternion)
        if getmetatable(position) == Matrix then position = position:data() end
        if getmetatable(quaternion) == Matrix then quaternion = quaternion:data() end
        return Matrix4x4(origFunc(position, quaternion))
    end
end)

-- number result,number distance,table_3 detectedPoint=sim.checkProximitySensor(number sensorHandle,number entityHandle)
sim.checkProximitySensor = wrap(sim.checkProximitySensor, function(origFunc)
    return function(sensorHandle, entityHandle)
        local result, distance, detectedPoint = origFunc(sensorHandle, entityHandle)
        detectedPoint = Vector(detectedPoint)
        return result, distance, detectedPoint
    end
end)

-- number result,number distance,table_3 detectedPoint,number detectedObjectHandle, table_3 surfaceNormalVector=sim.checkProximitySensorEx(number sensorHandle,number entityHandle,number detectionMode,number detectionthreshold,number maxAngle)
sim.checkProximitySensorEx = wrap(sim.checkProximitySensorEx, function(origFunc)
    return function(sensorHandle, entityHandle, detectionMode, detectionthreshold, maxAngle)
        local result, distance, detectedPoint, detectedObjectHandle, surfaceNormalVector = origFunc(
                                                                                               sensorHandle,
                                                                                               entityHandle,
                                                                                               detectionMode,
                                                                                               detectionthreshold,
                                                                                               maxAngle
                                                                                           )
        detectedPoint = Vector(detectedPoint)
        surfaceNormalVector = Vector(surfaceNormalVector)
        return result, distance, detectedPoint, detectedObjectHandle, surfaceNormalVector
    end
end)

-- number result,number distance,table_3 detectedPoint,table_3 normalVector=sim.checkProximitySensorEx2(number sensorHandle,table vertices,number itemType,number itemCount,number mode,number threshold,number maxAngle)
sim.checkProximitySensorEx2 = wrap(sim.checkProximitySensorEx2, function(origFunc)
    return function(sensorHandle, vertices, itemType, itemCount, mode, threshold, maxAngle)
        local result, distance, detectedPoint, normalVector = origFunc(
                                                                  sensorHandle, vertices,
                                                                  itemType, itemCount, mode,
                                                                  threshold, maxAngle
                                                              )
        detectedPoint = Vector(detectedPoint)
        normalVector = Vector(normalVector)
        return result, distance, detectedPoint, normalVector
    end
end)

-- number dummyHandle=sim.createDummy(number size,table_12 color=nil)
sim.createDummy = wrap(sim.createDummy, function(origFunc)
    return function(size, color)
        if getmetatable(color) == Matrix then color = color:data() end
        return origFunc(size, color)
    end
end)

-- number jointHandle=sim.createJoint(number jointType,number jointMode,number options,table_2 sizes=nil,table_12 colorA=nil,table_12 colorB=nil)
sim.createJoint = wrap(sim.createJoint, function(origFunc)
    return function(jointType, jointMode, options, sizes, colorA, colorB)
        if getmetatable(sizes) == Matrix then sizes = sizes:data() end
        if getmetatable(colorA) == Matrix then colorA = colorA:data() end
        if getmetatable(colorB) == Matrix then colorB = colorB:data() end
        return origFunc(jointType, jointMode, options, sizes, colorA, colorB)
    end
end)

-- number pathHandle=sim.createPath(number attributes,table_3 intParams=nil,table_3 floatParams=nil,table_12 color=nil)
sim.createPath = wrap(sim.createPath, function(origFunc)
    return function(attributes, intParams, floatParams, color)
        if getmetatable(color) == Matrix then color = color:data() end
        return origFunc(attributes, intParams, floatParams, color)
    end
end)

-- number objectHandle=sim.createPureShape(number primitiveType,number options,table_3 sizes,number mass,table_2 precision=nil)
sim.createPureShape = wrap(sim.createPureShape, function(origFunc)
    return function(primitiveType, options, sizes, mass, precision)
        if getmetatable(sizes) == Matrix then sizes = sizes:data() end
        if getmetatable(precision) == Matrix then precision = precision:data() end
        return origFunc(primitiveType, options, sizes, mass, precision)
    end
end)

-- number positionOnPath=sim.getClosestPositionOnPath(number pathHandle,table_3 relativePosition)
sim.getClosestPositionOnPath = wrap(sim.getClosestPositionOnPath, function(origFunc)
    return function(pathHandle, relativePosition)
        if getmetatable(relativePosition) == Matrix then
            relativePosition = relativePosition:data()
        end
        return origFunc(pathHandle, relativePosition)
    end
end)

-- table jointPositions=sim.getConfigForTipPose(number ikGroupHandle,table jointHandles,number distanceThreshold,number maxTimeInMs,table_4 metric=nil,table collisionPairs=nil,table jointOptions=nil,table lowLimits=nil,table ranges=nil)
sim.getConfigForTipPose = wrap(sim.getConfigForTipPose, function(origFunc)
    return function(ikGroupHandle, jointHandles, distanceThreshold, maxTimeInMs, metric,
                    collisionPairs, jointOptions, lowLimits, ranges)
        if getmetatable(metric) == Matrix then metric = metric:data() end
        if getmetatable(lowLimits) == Matrix then lowLimits = lowLimits:data() end
        if getmetatable(ranges) == Matrix then ranges = ranges:data() end
        local jointPositions = origFunc(
                                   ikGroupHandle, jointHandles, distanceThreshold, maxTimeInMs,
                                   metric, collisionPairs, jointOptions, lowLimits, ranges
                               )
        jointPositions = Vector(jointPositions)
        return jointPositions
    end
end)

-- table_2 collidingObjects,table_3 collisionPoint,table_3 reactionForce,table_3 normalVector=sim.getContactInfo(number dynamicPass,number objectHandle,number index)
sim.getContactInfo = wrap(sim.getContactInfo, function(origFunc)
    return function(dynamicPass, objectHandle, index)
        local collidingObjects, collisionPoint, reactionForce, normalVector = origFunc(
                                                                                  dynamicPass,
                                                                                  objectHandle,
                                                                                  index
                                                                              )
        collisionPoint = Vector(collisionPoint)
        reactionForce = Vector(reactionForce)
        normalVector = Vector(normalVector)
        return collidingObjects, collisionPoint, reactionForce, normalVector
    end
end)

-- number auxFlags,table_4 auxChannels=sim.getDataOnPath(number pathHandle,number relativeDistance)
sim.getDataOnPath = wrap(sim.getDataOnPath, function(origFunc)
    return function(pathHandle, relativeDistance)
        local auxFlags, auxChannels = origFunc(pathHandle, relativeDistance)
        auxChannels = Vector(auxChannels)
        return auxFlags, auxChannels
    end
end)

-- table_3 eulerAngles=sim.getEulerAnglesFromMatrix(table_12 matrix)
sim.getEulerAnglesFromMatrix = wrap(sim.getEulerAnglesFromMatrix, function(origFunc)
    return function(matrix)
        if getmetatable(matrix) == Matrix then matrix = matrix:data() end
        local eulerAngles = origFunc(matrix)
        eulerAngles = Vector(eulerAngles)
        return eulerAngles
    end
end)

-- table_12 matrix=sim.getJointMatrix(number objectHandle)
sim.getJointMatrix = wrap(sim.getJointMatrix, function(origFunc)
    return function(objectHandle)
        return Matrix4x4(origFunc(objectHandle))
    end
end)

-- number state,table_3 zero,table_3 diffusePart,table_3 specularPart=sim.getLightParameters(number objectHandle)
sim.getLightParameters = wrap(sim.getLightParameters, function(origFunc)
    return function(objectHandle)
        local state, zero, diffusePart, specularPart = origFunc(objectHandle)
        zero = Vector(zero)
        diffusePart = Vector(diffusePart)
        specularPart = Vector(specularPart)
        return state, zero, diffusePart, specularPart
    end
end)

-- table_7 pose=sim.getObjectPose(number objectHandle,number relativeToObjectHandle)
sim.getObjectPose = wrap(sim.getObjectPose, function(origFunc)
    return function(objectHandle, relativeToObjectHandle)
        local args = {objectHandle, relativeToObjectHandle}
        return Vector(origFunc(table.unpack(args)))
    end
end)

-- table_12 matrix=sim.getObjectMatrix(number objectHandle,number relativeToObjectHandle)
sim.getObjectMatrix = wrap(sim.getObjectMatrix, function(origFunc)
    return function(objectHandle, relativeToObjectHandle)
        local args = {objectHandle, relativeToObjectHandle}
        return Matrix4x4(origFunc(table.unpack(args)))
    end
end)

-- table_3 eulerAngles=sim.getObjectOrientation(number objectHandle,number relativeToObjectHandle)
sim.getObjectOrientation = wrap(sim.getObjectOrientation, function(origFunc)
    return function(objectHandle, relativeToObjectHandle)
        local args = {objectHandle, relativeToObjectHandle}
        return Vector(origFunc(table.unpack(args)))
    end
end)

-- table_3 position=sim.getObjectPosition(number objectHandle,number relativeToObjectHandle)
sim.getObjectPosition = wrap(sim.getObjectPosition, function(origFunc)
    return function(objectHandle, relativeToObjectHandle)
        local args = {objectHandle, relativeToObjectHandle}
        return Vector(origFunc(table.unpack(args)))
    end
end)

-- table_4 quaternion=sim.getObjectQuaternion(number objectHandle,number relativeToObjectHandle)
sim.getObjectQuaternion = wrap(sim.getObjectQuaternion, function(origFunc)
    return function(objectHandle, relativeToObjectHandle)
        local args = {objectHandle, relativeToObjectHandle}
        return Vector(origFunc(table.unpack(args)))
    end
end)

-- table_3 sizeValues=sim.getObjectSizeValues(number objectHandle)
sim.getObjectSizeValues = wrap(sim.getObjectSizeValues, function(origFunc)
    return function(objectHandle)
        return Vector(origFunc(objectHandle))
    end
end)

-- table_3 linearVelocity,table_3 angularVelocity=sim.getObjectVelocity(number shapeHandle)
sim.getObjectVelocity = wrap(sim.getObjectVelocity, function(origFunc)
    return function(shapeHandle)
        return Vector(origFunc(shapeHandle))
    end
end)

-- table_4 quaternion=sim.getQuaternionFromMatrix(table_12 matrix)
sim.getQuaternionFromMatrix = wrap(sim.getQuaternionFromMatrix, function(origFunc)
    return function(matrix)
        if getmetatable(matrix) == Matrix then matrix = matrix:data() end
        return Vector(origFunc(matrix))
    end
end)

-- table_3 axis,number angle=sim.getRotationAxis(table_12 matrixStart,table_12 matrixGoal)
sim.getRotationAxis = wrap(sim.getRotationAxis, function(origFunc)
    return function(matrixStart, matrixGoal)
        if getmetatable(matrixStart) == Matrix then matrixStart = matrixStart:data() end
        if getmetatable(matrixGoal) == Matrix then matrixGoal = matrixGoal:data() end
        local axis, angle = origFunc(matrixStart, matrixGoal)
        axis = Vector(axis)
        return axis, angle
    end
end)

-- number result,table_3 rgbData=sim.getShapeColor(number shapeHandle,string colorName,number colorComponent)
sim.getShapeColor = wrap(sim.getShapeColor, function(origFunc)
    return function(shapeHandle, colorName, colorComponent)
        local result, rgbData = origFunc(shapeHandle, colorName, colorComponent)
        rgbData = Vector(rgbData)
        return result, rgbData
    end
end)

-- number result,number pureType,table_4 dimensions=sim.getShapeGeomInfo(number shapeHandle)
sim.getShapeGeomInfo = wrap(sim.getShapeGeomInfo, function(origFunc)
    return function(shapeHandle)
        local result, pureType, dimensions = origFunc(shapeHandle)
        dimensions = Vector(dimensions)
        return result, pureType, dimensions
    end
end)

-- number mass,table_9 inertiaMatrix,table_3 centerOfMass=sim.getShapeMassAndInertia(number shapeHandle,table_12 transformation=nil)
sim.getShapeMassAndInertia = wrap(sim.getShapeMassAndInertia, function(origFunc)
    return function(shapeHandle, transformation)
        if getmetatable(transformation) == Matrix then
            transformation = transformation:data()
        end
        local mass, inertiaMatrix, centerOfMass = origFunc(shapeHandle, transformation)
        inertiaMatrix = Matrix(3, 3, inertiaMatrix)
        centerOfMass = Vector(centerOfMass)
        return mass, inertiaMatrix, centerOfMass
    end
end)

-- table_3 linearVelocity,table_3 angularVelocity=sim.getVelocity(number shapeHandle)
sim.getVelocity = wrap(sim.getVelocity, function(origFunc)
    return function(shapeHandle)
        local linearVelocity, angularVelocity = origFunc(shapeHandle)
        linearVelocity = Vector(linearVelocity)
        angularVelocity = Vector(angularVelocity)
        return linearVelocity, angularVelocity
    end
end)

-- number result,number distance,table_3 detectedPoint,number detectedObjectHandle,table_3 detectedSurfaceNormalVector=sim.handleProximitySensor(number sensorHandle)
sim.handleProximitySensor = wrap(sim.handleProximitySensor, function(origFunc)
    return function(sensorHandle)
        local result, distance, detectedPoint, detectedObjectHandle, detectedSurfaceNormalVector = origFunc(
                                                                                                       sensorHandle
                                                                                                   )
        detectedPoint = Vector(detectedPoint)
        detectedSurfaceNormalVector = Vector(detectedSurfaceNormalVector)
        return result, distance, detectedPoint, detectedObjectHandle,
               detectedSurfaceNormalVector
    end
end)

-- table_12 resultMatrix=sim.interpolateMatrices(table_12 matrixIn1,table_12 matrixIn2,number interpolFactor)
sim.interpolateMatrices = wrap(sim.interpolateMatrices, function(origFunc)
    return function(matrixIn1, matrixIn2, interpolFactor)
        if getmetatable(matrixIn1) == Matrix then matrixIn1 = matrixIn1:data() end
        if getmetatable(matrixIn2) == Matrix then matrixIn2 = matrixIn2:data() end
        return Matrix4x4(origFunc(matrixIn1, matrixIn2, interpolFactor))
    end
end)

-- number result, table_3 forceVector,table_3 torqueVector=sim.readForceSensor(number objectHandle)
sim.readForceSensor = wrap(sim.readForceSensor, function(origFunc)
    return function(objectHandle)
        local result, forceVector, torqueVector = origFunc(objectHandle)
        forceVector = Vector(forceVector)
        torqueVector = Vector(torqueVector)
        return result, forceVector, torqueVector
    end
end)

-- number result,number distance,table_3 detectedPoint,number detectedObjectHandle,table_3 detectedSurfaceNormalVector=sim.readProximitySensor(number sensorHandle)
sim.readProximitySensor = wrap(sim.readProximitySensor, function(origFunc)
    return function(sensorHandle)
        local result, distance, detectedPoint, detectedObjectHandle, detectedSurfaceNormalVector = origFunc(
                                                                                                       sensorHandle
                                                                                                   )
        detectedPoint = Vector(detectedPoint)
        detectedSurfaceNormalVector = Vector(detectedSurfaceNormalVector)
        return result, distance, detectedPoint, detectedObjectHandle,
               detectedSurfaceNormalVector
    end
end)

-- table_12 matrixOut=sim.rotateAroundAxis(table_12 matrixIn,table_3 axis,table_3 axisPos,number angle)
sim.rotateAroundAxis = wrap(sim.rotateAroundAxis, function(origFunc)
    return function(matrixIn, axis, axisPos, angle)
        if getmetatable(matrixIn) == Matrix then matrixIn = matrixIn:data() end
        if getmetatable(axis) == Matrix then axis = axis:data() end
        if getmetatable(axisPos) == Matrix then axisPos = axisPos:data() end
        return Matrix4x4(origFunc(matrixIn, axis, axisPos, angle))
    end
end)

-- sim.setLightParameters(number objectHandle,number state,nil,table_3 diffusePart,table_3 specularPart)
sim.setLightParameters = wrap(sim.setLightParameters, function(origFunc)
    return function(objectHandle, state, _nil, diffusePart, specularPart)
        if getmetatable(diffusePart) == Matrix then diffusePart = diffusePart:data() end
        if getmetatable(specularPart) == Matrix then
            specularPart = specularPart:data()
        end
        return origFunc(objectHandle, state, _nil, diffusePart, specularPart)
    end
end)

-- sim.setObjectPose(number objectHandle,table_7 pose,number relativeToObjectHandle)
sim.setObjectPose = wrap(sim.setObjectPose, function(origFunc)
    return function(objectHandle, pose, relativeToObjectHandle)
        if type(pose) == 'number' then
            -- old arg ordering (objectH,relObj,pose)
            local tmp = pose
            pose = relativeToObjectHandle
            relativeToObjectHandle = tmp
        end
        if getmetatable(pose) == Matrix then pose = pose:data() end
        local args = {objectHandle, pose, relativeToObjectHandle}
        return origFunc(table.unpack(args))
    end
end)

-- sim.setObjectMatrix(number objectHandle,table_12 matrix,number relativeToObjectHandle)
sim.setObjectMatrix = wrap(sim.setObjectMatrix, function(origFunc)
    return function(objectHandle, matrix, relativeToObjectHandle)
        if type(matrix) == 'number' then
            -- old arg ordering (objectH,relObj,matrix)
            local tmp = matrix
            matrix = relativeToObjectHandle
            relativeToObjectHandle = tmp
        end
        if getmetatable(matrix) == Matrix then matrix = matrix:data() end
        local args = {objectHandle, matrix, relativeToObjectHandle}
        return origFunc(table.unpack(args))
    end
end)

-- sim.setObjectOrientation(number objectHandle,table_3 eulerAngles,number relativeToObjectHandle)
sim.setObjectOrientation = wrap(sim.setObjectOrientation, function(origFunc)
    return function(objectHandle, eulerAngles, relativeToObjectHandle)
        if type(eulerAngles) == 'number' then
            -- old arg ordering (objectH,relObj,eulerAngles)
            local tmp = eulerAngles
            eulerAngles = relativeToObjectHandle
            relativeToObjectHandle = tmp
        end
        if getmetatable(eulerAngles) == Matrix then eulerAngles = eulerAngles:data() end
        local args = {objectHandle, eulerAngles, relativeToObjectHandle}
        return origFunc(table.unpack(args))
    end
end)

-- sim.setObjectPosition(number objectHandle,table_3 position,number relativeToObjectHandle)
sim.setObjectPosition = wrap(sim.setObjectPosition, function(origFunc)
    return function(objectHandle, position, relativeToObjectHandle)
        if type(position) == 'number' then
            -- old arg ordering (objectH,relObj,position)
            local tmp = position
            position = relativeToObjectHandle
            relativeToObjectHandle = tmp
        end
        if getmetatable(position) == Matrix then position = position:data() end
        local args = {objectHandle, position, relativeToObjectHandle}
        return origFunc(table.unpack(args))
    end
end)

-- sim.setObjectQuaternion(number objectHandle,table_4 quaternion,number relativeToObjectHandle)
sim.setObjectQuaternion = wrap(sim.setObjectQuaternion, function(origFunc)
    return function(objectHandle, quaternion, relativeToObjectHandle)
        if type(quaternion) == 'number' then
            -- old arg ordering (objectH,relObj,quaternion)
            local tmp = quaternion
            quaternion = relativeToObjectHandle
            relativeToObjectHandle = tmp
        end
        if getmetatable(quaternion) == Matrix then quaternion = quaternion:data() end
        local args = {objectHandle, quaternion, relativeToObjectHandle}
        return origFunc(table.unpack(args))
    end
end)

-- sim.setObjectSizeValues(number objectHandle,table_3 sizeValues)
sim.setObjectSizeValues = wrap(sim.setObjectSizeValues, function(origFunc)
    return function(objectHandle, sizeValues)
        if getmetatable(sizeValues) == Matrix then sizeValues = sizeValues:data() end
        return origFunc(objectHandle, sizeValues)
    end
end)

-- sim.setShapeColor(number shapeHandle,string colorName,number colorComponent,table_3 rgbData)
sim.setShapeColor = wrap(sim.setShapeColor, function(origFunc)
    return function(shapeHandle, colorName, colorComponent, rgbData)
        if getmetatable(rgbData) == Matrix then rgbData = rgbData:data() end
        return origFunc(shapeHandle, colorName, colorComponent, rgbData)
    end
end)

-- sim.setShapeMassAndInertia(number shapeHandle,number mass,table_9 inertiaMatrix,table_3 centerOfMass,table_12 transformation=nil)
sim.setShapeMassAndInertia = wrap(sim.setShapeMassAndInertia, function(origFunc)
    return function(shapeHandle, mass, inertiaMatrix, centerOfMass, transformation)
        if getmetatable(inertiaMatrix) == Matrix then
            inertiaMatrix = inertiaMatrix:data()
        end
        if getmetatable(centerOfMass) == Matrix then
            centerOfMass = centerOfMass:data()
        end
        if getmetatable(transformation) == Matrix then
            transformation = transformation:data()
        end
        return origFunc(shapeHandle, mass, inertiaMatrix, centerOfMass, transformation)
    end
end)

-- sim.setShapeTexture(number shapeHandle,number textureId,number mappingMode,number options,table_2 uvScaling,table_3 position=nil,table_3 orientation=nil)
sim.setShapeTexture = wrap(sim.setShapeTexture, function(origFunc)
    return function(shapeHandle, textureId, mappingMode, options, uvScaling, position,
                    orientation)
        if getmetatable(uvScaling) == Matrix then uvScaling = uvScaling:data() end
        if getmetatable(position) == Matrix then position = position:data() end
        if getmetatable(orientation) == Matrix then orientation = orientation:data() end
        return origFunc(
                   shapeHandle, textureId, mappingMode, options, uvScaling, position,
                   orientation
               )
    end
end)

-- sim.setSphericalJointMatrix(number objectHandle,table_12 matrix)
sim.setSphericalJointMatrix = wrap(sim.setSphericalJointMatrix, function(origFunc)
    return function(objectHandle, matrix)
        if getmetatable(matrix) == Matrix then matrix = matrix:data() end
        return origFunc(objectHandle, matrix)
    end
end)
