-- import lualine plugin safely
local status, lualine = pcall(require, "lualine")
if not status then
  return
end

-- get lualine nightfly theme
local lualine_gruvbox = require("lualine.themes.gruvbox")

-- new colors for theme
local new_colors = {
  blue = "#83a598",
  green = "#b8bb26",
  violet = "#d3869b",
  yellow = "#fabd2f",
  black = "#000000",
}

-- change nightlfy theme colors
lualine_gruvbox.normal.a.bg = new_colors.blue
lualine_gruvbox.insert.a.bg = new_colors.green
lualine_gruvbox.visual.a.bg = new_colors.violet
lualine_gruvbox.command = {
  a = {
    gui = "bold",
    bg = new_colors.yellow,
    fg = new_colors.black, -- black
  },
}

-- configure lualine with modified theme
lualine.setup({
  options = {
    theme = lualine_gruvbox,
  },
})

