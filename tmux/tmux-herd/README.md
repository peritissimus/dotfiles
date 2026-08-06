# tmux-herd

Agent-aware status for tmux. Know which of your AI coding agents are
**blocked**, **working**, **done**, or **idle** — from the status line you
already have. No sidebar, no new multiplexer, no processes spawned to render.

```
status-right:  ●2 ●3 ●1        (red: blocked on you, yellow: working, green: done)
prefix + g:    native choose-tree of agent panes — instant, like prefix+s
```

## How it works

State lives in a tmux **pane user option** (`@herd_state`) — not files, not a
daemon — so it dies with its pane and is readable natively by tmux formats.
Three cooperating parts:

1. **Agents self-report** through their lifecycle hooks. Any process in a
   pane can declare its state:

   ```sh
   /path/to/tmux-herd/scripts/hook-update.sh working   # or blocked|done|idle|clear
   ```

2. **`statusline.sh`** (runs on tmux's 1s status interval) renders the
   colored counts and acts as maintainer: panes with no hook-reported state
   get a `~state` inferred from their OSC title — Claude Code/Codex animate
   a braille spinner while working, park the title at `✳ ` when idle, and
   Codex titles say "Action Required" when blocked.

3. **`prefix + g`** opens an fzf popup of agent panes sorted blocked-first;
   enter jumps to the chosen pane. Filled `●` = hook-reported, hollow `○` =
   title-inferred. Set `@herd-popup 'native'` for a `choose-tree` variant
   instead (same machinery as tmux's `prefix + s` — zero process spawns,
   plainer looks).

## Install

With [TPM](https://github.com/tmux-plugins/tpm):

```tmux
set -g @plugin 'peritissimus/tmux-herd'
```

Manual:

```tmux
run-shell /path/to/tmux-herd/herd.tmux
```

By default the status segment is prepended to `status-right`. To control
placement yourself, put `#{herd_status}` anywhere in `status-left` or
`status-right` before the plugin loads.

## Claude Code integration

One command wires Claude Code's hooks to herd states:

```sh
./scripts/install-claude-hooks.sh          # merges into ~/.claude/settings.json (backs it up first)
```

Mapping: `UserPromptSubmit`/`PreToolUse` → working · `Stop` → done ·
`Notification` (permission prompt / waiting on input) → blocked ·
`SessionStart` → idle · `SessionEnd` → clear.

Other agent CLIs with hook/notification support can call `hook-update.sh`
the same way — the protocol is just "run a script with one argument".

## Options

| Option | Default | Meaning |
|---|---|---|
| `@herd-popup-key` | `g` | Key (after prefix) that opens the agent popup |
| `@herd-popup` | (fzf) | Set to `native` for a choose-tree instead of the fzf popup |

## Requirements

- tmux ≥ 3.1 (pane user options); the optional fzf popup wants ≥ 3.2 and `fzf`
- `python3` only for the Claude hooks installer

## License

MIT
