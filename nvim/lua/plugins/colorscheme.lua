return {
	-- {
	-- 	"tjdevries/colorbuddy.vim",
	-- },
	-- {
	-- 	"peritissimus/gruvbox.vim",
	-- 	lazy = true,
	-- 	priority = 1000,
	-- 	opts = function()
	-- 		return {
	-- 			transparent = true,
	-- 		}
	-- 	end,
	-- },
	{
		"rebelot/kanagawa.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			require("kanagawa").setup({
				theme = "dragon", -- Load the dragon variant
				transparent = true,
				background = {
					dark = "dragon",
					light = "lotus",
				},
			})
			vim.cmd("colorscheme kanagawa-dragon")
		end,
	},
	{
		"folke/tokyonight.nvim",
		lazy = true,
		opts = {
			style = "night",
			transparent = true,
			styles = {
				sibdebars = "transparent",
				floats = "transparent",
			},
		},
	},
}
