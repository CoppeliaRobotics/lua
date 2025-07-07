local sim = require 'sim'

local Color = {}

function Color:red()
    return math.max(0, math.min(1, self.r))
end

function Color:green()
    return math.max(0, math.min(1, self.g))
end

function Color:blue()
    return math.max(0, math.min(1, self.b))
end

function Color:r8()
    return math.min(255, math.floor(self:red() * 256))
end

function Color:g8()
    return math.min(255, math.floor(self:green() * 256))
end

function Color:b8()
    return math.min(255, math.floor(self:blue() * 256))
end

function Color:rgb888()
    return (self:r8() << 16) | (self:g8() << 8) | self:b8()
end

function Color:data()
    return {self:red(), self:green(), self:blue()}
end

function Color:inverted()
    return Color{1 - self:red(), 1 - self:green(), 1 - self:blue()}
end

function Color:iscolor(v)
    assert(self == Color, 'class method')
    return getmetatable(v) == Color
end

function Color:html()
    return string.format('#%02x%02x%02x', self:r8(), self:g8(), self:b8())
end

function Color:__eq(o)
    if Color:iscolor(o) then
        return self:html() == o:html()
    elseif type(o) == 'string' then
        return self:html() == o
    elseif math.type(o) == 'integer' then
        return self:rgb888() == o
    else
        return false
    end
end

function Color:__todisplay(opts)
    opts = opts or {}
    return string.format("Color '%s'", self:html())
end

function Color:__tostring()
    return string.format("Color '%s'", self:html())
end

function Color:__iscolor()
    return Color:iscolor(self)
end

function Color:__tocolor()
    return self:data()
end

function Color:__index(k)
    return Color[k]
end

function Color:__tocbor(sref, stref)
    local cbor = require 'org.conman.cbor'
    local cbor_c = require 'org.conman.cbor_c'
    return cbor_c.encode(0xC0, 4008)
        .. cbor.encode(self:rgb888())
end

setmetatable(
    Color, {
        __call = function(self, rgb)
            if type(rgb) == 'table' then
                assert(#rgb == 3, 'incorrect table size')
                return setmetatable({r = rgb[1], g = rgb[2], b = rgb[3]}, self)
            elseif type(rgb) == 'string' then
                assert(#rgb == 7 and rgb:sub(1, 1) == '#', 'invalid format')
                return Color(tonumber('0x' .. rgb:sub(2)))
            elseif math.type(rgb) == 'integer' then
                assert(0 <= rgb and rgb <= 0xFFFFFF, 'invalid value')
                return Color{
                    ((rgb & 0xFF0000) >> 16) / 255.,
                    ((rgb &   0xFF00) >>  8) / 255.,
                     (rgb &     0xFF)        / 255.,
                }
            else
                error 'invalid type'
            end
        end,
    }
)

function Color.unittest()
    assert(true)
    print(debug.getinfo(1, 'S').source, 'tests passed')
end

if arg and #arg == 1 and arg[1] == 'test' then
    Color.unittest()
end

return Color
