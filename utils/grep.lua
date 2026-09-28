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
            local matches = string.grep(targetObj.code, expr)
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

    local find = require 'utils.find'
    if opts.files or opts.dirs then
        if opts.models ~= false then
            find.models {
                files = opts.files,
                dirs = opts.dirs,
                exec = function(modelPath)
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
            }
        end
        if opts.scenes ~= false then
            find.scenes {
                files = opts.files,
                dirs = opts.dirs,
                exec = function(scenePath)
                    if opts.verbose then
                        sim.app:logInfo('Loading scene ' .. scenePath .. '...')
                    end
                    sim.app:loadScene(scenePath, {createNew = not loadedOneScene})
                    loadedOneScene = true
                    fileContext = scenePath
                    processCurrentScene()
                end
            }
        end
    else
        processCurrentScene()
    end

    print('(' .. numHits .. ' hits)')

    if loadedOneScene then
        sim.scene:remove()
    end
end
