local class = require 'middleclass'
local sim = require 'sim-2'
local xml = require 'pl.xml'

local apidoc = {}

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

local function xmlFind(node, tag)
    for _, subnode in ipairs(node) do
        if subnode.tag == tag then
            return subnode
        end
    end
end

local function xmlFindAll(node, tag)
    local ret = {}
    for _, subnode in ipairs(node) do
        if subnode.tag == tag then
            table.insert(ret, subnode)
        end
    end
    return ret
end

local function xmlText(node)
    for _, subnode in ipairs(node) do
        if type(subnode) == 'string' then
            return subnode
        end
    end
end

local function boolFromStr(s, def)
    if s == nil and def ~= nil then return def end
    if s == 'true' then return true end
    if s == 'false' then return false end
    error('invalid value for bool: "' .. s .. '"')
end

local PropertyFlags = class 'sim.apidoc.PropertyFlags'

function PropertyFlags:initialize(propertyInfo, node)
    self.propertyInfo = propertyInfo
    self.readable = false
    self.writable = false
    self.removable = false
    self.silent = false
    self.constant = false
    self.deprecated = false

    if node then
        assert(node.tag == 'flags', 'invalid node tag')
        self.readable = boolFromStr(node.attr.readable, self.readable)
        self.writable = boolFromStr(node.attr.writable, self.writable)
        self.removable = boolFromStr(node.attr.removable, self.removable)
        self.silent = boolFromStr(node.attr.silent, self.silent)
        self.constant = boolFromStr(node.attr.constant, self.constant)
        self.deprecated = boolFromStr(node.attr.deprecated, self.deprecated)
    end
end

function PropertyFlags:__tostring()
    return self.class.name .. '(...)'
end

local PropertyInfo = class 'sim.apidoc.PropertyInfo'

function PropertyInfo:initialize(classInfo, node)
    assert(node.tag == 'property', 'invalid node tag')
    assert(node.attr.name, 'missing "name" attribute')
    assert(node.attr.type, 'missing "type" attribute')

    self.classInfo = classInfo
    self.name = node.attr.name
    self.type = node.attr.type
    self.flags = PropertyFlags(self, xmlFind(node, 'flags'))
    self.label = ''
    self.description = ''
    self.replacedBy = nil
    self.migrateTo = nil
    self.supersedes = nil
    self.enum = nil
    self.var = node.attr.var
    self.aux = {}
    if node.attr.aux then
        self.aux = string.split(node.attr.aux, ',')
    end

    local supportNode = xmlFind(node, 'support')
    if supportNode then
        self.startSupport = supportNode.attr.start
        self.endSupport = supportNode.attr['end']
        self.startDeprecated = supportNode.attr['start-deprecated']
    end

    local replacedByNode = xmlFind(node, 'replaced-by')
    if replacedByNode then
        assert(replacedByNode.attr.name, 'missing "name" attribute in <replaced-by>')
        self.replacedBy = replacedByNode.attr.name
    end

    local migrateToNode = xmlFind(node, 'migrate-to')
    if migrateToNode then
        assert(migrateToNode.attr.name, 'missing "name" attribute in <migrate-to>')
        self.migrateTo = migrateToNode.attr.name
    end

    local supersedesNode = xmlFind(node, 'supersedes')
    if supersedesNode then
        self.supersedes = {}
        for _, itemNode in ipairs(xmlFindAll(supersedesNode, 'item')) do
            assert(itemNode.attr.name, 'missing "name" attribute in <supersedes>/<item>')
            table.insert(self.supersedes, itemNode.attr.name)
        end
    end

    local labelNode = xmlFind('label')
    if labelNode then
        self.label = xmlText(labelNode)
    end

    local descriptionNode = xmlFind('description')
    if descriptionNode then
        self.description = xmlText(descriptionNode)
    end

    local handleNode = xmlFind(node, 'handle')
    if handleNode then
        self.handleType = handleNode.attr['type']
    end

    local enumNode = xmlFind(node, 'enum')
    if enumNode then
        self.enum = enumNode.attr.name
    end
end

function PropertyInfo:__tostring()
    return tostring(self.classInfo) .. ', property ' .. self.name
end

local NamespaceInfo = class 'sim.apidoc.NamespaceInfo'

function NamespaceInfo:initialize(classInfo, node, acceptsDefaults)
    assert(node.tag == 'namespace', 'invalid node tag')
    assert(node.attr.name, 'missing "name" attribute')

    self.classInfo = classInfo
    self.name = node.attr.name
    self.newPropertyForcedType = node.attr['new-property-forced-type']
    self.deprecated = boolFromStr(node.attr.deprecated, false)
end

local ParamInfo = class 'sim.apidoc.ParamInfo'

function ParamInfo:initialize(methodInfo, node, acceptsDefaults, parent, xtype)
    assert(node.tag == 'param', 'invalid node tag')
    assert(node.attr.name, 'missing "name" attribute')
    assert(node.attr.type, 'missing "type" attribute')

    self.methodInfo = methodInfo
    self.array = false
    self.itemType, self.size = nil, nil
    if parent then
        self.name = parent.name
        self.type = xtype
        return
    end
    self.name = node.attr.name
    self.type = node.attr.type
    local itemType, size = self.type:match("^(%w+)%[(%d*)%]$")
    if itemType then
        self.array = true
        self.itemType = ParamInfo(minfo, node, acceptsDefaults, self, itemType)
        self.size = size ~= "" and tonumber(size) or nil
        self.type = self.itemType.type .. "array" .. (self.size or "")
    end
    self.description = ''

    if acceptsDefaults then
        self.default = node.attr.default
    elseif node.attr.default then
        error 'attribute "default" not allowed here'
    end

    local descriptionNode = xmlFind(node, 'description')
    if descriptionNode then
        self.description = getChildrenXML(descriptionNode)
    end
end

local MethodInfo = class 'sim.apidoc.MethodInfo'

function MethodInfo:initialize(classInfo, node, tag)
    assert(node.tag == tag, 'invalid node tag')
    assert(node.attr.name, 'missing "name" attribute')

    self.classInfo = classInfo
    self.name = node.attr.name
    self.type = 'method'
    self.lang = node.attr.lang
    self.flags = PropertyFlags()
    self.flags.silent = true
    self.flags.constant = true
    self.flags.modelhashexclude = true
    self.var = node.attr.var
    self.aux = {}
    self.params = {}
    self.returns = {}
    self.categories = {}
    self.seeAlso = {}
    self.related = {}
    self.description = ''
    self.replacedBy = nil
    self.migrateTo = nil
    self.supersedes = nil

    local paramsNode = xmlFind(node, 'params')
    if paramsNode then
        for _, paramNode in ipairs(xmlFindAll(paramsNode, 'param')) do
            table.insert(self.params, ParamInfo(self, paramNode, true))
        end
    end

    local returnsNode = xmlFind(node, 'returns')
    if returnsNode then
        for _, paramNode in ipairs(xmlFindAll(returnsNode, 'param')) do
            table.insert(self.returns, ParamInfo(self, paramNode))
        end
    end

    local descriptionNode = xmlFind(node, 'description')
    if descriptionNode then
        self.description = getChildrenXML(descriptionNode)
    end

    local categoriesNode = xmlFind(node, 'categories')
    if categoriesNode then
        for _, categoryNode in ipairs(xmlFindAll(categoriesNode, 'category')) do
            assert(categoryNode.attr.name, 'missing "name" attribute in <category>')
            self.categories[categoryNode.attr.name] = true
        end
    end

    local seeAlsoNode = xmlFind(node, 'see-also')
    if seeAlsoNode then
        for _, subnode in ipairs(xmlFindAll(seeAlsoNode, 'function-ref')) do
            assert(subnode.attr.name, 'missing "name" attribute in <function-ref>')
            table.insert(self.seeAlso, {'function', subnode.attr.name})
        end
        for _, subnode in ipairs(xmlFindAll(seeAlsoNode, 'property-ref')) do
            assert(subnode.attr.name, 'missing "name" attribute in <property-ref>')
            table.insert(self.seeAlso, {'property', subnode.attr.name})
        end
        for _, subnode in ipairs(xmlFindAll(seeAlsoNode, 'link')) do
            assert(subnode.attr.href, 'missing "href" attribute in <link>')
            table.insert(self.seeAlso, {'link', subnode.attr.href, subnode.attr.label})
        end
    end

    local supportNode = xmlFind(node, 'support')
    if supportNode then
        self.startSupport = supportNode.attr.start
        self.endSupport = supportNode.attr['end']
        self.startDeprecated = supportNode.attr['start-deprecated']
    end

    local replacedByNode = xmlFind(node, 'replaced-by')
    if replacedByNode then
        assert(replacedByNode.attr.name, 'missing "name" attribute in <replaced-by>')
        self.replacedBy = replacedByNode.attr.name
    end

    local migrateToNode = xmlFind(node, 'migrate-to')
    if migrateToNode then
        assert(migrateToNode.attr.name, 'missing "name" attribute in <migrate-to>')
        self.migrateTo = migrateToNode.attr.name
    end

    local supersedesNode = xmlFind(node, 'supersedes')
    if supersedesNode then
        self.supersedes = {}
        for _, itemNode in ipairs(xmlFindAll(supersedesNode, 'item')) do
            assert(itemNode.attr.name, 'missing "name" attribute in <supersedes>/<item>')
            table.insert(self.supersedes, itemNode.attr.name)
        end
    end
end

function MethodInfo:__tostring()
    return self.class.name .. '(name = ' .. self.name .. ')'
end

function MethodInfo:getCallTip(opts)
    opts = opts or {}
    local x = ''
    for i, p in ipairs(self.returns) do
        if i > 1 then x = x .. ', ' end
        if opts.types then
            if opts.format == 'html' then x = x .. '<span style="color: #00c;">' end
            x = x .. p.type
            if opts.format == 'html' then x = x .. '</span>' end
            x = x .. ' '
        end
        if opts.format == 'html' then x = x .. '<span style="color: #999;">' end
        x = x .. p.name
        if opts.format == 'html' then x = x .. '</span>' end
    end
    if #self.returns > 0 then
        if opts.format == 'html' then x = x .. '<span style="color: #ccc;">' end
        x = x .. ' = '
        if opts.format == 'html' then x = x .. '</span>' end
    end
    if opts.format == 'html' then x = x .. '<b>' end
    x = x .. self.classInfo.className .. ':' .. self.name
    if opts.format == 'html' then x = x .. '</b>' end
    x = x .. '('
    for i, p in ipairs(self.params) do
        if i > 1 then x = x .. ', ' end
        if opts.types then
            if opts.format == 'html' then x = x .. '<span style="color: #00c;">' end
            x = x .. p.type
            if opts.format == 'html' then x = x .. '</span>' end
            x = x .. ' '
        end
        if opts.format == 'html' then x = x .. '<span style="color: #999;">' end
        x = x .. p.name
        if opts.format == 'html' then x = x .. '</span>' end
        if p.default then
            if opts.format == 'html' then x = x .. '<span style="color: #ccc;">' end
            x = x .. '=' .. p.default
            if opts.format == 'html' then x = x .. '</span>' end
        end
    end
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

function MethodInfo:getDoc()
    local doc = self:getCallTip()
    if self.description then
        doc = doc .. '<hr/>' .. self.description
    end
    local p = self:getParamsDoc(self.params)
    if p and p ~= '' then
        doc = doc .. '<hr/>Params:<br/>' .. p
    end
    local r = self:getParamsDoc(self.returns)
    if r and r ~= '' then
        doc = doc .. '<hr/>Return value(s):<br/>' .. r
    end
    return doc
end

local ClassInfo = class 'sim.apidoc.ClassInfo'

function ClassInfo:initialize(node)
    assert(node.tag == 'object-class', 'invalid node tag')
    assert(node.attr.name, 'missing "name" attribute')

    self.className = node.attr.name
    self.superClassName = node.attr.superclass
    self.properties = {}
    self.methods = {}
    self.namespaces = {}

    for _, propertyNode in ipairs(xmlFindAll(node, 'property')) do
        local info = PropertyInfo(self, propertyNode)
        self.properties[info.name] = info
    end

    for _, methodNode in ipairs(xmlFindAll(node, 'method')) do
        local info = MethodInfo(self, methodNode, 'method')
        self.methods[info.name] = info
    end

    for _, namespaceNode in ipairs(xmlFindAll(node, 'namespace')) do
        local info = NamespaceInfo(self, namespaceNode)
        self.namespaces[info.name] = info
    end
end

function ClassInfo:__tostring()
    return self.class.name .. '(className = ' .. self.className .. ')'
end

function ClassInfo:getSuperClass()
    return apidoc.getClass(self.superClassName)
end

function ClassInfo:getMethod(methodName, opts)
    opts = opts or {}
    local c = self
    while c do
        if c.methods[methodName] then
            return c.methods[methodName]
        end
        if opts.searchSuperclasses == false then return end
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

apidoc.classes = {}
for _, node in ipairs(xmltree 'objects.xml') do
    if node.tag == 'object-class' then
        local info = ClassInfo(node)
        apidoc.classes[info.className] = info
    end
end

apidoc.functions = {}
for _, node in ipairs(xmltree 'functions.xml') do
    if node.tag == 'function' then
        local info = MethodInfo(nil, node, 'function')
        apidoc.functions[info.name] = info
    end
end

apidoc.enums = {}
for _, node in ipairs(xmltree 'enums.xml') do
    if node.tag == 'enum' then
        local info = EnumInfo(node, 'enum')
        apidoc.enums[info.name] = info
    end
end

function apidoc.getClass(className)
    return apidoc.classes[className]
end

function apidoc.getMethod(className, methodName, opts)
    local c = apidoc.getClass(className)
    if c then return c:getMethod(methodName, opts) end
end

function apidoc.findMethod(methodName)
    local ret = {}
    for _, classInfo in pairs(apidoc.classes) do
        local m = classInfo:getMethod(methodName, {searchSuperclasses = false})
        if m then table.insert(ret, m) end
    end
    return ret
end

function apidoc.getClassHierarchyGraph()
    local Graph = require 'Graph'
    local g = Graph(true)
    for _, classInfo in pairs(apidoc.classes) do
        g:addVertex(classInfo.className)
    end
    for _, classInfo in pairs(apidoc.classes) do
        if classInfo.superClassName then
            g:addEdge(classInfo.className, classInfo.superClassName)
        end
    end
    return g
end

function apidoc.getFunction(functionName)
    return apidoc.functions[functionName]
end

function apidoc.getEnum(enumName)
    return apidoc.enums[enumName]
end

return apidoc
