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
		"folke/tokyonight.nvim",
		lazy = false,
		opts = {
			style = "moon",
			transparent = true,
			styles = {
				sibdebars = "transparent",
				floats = "transparent",
			},
		},
	},
}
