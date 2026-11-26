-- Internal helpers shared by the simMotion classes.
-- This module is not part of the public API (i.e. not listed in simMotion.__all).

local copy = require('copy')

local helpers = {}


-- Concatenates several flat Lua arrays into a new flat Lua array.
-- Used to build the arrays expected by the Ruckig functions, without
-- creating Matrix/Vector temporaries.
function helpers.concat(...)
    local arrays = {...}
    local result = {}
    local k = 1

    for i = 1, #arrays do
        local a = arrays[i]

        for j = 1, #a do
            result[k] = a[j]
            k = k + 1
        end
    end

    return result
end


-- Returns a new flat Lua array with all values negated.
function helpers.negateData(a)
    local result = {}

    for i = 1, #a do
        result[i] = -a[i]
    end

    return result
end


-- Extracts the three consecutive Ruckig sections from a flat Lua array,
-- without creating Matrix/Vector temporaries.
function helpers.splitPosVelAccel(data, dim)
    local pos = {}
    local vel = {}
    local accel = {}

    local offset1 = dim
    local offset2 = dim * 2

    for i = 1, dim do
        pos[i] = data[i]
        vel[i] = data[offset1 + i]
        accel[i] = data[offset2 + i]
    end

    return pos, vel, accel
end


-- Deep-copies motion parameters. 'auxData' is excluded from the copy and
-- re-attached by reference (it may contain non-copyable values, e.g. sim objects).
function helpers.copyParams(pparams)
    pparams = pparams or {}

    local auxData = pparams.auxData
    pparams.auxData = nil

    local params = copy.deepcopy(pparams)

    pparams.auxData = auxData
    params.auxData = auxData

    return params
end


return helpers
