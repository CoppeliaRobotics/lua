local class = require 'middleclass'
local sim = require 'sim-2'
local xml = require 'pl.xml'

local function getChildrenXML(root)
    local children_xml = {}
    for i = 1, #root do
        local child = root[i]
        if type(child) == "table" then
            table.insert(children_xml, xml.tostring(child))
        else
            table.insert(children_xml, tostring(child)) -- text node
        end
    end
    return table.concat(children_xml)
end

local ParamInfo = class 'sim.apidoc.ParamInfo'

function ParamInfo:initialize(methodInfo, node, acceptsDefaults)
    assert(node.tag == 'param', 'invalid node tag')
    assert(node.attr.name, 'missing "name" attribute')
    assert(node.attr.type, 'missing "type" attribute')
    self.methodInfo = methodInfo
    self.name = node.attr.name
    self.type = node.attr.type
    if acceptsDefaults then
        self.default = node.attr.default
    end
    for _, descriptionNode in ipairs(node) do
        if descriptionNode.tag == 'description' then
            self.description = getChildrenXML(descriptionNode)
        end
    end
end

local MethodInfo = class 'sim.apidoc.MethodInfo'

function MethodInfo:initialize(classInfo, node, tag)
    assert(node.tag == tag, 'invalid node tag')
    assert(node.attr.name, 'missing "name" attribute')
    self.classInfo = classInfo
    self.name = node.attr.name
    self.lang = node.attr.lang
    self.params = {}
    self.returns = {}
    self.categories = {}
    self.related = {}
    for _, subNode in ipairs(node) do
        if subNode.tag == 'params' then
            for _, paramNode in ipairs(subNode) do
                if paramNode.tag == 'param' then
                    table.insert(self.params, ParamInfo(self, paramNode, true))
                end
            end
        elseif subNode.tag == 'returns' then
            for _, paramNode in ipairs(subNode) do
                if paramNode.tag == 'param' then
                    table.insert(self.returns, ParamInfo(self, paramNode))
                end
            end
        elseif subNode.tag == 'description' then
            self.description = getChildrenXML(subNode)
        elseif subNode.tag == 'categories' then
            for _, categoryNode in ipairs(subNode) do
                if categoryNode.tag == 'category' then
                    self.categories[categoryNode.attr.name] = true
                end
            end
        elseif subNode.tag == 'see-also' then
            for _, refNode in ipairs(subNode) do
                if refNode.tag == 'function-ref' then
                    table.insert(self.related, {refNode.tag, refNode.attr.name})
                elseif refNode.tag == 'link' then
                    table.insert(self.related, {refNode.tag, refNode.attr.href})
                end
            end
        end
    end
end

function MethodInfo:__tostring()
    return self.class.name .. '(name = ' .. self.name .. ')'
end

function MethodInfo:getCallTip(types)
    local x = ''
    for i, p in ipairs(self.returns) do
        if i > 1 then x = x .. ', ' end
        if types then
            x = x .. '<span style="color: #00c;">' .. p.type .. '</span> '
        end
        x = x .. '<span style="color: #999;">' .. p.name .. '</span>'
    end
    x = x .. '</span>'
    if #self.returns > 0 then
        x = x .. '<span style="color: #ccc;"> = </span>'
    end
    x = x .. '<b>' .. self.name .. '</b>('
    x = x .. '<span style="color: #ddd;">'
    for i, p in ipairs(self.params) do
        if i > 1 then x = x .. ', ' end
        if types then
            x = x .. '<span style="color: #00c;">' .. p.type .. '</span> '
        end
        x = x .. '<span style="color: #999;">' .. p.name .. '</span>'
        if p.default then
            x = x .. '<span style="color: #ccc;">=' .. p.default .. '</span>'
        end
    end
    x = x .. '</span>'
    x = x .. ')'
    return x
end

function MethodInfo:getParamsDoc(params)
    if #params == 0 then return '' end
    local x = '<ul>'
    for i, p in ipairs(params) do
        x = x .. '<li>'
        x = x .. '<b>' .. p.name .. '</b>'
        x = x .. ' (<span style="color: #00c;">' .. p.type .. '</span>'
        if p.default then
            x = x .. ', <span style="color: #ccc;">default: ' .. p.default .. '</span>'
        end
        x = x .. ')'
        if p.description then
            x = x .. ': ' .. p.description
        end
        x = x .. '</li>'
    end
    x = x .. '</ul>'
    return x
end

local ClassInfo = class 'sim.apidoc.ClassInfo'

function ClassInfo:initialize(node)
    assert(node.tag == 'object-class', 'invalid node tag')
    assert(node.attr.name, 'missing "name" attribute')
    self.className = node.attr.name
    self.superClassName = node.attr.superclass
    self.methods = {}
    for _, subNode in ipairs(node) do
        if subNode.tag == 'method' then
            local info = MethodInfo(self, subNode, 'method')
            self.methods[info.name] = info
        end
    end
end

function ClassInfo:__tostring()
    return self.class.name .. '(className = ' .. self.className .. ')'
end

function ClassInfo:getSuperClass()
    return apidoc.getClass(self.superClassName)
end

function ClassInfo:getMethod(methodName)
    local c = self
    while c do
        if c.methods[methodName] then
            return c.methods[methodName]
        end
        c = c:getSuperClass()
    end
end

local EnumInfo = class 'sim.apidoc.EnumInfo'

function EnumInfo:initialize(node)
    assert(node.tag == 'enum', 'invalid node tag')
    assert(node.attr.name, 'missing "name" attribute')
    self.name = node.attr.name
    self.label = node.attr.label

    local items = {}
    local v = 0
    for _, subNode in ipairs(node) do
        if subNode.tag == 'item' then
            assert(subNode.attr.name, 'missing "name" attribute')
            local name = subNode.attr.name
            local value = tonumber(subNode.attr.value) or v
            v = value + 1
            items[name] = value
        end
    end

    self.items = setmetatable(
        {},
        {
            __tostring = function()
                return self.class.name .. ' ' .. self.name .. ' items'
            end,
            __pairs = function()
                return pairs(items)
            end,
            __index = function(self, k)
                if type(k) == 'string' then
                    return items[k]
                elseif math.type(k) == 'integer' then
                    for name, value in pairs(items) do
                        if value == k then return name end
                    end
                end
            end,
        }
    )
end

local function xmltree(filename)
    local lfsx = require 'lfsx'
    local filepath = lfsx.pathjoin(sim.app.paths.resources, 'programming', 'include', 'sim', filename)
    local objxmlfile = io.open(filepath, 'r')
    assert(objxmlfile)
    local objxml = objxmlfile:read '*a'
    objxmlfile:close()
    return xml.parse(objxml)
end

local classes = {}
for _, node in ipairs(xmltree 'objects.xml') do
    if node.tag == 'object-class' then
        local info = ClassInfo(node)
        classes[info.className] = info
    end
end

local functions = {}
for _, node in ipairs(xmltree 'functions.xml') do
    if node.tag == 'function' then
        local info = MethodInfo(nil, node, 'function')
        functions[info.name] = info
    end
end

local enums = {}
for _, node in ipairs(xmltree 'enums.xml') do
    if node.tag == 'enum' then
        local info = EnumInfo(node, 'enum')
        enums[info.name] = info
    end
end

local apidoc = {}

function apidoc.getClass(className)
    return classes[className]
end

function apidoc.getMethod(className, methodName)
    local c = apidoc.getClass(className)
    if c then return c:getMethod(methodName) end
end

function apidoc.getClassHierarchyGraph()
    local Graph = require 'Graph'
    local g = Graph(true)
    for _, classInfo in pairs(classes) do
        g:addVertex(classInfo.className)
    end
    for _, classInfo in pairs(classes) do
        if classInfo.superClassName then
            g:addEdge(classInfo.className, classInfo.superClassName)
        end
    end
    return g
end

function apidoc.getFunction(functionName)
    return functions[functionName]
end

function apidoc.getEnum(enumName)
    return enums[enumName]
end

return apidoc
