local base16 = {}

function base16.encode(d)
    local ret = ''
    for i = 1, #d do ret = ret .. string.format('%02X', string.byte(string.sub(d, i, i))) end
    return ret
end

function base16.decode(d)
    local ret = ''
    for i = 1, #d, 2 do ret = ret .. string.char(tonumber('0x' .. string.sub(d, i, i + 1))) end
    return ret
end

return base16
