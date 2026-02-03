return function(what)
    local sim1 = require 'sim-1' -- this was written for sim-1

    what = what:lower()

    local mods = {sim = sim or sim1}
    for i, n in ipairs(sim1.getProperty(sim1.handle_app, 'pluginNames')) do
        pcall(function() mods[n] = require(n) end)
    end

    local results = {}

    -- search in API objects:
    for n, m in pairs(mods) do
        for k, v in pairs(m) do
            if k:lower():match(what) then
                local s = n .. '.' .. k
                local info = s
                if type(v) == 'function' then
                    info = s .. '(...)'
                    local i = sim1.getApiInfo(-1, s)
                    if i and i ~= '' then info = (string.split(i, '\n'))[1] end
                end
                table.insert(results, {s, info})
            end
        end
    end

    -- search in object properties:
    local visitedTypes = {}
    local visitedNames = {}
    local objs = sim1.getObjectsInTree(sim1.handle_scene)
    table.insert(objs, sim1.handle_scene)
    table.insert(objs, sim1.handle_app)
    for _, h in ipairs(objs) do
        local t = sim1.getStringProperty(h, 'objectType')
        if not visitedTypes[t] then
            visitedTypes[t] = true
            local i = 0
            while true do
                local pname, pclass = sim1.getPropertyName(h, i)
                if pname == nil then break end
                i = i + 1
                local fullname = pclass .. '.' .. pname
                if not visitedNames[fullname] then
                    visitedNames[fullname] = true
                    if pname:lower():match(what) then
                        table.insert(results, {'~:' .. t .. ':' .. pname, 'property ' .. fullname})
                    end
                end
            end
        end
    end

    table.sort(results, function(a, b) return a[1] < b[1] end)
    local s = ''
    for i, result in ipairs(results) do s = s .. (s == '' and '' or '\n') .. result[2] end
    print(s)
end
