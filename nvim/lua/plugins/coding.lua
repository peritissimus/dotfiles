return {
	{
		"akinsho/flutter-tools.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			require("flutter-tools").setup({})
		end,
	},
	{
		"brenoprata10/nvim-highlight-colors",
		config = function()
			require("nvim-highlight-colors").setup({
				enable_tailwind = false,
			})
		end,
	},
}
