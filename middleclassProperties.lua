-- properties.lua
local Properties = {}

-- Install property support onto a middleclass class.
-- After this, use:
--   Class.static.property(name, {
--       type = <int>, info = <int flags>, description = <string>,
--       get = function(self, key) ... end,
--       set = function(self, value, key) ... end,
--   })
-- Class-level introspection:
--   Class.properties()              -> array of property metadata (own + inherited)
--   Class.propertyInfo(name)        -> single property metadata, or nil
-- Instance-level introspection (works even if the class is not exported):
--   obj:properties()                -> array of property metadata
--   obj:propertyInfo(name)          -> single property metadata, or nil
function Properties.enable(Class)
    local dict = Class.__instanceDict

    -- Per-class registry: name -> def (def carries get/set + metadata)
    local registry = {}
    Class.static._properties = registry

    -- Resolve a property def for `key`, searching this class then ancestors:
    local function findProp(key)
        local p = registry[key]
        if p ~= nil then return p end
        local super = Class.super
        while super do
            local r = rawget(super.static, '_properties')
            if r and r[key] ~= nil then return r[key] end
            super = super.super
        end
        return nil
    end

    dict.__index = function(self, key)
        local prop = findProp(key)
        if prop and prop.get then
            return prop.get(self, key)
        end
        return dict[key]   -- normal method/inherited lookup
    end

    dict.__newindex = function(self, key, value)
        local prop = findProp(key)
        if prop then
            if not prop.set then
                error("property '" .. key .. "' is read-only", 2)
            end
            prop.set(self, value, key)
        else
            rawset(self, key, value)
        end
    end

    -- Registration API
    function Class.static.property(name, def)
        assert(type(name) == 'string', 'property name must be a string')
        assert(type(def) == 'table', 'property def must be a table')
        assert(def.get or def.set, 'property needs at least a get or set')

        -- normalize / default the metadata fields:
        assert(def.type == nil or math.type(def.type) == 'integer',
            "property 'type' must be an integer")
        assert(def.info == nil or math.type(def.info) == 'integer',
            "property 'info' must be an integer (flags)")
        assert(def.description == nil or type(def.description) == 'string',
            "property 'description' must be a string")

        def.name = name
        def.type = def.type or 0
        def.info = def.info or 0
        def.description = def.description or ''
        registry[name] = def
        return def
    end

    -- Metadata for a single property (searches ancestors too):
    function Class.static.propertyInfo(name)
        local p = findProp(name)
        if not p then return nil end
        return {
            name = p.name,
            type = p.type,
            info = p.info,
            description = p.description,
            readable = p.get ~= nil,
            writable = p.set ~= nil,
        }
    end

    -- List all properties (own + inherited). Returns an array of metadata
    -- tables, sorted by name. Subclass definitions override inherited ones
    -- of the same name.
    function Class.static.properties()
        local merged = {}

        -- collect from root down to self, so derived definitions win:
        local chain = {}
        local c = Class
        while c do
            chain[#chain + 1] = c
            c = c.super
        end
        for i = #chain, 1, -1 do
            local r = rawget(chain[i].static, '_properties')
            if r then
                for name, p in pairs(r) do
                    merged[name] = p
                end
            end
        end

        local list = {}
        for name, p in pairs(merged) do
            list[#list + 1] = {
                name = p.name,
                type = p.type,
                info = p.info,
                description = p.description,
                readable = p.get ~= nil,
                writable = p.set ~= nil,
            }
        end
        table.sort(list, function(a, b) return a.name < b.name end)
        return list
    end

    -- Instance-level forwarders (use self.class so the right class/subclass
    -- is resolved, even when the class itself is not exported from a module):
    function dict:properties()
        return self.class.properties()
    end

    function dict:propertyInfo(name)
        return self.class.propertyInfo(name)
    end

    return Class
end

return Properties
