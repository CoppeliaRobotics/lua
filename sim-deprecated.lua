local deprecated = {}

deprecated.functions = {
    {"addBanner", ""},
    {"addGhost", ""},
    {"addObjectToCollection", "addItemToCollection"},
    {"addObjectToSelection", "setObjectSel"},
    {"addStatusbarMessage", "addLog"},
    {"boolAnd32", "Lua's bitwise operators"},
    {"boolOr32", "Lua's bitwise operators"},
    {"boolXor32", "Lua's bitwise operators"},
    {"breakForceSensor", "setObjectParent"},
    {"buildMatrixQ", "poseToMatrix"},
    {"checkIkGroup", "the simIK functionality"},
    {"clearDoubleSignal", "clearFloatSignal"},
    {"clearIntegerSignal", "clearInt32Signal"},
    {"closeModule", ""},
    {"closeTextEditor", "textEditorClose"},
    {"computeJacobian", "the simIK functionality"},
    {"copyMatrix", "table.copy"},
    {"createIkElement", "the simIK functionality"},
    {"createIkGroup", "the simIK functionality"},
    {"createMeshShape", "createShape"},
    {"createPureShape", "createPrimitiveShape"},
    {"displayDialog", "the simUI functionality"},
    {"emptyCollection", "destroyCollection"},
    {"endDialog", "the simUI functionality"},
    {"exportIk", "the simIK functionality"},
    {"fileDialog", "the simUI functionality"},
    {"generateIkPath", "the simIK functionality"},
    {"getArrayParameter", "getArrayParam"},
    {"getBoolParameter", "getBoolParam"},
    {"getCollectionHandle", "createCollection"},
    {"getCollectionName", ""},
    {"getCollisionHandle", "checkCollision"},
    {"getConfigForTipPose", "the simIK functionality"},
    {"getConfigurationTree", ""},
    {"getCustomizationScriptAssociatedWithObject", "getObject"},
    {"getDialogInput", "the simUI functionality"},
    {"getDialogResult", "the simUI functionality"},
    {"getDistanceHandle", "checkDistance"},
    {"getDoubleSignal", "getFloatSignal"},
    {"getEngineBoolParameter", "getEngineBoolParam"},
    {"getEngineFloatParameter", "getEngineFloatParam"},
    {"getEngineInt32Parameter", "getEngineInt32Param"},
    {"getFloatParameter", "getFloatParam"},
    {"getIkGroupHandle", "the simIK functionality"},
    {"getIkGroupMatrix", "the simIK functionality"},
    {"getInt32Parameter", "getInt32Param"},
    {"getIntegerSignal", "getInt32Signal"},
    {"getJointMatrix", "getObjectChildPose"},
    {"getJointMaxForce", "getJointTargetForce"},
    {"getModuleInfo", "getPluginInfo"},
    {"getModuleName", "getPluginName"},
    {"getObjectAssociatedWithScript", "getObject"},
    {"getObjectConfiguration", ""},
    {"getObjectFloatParameter", "getObjectFloatParam"},
    {"getObjectHandle", "getObject"},
    {"getObjectName", "getObjectAlias"},
    {"getObjectSelection", "getObjectSel"},
    {"getObjectSizeValues", ""},
    {"getObjectStringParameter", "getObjectStringParam"},
    {"getObjectUniqueIdentifier", "getObjectUid"},
    {"getQuaternionFromMatrix", "matrixToPose"},
    {"getScriptAssociatedWithObject", "getObject"},
    {"getScriptAttribute", "getScriptInt32Param or getScriptStringParam"},
    {"getScriptHandle", "getObject"},
    {"getScriptName", "getScriptStringParam"},
    {"getShapeMassAndInertia", "sim.getShapeMass and/or sim.getShapeInertia"},
    {"getStringNamedParam", "getNamedStringParam"},
    {"getStringParameter", "getStringParam"},
    {"getSystemTimeInMs", "getSystemTime"},
    {"getThreadAutomaticSwitch", ""},
    {"getThreadExitRequest", "getSimulationStopping"},
    {"getThreadSwitchAllowed", ""},
    {"getThreadSwitchTiming", ""},
    {"getVisionSensorCharImage", "getVisionSensorImg"},
    {"getVisionSensorDepthBuffer", "getVisionSensorDepth"},
    {"getVisionSensorImage", "getVisionSensorImg"},
    {"getVisionSensorResolution", "getVisionSensorImg"},
    {"handleCollision", "checkCollision"},
    {"handleCustomizationScripts", "handleEmbeddedScripts"},
    {"handleDistance", "checkDistance"},
    {"handleIkGroup", "the simIK functionality"},
    {"handleModule", ""},
    {"isDeprecated", ""},
    {"isObjectInSelection", "getObjectSel"},
    {"loadModule", "loadPlugin"},
    {"modifyGhost", ""},
    {"msgBox", "the simUI functionality"},
    {"openModule", ""},
    {"readCollision", "checkCollision"},
    {"readCustomDataBlock", "readCustomStringData "},
    {"readCustomDataBlockTags", "readCustomDataTags"},
    {"readDistance", "checkDistance"},
    {"receiveData", ""},
    {"registerScriptFunction", ""},
    {"removeBanner", ""},
    {"removeCollection", "destroyCollection"},
    {"removeIkGroup", "the simIK functionality"},
    {"removeObject", "removeObjects"},
    {"removeObjectFromSelection", "setObjectSel"},
    {"reorientShapeBoundingBox", "sim.alignShapeBB and/or relocateShapeFrame"},
    {"resetCollision", "checkCollision"},
    {"resetDistance", "checkDistance"},
    {"rmlMoveToJointPositions", "moveToConfig"},
    {"rmlMoveToPosition", "moveToPose"},
    {"rmlPos", "ruckigPos"},
    {"rmlRemove", "ruckigRemove"},
    {"rmlStep", "ruckigStep"},
    {"rmlVel", "ruckigVel"},
    {"sendData", ""},
    {"setArrayParameter", "setArrayParam"},
    {"setBoolParameter", "setBoolParam"},
    {"setCollectionName", ""},
    {"setConfigurationTree", ""},
    {"setDebugWatchList", ""},
    {"setDoubleSignal", "setFloatSignal"},
    {"setEngineBoolParameter", "setEngineBoolParam"},
    {"setEngineFloatParameter", "setEngineFloatParam"},
    {"setEngineInt32Parameter", "setEngineInt32Param"},
    {"setFloatParameter", "setFloatParam"},
    {"setGraphUserData", "setGraphStreamValue"},
    {"setIkElementProperties", "the simIK functionality"},
    {"setIkGroupProperties", "the simIK functionality"},
    {"setInt32Parameter", "setInt32Param"},
    {"setIntegerSignal", "setInt32Signal"},
    {"setJointForce", "setJointTargetForce"},
    {"setJointMaxForce", "setJointTargetForce"},
    {"setObjectConfiguration", ""},
    {"setObjectFloatParameter", "setObjectFloatParam"},
    {"setObjectInt32Parameter", "setObjectInt32Param"},
    {"setObjectName", "setObjectAlias"},
    {"setObjectSelection", "setObjectSel"},
    {"setObjectSizeValues", ""},
    {"setObjectStringParameter", "setObjectStringParam"},
    {"setScriptAttribute", "sim.setScriptInt32Param or sim.setScriptStringParam"},
    {"setScriptText", "createScript"},
    {"setScriptVariable", ""},
    {"setShapeMassAndInertia", "sim.getShapeMass and/or sim.setShapeIntertia"},
    {"setShapeMaterial", ""},
    {"setSphericalJointMatrix", "setObjectChildPose"},
    {"setStringNamedParam", "setNamedStringParam"},
    {"setStringParameter", "setStringParam"},
    {"setThreadAutomaticSwitch", "setStepping"},
    {"setThreadSwitchAllowed", "sim.acquireLock and sim.releaseLock"},
    {"setThreadSwitchTiming", "setAutoYieldDelay"},
    {"setVisionSensorCharImage", "setVisionSensorImg"},
    {"setVisionSensorImage", "setVisionSensorImg"},
    {"switchThread", "step"},
    {"unloadModule", "unloadPlugin"},
    {"writeCustomDataBlock", "writeCustomStringData"},
}

function deprecated.extend(sim)
    if sim.getScriptInt32Param(sim.handle_self, sim.scriptintparam_type) ~= sim.scripttype_mainscript then
        for _, pair in ipairs(deprecated.functions) do
            local old, new = table.unpack(pair)
            if new == '' then
                sim[old] = wrap(sim[old], function(origFunc)
                    return function(...)
                        sim.addLog(sim.verbosity_warnings | sim.verbosity_once, string.format('sim.%s is deprecated and the related functionality will disappear in a future release.', old, new))
                        return origFunc(...)
                    end
                end)
            else
                if sim[new] == nil then
                    sim[old] = wrap(sim[old], function(origFunc)
                        return function(...)
                            sim.addLog(sim.verbosity_warnings | sim.verbosity_once, string.format('sim.%s is deprecated. please use %s instead.', old, new))
                            return origFunc(...)
                        end
                    end)
                else
                    sim[old] = wrap(sim[old], function(origFunc)
                        return function(...)
                            sim.addLog(sim.verbosity_warnings | sim.verbosity_once, string.format('sim.%s is deprecated. please use sim.%s instead.', old, new))
                            return origFunc(...)
                        end
                    end)
                end
            end
        end
    end
end

return deprecated
