local lfs = require 'lfs'

-- deletes a non-empty directory
function lfs.rmdir_r(dir)
    for file in lfs.dir(dir) do
        local file_path = dir .. '/' .. file
        if file ~= '.' and file ~= '..' then
            local mode = lfs.attributes(file_path, 'mode')
            if mode == 'file' then
                os.remove(file_path)
            elseif mode == 'directory' then
                lfs.rmdir_r(file_path)
            end
        end
    end
    return lfs.rmdir(dir)
end

function lfs.pathsanitize(p)
    if lfs.pathsep() == '\\' then
        p = p:gsub('/', '\\')
    end
    return p
end

function lfs.pathsep()
    return package.config:sub(1,1)
end

-- Returns the directory part and the file part, similar to Python's os.path.split
function lfs.pathsplit(p)
    p = lfs.pathsanitize(p)
    local sep = lfs.pathsep()
    -- Normalize trailing separator (unless it's root '/')
    if #p > 1 and p:sub(-1) == sep then
        p = p:sub(1, -2)
    end
    local head, tail = p:match("^(.*"..sep..")([^"..sep.."]+)$")
    if not head then
        return "", p
    else
        -- Remove trailing separator from head unless it's root
        if #head > 1 and head:sub(-1) == sep then
            head = head:sub(1, -2)
        end
        return head, tail
    end
end

-- Joins paths, taking into account absolute paths
function lfs.pathjoin(...)
    local sep = lfs.pathsep()
    local args = {...}
    local result = ""
    for i, part in ipairs(args) do
        if part:sub(1, 1) == sep then
            -- Absolute path resets the result
            result = part
        else
            if result == "" or result:sub(-1) == sep then
                result = result .. part
            else
                result = result .. sep .. part
            end
        end
    end
    return result
end

-- similar to pathlib.Path(...).parts
function lfs.pathparts(p)
    p = lfs.pathsanitize(p)
    local result = {}
    local head, tail
    head = p
    while true do
        if head == '' then break end
        head, tail = lfs.pathsplit(head)
        table.insert(result, 1, tail)
    end
    return result
end

function lfs.basename(path)
    path = lfs.pathsanitize(path)
    local name = string.gsub(path, '(.*' .. lfs.pathsep() .. ')(.*)', '%2')
    return name
end

function lfs.dirname(path)
    path = lfs.pathsanitize(path)
    if path:match('.-' .. lfs.pathsep() .. '.-') then
        local name = string.gsub(path, '(.*)(' .. lfs.pathsep() .. ')(.*)', '%1')
        return name
    else
        return ''
    end
end

function lfs.isfile(p)
    return lfs.attributes(p, 'mode') == 'file'
end

function lfs.isdir(p)
    return lfs.attributes(p, 'mode') == 'directory'
end

function lfs.ispathabsolute(path)
    -- Handle empty or nil paths
    if not path or path == '' then return false end

    if lfs.pathsep() == '\\' then
        -- Windows absolute path: starts with drive letter (e.g., C:\ or C:/)
        if path:match('^%a:[/\\]') then return true end

        -- Windows UNC path: starts with double backslashes (e.g., \\Server\Share)
        if path:match('^\\\\') then return true end
    else
        -- Unix absolute path: starts with a slash
        if path:sub(1, 1) == '/' then return true end
    end

    return false
end

function lfs.makedirs(path, exist_ok)
    exist_ok = exist_ok or false

    local sep = lfs.pathsep()
    local parts = lfs.pathparts(path)
    local current = ""

    -- Windows drive letters or UNC paths need special handling
    if lfs.ispathabsolute(path) then
        -- If the first part is a drive letter or UNC root, preserve it
        if parts[1]:match("^[A-Za-z]:$") or parts[1]:match("^\\\\") then
            current = parts[1]
            table.remove(parts, 1)
        elseif sep == "/" then
            current = sep
        end
    end

    for _, part in ipairs(parts) do
        if current == "" or current:sub(-1) == sep then
            current = current .. part
        else
            current = current .. sep .. part
        end

        if not lfs.isdir(current) then
            local ok, err = lfs.mkdir(current)
            if not ok then
                error('Could not create directory: ' .. current .. ' (' .. err .. ')')
            end
        elseif not exist_ok and not lfs.isdir(current) then
            error('Path exists and is not a directory: ' .. current)
        end
    end
end

function lfs.gettempdir()
    local temp = os.getenv("TMP") or os.getenv("TEMP") or os.getenv("TMPDIR")
    if not temp and package.config:sub(1,1) == '/' then
        -- On Unix, fallback to /tmp
        temp = "/tmp"
    elseif not temp then
        -- On Windows, fallback to C:\Temp
        temp = "C:\\Temp"
    end
    return temp
end

function lfs.realpath(path)
    local dir, file = lfs.pathsplit(path)
    local lower = file:lower()
    for entry in lfs.dir(dir) do
        if entry:lower() == lower then
            return lfs.pathjoin(dir, entry)
        end
    end
end

local function getWalkAttributes(path, follow)
    path = lfs.pathsanitize(path)

    if follow then
        return lfs.attributes(path)
    end

    if not lfs.symlinkattributes then
        return nil, "symlinkattributes is unavailable; cannot honor follow=false"
    end

    local mode, err = lfs.symlinkattributes(path, "mode")
    if not mode then
        return nil, err
    end

    if mode == "link" then
        -- Do not retrieve target attributes or follow the link.
        return {mode = mode}
    end

    return lfs.attributes(path)
end

--- Recursively visit every file under `dir`.
-- @param dir  string  starting directory
-- @param fn   function(path, attr) called for each regular file
-- @param opts table   optional:
--     onDir   (function(path)) called for each directory (before descending)
--     onOther (function(path, mode)) called for symlinks, sockets, etc.
--     follow  (bool)  follow symlinks (default false → avoids loops)
--     sort    (bool)  sort entries per directory (default false)
function lfs.walk(dir, fn, opts)
    opts = opts or {}
    dir  = dir or '.'

    -- collect first: safer than iterating while recursing on some platforms
    local entries = {}
    for entry in lfs.dir(dir) do
        if entry ~= '.' and entry ~= '..' then
            entries[#entries + 1] = entry
        end
    end
    if opts.sort then table.sort(entries) end

    for _, entry in ipairs(entries) do
        local path = lfs.pathjoin(dir, entry)
        local ok, attr, err = pcall(getWalkAttributes, path, opts.follow)

        if not ok then
            -- On an exception, the error message is in attr.
            error(("Cannot inspect %q: %s"):format(path, tostring(attr)), 0)
        end

        if not attr then
            error(("Cannot inspect %q: %s"):format(path, tostring(err)), 0)
        end

        local mode = attr.mode

        if mode == 'directory' then
            if opts.onDir then opts.onDir(path) end
            lfs.walk(path, fn, opts)
        elseif mode == 'file' then
            fn(path, attr)
        else
            if opts.onOther then opts.onOther(path, mode) end
        end
    end
end

-- iterator-style walk, e.g.:
-- for path, attr in lfs.iwalk('src') do … end
function lfs.iwalk(root, opts)
    opts = opts or {}
    local function walk(dir)
        local entries = {}
        for entry in lfs.dir(dir) do
            if entry ~= '.' and entry ~= '..' then
                entries[#entries + 1] = entry
            end
        end
        if opts.sort then table.sort(entries) end
        for _, entry in ipairs(entries) do
            local path = lfs.pathjoin(dir, entry)
            local ok, attr, err = pcall(getWalkAttributes, path, opts.follow)

            if not ok then
                -- On an exception, the error message is in attr.
                error(("Cannot inspect %q: %s"):format(path, tostring(attr)), 0)
            end

            if not attr then
                error(("Cannot inspect %q: %s"):format(path, tostring(err)), 0)
            end

            local mode = attr.mode
            if mode == 'directory' then
                walk(path)
            elseif mode == 'file' then
                coroutine.yield(path, attr)
            elseif opts.onOther then
                opts.onOther(path, mode)
            end
        end
    end

    local co = coroutine.create(function() walk(root or '.') end)
    return function()
        local ok, path, attr = coroutine.resume(co)
        if not ok then error(path, 0) end
        if coroutine.status(co) == 'dead' then return nil end
        return path, attr
    end
end

function lfs.unittest()
    require 'tablex'
    if lfs.pathsep() == '\\' then
        assert(lfs.pathsanitize('c:\\tmp\\foo.txt') == 'c:\\tmp\\foo.txt')
        assert(lfs.pathsanitize('c:/tmp/foo.txt') == 'c:\\tmp\\foo.txt')
        assert(lfs.pathjoin('c:', 'tmp', 'foo.txt') == 'c:\\tmp\\foo.txt')
        assert(table.eq({lfs.pathsplit 'c:\\tmp\\foo.txt'}, {'c:\\tmp', 'foo.txt'}))
        assert(table.eq(lfs.pathparts 'c:\\tmp\\foo.txt', {'c:', 'tmp', 'foo.txt'}))
        assert(lfs.basename 'c:\\tmp\\foo.txt' == 'foo.txt')
        assert(lfs.dirname 'c:\\tmp\\foo.txt' == 'c:\\tmp')
        assert(lfs.dirname 'c:\\tmp1\\tmp2\\foo.txt' == 'c:\\tmp1\\tmp2')
        assert(lfs.ispathabsolute 'c:\\tmp\\foo.txt')
        assert(not lfs.ispathabsolute 'tmp\\foo.txt')
        assert(lfs.pathsanitize 'c:/tmp/foo.txt', 'c:\\tmp\\foo.txt')
    else
        assert(table.eq({lfs.pathsplit '/usr/bin/foo'}, {'/usr/bin', 'foo'}))
        assert(table.eq(lfs.pathparts '/usr/bin/foo', {'/', 'usr', 'bin', 'foo'}))
        assert(lfs.pathjoin('/usr', 'bin', 'foo') == '/usr/bin/foo')
        assert(lfs.basename '/usr/bin/foo' == 'foo')
        assert(lfs.dirname '/usr/bin/foo' == '/usr/bin')
        assert(lfs.ispathabsolute '/usr/bin/foo')
        assert(not lfs.ispathabsolute 'bin/foo')
        assert(lfs.pathsanitize '/usr/bin/foo', '/usr/bin/foo')
    end
    local tmp1 = lfs.pathjoin(lfs.gettempdir(), 'foo')
    local tmp = lfs.pathjoin(tmp1, 'bar', 'baz')
    if lfs.isdir(tmp) then
        print('warning: ' .. tmp .. ' already exists')
        print('removing ' .. tmp1 .. ' first...')
        lfs.rmdir_r(tmp1)
    end
    assert(not lfs.isdir(tmp))
    lfs.makedirs(tmp)
    assert(lfs.isdir(tmp))
    lfs.rmdir_r(tmp1)
    print(debug.getinfo(1, 'S').source, 'tests passed')
end

return lfs
