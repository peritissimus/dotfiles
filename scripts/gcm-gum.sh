#!/bin/bash
# Git Commit Message Generator - Gum Enhanced Version
# Exit on error
set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly GIT_DIR="$(git rev-parse --git-dir 2>/dev/null || echo .git)"
readonly CACHE_DIR="${GIT_DIR}/gcm-cache"
readonly CONFIG_FILE="${GCM_CONFIG:-.gcmrc}"
readonly MAX_DIFF_SIZE=${GCM_MAX_DIFF_SIZE:-50000}  # Max characters to send to API
readonly MAX_TOKENS=${GCM_MAX_TOKENS:-2000}        # Max estimated tokens
readonly DEFAULT_MODEL=${GCM_MODEL:-gpt-4o-mini}
readonly CACHE_TTL=${GCM_CACHE_TTL:-604800}        # Cache TTL in seconds (1 week)

# Gum styles using terminal colors
readonly ERROR_STYLE="foreground=9"       # Bright Red
readonly SUCCESS_STYLE="foreground=10"    # Bright Green
readonly WARNING_STYLE="foreground=11"    # Bright Yellow
readonly INFO_STYLE="foreground=14"       # Bright Cyan
readonly DIM_STYLE="foreground=8"         # Bright Black (Gray)
readonly ACCENT_STYLE="foreground=13"     # Bright Magenta
readonly HEADER_STYLE="foreground=12"     # Bright Blue

# Logging utilities using gum
log_info() { gum style --$INFO_STYLE "ℹ $1"; }
log_success() { gum style --$SUCCESS_STYLE "✓ $1"; }
log_warning() { gum style --$WARNING_STYLE "⚠ $1"; }
log_error() { gum style --$ERROR_STYLE "✗ $1" >&2; }
log_debug() { [[ "${DEBUG:-0}" == "1" ]] && gum style --$DIM_STYLE "  $1" >&2; }

# Sensitive patterns to detect
readonly SENSITIVE_PATTERNS=(
  # API Keys and Tokens
  'api[_-]?key.*[:=][[:space:]]*[a-zA-Z0-9_-]{20,}'
  'token.*[:=][[:space:]]*[a-zA-Z0-9_-]{20,}'
  'bearer[[:space:]]+[a-zA-Z0-9_.-]+' 
  'authorization.*[:=][[:space:]]*[a-zA-Z0-9_-]{20,}'
  
  # AWS
  'AKIA[0-9A-Z]{16}'
  'aws[_-]?secret[_-]?access[_-]?key.*[:=][[:space:]]*[a-zA-Z0-9/+=]{40}'
  
  # Private Keys
  '-----BEGIN[[:space:]]+PRIVATE[[:space:]]+KEY'
  
  # Generic Secrets
  'password.*[:=][[:space:]]*[^[:space:]]{8,}'
  'secret.*[:=][[:space:]]*[a-zA-Z0-9_-]{20,}'
  
  # Database URLs
  'postgres://|mysql://|mongodb://|redis://'
)

# Function to check for sensitive content
check_sensitive_content() {
  local content="$1"
  local found_secrets=false
  
  # Use ripgrep if available, otherwise fall back to grep
  local grep_cmd="grep -qiE"
  if command -v rg &>/dev/null; then
    grep_cmd="rg -qi"
  fi
  
  for pattern in "${SENSITIVE_PATTERNS[@]}"; do
    if echo "$content" | $grep_cmd "$pattern" 2>/dev/null; then
      log_warning "Potential secret detected matching pattern: $pattern"
      found_secrets=true
    fi
  done
  
  if [[ "$found_secrets" == "true" ]]; then
    log_error "Sensitive content detected in diff. Please review and remove secrets before committing."
    if ! gum confirm "Continue anyway?"; then
      return 1
    fi
  fi
  return 0
}

# Function to estimate tokens more accurately
estimate_tokens() {
  local text="$1"
  # More accurate estimation based on OpenAI's guidelines
  # ~4 characters per token for English, ~2-3 for code
  local char_count=${#text}
  local word_count=$(echo "$text" | wc -w | tr -d ' ')
  
  # Use character-based estimation for code-heavy content
  local estimated_tokens=$((char_count / 3))
  
  log_debug "Characters: $char_count, Words: $word_count, Estimated tokens: $estimated_tokens"
  echo "$estimated_tokens"
}

# Function to truncate diff if too large
truncate_diff() {
  local diff="$1"
  local max_size="$2"
  
  if [[ ${#diff} -gt $max_size ]]; then
    log_warning "Diff truncated from ${#diff} to $max_size characters"
    echo "${diff:0:$max_size}... [truncated]"
  else
    echo "$diff"
  fi
}

# Function to get API key securely
get_api_key() {
  local key=""
  
  # Try environment variable first
  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    log_debug "Using API key from environment"
    echo "$OPENAI_API_KEY"
    return 0
  fi
  
  # Try macOS keychain
  if command -v security &>/dev/null; then
    key=$(security find-generic-password -s "gcm-openai-api-key" -w 2>/dev/null || true)
    if [[ -n "$key" ]]; then
      log_debug "Using API key from keychain"
      echo "$key"
      return 0
    fi
  fi
  
  # Try Linux secret service
  if command -v secret-tool &>/dev/null; then
    key=$(secret-tool lookup service gcm-openai-api-key 2>/dev/null || true)
    if [[ -n "$key" ]]; then
      log_debug "Using API key from secret service"
      echo "$key"
      return 0
    fi
  fi
  
  # Fall back to llm CLI
  if command -v llm &>/dev/null && llm keys get openai &>/dev/null; then
    log_debug "Using API key from llm CLI"
    return 0
  fi
  
  return 1
}

# Function to store API key securely
store_api_key() {
  local key="$1"
  
  if command -v security &>/dev/null; then
    security add-generic-password -s "gcm-openai-api-key" -a "$USER" -w "$key" 2>/dev/null || \
      security add-generic-password -U -s "gcm-openai-api-key" -a "$USER" -w "$key"
    log_success "API key stored in macOS keychain"
  elif command -v secret-tool &>/dev/null; then
    echo "$key" | secret-tool store --label="GCM OpenAI API Key" service gcm-openai-api-key
    log_success "API key stored in secret service"
  else
    # Fall back to llm CLI
    llm keys set openai --value "$key"
    log_warning "API key stored in llm CLI (less secure)"
  fi
}

# Function to load configuration
load_config() {
  # Check multiple config locations
  local config_files=(
    "$CONFIG_FILE"
    ".gcmrc"
    "$HOME/.gcmrc"
    "$HOME/.config/gcm/config"
  )
  
  for cfg in "${config_files[@]}"; do
    if [[ -f "$cfg" ]]; then
      log_debug "Loading config from $cfg"
      # Safe config loading - only allow specific variables
      while IFS='=' read -r key value; do
        # Remove quotes and whitespace
        value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^["'\'']//' -e 's/["'\'']*$//')
        case "$key" in
          model|max_tokens|max_diff_size|cache_ttl)
            local var_name="GCM_$(echo "$key" | tr '[:lower:]' '[:upper:]')"
            export "$var_name=$value"
            log_debug "Set $key=$value"
            ;;
          default_context)
            DEFAULT_CONTEXT="$value"
            ;;
          auto_stage)
            AUTO_STAGE="$value"
            ;;
          commit_style)
            COMMIT_STYLE="$value"
            ;;
          exclude_patterns)
            EXCLUDE_PATTERNS="$value"
            ;;
        esac
      done < <(grep -E '^[a-zA-Z_]+=' "$cfg" | grep -v '^#')
      break  # Use first found config
    fi
  done
}

# Function to create sample config
create_sample_config() {
  local config_path="${1:-.gcmrc}"
  
  if [[ -f "$config_path" ]]; then
    log_warning "Config file already exists: $config_path"
    return 1
  fi
  
  cat > "$config_path" << 'EOF'
# GCM Configuration File
# Place in project root or ~/.gcmrc

# LLM model to use
model=gpt-4o-mini

# Maximum tokens for prompt (affects cost)
max_tokens=2000

# Maximum diff size in characters
max_diff_size=50000

# Cache TTL in seconds (604800 = 1 week)
cache_ttl=604800

# Default context to add to all commits
# default_context="Part of Project X refactoring"

# Automatically stage modified files before commit
# auto_stage=false

# Commit message style (conventional, angular, custom)
commit_style=conventional

# Files to exclude from diff (gitignore patterns)
# exclude_patterns="*.min.js,*.lock,dist/*"
EOF
  
  log_success "Created config file: $config_path"
  log_info "Edit this file to customize GCM behavior"
}

# Initialize cache directory
init_cache() {
  if [[ ! -d "$CACHE_DIR" ]]; then
    mkdir -p "$CACHE_DIR"
  fi
}

# Function to check cache validity
is_cache_valid() {
  local cache_file="$1"
  local ttl="${2:-$CACHE_TTL}"
  
  [[ ! -f "$cache_file" ]] && return 1
  
  local file_age
  if [[ "$(uname)" == "Darwin" ]]; then
    file_age=$(stat -f %m "$cache_file" 2>/dev/null) || return 1
  else
    file_age=$(stat -c %Y "$cache_file" 2>/dev/null) || return 1
  fi
  
  [[ $(($(date +%s) - file_age)) -lt $ttl ]]
}

# Function to get cached or fresh project info
get_project_info() {
  local cache_file="$CACHE_DIR/project_info"
  
  # Check cache validity
  if is_cache_valid "$cache_file"; then
    log_debug "Using cached project info"
    cat "$cache_file"
    return 0
  fi
  
  log_debug "Generating fresh project info"
  
  # Get primary languages more efficiently
  local languages=$(git ls-files | \
    grep -E '\.(js|ts|tsx|jsx|py|java|go|rs|rb|php|cs|cpp|c|swift|kt|scala|clj|ex|exs)$' | \
    sed 's/.*\.//' | sort | uniq -c | sort -nr | head -5 | \
    awk '{printf "%s ", $2}' | sed 's/ $//')
  
  # Get key directories (top-level and important subdirs)
  local structure=$(git ls-files | \
    awk -F/ 'NF>1 {print $1"/"$2} NF==1 && /^[^.]+$/ {print $1}' | \
    sort | uniq -c | sort -rn | head -10 | awk '{print $2}')
  
  local info="Languages: ${languages:-unknown}\nKey directories:\n${structure}"
  echo "$info" | tee "$cache_file"
}

# Function to get recent commit patterns (cached)
get_commit_patterns() {
  local cache_file="$CACHE_DIR/commit_patterns"
  
  if is_cache_valid "$cache_file" 86400; then  # 24 hour cache
    cat "$cache_file"
    return 0
  fi
  
  # Analyze recent commits for patterns
  local patterns=$(git log --oneline -n 50 --pretty=format:'%s' 2>/dev/null | \
    grep -E '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore)' | \
    sed -E 's/^([a-z]+)(\([^)]+\))?:.*/\1 \2/' | \
    sort | uniq -c | sort -rn | head -5)
  
  echo "$patterns" | tee "$cache_file"
}

# Function to check for local LLM
check_local_llm() {
  if command -v ollama &>/dev/null && ollama list 2>/dev/null | grep -q .; then
    return 0
  fi
  return 1
}

# Function to generate commit message with gum spinner
generate_commit_message() {
  local files="$1"
  local diff="$2"
  local context="${3:-}"
  local model="${4:-$DEFAULT_MODEL}"
  local use_local=${5:-false}
  
  # Check for sensitive content
  if ! check_sensitive_content "$diff"; then
    return 1
  fi
  
  # Truncate diff if needed
  diff=$(truncate_diff "$diff" "$MAX_DIFF_SIZE")
  
  # Get project info and commit patterns
  local project_info=$(get_project_info)
  local patterns=$(get_commit_patterns)
  
  # Build optimized prompt
  local prompt="Generate a conventional commit message.

Modified files: $files
$project_info

Recent commit patterns:
$patterns

${context:+Context: $context}

Diff:
\`\`\`diff
$diff
\`\`\`

Rules:
- Format: <type>(<scope>): <description>
- Types: feat|fix|docs|style|refactor|perf|test|build|ci|chore
- Max 72 chars, imperative mood, no period
- Output ONLY the commit message, nothing else"

  # Estimate tokens
  local tokens=$(estimate_tokens "$prompt")
  if [[ $tokens -gt $MAX_TOKENS ]]; then
    log_error "Prompt too large ($tokens tokens). Please stage fewer changes."
    return 1
  fi
  
  # Try local LLM first if requested
  if [[ "$use_local" == "true" ]] && check_local_llm; then
    log_debug "Using local LLM (Ollama)"
    local result=$(echo "$prompt" | gum spin --spinner dots --title "Generating with local LLM..." --spinner.foreground="13" -- ollama run codellama --quiet 2>/dev/null || echo "")
    if [[ -n "$result" ]]; then
      echo "$result"
      return 0
    fi
    log_warning "Local LLM failed, falling back to API"
  fi
  
  # Call remote LLM with spinner
  if command -v llm &>/dev/null; then
    echo "$prompt" | gum spin --spinner dots --title "Generating commit message..." --spinner.foreground="13" -- llm -m "$model" --no-stream 2>/dev/null
  else
    log_error "llm CLI not found. Please install: pip install llm"
    return 1
  fi
}

# Function to validate commit message format
validate_commit_message() {
  local message="$1"
  # Only validate the first line (header)
  local first_line=$(echo "$message" | head -1)
  local pattern='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore)(\([a-z0-9\-]+\))?!?: .{1,72}$'
  
  if [[ ! "$first_line" =~ $pattern ]]; then
    log_warning "Generated message doesn't match conventional format"
    return 1
  fi
  return 0
}

# Function to interactively stage files with gum
interactive_stage() {
  local unstaged_files=$(git ls-files -m -o --exclude-standard | sort)
  
  if [[ -z "$unstaged_files" ]]; then
    log_info "No unstaged files to add"
    return 0
  fi
  
  log_info "Select files to stage:"
  local selected_files=$(echo "$unstaged_files" | gum choose --no-limit --height 10 --header "Select files to stage (Space to select, Enter to confirm):" --selected.foreground="10")
  
  if [[ -n "$selected_files" ]]; then
    echo "$selected_files" | xargs git add
    log_success "Files staged successfully"
  fi
}

# Main function
main() {
  # Debug
  [[ "${DEBUG:-0}" == "1" ]] && echo "DEBUG: Starting main function" >&2
  
  # Check git repository
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    log_error "Not a git repository"
    exit 1
  fi
  
  # Show header
  gum style \
    --foreground 13 \
    --border-foreground 13 \
    --border double \
    --align center \
    --width 50 \
    --margin "1 2" \
    --padding "1 2" \
    "🚀 Git Commit Message Generator" \
    "Enhanced with Gum"
  
  # Load configuration
  load_config
  
  # Apply default context if set
  if [[ -n "${DEFAULT_CONTEXT:-}" ]] && [[ -z "$context" ]]; then
    context="$DEFAULT_CONTEXT"
    log_debug "Using default context: $context"
  fi
  
  # Parse arguments
  local preview=false
  local context=""
  local model="$DEFAULT_MODEL"
  local dry_run=false
  local use_local=false
  local clear_cache=false
  local interactive_add=false
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      -p|--preview) preview=true; shift ;;
      -c|--context) context="$2"; shift 2 ;;
      -m|--model) model="$2"; shift 2 ;;
      -d|--dry-run) dry_run=true; shift ;;
      -l|--local) use_local=true; shift ;;
      -i|--interactive-add) interactive_add=true; shift ;;
      --clear-cache) clear_cache=true; shift ;;
      --init-config)
        create_sample_config "${2:-.gcmrc}"
        exit 0
        ;;
      -h|--help) 
        gum style --border double --padding "1 2" --margin "1" --border-foreground 14 --$HEADER_STYLE \
          "$(cat << 'EOF'
Git Commit Message Generator - Gum Enhanced

Usage: gcm-gum [OPTIONS]

Options:
  -p, --preview         Preview without committing
  -c, --context         Additional context
  -m, --model           LLM model (default: gpt-4o-mini)
  -d, --dry-run         Show token count without API call
  -l, --local           Try local LLM first (requires Ollama)
  -i, --interactive-add Interactive file staging with gum
  --clear-cache         Clear all cached data
  --init-config         Create a sample .gcmrc file

Config locations (in order of precedence):
  1. .gcmrc (current directory)
  2. ~/.gcmrc
  3. ~/.config/gcm/config
EOF
        )"
        exit 0
        ;;
      *) log_error "Unknown option: $1"; exit 1 ;;
    esac
  done
  
  # Initialize cache
  init_cache
  
  # Handle cache clearing
  if [[ "$clear_cache" == "true" ]]; then
    log_info "Clearing cache..."
    rm -rf "$CACHE_DIR"
    init_cache
    log_success "Cache cleared"
    [[ "$#" -eq 1 ]] && exit 0
  fi
  
  # Interactive staging if requested
  if [[ "$interactive_add" == "true" ]]; then
    interactive_stage
  fi
  
  # Check for staged changes (use name-status for more info)
  local staged_status=$(git diff --cached --name-status)
  if [[ -z "$staged_status" ]]; then
    log_error "No staged changes found"
    if gum confirm "Would you like to interactively stage files?"; then
      interactive_stage
      staged_status=$(git diff --cached --name-status)
      if [[ -z "$staged_status" ]]; then
        log_error "Still no staged changes"
        exit 1
      fi
    else
      echo
      gum style --$DIM_STYLE "Hint: Use 'git add <files>' to stage changes or use -i flag for interactive staging"
      exit 1
    fi
  fi
  
  # Get file list and diff in one go
  local staged_files=$(echo "$staged_status" | awk '{print $2}' | paste -sd' ' -)
  local file_count=$(echo "$staged_status" | wc -l | tr -d ' ')
  
  log_debug "Processing $file_count files: $staged_files"
  
  local staged_diff=$(git diff --cached)
  
  # Dry run mode
  if [[ "$dry_run" == "true" ]]; then
    local tokens=$(estimate_tokens "$staged_diff")
    gum style --border normal --padding "1 2" --border-foreground 14 --$INFO_STYLE \
      "Token estimate: $tokens (max: $MAX_TOKENS)
Diff size: ${#staged_diff} characters (max: $MAX_DIFF_SIZE)"
    exit 0
  fi
  
  # Check API key (skip for local mode)
  if [[ "$use_local" != "true" ]] || ! check_local_llm; then
    if ! get_api_key >/dev/null; then
      log_error "OpenAI API key not found"
      gum style --$DIM_STYLE "Get your API key from: https://platform.openai.com/api-keys"
      api_key=$(gum input --placeholder "Enter your OpenAI API key" --password --prompt.foreground="14")
      if [[ -z "$api_key" ]]; then
        log_error "API key is required"
        exit 1
      fi
      store_api_key "$api_key"
    fi
  fi
  
  # Generate commit message
  local commit_message=$(generate_commit_message "$staged_files" "$staged_diff" "$context" "$model" "$use_local")
  
  if [[ -z "$commit_message" ]]; then
    log_error "Failed to generate commit message"
    exit 1
  fi
  
  # Validate message
  if ! validate_commit_message "$commit_message"; then
    log_warning "Invalid format. Edit before committing."
  fi
  
  # Display generated message with formatting
  echo
  gum style --border rounded --padding "1 2" --border-foreground 10 --$HEADER_STYLE \
    "Generated message:" \
    "" \
    "$commit_message"
  
  # Preview mode - just display
  if [[ "$preview" == "true" ]]; then
    return 0
  fi
  
  # Interactive mode with gum
  while true; do
    echo
    local choice=$(gum choose \
      "$(gum style --foreground 10 '✓ Use this message')" \
      "$(gum style --foreground 11 '✏️  Edit message')" \
      "$(gum style --foreground 11 '🔄 Regenerate')" \
      "$(gum style --foreground 11 '➕ Add context')" \
      "$(gum style --foreground 14 '👁  View diff')" \
      "$(gum style --foreground 9 '✗ Cancel')" \
      --header "What would you like to do?" --cursor.foreground="13")
    
    case "$choice" in
      *"Use this message"*)
        # Commit with message
        if git commit -m "$commit_message"; then
          log_success "✨ Committed successfully!"
          # Show what was committed
          echo
          gum style --$DIM_STYLE "$(git log -1 --oneline)"
        else
          log_error "Commit failed"
          exit 1
        fi
        break
        ;;
      *"Edit message"*)
        # Edit message with gum
        commit_message=$(echo "$commit_message" | gum write --width 72 --height 10 --header "Edit commit message:" --header.foreground="14")
        
        # Re-validate
        if ! validate_commit_message "$commit_message"; then
          log_warning "Edited message doesn't match conventional format"
        fi
        
        echo
        gum style --border rounded --padding "1 2" --border-foreground 14 --$INFO_STYLE \
          "Updated message:" \
          "" \
          "$commit_message"
        ;;
      *"Regenerate"*)
        commit_message=$(generate_commit_message "$staged_files" "$staged_diff" "$context" "$model" "$use_local")
        if [[ -z "$commit_message" ]]; then
          log_error "Failed to regenerate message"
          continue
        fi
        echo
        gum style --border rounded --padding "1 2" --border-foreground 10 --$SUCCESS_STYLE \
          "New message:" \
          "" \
          "$commit_message"
        ;;
      *"Add context"*)
        new_context=$(gum input --placeholder "Enter additional context" --width 50 --prompt.foreground="14")
        context="${context:+$context. }$new_context"
        commit_message=$(generate_commit_message "$staged_files" "$staged_diff" "$context" "$model" "$use_local")
        if [[ -z "$commit_message" ]]; then
          log_error "Failed to regenerate message"
          continue
        fi
        echo
        gum style --border rounded --padding "1 2" --border-foreground 10 --$SUCCESS_STYLE \
          "New message with context:" \
          "" \
          "$commit_message"
        ;;
      *"View diff"*)
        # Show diff with gum pager
        git diff --cached --color=always | gum pager
        ;;
      *"Cancel"*)
        log_info "Commit cancelled"
        exit 0
        ;;
    esac
  done
}

# Check if gum is installed
if ! command -v gum &>/dev/null; then
  echo "Error: gum is not installed. Please install it first:"
  echo "  brew install gum  # macOS"
  echo "  # or see: https://github.com/charmbracelet/gum#installation"
  exit 1
fi

# Run main function
main "$@" || { echo "Script failed with exit code: $?" >&2; exit 1; }