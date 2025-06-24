return {
	{
		"kristijanhusak/vim-dadbod-ui",
		dependencies = {
			{ "tpope/vim-dadbod", lazy = true },
			{ "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true }, -- Optional
		},
		cmd = {
			"DBUI",
			"DBUIToggle",
			"DBUIAddConnection",
			"DBUIFindBuffer",
		},
		init = function()
			vim.g.db_ui_use_nerd_fonts = 1
		end,
	},
	{
		"hat0uma/csvview.nvim",
		config = function()
			require("csvview").setup()
			-- Add a keymapping to toggle CSV view
			vim.keymap.set("n", "<leader>cv", function()
				require("csvview").toggle()
			end, { desc = "Toggle CSV View" })
		end,
	},
	-- Navigator.nvim for seamless navigation between nvim and terminal multiplexer
	{
		"numToStr/Navigator.nvim",
		lazy = false,
		config = function()
			require("Navigator").setup({
				-- Auto save modified files when moving to mux pane
				auto_save = "current",
				-- Disable navigation in these filetypes
				disable_on_zoom = true,
			})
		end,
		keys = {
			{ "<C-h>", "<CMD>NavigatorLeft<CR>", mode = { "n", "t" }, desc = "Navigator Left" },
			{ "<C-j>", "<CMD>NavigatorDown<CR>", mode = { "n", "t" }, desc = "Navigator Down" },
			{ "<C-k>", "<CMD>NavigatorUp<CR>", mode = { "n", "t" }, desc = "Navigator Up" },
			{ "<C-l>", "<CMD>NavigatorRight<CR>", mode = { "n", "t" }, desc = "Navigator Right" },
			{ "<C-\\>", "<CMD>NavigatorPrevious<CR>", mode = { "n", "t" }, desc = "Navigator Previous" },
		},
	},
}
