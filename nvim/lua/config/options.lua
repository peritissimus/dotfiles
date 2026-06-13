vim.g.mapleader = " "
vim.g.maplocalleader = ","
vim.g.tmux_navigator_save_on_switch = 2
vim.g.tmux_navigator_disable_when_zoomed = 1

vim.opt.number = true
vim.opt.title = true
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.hlsearch = true
vim.opt.backup = false
vim.opt.showcmd = true
vim.opt.laststatus = 2
vim.opt.expandtab = true
vim.opt.scrolloff = 10
vim.opt.backupskip = { "/tmp/*", "/private/tmp/*" }
vim.opt.inccommand = "split"
vim.opt.ignorecase = true
vim.opt.smarttab = true
vim.opt.breakindent = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.wrap = false
vim.opt.backspace = { "start", "eol", "indent" }
vim.opt.wildignore:append({ "*/node_modules/*", "*/.git/*", "*/dist/*", "*/build/*" })
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.splitkeep = "cursor"
vim.opt.mouse = ""
vim.opt.spelllang = "en_us"
vim.opt.foldmethod = "marker"
vim.opt.cmdheight = 0
vim.opt.formatoptions:append({ "r" })

vim.g.snacks_animate = false

-- Undercurl in terminals that support it
vim.cmd([[let &t_Cs = "\e[4:3m"]])
vim.cmd([[let &t_Ce = "\e[4:0m"]])

vim.filetype.add({
	extension = { astro = "astro" },
	filename = { Podfile = "ruby" },
})
