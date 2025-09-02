# Colorscheme Update Guide

This guide explains how to update the color scheme across your entire development environment for a cohesive visual experience.

## Components to Update

Your development setup consists of three main components that need color scheme updates:

1. **Neovim** - Text editor colors and themes
2. **Alacritty** - Terminal emulator colors
3. **Lualine** - Neovim statusline colors

## Current Setup (Kanagawa Dragon)

### File Locations

- **Neovim colorscheme**: `nvim/lua/plugins/colorscheme.lua`
- **Alacritty colors**: `alacritty/alacritty.toml`
- **Lualine theme**: `nvim/lua/plugins/ui.lua`
- **LazyVim config**: `nvim/lua/config/lazy.lua`

## Step-by-Step Update Process

### 1. Neovim Colorscheme

#### Add New Theme Plugin
Edit `nvim/lua/plugins/colorscheme.lua`:

```lua
return {
	{
		"author/colorscheme-name",  -- Replace with actual plugin
		lazy = false,
		priority = 1000,
		config = function()
			require("colorscheme-name").setup({
				-- Theme-specific options
				transparent = true,  -- Keep transparency
			})
			vim.cmd("colorscheme theme-name")
		end,
	},
	-- Keep old themes as fallbacks with lazy = true
}
```

#### Remove LazyVim Default (if needed)
Edit `nvim/lua/config/lazy.lua` and remove/comment:
```lua
opts = {
	-- colorscheme = "old-theme",  -- Remove this line
}
```

### 2. Alacritty Terminal Colors

Edit `alacritty/alacritty.toml` in the colors section:

```toml
# [Theme Name] theme colors
[colors.primary]
background = '#background-hex'
foreground = '#foreground-hex'

[colors.normal]
black = '#black-hex'
red = '#red-hex'
green = '#green-hex'
yellow = '#yellow-hex'
blue = '#blue-hex'
magenta = '#magenta-hex'
cyan = '#cyan-hex'
white = '#white-hex'

[colors.bright]
black = '#bright-black-hex'
red = '#bright-red-hex'
green = '#bright-green-hex'
yellow = '#bright-yellow-hex'
blue = '#bright-blue-hex'
magenta = '#bright-magenta-hex'
cyan = '#bright-cyan-hex'
white = '#bright-white-hex'

[colors.selection]
background = '#selection-bg-hex'
text = '#selection-text-hex'
```

### 3. Lualine Statusline

Edit `nvim/lua/plugins/ui.lua`:

```lua
{
	"nvim-lualine/lualine.nvim",
	event = "VeryLazy",
	opts = {
		options = {
			theme = "theme-name",  -- Update this line
		},
	},
},
```

## Popular Color Schemes

### Blue-Green Themes
- **kanagawa-dragon**: Deep ocean waves with jade accents
- **everforest**: Forest-inspired green-blue palette
- **nightfox (terafox)**: Earthy blue-green balance

### Modern Minimal
- **catppuccin**: Soft pastels (mocha, frappe, macchiato, latte)
- **rose-pine**: Muted soho vibes (main, moon, dawn)
- **nordic**: Clean arctic palette

### Classic
- **tokyonight**: Neon city lights (night, storm, moon)
- **gruvbox**: Retro warm colors
- **dracula**: Purple vampire aesthetic

## Color Extraction for Alacritty

When adapting a Neovim theme to Alacritty, you can usually find colors in:

1. **Theme documentation** - Most themes provide terminal colors
2. **Theme source code** - Look for color definitions
3. **Online resources** - Many have Alacritty configs available
4. **Terminal color extractors** - Tools that convert vim themes

### Example: Finding Theme Colors

For kanagawa-dragon theme:
```lua
-- In theme source, look for colors like:
local colors = {
  bg = '#181616',
  fg = '#c5c9c5',
  red = '#c4746e',
  green = '#8a9a7b',
  -- etc...
}
```

## Application Order

1. **Update Neovim first** - This lets you see the theme in action
2. **Update Alacritty** - Match terminal to editor
3. **Update Lualine** - Ensure statusline matches
4. **Restart applications** - See changes take effect

## Testing Changes

### Neovim
```vim
:Lazy sync        " Install new plugins
:colorscheme name " Test theme manually
```

### Alacritty
- Restart terminal or open new window
- Colors apply immediately

## Troubleshooting

### Theme Not Loading
- Check plugin name spelling
- Verify theme supports your variant (dark/light)
- Ensure `priority = 1000` for main theme

### Colors Look Wrong
- Verify terminal supports true color
- Check Alacritty color hex values
- Ensure theme transparency settings match

### Lualine Errors
- Some themes don't have lualine support
- Fall back to `"auto"` theme
- Check theme documentation for lualine compatibility

## Backup Strategy

Before major changes:
```bash
# Backup current configs
cp nvim/lua/plugins/colorscheme.lua nvim/lua/plugins/colorscheme.lua.bak
cp alacritty/alacritty.toml alacritty/alacritty.toml.bak
cp nvim/lua/plugins/ui.lua nvim/lua/plugins/ui.lua.bak
```

## Current Configuration Reference

### Kanagawa Dragon Colors
```
Background: #181616
Foreground: #c5c9c5
Red: #c4746e / #E46876
Green: #8a9a7b / #87a987
Blue: #8ba4b0 / #7fb4ca
Cyan: #8ea4a2 / #7aa89f
```

---

**Note**: Always restart Neovim and Alacritty after making changes to see the full effect of your new color scheme.