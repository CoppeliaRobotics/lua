local function find(opts)
    assert(type(opts) == 'table', 'invalid arg type: must be a table')

    local function matches(path)
        local pats = {}

        -- name/iname can be a string or a list of strings
        local name = opts.name or opts.iname
        local matchCase = not opts.iname
        local pathC = matchCase and path or path:lower()
        if name then
            if type(name) == 'string' then
                name = {name}
            end
            assert(type(name) == 'table', 'bad type')
            for _, n in ipairs(name) do
                assert(type(n) == 'string', 'bad type')
                if not matchCase then n = n:lower() end
                table.insert(pats, n)
            end
        end

        if next(pats) then
            local fnmatch = require 'fnmatch'
            for _, pat in ipairs(pats) do
                if fnmatch.fnmatch(pathC, pat) then
                    return true
                end
            end
            return false
        else
            return true
        end
    end

    local ret = {}

    local function found(path)
        if opts.exec then
            assert(type(opts.exec) == 'function', 'exec must be a function')
            opts.exec(path)
        else
            table.insert(ret, path)
        end
    end

    if opts.files then
        assert(type(opts.files) == 'table', 'files must be a table')
        for _, file in ipairs(opts.files) do
            if matches(file) then
                found(file)
            end
        end
    end

    if opts.dirs then
        assert(type(opts.dirs) == 'table', 'dirs must be a table')
        local lfsx = require 'lfsx'
        for _, dir in ipairs(opts.dirs) do
            for path, attr in lfsx.iwalk(dir) do
                if matches(path) then
                    found(path)
                end
            end
        end
    end

    if opts.exec == nil then
        return ret
    end
end

local function find_models(opts)
    opts = table.clone(opts or {})
    opts.name = {'*.ttm', '*.simmodel.xml'}
    return find(opts)
end

local function find_scenes(opts)
    opts = table.clone(opts or {})
    opts.name = {'*.ttt', '*.simscene.xml'}
    return find(opts)
end

return setmetatable(
    {
        models = find_models,
        scenes = find_scenes,
    },
    {
        __call = function(_, ...) return find(...) end,
    }
)
