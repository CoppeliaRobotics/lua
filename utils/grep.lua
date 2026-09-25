return function(expr, opts)
    local sim = require 'sim-2'

    opts = opts or {}

    local fileContext, objectContext = '(current scene)', '?'
    local loadedOneScene = false
    local numHits = 0

    local function reportHit(matchContext)
        if fileContext then
            print(fileContext .. ':')
            fileContext = nil
        end
        if objectContext then
            print('    ' .. objectContext .. ':')
            objectContext = nil
        end
        print('        ' .. matchContext)
        numHits = numHits + 1
    end

    local function processObject(obj, ctx)
        objectContext = ctx

        if isbuffer(expr) and obj.dna == expr then
            reportHit('object\'s "dna" property matches')
        end

        if type(expr) == 'string' and (obj.type == 'script' or obj.type == 'scriptObject') then
            local targetObj = obj.type == 'scriptObject' and obj.script or obj
            local matches = string.grep(obj.code, expr)
            for _, match in ipairs(matches) do
                reportHit('line ' .. match.line .. ': ' .. match.lineText)
            end
        end
    end

    local function processCurrentScene()
        processObject(sim.scene.mainScript, 'scene.mainScript')
        for _, obj in ipairs(sim.scene.objects) do
            processObject(obj, obj:getName {mode = 'fullPath'})
        end
    end

    local function loadAndProcessScene(scenePath)
        if opts.verbose then
            sim.app:logInfo('Loading scene ' .. scenePath .. '...')
        end
        sim.app:loadScene(scenePath, {createNew = not loadedOneScene})
        loadedOneScene = true
        fileContext = scenePath
        processCurrentScene()
    end

    local function loadAndProcessModel(modelPath)
        if opts.verbose then
            sim.app:logInfo('Loading model ' .. modelPath .. '...')
        end
        sim.app:loadScene(app.paths.system .. '/dfltscn.ttt', {createNew = not loadedOneScene})
        local model = sim.scene:loadModel(modelPath)
        loadedOneScene = true
        fileContext = modelPath
        for _, obj in ipairs(model.tree) do
            processObject(obj, obj:getName {mode = 'fullPath'})
        end
        model:removeModel()
    end

    local function isModelFile(path)
        return path:endswith '.ttm' or path:endswith '.simmodel.xml'
    end

    local function isSceneFile(path)
        return path:endswith '.ttt' or path:endswith '.simscene.xml'
    end

    if opts.files then
        assert(type(opts.files) == 'table', 'files must be a table')
        for _, file in ipairs(opts.files) do
            if isSceneFile(file) then
                loadAndProcessScene(file)
            elseif isModelFile(file) then
                loadAndProcessModel(file)
            end
        end
    end

    if opts.dirs then
        assert(type(opts.dirs) == 'table', 'dirs must be a table')
        local lfsx = require 'lfsx'
        for _, dir in ipairs(opts.dirs) do
            for path, attr in lfsx.iwalk(dir) do
                if opts.scenes ~= false and isSceneFile(path) then
                    loadAndProcessScene(path)
                elseif opts.models ~= false and isModelFile(path) then
                    loadAndProcessModel(path)
                end
            end
        end
    end

    if not opts.files and not opts.dirs then
        processCurrentScene()
    end

    print('(' .. numHits .. ' hits)')

    if loadedOneScene then
        sim.scene:remove()
    end
end
