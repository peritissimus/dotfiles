local status, _ = pcall(vim.cmd, "colorscheme gruvbox")
if not status then
  print("ColorScheme not Found")
  return
end

