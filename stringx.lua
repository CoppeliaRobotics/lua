function string.qsplit(s, pat) -- respects single and double quotes
    if isbuffer(s) then
        s = tostring(s)
    end
    local quotes = {}
    local retVal = {}
    local w = ''
    local i = 1
    while i <= #s do
        local si = string.find(s, pat, i)
        if si == i and #quotes == 0 then
            i = i + #pat
            if #w > 0 then
                retVal[#retVal + 1] = w
                w = ''
            end
        else
            local c = string.sub(s, i, i)
            if c == '"' or c == "'" then
                if #quotes == 0 or quotes[#quotes] ~= c then
                    w = w .. c
                    if #quotes > 1 then
                        quotes = {}
                    else
                        quotes[#quotes + 1] = c
                    end
                else
                    table.remove(quotes)
                    w = w .. c
                end
            else
                w = w .. c
            end
            i = i + 1
        end
    end
    if #w > 0 then
        retVal[#retVal + 1] = w
    end
    return retVal
end

function string.gsplit(text, pattern, plain)
    if isbuffer(text) then
        text = tostring(text)
    end
    local splitStart, length = 1, #text
    return function()
        if splitStart then
            local sepStart, sepEnd = string.find(text, pattern, splitStart, plain)
            local ret
            if not sepStart then
                ret = string.sub(text, splitStart)
                splitStart = nil
            elseif sepEnd < sepStart then
                -- empty separator
                ret = string.sub(text, splitStart, sepStart)
                if sepStart < length then
                    splitStart = sepStart + 1
                else
                    splitStart = nil
                end
            else
                ret = sepStart > splitStart and string.sub(text, splitStart, sepStart - 1) or ''
                splitStart = sepEnd + 1
            end
            return ret
        end
    end
end

function string.split(text, pattern, plain)
    if isbuffer(text) then
        text = tostring(text)
    end
    local ret = {}
    for match in string.gsplit(text, pattern, plain) do table.insert(ret, match) end
    return ret
end

function string.startswith(s, prefix)
    if isbuffer(s) then
        s = tostring(s)
    end
    return prefix == '' or s:sub(1, #prefix) == prefix
end

function string.endswith(s, suffix)
    if isbuffer(s) then
        s = tostring(s)
    end
    return suffix == '' or s:sub(-#suffix) == suffix
end

function string.trim(s)
    if isbuffer(s) then
        s = tostring(s)
    end
    return s:gsub('^%s*(.-)%s*$', '%1')
end

function string.ltrim(s)
    if isbuffer(s) then
        s = tostring(s)
    end
    return s:gsub('^%s*', '')
end

function string.rtrim(s)
    if isbuffer(s) then
        s = tostring(s)
    end
    local n = #s
    while n > 0 and s:find('^%s', n) do n = n - 1 end
    return s:sub(1, n)
end

function string.chars(s)
    if isbuffer(s) then
        s = tostring(s)
    end
    local ret = {}
    for i = 1, #s do table.insert(ret, s:sub(i, i)) end
    return ret
end

function string.bytes(s)
    if isbuffer(s) then
        s = tostring(s)
    end
    local ret = {}
    for i = 1, #s do table.insert(ret, string.byte(s:sub(i, i))) end
    return ret
end

function string.escpat(x)
    if isbuffer(x) then
        x = tostring(x)
    end
    return (x
        :gsub('%%', '%%%%')
        :gsub('^%^', '%%^')
        :gsub('%$$', '%%$')
        :gsub('%(', '%%(')
        :gsub('%)', '%%)')
        :gsub('%.', '%%.')
        :gsub('%[', '%%[')
        :gsub('%]', '%%]')
        :gsub('%*', '%%*')
        :gsub('%+', '%%+')
        :gsub('%-', '%%-')
        :gsub('%?', '%%?')
   )
end

function string.isalnum(s)
    if isbuffer(s) then
        s = tostring(s)
    end
    return s:match('^%w*$')
end

function string.isalpha(s)
    if isbuffer(s) then
        s = tostring(s)
    end
    return s:match('^%a*$')
end

function string.isidentifier(s)
    if isbuffer(s) then
        s = tostring(s)
    end
    return s:match('^[_%a][_%w]*$')
end

function string.islower(s)
    if isbuffer(s) then
        s = tostring(s)
    end
    return s:lower() == s
end

function string.isnumeric(s)
    if isbuffer(s) then
        s = tostring(s)
    end
    return s:match('^%d*$')
end

function string.isprintable(s)
    if isbuffer(s) then
        s = tostring(s)
    end
    if #s == 0 then return true end

    -- Check if the string is valid UTF-8
    if not pcall(utf8.len, s) then
        return false  -- Invalid UTF-8 sequence
    end

    -- Check for non-printable ASCII control characters (0-31, 127)
    if s:match("[%c]") then
        return false  -- Contains control characters
    end

    return true  -- String is valid UTF-8 and contains only printable characters
end

function string.isspace(s)
    if isbuffer(s) then
        s = tostring(s)
    end
    return s:match('^%s*$')
end

function string.isupper(s)
    if isbuffer(s) then
        s = tostring(s)
    end
    return s:upper() == s
end

function string.capitalize(s)
    if isbuffer(s) then
        s = tostring(s)
    end
    return s:sub(1, 1):upper() .. s:sub(2)
end

function string.escapequotes(s, context)
    context = context or '\''
    if context ~= "'" and context ~= '"' then
        error("Invalid context. Use '\'' for single quotes or '\"' for double quotes.")
    end
    -- Escape backslashes first to avoid double escaping
    s = s:gsub('\\', '\\\\')
    -- Escape the appropriate quote type
    local pattern = context == "'" and "'" or '"'
    s = s:gsub(pattern, '\\' .. pattern)
    return s
end

function string.escapehtml(s, opts)
    if isbuffer(s) then
        s = tostring(s)
    end
    opts = opts or {}
    opts.entities = opts.entities or true

    if opts.entities then
        local htmlEntities = {
            ["&"] = "&amp;",
            ["<"] = "&lt;",
            [">"] = "&gt;",
            ['"'] = "&quot;",
            ["'"] = "&#39;",
        }
        s = s:gsub("[&<>\"']", function(match) return htmlEntities[match] end)
    end

    return s
end

function string.stripmarkdown(s, opts)
    if isbuffer(s) then
        s = tostring(s)
    end
    opts = opts or {}

    -- Remove headers (##, ###, ####, etc.)
    s = s:gsub("##+ ([^\n]*)\n", "%1")

    -- Remove bold
    s = s:gsub("%*%*([^*]+)%*%*", "%1")
    s = s:gsub("__([^_]+)__", "%1")

    -- Remove italic
    s = s:gsub("%*([^*]*)%*", "%1")
    s = s:gsub("_([^_]*)_", "%1")

    -- Remove inline code (`code`)
    s = s:gsub("`([^`]*)`", "%1")

    if not opts.keeplinks then
        -- Remove links [text](url)
        s = s:gsub("%[([^%]]+)%]%([^%)]+%)", "%1")
    end

    return s
end

function string.stripprefix(s, prefix)
    if string.startswith(s, prefix) then
        return s:sub(#prefix + 1)
    end
end

function string.utf8sub(s, i, j)
    local start_byte = utf8.offset(s, i) or (#s + 1)
    local end_byte = j and (utf8.offset(s, j + 1) or (#s + 1)) - 1 or #s
    return s:sub(start_byte, end_byte)
end

function string.pad(s, width, clip)
    if clip then
        s = string.utf8sub(s, 1, math.abs(width))
    end
    local p = string.rep(' ', math.abs(width) - utf8.len(s))
    if width < 0 then
        return p .. s
    elseif width > 0 then
        return s .. p
    else
        return ''
    end
end

function string.blocksize(s)
    local lines = string.split(s, '\n')
    local width, height = 0, #lines
    for i = 1, #lines do
        width = math.max(width, utf8.len(lines[i]))
    end
    return width, height
end

function string.blockpad(s, width, height, clip)
    if width == nil and height == nil then
        width, height = string.blocksize(s)
    end
    local lines = string.split(s, '\n')
    if clip then
        lines = table.slice(lines, 1, math.abs(height))
    end
    for i = 1, math.max(math.abs(height) - #lines, 0) do
        if height < 0 then
            table.insert(lines, 1, '')
        elseif height > 0 then
            table.insert(lines, '')
        end
    end
    for i = 1, #lines do
        lines[i] = string.pad(lines[i], width, clip)
    end
    return table.join(lines, '\n')
end

function string.blockhstack(blocks, spacing)
    spacing = spacing or 1
    local sz = map(function(x) return {string.blocksize(x)} end, blocks)
    local h = 0
    for i = 1, #sz do
        h = math.max(h, sz[i][2])
    end
    local paddedblocks, lines = {}, {}
    for i = 1, #blocks do
        paddedblocks[i] = string.blockpad(blocks[i], sz[i][1], -h, true)
        lines[i] = string.split(paddedblocks[i], '\n')
    end
    local r, spc = {}, string.rep(' ', spacing)
    for j = 1, h do
        r[j] = ''
        for i = 1, #paddedblocks do
            r[j] = r[j] .. (i > 1 and spc or '') .. lines[i][j]
        end
    end
    return table.join(r, '\n')
end

if arg and #arg == 1 and arg[1] == 'test' then
    -- fix for "attempt to call a nil value (global 'isbuffer')"
    function isbuffer(x) return false end

    require 'tablex'
    assert(table.eq(string.split('a%b%c', '%', true), {'a', 'b', 'c'}))
    assert(table.eq(string.split('a', '%', true), {'a'}))
    assert(table.eq(string.split('a%', '%', true), {'a', ''}))
    assert(table.eq(string.split('a%--b', '%-', true), {'a', '-b'}))
    assert(table.eq(string.split('"a b" "c d"', '"', true), {'', 'a b', ' ', 'c d', ''}))
    assert(table.eq(string.split('"a b" "c d"', ' ', true), {'"a', 'b"', '"c', 'd"'}))
    assert(table.eq(string.qsplit('"a b" "c d"', ' '), {'"a b"', '"c d"'}))
    assert(table.eq(string.qsplit("'a b' 'c d'", ' '), {"'a b'", "'c d'"}))
    assert(table.eq(string.qsplit('"a\' b" "c d"', ' '), {'"a\' b"', '"c d"'}))
    assert(table.eq(string.qsplit("'a\" b' 'c d'", ' '), {"'a\" b'", "'c d'"}))
    assert(string.startswith('abcde', 'abc'))
    assert(string.startswith('abc', 'abc'))
    assert(not string.startswith('bcde', 'abc'))
    assert(string.endswith('abcde', 'cde'))
    assert(string.endswith('abc', 'abc'))
    assert(not string.endswith('bcde', 'bcd'))
    assert(string.trim(' abc ') == 'abc')
    assert(string.ltrim(' abc ') == 'abc ')
    assert(string.rtrim(' abc ') == ' abc')
    assert(table.eq(string.chars('abc'), {'a', 'b', 'c'}))
    assert(table.eq(string.bytes('abc'), {0x61, 0x62, 0x63}))
    assert(string.escpat('[[--x') == '%[%[%-%-x')
    assert(string.isalnum 'abcABC123')
    assert(not string.isalnum 'abc-ABC123')
    assert(string.isalpha 'abcABC')
    assert(not string.isalpha 'abcABC123')
    assert(string.isidentifier 'abcABC3')
    assert(string.isidentifier '_3')
    assert(not string.isidentifier '3abcABC123')
    assert(not string.isidentifier 'abc ABC123')
    assert(string.islower 'abc123')
    assert(not string.islower 'abcABC123')
    assert(string.isnumeric '123')
    assert(not string.isnumeric '123abcABC')
    assert(string.isprintable 'abc,:ABC!123')
    assert(not string.isprintable '\xff\x00123abcABC')
    assert(string.isspace ' 	\n')
    assert(not string.isspace 'abc ABC')
    assert(string.isupper 'ABC123')
    assert(not string.isupper 'abcABC123')
    assert(string.capitalize 'robot' == 'Robot')
    assert(string.escapequotes('abc') == 'abc')
    assert(string.escapequotes('a = \'b\'', '\'') == 'a = \\\'b\\\'')
    assert(string.escapequotes('a = \'b\'', '\"') == 'a = \'b\'')
    assert(string.escapequotes('a = "b"', '\'') == 'a = "b"')
    assert(string.escapequotes('a = "b"', '"') == 'a = \\"b\\"')
    assert(string.padlines('a\naa\naaa', 4) == 'a   \naa  \naaa ')
    print(debug.getinfo(1, 'S').source, 'tests passed')
end
