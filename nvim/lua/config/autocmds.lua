-- Turn off paste mode when leaving insert
vim.api.nvim_create_autocmd("InsertLeave", {
	pattern = "*",
	command = "set nopaste",
})

-- Disable concealing for these file formats (LazyVim defaults to 3 for markdown)
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "json", "jsonc", "markdown" },
	callback = function()
		vim.opt_local.conceallevel = 0
	end,
})

-- Line wrap and spell check for prose filetypes
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "text", "markdown", "norg", "gitcommit" },
	callback = function()
		vim.opt_local.wrap = true
		vim.opt_local.spell = true
	end,
})
