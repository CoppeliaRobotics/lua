local simCBOR = {}

local cbor = require 'org.conman.cbor'

local type_tags = {}


-- NOTE: before defining custom type tags, check on
--       https://www.iana.org/assignments/cbor-tags/cbor-tags.xhtml
--       if a type tag for that type has been already reserved.


-- RFC8746 multi-dimensional array tag
function type_tags.TAG_40(values)
    local simEigen = require('simEigen')
    local rows, cols = table.unpack(values[1])
    local data = values[2]
    return simEigen.Matrix(rows, cols, data)
end

function simCBOR.decode(data)
    return cbor.decode(data, 1, type_tags)
end

function simCBOR.encode(...)
    return cbor.encode(...)
end

return simCBOR
