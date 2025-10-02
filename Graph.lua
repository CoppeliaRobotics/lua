local class = require 'middleclass'

local Graph = class 'Graph'

function Graph:initialize(directed)
    self.directed = directed or false
    self.vertices = {}
    self.edges = {}
    self.adjacency = {} -- adjacency list for efficient edge lookups
end

-- Add a vertex with optional info
function Graph:addVertex(id, info)
    if self.vertices[id] then
        return false -- vertex already exists
    end

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

-- Add an edge with optional info
function Graph:addEdge(id1, id2, info)
    -- Ensure both vertices exist
    if not self.vertices[id1] then
        self:addVertex(id1)
    end
    if not self.vertices[id2] then
        self:addVertex(id2)
    end

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

-- Compute connected components using BFS
function Graph:connectedComponents()
    if self.directed then
        return self:_weaklyConnectedComponents()
    else
        return self:_undirectedConnectedComponents()
    end
end

-- Private method for undirected graph connected components
function Graph:_undirectedConnectedComponents()
    local visited = {}
    local components = {}

    for vertexId, _ in pairs(self.vertices) do
        if not visited[vertexId] then
            local component = Graph:new(self.directed)
            local queue = {vertexId}
            visited[vertexId] = true

            while #queue > 0 do
                local currentId = table.remove(queue, 1)
                component:addVertex(currentId, self.vertices[currentId].info)

                -- Add all neighbors to the queue
                for neighborId, edgeKey in pairs(self.adjacency[currentId]) do
                    if not visited[neighborId] then
                        visited[neighborId] = true
                        table.insert(queue, neighborId)

                        -- Add the edge to the component
                        local info = self.edges[edgeKey]
                        component:addEdge(currentId, neighborId, info)
                    elseif component:getVertex(neighborId) then
                        -- If neighbor is already in component, ensure edge is added
                        if not component:getEdge(currentId, neighborId) then
                            local info = self.edges[edgeKey]
                            component:addEdge(currentId, neighborId, info)
                        end
                    end
                end
            end

            table.insert(components, component)
        end
    end

    return components
end

-- Private method for weakly connected components in directed graphs
function Graph:_weaklyConnectedComponents()
    local visited = {}
    local components = {}

    for vertexId, _ in pairs(self.vertices) do
        if not visited[vertexId] then
            local component = Graph:new(self.directed)
            local queue = {vertexId}
            visited[vertexId] = true

            while #queue > 0 do
                local currentId = table.remove(queue, 1)
                component:addVertex(currentId, self.vertices[currentId].info)

                -- Add outgoing neighbors
                for targetId, edgeKey in pairs(self.adjacency[currentId]) do
                    if not visited[targetId] then
                        visited[targetId] = true
                        table.insert(queue, targetId)
                    end

                    -- Add the edge to component if both vertices are in component
                    if component:getVertex(targetId) then
                        local info = self.edges[edgeKey]
                        component:addEdge(currentId, targetId, info)
                    end
                end

                -- Add incoming neighbors (for weak connectivity)
                for sourceId, targets in pairs(self.adjacency) do
                    if targets[currentId] and not visited[sourceId] then
                        visited[sourceId] = true
                        table.insert(queue, sourceId)
                    end
                end
            end

            table.insert(components, component)
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

-- Check if vertex exists
function Graph:hasVertex(id)
    return self.vertices[id] ~= nil
end

-- Check if edge exists
function Graph:hasEdge(id1, id2)
    return self:getEdge(id1, id2) ~= nil
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
    table.insert(lines, 'graph G {')

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
    local seen = {}
    for _, ids in ipairs(self:getAllEdges()) do
        local id1, id2 = table.unpack(ids)
        local edgeStyle = opts.edgeStyle(id1, id2)
        local a, b = math.min(id1, id2), math.max(id1, id2)
        local key = a .. '-' .. b
        if not seen[key] then
            seen[key] = true
            table.insert(lines, string.format('  %d -- %d%s;', a, b, styleTxt(edgeStyle)))
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
    if ec ~= 0 then error('dot failed: ' .. err) end
    if not outFile then
        -- result image is written to stdout
        return out
    end
end

return Graph
