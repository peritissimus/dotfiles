return {
	{
		"brenoprata10/nvim-highlight-colors",
		event = "VeryLazy",
		opts = {
			enable_tailwind = false,
		},
	},
	{
		"Equilibris/nx.nvim",
		dependencies = {
			"nvim-telescope/telescope.nvim",
		},
		cmd = { "Nx", "NxActions" },
		opts = {
			nx_cmd_root = "npx nx",
		},
		keys = {
			{ "<leader>nx", "<cmd>Telescope nx actions<CR>", desc = "nx actions" },
		},
	},
}
