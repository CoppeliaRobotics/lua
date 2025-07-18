local class = require 'middleclass'

local Color = class 'Color'

function Color:initialize(rgb)
    if type(rgb) == 'string' then
        assert(rgb:sub(1, 1) == '#', 'invalid format')
        rgb = rgb:sub(2)
        if #rgb == 3 then
            local r, g, b = table.unpack(string.chars(rgb))
            rgb = r .. r .. g .. g .. b .. b
        end
        assert(#rgb == 6, 'invalid length')
        rgb = tonumber('0x' .. rgb)
    end

    if math.type(rgb) == 'integer' then
        assert(0 <= rgb and rgb <= 0xFFFFFF, 'invalid value')
        rgb = {
            ((rgb & 0xFF0000) >> 16) / 255.,
            ((rgb &   0xFF00) >>  8) / 255.,
             (rgb &     0xFF)        / 255.,
        }
    end

    assert(type(rgb) == 'table', 'invalid type')
    assert(#rgb == 3, 'incorrect table size')
    self.r, self.g, self.b = table.unpack(rgb)
end

function Color:red()
    return math.max(0, math.min(1, self.r))
end

function Color:green()
    return math.max(0, math.min(1, self.g))
end

function Color:blue()
    return math.max(0, math.min(1, self.b))
end

function Color:hue()
    local r, g, b = self:red(), self:green(), self:blue()
    local maxc = math.max(r, g, b)
    local minc = math.min(r, g, b)
    local d = maxc - minc

    if d == 0 then
        return 0 -- Undefined hue, grayscale
    end

    local h
    if maxc == r then
        h = (g - b) / d
        if g < b then h = h + 6 end
    elseif maxc == g then
        h = (b - r) / d + 2
    elseif maxc == b then
        h = (r - g) / d + 4
    end

    h = h / 6
    return h
end

function Color:saturation()
    local r, g, b = self:red(), self:green(), self:blue()
    local maxc = math.max(r, g, b)
    local minc = math.min(r, g, b)
    if maxc == 0 then
        return 0
    else
        return (maxc - minc) / maxc
    end
end

function Color:value()
    local r, g, b = self:red(), self:green(), self:blue()
    return math.max(r, g, b)
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

function Color:html()
    return string.format('#%02x%02x%02x', self:r8(), self:g8(), self:b8())
end

function Color:__copy()
    return Color(self:rgb888())
end

function Color:__deepcopy(m)
    return Color(self:rgb888())
end

function Color:__eq(o)
    if Color.isInstanceOf(o, Color) then
        return self:rgb888() == o:rgb888()
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
    return true
end

function Color:__tocolor()
    return self:data()
end

function Color:__tocbor(sref, stref)
    local cbor = require 'simCBOR'
    local cbor_c = require 'org.conman.cbor_c'
    return cbor_c.encode(0xC0, 4008)
        .. cbor.encode(self:rgb888())
end

function Color:rgb(r, g, b)
    assert(self == Color, 'class method')
    for k, v in pairs{red = r, green = g, blue = b} do
        assert(type(v) == 'number' and v >= 0 and v <= 1, k .. ' component must be a number [0..1]')
    end
    return Color{r, g, b}
end

function Color:hsv(h, s, v)
    assert(self == Color, 'class method')
    for k, w in pairs{hue = h, saturation = s, value = v} do
        assert(type(w) == 'number' and w >= 0 and w <= 1, k .. ' component must be a number [0..1]')
    end
    local r, g, b
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end
    return Color{r, g, b}
end

function Color:iscolor(c)
    assert(self == Color, 'class method')
    return Color:isInstanceOf(c, Color)
end

function Color:tocolor(c)
    assert(self == Color, 'class method')
    if Color:iscolor(c) then return c end
    if type(c) == 'table' and #t == 3 then return Color(c) end
    error 'bad data'
end

function Color.unittest()
    assert(true)
    print(debug.getinfo(1, 'S').source, 'tests passed')
end

if arg and #arg == 1 and arg[1] == 'test' then
    Color.unittest()
end

return Color
