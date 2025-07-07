local function _callmeta(o, mm, d)
    local mt = getmetatable(o)
    if mt and mt[mm] then
        return mt[mm](o)
    else
        return d
    end
end

function ismatrix(o)
    return _callmeta(o, '__ismatrix', false)
end

function isvector3(o)
    return _callmeta(o, '__isvector3', false)
end

function isquaternion(o)
    return _callmeta(o, '__isquaternion', false)
end

function ispose(o)
    return _callmeta(o, '__ispose', false)
end

function iscolor(o)
    return _callmeta(o, '__iscolor', false)
end

function tomatrix(o)
    return _callmeta(o, '__tomatrix')
end

function tovector3(o)
    return _callmeta(o, '__tovector3')
end

function toquaternion(o)
    return _callmeta(o, '__toquaternion')
end

function topose(o)
    return _callmeta(o, '__topose')
end

function tocolor(o)
    return _callmeta(o, '__tocolor')
end
