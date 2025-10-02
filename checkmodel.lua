local checkmodel = {}

local sim = require 'sim'
local Graph = require 'Graph'

local function getInfo(handle)
    local info = {
        dynamic = sim.getIntProperty(handle, 'dynamicFlag') > 0,
        alias = sim.getStringProperty(handle, 'alias'),
        objType = sim.getStringProperty(handle, 'objectType'),
    }
    local extraInfo = {}
    local objType = sim.getStringProperty(handle, 'objectType')
    if objType == 'shape' then
        if sim.getBoolProperty(handle, 'primitive') then
            table.insert(extraInfo, 'primitive')
        elseif sim.getBoolProperty(handle, 'convex') then
            table.insert(extraInfo, 'convex')
        else
            table.insert(extraInfo, 'non-convex')
        end
        if sim.getBoolProperty(handle, 'compound') then
            table.insert(extraInfo, 'compound')
        end
    elseif objType == 'joint' then
        table.insert(extraInfo, 'dynCtrlMode=' .. sim.getIntProperty(handle, 'dynCtrlMode'))
    end
    if #extraInfo > 0 then
        info.info = table.concat(extraInfo, ', ')
    end
    return info
end

function checkmodel.buildDynamicObjectsGraph(parentHandle, g, visited)
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
                    checkmodel.buildDynamicObjectsGraph(handle, g, visited)
                end
            end
        elseif objType == 'forceSensor' then
            edge(parentHandle, handle)
        end
        checkmodel.buildDynamicObjectsGraph(handle, g, visited)
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

function checkmodel.showDynamicObjectsGraph(parentHandle, g, visited)
    local g = checkmodel.buildDynamicObjectsGraph(parentHandle)
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

            style.color = node.dynamic and "black" or "gray"
            style.label = string.format("%s (%d)", node.alias or "?", id)
            if node.info then
                style.label = '< <TABLE BORDER="0" CELLBORDER="0" CELLSPACING="0"><TR><TD>' .. style.label .. '</TD></TR><TR><TD><FONT POINT-SIZE="10">' .. node.info .. '</FONT></TD></TR></TABLE> >'
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
