local class = require 'middleclass'

local Graph = class 'Graph'

function Graph:initialize(directed)
    self.directed = directed or false
    self.vertices = {}
    self.edges = {}
    self.adjacency = {} -- adjacency list for efficient edge lookups
end

function Graph:union(g2)
    for _, id in ipairs(g2:getAllVertices()) do
        self:addVertex(id, g2:getVertex(id))
    end
    for _, ids in ipairs(g2:getAllEdges()) do
        self:addEdge(ids[1], ids[2], g2:getEdge(ids[1], ids[2]))
    end
end

-- Add a vertex with optional info
function Graph:addVertex(id, info)
    assert(self.vertices[id] == nil, 'vertex already exists')

    self.vertices[id] = info or {}
    self.adjacency[id] = {}

    return true
end

-- Remove a vertex and all connected edges
function Graph:removeVertex(id)
    if not self.vertices[id] then
        return false
    end

    -- Remove all outgoing edges
    for targetId, _ in pairs(self.adjacency[id]) do
        self:removeEdge(id, targetId)
    end

    -- Remove all incoming edges
    for sourceId, targets in pairs(self.adjacency) do
        if targets[id] then
            self:removeEdge(sourceId, id)
        end
    end

    self.vertices[id] = nil
    self.adjacency[id] = nil

    return true
end

-- Retrieve a vertex by id
function Graph:getVertex(id)
    return self.vertices[id]
end

-- Check if vertex exists
function Graph:hasVertex(id)
    return self.vertices[id] ~= nil
end

-- Add an edge with optional info
function Graph:addEdge(id1, id2, info)
    assert(self.vertices[id1] ~= nil, 'vertex ' .. id1 .. ' doesn\'t exist')
    assert(self.vertices[id2] ~= nil, 'vertex ' .. id2 .. ' doesn\'t exist')

    local edgeKey = self:_getEdgeKey(id1, id2)
    local reverseKey = self:_getEdgeKey(id2, id1)

    -- Check if edge already exists
    if self.edges[edgeKey] then
        return false
    end

    self.edges[edgeKey] = info or {}
    self.adjacency[id1][id2] = edgeKey

    -- For undirected graphs, add the reverse edge
    if not self.directed and id1 ~= id2 then
        self.edges[reverseKey] = info or {}
        self.adjacency[id2][id1] = reverseKey
    end

    return true
end

-- Remove an edge
function Graph:removeEdge(id1, id2)
    local edgeKey = self:_getEdgeKey(id1, id2)
    local reverseKey = self:_getEdgeKey(id2, id1)

    if not self.edges[edgeKey] then
        return false
    end

    -- Remove the edge
    self.edges[edgeKey] = nil
    self.adjacency[id1][id2] = nil

    -- For undirected graphs, remove the reverse edge too
    if not self.directed and self.edges[reverseKey] then
        self.edges[reverseKey] = nil
        self.adjacency[id2][id1] = nil
    end

    return true
end

-- Retrieve an edge by source and target
function Graph:getEdge(id1, id2)
    local edgeKey = self:_getEdgeKey(id1, id2)
    return self.edges[edgeKey]
end

-- Check if edge exists
function Graph:hasEdge(id1, id2)
    return self:getEdge(id1, id2) ~= nil
end

-- Get all outgoing edges from a vertex
function Graph:getOutEdges(id)
    if not self.adjacency[id] then
        return {}
    end

    local outEdges = {}
    for targetId, edgeKey in pairs(self.adjacency[id]) do
        table.insert(outEdges, targetId)
    end

    return outEdges
end

-- Get all incoming edges to a vertex
function Graph:getInEdges(id)
    local inEdges = {}

    for sourceId, targets in pairs(self.adjacency) do
        if targets[id] then
            local edgeKey = targets[id]
            table.insert(inEdges, sourceId)
        end
    end

    return inEdges
end

function Graph:connectedComponents(strongly)
    local visited = {}
    local components = {}

    local function dfs(u, vertices, useDirs)
        visited[u] = true
        table.insert(vertices, u)

        local neighbors = {}
        if useDirs then
            neighbors = self:getOutEdges(u)
        else
            -- weakly connected (or undirected)
            local outs = self:getOutEdges(u)
            local ins = self:getInEdges(u)
            local seen = {}
            for _, v in ipairs(outs) do seen[v] = true end
            for _, v in ipairs(ins) do seen[v] = true end
            for v,_ in pairs(seen) do table.insert(neighbors, v) end
        end

        for _, v in ipairs(neighbors) do
            if not visited[v] then
                dfs(v, vertices, useDirs)
            end
        end
    end

    local function buildSubgraph(vertices)
        local g = Graph(self:isDirected())
        -- clone vertices
        for _, v in ipairs(vertices) do
            g:addVertex(v, self:getVertex(v))
        end
        -- clone edges (only inside this component)
        for _, v in ipairs(vertices) do
            for _, w in ipairs(self:getOutEdges(v)) do
                if g:hasVertex(w) then
                    g:addEdge(v, w, self:getEdge(v, w))
                end
            end
        end
        return g
    end

    if not self:isDirected() then
        -- undirected graph
        for _, v in ipairs(self:getAllVertices()) do
            if not visited[v] then
                local verts = {}
                dfs(v, verts, false)
                table.insert(components, buildSubgraph(verts))
            end
        end
    else
        if strongly then
            -- Kosaraju SCC
            local order = {}
            local visited1 = {}

            local function dfs1(u)
                visited1[u] = true
                for _, v in ipairs(self:getOutEdges(u)) do
                    if not visited1[v] then dfs1(v) end
                end
                table.insert(order, u)
            end

            for _, v in ipairs(self:getAllVertices()) do
                if not visited1[v] then dfs1(v) end
            end

            local visited2 = {}
            local function dfs2(u, verts)
                visited2[u] = true
                table.insert(verts, u)
                for _, v in ipairs(self:getInEdges(u)) do
                    if not visited2[v] then dfs2(v, verts) end
                end
            end

            for i = #order, 1, -1 do
                local v = order[i]
                if not visited2[v] then
                    local verts = {}
                    dfs2(v, verts)
                    table.insert(components, buildSubgraph(verts))
                end
            end
        else
            -- weakly connected components
            for _, v in ipairs(self:getAllVertices()) do
                if not visited[v] then
                    local verts = {}
                    dfs(v, verts, false)
                    table.insert(components, buildSubgraph(verts))
                end
            end
        end
    end

    return components
end

-- Private helper method to generate edge keys
function Graph:_getEdgeKey(id1, id2)
    return id1 .. "->" .. id2
end

-- Additional utility methods

-- Check if graph is directed
function Graph:isDirected()
    return self.directed
end

-- Get all vertices
function Graph:getAllVertices()
    local vertices = {}
    for id, _ in pairs(self.vertices) do
        table.insert(vertices, id)
    end
    return vertices
end

-- Get all edges
function Graph:getAllEdges()
    local edges = {}
    for id1, adj in pairs(self.adjacency) do
        for id2, _ in pairs(adj) do
            table.insert(edges, {id1, id2})
        end
    end
    return edges
end

-- Get number of vertices
function Graph:vertexCount()
    local count = 0
    for _ in pairs(self.vertices) do
        count = count + 1
    end
    return count
end

-- Get number of edges
function Graph:edgeCount()
    local count = 0
    for _ in pairs(self.edges) do
        count = count + 1
    end
    return count
end

-- Render to image
function Graph:render(opts)
    local gvdoc = self:tographviz(opts)
    return Graph:dot(gvdoc, opts.outFile)
end

-- Render to a dot file
function Graph:tographviz(opts)
    opts = opts or {}
    opts.nodeStyle = opts.nodeStyle or function(id) return {} end
    opts.edgeStyle = opts.edgeStyle or function(id1, id2) return {} end

    local lines = {}
    table.insert(lines, (self:isDirected() and 'di' or '') .. 'graph G {')

    local function styleTxt(s)
        if next(s) == nil then return '' end
        local ret = {}
        for k, v in pairs(s) do
            table.insert(ret, k .. '=' .. v)
        end
        return ' [' .. table.concat(ret, ', ') .. ']'
    end

    -- render nodes
    for _, id in ipairs(self:getAllVertices()) do
        local nodeStyle = opts.nodeStyle(id)
        table.insert(lines, string.format('  %d%s;', id, styleTxt(nodeStyle)))
    end

    -- render edges (undirected, deduplicated)
    local arrow = self:isDirected() and '->' or '--'
    local seen = {}
    for _, ids in ipairs(self:getAllEdges()) do
        local id1, id2 = table.unpack(ids)
        if not self:isDirected() then
            id1, id2 = math.min(id1, id2), math.max(id1, id2)
        end
        local edgeStyle = opts.edgeStyle(id1, id2)
        local key = id1 .. '-' .. id2
        if not seen[key] then
            seen[key] = true
            table.insert(lines, string.format('  %d %s %d%s;', id1, arrow, id2, styleTxt(edgeStyle)))
        end
    end

    table.insert(lines, '}')
    return table.concat(lines, '\n')
end

-- Render a dot file to image
function Graph.static:dot(doc, outFile)
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
    if ec ~= 0 then error('dot failed (' .. err .. '), dot source: ' .. doc) end
    if not outFile then
        -- result image is written to stdout
        return out
    end
end

return Graph
