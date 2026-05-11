return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "cmake",
        "cpp",
        "css",
        "fish",
        "gitignore",
        "go",
        "graphql",
        "http",
        "rust",
        "scss",
        "sql",
        "svelte",
        "python",
        "typescript",
        "tsx",
        "lua",
        "terraform",
        "hcl",
        "astro",
        "swift",
        "glsl",
      },
    },
    init = function()
      vim.filetype.add({ extension = { astro = "astro" } })
      vim.filetype.add({ extension = { fs = "glsl", vs = "glsl" } })
      vim.treesitter.language.register("astro", "astro")
      vim.treesitter.language.register("glsl", "glsl")
    end,
  },
}
