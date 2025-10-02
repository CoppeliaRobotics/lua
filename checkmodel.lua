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
        local shapeType
        if sim.getBoolProperty(handle, 'primitive') then
            shapeType = 'primitive'
        elseif sim.getBoolProperty(handle, 'convex') then
            shapeType = 'convex'
        else
            shapeType = 'non-convex'
        end
        if shapeType and sim.getBoolProperty(handle, 'compound') then
            shapeType = shapeType .. ', compound'
        end
        local massInfo = 'mass=' .. sim.getFloatProperty(handle, 'mass')
        info.info = {shapeType, massInfo}
    elseif objType == 'joint' then
        info.info = {'dynCtrlMode=' .. sim.getIntProperty(handle, 'dynCtrlMode')}
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
        --if not v.dynamic then table.insert(staticV, id) end
        if not v.dynamic then g:removeVertex(id) end
    end
    for _, ids in ipairs(g:getAllEdges()) do
        local e = g:getEdge(table.unpack(ids))
        --if not e.dynamic then table.insert(staticE, ids) end
        if not e.dynamic then g:removeEdge(table.unpack(ids)) end
    end

    return g
end

function checkmodel.openFile(f)
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

function checkmodel.showObjectsGraph(g)
    local outFile = sim.getStringProperty(sim.handle_app, 'tempPath') .. '/graph.png'
    g:render{
        nodeStyle = function(id)
            local node = g:getVertex(id)
            local style = {}
            style.shape = "ellipse"
            if node.objType == "shape" then
                style.shape = "box"
            elseif node.objType == "joint" or node.objType == "forceSensor" then
                style.shape = "ellipse"
            end
            if node.dynamic then
                style.style = 'filled'
                style.fillcolor = 'lightgray'
            end
            style.color = node.dynamic and "black" or "gray"
            style.label = string.format("%s (%d)", node.alias or "?", id)
            if node.info and #node.info > 0 then
                style.label = '< <TABLE BORDER="0" CELLBORDER="0" CELLSPACING="0"><TR><TD>' .. style.label .. '</TD></TR><TR><TD><FONT POINT-SIZE="10">' .. table.concat(node.info, '<BR/>') .. '</FONT></TD></TR></TABLE> >'
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
    checkmodel.openFile(outFile)
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
