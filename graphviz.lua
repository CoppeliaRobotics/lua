local graphviz = {}

function graphviz.dot(doc, outFile)
    local sim = require 'sim'
    local simSubprocess = require 'simSubprocess'
    local dotPath = sim.getStringProperty(sim.handle_app, 'customData.graphvizPath', {noError = true})
    local usp = false
    if dotPath == nil then
        dotPath = 'dot'
        usp = true
    else
        dotPath = dotPath .. '/dot'
    end
    local args = {'-Tjpg', '-Gsize=10!', '-Gdpi=150'}
    if outFile then
        table.insert(args, '-o')
        table.insert(args, outFile)
    end
    local ec, out, err = simSubprocess.exec(dotPath, args, doc, {useSearchPath=usp})
    if not outFile then
        -- result image is written to stdout
        return out
    end
end

return graphviz
