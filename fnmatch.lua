-- Lua implementation of Python's fnmatch.fnmatch
-- Supports shell-style wildcards: *, ?, [seq], [!seq]
-- Caches compiled patterns with an LRU-like limit of 32768 entries.

local cache = {}
local MAX_CACHE = 32768
local cache_size = 0

-- Compile a shell pattern into a list of tokens.
local function compile_pattern(pat)
    local tokens = {}
    local i = 1
    local n = #pat

    while i <= n do
        local c = pat:sub(i, i)

        if c == '*' then
            table.insert(tokens, { type = "star" })
            i = i + 1

        elseif c == '?' then
            table.insert(tokens, { type = "question" })
            i = i + 1

        elseif c == '[' then
            -- Parse character class: [seq] or [!seq]
            local start = i
            i = i + 1  -- skip '['
            local negated = false

            if i <= n and pat:sub(i, i) == '!' then
                negated = true
                i = i + 1
            end

            -- Build the sequence inside the brackets.
            local seq = ""
            local j = i
            while j <= n do
                if pat:sub(j, j) == ']' then
                    -- If this ']' is the first character of seq, it is literal.
                    if j == i then
                        seq = seq .. ']'
                        j = j + 1
                    else
                        -- Found the closing ']'
                        break
                    end
                else
                    seq = seq .. pat:sub(j, j)
                    j = j + 1
                end
            end

            if j > n then
                error("Unclosed character class in pattern: " .. pat)
            end

            -- Now parse seq into a list of characters and ranges.
            local class_items = {}
            local k = 1
            local slen = #seq
            while k <= slen do
                local ch = seq:sub(k, k)
                if ch == '-' and k > 1 and k < slen then
                    -- Range: previous character to next character
                    local prev = seq:sub(k - 1, k - 1)
                    local nxt = seq:sub(k + 1, k + 1)
                    table.insert(class_items, { type = "range", from = prev, to = nxt })
                    k = k + 2  -- consume '-' and the next char
                else
                    table.insert(class_items, { type = "char", char = ch })
                    k = k + 1
                end
            end

            table.insert(tokens, {
                type = "class",
                negated = negated,
                items = class_items
            })

            i = j + 1  -- skip closing ']'

        else
            -- Literal character
            table.insert(tokens, { type = "literal", char = c })
            i = i + 1
        end
    end

    return tokens
end

-- Match compiled tokens against a string.
local function match_tokens(tokens, str)
    local n = #str

    local function match(idx, pos)
        -- idx: current token index (1-based)
        -- pos: current position in str (1-based)
        if idx > #tokens then
            return pos == n + 1
        end

        local tok = tokens[idx]

        if tok.type == "literal" then
            if pos <= n and str:sub(pos, pos) == tok.char then
                return match(idx + 1, pos + 1)
            end
            return false

        elseif tok.type == "question" then
            if pos <= n then
                return match(idx + 1, pos + 1)
            end
            return false

        elseif tok.type == "star" then
            -- Try all possible lengths (including 0) for what '*' can consume
            for len = 0, n - pos + 1 do
                if match(idx + 1, pos + len) then
                    return true
                end
            end
            return false

        elseif tok.type == "class" then
            if pos > n then
                return false
            end

            local ch = str:sub(pos, pos)
            local in_class = false

            for _, item in ipairs(tok.items) do
                if item.type == "char" then
                    if item.char == ch then
                        in_class = true
                        break
                    end
                elseif item.type == "range" then
                    if ch >= item.from and ch <= item.to then
                        in_class = true
                        break
                    end
                end
            end

            if tok.negated then
                in_class = not in_class
            end

            if in_class then
                return match(idx + 1, pos + 1)
            end
            return false

        else
            error("Unknown token type")
        end
    end

    return match(1, 1)
end

local fnmatch = {}

function fnmatch.fnmatch(name, pat)
    if type(name) ~= "string" or type(pat) ~= "string" then
        error("name and pat must be strings")
    end

    -- Retrieve from cache or compile
    local tokens = cache[pat]
    if not tokens then
        tokens = compile_pattern(pat)

        -- Simple cache management (clear when limit reached)
        if cache_size >= MAX_CACHE then
            cache = {}
            cache_size = 0
        end
        cache[pat] = tokens
        cache_size = cache_size + 1
    end

    return match_tokens(tokens, name)
end

function string.unittest()
    assert(fnmatch.fnmatch('abc', 'abc'))
    assert(fnmatch.fnmatch('abc', 'ab*'))
    assert(fnmatch.fnmatch('abc', 'a*c'))
    assert(fnmatch.fnmatch('abc', 'a?c'))
    assert(fnmatch.fnmatch('abbbbc', 'a*c'))
    assert(not fnmatch.fnmatch('abbbbc', 'a?c'))
    assert(not fnmatch.fnmatch('abd', 'abc'))
    assert(not fnmatch.fnmatch('abcd', 'abc'))
    assert(not fnmatch.fnmatch('abc', 'abcd'))
    assert(not fnmatch.fnmatch('abd', 'ac*'))
    print(debug.getinfo(1, 'S').source, 'tests passed')
end

return fnmatch
