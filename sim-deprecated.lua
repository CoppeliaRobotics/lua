local deprecated = {}

deprecated.functions = {
    {'addBanner', ''},
    {'readCustomDataBlock', 'readCustomStringData'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
    {'xxxxxxxxxxx', 'xxxxxxxxxxxx'},
}

function deprecated.extend(sim)
    for _, pair in ipairs(deprecated.functions) do
        local old, new = table.unpack(pair)
        if new == '' then
            sim[old] = wrap(sim[old], function(origFunc)
                return function(...)
                    sim.addLog(sim.verbosity_warnings | sim.verbosity_once, string.format('sim.%s is deprecated and the related functionality will disappear in a future release.', old, new))
                    origFunc(...)
                end
            end)
        else
            sim[old] = wrap(sim[old], function(origFunc)
                return function(...)
                    sim.addLog(sim.verbosity_warnings | sim.verbosity_once, string.format('sim.%s is deprecated. please use sim.%s instead.', old, new))
                    origFunc(...)
                end
            end)
        end
    end
end

return deprecated
