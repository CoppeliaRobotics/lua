local class = require 'middleclass'

local Color = class 'Color'

local ColorNames = {}

for k, v in pairs{
    IndianRed = 0xCD5C5C,
    LightCoral = 0xF08080,
    Salmon = 0xFA8072,
    DarkSalmon = 0xE9967A,
    LightSalmon = 0xFFA07A,
    Crimson = 0xDC143C,
    Red = 0xFF0000,
    FireBrick = 0xB22222,
    DarkRed = 0x8B0000,
    Pink = 0xFFC0CB,
    LightPink = 0xFFB6C1,
    HotPink = 0xFF69B4,
    DeepPink = 0xFF1493,
    MediumVioletRed = 0xC71585,
    PaleVioletRed = 0xDB7093,
    LightSalmon = 0xFFA07A,
    Coral = 0xFF7F50,
    Tomato = 0xFF6347,
    OrangeRed = 0xFF4500,
    DarkOrange = 0xFF8C00,
    Orange = 0xFFA500,
    Gold = 0xFFD700,
    Yellow = 0xFFFF00,
    LightYellow = 0xFFFFE0,
    LemonChiffon = 0xFFFACD,
    LightGoldenrodYellow = 0xFAFAD2,
    PapayaWhip = 0xFFEFD5,
    Moccasin = 0xFFE4B5,
    PeachPuff = 0xFFDAB9,
    PaleGoldenrod = 0xEEE8AA,
    Khaki = 0xF0E68C,
    DarkKhaki = 0xBDB76B,
    Lavender = 0xE6E6FA,
    Thistle = 0xD8BFD8,
    Plum = 0xDDA0DD,
    Violet = 0xEE82EE,
    Orchid = 0xDA70D6,
    Fuchsia = 0xFF00FF,
    Magenta = 0xFF00FF,
    MediumOrchid = 0xBA55D3,
    MediumPurple = 0x9370DB,
    RebeccaPurple = 0x663399,
    BlueViolet = 0x8A2BE2,
    DarkViolet = 0x9400D3,
    DarkOrchid = 0x9932CC,
    DarkMagenta = 0x8B008B,
    Purple = 0x800080,
    Indigo = 0x4B0082,
    SlateBlue = 0x6A5ACD,
    DarkSlateBlue = 0x483D8B,
    MediumSlateBlue = 0x7B68EE,
    GreenYellow = 0xADFF2F,
    Chartreuse = 0x7FFF00,
    LawnGreen = 0x7CFC00,
    Lime = 0x00FF00,
    LimeGreen = 0x32CD32,
    PaleGreen = 0x98FB98,
    LightGreen = 0x90EE90,
    MediumSpringGreen = 0x00FA9A,
    SpringGreen = 0x00FF7F,
    MediumSeaGreen = 0x3CB371,
    SeaGreen = 0x2E8B57,
    ForestGreen = 0x228B22,
    Green = 0x008000,
    DarkGreen = 0x006400,
    YellowGreen = 0x9ACD32,
    OliveDrab = 0x6B8E23,
    Olive = 0x808000,
    DarkOliveGreen = 0x556B2F,
    MediumAquamarine = 0x66CDAA,
    DarkSeaGreen = 0x8FBC8B,
    LightSeaGreen = 0x20B2AA,
    DarkCyan = 0x008B8B,
    Teal = 0x008080,
    Aqua = 0x00FFFF,
    Cyan = 0x00FFFF,
    LightCyan = 0xE0FFFF,
    PaleTurquoise = 0xAFEEEE,
    Aquamarine = 0x7FFFD4,
    Turquoise = 0x40E0D0,
    MediumTurquoise = 0x48D1CC,
    DarkTurquoise = 0x00CED1,
    CadetBlue = 0x5F9EA0,
    SteelBlue = 0x4682B4,
    LightSteelBlue = 0xB0C4DE,
    PowderBlue = 0xB0E0E6,
    LightBlue = 0xADD8E6,
    SkyBlue = 0x87CEEB,
    LightSkyBlue = 0x87CEFA,
    DeepSkyBlue = 0x00BFFF,
    DodgerBlue = 0x1E90FF,
    CornflowerBlue = 0x6495ED,
    MediumSlateBlue = 0x7B68EE,
    RoyalBlue = 0x4169E1,
    Blue = 0x0000FF,
    MediumBlue = 0x0000CD,
    DarkBlue = 0x00008B,
    Navy = 0x000080,
    MidnightBlue = 0x191970,
    Cornsilk = 0xFFF8DC,
    BlanchedAlmond = 0xFFEBCD,
    Bisque = 0xFFE4C4,
    NavajoWhite = 0xFFDEAD,
    Wheat = 0xF5DEB3,
    BurlyWood = 0xDEB887,
    Tan = 0xD2B48C,
    RosyBrown = 0xBC8F8F,
    SandyBrown = 0xF4A460,
    Goldenrod = 0xDAA520,
    DarkGoldenrod = 0xB8860B,
    Peru = 0xCD853F,
    Chocolate = 0xD2691E,
    SaddleBrown = 0x8B4513,
    Sienna = 0xA0522D,
    Brown = 0xA52A2A,
    Maroon = 0x800000,
    White = 0xFFFFFF,
    Snow = 0xFFFAFA,
    HoneyDew = 0xF0FFF0,
    MintCream = 0xF5FFFA,
    Azure = 0xF0FFFF,
    AliceBlue = 0xF0F8FF,
    GhostWhite = 0xF8F8FF,
    WhiteSmoke = 0xF5F5F5,
    SeaShell = 0xFFF5EE,
    Beige = 0xF5F5DC,
    OldLace = 0xFDF5E6,
    FloralWhite = 0xFFFAF0,
    Ivory = 0xFFFFF0,
    AntiqueWhite = 0xFAEBD7,
    Linen = 0xFAF0E6,
    LavenderBlush = 0xFFF0F5,
    MistyRose = 0xFFE4E1,
    Gainsboro = 0xDCDCDC,
    LightGray = 0xD3D3D3,
    Silver = 0xC0C0C0,
    DarkGray = 0xA9A9A9,
    Gray = 0x808080,
    DimGray = 0x696969,
    LightSlateGray = 0x778899,
    SlateGray = 0x708090,
    DarkSlateGray = 0x2F4F4F,
    Black = 0x000000,
} do
    ColorNames[k:lower()] = v
end

function Color:initialize(rgb)
    if type(rgb) == 'string' and ColorNames[rgb:lower()] then
        rgb = ColorNames[rgb:lower()]
    end

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
    return cbor_c.encode(0xC0, 4294970000)
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
    if type(c) == 'table' and #c == 3 then return Color(c) end
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
