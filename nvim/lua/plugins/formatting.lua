return {
	{
		"stevearc/conform.nvim",
		dependencies = { "mason.nvim" },
		lazy = true,
		cmd = "ConformInfo",
		keys = {
			{
				"<leader>cF",
				function()
					require("conform").format({ formatters = { "prettier", "prettierd" } })
				end,
				mode = { "n", "v" },
				desc = "Format Injected Langs",
			},
		},
	},
}
