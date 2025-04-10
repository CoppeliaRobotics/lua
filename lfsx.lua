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

function lfs.pathsep()
    return package.config:sub(1,1)
end

function lfs.pathjoin(parts)
    return table.join(parts, lfs.pathsep())
end

function lfs.basename(str)
    local name = string.gsub(str, '(.*' .. lfs.pathsep() .. ')(.*)', '%2')
    return name
end

function lfs.dirname(str)
    if str:match('.-/.-') then
        local name = string.gsub(str, '(.*)(' .. lfs.pathsep() .. ')(.*)', '%1')
        return name
    else
        return ''
    end
end

return lfs
