local itertools = {}

-- Chaining iterators for unordered key-value tables (pairs)
function itertools.chain(...)
    local iterators = { ... }
    local i = 1
    local current_iter, current_table, current_key = pairs(iterators[i] or {})

    return function()
        while i <= #iterators do
            local new_key, new_value = current_iter(current_table, current_key)
            if new_key ~= nil then
                current_key = new_key
                return new_key, new_value
            end
            -- Move to the next iterator when the current one is exhausted
            i = i + 1
            if i <= #iterators then
                current_iter, current_table, current_key = pairs(iterators[i] or {})
            end
        end
    end
end

-- Chaining iterators for ordered arrays (ipairs)
function itertools.ichain(...)
    local iterators = { ... }
    local i = 1
    local current_iter, current_table, current_index = ipairs(iterators[i] or {})

    return function()
        while i <= #iterators do
            local new_index, new_value = current_iter(current_table, current_index)
            if new_index ~= nil then
                current_index = new_index
                return new_index, new_value
            end
            -- Move to the next iterator when the current one is exhausted
            i = i + 1
            if i <= #iterators then
                current_iter, current_table, current_index = ipairs(iterators[i] or {})
            end
        end
    end
end

function itertools.product(arrays, current, results, index)
    -- Example usage:
    -- local p = itertools.product({{1, 2}, {"a", "b"}})

    current = current or {}
    results = results or {}
    index = index or 1

    if index > #arrays then
        table.insert(results, {table.unpack(current)})
        return results
    end

    for _, value in ipairs(arrays[index]) do
        current[index] = value
        itertools.product(arrays, current, results, index + 1)
    end

    return results
end

function itertools.permutations(arr, length, current, used, results)
    -- Example usage:
    -- local perm = itertools.permutations({1, 2, 3}, 2)

    length = length or #arr
    current = current or {}
    used = used or {}
    results = results or {}

    if #current == length then
        table.insert(results, {table.unpack(current)})
        return results
    end

    for i, value in ipairs(arr) do
        if not used[i] then
            used[i] = true
            table.insert(current, value)
            itertools.permutations(arr, length, current, used, results)
            table.remove(current)
            used[i] = false
        end
    end

    return results
end

function itertools.combinations(arr, length, start, current, results)
    -- Example usage:
    -- local comb = itertools.combinations({1, 2, 3}, 2)

    start = start or 1
    current = current or {}
    results = results or {}

    if #current == length then
        table.insert(results, {table.unpack(current)})
        return results
    end

    for i = start, #arr do
        table.insert(current, arr[i])
        itertools.combinations(arr, length, i + 1, current, results)
        table.remove(current)
    end

    return results
end

function itertools.combinations_with_replacement(arr, length, start, current, results)
    -- Example usage:
    -- local comb_wr = itertools.combinations_with_replacement({1, 2, 3}, 2)

    start = start or 1
    current = current or {}
    results = results or {}

    if #current == length then
        table.insert(results, {table.unpack(current)})
        return results
    end

    for i = start, #arr do
        table.insert(current, arr[i])
        itertools.combinations_with_replacement(arr, length, i, current, results)
        table.remove(current)
    end

    return results
end

return itertools
