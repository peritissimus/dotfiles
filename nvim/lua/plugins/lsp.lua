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
    "pmizio/typescript-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    opts = {
      settings = {
        tsserver_max_memory = "8192MB",
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
        terraformls = {},
        bash_ls = {
          filetypes = { "sh", "zsh", "fish" }
        },
        vtsls = {
          enabled = false,
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
