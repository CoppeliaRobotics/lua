local base64 = {}

function base64.encode(d)
    local sim = require('sim-2')
    return sim.transformBuffer(d, sim.buffer_uint8, 1, 0, sim.buffer_base64)
end

function base64.decode(d)
    local sim = require('sim-2')
    return sim.transformBuffer(d, sim.buffer_base64, 1, 0, sim.buffer_uint8)
end

return base64
