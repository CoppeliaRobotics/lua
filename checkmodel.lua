local checkmodel = {}

local sim = require 'sim'
local Graph = require 'Graph'

local function getInfo(handle)
    local info = {
        dynamic = sim.getIntProperty(handle, 'dynamicFlag') > 0,
        alias = sim.getStringProperty(handle, 'alias'),
        objType = sim.getStringProperty(handle, 'objectType'),
    }
    local objType = sim.getStringProperty(handle, 'objectType')
    if objType == 'shape' then
        info.is = {}
        if sim.getBoolProperty(handle, 'primitive') then
            info.is.primitive = true
        elseif sim.getBoolProperty(handle, 'convex') then
            info.is.convex = true
        else
            info.is.non_convex = true
        end
        if shapeType and sim.getBoolProperty(handle, 'compound') then
            info.is.compound = true
        end
        info.mass = sim.getFloatProperty(handle, 'mass')
    elseif objType == 'joint' then
        info.dynCtrlMode = sim.getIntProperty(handle, 'dynCtrlMode')
    end
    return info
end

function checkmodel.buildObjectsGraph(parentHandle, g, visited)
    parentHandle = parentHandle or sim.handle_scene
    g = g or Graph(); visited = visited or {}

    if visited[parentHandle] then return else visited[parentHandle] = true end

    local function edge(a, b)
        for _, v in ipairs{a, b} do
            if not g:hasVertex(v) then g:addVertex(v, getInfo(v)) end
        end
        local va, vb = g:getVertex(a), g:getVertex(b)
        g:addEdge(a, b, {dynamic = va.dynamic and vb.dynamic})
    end

    for index = 0, 10000 do
        local handle = sim.getObjectChild(parentHandle, index)
        if handle == -1 then break end
        local objType = sim.getStringProperty(handle, 'objectType')
        if objType == 'shape' then
            edge(parentHandle, handle)
        elseif objType == 'joint' then
            edge(parentHandle, handle)
        elseif objType == 'dummy' then
            if sim.getIntProperty(handle, 'dummyType') == 0 then -- dyn-overlap
                local linkedDummy = sim.getIntProperty(handle, 'linkedDummyHandle')
                if linkedDummy ~= -1 then
                    local obj = sim.getObjectParent(linkedDummy)
                    edge(parentHandle, obj)
                    checkmodel.buildObjectsGraph(handle, g, visited)
                end
            end
            edge(parentHandle, handle)
        elseif objType == 'forceSensor' then
            edge(parentHandle, handle)
        end
        checkmodel.buildObjectsGraph(handle, g, visited)
    end
    return g
end

function checkmodel.buildDynamicObjectsGraph(parentHandle)
    local g = checkmodel.buildObjectsGraph(parentHandle)

    -- remove non-dynamic items:
    local staticV, staticE = {}, {}
    for _, id in ipairs(g:getAllVertices()) do
        local v = g:getVertex(id)
        if not v.dynamic then g:removeVertex(id) end
    end
    for _, ids in ipairs(g:getAllEdges()) do
        local e = g:getEdge(table.unpack(ids))
        if not e.dynamic then g:removeEdge(table.unpack(ids)) end
    end

    return g
end

function checkmodel.showObjectsGraph(g)
    local outFile = sim.getStringProperty(sim.handle_app, 'tempPath') .. '/graph.png'
    g:render{
        nodeStyle = function(id)
            local node = g:getVertex(id)
            local style = {}
            style.shape = "box"
            if node.objType == "joint" or node.objType == "forceSensor" then
                style.shape = "ellipse"
            end
            if node.dynamic then
                style.style = 'filled'
                style.fillcolor = 'lightgray'
            end
            style.color = node.dynamic and "black" or "gray"
            style.label = string.format("%s (%d)", node.alias or "?", id)
            local extraInfo = {}
            if node.objType == 'dummy' then
                table.insert(extraInfo, 'type=dummy')
            end
            if node.is then
                local s = {}
                for k in pairs(node.is) do table.insert(s, k) end
                table.insert(extraInfo, table.concat(s, ', '))
            end
            for _, k in ipairs{'mass', 'dynCtrlMode'} do
                if node[k] then
                    table.insert(extraInfo, k .. '=' .. node[k])
                end
            end
            if #extraInfo > 0 then
                style.label = '< <TABLE BORDER="0" CELLBORDER="0" CELLSPACING="0"><TR><TD>' .. style.label .. '</TD></TR><TR><TD><FONT POINT-SIZE="10">' .. table.concat(extraInfo, '<BR/>') .. '</FONT></TD></TR></TABLE> >'
            else
                style.label = '"' .. style.label .. '"'
            end
            return style
        end,
        edgeStyle = function(id1, id2)
            local edge = g:getEdge(id1, id2)
            local style = {}
            style.color = edge.dynamic and 'black' or 'gray'
            return style
        end,
        outFile = outFile,
    }
    sim.openFile(outFile)
end

function checkmodel.checkConnectedComponentMasses(cc, maxRatioLimit, report, removed)
    removed = removed or {}

    local function maxRatio(a, b)
        return math.max(a/b, b/a)
    end

    local function score(mass)
        local maximalMaxRatio = 0
        local numViolations = 0
        for _, id in ipairs(cc:getAllVertices()) do
            local v = cc:getVertex(id)
            if not removed[id] and v.mass then
                local mr = maxRatio(mass, v.mass)
                if mr > maxRatioLimit then
                    numViolations = numViolations + 1
                    maximalMaxRatio = math.max(maximalMaxRatio, mr)
                end
            end
        end
        return numViolations * maximalMaxRatio
    end

    local scores = {}
    for _, id in ipairs(cc:getAllVertices()) do
        local v = cc:getVertex(id)
        if not removed[id] and v.mass then
            table.insert(scores, {id, v.mass, score(v.mass)})
        end
    end
    table.sort(scores, function(a, b) return a[3] > b[3] end)
    assert(#scores > 0, 'empty')

    local topScore = scores[1]
    if topScore[3] > 0 then
        report(topScore[1], string.format('mass of %f is inbalanced with respect to neighboring objects', topScore[2]))
        removed[topScore[1]] = true
        checkmodel.checkConnectedComponentMasses(cc, maxRatioLimit, report, removed)
    end
end

function checkmodel.check(modelHandle)
    local issues = {}

    local function report(handle, issue, ...)
        if not issues[handle] then issues[handle] = {} end
        table.insert(issues[handle], string.format(issue, ...))
    end

    local g = checkmodel.buildDynamicObjectsGraph(modelHandle)

    if sim.getBoolProperty(modelHandle, 'model.notDynamic') then
        report(modelHandle, 'Model is not dynamic')
    end

    for _, id in ipairs(g:getAllVertices()) do
        local v = g:getVertex(id)
        if v.objType == 'shape' and v.dynamic then
            if not v.is.primitive and not v.is.convex then
                report(id, 'Shape is dynamic and non-convex: simulation will be unstable')
            end
        end
    end

    for i, cc in ipairs(g:connectedComponents()) do
        checkmodel.checkConnectedComponentMasses(cc, 10, report)
    end

    for _, id in ipairs(g:getAllVertices()) do
        if sim.getStringProperty(id, 'objectType') == 'shape' then
            local bb = sim.getVector3Property(id, 'bbHSize')
            local com = map(math.abs, sim.getVector3Property(id, 'centerOfMass'))
            if com[1] > bb[1] or com[2] > bb[2] or com[3] > bb[3] then
                report(id, 'Center of mass is outside shape bounding box')
            end
        end
    end

    return issues
end

return checkmodel
