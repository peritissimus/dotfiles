return {
	-- messages, cmdline and the popupmenu
	{
		"folke/noice.nvim",
		opts = function(_, opts)
			table.insert(opts.routes, {
				filter = {
					event = "notify",
					find = "No information available",
				},
				opts = { skip = true },
			})
			local focused = true
			vim.api.nvim_create_autocmd("FocusGained", {
				callback = function()
					focused = true
				end,
			})
			vim.api.nvim_create_autocmd("FocusLost", {
				callback = function()
					focused = false
				end,
			})
			table.insert(opts.routes, 1, {
				filter = {
					cond = function()
						return not focused
					end,
				},
				view = "notify_send",
				opts = { stop = false },
			})

			opts.commands = {
				all = {
					-- options for the message history that you get with `:Noice`
					view = "split",
					opts = { enter = true, format = "details" },
					filter = {},
				},
			}

			vim.api.nvim_create_autocmd("FileType", {
				pattern = "markdown",
				callback = function(event)
					vim.schedule(function()
						require("noice.text.markdown").keys(event.buf)
					end)
				end,
			})

			opts.presets.lsp_doc_border = true
		end,
	},

	-- buffer line
	{
		"akinsho/bufferline.nvim",
		event = "VeryLazy",
		keys = {
			{ "<Tab>", "<Cmd>BufferLineCycleNext<CR>", desc = "Next tab" },
			{ "<S-Tab>", "<Cmd>BufferLineCyclePrev<CR>", desc = "Prev tab" },
		},
		opts = {
			options = {
				mode = "tabs",
				-- separator_style = "slant",
				show_buffer_close_icons = false,
				show_close_icon = false,
			},
		},
	},

	-- statusline
	{
		"nvim-lualine/lualine.nvim",
		event = "VeryLazy",
		opts = {
			options = {
				-- globalstatus = false,
				theme = "tokyonight",
			},
		},
	},

	{
		"folke/snacks.nvim",
		opts = {
			dashboard = {

				preset = {
					header = [[
██████╗ ███████╗██████╗ ██╗████████╗██╗███████╗███████╗██╗███╗   ███╗██╗   ██╗███████╗
██╔══██╗██╔════╝██╔══██╗██║╚══██╔══╝██║██╔════╝██╔════╝██║████╗ ████║██║   ██║██╔════╝
██████╔╝█████╗  ██████╔╝██║   ██║   ██║███████╗███████╗██║██╔████╔██║██║   ██║███████╗
██╔═══╝ ██╔══╝  ██╔══██╗██║   ██║   ██║╚════██║╚════██║██║██║╚██╔╝██║██║   ██║╚════██║
██║     ███████╗██║  ██║██║   ██║   ██║███████║███████║██║██║ ╚═╝ ██║╚██████╔╝███████║
╚═╝     ╚══════╝╚═╝  ╚═╝╚═╝   ╚═╝   ╚═╝╚══════╝╚══════╝╚═╝╚═╝     ╚═╝ ╚═════╝ ╚══════╝
 ]],
					---@type snacks.dashboard.Item[]
					keys = {
						{
							icon = " ",
							key = "f",
							desc = "Find File",
							action = ":lua Snacks.dashboard.pick('files')",
						},
						{ icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
						{
							icon = " ",
							key = "g",
							desc = "Find Text",
							action = ":lua Snacks.dashboard.pick('live_grep')",
						},
						{
							icon = " ",
							key = "r",
							desc = "Recent Files",
							action = ":lua Snacks.dashboard.pick('oldfiles')",
						},
						{
							icon = " ",
							key = "c",
							desc = "Config",
							action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})",
						},
						{ icon = " ", key = "s", desc = "Restore Session", section = "session" },
						{ icon = " ", key = "x", desc = "Lazy Extras", action = ":LazyExtras" },
						{ icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
						{ icon = " ", key = "q", desc = "Quit", action = ":qa" },
					},
					formats = {
						icon = function(item)
							if item.file and item.icon == "file" or item.icon == "directory" then
								return M.icon(item.file, item.icon)
							end
							return { item.icon, width = 2, hl = "icon" }
						end,
						footer = { "%s", align = "center" },
						header = { "%s", align = "center" },
						file = function(item, ctx)
							local fname = vim.fn.fnamemodify(item.file, ":~")
							fname = ctx.width and #fname > ctx.width and vim.fn.pathshorten(fname) or fname
							local dir, file = fname:match("^(.*)/(.+)$")
							return dir and { { dir .. "/", hl = "dir" }, { file, hl = "file" } }
								or { { fname, hl = "file" } }
						end,
					},
				},
			},
		},
	},
}
