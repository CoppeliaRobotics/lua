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

function lfs.pathjoin(parts)
    return table.join(parts, lfs.pathsep())
end

function lfs.pathsplit(p)
    p = lfs.pathsanitize(p)
    local parts = {}
    for part in string.gmatch(p, '[^' .. lfs.pathsep() .. ']+') do
        table.insert(parts, part)
    end
    return parts
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

    local sep = ''
    if lfs.ispathabsolute(path) then sep = lfs.pathsep() end

    local current = sep
    for _, part in ipairs(lfs.pathsplit(path)) do
        if current == '' then
            current = part
        else
            current = current .. lfs.pathsep() .. part
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

return lfs
