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
    local ok, val = pcall(utf8.len, s)
    if not ok then return false end -- e.g.: "invalid UTF-8 sequence" error (?)
    if val == nil then return false end -- utf8.len returns nil for invalid seq

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
    opts.entities = opts.entities ~= false
    if opts.entities then
        local htmlEntities = {
            ["&"] = "&amp;",
            ["<"] = "&lt;",
            [">"] = "&gt;",
            ['"'] = "&quot;",
            ["'"] = "&apos;",
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

    -- Remove headers at start of a line, with or without trailing newline
    s = s:gsub("^##+ ([^\n]*)\n", "%1\n")
    s = s:gsub("\n##+ ([^\n]*)\n", "\n%1\n")
    s = s:gsub("^##+ ([^\n]*)$", "%1")
    s = s:gsub("\n##+ ([^\n]*)$", "\n%1")

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

function string.renderxml(node, opts, _indent)
    if type(opts) == 'string' then
        -- backward compatibility fix: second arg was attrs_order
        opts = {attrsOrder = opts}
    end
    opts = opts or {}
    _indent = _indent or ""
    local nl = "\n"

    local shortFormat = nil
    if node.tag == nil then
        assert(type(node[1]) == 'string', 'missing tag')
        shortFormat = true
    else
        shortFormat = false
    end

    local xml = {}

    local tag = shortFormat and node[1] or node.tag

    local function normalizeAttribute(a)
        if opts.attrUnderscoreToDash ~= false then
            a = a:gsub('_', '-')
        end
        return a
    end

    local attrs = shortFormat and node or node.attrs
    local attrsEntries = {}
    if attrs then
        local attrsNorm = {}
        for k, v in pairs(attrs) do
            if type(k) == 'string' then
                k = normalizeAttribute(k)
                attrsNorm[k] = v
            end
        end
        local done = {}
        for _, k in ipairs(opts.attrsOrder or {}) do
            k = normalizeAttribute(k)
            local v = attrsNorm[k]
            if v then
                table.insert(attrsEntries, {k, v})
                done[k] = true
            end
        end
        for k, v in pairs(attrsNorm) do
            if not done[k] then
                table.insert(attrsEntries, {k, v})
            end
        end
    end
    local attrsStr = ""
    for _, attrEntry in ipairs(attrsEntries) do
        local k, v = table.unpack(attrEntry)
        v = string.escapehtml(tostring(v))
        attrsStr = attrsStr .. string.format(' %s="%s"', k, string.escapehtml(tostring(v)))
    end

    local children = shortFormat and node or node.children or {}
    local numChildren = shortFormat and (#children - 1) or #children
    local i = shortFormat and 2 or 1 -- starting index

    if numChildren == 0 then
        table.insert(xml, string.format("%s<%s%s />", _indent, tag, attrsStr))
        return table.concat(xml, "")
    end

    -- exactly one text child -> inline start/end tag
    if numChildren == 1 and type(children[i]) == "string" then
        table.insert(xml, string.format("%s<%s%s>%s</%s>", _indent, tag, attrsStr, string.escapehtml(children[i]), tag))
        return table.concat(xml)
    end

    table.insert(xml, string.format("%s<%s%s>", _indent, tag, attrsStr))
    while children[i] do
        if type(children[i]) == "string" then
            table.insert(xml, string.escapehtml(children[i]))
        else
            table.insert(xml, nl .. string.renderxml(children[i], opts, _indent .. "  "))
        end
        i = i + 1
    end
    table.insert(xml, string.format("%s</%s>", nl .. _indent, tag))

    return table.concat(xml)
end

function string.stripprefix(s, prefix)
    if string.startswith(s, prefix) then
        return s:sub(#prefix + 1)
    else
        return s
    end
end

function string.stripsuffix(s, suffix)
    if string.endswith(s, suffix) then
        return s:sub(1, #s - #suffix)
    else
        return s
    end
end

function string.elide(s, maxLen, opts)
    maxLen = maxLen or 80
    opts = opts or {}
    local ret = s
    if opts.truncateAtNewLine then
        local n = ret:find("\n")
        if n then
            ret = ret:sub(1, n - 1)
        end
    end
    if #ret > maxLen then
        ret = ret:sub(1, maxLen)
    end
    if #ret < #s then
        ret = ret .. "..."
    end
    return ret
end

function string.utf8sub(s, i, j)
    local start_byte = utf8.offset(s, i) or (#s + 1)
    local end_byte = j and (utf8.offset(s, j + 1) or (#s + 1)) - 1 or #s
    return s:sub(start_byte, end_byte)
end

function string._len(s)
    -- undocumented
    if s == '' then return 0 end
    local l, o = utf8.len(s)
    if l then
        return l
    else
        return utf8.len(s:sub(1, o - 1)) + 1 + string._len(s:sub(o + 1))
    end
end

function string.pad(s, width, clip)
    if clip then
        s = string.utf8sub(s, 1, math.abs(width))
    end
    local p = string.rep(' ', math.abs(width) - string._len(s))
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
        width = math.max(width, string._len(lines[i]))
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

function string.numbertostring(x, opts)
    if math.type(x) ~= 'float' then
        return tostring(x)
    end

    opts = opts and table.clone(opts) or {}
    opts.numFloatDigits = math.max(0, opts.numFloatDigits or 6)
    opts.stripTrailingZeros = opts.stripTrailingZeros ~= false

    local s = string.format('%.' .. opts.numFloatDigits .. 'f', x)
    if opts.stripTrailingZeros then
        local i, d = table.unpack(string.split(s, '%.'))
        d = string.gsub(d or '', '0*$', '')
        s = i .. '.' .. d
    end
    return s
end

function string.getshortstring(x, opts)
    opts = opts or {}
    opts.omitQuotes = opts.omitQuotes == true
    opts.escapeNewline = opts.escapeNewline ~= false
    opts.allowBinary = opts.allowBinary == true
    opts.allowBinary = true

    if type(x) == 'string' then
        if not string.isprintable(x) and not opts.allowBinary then
            return string.format('[binary string (%s bytes)]', #x)
        end
        if opts.longStringThreshold and #x > opts.longStringThreshold then
            return string.format('[long string (%s bytes)]', #x)
        end
        if not opts.omitQuotes then
            x = "'" .. string.escapequotes(x, '\'') .. "'"
        end
        if opts.escapeNewline then
            x = x:gsub('\n', '\\n')
        end
        return x
    end
    return "[not a string]"
end

function string.isidentifier(x)
    return type(x) == 'string' and x:match('^[a-zA-Z_][a-zA-Z0-9_]*$') ~= nil
end

function string.anytostring(x, opts)
    opts = opts or {}
    local t = type(x)
    if t == 'nil' then
        return tostring(nil)
    elseif t == 'table' then
        local mt = getmetatable(x) or {}
        if opts.display and mt.__todisplay then return mt.__todisplay(x, opts) end
        if isbuffer(x) then return mt.__todisplay(x, opts) end
        if mt.__tostring then return mt.__tostring(x, opts) end
        -- displays inside table won't render good:
        opts = table.update({}, opts, {display = false})
        require 'tablex'
        return table.tostring(x, opts)
    elseif t == 'string' then
        return string.getshortstring(x, opts)
    elseif t == 'number' then
        return string.numbertostring(x, opts)
    else
        return tostring(x)
    end
end

function string.unittest()
    -- fix for "attempt to call a nil value (global 'isbuffer')"
    isbuffer = isbuffer or function(x) return false end

    require 'tablex'

    -- helpers:
    local function assert_eq(actual, expected, msg)
        if not table.eq(actual, expected) then
            error(string.format('%s\nactual: %s\nexpected: %s', msg or 'assert_eq failed', table.tostring(actual), table.tostring(expected)), 2)
        end
    end

    local function assert_eq_s(actual, expected, msg)
        if actual ~= expected then
            error(string.format('%s\nactual: %s\nexpected: %s', msg or 'assert_eq_s failed', tostring(actual), tostring(expected)), 2)
        end
    end

    do
        local it = string.gsplit('a,b,c', ',')
        assert_eq_s(it(), 'a')
        assert_eq_s(it(), 'b')
        assert_eq_s(it(), 'c')
        assert(it() == nil)
    end

    assert_eq(string.split('a%b%c', '%', true), {'a', 'b', 'c'})
    assert_eq(string.split('a', '%', true), {'a'})
    assert_eq(string.split('a%', '%', true), {'a', ''})
    assert_eq(string.split('a%--b', '%-', true), {'a', '-b'})
    assert_eq(string.split('"a b" "c d"', '"', true), {'', 'a b', ' ', 'c d', ''})
    assert_eq(string.split('"a b" "c d"', ' ', true), {'"a', 'b"', '"c', 'd"'})
    assert_eq(string.split('', ','), {''})
    assert_eq(string.split('a,b,', ','), {'a', 'b', ''})
    assert_eq(string.split(',a,b', ','), {'', 'a', 'b'})
    assert_eq(string.split('a,,b', ','), {'a', '', 'b'})
    assert_eq(string.split('abc', ''), {'a', 'b', 'c'})
    assert_eq(string.split('abc', 'b'), {'a', 'c'})

    assert_eq(string.qsplit('"a b" "c d"', ' '), {'"a b"', '"c d"'})
    assert_eq(string.qsplit("'a b' 'c d'", ' '), {"'a b'", "'c d'"})
    assert_eq(string.qsplit('"a\' b" "c d"', ' '), {'"a\' b"', '"c d"'})
    assert_eq(string.qsplit("'a\" b' 'c d'", ' '), {"'a\" b'", "'c d'"})
    assert_eq(string.qsplit('', ' '), {})
    assert_eq(string.qsplit('   ', ' '), {})
    assert_eq(string.qsplit('a  b', ' '), {'a', 'b'})
    assert_eq(string.qsplit('a "b c" d', ' '), {'a', '"b c"', 'd'})
    assert_eq(string.qsplit('"a \'b\' c" d', ' '), {'"a \'b\' c"', 'd'})
    assert_eq(string.qsplit('a "b c', ' '), {'a', '"b c'})

    assert(string.startswith('abcde', 'abc'))
    assert(string.startswith('abc', 'abc'))
    assert(not string.startswith('bcde', 'abc'))
    assert(string.startswith('abc', ''))
    assert(not string.startswith('', 'a'))

    assert(string.endswith('abcde', 'cde'))
    assert(string.endswith('abc', 'abc'))
    assert(not string.endswith('bcde', 'bcd'))
    assert(string.endswith('abc', ''))
    assert(not string.endswith('', 'a'))

    assert_eq_s(string.trim(' abc '), 'abc')
    assert_eq_s(string.ltrim(' abc '), 'abc ')
    assert_eq_s(string.rtrim(' abc '), ' abc')
    assert_eq_s(string.trim(''), '')
    assert_eq_s(string.trim('   '), '')
    assert_eq_s(string.ltrim('   '), '')
    assert_eq_s(string.rtrim('   '), '')

    assert_eq(string.chars('abc'), {'a', 'b', 'c'})
    assert_eq(string.chars(''), {})
    assert_eq(string.chars('\xC3\xA9'), {'\xC3', '\xA9'})

    assert_eq(string.bytes('abc'), {0x61, 0x62, 0x63})
    assert_eq(string.bytes(''), {})
    assert_eq(string.bytes('\xC3\xA9'), {0xC3, 0xA9}) -- UTF-8 é

    assert_eq_s(string.escpat('[[--x'), '%[%[%-%-x')
    assert_eq_s(string.escpat('^()%.[]*+-?$'), '%^%(%)%%%.%[%]%*%+%-%?%$')

    assert(string.isalnum 'abcABC123')
    assert(not string.isalnum 'abc-ABC123')
    assert(string.isalnum '')

    assert(string.isalpha 'abcABC')
    assert(not string.isalpha 'abcABC123')
    assert(string.isalpha '')

    assert(string.islower 'abc123')
    assert(not string.islower 'abcABC123')
    assert(string.islower '')

    assert(string.isupper 'ABC123')
    assert(not string.isupper 'abcABC123')
    assert(string.isupper '')

    assert(string.isnumeric '123')
    assert(not string.isnumeric '123abcABC')
    assert(string.isnumeric '')

    assert(string.isspace ' 	\n')
    assert(not string.isspace 'abc ABC')
    assert(string.isspace '')

    assert(string.isidentifier 'abcABC3')
    assert(string.isidentifier '_3')
    assert(not string.isidentifier '3abcABC123')
    assert(not string.isidentifier 'abc ABC123')
    assert(not string.isidentifier '')

    assert(string.isprintable 'abc,:ABC!123')
    assert(not string.isprintable '\xff\x00123abcABC')
    assert(not string.isprintable '\001')
    assert(string.isprintable '\xC3\xA9') -- é
    assert(not string.isprintable '\255') -- invalid UTF-8
    assert(string.isprintable '')

    assert_eq_s(string.capitalize 'robot', 'Robot')
    assert_eq_s(string.capitalize 'robot', 'Robot')
    assert_eq_s(string.capitalize 'robotArray', 'RobotArray')
    assert_eq_s(string.capitalize '', '')

    assert_eq_s(string.escapequotes('abc'), 'abc')
    assert_eq_s(string.escapequotes('a = \'b\'', '\''), 'a = \\\'b\\\'')
    assert_eq_s(string.escapequotes('a = \'b\'', '\"'), 'a = \'b\'')
    assert_eq_s(string.escapequotes('a = "b"', '\''), 'a = "b"')
    assert_eq_s(string.escapequotes('a = "b"', '"'), 'a = \\"b\\"')
    assert_eq_s(string.escapequotes('a\\b', "'"), 'a\\\\b')
    assert_eq_s(string.escapequotes('a\\b', '"'), 'a\\\\b')
    do
        local ok = pcall(string.escapequotes, 'x', '`')
        assert(not ok)
    end

    assert_eq_s(string.escapehtml('&<>"\''), '&amp;&lt;&gt;&quot;&apos;')
    assert_eq_s(string.escapehtml('&<>', {entities = false}), '&<>')

    assert_eq_s(string.stripmarkdown('## Header\n**bold** _italic_ `code` [link](url)'), 'Header\nbold italic code link')
    assert_eq_s(string.stripmarkdown('[link](url)', {keeplinks = true}), '[link](url)')

    assert_eq_s(string.stripprefix('foobar', 'foo'), 'bar')
    assert_eq_s(string.stripprefix('foobar', 'bar'), 'foobar')

    assert_eq_s(string.stripsuffix('foobar', 'bar'), 'foo')
    assert_eq_s(string.stripsuffix('foobar', 'foo'), 'foobar')

    assert_eq_s(string.elide('abcdef', 3), 'abc...')
    assert_eq_s(string.elide('abc', 5), 'abc')
    assert_eq_s(string.elide('a\nb', 10, {truncateAtNewLine = true}), 'a...')

    local e = '\xC3\xA9'  -- é

    do
        local s = 'a' .. e .. 'bc'
        assert_eq_s(string.utf8sub(s, 1, 1), 'a')
        assert_eq_s(string.utf8sub(s, 2, 2), e)
        assert_eq_s(string.utf8sub(s, 3, 3), 'b')
        assert_eq_s(string.utf8sub(s, 4, 4), 'c')
        assert_eq_s(string.utf8sub(s, 1, 4), s)
        assert_eq_s(string.utf8sub(s, 2), e .. 'bc')   -- j omitted → to end
        assert_eq_s(string.utf8sub(s, 2, 100), e .. 'bc') -- j past end
        assert_eq_s(string.utf8sub(s, 5, 5), '')       -- i past end

        assert_eq_s(string._len('a' .. e .. 'bc'), 4)
        assert_eq_s(string._len(''), 0)
    end

    assert_eq_s(string.pad(e, 2), e .. ' ')
    assert_eq_s(string.pad(e, -2), ' ' .. e)
    assert_eq_s(string.pad('aaa', 4), 'aaa ')
    assert_eq_s(string.pad('aaa', -4), ' aaa')
    assert_eq_s(string.pad('aaa', 2), 'aaa')
    assert_eq_s(string.pad('aaa', 2, true), 'aa')

    assert_eq({string.blocksize(e .. '\nabc')}, {3, 2})
    assert_eq({string.blocksize('aaa\naaa')}, {3, 2})

    assert_eq_s(string.blockpad('a\nbb', 3, -3), '   \na  \nbb ')
    assert_eq_s(string.blockpad('a\naa', 4, 3), 'a   \naa  \n    ')

    assert_eq_s(string.blockhstack({'aa', 'bbb'}, 2), 'aa  bbb')
    assert_eq_s(string.blockhstack({'aa\naa', 'bbb\nbbb\nbbb'}), '   bbb\naa bbb\naa bbb')

    assert_eq_s(string.numbertostring(42), '42')
    assert_eq_s(string.numbertostring(1.23456789, {numFloatDigits = 2}), '1.23')
    assert_eq_s(string.numbertostring(1.2, {stripTrailingZeros = false, numFloatDigits = 4}), '1.2000')
    assert_eq_s(string.numbertostring(1.2, {numFloatDigits = 4}), '1.2')

    assert_eq_s(string.getshortstring('abc'), "'abc'")
    assert_eq_s(string.getshortstring("a'b"), "'a\\'b'")
    assert_eq_s(string.getshortstring('a\nb'), "'a\\nb'")
    assert_eq_s(string.getshortstring('abcdef', {longStringThreshold = 3}), '[long string (6 bytes)]')
    assert_eq_s(string.getshortstring('abc', {omitQuotes = true}), 'abc')

    assert_eq_s(string.anytostring(nil), 'nil')
    assert_eq_s(string.anytostring(42), '42')
    assert_eq_s(string.anytostring('abc'), "'abc'")

    do
        local opts = {
            attrsOrder = {
                'title', 'closeable', 'resizable', 'on-close',
                'id', 'style', 'read-only'
            }
        }
        local xml = string.renderxml({
            tag = 'ui',
            attrs = {
                title = 'thetitle',
                closeable = true,
                resizable = 4,
                ['on-close'] = ':onClose'
            },
            children = {
                {
                    tag = 'text-browser',
                    attrs = {
                        id = 1,
                        style = 'color: red;',
                        ['read-only'] = true
                    }
                }
            }
        }, opts)
        assert_eq_s(
            xml,
            '<ui title="thetitle" closeable="true" resizable="4" on-close=":onClose">\n' ..
            '  <text-browser id="1" style="color: red;" read-only="true" />\n' ..
            '</ui>'
        )
    end
    assert_eq_s(string.renderxml{tag = 'p', children = {'hello'}}, '<p>hello</p>')
    assert_eq_s(string.renderxml{'br'}, '<br />')
    assert_eq_s(
        string.renderxml{
            tag = 'ui',
            attrs = {
                title = 'thetitle',
                closeable = true,
                resizable = 4,
                ['on-close'] = ':onClose',
            },
            children = {
                {
                    tag = 'text-browser',
                    attrs = {
                        id = 1,
                        style = 'color: red;',
                        ['read-only'] = true,
                    }
                },
            },
        },
        string.renderxml{
            'ui',
            title = 'thetitle',
            closeable = true,
            resizable = 4,
            on_close = ':onClose',
            {
                'text-browser',
                id = 1,
                style = 'color: red;',
                read_only = true,
            },
        }
    )
    print(debug.getinfo(1, 'S').source, 'tests passed')
end
