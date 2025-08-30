# Neovim DAP (Debug Adapter Protocol) Usage Guide

This guide covers how to use the DAP (Debug Adapter Protocol) debugging setup in this Neovim configuration.

## Overview

The configuration uses:
- **nvim-dap**: Core debugging support
- **nvim-dap-ui**: Visual debugging interface
- **nvim-dap-virtual-text**: Shows variable values inline during debugging
- **mason-nvim-dap**: Automatic installation and setup of debug adapters

## Key Mappings

All debugging commands are prefixed with `<leader>d` (default leader is space):

### Core Debugging
- `<leader>dc` - **Continue/Run** - Start or continue debugging
- `<leader>db` - **Toggle Breakpoint** - Set/remove a breakpoint at current line
- `<leader>dB` - **Conditional Breakpoint** - Set a breakpoint with a condition
- `<leader>dt` - **Terminate** - Stop the debugging session
- `<leader>dP` - **Pause** - Pause execution

### Stepping Through Code
- `<leader>di` - **Step Into** - Step into function calls
- `<leader>do` - **Step Out** - Step out of current function
- `<leader>dO` - **Step Over** - Execute current line without entering functions
- `<leader>dC` - **Run to Cursor** - Continue execution until cursor position

### Navigation
- `<leader>dj` - **Down** - Go down in call stack
- `<leader>dk` - **Up** - Go up in call stack
- `<leader>dg` - **Go to Line** - Jump to line without executing

### Debug UI & Tools
- `<leader>du` - **Toggle DAP UI** - Show/hide the debugging interface
- `<leader>de` - **Evaluate** - Evaluate expression under cursor (works in visual mode too)
- `<leader>dr` - **Toggle REPL** - Open debug console
- `<leader>dw` - **Widgets** - Show hover information
- `<leader>ds` - **Session** - Manage debug sessions

### Other Commands
- `<leader>da` - **Run with Args** - Start debugging with arguments
- `<leader>dl` - **Run Last** - Re-run the last debug configuration

## Setting Up Language-Specific Debuggers

### 1. Install Debug Adapters via Mason

Open Neovim and run:
```vim
:Mason
```

Look for and install debug adapters (they usually have `-debug` or `-dap` suffix):
- Python: `debugpy`
- JavaScript/TypeScript: `js-debug-adapter`
- Go: `delve`
- Rust: `codelldb`
- C/C++: `cpptools` or `codelldb`

### 2. Configure launch.json (VS Code Style)

Create a `.vscode/launch.json` file in your project root. The configuration automatically reads VS Code launch configurations:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "python",
      "request": "launch",
      "name": "Launch Python",
      "program": "${file}",
      "console": "integratedTerminal"
    },
    {
      "type": "node",
      "request": "launch",
      "name": "Launch Node",
      "program": "${workspaceFolder}/index.js",
      "skipFiles": ["<node_internals>/**"]
    }
  ]
}
```

### 3. Language-Specific Examples

#### Python
```json
{
  "type": "python",
  "request": "launch",
  "name": "Python: Current File",
  "program": "${file}",
  "console": "integratedTerminal",
  "justMyCode": true
}
```

#### JavaScript/TypeScript (Node.js)
```json
{
  "type": "node",
  "request": "launch",
  "name": "Launch Program",
  "skipFiles": ["<node_internals>/**"],
  "program": "${workspaceFolder}/app.js",
  "outFiles": ["${workspaceFolder}/**/*.js"]
}
```

#### Go
```json
{
  "type": "go",
  "request": "launch",
  "name": "Launch Go",
  "mode": "auto",
  "program": "${fileDirname}"
}
```

#### Rust
```json
{
  "type": "lldb",
  "request": "launch",
  "name": "Launch Rust",
  "cargo": {
    "args": ["build", "--bin=myapp"],
    "filter": {
      "name": "myapp",
      "kind": "bin"
    }
  },
  "args": [],
  "cwd": "${workspaceFolder}"
}
```

## Debugging Workflow

1. **Set Breakpoints**: Navigate to the line and press `<leader>db`
2. **Start Debugging**: Press `<leader>dc` to start/continue
3. **Inspect Variables**: 
   - Hover over variables with `<leader>dw`
   - Use `<leader>de` to evaluate expressions
   - Virtual text automatically shows variable values
4. **Step Through Code**: Use `<leader>di`, `<leader>do`, `<leader>dO`
5. **View Debug UI**: Toggle with `<leader>du` for a comprehensive view
6. **Stop Debugging**: Press `<leader>dt` to terminate

## DAP UI Layout

When `<leader>du` is pressed, the UI opens with:
- **Variables**: Shows local and global variables
- **Watches**: Monitor specific expressions
- **Call Stack**: View the execution stack
- **Breakpoints**: List all breakpoints
- **Console/REPL**: Interactive debug console

The UI automatically opens when debugging starts and closes when finished.

## Tips

1. **Conditional Breakpoints**: Use `<leader>dB` and enter conditions like `i > 10`
2. **Log Points**: Some adapters support log points - breakpoints that log instead of stopping
3. **Exception Breakpoints**: Configure in launch.json to break on exceptions
4. **Multi-Session**: DAP supports multiple concurrent debug sessions
5. **Remote Debugging**: Many adapters support attaching to remote processes

## Troubleshooting

1. **Adapter Not Found**: Install via `:Mason` or configure manually
2. **Breakpoints Not Hit**: Ensure source maps are configured (for compiled languages)
3. **UI Not Opening**: Check that `nvim-dap-ui` is installed and loaded
4. **Launch Config Issues**: Validate JSON syntax in `.vscode/launch.json`

## Visual Indicators

The configuration includes visual indicators for:
- Breakpoints (red dot by default)
- Current execution line (highlighted)
- Conditional breakpoints (different color/symbol)
- Log points (if supported by adapter)

## Advanced Configuration

For custom adapter configuration, create a file in `~/.config/nvim/lua/plugins/` and configure adapters directly:

```lua
return {
  "mfussenegger/nvim-dap",
  config = function()
    local dap = require("dap")
    
    -- Custom adapter configuration
    dap.adapters.custom = {
      type = "executable",
      command = "path/to/adapter",
      args = { "--port", "9001" }
    }
    
    -- Custom configuration
    dap.configurations.mylang = {
      {
        type = "custom",
        request = "launch",
        name = "Custom Debug",
        -- configuration specific options
      }
    }
  end
}
```

## Resources

- [nvim-dap Wiki](https://github.com/mfussenegger/nvim-dap/wiki)
- [Debug Adapter Protocol](https://microsoft.github.io/debug-adapter-protocol/)
- [Mason DAP Adapters](https://github.com/jay-babu/mason-nvim-dap.nvim)