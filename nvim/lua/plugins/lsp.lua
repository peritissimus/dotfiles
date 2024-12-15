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
				vtsls = {
					-- explicitly add default filetypes, so that we can extend
					-- them in related extras
					filetypes = {
						"javascript",
						"javascriptreact",
						"javascript.jsx",
						"typescript",
						"typescriptreact",
						"typescript.tsx",
					},
					settings = {
						complete_function_calls = true,
						vtsls = {
							enableMoveToFileCodeAction = true,
							autoUseWorkspaceTsdk = true,
							experimental = {
								maxInlayHintLength = 30,
								completion = {
									enableServerSideFuzzyMatch = true,
								},
							},
						},
						typescript = {
							updateImportsOnFileMove = { enabled = "always" },
							suggest = {
								completeFunctionCalls = true,
							},
							inlayHints = {
								enumMemberValues = { enabled = true },
								functionLikeReturnTypes = { enabled = true },
								parameterNames = { enabled = "literals" },
								parameterTypes = { enabled = true },
								propertyDeclarationTypes = { enabled = true },
								variableTypes = { enabled = false },
							},
						},
					},
					keys = {
						{
							"gD",
							function()
								local params = vim.lsp.util.make_position_params()
								LazyVim.lsp.execute({
									command = "typescript.goToSourceDefinition",
									arguments = { params.textDocument.uri, params.position },
									open = true,
								})
							end,
							desc = "Goto Source Definition",
						},
						{
							"gR",
							function()
								LazyVim.lsp.execute({
									command = "typescript.findAllFileReferences",
									arguments = { vim.uri_from_bufnr(0) },
									open = true,
								})
							end,
							desc = "File References",
						},
						{
							"<leader>co",
							LazyVim.lsp.action["source.organizeImports"],
							desc = "Organize Imports",
						},
						{
							"<leader>cM",
							LazyVim.lsp.action["source.addMissingImports.ts"],
							desc = "Add missing imports",
						},
						{
							"<leader>cu",
							LazyVim.lsp.action["source.removeUnused.ts"],
							desc = "Remove unused imports",
						},
						{
							"<leader>cD",
							LazyVim.lsp.action["source.fixAll.ts"],
							desc = "Fix all diagnostics",
						},
						{
							"<leader>cV",
							function()
								LazyVim.lsp.execute({ command = "typescript.selectTypeScriptVersion" })
							end,
							desc = "Select TS workspace version",
						},
					},
				},
				ruff_lsp = {
					enabled = true,
					settings = {},
				},
				basedpyright = {
					enabled = false,
					settings = {},
				},
				pyright = {
					enabled = true,
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
				eslint = {
					settings = {
						workingDirectory = { mode = "auto" },
					},
				},
			},

			setup = {
				vtsls = function(_, opts)
					LazyVim.lsp.on_attach(function(client, buffer)
						client.commands["_typescript.moveToFileRefactoring"] = function(command, ctx)
							---@type string, string, lsp.Range
							local action, uri, range = unpack(command.arguments)

							local function move(newf)
								client.request("workspace/executeCommand", {
									command = command.command,
									arguments = { action, uri, range, newf },
								})
							end

							local fname = vim.uri_to_fname(uri)
							client.request("workspace/executeCommand", {
								command = "typescript.tsserverRequest",
								arguments = {
									"getMoveToRefactoringFileSuggestions",
									{
										file = fname,
										startLine = range.start.line + 1,
										startOffset = range.start.character + 1,
										endLine = range["end"].line + 1,
										endOffset = range["end"].character + 1,
									},
								},
							}, function(_, result)
								---@type string[]
								local files = result.body.files
								table.insert(files, 1, "Enter new path...")
								vim.ui.select(files, {
									prompt = "Select move destination:",
									format_item = function(f)
										return vim.fn.fnamemodify(f, ":~:.")
									end,
								}, function(f)
									if f and f:find("^Enter new path") then
										vim.ui.input({
											prompt = "Enter move destination:",
											default = vim.fn.fnamemodify(fname, ":h") .. "/",
											completion = "file",
										}, function(newf)
											return newf and move(newf)
										end)
									elseif f then
										move(f)
									end
								end)
							end)
						end
					end, "vtsls")
					-- copy typescript settings to javascript
					opts.settings.javascript =
						vim.tbl_deep_extend("force", {}, opts.settings.typescript, opts.settings.javascript or {})
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
