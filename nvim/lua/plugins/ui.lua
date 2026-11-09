-- snacks' git_log finder always runs an extra `git log --follow --name-status`
-- rename-detection pass before the real log whenever it targets a file, and
-- that `--follow` is hardcoded (the source's own `follow = false` doesn't skip
-- it). On a 44k-commit repo that pass alone blocks the picker for ~5s. These
-- finders do the plain log only: no history across renames, but instant.
local function git_log_finder(extra_args)
	return function(_, ctx)
		local git = require("snacks.picker.source.git")
		local Proc = require("snacks.picker.source.proc")
		local file = vim.fs.normalize(vim.api.nvim_buf_get_name(ctx.filter.current_buf))
		local dir = vim.fs.dirname(file)
		local cwd = Snacks.git.get_root(dir) or dir
		local args = git.git(
			"log",
			"--pretty=format:%h %s (%ch) <%an>",
			"--abbrev-commit",
			"--decorate",
			"--date=short",
			"--color=never",
			"--no-show-signature",
			"--no-patch"
		)
		vim.list_extend(args, extra_args(file, ctx))
		return Proc.proc(
			ctx:opts({
				cwd = cwd,
				cmd = "git",
				args = args,
				transform = function(item)
					local commit, msg, date, author = item.text:match("^(%S+) (.*) %((.*)%) <(.*)>$")
					if not commit then
						return false
					end
					item.cwd = cwd
					item.commit = commit
					item.msg = msg
					item.date = date
					item.author = author
					item.file = file
				end,
			}),
			ctx
		)
	end
end

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
			picker = {
				sources = {
					-- <leader>gf -- Git Current File History
					git_log_file = {
						finder = git_log_finder(function(file)
							return { "--", file }
						end),
					},
					-- <leader>gb -- Git Blame Line
					git_log_line = {
						finder = git_log_finder(function(file, ctx)
							local line = vim.api.nvim_win_get_cursor(ctx.filter.current_win)[1]
							return { "-L", line .. ",+1:" .. file }
						end),
					},
				},
			},
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
