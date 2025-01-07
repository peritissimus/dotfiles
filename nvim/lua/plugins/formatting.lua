return {

	{
		"stevearc/conform.nvim",
		event = { "BufWritePre" },
		cmd = { "ConformInfo" },
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
		opts = {
			formatters_by_ft = {
				javascript = { { "prettierd", "prettier" } },
				typescript = { { "prettierd", "prettier" } },
				javascriptreact = { { "prettierd", "prettier" } },
				typescriptreact = { { "prettierd", "prettier" } },
				python = { "isort", "black" },
			},
			-- Format on save
			format_on_save = {
				timeout_ms = 500,
				lsp_fallback = true,
			},
			formatters = {
				prettier = {
					-- Look for prettier config files in the project
					require_cwd = true,
					try_node_modules = true,
					-- Only run if we find prettier config
					condition = function(ctx)
						local found = false
						local config_files = {
							".prettierrc",
							".prettierrc.json",
							".prettierrc.yml",
							".prettierrc.yaml",
							".prettierrc.json5",
							".prettierrc.js",
							".prettierrc.cjs",
							"prettier.config.js",
							"prettier.config.cjs",
						}

						for _, config_file in ipairs(config_files) do
							if vim.fn.findfile(config_file, ".;") ~= "" then
								found = true
								break
							end
						end

						-- If no config found, use these defaults
						if not found then
							return {
								args = {
									"--single-quote",
									"--jsx-single-quote",
									"--trailing-comma",
									"es5",
									"--arrow-parens",
									"avoid",
								},
							}
						end
						return true
					end,
				},
				black = {
					prepend_args = { "--line-length", "88", "--quiet" },
				},
				isort = {
					prepend_args = { "--profile", "black" },
				},
			},
		},
	},
}
