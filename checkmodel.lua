local checkmodel = {}

local sim = require 'sim'

local function isDynamic(handle)
    return sim.getBoolProperty(handle, 'dynamic', {noError=true})
end

local function addVertex(g, handle)
    g[handle] = g[handle] or {
        objType = sim.getStringProperty(handle, 'objectType'),
        alias = sim.getStringProperty(handle, 'alias'),
        dynamic = isDynamic(handle),
        edges = {},
    }
end

local function addEdge(g, k1, k2)
    if not g[k1] then addVertex(g, k1) end
    if not g[k2] then addVertex(g, k2) end
    table.insert(g[k1].edges, k2)
    table.insert(g[k2].edges, k1)
end

function checkmodel.buildDynamicObjectsGraph(parentHandle, g, visited)
    parentHandle = parentHandle or sim.handle_scene
    g = g or {}; visited = visited or {}

    if visited[parentHandle] then return else visited[parentHandle] = true end

    for index = 0, 10000 do
        local handle = sim.getObjectChild(parentHandle, index)
        if handle == -1 then break end
        local objType = sim.getStringProperty(handle, 'objectType')
        if objType == 'shape' then
            if sim.getBoolProperty(handle, 'dynamic') then
                addEdge(g, parentHandle, handle)
            end
        elseif objType == 'joint' then
            addEdge(g, parentHandle, handle)
        elseif objType == 'dummy' then
            if sim.getIntProperty(handle, 'dummyType') == 0 then -- dyn-overlap
                local linkedDummy = sim.getIntProperty(handle, 'linkedDummyHandle')
                if linkedDummy ~= -1 then
                    local obj = sim.getObjectParent(linkedDummy)
                    addVertex(g, obj)
                    addEdge(g, parentHandle, obj)
                    checkmodel.buildDynamicObjectsGraph(handle, g, visited)
                end
            end
        elseif objType == 'forceSensor' then
            addEdge(g, parentHandle, handle)
        end
        checkmodel.buildDynamicObjectsGraph(handle, g, visited)
    end
    return g
end

local function graphToDot(graph)
    local lines = {}
    table.insert(lines, "graph G {")

    -- render nodes
    for id, node in pairs(graph) do
        local shape = "ellipse"
        if node.objType == "shape" then
            shape = "box"
        elseif node.objType == "joint" or node.objType == "forceSensor" then
            shape = "ellipse"
        end

        local color = (node.dynamic and "red" or "gray")
        local label = string.format("%s (%d)", node.alias or "?", id)

        table.insert(lines,
            string.format('  %d [label="%s", shape=%s, color=%s];',
                          id, label, shape, color))
    end

    -- render edges (undirected, deduplicated)
    local seen = {}
    for id, node in pairs(graph) do
        for _, target in ipairs(node.edges or {}) do
            local a, b = math.min(id, target), math.max(id, target)
            local key = a .. "-" .. b
            if not seen[key] then
                seen[key] = true
                table.insert(lines, string.format("  %d -- %d;", a, b))
            end
        end
    end

    table.insert(lines, "}")
    return table.concat(lines, "\n")
end

local function openFile(f)
    local platform = sim.getIntProperty(sim.handle_app, 'platform')
    local simSubprocess = require 'simSubprocess'
    if platform == 0 then
        -- windows
        simSubprocess.exec('cmd', {'/c', 'start', '', f})
    elseif platform == 1 then
        -- mac
        simSubprocess.exec('open', {f})
    elseif platform == 2 then
        -- linux
        simSubprocess.exec('xdg-open', {f})
    else
        error('unknown platform: ' .. platform)
    end
end

function checkmodel.showDynamicObjectsGraph(parentHandle, g, visited)
    local g = checkmodel.buildDynamicObjectsGraph()
    local outfile = sim.getStringProperty(sim.handle_app, 'tempPath') .. '/graph.png'
    local graphviz = require 'graphviz'
    graphviz.dot(graphToDot(g), outfile)
    openFile(outfile)
end

function checkmodel.check(modelHandle)
    local issues = {}

    local function report(handle, issue, ...)
        if not issues[handle] then issues[handle] = {} end
        table.insert(issues[handle], string.format(issue, ...))
    end

    if sim.getBoolProperty(modelHandle, 'model.notDynamic') then
        report(modelHandle, 'Model is not dynamic')
    end

    for _, handle in ipairs(sim.getObjectsInTree(modelHandle)) do
        if sim.getStringProperty(handle, 'objectType') == 'shape' and sim.getBoolProperty(handle, 'dynamic') then
            if not sim.getBoolProperty(handle, 'primitive') and not sim.getBoolProperty(handle, 'convex') then
                report(handle, 'Shape is dynamic and non-convex: simulation will be unstable')
            end
        end
    end

    return issues
end

return checkmodel
