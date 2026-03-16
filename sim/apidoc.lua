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

local apidoc = {}

function apidoc.path(filename)
    local lfsx = require 'lfsx'
    return lfsx.pathjoin(sim.app.resourcePath, 'manual', 'apiDoc', filename)
end

function apidoc.xmltree(filename)
    local objxmlfile = io.open(apidoc.path(filename), 'r')
    assert(objxmlfile)
    local objxml = objxmlfile:read '*a'
    objxmlfile:close()
    return xml.parse(objxml)
end

apidoc.ParamInfo = class 'sim.apidoc.ParamInfo'

function apidoc.ParamInfo:initialize(methodInfo, node, acceptsDefaults)
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

apidoc.MethodInfo = class 'sim.apidoc.MethodInfo'

function apidoc.MethodInfo:initialize(classInfo, node)
    assert(node.tag == 'method', 'invalid node tag')
    assert(node.attr.name, 'missing "name" attribute')
    self.classInfo = classInfo
    self.name = node.attr.name
    self.params = {}
    self.returns = {}
    for _, subNode in ipairs(node) do
        if subNode.tag == 'params' then
            for _, paramNode in ipairs(subNode) do
                if paramNode.tag == 'param' then
                    table.insert(self.params, apidoc.ParamInfo(self, paramNode, true))
                end
            end
        elseif subNode.tag == 'returns' then
            for _, paramNode in ipairs(subNode) do
                if paramNode.tag == 'param' then
                    table.insert(self.returns, apidoc.ParamInfo(self, paramNode))
                end
            end
        elseif subNode.tag == 'description' then
            self.description = getChildrenXML(subNode)
        end
    end
end

function apidoc.MethodInfo:__tostring()
    return self.class.name .. '(name = ' .. self.name .. ')'
end

function apidoc.MethodInfo:getCallTip(types)
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

function apidoc.MethodInfo:getParamsDoc(params)
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

apidoc.ClassInfo = class 'sim.apidoc.ClassInfo'

function apidoc.ClassInfo:initialize(classesInfo, node)
    assert(node.tag == 'object-class', 'invalid node tag')
    assert(node.attr.name, 'missing "name" attribute')
    self.classesInfo = classesInfo
    self.className = node.attr.name
    self.superClassName = node.attr.superclass
    self.methods = {}
    for _, subNode in ipairs(node) do
        if subNode.tag == 'method' then
            local info = apidoc.MethodInfo(self, subNode)
            self.methods[info.name] = info
        end
    end
end

function apidoc.ClassInfo:__tostring()
    return self.class.name .. '(className = ' .. self.className .. ')'
end

function apidoc.ClassInfo:getSuperClass()
    return self.classesInfo:getClass(self.superClassName)
end

function apidoc.ClassInfo:getMethod(methodName)
    local c = self
    while c do
        if c.methods[methodName] then
            return c.methods[methodName]
        end
        c = c:getSuperClass()
    end
end

apidoc.ClassesInfo = class 'sim.apidoc.ClassesInfo'

function apidoc.ClassesInfo:initialize()
    self.classes = {}
    for _, node in ipairs(apidoc.xmltree 'objects.xml') do
        if node.tag == 'object-class' then
            local info = apidoc.ClassInfo(self, node)
            self.classes[info.className] = info
        end
    end
end

function apidoc.ClassesInfo:getClass(className)
    return self.classes[className]
end

function apidoc.ClassesInfo:getMethod(className, methodName)
    local c = self:getClass(className)
    if c then return c:getMethod(methodName) end
end

return apidoc