return function(name)
    local searchPaths = string.split(package.path, package.config:sub(3, 3))
    local nameWithSlashes = name:gsub('%.', '/')
    for _, searchPath in ipairs(searchPaths) do
        local exists = false
        local fileName = searchPath:gsub('?', nameWithSlashes)
        local f = io.open(fileName, 'r')
        if f ~= nil then
            exists = true
            io.close(f)
        end
        if exists then
            local success, result = xpcall(
                function(filename, env)
                    local f = assert(loadfile(filename))
                    return f()
                end,
                function(err)
                    return debug.traceback(err)
                end,
                fileName
            )
            if success then
                return result
            else
                addLog(420, result)
                return
            end
        end
    end
end
