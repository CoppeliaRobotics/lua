return function(x)
    local s = ''
    for i = 1, #x do
        s = s .. string.format('%s%02x', i > 1 and ' ' or '', string.byte(x:sub(i, i)))
    end
    print(s)
end
