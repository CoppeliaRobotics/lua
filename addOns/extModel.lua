local extModel = {}

local sim = require 'sim'

function extModel.modelFileDisplay(location, relPath)
    if location == 'absolute' then
        return relPath
    else
        return string.format('<%s dir>/%s', location, relPath)
    end
end

function extModel.scanForExtModelsToReload()
    for _, modelHandle in ipairs(extModel.getExternalModels()) do
        if extModel.isModelFileNewer(modelHandle) then
            local modelPath = sim.getObjectAlias(modelHandle, 2)
            local relPath = sim.getStringProperty(modelHandle, 'customData.sourceModelFile')
            local location = sim.getStringProperty(modelHandle, 'customData.sourceModelFileLocation')
            if extModel.prompt('Model file %s (referenced by %s) is newer.\n\nDo you want to reload it?', extModel.modelFileDisplay(location, relPath), modelPath) then
                extModel.loadModel(modelHandle, nil)
            end
        end
    end
end

function extModel.scanForExtModelsToSave()
    for _, modelHandle in ipairs(extModel.getExternalModels()) do
        if extModel.hasModelBeenModified(modelHandle) then
            local modelPath = sim.getObjectAlias(modelHandle, 2)
            local relPath = sim.getStringProperty(modelHandle, 'customData.sourceModelFile')
            local location = sim.getStringProperty(modelHandle, 'customData.sourceModelFileLocation')
            if extModel.prompt('Model %s has been modified since load.\n\nDo you want to save it back to %s?', modelPath, extModel.modelFileDisplay(location, relPath)) then
                extModel.saveModel(modelHandle, nil)
            end
        end
    end
end

function extModel.prompt(...)
    local simUI = require 'simUI'
    local r = simUI.msgBox(simUI.msgbox_type.question, simUI.msgbox_buttons.yesno, '', string.format(...))
    return r == simUI.msgbox_result.yes
end

function extModel.getModelPathRules()
    local lfsx = require 'lfsx'
    return {
        {'scene', lfsx.dirname(sim.getStringProperty(sim.handle_scene, 'scenePath')) .. lfsx.pathsep()},
        {'overlays', sim.getStringProperty(sim.handle_app, 'settingsPath') .. lfsx.pathsep() .. 'overlays' .. lfsx.pathsep()},
        {'models', sim.getStringProperty(sim.handle_app, 'modelPath') .. lfsx.pathsep()},
    }
end

function extModel.getRelativeModelPath(absPath)
    local lfsx = require 'lfsx'
    for _, rule in ipairs(extModel.getModelPathRules()) do
        local location, path = table.unpack(rule)
        if string.startswith(absPath, path) then
            return location, string.stripprefix(absPath, path)
        end
    end
    return 'absolute', absPath
end

function extModel.getAbsoluteModelPath(location, relPath)
    local lfsx = require 'lfsx'
    local rules = {absolute = function(p) return p end}
    for _, rule in ipairs(extModel.getModelPathRules()) do
        local loc, path = table.unpack(rule)
        rules[loc] = function(p) return path .. p end
    end
    assert(rules[location], 'invalid location: ' .. location)
    return rules[location](relPath)
end

function extModel.getFileModTime(path)
    local lfs = require 'lfs'
    local attr = lfs.attributes(path)
    return attr.modification
end

function extModel.loadModel(modelHandle, modelFile)
    if modelHandle ~= nil then
        assert(math.type(modelHandle) == 'integer' and sim.isHandle(modelHandle), 'invalid handle')
        assert(sim.getBoolProperty(modelHandle, 'modelBase'), 'not a model')
    end
    if modelFile == nil then
        local relPath = sim.getStringProperty(modelHandle, 'customData.sourceModelFile')
        local location = sim.getStringProperty(modelHandle, 'customData.sourceModelFileLocation')
        modelFile = extModel.getAbsoluteModelPath(location, relPath)
    end
    local newModelHandle = sim.loadModel(modelFile)
    if modelHandle ~= nil then
        sim.setObjectPose(newModelHandle, {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0}, modelHandle)
        sim.setObjectParent(newModelHandle, sim.getObjectParent(modelHandle))
        sim.removeModel(modelHandle)
    end
    local location, relPath = extModel.getRelativeModelPath(modelFile)
    sim.setStringProperty(newModelHandle, 'customData.sourceModelFile', relPath)
    sim.setStringProperty(newModelHandle, 'customData.sourceModelFileLocation', location)
    sim.setIntProperty(newModelHandle, 'customData.sourceModelFileModTime', extModel.getFileModTime(modelFile))
    sim.setStringProperty(newModelHandle, 'customData.modelHash', extModel.modelHash(newModelHandle))
    sim.addLog(sim.verbosity_scriptinfos, 'Model was loaded from ' .. modelFile)
    sim.announceSceneContentChange()
end

function extModel.saveModel(modelHandle, modelFile)
    assert(math.type(modelHandle) == 'integer' and sim.isHandle(modelHandle), 'invalid handle')
    assert(sim.getBoolProperty(modelHandle, 'modelBase'), 'not a model')
    if modelFile == nil then
        local relPath = sim.getStringProperty(modelHandle, 'customData.sourceModelFile')
        local location = sim.getStringProperty(modelHandle, 'customData.sourceModelFileLocation')
        modelFile = extModel.getAbsoluteModelPath(location, relPath)
    end
    sim.removeProperty(modelHandle, 'customData.sourceModelFile', {noError = true})
    sim.removeProperty(modelHandle, 'customData.sourceModelFileLocation', {noError = true})
    sim.removeProperty(modelHandle, 'customData.sourceModelFileModTime', {noError = true})
    sim.removeProperty(modelHandle, 'customData.modelHash', {noError = true})
    sim.saveModel(modelHandle, modelFile)
    local location, relPath = extModel.getRelativeModelPath(modelFile)
    sim.setStringProperty(modelHandle, 'customData.sourceModelFile', relPath)
    sim.setStringProperty(modelHandle, 'customData.sourceModelFileLocation', location)
    sim.setIntProperty(modelHandle, 'customData.sourceModelFileModTime', extModel.getFileModTime(modelFile))
    sim.setStringProperty(modelHandle, 'customData.modelHash', extModel.modelHash(modelHandle))
    sim.addLog(sim.verbosity_scriptinfos, 'Model was saved to ' .. modelFile)
    sim.announceSceneContentChange()
end

function extModel.isModelFileNewer(modelHandle)
    local relPath = sim.getStringProperty(modelHandle, 'customData.sourceModelFile')
    local location = sim.getStringProperty(modelHandle, 'customData.sourceModelFileLocation')
    local modelFile = extModel.getAbsoluteModelPath(location, relPath)
    local fmtime = extModel.getFileModTime(modelFile)
    local mtime = sim.getIntProperty(modelHandle, 'customData.sourceModelFileModTime')
    return os.difftime(mtime, fmtime) < 0
end

function extModel.hasExternalModel(modelHandle)
    return not not sim.getStringProperty(modelHandle, 'customData.sourceModelFile', {noError = true})
end

function extModel.hasModelBeenModified(modelHandle)
    assert(math.type(modelHandle) == 'integer' and sim.isHandle(modelHandle), 'invalid handle')
    assert(sim.getBoolProperty(modelHandle, 'modelBase'), 'not a model')
    local storedModelHash = sim.getStringProperty(modelHandle, 'customData.modelHash', {noError = true}) or ''
    local computedModelHash = extModel.modelHash(modelHandle)
    return storedModelHash ~= computedModelHash
end

function extModel.getExternalModels()
    return filter(extModel.hasExternalModel, sim.getObjectsInTree(sim.handle_scene))
end

function extModel.modelHash(modelHandle)
    cbor = require 'org.conman.cbor'
    sha1 = require 'sha1'
    return sha1.sha1(
        cbor.encode(
            map(
                function(handle)
                    local props = sim.getProperties(handle)
                    props.selected = nil
                    props.objectUid = nil
                    props.parentUid = nil
                    props.parentHandle = nil
                    props.persistentUid = nil
                    props['customData.modelHash'] = nil
                    props['customData.sourceModelFile'] = nil
                    props['customData.sourceModelFileLocation'] = nil
                    props['customData.sourceModelFileModTime'] = nil
                    if props.linkedDummyHandle ~= -1 then props.linkedDummyHandle = 1 end
                    -- convert to list for stable order:
                    local items = {}
                    for k, v in pairs(props) do table.insert(items, {k, v}) end
                    table.sort(items, function(a, b) return a[1] < b[1] end)
                    return items
                end,
                sim.getObjectsInTree(modelHandle)
            )
        )
    )
end

return extModel
