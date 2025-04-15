local extModel = {}

local sim = require 'sim'

function extModel.customPropertyName(pname)
    return 'customData.extModel.' .. pname
end

function extModel.getBoolProperty(handle, pname, opts)
    return sim.getBoolProperty(handle, extModel.customPropertyName(pname), opts)
end

function extModel.getIntProperty(handle, pname, opts)
    return sim.getIntProperty(handle, extModel.customPropertyName(pname), opts)
end

function extModel.getStringProperty(handle, pname, opts)
    return sim.getStringProperty(handle, extModel.customPropertyName(pname), opts)
end

function extModel.setBoolProperty(handle, pname, pvalue, opts)
    return sim.setBoolProperty(handle, extModel.customPropertyName(pname), pvalue, opts)
end

function extModel.setIntProperty(handle, pname, pvalue, opts)
    return sim.setIntProperty(handle, extModel.customPropertyName(pname), pvalue, opts)
end

function extModel.setStringProperty(handle, pname, pvalue, opts)
    return sim.setStringProperty(handle, extModel.customPropertyName(pname), pvalue, opts)
end

function extModel.removeProperty(handle, pname, opts)
    sim.removeProperty(handle, extModel.customPropertyName(pname), opts)
end

function extModel.relativeModelPathDisplay(location, relPath)
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
            local relPath = extModel.getStringProperty(modelHandle, 'sourceModelFile')
            local location = extModel.getStringProperty(modelHandle, 'sourceModelFileLocation')
            if extModel.prompt('Model file %s (referenced by %s) is newer.\n\nDo you want to reload it?', extModel.relativeModelPathDisplay(location, relPath), modelPath) then
                extModel.loadModel(modelHandle, nil)
            end
        end
    end
end

function extModel.scanForExtModelsToSave()
    for _, modelHandle in ipairs(extModel.getExternalModels()) do
        if extModel.hasModelBeenModified(modelHandle) then
            local modelPath = sim.getObjectAlias(modelHandle, 2)
            local relPath = extModel.getStringProperty(modelHandle, 'sourceModelFile')
            local location = extModel.getStringProperty(modelHandle, 'sourceModelFileLocation')
            if extModel.prompt('Model %s has been modified since load.\n\nDo you want to save it back to %s?', modelPath, extModel.relativeModelPathDisplay(location, relPath)) then
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
    if attr then return attr.modification end
end

function extModel.loadModel(modelHandle, modelFile)
    if modelHandle ~= nil then
        assert(math.type(modelHandle) == 'integer' and sim.isHandle(modelHandle), 'invalid handle')
        assert(sim.getBoolProperty(modelHandle, 'modelBase'), 'not a model')
    end
    if modelFile == nil then
        local relPath = extModel.getStringProperty(modelHandle, 'sourceModelFile')
        local location = extModel.getStringProperty(modelHandle, 'sourceModelFileLocation')
        modelFile = extModel.getAbsoluteModelPath(location, relPath)
        if not extModel.getFileModTime(modelFile) then
            sim.addLog(sim.verbosity_errors, 'Model file ' .. modelFile .. ' not found')
            return
        end
    end
    local newModelHandle = sim.loadModel(modelFile)
    if modelHandle ~= nil then
        sim.setObjectPose(newModelHandle, {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0}, modelHandle)
        sim.setObjectParent(newModelHandle, sim.getObjectParent(modelHandle))
        sim.removeModel(modelHandle)
    end
    local location, relPath = extModel.getRelativeModelPath(modelFile)
    extModel.setStringProperty(newModelHandle, 'sourceModelFile', relPath)
    extModel.setStringProperty(newModelHandle, 'sourceModelFileLocation', location)
    extModel.setIntProperty(newModelHandle, 'sourceModelFileModTime', extModel.getFileModTime(modelFile))
    extModel.setStringProperty(newModelHandle, 'modelHash', extModel.modelHash(newModelHandle))
    sim.addLog(sim.verbosity_scriptinfos, 'Model was loaded from ' .. modelFile)
    sim.announceSceneContentChange()
end

function extModel.saveModel(modelHandle, modelFile)
    assert(math.type(modelHandle) == 'integer' and sim.isHandle(modelHandle), 'invalid handle')
    assert(sim.getBoolProperty(modelHandle, 'modelBase'), 'not a model')
    if modelFile == nil then
        local relPath = extModel.getStringProperty(modelHandle, 'sourceModelFile')
        local location = extModel.getStringProperty(modelHandle, 'sourceModelFileLocation')
        modelFile = extModel.getAbsoluteModelPath(location, relPath)
    end
    extModel.removeProperty(modelHandle, 'sourceModelFile', {noError = true})
    extModel.removeProperty(modelHandle, 'sourceModelFileLocation', {noError = true})
    extModel.removeProperty(modelHandle, 'sourceModelFileModTime', {noError = true})
    extModel.removeProperty(modelHandle, 'modelHash', {noError = true})
    sim.saveModel(modelHandle, modelFile)
    local location, relPath = extModel.getRelativeModelPath(modelFile)
    extModel.setStringProperty(modelHandle, 'sourceModelFile', relPath)
    extModel.setStringProperty(modelHandle, 'sourceModelFileLocation', location)
    extModel.setIntProperty(modelHandle, 'sourceModelFileModTime', extModel.getFileModTime(modelFile))
    extModel.setStringProperty(modelHandle, 'modelHash', extModel.modelHash(modelHandle))
    sim.addLog(sim.verbosity_scriptinfos, 'Model was saved to ' .. modelFile)
    sim.announceSceneContentChange()
end

function extModel.isModelFileNewer(modelHandle)
    local relPath = extModel.getStringProperty(modelHandle, 'sourceModelFile')
    local location = extModel.getStringProperty(modelHandle, 'sourceModelFileLocation')
    local modelFile = extModel.getAbsoluteModelPath(location, relPath)
    local fmtime = extModel.getFileModTime(modelFile)
    if fmtime == nil then
        sim.addLog(sim.verbosity_warnings, 'Model file ' .. modelFile .. ' not found')
        return false
    end
    local mtime = extModel.getIntProperty(modelHandle, 'sourceModelFileModTime')
    return os.difftime(mtime, fmtime) < 0
end

function extModel.hasExternalModel(modelHandle)
    return not not extModel.getStringProperty(modelHandle, 'sourceModelFile', {noError = true})
end

function extModel.hasModelBeenModified(modelHandle)
    assert(math.type(modelHandle) == 'integer' and sim.isHandle(modelHandle), 'invalid handle')
    assert(sim.getBoolProperty(modelHandle, 'modelBase'), 'not a model')
    local storedModelHash = extModel.getStringProperty(modelHandle, 'modelHash', {noError = true}) or ''
    local computedModelHash = extModel.modelHash(modelHandle)
    return storedModelHash ~= computedModelHash
end

function extModel.getExternalModels()
    return filter(extModel.hasExternalModel, sim.getObjectsInTree(sim.handle_scene))
end

function extModel.modelHash(modelHandle)
    cbor = require 'org.conman.cbor'
    local simUI = require 'simUI'

    -- Lua table [non-integer] key order is random. convert to a stable datastruct:
    local function stableTable(t)
        local items = {}
        for k, v in pairs(t) do table.insert(items, {k, v}) end
        table.sort(items, function(a, b) return a[1] < b[1] end)
        return items
    end

    local t0 = sim.getSystemTime()
    local modelTreeData = map(
        function(handle)
            local props = sim.getProperties(handle)
            props.selected = nil
            props.objectUid = nil
            props.parentUid = nil
            props.parentHandle = nil
            props[extModel.customPropertyName('modelHash')] = nil
            props[extModel.customPropertyName('sourceModelFile')] = nil
            props[extModel.customPropertyName('sourceModelFileLocation')] = nil
            props[extModel.customPropertyName('sourceModelFileModTime')] = nil

            if props.objectType == 'shape' then
                local meshes = {}
                for _, meshUid in ipairs(props.meshes) do
                    local mesh = sim.getProperties(meshUid)
                    mesh.shapeUid = nil
                    table.insert(meshes, stableTable(mesh))
                end
                props.meshes = meshes
            end

            if props.linkedDummyHandle ~= nil and props.linkedDummyHandle ~= -1 then
                props.linkedDummyHandle = sim.getStringProperty(props.linkedDummyHandle, 'persistentUid')
            end

            -- FIXME: probably forgot other properties referencing object handles

            return stableTable(props)
        end,
        sim.getObjectsInTree(modelHandle)
    )
    local t1 = sim.getSystemTime()
    modelTreeData = cbor.encode(modelTreeData)
    local hash = simUI.hash(modelTreeData, 'Sha1')
    local t2 = sim.getSystemTime()
    if extModel.getBoolProperty(sim.handle_app, 'traceHashing', {noError = true}) then
        sim.addLog(sim.verbosity_scriptinfos, string.format('Took %.3fs to extract model data and %.3f to compute encoded hash (blob length = %d bytes)', t1 - t0, t2 - t1, #modelTreeData))
    end
    return hash
end

return extModel
