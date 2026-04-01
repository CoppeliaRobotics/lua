local simCBOR = {}

simCBOR.Tags = {
    Array = {
        Nd          =   40,
        Nd_RowMajor =   40,
        Nd_ColMajor = 1040,

        Homog   = 41,

        U8     = 64,
        U16BE  = 65,
        U32BE  = 66,
        U64BE  = 67,
        U8C    = 68,
        U16LE  = 69,
        U32LE  = 70,
        U64LE  = 71,
        S8     = 72,

        S16BE  = 73,
        S32BE  = 74,
        S64BE  = 75,
        S16LE  = 77,
        S32LE  = 78,
        S64LE  = 79,

        F16BE  = 80,
        F32BE  = 81,
        F64BE  = 82,
        F128BE = 83,
        F16LE  = 84,
        F32LE  = 85,
        F64LE  = 86,
        F128LE = 87,
    },
    Sim = {
        Handle = 4294999999,
        HandleArray = 4294999998,
        Quaternion = 4294980000,
        Color = 4294970000,
        Pose = 4294980500,
    },
}

local sim = require 'sim'
local cbor = require 'org.conman.cbor'

local type_tags = {}

local function registerTag(tagNumber)
    return function(fn)
        type_tags["TAG_" .. tagNumber] = fn
    end
end

-- NOTE: before defining custom type tags, check on
--       https://www.iana.org/assignments/cbor-tags/cbor-tags.xhtml
--       if a type tag for that type has been already reserved.


-- RFC8746 multi-dimensional array tag
registerTag(simCBOR.Tags.Array.Nd)(function(values)
    local simEigen = require 'simEigen'
    local rows, cols = table.unpack(values[1])
    local data = values[2]
    return simEigen.Matrix(rows, cols, data)
end)

-- RFC8746 typed-arrays: uint8 Typed Array
registerTag(simCBOR.Tags.Array.U8)(function(values)
    return sim.unpackUInt8Table(values)
end)

-- RFC8746 typed-arrays: uint16, little endian, Typed Array
registerTag(simCBOR.Tags.Array.U16LE)(function(values)
    return sim.unpackUInt16Table(values)
end)

-- RFC8746 typed-arrays: uint32, little endian, Typed Array
registerTag(simCBOR.Tags.Array.U32LE)(function(values)
    return sim.unpackUInt32Table(values)
end)

-- RFC8746 typed-arrays: sint32, little endian, Typed Array
registerTag(simCBOR.Tags.Array.S32LE)(function(values)
    return sim.unpackInt32Table(values)
end)

-- RFC8746 typed-arrays: sint64, little endian, Typed Array
registerTag(simCBOR.Tags.Array.S64LE)(function(values)
    return sim.unpackInt64Table(values)
end)

-- RFC8746 typed-arrays: IEEE 754 binary32, little endian, Typed Array
registerTag(simCBOR.Tags.Array.F32LE)(function(values)
    return sim.unpackFloatTable(values)
end)

-- RFC8746 typed-arrays: IEEE 754 binary64, little endian, Typed Array
registerTag(simCBOR.Tags.Array.F64LE)(function(values)
    return sim.unpackDoubleTable(values)
end)

registerTag(simCBOR.Tags.Sim.Color)(function(value)
    return Color(value)
end)

registerTag(simCBOR.Tags.Sim.Quaternion)(function(value)
    local simEigen = require 'simEigen'
    return simEigen.Quaternion(value)
end)

registerTag(simCBOR.Tags.Sim.Pose)(function(value)
    local simEigen = require 'simEigen'
    return simEigen.Pose(value)
end)

registerTag(simCBOR.Tags.Sim.Handle)(function(value)
    local sim = require 'sim-2'
    if value ~= -1 then
        return sim.Object(value)
    end
end)

registerTag(simCBOR.Tags.Sim.HandleArray)(function(value)
    local sim = require 'sim-2'
    return map(function(h)
        if h == -1 then return nil end
        return sim.Object(h)
    end, value)
end)

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
