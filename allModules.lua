local index = 0
while true do
    local plugin = auxFunc('getKnownPlugin', index)
    if plugin == '' then break end
    index = index + 1
    local res, err = pcall(require, plugin)
    if res then
        addLog(450, "successfully loaded module " .. plugin)
    else
        addLog(430, "failed loading module " .. plugin) -- ..": "..err)
    end
end
