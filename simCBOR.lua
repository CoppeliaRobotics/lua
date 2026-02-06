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

-- RFC8746 typed-arrays: uint8 Typed Array
function type_tags.TAG_64(values)
    return sim.unpackUInt8Table(values)
end

-- RFC8746 typed-arrays: uint16, little endian, Typed Array
function type_tags.TAG_69(values)
    return sim.unpackUInt16Table(values)
end

-- RFC8746 typed-arrays: uint32, little endian, Typed Array
function type_tags.TAG_70(values)
    return sim.unpackUInt32Table(values)
end

-- RFC8746 typed-arrays: uint64, little endian, Typed Array
function type_tags.TAG_71(values)
    return sim.unpackUInt64Table(values)
end

-- RFC8746 typed-arrays: sint32, little endian, Typed Array
function type_tags.TAG_78(values)
    return sim.unpackInt32Table(values)
end

-- RFC8746 typed-arrays: sint64, little endian, Typed Array
function type_tags.TAG_79(values)
    return sim.unpackInt64Table(values)
end

-- RFC8746 typed-arrays: IEEE 754 binary32, little endian, Typed Array
function type_tags.TAG_85(values)
    return sim.unpackFloatTable(values)
end

-- RFC8746 typed-arrays: IEEE 754 binary64, little endian, Typed Array
function type_tags.TAG_86(values)
    return sim.unpackDoubleTable(values)
end

function type_tags.TAG_4294970000(value)
    local Color = require 'Color'
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

function type_tags.TAG_4294999999(value)
    local sim = require 'sim-2'
    return sim.Object(value)
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
