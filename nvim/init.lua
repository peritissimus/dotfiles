require('peritissimus.base')
require('peritissimus.highlights')
require('peritissimus.maps')
require('peritissimus.plugins')

local has = vim.fn.has
local is_mac = has "macunix"
local is_win = has "win32"
local is_wsl = has "wsl"

if is_mac == 1 then
  require('peritissimus.macos')
end
if is_win == 1 then
  require('peritissimus.windows')
end
if is_wsl == 1 then
  require('peritissimus.wsl')
end

local status, _ = pcall(require, "gruvbox-material")
if (not status) then return end
