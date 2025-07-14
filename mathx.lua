math.atan2 = math.atan2 or math.atan

math.pow = math.pow or function(a, b)
    return a ^ b
end

math.log10 = math.log10 or function(a)
    return math.log(a, 10)
end

math.ldexp = math.ldexp or function(x, exp)
    return x * 2.0 ^ exp
end

math.frexp = math.frexp or function(x)
    return auxFunc('frexp', x)
end

math.mod = math.mod or math.fmod

math.hypot = math.hypot or function(...)
    local sum = 0
    for _, x in ipairs {...} do sum = sum + x * x end
    return math.sqrt(sum)
end

math.sign = math.sign or function(x)
    if x >= 0 then
        return 1
    else
        return -1
    end
end

function math.random2(lower, upper)
    -- same as math.random, but each script has its own generator
    local r = auxFunc('rand')
    if lower then
        local b = 1
        local d
        if upper then
            b = lower
            d = upper - b
        else
            d = lower - b
        end
        local e = d / (d + 1)
        r = b + math.floor(r * d / e)
    end
    return r
end

function math.randomseed2(seed)
    -- same as math.randomseed, but each script has its own generator
    auxFunc('randseed', seed)
end

math.randomseed = wrap(math.randomseed, function(origFunc)
    return function(a, ...)
        return origFunc(math.floor(a), ...) -- in Lua 5.4 only integer accepted
    end
end)
