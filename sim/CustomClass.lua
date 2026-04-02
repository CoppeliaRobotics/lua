local class = require 'middleclass'

local CustomClass = class 'sim.CustomClass'

CustomClass.static.registeredClasses = {}

function CustomClass.static:register(objectType, objectMetaInfo)
    assert(CustomClass.static.registeredClasses[objectType] == nil, 'class already registered')
    if type(objectMetaInfo) == 'string' then
        local json = require 'dkjson'
        objectMetaInfo = json.decode(objectMetaInfo)
        assert(objectMetaInfo ~= nil, 'JSON error in objectMetaInfo')
    end
    assert(type(objectMetaInfo) == 'table', 'bad objectMetaInfo type')
    CustomClass.static.registeredClasses[objectType] = CustomClass(objectMetaInfo)
end

function CustomClass.static:isRegistered(objectType)
    return CustomClass.static.registeredClasses[objectType] ~= nil
end

function CustomClass.static:getMethod(objectType, methodName)
    local cls = CustomClass.static.registeredClasses[objectType]
    if cls then
        local methodInfo = cls.methods[methodName]
        if methodInfo then
            local module = methodInfo.module and require(methodInfo.module) or _G
            return module[methodName]
        end
    end
end

function CustomClass.static:createObject(objectType, initialProperties)
    local cls = CustomClass.static.registeredClasses[objectType]
    assert(cls ~= nil, 'invalid objectType')
    local sim = require 'sim-2'
    local json = require 'dkjson'
    local objectMetaInfo = json.encode(cls:objectMetaInfo())
    local obj = sim.Object(sim.app:createCustomObject(objectType, objectMetaInfo))
    local initMethod = CustomClass:getMethod(objectType, 'initialize')
    if initMethod then
        initMethod(obj, initialProperties)
    end
    return obj
end

function CustomClass:initialize(objectMetaInfo)
    for k, v in pairs(objectMetaInfo) do
        self[k] = v
    end
    self.superclass = self.superclass or 'custom'
    self.methods = self.methods or {}
end

function CustomClass:objectMetaInfo()
    return {
        superclass = self.superclass,
        methods = self.methods,
    }
end

return CustomClass
