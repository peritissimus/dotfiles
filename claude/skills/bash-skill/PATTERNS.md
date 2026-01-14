# Common Bash Patterns

## Script Template

```bash
#!/usr/bin/env bash
set -euo pipefail

# Description: What this script does
# Usage: ./script.sh [options] <args>

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"

main() {
    # Main logic here
    echo "Running $SCRIPT_NAME"
}

main "$@"
```

## Logging

```bash
log_info()  { echo "[INFO]  $*"; }
log_warn()  { echo "[WARN]  $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }
log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo "[DEBUG] $*"; }
```

## Cleanup Trap

```bash
cleanup() {
    rm -rf "$tmp_dir"
}
trap cleanup EXIT
tmp_dir="$(mktemp -d)"
```

## Confirm Prompt

```bash
confirm() {
    read -rp "$1 [y/N] " response
    [[ "$response" =~ ^[Yy]$ ]]
}

if confirm "Continue?"; then
    echo "Proceeding..."
fi
```

## Retry Logic

```bash
retry() {
    local max_attempts=$1
    shift
    local attempt=1
    until "$@"; do
        if ((attempt >= max_attempts)); then
            return 1
        fi
        ((attempt++))
        sleep 1
    done
}

retry 3 curl -f https://example.com
```

## Parallel Execution

```bash
# Run commands in parallel
pids=()
for item in "${items[@]}"; do
    process_item "$item" &
    pids+=($!)
done

# Wait for all
for pid in "${pids[@]}"; do
    wait "$pid"
done
```
