---@diagnostic disable: undefined-doc-name, undefined-field
--[[
███╗   ██╗██╗ ██████╗███████╗
████╗  ██║██║██╔════╝██╔════╝
██╔██╗ ██║██║██║     █████╗
██║╚██╗██║██║██║     ██╔══╝
██║ ╚████║██║╚██████╗███████╗
╚═╝  ╚═══╝╚═╝ ╚═════╝╚══════╝
Author: mu-tex
Co-Author: Crylia
License: MIT
Repository: https://github.com/crylia/awesome-wm-nice
Original Repository: https://github.com/mut-ex/awesome-wm-nice
]]
-- Awesome libs
local abutton = require("awful.button")
local atitlebar = require("awful.titlebar")
local atooltip = require("awful.tooltip")
local gdk = require("lgi").Gdk
local gsurface = require("gears.surface")
local gtimer = require("gears.timer")
local wibox = require("wibox")
local dpi = require("beautiful").xresources.apply_dpi

-- Local libs
local colors = require("src.lib.nice.colors")
local shapes = require("src.lib.nice.shapes")

gdk.init({})

local titlebar = {}

local _private = {}

_private.close_color = Theme_config.titlebar.close
_private.minimize_color = Theme_config.titlebar.minimize
_private.maximize_color = Theme_config.titlebar.maximize
_private.floating_color = Theme_config.titlebar.floating
_private.ontop_color = Theme_config.titlebar.ontop
_private.sticky_color = Theme_config.titlebar.sticky

local titlebar_position = User_config.titlebar_position

local ntable = require("src.lib.nice.table")

local gfilesystem = require("gears.filesystem")
local color_rules_filepath = gfilesystem.get_configuration_dir() .. "/src/config/" .. "color_rules"
_private.color_rules = ntable.load(color_rules_filepath) or {}

local function set_color_rule(c, color)
  if not c.instance then return end
  _private.color_rules[c.instance .. titlebar_position] = color
  ntable.save(_private.color_rules, color_rules_filepath)
end

local function get_color_rule(c) return _private.color_rules[c.instance .. titlebar_position] end

---Gets the dominant color of a client for the purpose of setting the titlebar color
---@param client any
---@return string hex color
local function get_dominant_color(client)
  local tally = {}
  local content = gsurface(client.content)
  local cgeo = client:geometry()
  local x_offset, y_offset = 2, 2
  local color

  if titlebar_position == "top" then
    for x_pos = 0, math.floor(cgeo.width / 2), 2 do
      for y_pos = 0, 8, 1 do
        color = "#" .. gdk.pixbuf_get_from_surface(content, x_offset + x_pos, y_offset + y_pos, 1, 1
        ):get_pixels():gsub(".", function(c)
          return ("%02x"):format(c:byte())
        end)
        if not tally[color] then
          tally[color] = 1
        else
          tally[color] = tally[color] + 1
        end
      end
    end
  elseif titlebar_position == "left" then
    x_offset = 0
    for y_pos = 0, math.floor(cgeo.height / 2), 2 do
      for x_pos = 0, 8, 1 do
        color = "#" .. gdk.pixbuf_get_from_surface(content, x_offset + x_pos, y_offset + y_pos, 1, 1
        ):get_pixels():gsub(".", function(c)
          return ("%02x"):format(c:byte())
        end)
        if not tally[color] then
          tally[color] = 1
        else
          tally[color] = tally[color] + 1
        end
      end
    end
  end

  local mode_c = 0
  for kolor, kount in pairs(tally) do
    if kount > mode_c then
      mode_c = kount
      color = kolor
    end
  end
  set_color_rule(client, color)
  return color
end

---Create a cairo surface for the titlebar buttons
---@param name any
---@param is_focused any
---@param event any
---@param is_on any
---@return unknown
local function create_button_image(name, is_focused, event, is_on)
  local focus_state = is_focused and "focused" or "unfocused"
  local key_img
  if is_on ~= nil then
    local toggle_state = is_on and "on" or "off"
    key_img = ("%s_%s_%s_%s"):format(name, toggle_state, focus_state, event)
  else
    key_img = ("%s_%s_%s"):format(name, focus_state, event)
  end
  if _private[key_img] then return _private[key_img] end
  local key_color = key_img .. "_color"
  if not _private[key_color] then
    local key_base_color = name .. "_color"
    local base_color = _private[key_base_color] or colors.rotate_hue(colors.rand_hex(), 33)
    _private[key_base_color] = base_color
    local button_color = base_color
    local H = colors.hex2hsv(base_color)
    if not is_focused and event ~= "hover" then
      button_color = colors.hsv2hex(H, 0, 50)
    end
    button_color = (event == "hover") and colors.lighten(button_color, 25) or
        (event == "press") and colors.darken(button_color, 25) or button_color
    _private[key_color] = button_color
  end
  local button_size = Theme_config.titlebar.button_size
  _private[key_img] = shapes.circle_filled(_private[key_color], button_size)
  return _private[key_img]
end

---Returns a button widget for the titlebar
---@param c client
---@param name string Name for the tooltip and the correct button image
---@param button_callback function callback function called when the button is pressed
---@param property string|nil client state, e.g. active or inactive
---@return wibox.widget button widget
local function create_titlebar_button(c, name, button_callback, property)
  local button_img = wibox.widget.imagebox(nil, false)
  local tooltip = atooltip {
    text = name,
    delay_show = 0.5,
    margins_leftright = 12,
    margins_topbottom = 6,
    timeout = 0.25,
    align = "bottom_right",
  }
  tooltip:add_to_object(button_img)
  local is_on, is_focused
  local event = "normal"
  local function update()
    is_focused = c.active
    -- If the button is for a property that can be toggled
    if property then
      is_on = c[property]
      button_img.image = create_button_image(name, is_focused, event, is_on)
    else
      button_img.image = create_button_image(name, is_focused, event)
    end
  end

  c:connect_signal("unfocus", update)
  c:connect_signal("focus", update)
  if property then c:connect_signal("property::" .. property, update) end
  button_img:connect_signal("mouse::enter", function()
    event = "hover"
    update()
  end)
  button_img:connect_signal("mouse::leave", function()
    event = "normal"
    update()
  end)

  button_img.buttons = abutton({}, 1, function()
    event = "press"
    update()
  end, function()
    if button_callback then
      event = "normal"
      button_callback()
    else
      event = "hover"
    end
    update()
  end)

  button_img.id = "button_image"
  update()
  return wibox.widget {
    {
      {
        button_img,
        widget = wibox.container.constraint,
        height = Theme_config.titlebar.button_size,
        width = Theme_config.titlebar.button_size,
        strategy = "exact",
      },
      widget = wibox.container.margin,
      margins = dpi(5),
    },
    widget = wibox.container.place,
  }
end

---Get the mouse bindings for the titlebar
---@param c client
---@return table all mouse bindings for the titlebar
local function get_titlebar_mouse_bindings(c)
  local clicks = 0
  local tolerance = 4
  local buttons = { abutton({}, 1, function()
    local cx, cy = _G.mouse.coords().x, _G.mouse.coords().y
    local delta = 250 / 1000
    clicks = clicks + 1
    if clicks == 2 then
      local nx, ny = _G.mouse.coords().x, _G.mouse.coords().y
      if math.abs(cx - nx) <= tolerance and math.abs(cy - ny) <= tolerance then
        c.maximized = not c.maximized
      end
    else
      c:activate { context = "titlebar", action = "mouse_move" }
    end
    -- Start a timer to clear the click count
    gtimer.weak_start_new(delta, function() clicks = 0 end)
  end), abutton({}, 2, function()
    c._nice_base_color = get_dominant_color(c)
    set_color_rule(c, c._nice_base_color)
    _private.add_titlebar(c)
  end), abutton({}, 3, function()
    c:activate { context = "mouse_click", action = "mouse_resize" }
  end), }
  return buttons
end

---Creates a title widget for the titlebar
---@param c client
---@return wibox.widget The title widget
local function create_titlebar_title(c)
  local title_widget = wibox.widget {
    halign = "center",
    ellipsize = "middle",
    opacity = c.active and 1 or 0.7,
    valign = "center",
    widget = wibox.widget.textbox,
  }

  local function update()
    title_widget.markup = ("<span foreground='%s'>%s</span>"):format(colors.is_contrast_acceptable("#fefefa",
      c._nice_base_color) and "#fefefa" or
      "#242424", c.name)
  end

  c:connect_signal("property::name", update)
  c:connect_signal("unfocus", function()
    title_widget.opacity = 0.7
  end)
  c:connect_signal("focus", function() title_widget.opacity = 1 end)
  update()
  return {
    title_widget,
    widget = wibox.container.margin,
    margins = Theme_config.titlebar.title_margin,
  }
end

---Creates the widget for a titlebar item
---@param c client
---@param name string The name of the item
---@return wibox.widget|nil widget The titlebar item widget
local function get_titlebar_item(c, name)
  if titlebar_position == "top" then
    if name == "close" then return create_titlebar_button(c, name, function() c:kill() end)
    elseif name == "maximize" then
      return create_titlebar_button(c, name, function() c.maximized = not c.maximized end, "maximized")
    elseif name == "minimize" then
      return create_titlebar_button(c, name, function() c.minimized = true end)
    elseif name == "ontop" then
      return create_titlebar_button(c, name, function() c.ontop = not c.ontop end, "ontop")
    elseif name == "floating" then
      return create_titlebar_button(c, name, function()
        c.floating = not c.floating
        if c.floating then
          c.maximized = false
        end
      end, "floating")
    elseif name == "sticky" then
      return create_titlebar_button(c, name, function()
        c.sticky = not c.sticky
        return c.sticky
      end, "sticky")
    elseif name == "title" then
      return create_titlebar_title(c)
    elseif name == "icon" then
      return wibox.widget {
        atitlebar.widget.iconwidget(c),
        widget = wibox.container.margin,
        margins = dpi(10)
      }
    end
  elseif titlebar_position == "left" then
    if name == "close" then
      return create_titlebar_button(c, name, function() c:kill() end)
    elseif name == "maximize" then
      return create_titlebar_button(c, name, function() c.maximized = not c.maximized end, "maximized")
    elseif name == "minimize" then
      return create_titlebar_button(c, name, function() c.minimized = true end)
    elseif name == "ontop" then
      return create_titlebar_button(c, name, function() c.ontop = not c.ontop end, "ontop")
    elseif name == "floating" then
      return create_titlebar_button(c, name, function()
        c.floating = not c.floating
        if c.floating then
          c.maximized = false
        end
      end, "floating")
    elseif name == "sticky" then
      return create_titlebar_button(c, name, function()
        c.sticky = not c.sticky
        return c.sticky
      end, "sticky")
    elseif name == "icon" then
      return wibox.widget {
        atitlebar.widget.iconwidget(c),
        widget = wibox.container.margin,
        margins = dpi(10)
      }
    end
  end
end

---Groups together the titlebar items for left, center, right placement
---@param c client
---@param group table|string The name of the group or a table of item names
---@return wibox.widget|nil widget The titlebar item widget
local function create_titlebar_items(c, group)
  if not group then return nil end
  if type(group) == "string" then return create_titlebar_title(c) end
  local layout

  if titlebar_position == "left" then
    layout = wibox.widget {
      layout = wibox.layout.fixed.vertical,
    }
  elseif titlebar_position == "top" then
    layout = wibox.widget {
      layout = wibox.layout.fixed.horizontal,
    }
  end

  local item
  for _, name in ipairs(group) do
    item = get_titlebar_item(c, name)
    if item then layout:add(item) end
  end
  return layout
end

---Adds the titlebar to the left of a client
---@param c client
function _private.add_titlebar(c)
  if titlebar_position == "top" then
    atitlebar(c, {
      size = Theme_config.titlebar.size,
      bg = "transparent"
    }):setup {
      {
        {
          create_titlebar_items(c, User_config.titlebar_items.left_and_bottom),
          widget = wibox.container.margin,
          left = dpi(5),
        },
        {
          create_titlebar_items(c, User_config.titlebar_items.middle),
          buttons = get_titlebar_mouse_bindings(c),
          layout = wibox.layout.flex.horizontal,
        },
        {
          create_titlebar_items(c, User_config.titlebar_items.right_and_top),
          widget = wibox.container.margin,
          right = dpi(5),
        },
        layout = wibox.layout.align.horizontal,
      },
      widget = wibox.container.background,
      bg = shapes.duotone_gradient_vertical(
        colors.lighten(c._nice_base_color, 1),
        c._nice_base_color,
        Theme_config.titlebar.size,
        0,
        0.5
      ),
    }
  elseif titlebar_position == "left" then
    atitlebar(c, {
      size = Theme_config.titlebar.size,
      bg = "transparent",
      position = "left"
    }):setup {
      {
        {
          create_titlebar_items(c, User_config.titlebar_items.right_and_top),
          widget = wibox.container.margin,
          top = dpi(5),
        },
        {
          create_titlebar_items(c, User_config.titlebar_items.middle),
          buttons = get_titlebar_mouse_bindings(c),
          layout = wibox.layout.flex.vertical,
        },
        {
          create_titlebar_items(c, User_config.titlebar_items.left_and_bottom),
          widget = wibox.container.margin,
          left = dpi(5),
        },
        layout = wibox.layout.align.vertical,
      },
      widget = wibox.container.background,
      bg = shapes.duotone_gradient_horizontal(
        colors.lighten(c._nice_base_color, 1),
        c._nice_base_color,
        Theme_config.titlebar.size,
        0,
        0.5
      ),
    }
  end

  if not c.floating then
    atitlebar.hide(c, titlebar_position)
  end
  c:connect_signal("property::maximized", function()
    if c.maximized then
      atitlebar.hide(c, titlebar_position)
    else
      atitlebar.show(c, titlebar_position)
    end
  end)
  c:connect_signal("property::floating", function()
    if not c.floating then
      if not client or not client.focus then return end
      atitlebar.hide(c, titlebar_position)
    else
      atitlebar.show(c, titlebar_position)
    end
  end)
end

---Titlebar initialization.
function titlebar.new()
  _G.client.connect_signal("request::titlebars", function(c)
    c._cb_add_window_decorations = function()
      gtimer.weak_start_new(0.5, function()
        c._nice_base_color = get_dominant_color(c)
        print(get_dominant_color(c))
        _private.add_titlebar(c)
        c:disconnect_signal("request::activate", c._cb_add_window_decorations)
      end)
    end

    local base_color = get_color_rule(c)
    if base_color then
      c._nice_base_color = base_color
      _private.add_titlebar(c)
    else
      c._nice_base_color = Theme_config.titlebar.color
      _private.add_titlebar(c)
      c:connect_signal("request::activate", c._cb_add_window_decorations)
    end
  end)

  _G.client.connect_signal(
    "request::manage", function(c)
    if not c.floating then
      if not client or not client.focus then return end
      atitlebar.hide(c, titlebar_position)
    else
      atitlebar.show(c, titlebar_position)
    end
  end)
end

return setmetatable(titlebar, { __call = function() return titlebar.new() end })
