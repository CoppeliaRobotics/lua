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

function extModel.getModelInfo(modelHandle)
    assert(math.type(modelHandle) == 'integer' and sim.isHandle(modelHandle))
    local info = {
        relPath = extModel.getStringProperty(modelHandle, 'sourceModelFile', {noError = true}),
        location = extModel.getStringProperty(modelHandle, 'sourceModelFileLocation', {noError = true}),
    }
    if not info.relPath or not info.location then return nil end
    if info.location == 'absolute' then
        info.displayPath = info.relPath
    else
        info.displayPath = string.format('<%s dir>/%s', info.location, info.relPath)
    end
    info.absPath = extModel.getAbsoluteModelPath(info.location, info.relPath)
    info.modTime = extModel.getFileModTime(info.absPath)
    info.fileExists = not not info.modTime
    if info.fileExists then
        info.isFileNewer = os.difftime(extModel.getIntProperty(modelHandle, 'sourceModelFileModTime', {noError = true}) or 0, info.modTime) < 0
    end
    return info
end

function extModel.changedModelsBannerCreate(changedModels, changedModelFiles)
    local simUI = require 'simUI'

    if table.eq(changedModelsBannerContent, changedModelFiles) then return end

    extModel.changedModelsBannerDestroy()

    local changedModelFilesKeys = table.keys(changedModelFiles)
    local limit = 3
    local others = math.max(0, #changedModelFilesKeys - limit)
    changedModelFilesKeys = table.slice(changedModelFilesKeys, 1, limit)

    bannerId = simUI.bannerCreate('<b>External model auto reload:</b> some external model files (' .. string.escapehtml(table.join(changedModelFilesKeys, ', ')) .. (#changedModelFilesKeys > limit and (' and ' .. others .. ' others') or '') .. ') have been changed externally.', {'reload', 'dismiss'}, {'Reload...', 'Dismiss'}, 'onChangedModelsBannerButtonClick')
    changedModelsBannerContent = changedModelFiles

    function onChangedModelsBannerButtonClick(bannerId, k)
        if k == 'dismiss' then
            for displayPath, absPath in pairs(changedModelFiles) do
                extModel.ignoreFile(absPath)
            end
            extModel.changedModelsBannerDestroy()
        elseif k == 'reload' then
            extModel.changedModelsDialogCreate(changedModels)
        end
    end
end

function extModel.changedModelsBannerDestroy()
    local simUI = require 'simUI'
    if bannerId then
        simUI.bannerDestroy(bannerId)
        bannerId = nil
    end
    changedModelsBannerContent = nil
end

function extModel.changedModelsDialogCreate(changedModels)
    local simUI = require 'simUI'

    local xml = ''
    for _, modelHandle in ipairs(changedModels) do
        local info = extModel.getModelInfo(modelHandle)
        xml = xml .. '<label text="' .. string.escapehtml('Model: <b>' .. string.escapehtml(sim.getObjectAlias(modelHandle, 2)) .. '</b><br/><small>File: ' .. string.escapehtml(info.displayPath) .. '</small><br/><small>Mod. date: ' .. os.date("%Y-%m-%d %H:%M:%S", info.modTime) .. '</small>') .. '" />'
        xml = xml .. '<button id="' .. (1000 + modelHandle) .. '" text="Reload" on-click="reloadModel" />'
        xml = xml .. '<br/>'
    end

    function reloadModel(ui, id)
        local modelHandle = id - 1000
        extModel.reloadModelInteractive(modelHandle)
        simUI.setEnabled(ui, id, false)
    end

    function changedModelsDialogClose()
        extModel.changedModelsBannerDestroy()
        extModel.changedModelsDialogDestroy()
        extModel.scanForExtModelsToReload()
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

function extModel.scanForExtModelsToReload()
    local changedModels = {}
    for _, modelHandle in ipairs(extModel.getExternalModels()) do
        local info = extModel.getModelInfo(modelHandle)
        if info.isFileNewer then
            table.insert(changedModels, modelHandle)
        end
    end
    if not changedModelsDialog then
        local changedModelFiles = {}
        for _, modelHandle in ipairs(changedModels) do
            local info = extModel.getModelInfo(modelHandle)
            if not extModel.isFileIgnored(info.absPath) then
                changedModelFiles[info.displayPath] = info.absPath
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
            local info = extModel.getModelInfo(modelHandle)
            if extModel.prompt('Model %s has been modified since load.\n\nDo you want to save it back to %s?', sim.getObjectAlias(modelHandle, 2), info.displayPath) then
                extModel.saveModel(modelHandle, nil)
            end
        end
    end
end

function extModel.alert(...)
    local simUI = require 'simUI'
    simUI.msgBox(simUI.msgbox_type.critical, simUI.msgbox_buttons.ok, '', string.format(...))
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

function extModel.ignoreFile(absPath)
    ignoreFiles = ignoreFiles or {}
    ignoreFiles[absPath] = extModel.getFileModTime(absPath) or -1
end

function extModel.isFileIgnored(absPath)
    if not ignoreFiles then return false end
    if not ignoreFiles[absPath] then return false end
    if ignoreFiles[absPath] == -1 then return true end
    local modTime = extModel.getFileModTime(absPath)
    return os.difftime(ignoreFiles[absPath], modTime) >= 0
end

function extModel.loadModel(modelHandle, modelFile)
    if modelHandle ~= nil then
        assert(math.type(modelHandle) == 'integer' and sim.isHandle(modelHandle), 'invalid handle')
        assert(sim.getBoolProperty(modelHandle, 'modelBase'), 'not a model')
    end
    if modelFile == nil then
        local info = extModel.getModelInfo(modelHandle)
        if not info.fileExists then
            if not extModel.isFileIgnored(info.absPath) then
                sim.addLog(sim.verbosity_errors, 'Model file ' .. info.absPath .. ' not found')
                extModel.ignoreFile(info.absPath)
            end
            return
        end
        modelFile = info.absPath
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

function extModel.reloadModelInteractive(modelHandle)
    local info = extModel.getModelInfo(modelHandle)

    if not info then
        extModel.alert('Object does not reference an external model')
        return
    end

    if not info.fileExists then
        extModel.alert('Model file %s is missing.\n\nUse the external model save function to relocate it.', info.displayPath)
        return
    end

    return extModel.loadModel(modelHandle, info.absPath)
end

function extModel.saveModel(modelHandle, modelFile)
    assert(math.type(modelHandle) == 'integer' and sim.isHandle(modelHandle), 'invalid handle')
    assert(sim.getBoolProperty(modelHandle, 'modelBase'), 'not a model')
    if modelFile == nil then
        local info = extModel.getModelInfo(modelHandle)
        modelFile = info.absPath
    end
    extModel.removeProperty(modelHandle, 'sourceModelFile', {noError = true})
    extModel.removeProperty(modelHandle, 'sourceModelFileLocation', {noError = true})
    extModel.removeProperty(modelHandle, 'sourceModelFileModTime', {noError = true})
    extModel.removeProperty(modelHandle, 'modelHash', {noError = true})
    local lfsx = require 'lfsx'
    lfsx.makedirs(lfsx.dirname(modelFile), true) -- model in nested subdir & saving scene to a new location would result in error
    sim.saveModel(modelHandle, modelFile)
    local location, relPath = extModel.getRelativeModelPath(modelFile)
    extModel.setStringProperty(modelHandle, 'sourceModelFile', relPath)
    extModel.setStringProperty(modelHandle, 'sourceModelFileLocation', location)
    extModel.setIntProperty(modelHandle, 'sourceModelFileModTime', extModel.getFileModTime(modelFile))
    extModel.setStringProperty(modelHandle, 'modelHash', extModel.modelHash(modelHandle))
    sim.addLog(sim.verbosity_scriptinfos, 'Model was saved to ' .. modelFile)
    sim.announceSceneContentChange()
end

function extModel.saveModelInteractive(modelHandle)
    local info = extModel.getModelInfo(modelHandle)

    if info then
        if info.fileExists then
            extModel.saveModel(modelHandle)
            return true
        else
            if not extModel.prompt('File %s is missing. Do you want to manually locate it?', info.displayPath) then
                return false
            end
        end
    else
        if not extModel.prompt('Object %s does not reference an external model.\n\nDo you want to choose one?', sim.getObjectAlias(modelHandle, 2)) then
            return false
        end
    end

    local simUI = require 'simUI'
    local lfsx = require 'lfsx'
    local initPath = lfsx.dirname(sim.getStringProperty(sim.handle_scene, 'scenePath'))
    files = simUI.fileDialog(simUI.filedialog_type.save, 'Save model...', initPath, '', 'Model files', 'ttm;simmodel.xml')
    if #files > 1 then
        sim.addLog(sim.verbosity_errors, 'Please choose exactly one file')
        return false
    elseif #files == 1 then
        local f = io.open(files[1], 'r')
        local exists = false
        if f then
            f:close()
            exists = true
        end
        if not exists or extModel.prompt('File %s already exists.\n\nDo you want to overwrite it?', files[1]) then
            extModel.saveModel(modelHandle, files[1])
            return true
        end
    end
    return false
end

function extModel.hasModelBeenModified(modelHandle)
    assert(math.type(modelHandle) == 'integer' and sim.isHandle(modelHandle), 'invalid handle')
    assert(sim.getBoolProperty(modelHandle, 'modelBase'), 'not a model')
    local storedModelHash = extModel.getStringProperty(modelHandle, 'modelHash', {noError = true}) or ''
    local computedModelHash = extModel.modelHash(modelHandle)
    return storedModelHash ~= computedModelHash
end

function extModel.getExternalModels()
    return filter(function(h) return not not extModel.getModelInfo(h) end, sim.getObjectsInTree(sim.handle_scene))
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
