local class = require 'middleclass'

local Color = class 'Color'

local ColorNames = {}

for k, v in pairs{
    ['#CD5C5C'] = 'IndianRed',
    ['#F08080'] = 'LightCoral',
    ['#FA8072'] = 'Salmon',
    ['#E9967A'] = 'DarkSalmon',
    ['#FFA07A'] = 'LightSalmon',
    ['#DC143C'] = 'Crimson',
    ['#FF0000'] = 'Red',
    ['#B22222'] = 'FireBrick',
    ['#8B0000'] = 'DarkRed',
    ['#FFC0CB'] = 'Pink',
    ['#FFB6C1'] = 'LightPink',
    ['#FF69B4'] = 'HotPink',
    ['#FF1493'] = 'DeepPink',
    ['#C71585'] = 'MediumVioletRed',
    ['#DB7093'] = 'PaleVioletRed',
    ['#FFA07A'] = 'LightSalmon',
    ['#FF7F50'] = 'Coral',
    ['#FF6347'] = 'Tomato',
    ['#FF4500'] = 'OrangeRed',
    ['#FF8C00'] = 'DarkOrange',
    ['#FFA500'] = 'Orange',
    ['#FFD700'] = 'Gold',
    ['#FFFF00'] = 'Yellow',
    ['#FFFFE0'] = 'LightYellow',
    ['#FFFACD'] = 'LemonChiffon',
    ['#FAFAD2'] = 'LightGoldenrodYellow',
    ['#FFEFD5'] = 'PapayaWhip',
    ['#FFE4B5'] = 'Moccasin',
    ['#FFDAB9'] = 'PeachPuff',
    ['#EEE8AA'] = 'PaleGoldenrod',
    ['#F0E68C'] = 'Khaki',
    ['#BDB76B'] = 'DarkKhaki',
    ['#E6E6FA'] = 'Lavender',
    ['#D8BFD8'] = 'Thistle',
    ['#DDA0DD'] = 'Plum',
    ['#EE82EE'] = 'Violet',
    ['#DA70D6'] = 'Orchid',
    ['#FF00FF'] = 'Fuchsia',
    ['#FF00FF'] = 'Magenta',
    ['#BA55D3'] = 'MediumOrchid',
    ['#9370DB'] = 'MediumPurple',
    ['#663399'] = 'RebeccaPurple',
    ['#8A2BE2'] = 'BlueViolet',
    ['#9400D3'] = 'DarkViolet',
    ['#9932CC'] = 'DarkOrchid',
    ['#8B008B'] = 'DarkMagenta',
    ['#800080'] = 'Purple',
    ['#4B0082'] = 'Indigo',
    ['#6A5ACD'] = 'SlateBlue',
    ['#483D8B'] = 'DarkSlateBlue',
    ['#7B68EE'] = 'MediumSlateBlue',
    ['#ADFF2F'] = 'GreenYellow',
    ['#7FFF00'] = 'Chartreuse',
    ['#7CFC00'] = 'LawnGreen',
    ['#00FF00'] = 'Lime',
    ['#32CD32'] = 'LimeGreen',
    ['#98FB98'] = 'PaleGreen',
    ['#90EE90'] = 'LightGreen',
    ['#00FA9A'] = 'MediumSpringGreen',
    ['#00FF7F'] = 'SpringGreen',
    ['#3CB371'] = 'MediumSeaGreen',
    ['#2E8B57'] = 'SeaGreen',
    ['#228B22'] = 'ForestGreen',
    ['#008000'] = 'Green',
    ['#006400'] = 'DarkGreen',
    ['#9ACD32'] = 'YellowGreen',
    ['#6B8E23'] = 'OliveDrab',
    ['#808000'] = 'Olive',
    ['#556B2F'] = 'DarkOliveGreen',
    ['#66CDAA'] = 'MediumAquamarine',
    ['#8FBC8B'] = 'DarkSeaGreen',
    ['#20B2AA'] = 'LightSeaGreen',
    ['#008B8B'] = 'DarkCyan',
    ['#008080'] = 'Teal',
    ['#00FFFF'] = 'Aqua',
    ['#00FFFF'] = 'Cyan',
    ['#E0FFFF'] = 'LightCyan',
    ['#AFEEEE'] = 'PaleTurquoise',
    ['#7FFFD4'] = 'Aquamarine',
    ['#40E0D0'] = 'Turquoise',
    ['#48D1CC'] = 'MediumTurquoise',
    ['#00CED1'] = 'DarkTurquoise',
    ['#5F9EA0'] = 'CadetBlue',
    ['#4682B4'] = 'SteelBlue',
    ['#B0C4DE'] = 'LightSteelBlue',
    ['#B0E0E6'] = 'PowderBlue',
    ['#ADD8E6'] = 'LightBlue',
    ['#87CEEB'] = 'SkyBlue',
    ['#87CEFA'] = 'LightSkyBlue',
    ['#00BFFF'] = 'DeepSkyBlue',
    ['#1E90FF'] = 'DodgerBlue',
    ['#6495ED'] = 'CornflowerBlue',
    ['#7B68EE'] = 'MediumSlateBlue',
    ['#4169E1'] = 'RoyalBlue',
    ['#0000FF'] = 'Blue',
    ['#0000CD'] = 'MediumBlue',
    ['#00008B'] = 'DarkBlue',
    ['#000080'] = 'Navy',
    ['#191970'] = 'MidnightBlue',
    ['#FFF8DC'] = 'Cornsilk',
    ['#FFEBCD'] = 'BlanchedAlmond',
    ['#FFE4C4'] = 'Bisque',
    ['#FFDEAD'] = 'NavajoWhite',
    ['#F5DEB3'] = 'Wheat',
    ['#DEB887'] = 'BurlyWood',
    ['#D2B48C'] = 'Tan',
    ['#BC8F8F'] = 'RosyBrown',
    ['#F4A460'] = 'SandyBrown',
    ['#DAA520'] = 'Goldenrod',
    ['#B8860B'] = 'DarkGoldenrod',
    ['#CD853F'] = 'Peru',
    ['#D2691E'] = 'Chocolate',
    ['#8B4513'] = 'SaddleBrown',
    ['#A0522D'] = 'Sienna',
    ['#A52A2A'] = 'Brown',
    ['#800000'] = 'Maroon',
    ['#FFFFFF'] = 'White',
    ['#FFFAFA'] = 'Snow',
    ['#F0FFF0'] = 'HoneyDew',
    ['#F5FFFA'] = 'MintCream',
    ['#F0FFFF'] = 'Azure',
    ['#F0F8FF'] = 'AliceBlue',
    ['#F8F8FF'] = 'GhostWhite',
    ['#F5F5F5'] = 'WhiteSmoke',
    ['#FFF5EE'] = 'SeaShell',
    ['#F5F5DC'] = 'Beige',
    ['#FDF5E6'] = 'OldLace',
    ['#FFFAF0'] = 'FloralWhite',
    ['#FFFFF0'] = 'Ivory',
    ['#FAEBD7'] = 'AntiqueWhite',
    ['#FAF0E6'] = 'Linen',
    ['#FFF0F5'] = 'LavenderBlush',
    ['#FFE4E1'] = 'MistyRose',
    ['#DCDCDC'] = 'Gainsboro',
    ['#D3D3D3'] = 'LightGray',
    ['#C0C0C0'] = 'Silver',
    ['#A9A9A9'] = 'DarkGray',
    ['#808080'] = 'Gray',
    ['#696969'] = 'DimGray',
    ['#778899'] = 'LightSlateGray',
    ['#708090'] = 'SlateGray',
    ['#2F4F4F'] = 'DarkSlateGray',
    ['#000000'] = 'Black',
} do
    ColorNames[v:lower()] = k
end

function Color:initialize(rgba)
    if type(rgba) == 'string' and ColorNames[rgba:lower()] then
        rgba = ColorNames[rgba:lower()]
    end

    if type(rgba) == 'string' then
        assert(rgba:sub(1, 1) == '#', 'invalid format')
        rgba = rgba:sub(2)
        if #rgba == 3 then
            rgba = rgba .. 'F'
        end
        if #rgba == 4 then
            local r, g, b, a = table.unpack(string.chars(rgba))
            rgba = r .. r .. g .. g .. b .. b .. a .. a
        end
        if #rgba == 6 then
            rgba = rgba .. 'FF'
        end
        assert(#rgba == 8, 'invalid string format')
        rgba = tonumber('0x' .. rgba)
        rgba = {
            ((rgba & 0xFF000000) >> 24) / 255.,
            ((rgba & 0x00FF0000) >> 16) / 255.,
            ((rgba & 0x0000FF00) >>  8) / 255.,
             (rgba & 0x000000FF)        / 255.,
        }
    end

    assert(type(rgba) == 'table', 'invalid type')
    if #rgba == 3 then table.insert(rgba, 1.0) end
    assert(#rgba == 4, 'incorrect table size')
    self.r, self.g, self.b, self.a = table.unpack(rgba)
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

function Color:alpha()
    return math.max(0, math.min(1, self.a))
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

function Color:a8()
    return math.min(255, math.floor(self:alpha() * 256))
end

function Color:rgb888()
    return (self:r8() << 16) | (self:g8() << 8) | self:b8()
end

function Color:rgba888()
    return (self:r8() << 24) | (self:g8() << 16) | (self:b8() << 8) | self:a8()
end

function Color:rgb888table()
    return {self:r8(), self:g8(), self:b8()}
end

function Color:rgba888table()
    return {self:r8(), self:g8(), self:b8(), self:a8()}
end

function Color:data()
    return {self:red(), self:green(), self:blue(), self:alpha()}
end

function Color:inverted()
    return Color{1 - self:red(), 1 - self:green(), 1 - self:blue(), self:alpha()}
end

function Color:html(format)
    format = format or 'auto'
    if format == 'auto' then
        local a8 = self:a8()
        format = a8 < 255 and 'rgba' or 'rgb'
    end
    if format == 'rgba' then
        return string.format('#%02x%02x%02x%02x', self:r8(), self:g8(), self:b8(), self:a8())
    elseif format == 'rgb' then
        return string.format('#%02x%02x%02x', self:r8(), self:g8(), self:b8())
    else
        error 'invalid format'
    end
end

function Color:__copy()
    return Color(self:data())
end

function Color:__deepcopy(m)
    return Color(self:data())
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
    return cbor_c.encode(0xC0, cbor.Tags.Sim.Color)
        .. cbor.encode(self:data())
end

function Color.static:rgb(r, g, b)
    return Color:rgba(r, g, b, 1)
end

function Color.static:rgba(r, g, b, a)
    for k, v in pairs{red = r, green = g, blue = b, alpha = a} do
        assert(type(v) == 'number' and v >= 0 and v <= 1, k .. ' component must be a number [0..1]')
    end
    return Color{r, g, b, a}
end

function Color.static:hsv(h, s, v)
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

function Color.static:iscolor(c)
    return Color.isInstanceOf(c, Color)
end

function Color.static:tocolor(c)
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
