local simCBOR = {}

local cbor = require 'org.conman.cbor'

local type_tags = {}


-- NOTE: before defining custom type tags, check on
--       https://www.iana.org/assignments/cbor-tags/cbor-tags.xhtml
--       if a type tag for that type has been already reserved.


-- RFC8746 multi-dimensional array tag
function type_tags.TAG_40(values)
    local simEigen = require 'simEigen'
    local rows, cols = table.unpack(values[1])
    local data = values[2]
    return simEigen.Matrix(rows, cols, data)
end

function type_tags.TAG_4294970000(value)
    local Color = require 'color'
    return Color(value)
end

function type_tags.TAG_4294980000(value)
    local simEigen = require 'simEigen'
    return simEigen.Quaternion(value)
end

function type_tags.TAG_4294980500(value)
    local simEigen = require 'simEigen'
    return simEigen.Pose(value)
end

function simCBOR.decode(data)
    return cbor.decode(data, 1, type_tags)
end

for _, name in ipairs {
    'encode',
    'isfloat',
    'isinteger',
    'isnumber',
    'pdecode',
    'pencode',
    '_VERSION',
    'SIMPLE',
    'TAG',
    'TYPE',
    '__ENCODE_MAP',
} do
    simCBOR[name] = cbor[name]
end

return simCBOR
