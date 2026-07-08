local json = require 'dkjson'
local sim = require 'sim-2'

local Properties = {}

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
            if prop.plain then
                rawset(self, key, value)          -- plain documented field
            elseif prop.set then
                prop.set(self, value, key)
            else
                error("property '" .. key .. "' is read-only", 2)
            end
        else
            rawset(self, key, value)
        end
    end
    --[[
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
    --]]
    
    -- Registration API
    function Class.static.property(name, def)
        assert(type(name) == 'string', 'property name must be a string')
        assert(type(def) == 'table', 'property def must be a table')
        --assert(def.get or def.set, 'property needs at least a get or set')

        -- normalize / default the metadata fields:
        assert(math.type(def.type) == 'integer', "invalid property 'type'")
        assert(def.flags == nil or math.type(def.flags) == 'integer', "invalid property 'flags'")
        assert(def.info == nil or type(def.info) == 'table', "invalid property 'info'")

        def.name = name
        def.plain = (def.get == nil and def.set == nil)  -- documented plain field
        def.type = def.type or 0
        def.flags = def.flags or (sim.propertyinfo_silent | sim.propertyinfo_modelhashexclude)
        if def.info then
            def.info = json.encode(def.info)
        else
            def.info = '{}'
        end
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
            flags = p.flags,
            info = p.info,
            readable = p.plain or (p.get ~= nil),
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
                flags = p.flags,
                info = p.info,
                readable = p.plain or (p.get ~= nil),
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

    function dict:__pairs(opts)
        opts = opts or {}
        local props = self:properties()
        local i = 0
        return function()
            while true do
                i = i + 1
                local p = props[i]
                if not p then return nil end
                if p.readable then
                    return p.name, self[p.name]
                end
                -- skip non-readable (write-only) properties
            end
        end
    end

    -- Produce a plain table representation for dump()/printing.
    function dict:__dump(maxDepth)
        maxDepth = maxDepth or math.huge
        local tbl = {}
        for k, v in self:__pairs{dump = true} do
            tbl[k] = dump(v, maxDepth - 1)
        end
        return tbl
    end
    
    return Class
end

return Properties
