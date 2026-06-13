return {
  -- tools
  {
    "mason-org/mason.nvim",
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
        "rust-analyzer",
      })
    end,
  },

  {
    "pmizio/typescript-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    ft = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    opts = {
      settings = {
        tsserver_max_memory = "auto",
        separate_diagnostic_server = true,
        publish_diagnostic_on = "insert_leave",
        expose_as_code_action = "all",
        filter_out_diagnostics_by_code = { 80001 },
      },
      on_attach = function(_, bufnr)
        local function buf_set_keymap(...)
          vim.api.nvim_buf_set_keymap(bufnr, ...)
        end
        local opts = { noremap = true, silent = true }

        -- Go to Source Definition
        buf_set_keymap("n", "gD", "<cmd>TSToolsGoToSourceDefinition<CR>", opts)

        -- Find All File References
        buf_set_keymap("n", "gR", "<cmd>TSToolsFileReferences<CR>", opts)

        -- Organize Imports
        buf_set_keymap("n", "<leader>co", "<cmd>TSToolsOrganizeImports<CR>", opts)

        -- Add Missing Imports
        buf_set_keymap("n", "<leader>cM", "<cmd>TSToolsAddMissingImports<CR>", opts)

        -- Remove Unused Imports
        buf_set_keymap("n", "<leader>cu", "<cmd>TSToolsRemoveUnusedImports<CR>", opts)

        -- Fix All Diagnostics
        buf_set_keymap("n", "<leader>cD", "<cmd>TSToolsFixAll<CR>", opts)
      end,
    },
  },

  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local root_pattern = require("lspconfig").util.root_pattern

      opts.inlay_hints = { enabled = false }
      opts.diagnostics = vim.tbl_deep_extend("force", opts.diagnostics or {}, {
        underline = true,
        update_in_insert = false,
        virtual_text = {
          spacing = 2,
          source = "if_many",
          prefix = "●",
        },
        severity_sort = true,
      })

      opts.servers = vim.tbl_deep_extend("force", opts.servers or {}, {
        terraformls = {},
        vtsls = { enabled = false },
        ruff_lsp = {
          root_dir = root_pattern("nx.json", ".git"),
        },
        pyright = {
          root_dir = root_pattern("nx.json", ".git"),
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
          root_dir = root_pattern("nx.json", ".git"),
          settings = {
            Lua = {
              workspace = { checkThirdParty = false },
              completion = { callSnippet = "Replace" },
              diagnostics = { globals = { "vim" } },
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
          root_dir = root_pattern("nx.json", "package.json"),
          settings = {
            workingDirectory = { mode = "auto" },
          },
        },
        basedpyright = { enabled = false },
        cssls = { enabled = false },
        tailwindcss = { enabled = false },
      })

      opts.setup = vim.tbl_deep_extend("force", opts.setup or {}, {
        eslint = function()
          Snacks.util.lsp.on({ name = "eslint" }, function(_, client)
            client.server_capabilities.documentFormattingProvider = true
          end)
          Snacks.util.lsp.on({ name = "tsserver" }, function(_, client)
            client.server_capabilities.documentFormattingProvider = false
          end)
        end,
      })
    end,
  },
}
