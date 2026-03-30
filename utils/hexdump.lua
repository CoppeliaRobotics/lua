return function(x, opts)
    opts = opts or {}
    opts.width = opts.width or 16
    opts.offset = opts.offset ~= false
    opts.printable = opts.printable ~= false
    assert(isbuffer(x) or type(x) == 'string', 'works only on buffer and strings')
    local s = {}
    local ow = #x > 0 and math.floor(math.log(#x, 16)) + 1 or 1

    local byteHex, byteChar = {}, {}
    for i = 0, 255 do
        byteHex[i] = string.format(' %02x', i)
        byteChar[i] = ' ' .. (i >= 32 and i < 127 and string.char(i) or '.')
    end
    byteHex[-1] = '   '
    byteChar[-1] = ''

    for i = 1, #x, opts.width do
        if opts.offset then
            table.insert(s, string.format(' %0' .. ow .. 'x |', i - 1))
        end
        for j = i, i + opts.width - 1 do
            table.insert(s, byteHex[x:byte(j) or -1])
        end
        if opts.printable then
            table.insert(s, ' |')
            for j = i, math.min(#x, i + opts.width - 1) do
                table.insert(s, byteChar[x:byte(j) or -1])
            end
        end
        table.insert(s, '\n')
    end
    print(table.concat(s))
end
