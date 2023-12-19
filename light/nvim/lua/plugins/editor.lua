return {
  {
    enabled=true,
    "nvim-neorg/neorg",
    dependencies = {"nvim-lua/plenary.nvim"},
    build = ":Neorg sync-parsers",
    opts = {
      load = {
        ["core.defaults"] = {},
        ["core.keybinds"] = {},
        ["core.itero"] = {},
        ["core.summary"] = {},
        ["core.export.markdown"] = {
          config = {
            extension = "md",
          }
        },
        ["core.journal"] = {
          config = {
            strategy = "nested",
          }
        },
        ["core.concealer"] = {},
        ["core.dirman"] = {
          config = {
            workspaces = {
              noteBook= "~/NoteBook/",
              work= "~/work"
            },
            default_workspace = "noteBook"
          },
        },
      },
    },
  },
}
