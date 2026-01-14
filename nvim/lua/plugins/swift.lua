return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local lspconfig = require("lspconfig")
      
      -- Swift-specific keymaps
      local on_attach = function(client, bufnr)
        local function buf_set_keymap(...)
          vim.api.nvim_buf_set_keymap(bufnr, ...)
        end
        local kopts = { noremap = true, silent = true }

        -- Swift-specific keybindings
        buf_set_keymap("n", "<leader>cb", "<cmd>!swift build<CR>", kopts) -- Build
        buf_set_keymap("n", "<leader>cr", "<cmd>!swift run<CR>", kopts) -- Run
        buf_set_keymap("n", "<leader>ct", "<cmd>!swift test<CR>", kopts) -- Test
        buf_set_keymap("n", "<leader>cp", "<cmd>!swift package<CR>", kopts) -- Package commands
      end

      -- Extend the sourcekit setup
      if opts.servers.sourcekit then
        opts.servers.sourcekit.on_attach = on_attach
      end

      return opts
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      -- Add Swift-specific text objects
      if type(opts.textobjects) == "table" then
        opts.textobjects.select = opts.textobjects.select or {}
        vim.list_extend(opts.textobjects.select, {
          ["af"] = "@function.outer",
          ["if"] = "@function.inner",
          ["ac"] = "@class.outer",
          ["ic"] = "@class.inner",
        })
      end
      return opts
    end,
  },
  -- Swift-specific formatting
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        swift = { "swiftformat" },
      },
    },
  },
}