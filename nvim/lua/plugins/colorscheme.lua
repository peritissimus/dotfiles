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
		"sainnhe/everforest",
		lazy = true,
		config = function()
			-- Configure everforest
			vim.g.everforest_style = "medium" -- Available: 'hard', 'medium', 'soft'
			vim.g.everforest_background = "medium" -- Available: 'hard', 'medium', 'soft'
			vim.g.everforest_transparent_background = 1
			vim.g.everforest_enable_italic = 1
			vim.g.everforest_better_performance = 1
			
			vim.cmd("colorscheme everforest")
		end,
	},
	{
		"rebelot/kanagawa.nvim",
		lazy = true,
		config = function()
			require("kanagawa").setup({
				theme = "dragon",
				transparent = true,
				background = {
					dark = "dragon",
					light = "lotus",
				},
			})
		end,
	},
	{
		"folke/tokyonight.nvim",
		lazy = false,
		priority = 1000,
		opts = {
			style = "night",
			transparent = true,
			styles = {
				sidebars = "transparent",
				floats = "transparent",
			},
		},
		config = function()
			require("tokyonight").setup({
				style = "night",
				transparent = true,
				styles = {
					sidebars = "transparent",
					floats = "transparent",
				},
			})
			vim.cmd("colorscheme tokyonight-night")
		end,
	},
}
