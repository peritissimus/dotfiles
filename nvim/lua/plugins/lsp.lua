return {
	-- tools
	{
		"williamboman/mason.nvim",
		opts = function(_, opts)
			vim.list_extend(opts.ensure_installed, {
				"prettier",
				"prettierd",
				"stylua",
				"selene",
				"luacheck",
				"shellcheck",
				"shfmt",
				"sqlfluff",
				"tailwindcss-language-server",
				"typescript-language-server",
				"css-lsp",
				"ruff-lsp",
				"basedpyright",
			})
		end,
	},

	{
		"neovim/nvim-lspconfig",
		opts = {
			inlay_hints = { enabled = false },
			diagnostics = {
				underline = true,
				update_in_insert = false,
				virtual_text = {
					spacing = 2,
					source = "if_many",
					prefix = "●",
				},
				severity_sort = true,
			},
			servers = {
				vtsls = {
					filetypes = {
						"javascript",
						"javascriptreact",
						"typescript",
						"typescriptreact",
					},
					root_dir = require("lspconfig").util.root_pattern("nx.json", "package.json"),
					settings = {
						typescript = {
							maxTsServerMemory = 4096, -- Example setting to increase memory
						},
						javascript = {
							-- Merged settings as per setup function
						},
					},
					on_attach = function(client, buffer)
						-- Simplified on_attach if necessary
					end,
					-- Lazy loading flag (if supported by your plugin manager)
					lazy = true,
				},
				ruff_lsp = {
					enabled = true,
					settings = {},
					root_dir = require("lspconfig").util.root_pattern("nx.json", ".git"),
				},
				pyright = {
					enabled = true,
					root_dir = require("lspconfig").util.root_pattern("nx.json", ".git"),
					settings = {
						python = {
							analysis = {
								typeCheckingMode = "basic",
								autoSearchPaths = true,
								useLibraryCodeForTypes = true,
							},
						},
					},
				},
				lua_ls = {
					single_file_support = true,
					root_dir = require("lspconfig").util.root_pattern("nx.json", ".git"),
					settings = {
						Lua = {
							workspace = {
								checkThirdParty = false,
							},
							completion = {
								callSnippet = "Replace",
							},
							diagnostics = {
								globals = { "vim" },
							},
							hint = {
								enable = true,
								arrayIndex = "Enable",
								setType = true,
								paramName = "All",
								paramType = true,
								semicolon = "All",
							},
						},
					},
				},
				eslint = {
					root_dir = require("lspconfig").util.root_pattern("nx.json", "package.json"),
					settings = {
						workingDirectory = { mode = "auto" },
					},
				},
				-- Disable unused servers
				basedpyright = { enabled = false },
				cssls = { enabled = false },
				tailwindcss = { enabled = false },
			},
			setup = {
				vtsls = function(_, opts)
					-- Ensure merged settings
					opts.settings.javascript =
						vim.tbl_deep_extend("force", {}, opts.settings.typescript, opts.settings.javascript or {})
					-- Optional: Further optimize or remove custom commands
				end,
				eslint = function()
					require("lazyvim.util").lsp.on_attach(function(client)
						if client.name == "eslint" then
							client.server_capabilities.documentFormattingProvider = true
						elseif client.name == "tsserver" then
							client.server_capabilities.documentFormattingProvider = false
						end
					end)
				end,
			},
		},
	},
}
