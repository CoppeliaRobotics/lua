local deprecated = {}

deprecated.functions = {
    {'oldFunction1', 'newFunction1'},
    {'oldFunction2', 'newFunction2'},
}

function deprecated.extend(sim)
    for _, pair in ipairs(deprecated.functions) do
        local old, new = table.unpack(pair)
        sim[old] = function(...)
            sim.addLog(sim.verbosity_warnings | sim.verbosity_once, string.format('sim.%s is deprecated. please use sim.%s instead.', old, new))
            return sim[new](...)
        end
    end
end

return deprecated
