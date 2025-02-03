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

return itertools
