return function(expr, opts)
    local sim = require 'sim-2'

    opts = opts or {}

    local sceneContext, objectContext = '(current scene)', '?'
    local loadedOneScene = false
    local numHits = 0

    local function reportHit(matchContext)
        if sceneContext then
            print(sceneContext .. ':')
            sceneContext = nil
        end
        if objectContext then
            print('    ' .. objectContext .. ':')
            objectContext = nil
        end
        print('        ' .. matchContext)
        numHits = numHits + 1
    end

    local function processObject(obj)
        local matches = string.grep(obj.code, expr)
        for _, match in ipairs(matches) do
            reportHit('line ' .. match.line .. ': ' .. match.lineText)
        end
    end

    local function processCurrentScene()
        if type(expr) == 'string' then
            objectContext = 'scene.mainScript'
            processObject(sim.scene.mainScript)

            for _, obj in ipairs(sim.scene:getObjects{types={'scriptObject'}}) do
                objectContext = obj:getName {mode = 'fullPath'}
                processObject(obj.script)
            end
        end

        if isbuffer(expr) then
            for _, obj in ipairs(sim.scene.objects) do
                if obj.dna == expr then
                    objectContext = obj:getName {mode = 'fullPath'}
                    reportHit('object\'s "dna" property matches')
                end
            end
        end
    end

    local function loadAndProcessScene(scenePath)
        if opts.verbose then
            sim.app:logInfo('Loading scene ' .. scenePath .. '...')
        end
        sim.app:loadScene(scenePath, {createNew = not loadedOneScene})
        loadedOneScene = true
        sceneContext = scenePath
        processCurrentScene()
    end

    if opts.files then
        assert(type(opts.files) == 'table', 'files must be a table')
        for _, file in ipairs(opts.files) do
            loadAndProcessScene(file)
        end
    end

    if opts.dirs then
        assert(type(opts.dirs) == 'table', 'dirs must be a table')
        local lfsx = require 'lfsx'
        for _, dir in ipairs(opts.dirs) do
            for path, attr in lfsx.iwalk(dir) do
                if false
                    or (opts.scenes ~= false and (path:endswith '.ttt' or path:endswith '.simscene.xml'))
                    or (opts.models ~= false and (path:endswith '.ttm' or path:endswith '.simmodel.xml'))
                then
                    loadAndProcessScene(path)
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
