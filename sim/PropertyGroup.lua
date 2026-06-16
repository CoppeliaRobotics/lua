local class = require 'middleclass'

local PropertyGroup = class 'sim.PropertyGroup'

local sim = {
    propertytype_group = 24,
    propertytype_enum = 25,
    propertytype_method = 240,
}

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

    if self.__localProperties[k] then
        assert(self.__localProperties[k].get, 'local property "' .. k .. '" can\'t be read')
        return self.__localProperties[k].get()
    end

    local prefix = self.__opts.prefix or ''
    if prefix ~= '' then k = prefix .. '.' .. k end

    local object = rawget(self, '__object')
    local ptype = object:getPropertyInfo(k, {noError = true})
    if ptype == sim.propertytype_method then
        return function(_, ...)
            return object:callMethod(k, ...)
        end
    elseif ptype == sim.propertytype_group then
        return PropertyGroup(object, {prefix = k})
    elseif ptype then
        local v = object:callMethod('getProperty', k, {type = ptype})

        local simEigen = require 'simEigen'
        if simEigen.Matrix:ismatrix(v) or simEigen.Quaternion:isquaternion(v) then
            -- prevent inline modifications, e.g.: obj.position[3] = 0
            -- which havbe no effect (don't trigger a setProperty call) and
            -- might confuse users
            v:freeze()
        end

        return v
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
    object:callMethod('setProperty', k, v, {type = self.__opts.newPropertyForcedType})
end

function PropertyGroup:__tostring()
    local s = self.class.name .. '(' .. self.__object.handle
    if next(self.__opts) then
        s = s .. ', ' .. table.tostring(self.__opts)
    end
    s = s .. ')'
    return s
end

function PropertyGroup:__pairs(opts)
    opts = opts or {}
    local object = self.__object
    local prefix = self.__opts.prefix or ''
    if prefix ~= '' then prefix = prefix .. '.' end
    local props = {}
    local i = 0
    while true do
        local pnameFull = object:callMethod('getPropertyName', i, {prefix = prefix})
        if pnameFull == nil then break end
        local pname = string.stripprefix(pnameFull, prefix)
        pname = pname:gsub('%..*', '') -- strip everything after first dot
        if not props[pname] then
            local ptype, pflags, metaInfo = object:callMethod('getPropertyInfo', prefix .. pname)
            local readable = pflags & 2 == 0
            if ptype == sim.propertytype_group then
                props[pname] = PropertyGroup(object, {prefix = prefix .. pname})
            elseif readable then
                props[pname] = object:callMethod('getProperty', prefix .. pname, {type = ptype})
                if opts.dump and ptype == sim.propertytype_enum then
                    props[pname] = setmetatable({}, {__tostring = function(self)
                        return string.format('%d (%s)', object:getIntProperty(pnameFull), object:getStringProperty(pnameFull))
                    end})
                end
            end
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

function PropertyGroup:__dump(maxDepth)
    local tbl = {}
    for k, v in self:__pairs{dump = true} do
        tbl[k] = dump(v, maxDepth - 1)
    end
    return tbl
end

function PropertyGroup:registerLocalProperty(k, getter, setter)
    self.__localProperties[k] = {get = getter, set = setter}
end

return PropertyGroup
