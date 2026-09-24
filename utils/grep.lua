return function(expr, opts)
    local sim = require 'sim-2'
    opts = opts or {}
    assert(opts.files or opts.dirs, 'at least files or dirs must be set')
    local loadedOneScene = false
    local numHits = 0
    local function processScene(scenePath)
        if opts.verbose then
            sim.app:logInfo('Loading scene ' .. scenePath .. '...')
        end
        sim.app:loadScene(scenePath, {createNew = not loadedOneScene})
        loadedOneScene = true
        local sceneContext = scenePath
        for _, obj in ipairs(sim.scene:getObjects{types={'scriptObject'}}) do
            local objectContext = obj:getName {mode = 'fullPath'}
            local matches = string.grep(obj.script.code, expr)
            for _, match in ipairs(matches) do
                if sceneContext then
                    print(sceneContext .. ':')
                    sceneContext = nil
                end
                if objectContext then
                    print('    ' .. objectContext .. ':')
                    objectContext = nil
                end
                print('        line ' .. match.line .. ': ' .. match.lineText)
            end
            numHits = numHits + #matches
        end
    end

    if opts.files then
        assert(type(opts.files) == 'table', 'files must be a table')
        for _, file in ipairs(opts.files) do
            processScene(file)
        end
    end

    if opts.dirs then
        assert(type(opts.dirs) == 'table', 'dirs must be a table')
        local lfsx = require 'lfsx'
        for _, dir in ipairs(opts.dirs) do
            for path, attr in lfsx.iwalk(dir) do
                if path:endswith '.ttt' then
                    processScene(path)
                end
            end
        end
    end

    print('(' .. numHits .. ' hits)')

    if loadedOneScene then
        sim.scene:remove()
    end
end
