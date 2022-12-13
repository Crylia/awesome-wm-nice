-- => Shapes
-- Provides utility functions for handling cairo shapes and geometry
-- ============================================================
--
local cairo = require("lgi").cairo
local colors = require("src.lib.nice.colors")
local hex2rgb = colors.hex2rgb
-- Returns a circle of the specified size filled with the specified color
local function circle_filled(color, size)
    local surface = cairo.ImageSurface.create("ARGB32", size, size)
    local cr = cairo.Context.create(surface)
    cr:arc(size / 2, size / 2, size / 2, math.rad(0), math.rad(360))
    cr:set_source_rgba(hex2rgb(color or "#fefefa"))
    cr.antialias = cairo.Antialias.BEST
    cr:fill()
    return surface
end

-- Returns a vertical gradient pattern going from cololr_1 -> color_2
local function duotone_gradient_vertical(color_1, color_2, height, offset_1, offset_2)
    local fill_pattern = cairo.Pattern.create_linear(0, 0, 0, height)
    local r, g, b, a
    r, g, b, a = hex2rgb(color_1)
    fill_pattern:add_color_stop_rgba(offset_1 or 0, r, g, b, a)
    r, g, b, a = hex2rgb(color_2)
    fill_pattern:add_color_stop_rgba(offset_2 or 1, r, g, b, a)
    return fill_pattern
end

-- Returns a horizontal gradient pattern going from cololr_1 -> color_2
local function duotone_gradient_horizontal(color_1, color_2, width, offset_1, offset_2)
    local fill_pattern = cairo.Pattern.create_linear(0, 0, width, 0)
    local r, g, b, a
    r, g, b, a = hex2rgb(color_1)
    fill_pattern:add_color_stop_rgba(offset_1 or 0, r, g, b, a)
    r, g, b, a = hex2rgb(color_2)
    fill_pattern:add_color_stop_rgba(offset_2 or 1, r, g, b, a)
    return fill_pattern
end

return {
    circle_filled = circle_filled,
    duotone_gradient_vertical = duotone_gradient_vertical,
    duotone_gradient_horizontal = duotone_gradient_horizontal,
}
