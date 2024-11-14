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
				"tailwindcss-language-server",
				"typescript-language-server",
				"css-lsp",
				"pyright",
				"ruff-lsp",
			})
		end,
	},

	-- lsp servers
	{
		"neovim/nvim-lspconfig",
		opts = {
			inlay_hints = { enabled = false },
			diagnostics = {
				underline = true,
				update_in_insert = false,
				virtual_text = {
					spacing = 4,
					source = "if_many",
					prefix = "●",
				},
				severity_sort = true,
			},
			servers = {
				eslint = {
					settings = {
						-- helps eslint find the eslintrc when it's placed in a subfolder
						workingDirectory = { mode = "auto" },
					},
				},
				pyright = {
					enabled = true,
					settings = {
						python = {
							analysis = {
								autoImportCompletions = true,
								autoSearchPaths = true,
								diagnosticMode = "workspace",
								typeCheckingMode = "basic",
								useLibraryCodeForTypes = true,
							},
						},
					},
				},
				cssls = {
					settings = {
						css = { validate = true },
						scss = { validate = true },
						less = { validate = true },
					},
				},
				tailwindcss = {
					hovers = true,
					suggestions = true,
					root_dir = function(fname)
						local root_pattern = require("lspconfig").util.root_pattern(
							"tailwind.config.cjs",
							"tailwind.config.js",
							"postcss.config.js"
						)
						return root_pattern(fname)
					end,
				},
				tsserver = {
					root_dir = function(...)
						return require("lspconfig.util").root_pattern(".git")(...)
					end,
					single_file_support = false,
					settings = {
						typescript = {
							inlayHints = {
								includeInlayParameterNameHints = "all",
								includeInlayParameterNameHintsWhenArgumentMatchesName = false,
								includeInlayFunctionParameterTypeHints = true,
								includeInlayVariableTypeHints = true,
								includeInlayPropertyDeclarationTypeHints = true,
								includeInlayFunctionLikeReturnTypeHints = true,
								includeInlayEnumMemberValueHints = true,
							},
							suggest = {
								includeCompletionsForModuleExports = true,
								includeCompletionsWithObjectLiteralMethodSnippets = true,
								includeCompletionsWithClassMemberSnippets = true,
								includeCompletionsWithImportStatements = true,
							},
							implementationsCodeLens = true,
							referencesCodeLens = true,
							format = {
								indentSize = 2,
							},
						},
						javascript = {
							inlayHints = {
								includeInlayParameterNameHints = "all",
								includeInlayParameterNameHintsWhenArgumentMatchesName = false,
								includeInlayFunctionParameterTypeHints = true,
								includeInlayVariableTypeHints = true,
								includeInlayPropertyDeclarationTypeHints = true,
								includeInlayFunctionLikeReturnTypeHints = true,
								includeInlayEnumMemberValueHints = true,
							},
						},
					},
					commands = {
						OrganizeImports = {
							function()
								local params = {
									command = "_typescript.organizeImports",
									arguments = { vim.api.nvim_buf_get_name(0) },
									title = "",
								}
								vim.lsp.buf.execute_command(params)
							end,
							description = "Organize Imports",
						},
					},
				},
				lua_ls = {
					single_file_support = true,
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
				ruff_lsp = {
					keys = {
						{
							"<leader>co",
							function()
								vim.lsp.buf.code_action({
									apply = true,
									context = {
										only = { "source.organizeImports" },
										diagnostics = {},
									},
								})
							end,
							desc = "Organize Imports",
						},
					},
					settings = {
						organizeImports = true,
						fixAll = true,
					},
				},
			},
			setup = {
				eslint = function()
					require("lazyvim.util").lsp.on_attach(function(client)
						if client.name == "eslint" then
							client.server_capabilities.documentFormattingProvider = true
						elseif client.name == "tsserver" then
							client.server_capabilities.documentFormattingProvider = false
						end
					end)
				end,
				ruff_lsp = function()
					require("lazyvim.util").lsp.on_attach(function(client, _)
						if client.name == "ruff_lsp" then
							client.server_capabilities.hoverProvider = false
						end
					end)
				end,
			},
		},
	},
}
