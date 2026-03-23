local class = require 'middleclass'

local PropertyGroup = class 'sim.PropertyGroup'

function PropertyGroup:initialize(object, opts)
    local Object = require 'sim.Object'
    self.__object = Object:toobject(object)
    self.__opts = table.clone(opts or {})
    self.__localProperties = {}
    if self.__opts.newPropertyForcedType then
        assert(math.type(self.__opts.newPropertyForcedType) == 'integer', 'invalid type for option "newPropertyForcedType"')
    end
end

function PropertyGroup:__index(k)
    assert(type(k) == 'string', 'invalid key type')

    if k:startswith '__' then
        return rawget(self, k)
    end

    if self.__localProperties[k] then
        assert(self.__localProperties[k].get, 'local property "' .. k .. '" can\'t be read')
        return self.__localProperties[k].get()
    end

    local prefix = self.__opts.prefix or ''
    if prefix ~= '' then k = prefix .. '.' .. k end

    local object = rawget(self, '__object')
    local ptype = object:getPropertyInfo(k)
    if ptype then
        return object:getProperty(k)
    end

    if object:getPropertyName(0, {prefix = k .. '.'}) then
        return PropertyGroup(object, {prefix = k})
    end
end

function PropertyGroup:__newindex(k, v)
    assert(type(k) == 'string', 'invalid key type')

    if k:startswith '__' then
        rawset(self, k, v)
        return
    end

    if self.__localProperties[k] then
        assert(self.__localProperties[k].set, 'local property "' .. k .. '" can\'t be written')
        return self.__localProperties[k].set(v)
    end

    local prefix = self.__opts.prefix or ''
    if prefix ~= '' then k = prefix .. '.' .. k end

    local object = rawget(self, '__object')
    object:setProperty(k, v, {type = self.__opts.newPropertyForcedType})
end

function PropertyGroup:__tostring()
    local s = self.class.name .. '(' .. self.__object.handle
    if next(self.__opts) then
        s = s .. ', ' .. table.tostring(self.__opts)
    end
    s = s .. ')'
    return s
end

function PropertyGroup:__pairs()
    local object = self.__object
    local prefix = self.__opts.prefix or ''
    if prefix ~= '' then prefix = prefix .. '.' end
    local props = {}
    local i = 0
    while true do
        local pname = object:getPropertyName(i, {prefix = prefix})
        if pname == nil then break end
        pname = string.stripprefix(pname, prefix)
        local pname2 = string.gsub(pname, '%..*$', '')
        if pname == pname2 then
            local ptype, pflags, descr = object:getPropertyInfo(prefix .. pname)
            local readable = pflags & 2 == 0
            if readable then
                props[pname2] = object:getProperty(prefix .. pname)
            end
        elseif props[pname2] == nil then
            props[pname2] = PropertyGroup(object, {prefix = prefix .. pname})
        end
        i = i + 1
    end
    local function stateless_iter(self, k)
        local v
        k, v = next(props, k)
        if v ~= nil then return k, v end
    end
    return stateless_iter, self, nil
end

function PropertyGroup:registerLocalProperty(k, getter, setter)
    self.__localProperties[k] = {get = getter, set = setter}
end

return PropertyGroup
