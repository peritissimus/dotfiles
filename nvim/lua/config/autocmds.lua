-- Turn off paste mode when leaving insert
vim.api.nvim_create_autocmd("InsertLeave", {
	pattern = "*",
	command = "set nopaste",
})

-- Disable the concealing in some file formats
-- The default conceallevel is 3 in LazyVim
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "json", "jsonc", "markdown" },
	callback = function()
		vim.opt.conceallevel = 0
	end,
})
-- Add the file types you want line wrapping for
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "text", "markdown", "norg" },
    callback = function()
        vim.opt.wrap = true
    end,
})


