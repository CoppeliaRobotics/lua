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

function extModel.changedModelsBannerCreate(changedModels, changedModelFiles)
    local simUI = require 'simUI'

    if table.eq(changedModelsBannerContent, changedModelFiles) then return end

    extModel.changedModelsBannerDestroy()

    local changedModelFilesKeys = table.keys(changedModelFiles)
    local limit = 3
    local others = math.max(0, #changedModelFilesKeys - limit)
    changedModelFilesKeys = table.slice(changedModelFilesKeys, 1, limit)

    bannerId = simUI.bannerShow('<b>External model auto reload:</b> some external model files (' .. string.escapehtml(table.join(changedModelFilesKeys, ', ')) .. (#changedModelFilesKeys > limit and (' and ' .. others .. ' others') or '') .. ') have been changed externally.', {'reload', 'dismiss'}, {'Reload...', 'Dismiss'}, 'onChangedModelsBannerButtonClick')
    changedModelsBannerContent = changedModelFiles

    function onChangedModelsBannerButtonClick(k)
        extModel.changedModelsBannerDestroy()
        if k == 'dismiss' then
            ignoreFiles = ignoreFiles or {}
            for displayPath, absPath in pairs(changedModelFiles) do
                ignoreFiles[absPath] = extModel.getFileModTime(absPath)
            end
        elseif k == 'reload' then
            extModel.changedModelsDialogCreate(changedModels)
        end
    end
end

function extModel.changedModelsBannerDestroy()
    local simUI = require 'simUI'
    if bannerId then
        simUI.bannerHide(bannerId)
        bannerId = nil
    end
    changedModelsBannerContent = nil
end

function extModel.changedModelsDialogCreate(changedModels)
    local simUI = require 'simUI'

    local xml = ''
    for _, modelHandle in ipairs(changedModels) do
        local relPath = extModel.getStringProperty(modelHandle, 'sourceModelFile')
        local location = extModel.getStringProperty(modelHandle, 'sourceModelFileLocation')
        local displayPath = extModel.relativeModelPathDisplay(location, relPath)
        local modelPath = sim.getObjectAlias(modelHandle, 2)
        local absPath = extModel.getAbsoluteModelPath(location, relPath)
        local modTime = extModel.getFileModTime(absPath)
        xml = xml .. '<label text="' .. string.escapehtml('Model: <b>' .. string.escapehtml(modelPath) .. '</b><br/><small>File: ' .. string.escapehtml(displayPath) .. '</small><br/><small>Mod. date: ' .. os.date("%Y-%m-%d %H:%M:%S", modTime) .. '</small>') .. '" />'
        xml = xml .. '<button id="' .. (1000 + modelHandle) .. '" text="Reload" on-click="reloadModel" />'
        xml = xml .. '<br/>'
    end

    function reloadModel(ui, id)
        local modelHandle = id - 1000
        extModel.loadModel(modelHandle, nil)
        simUI.setEnabled(ui, id, false)
    end

    function changedModelsDialogClose()
        extModel.changedModelsDialogDestroy()
    end

    changedModelsDialog = simUI.create([[
        <ui title="External model auto reload" resizable="false" closeable="true" placement="center" modal="true" on-close="changedModelsDialogClose">
            <label text="The following models have been modified externally:" />
            <group layout="grid">]] .. xml .. [[</group>
        </ui>
    ]])
end

function extModel.changedModelsDialogDestroy()
    local simUI = require 'simUI'

    if changedModelsDialog then
        simUI.destroy(changedModelsDialog)
        changedModelsDialog = nil
    end
end

function extModel.scanForExtModelsToReload(immediatePrompt)
    local changedModels = {}
    for _, modelHandle in ipairs(extModel.getExternalModels()) do
        if extModel.isModelFileNewer(modelHandle) then
            if immediatePrompt then
                local modelPath = sim.getObjectAlias(modelHandle, 2)
                local relPath = extModel.getStringProperty(modelHandle, 'sourceModelFile')
                local location = extModel.getStringProperty(modelHandle, 'sourceModelFileLocation')
                if extModel.prompt('Model file %s (referenced by %s) is newer.\n\nDo you want to reload it?', extModel.relativeModelPathDisplay(location, relPath), modelPath) then
                    extModel.loadModel(modelHandle, nil)
                end
            else
                table.insert(changedModels, modelHandle)
            end
        end
    end
    if not immediatePrompt and not changedModelsDialog then
        local changedModelFiles = {}
        for _, modelHandle in ipairs(changedModels) do
            local relPath = extModel.getStringProperty(modelHandle, 'sourceModelFile')
            local location = extModel.getStringProperty(modelHandle, 'sourceModelFileLocation')
            local displayPath = extModel.relativeModelPathDisplay(location, relPath)
            local absPath = extModel.getAbsoluteModelPath(location, relPath)
            local modTime = extModel.getFileModTime(absPath)
            if not ignoreFiles or not ignoreFiles[absPath] or os.difftime(ignoreFiles[absPath], modTime) < 0 then
                changedModelFiles[displayPath] = absPath
            end
        end
        if next(changedModelFiles) then
            extModel.changedModelsBannerCreate(changedModels, changedModelFiles)
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
    local r = {}
    local function addRule(name, path)
        table.insert(r, {name, lfsx.pathsanitize(path)})
    end
    addRule('scene', lfsx.dirname(sim.getStringProperty(sim.handle_scene, 'scenePath')) .. lfsx.pathsep())
    addRule('overlays', sim.getStringProperty(sim.handle_app, 'settingsPath') .. lfsx.pathsep() .. 'overlays' .. lfsx.pathsep())
    addRule('models', sim.getStringProperty(sim.handle_app, 'modelPath') .. lfsx.pathsep())
    return r
end

function extModel.getRelativeModelPath(absPath)
    local lfsx = require 'lfsx'
    absPath = lfsx.pathsanitize(absPath)
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
        sim.setObjectHierarchyOrder(newModelHandle, sim.getObjectHierarchyOrder(modelHandle))
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
    local ignoreProps = {
        modelHash = '',
        sourceModelFile = '',
        sourceModelFileLocation = '',
        sourceModelFileModTime = 0,
    }
    for prop, _ in pairs(ignoreProps) do
        ignoreProps[prop] = sim.getProperty(modelHandle, extModel.customPropertyName(prop), {noError = true})
        extModel.removeProperty(modelHandle, prop, {noError = true})
    end
    local modelHash = sim.getStringProperty(modelHandle, 'modelHash')
    for prop, val in pairs(ignoreProps) do
        sim.setProperty(modelHandle, extModel.customPropertyName(prop), val)
    end
    return modelHash
end

return extModel
