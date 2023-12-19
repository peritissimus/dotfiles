return {
	{
		"tjdevries/colorbuddy.vim",
	},
	{
		"peritissimus/gruvbox.vim",
		lazy = true,
		priority = 1000,
		opts = function()
			return {
				transparent = true,
			}
		end,
	},
}
