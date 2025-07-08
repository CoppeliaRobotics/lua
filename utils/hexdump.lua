return function(x, opts)
    opts = opts or {}
    opts.width = opts.width or 16
    opts.offset = opts.offset ~= false
    opts.printable = opts.printable ~= false
    assert(isbuffer(x) or type(x) == 'string', 'works only on buffer and strings')
    local s = ''
    local sep = ''
    local ow = #x > 0 and math.floor(math.log(#x, 16)) + 1 or 1
    for i = 1, #x, opts.width do
        if opts.offset then
            s = s .. string.format(' %0' .. ow .. 'x |', i - 1)
        end
        for j = i, i + opts.width - 1 do
            local c = x:sub(j, j)
            s = s .. (c == '' and '   ' or string.format(' %02x', string.byte(c)))
        end
        if opts.printable then
            s = s .. ' |'
            for j = i, math.min(#x, i + opts.width) do
                local c = x:sub(j, j)
                s = s .. ' ' .. (string.isprintable(c) and c or ' ')
            end
        end
        s = s .. '\n'
        sep = ' '
    end
    print(s)
end
