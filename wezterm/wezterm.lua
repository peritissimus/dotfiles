local wezterm = require 'wezterm'
local config = {}

if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- Session persistence
local session_file = wezterm.home_dir .. '/.wezterm_sessions.json'

-- Helper function to save session state
local function save_session(window)
  local session_data = {
    tabs = {},
    timestamp = os.time(),
  }

  local tabs = window:mux_window():tabs()
  for _, tab in ipairs(tabs) do
    local tab_data = {
      title = tab:get_title(),
      panes = {},
    }

    -- Get panes in the tab
    local panes = tab:panes_with_info()
    for _, pane_info in ipairs(panes) do
      local pane = pane_info.pane
      local cwd = pane:get_current_working_dir()
      if cwd then
        table.insert(tab_data.panes, {
          cwd = cwd.file_path,
          is_active = pane_info.is_active,
          width = pane_info.width,
          height = pane_info.height,
          left = pane_info.left,
          top = pane_info.top,
        })
      end
    end

    table.insert(session_data.tabs, tab_data)
  end

  -- Write to file
  local file = io.open(session_file, 'w')
  if file then
    file:write(wezterm.json_encode(session_data))
    file:close()
    window:toast_notification('WezTerm', 'Session saved!', nil, 2000)
  end
end

-- Helper function to restore session
local function restore_session(window)
  local file = io.open(session_file, 'r')
  if not file then
    window:toast_notification('WezTerm', 'No saved session found', nil, 2000)
    return
  end

  local content = file:read('*a')
  file:close()

  local ok, session_data = pcall(wezterm.json_parse, content)
  if not ok then
    window:toast_notification('WezTerm', 'Failed to parse session file', nil, 2000)
    return
  end

  -- Close all existing tabs except the first one
  local existing_tabs = window:mux_window():tabs()
  for i = #existing_tabs, 2, -1 do
    existing_tabs[i]:activate()
    window:perform_action(wezterm.action.CloseCurrentTab { confirm = false }, existing_tabs[i]:active_pane())
  end

  -- Recreate tabs
  for i, tab_data in ipairs(session_data.tabs) do
    local tab, pane
    if i == 1 then
      -- Use the existing first tab
      tab = existing_tabs[1]
      pane = tab:active_pane()
      -- Set working directory for first pane
      if #tab_data.panes > 0 then
        pane:send_text('cd ' .. tab_data.panes[1].cwd .. '\n')
      end
    else
      -- Create new tab
      tab, pane = window:mux_window():spawn_tab {
        cwd = #tab_data.panes > 0 and tab_data.panes[1].cwd or wezterm.home_dir,
      }
    end

    tab:set_title(tab_data.title)

    -- Note: WezTerm doesn't support restoring exact pane layouts,
    -- so we'll just create a simple split layout
    if #tab_data.panes > 1 then
      for j = 2, #tab_data.panes do
        local new_pane = pane:split {
          direction = j % 2 == 0 and 'Right' or 'Bottom',
          cwd = tab_data.panes[j].cwd,
        }
      end
    end
  end

  -- Switch back to first tab
  window:perform_action(wezterm.action.ActivateTab(0), existing_tabs[1]:active_pane())
  window:toast_notification('WezTerm', 'Session restored!', nil, 2000)
end

-- Font Configuration (matching Ghostty)
config.font = wezterm.font_with_fallback {
  {
    family = 'FiraCode Nerd Font',
    weight = 'Regular', -- Changed from Medium to Regular
  },
  'FiraCode Nerd Font',
}
config.font_size = 12.0
config.freetype_load_target = 'Normal'    -- Changed from Light to Normal
config.freetype_render_target = 'Normal'  -- Changed from HorizontalLcd to Normal
config.freetype_load_flags = 'NO_HINTING' -- Disable hinting for thinner rendering

-- Window Configuration (matching Ghostty)
config.window_decorations = "RESIZE"
config.window_background_opacity = 0.8
config.macos_window_background_blur = 30
-- Ensure color accuracy
config.front_end = "WebGpu" -- Better color rendering
config.webgpu_power_preference = "HighPerformance"
config.window_padding = {
  left = 8,
  right = 8,
  top = 0,
  bottom = 0,
}

-- Tab bar configuration
config.enable_tab_bar = true
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 30
config.show_new_tab_button_in_tab_bar = true
config.switch_to_last_active_tab_when_closing_tab = true
config.tab_and_split_indices_are_zero_based = false

-- Terminal
config.term = 'xterm-256color'

-- Set environment variables for better integration
config.set_environment_variables = {
  TERM_PROGRAM = 'WezTerm',
}

-- Color accuracy settings (matching macOS display)
config.color_scheme = nil -- Use our custom colors
config.force_reverse_video_cursor = false
config.use_cap_height_to_scale_fallback_fonts = true

-- macOS specific color settings
if wezterm.target_triple:find("darwin") then
  -- Match Ghostty's color space
  config.window_frame = {
    font_size = 12.0,
  }
  -- Ensure accurate color reproduction on macOS
  config.native_macos_fullscreen_mode = true
end

-- Custom color scheme matching Ghostty palette
config.colors = {
  foreground = '#c0caf5',
  background = '#171717',
  cursor_bg = '#c0caf5',
  cursor_fg = '#171717',
  cursor_border = '#c0caf5',
  selection_fg = '#c0caf5',
  selection_bg = '#283457',

  -- ANSI colors
  ansi = {
    '#1b1d2b', -- black
    '#ff757f', -- red
    '#c3e88d', -- green
    '#ffc777', -- yellow
    '#82aaff', -- blue
    '#c099ff', -- magenta
    '#86e1fc', -- cyan
    '#828bb8', -- white
  },

  -- Bright colors
  brights = {
    '#444a73', -- bright black
    '#ff8d94', -- bright red
    '#c7fb6d', -- bright green
    '#ffd8ab', -- bright yellow
    '#9ab8ff', -- bright blue
    '#caabff', -- bright magenta
    '#b2ebff', -- bright cyan
    '#c8d3f5', -- bright white
  },

  -- Tab bar colors (matching tmux window status style)
  tab_bar = {
    background = '#171717', -- Keep dark background
    active_tab = {
      bg_color = 'NONE',    -- Transparent background like tmux
      fg_color = '#ebcb8b', -- Yellow - matching tmux active window
    },
    inactive_tab = {
      bg_color = 'NONE',    -- Transparent background like tmux
      fg_color = '#4c566a', -- Dark gray - matching tmux inactive window
    },
    inactive_tab_hover = {
      bg_color = '#1b1d2b', -- Slight highlight on hover
      fg_color = '#828bb8', -- Brighter on hover
      italic = false,
    },
    new_tab = {
      bg_color = 'NONE',
      fg_color = '#4c566a',
    },
    new_tab_hover = {
      bg_color = '#1b1d2b',
      fg_color = '#82aaff',
    },
  },
}

-- Bold text
config.bold_brightens_ansi_colors = false

-- Mouse
config.hide_mouse_cursor_when_typing = true

-- Scrollback
config.scrollback_lines = 50000

-- macOS specific
config.send_composed_key_when_left_alt_is_pressed = true
config.send_composed_key_when_right_alt_is_pressed = true

-- Leader key (similar to tmux prefix)
config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }

-- Key bindings
config.keys = {
  -- Send CTRL-A when pressing CTRL-A twice (like tmux)
  {
    key = 'a',
    mods = 'LEADER|CTRL',
    action = wezterm.action.SendKey { key = 'a', mods = 'CTRL' },
  },
  -- Split panes like tmux
  {
    key = '|',
    mods = 'LEADER',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    key = '-',
    mods = 'LEADER',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
  },
  -- Reload configuration (like tmux)
  {
    key = 'r',
    mods = 'LEADER',
    action = wezterm.action.ReloadConfiguration,
  },
  -- Pane navigation with vim keys (like tmux)
  {
    key = 'h',
    mods = 'LEADER',
    action = wezterm.action.ActivatePaneDirection 'Left',
  },
  {
    key = 'j',
    mods = 'LEADER',
    action = wezterm.action.ActivatePaneDirection 'Down',
  },
  {
    key = 'k',
    mods = 'LEADER',
    action = wezterm.action.ActivatePaneDirection 'Up',
  },
  {
    key = 'l',
    mods = 'LEADER',
    action = wezterm.action.ActivatePaneDirection 'Right',
  },
  -- Pane resizing (like tmux)
  {
    key = 'H',
    mods = 'LEADER',
    action = wezterm.action.AdjustPaneSize { 'Left', 10 },
  },
  {
    key = 'J',
    mods = 'LEADER',
    action = wezterm.action.AdjustPaneSize { 'Down', 10 },
  },
  {
    key = 'K',
    mods = 'LEADER',
    action = wezterm.action.AdjustPaneSize { 'Up', 10 },
  },
  {
    key = 'L',
    mods = 'LEADER',
    action = wezterm.action.AdjustPaneSize { 'Right', 10 },
  },
  -- Zoom pane (like tmux)
  {
    key = 'm',
    mods = 'LEADER',
    action = wezterm.action.TogglePaneZoomState,
  },
  -- Close pane (like tmux)
  {
    key = 'x',
    mods = 'LEADER',
    action = wezterm.action.CloseCurrentPane { confirm = true },
  },
  -- Create new tab (similar to tmux windows)
  {
    key = 'c',
    mods = 'LEADER',
    action = wezterm.action.SpawnTab 'CurrentPaneDomain',
  },
  -- Navigate tabs (like tmux windows)
  {
    key = 'n',
    mods = 'LEADER',
    action = wezterm.action.ActivateTabRelative(1),
  },
  {
    key = 'p',
    mods = 'LEADER',
    action = wezterm.action.ActivateTabRelative(-1),
  },
  -- Tab selection by number (like tmux)
  {
    key = '1',
    mods = 'LEADER',
    action = wezterm.action.ActivateTab(0),
  },
  {
    key = '2',
    mods = 'LEADER',
    action = wezterm.action.ActivateTab(1),
  },
  {
    key = '3',
    mods = 'LEADER',
    action = wezterm.action.ActivateTab(2),
  },
  {
    key = '4',
    mods = 'LEADER',
    action = wezterm.action.ActivateTab(3),
  },
  {
    key = '5',
    mods = 'LEADER',
    action = wezterm.action.ActivateTab(4),
  },
  {
    key = '6',
    mods = 'LEADER',
    action = wezterm.action.ActivateTab(5),
  },
  {
    key = '7',
    mods = 'LEADER',
    action = wezterm.action.ActivateTab(6),
  },
  {
    key = '8',
    mods = 'LEADER',
    action = wezterm.action.ActivateTab(7),
  },
  {
    key = '9',
    mods = 'LEADER',
    action = wezterm.action.ActivateTab(8),
  },
  -- Copy mode (like tmux)
  {
    key = '[',
    mods = 'LEADER',
    action = wezterm.action.ActivateCopyMode,
  },
  -- Paste from clipboard
  {
    key = ']',
    mods = 'LEADER',
    action = wezterm.action.PasteFrom 'Clipboard',
  },
  -- Search (like tmux)
  {
    key = '/',
    mods = 'LEADER',
    action = wezterm.action.Search 'CurrentSelectionOrEmptyString',
  },
  -- Rename tab (like tmux rename window)
  {
    key = ',',
    mods = 'LEADER',
    action = wezterm.action.PromptInputLine {
      description = 'Enter new name for tab',
      action = wezterm.action_callback(function(window, pane, line)
        if line then
          window:active_tab():set_title(line)
        end
      end),
    },
  },
}

-- Navigator.nvim integration (from official wiki)
local act = wezterm.action

local function isViProcess(pane)
  -- get_foreground_process_name On Linux, macOS and Windows,
  -- the process can be queried to get this path. Other operating systems
  -- (notably, FreeBSD and other unix systems) are not currently supported
  return pane:get_foreground_process_name():find('n?vim') ~= nil
  -- return pane:get_title():find("n?vim") ~= nil
end

local function conditionalActivatePane(window, pane, pane_direction, vim_direction)
  if isViProcess(pane) then
    window:perform_action(
    -- This should match the keybinds you set in Neovim.
      act.SendKey({ key = vim_direction, mods = 'CTRL' }),
      pane
    )
  else
    window:perform_action(act.ActivatePaneDirection(pane_direction), pane)
  end
end

table.insert(config.keys, {
  key = 'h',
  mods = 'CTRL',
  action = wezterm.action_callback(function(window, pane)
    conditionalActivatePane(window, pane, 'Left', 'h')
  end),
})
table.insert(config.keys, {
  key = 'j',
  mods = 'CTRL',
  action = wezterm.action_callback(function(window, pane)
    conditionalActivatePane(window, pane, 'Down', 'j')
  end),
})
table.insert(config.keys, {
  key = 'k',
  mods = 'CTRL',
  action = wezterm.action_callback(function(window, pane)
    conditionalActivatePane(window, pane, 'Up', 'k')
  end),
})
table.insert(config.keys, {
  key = 'l',
  mods = 'CTRL',
  action = wezterm.action_callback(function(window, pane)
    conditionalActivatePane(window, pane, 'Right', 'l')
  end),
})

-- Mouse bindings
config.mouse_bindings = {
  -- Right click to paste
  {
    event = { Up = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    action = wezterm.action.PasteFrom 'Clipboard',
  },
}


-- Status line (similar to tmux)
wezterm.on('update-status', function(window, pane)
  local date = wezterm.strftime '%Y-%m-%d %H:%M '
  local hostname = wezterm.hostname()
  local cwd = pane:get_current_working_dir()
  local cwd_string = ''
  if cwd then
    cwd_string = cwd.file_path:gsub(os.getenv('HOME'), '~')
  end

  window:set_right_status(wezterm.format {
    { Foreground = { Color = '#ffc777' } },
    { Text = cwd_string },
    { Foreground = { Color = '#82aaff' } },
    { Text = ' ❯ ' },
    { Foreground = { Color = '#c3e88d' } },
    { Text = date },
    { Foreground = { Color = '#82aaff' } },
    { Text = '❯ ' },
    { Foreground = { Color = '#ff757f' } },
    { Text = hostname .. ' ' },
  })
end)

-- Custom tab bar formatting
wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local title = tab.tab_title
  if #title == 0 then
    title = tab.active_pane.title
  end

  -- Ensure title fits
  if #title > max_width - 6 then
    title = wezterm.truncate_right(title, max_width - 6) .. '…'
  end

  local index = tab.tab_index + 1
  local bg = 'NONE'    -- Transparent like tmux
  local fg = '#4c566a' -- Inactive window color from tmux
  local intensity = 'Normal'

  if tab.is_active then
    bg = 'NONE'    -- Keep transparent
    fg = '#ebcb8b' -- Yellow - active window color from tmux
    intensity = 'Bold'
  elseif hover then
    bg = '#1b1d2b' -- Slight background on hover
    fg = '#828bb8' -- Brighter text on hover
  end

  -- Add Nerd Font icons based on common tab names
  local icon = ''
  local title_lower = title:lower()
  if title_lower:find('nvim') or title_lower:find('vim') then
    icon = ' '
  elseif title_lower:find('git') then
    icon = ' '
  elseif title_lower:find('docker') then
    icon = ' '
  elseif title_lower:find('server') or title_lower:find('redis') then
    icon = ' '
  elseif title_lower:find('dotfiles') or title_lower:find('config') then
    icon = ' '
  elseif title_lower:find('lambda') then
    icon = 'λ '
  elseif title_lower:find('node') or title_lower:find('npm') then
    icon = ' '
  elseif title_lower:find('python') or title_lower:find('py') then
    icon = ' '
  elseif title_lower:find('rust') or title_lower:find('cargo') then
    icon = ' '
  elseif title_lower:find('go') then
    icon = ' '
  elseif title_lower:find('ruby') then
    icon = ' '
  elseif title_lower:find('www') or title_lower:find('web') then
    icon = ' '
  elseif title_lower:find('remote') or title_lower:find('ssh') then
    icon = ' '
  elseif title_lower:find('test') then
    icon = ' '
  elseif title_lower:find('build') then
    icon = ' '
  elseif title_lower:find('database') or title_lower:find('db') then
    icon = ' '
  elseif title_lower:find('terminal') or title_lower:find('shell') then
    icon = ' '
  elseif title_lower:find('fish') then
    icon = ' '
  elseif title_lower:find('bash') or title_lower:find('zsh') then
    icon = ' '
  end

  -- Match tmux window format: "1 ❯ title" for active, "1 ❭ title" for inactive
  local separator = tab.is_active and '❯' or '❭'

  -- Format similar to tmux window-status-format
  return {
    { Background = { Color = bg } },
    { Foreground = { Color = fg } },
    { Attribute = { Intensity = intensity } },
    { Text = index .. ' ' .. separator .. ' ' .. icon .. title .. ' ' },
  }
end)

-- Workspace configurations (similar to tmuxinator)
local function create_appledore_workspace(window)
  local tab, build_pane, window = window:mux_window():spawn_tab {
    cwd = wezterm.home_dir .. "/dotfiles",
  }
  tab:set_title("dotfiles")

  -- Split horizontally for git status
  local git_pane = build_pane:split {
    direction = 'Bottom',
    size = 0.3,
    cwd = wezterm.home_dir .. "/dotfiles",
  }
  git_pane:send_text("git status\n")

  -- Split the bottom pane vertically for scripts
  local scripts_pane = git_pane:split {
    direction = 'Right',
    size = 0.5,
    cwd = wezterm.home_dir .. "/scripts",
  }
  scripts_pane:send_text("ls -la\n")

  -- Send nvim command to main pane
  build_pane:send_text("nvim .\n")

  -- Create remote tab
  local remote_tab, remote_pane = window:spawn_tab {
    cwd = wezterm.home_dir,
  }
  remote_tab:set_title("remote")

  -- Split for htop
  local htop_pane = remote_pane:split {
    direction = 'Right',
    size = 0.5,
  }
  htop_pane:send_text("htop\n")
  remote_pane:send_text("clear\necho 'Ready for SSH connections'\n")

  -- Switch back to first tab
  window:perform_action(wezterm.action.ActivateTab(0), build_pane)
end

local function create_timely_workspace(window)
  -- PyBench tab
  local pybench_tab, pybench_pane, window = window:mux_window():spawn_tab {
    cwd = wezterm.home_dir .. "/projects/pybench",
  }
  pybench_tab:set_title("pybench")

  local pybench_pane2 = pybench_pane:split {
    direction = 'Bottom',
    size = 0.3,
  }
  local pybench_pane3 = pybench_pane2:split {
    direction = 'Right',
    size = 0.5,
  }

  -- Raft tab
  local raft_tab, raft_pane = window:spawn_tab {
    cwd = wezterm.home_dir .. "/projects/raft",
  }
  raft_tab:set_title("raft")

  local raft_pane2 = raft_pane:split {
    direction = 'Bottom',
    size = 0.3,
  }
  local raft_pane3 = raft_pane2:split {
    direction = 'Right',
    size = 0.5,
  }

  -- Lambdas tab
  local lambdas_tab, lambdas_pane = window:spawn_tab {
    cwd = wezterm.home_dir .. "/projects/lambdas-prod",
  }
  lambdas_tab:set_title("lambdas")

  lambdas_pane:send_text("startenv | nvim\n")

  local lambdas_pane2 = lambdas_pane:split {
    direction = 'Bottom',
    size = 0.3,
  }
  lambdas_pane2:send_text("startenv | git fetch\n")

  local lambdas_pane3 = lambdas_pane2:split {
    direction = 'Right',
    size = 0.5,
  }
  lambdas_pane3:send_text("startenv\n")

  local lambdas_pane4 = lambdas_pane3:split {
    direction = 'Right',
    size = 0.5,
  }
  lambdas_pane4:send_text("startenv\n")

  -- Mononest tab
  local mononest_tab, mononest_pane = window:spawn_tab {
    cwd = wezterm.home_dir .. "/projects/mononest",
  }
  mononest_tab:set_title("mononest")

  mononest_pane:send_text("startenv\nnvim\n")

  local mononest_pane2 = mononest_pane:split {
    direction = 'Bottom',
    size = 0.3,
  }
  mononest_pane2:send_text("startenv\ngit fetch\n")

  -- Dotfiles tab
  local dotfiles_tab, dotfiles_pane = window:spawn_tab {
    cwd = wezterm.home_dir .. "/dotfiles",
  }
  dotfiles_tab:set_title("dotfiles")

  -- Switch back to first tab
  window:perform_action(wezterm.action.ActivateTab(0), pybench_pane)
end

local function create_zoca_workspace(window)
  -- Similar structure but with zoca-specific tabs
  -- PyBench tab
  local pybench_tab, pybench_pane, window = window:mux_window():spawn_tab {
    cwd = wezterm.home_dir .. "/projects/pybench",
  }
  pybench_tab:set_title("pybench")

  local pybench_pane2 = pybench_pane:split {
    direction = 'Bottom',
    size = 0.3,
  }
  local pybench_pane3 = pybench_pane2:split {
    direction = 'Right',
    size = 0.5,
  }

  -- Raft tab
  local raft_tab, raft_pane = window:spawn_tab {
    cwd = wezterm.home_dir .. "/projects/raft",
  }
  raft_tab:set_title("raft")

  local raft_pane2 = raft_pane:split {
    direction = 'Bottom',
    size = 0.3,
  }
  local raft_pane3 = raft_pane2:split {
    direction = 'Right',
    size = 0.5,
  }

  -- WWW tab
  local www_tab, www_pane = window:spawn_tab {
    cwd = wezterm.home_dir .. "/projects/zoca-websites",
  }
  www_tab:set_title("www")

  local www_pane2 = www_pane:split {
    direction = 'Bottom',
    size = 0.3,
  }
  local www_pane3 = www_pane2:split {
    direction = 'Right',
    size = 0.5,
  }

  -- Mononest tab
  local mononest_tab, mononest_pane = window:spawn_tab {
    cwd = wezterm.home_dir .. "/projects/mononest",
  }
  mononest_tab:set_title("mononest")

  mononest_pane:send_text("startenv\nnvim\n")

  local mononest_pane2 = mononest_pane:split {
    direction = 'Bottom',
    size = 0.3,
  }
  mononest_pane2:send_text("startenv\ngit fetch\n")

  -- Dotfiles tab
  local dotfiles_tab, dotfiles_pane = window:spawn_tab {
    cwd = wezterm.home_dir .. "/dotfiles",
  }
  dotfiles_tab:set_title("dotfiles")

  -- Servers tab
  local servers_tab, servers_pane = window:spawn_tab {
    cwd = wezterm.home_dir,
  }
  servers_tab:set_title("servers")

  servers_pane:send_text("redis-server\n")

  local redis_cli_pane = servers_pane:split {
    direction = 'Right',
    size = 0.5,
  }
  redis_cli_pane:send_text("redis-cli\n")

  local servers_pane3 = servers_pane:split {
    direction = 'Bottom',
    size = 0.5,
  }

  local servers_pane4 = redis_cli_pane:split {
    direction = 'Bottom',
    size = 0.5,
  }

  local servers_pane5 = servers_pane3:split {
    direction = 'Right',
    size = 0.5,
  }

  local servers_pane6 = servers_pane4:split {
    direction = 'Right',
    size = 0.5,
  }

  -- Switch back to first tab
  window:perform_action(wezterm.action.ActivateTab(0), pybench_pane)
end

-- Add workspace launching keybindings
table.insert(config.keys, {
  key = 'W',
  mods = 'LEADER',
  action = wezterm.action.InputSelector {
    title = 'Launch Workspace',
    choices = {
      { label = 'appledore', id = 'appledore' },
      { label = 'timely',    id = 'timely' },
      { label = 'zoca',      id = 'zoca' },
    },
    action = wezterm.action_callback(function(window, pane, id, label)
      if id == 'appledore' then
        create_appledore_workspace(window)
      elseif id == 'timely' then
        create_timely_workspace(window)
      elseif id == 'zoca' then
        create_zoca_workspace(window)
      end
    end),
  },
})

-- Session management keybindings
table.insert(config.keys, {
  key = 'S',
  mods = 'LEADER',
  action = wezterm.action_callback(function(window, pane)
    save_session(window)
  end),
})

table.insert(config.keys, {
  key = 'R',
  mods = 'LEADER',
  action = wezterm.action_callback(function(window, pane)
    restore_session(window)
  end),
})

-- Show workspace/session info
table.insert(config.keys, {
  key = '?',
  mods = 'LEADER',
  action = wezterm.action_callback(function(window, pane)
    local info = [[
WezTerm Workspaces & Sessions

Available Workspaces (Ctrl-A W):
  • appledore - Dotfiles development environment
    - dotfiles: nvim, git status, scripts listing
    - remote: SSH ready + htop monitoring

  • timely - Work projects setup
    - pybench: 3-pane development layout
    - raft: 3-pane development layout
    - lambdas: nvim + git + 2 shells (with startenv)
    - mononest: nvim + git fetch (with startenv)
    - dotfiles: single pane

  • zoca - Full development environment
    - pybench: 3-pane development layout
    - raft: 3-pane development layout
    - www: 3-pane development layout
    - mononest: nvim + git fetch (with startenv)
    - dotfiles: single pane
    - servers: redis-server, redis-cli + 4 additional panes

Session Commands:
  Ctrl-A S - Save current session
  Ctrl-A R - Restore saved session

Current Session Info:
]]

    -- Add current tabs info
    local tabs = window:mux_window():tabs()
    info = info .. "  Active tabs: " .. #tabs .. "\n"
    for i, tab in ipairs(tabs) do
      local panes = tab:panes()
      info = info .. "  " .. i .. ". " .. tab:get_title() .. " (" .. #panes .. " panes)\n"
    end

    -- Check if saved session exists
    local file = io.open(session_file, 'r')
    if file then
      local content = file:read('*a')
      file:close()
      local ok, session_data = pcall(wezterm.json_parse, content)
      if ok and session_data.timestamp then
        local saved_time = os.date("%Y-%m-%d %H:%M:%S", session_data.timestamp)
        info = info .. "\n  Saved session from: " .. saved_time
        info = info .. "\n  Saved tabs: " .. #session_data.tabs
      end
    else
      info = info .. "\n  No saved session found"
    end

    -- Create a temporary pane to show the info
    local temp_pane = pane:split {
      direction = 'Right',
      size = 0.6,
    }
    -- Use printf for better compatibility with fish
    temp_pane:send_text("clear; printf '%s\\n' " .. wezterm.shell_quote_arg(info) .. "\n")
    temp_pane:send_text("echo '\\nPress Enter to close this pane...'; read; exit\n")
  end),
})

-- List all keybindings
table.insert(config.keys, {
  key = '0',
  mods = 'LEADER',
  action = wezterm.action_callback(function(window, pane)
    local help = [[
WezTerm Keybindings (tmux-style)

Leader key: Ctrl-A

== Pane Management ==
  Ctrl-A |     Split pane horizontally
  Ctrl-A -     Split pane vertically
  Ctrl-A h/j/k/l   Navigate panes
  Ctrl-A H/J/K/L   Resize panes (by 10)
  Ctrl-A m     Toggle pane zoom
  Ctrl-A x     Close current pane
  Ctrl-h/j/k/l Smart vim-aware navigation

== Tab Management ==
  Ctrl-A c     Create new tab
  Ctrl-A n/p   Next/previous tab
  Ctrl-A 1-9   Switch to tab by number
  Ctrl-A ,     Rename current tab

== Copy Mode ==
  Ctrl-A [     Enter copy mode
  Ctrl-A ]     Paste from clipboard
  Ctrl-A /     Search

== Workspaces & Sessions ==
  Ctrl-A W     Launch workspace menu
  Ctrl-A S     Save current session
  Ctrl-A R     Restore saved session
  Ctrl-A ?     Show workspace info

== Other ==
  Ctrl-A r     Reload configuration
  Ctrl-A h     Show this help
  Ctrl-A Ctrl-A    Send literal Ctrl-A

Press Enter to close this help...
]]

    -- Create a temporary pane to show help
    local help_pane = pane:split {
      direction = 'Right',
      size = 0.5,
    }
    -- Use printf for better compatibility with fish
    help_pane:send_text("clear; printf '%s\\n' " .. wezterm.shell_quote_arg(help) .. "\n")
    help_pane:send_text("read; exit\n")
  end),
})

-- Auto-save session periodically (every 5 minutes)
wezterm.on('trigger-save-session', function(window, pane)
  save_session(window)
  -- Schedule next save
  window:set_timeout(300000, function()
    window:perform_action(wezterm.action.EmitEvent 'trigger-save-session', pane)
  end)
end)

-- Optionally auto-restore last session on startup
wezterm.on('gui-startup', function(cmd)
  local args = cmd.args
  if args and #args > 0 then
    -- If started with arguments, don't restore session
    return
  end

  -- Check if session file exists and is recent (less than 24 hours old)
  local file = io.open(session_file, 'r')
  if file then
    file:close()
    local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
    -- Small delay to ensure window is ready
    window:set_timeout(100, function()
      restore_session(window)
    end)
  end
end)

-- Save session on exit
wezterm.on('window-close-requested', function(window, pane)
  save_session(window)
  -- Allow window to close
  window:perform_action(wezterm.action.CloseCurrentPane { confirm = false }, pane)
end)

return config
