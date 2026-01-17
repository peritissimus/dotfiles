# Enterprise Bash Patterns

## Enterprise Script Template

Use this template for production-grade scripts. It includes safety settings, logging, help generation, and argument parsing.

```bash
#!/usr/bin/env bash

# Enable "Bash strict mode"
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error.
# -o pipefail: The return value of a pipeline is the status of the last command to exit with a non-zero status.
set -euo pipefail

# Inherit the ERR trap for functions, command substitutions, and subshells
set -E

# Constants
readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/tmp/${SCRIPT_NAME%.*}.log"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Default settings
VERBOSE=0
DRY_RUN=0

# usage: prints help message
usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [options] <arguments>

Description:
    A brief description of what this script does.

Options:
    -h, --help      Show this help message and exit
    -v, --verbose   Enable verbose logging
    -n, --dry-run   Simulate actions without executing them
    -f, --file      Specify an input file

Examples:
    $SCRIPT_NAME --verbose --dry-run
    $SCRIPT_NAME -f input.txt
EOF
}

# cleanup: function executed on exit
cleanup() {
    # Remove temporary files, kill background jobs, etc.
    # rm -f /tmp/tempfile
    : 
}
trap cleanup EXIT

# Logging functions
log() {
    local level="$1"
    shift
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    # Print to stderr to separate from normal output, and optionally to a log file
    echo -e "${timestamp} [${level}] $*" >&2
}

info() { log "${BLUE}INFO${NC}" "$@"; }
warn() { log "${YELLOW}WARN${NC}" "$@"; }
error() { log "${RED}ERROR${NC}" "$@"; }
success() { log "${GREEN}OK${NC}" "$@"; }
debug() { [[ "${VERBOSE}" -eq 1 ]] && log "DEBUG" "$@"; }

# die: print error and exit
die() {
    error "$@"
    exit 1
}

# assert_cmd: check if a command exists
assert_cmd() {
    if ! command -v "$1" &>/dev/null; then
        die "Required command '$1' not found. Please install it."
    fi
}

# parse_params: parse command line arguments
parse_params() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=1
                shift
                ;;
            -f|--file)
                if [[ -z "${2-}" ]]; then
                    die "Option $1 requires an argument."
                fi
                INPUT_FILE="$2"
                shift 2
                ;;
            -*) # Handle unknown options
                die "Unknown option: $1"
                ;;
            *) # Handle positional arguments
                ARGS+=("$1")
                shift
                ;;
        esac
    done
}

main() {
    # Initialize variables
    ARGS=()
    
    # Parse arguments
    parse_params "$@"
    
    # Validation logic
    # [[ ${#ARGS[@]} -eq 0 ]] && die "Missing required arguments"
    
    # Check dependencies
    assert_cmd "curl"
    assert_cmd "jq"
    
    info "Starting script..."
    debug "Arguments: ${ARGS[*]}"
    
    # Main logic
    if [[ "$DRY_RUN" -eq 1 ]]; then
        warn "Dry run mode enabled. No changes will be made."
    else
        success "Operation completed successfully."
    fi
}

# Pass arguments to main
main "$@"
```

## Robust Error Handling

Wrap critical commands to handle failures gracefully or provide context.

```bash
# safe_exec: execute a command with error handling
safe_exec() {
    local cmd="$1"
    local error_msg="${2:-Command failed}"
    
    info "Executing: $cmd"
    if ! eval "$cmd"; then
        die "$error_msg"
    fi
}

# Usage
safe_exec "mkdir -p /path/to/dir" "Failed to create directory"
```

## Atomic File Operations

Use temporary files and move them into place to ensure file integrity.

```bash
atomic_write() {
    local file="$1"
    local content="$2"
    local tmp_file
    tmp_file="$(mktemp)"
    
    echo "$content" > "$tmp_file"
    
    # Preserve permissions if the file exists
    if [[ -f "$file" ]]; then
        chmod --reference="$file" "$tmp_file"
        chown --reference="$file" "$tmp_file"
    fi
    
    mv "$tmp_file" "$file" || die "Failed to write to $file"
}
```

## Lock File (Singleton Execution)

Prevent multiple instances of the script from running simultaneously.

```bash
lock() {
    local lock_file="/tmp/${SCRIPT_NAME}.lock"
    exec 200>"$lock_file"
    if ! flock -n 200; then
        die "Another instance is already running."
    fi
}

# Call lock at the start of main
# lock
```

## User Interaction

Safe user prompts with defaults and validation.

```bash
ask() {
    local prompt="$1"
    local default="${2:-}"
    local reply
    
    if [[ -n "$default" ]]; then
        read -rp "$prompt [$default]: " reply
    else
        read -rp "$prompt: " reply
    fi
    echo "${reply:-$default}"
}

# Usage
name=$(ask "Enter your name" "User")
```
