#!/bin/bash
# Git Commit Message Generator - Improved Version
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

# Detect terminal capabilities
if [[ -t 1 ]] && [[ -n "$TERM" ]] && [[ "$TERM" != "dumb" ]]; then
  readonly INTERACTIVE=true
else
  readonly INTERACTIVE=false
fi

# ANSI color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly YELLOW='\033[1;33m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

# Logging utilities
log_info() { echo -e "${CYAN}ℹ ${NC}$1"; }
log_success() { echo -e "${GREEN}✓ ${NC}$1"; }
log_warning() { echo -e "${YELLOW}⚠ ${NC}$1"; }
log_error() { echo -e "${RED}✗ ${NC}$1" >&2; }
log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo -e "${DIM}  $1${NC}" >&2; }

# Progress indicator
show_spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='⣾⣽⣻⢿⡿⣟⣯⣷'
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

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
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
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

# Function to generate commit message
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
    local result=$(echo "$prompt" | ollama run codellama --quiet 2>/dev/null || echo "")
    if [[ -n "$result" ]]; then
      echo "$result"
      return 0
    fi
    log_warning "Local LLM failed, falling back to API"
  fi
  
  # Call remote LLM
  if command -v llm &>/dev/null; then
    echo "$prompt" | llm -m "$model" --no-stream 2>/dev/null
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

# Main function
main() {
  # Debug
  [[ "${DEBUG:-0}" == "1" ]] && echo "DEBUG: Starting main function" >&2
  
  # Check git repository
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    log_error "Not a git repository"
    exit 1
  fi
  
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
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      -p|--preview) preview=true; shift ;;
      -c|--context) context="$2"; shift 2 ;;
      -m|--model) model="$2"; shift 2 ;;
      -d|--dry-run) dry_run=true; shift ;;
      -l|--local) use_local=true; shift ;;
      --clear-cache) clear_cache=true; shift ;;
      --init-config)
        create_sample_config "${2:-.gcmrc}"
        exit 0
        ;;
      -h|--help) 
        echo "Usage: $0 [OPTIONS]"
        echo "Options:"
        echo "  -p, --preview     Preview without committing"
        echo "  -c, --context     Additional context"
        echo "  -m, --model       LLM model (default: $DEFAULT_MODEL)"
        echo "  -d, --dry-run     Show token count without API call"
        echo "  -l, --local       Try local LLM first (requires Ollama)"
        echo "  --clear-cache     Clear all cached data"
        echo "  --init-config     Create a sample .gcmrc file"
        echo ""
        echo "Config locations (in order of precedence):"
        echo "  1. .gcmrc (current directory)"
        echo "  2. ~/.gcmrc"
        echo "  3. ~/.config/gcm/config"
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
  
  # Check for staged changes (use name-status for more info)
  local staged_status=$(git diff --cached --name-status)
  if [[ -z "$staged_status" ]]; then
    log_error "No staged changes found"
    echo -e "\n${DIM}Hint: Use 'git add <files>' to stage changes${NC}"
    exit 1
  fi
  
  # Get file list and diff in one go
  local staged_files=$(echo "$staged_status" | awk '{print $2}' | paste -sd' ' -)
  local file_count=$(echo "$staged_status" | wc -l | tr -d ' ')
  
  log_debug "Processing $file_count files: $staged_files"
  
  local staged_diff=$(git diff --cached)
  
  # Dry run mode
  if [[ "$dry_run" == "true" ]]; then
    local tokens=$(estimate_tokens "$staged_diff")
    log_info "Estimated tokens: $tokens (max: $MAX_TOKENS)"
    log_info "Diff size: ${#staged_diff} characters (max: $MAX_DIFF_SIZE)"
    exit 0
  fi
  
  # Check API key (skip for local mode)
  if [[ "$use_local" != "true" ]] || ! check_local_llm; then
    if ! get_api_key >/dev/null; then
      log_error "OpenAI API key not found"
      echo -e "${DIM}Get your API key from: https://platform.openai.com/api-keys${NC}"
      read -s -p "Enter your OpenAI API key: " api_key
      echo
      if [[ -z "$api_key" ]]; then
        log_error "API key is required"
        exit 1
      fi
      store_api_key "$api_key"
    fi
  fi
  
  # Generate commit message
  log_info "Generating commit message..."
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
  echo -e "\n${BOLD}Generated message:${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo "$commit_message"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  # Preview mode - just display
  if [[ "$preview" == "true" ]]; then
    return 0
  fi
  
  # Interactive mode
  while true; do
    echo -e "\n${CYAN}Options:${NC}"
    echo -e "  ${GREEN}[Y]es${NC} - Use this message"
    echo -e "  ${YELLOW}[e]dit${NC} - Edit in ${EDITOR:-vi}"
    echo -e "  ${YELLOW}[r]egenerate${NC} - Generate new message"
    echo -e "  ${YELLOW}[a]dd context${NC} - Add context and regenerate"
    echo -e "  ${RED}[n]o/cancel${NC} - Cancel commit"
    
    printf "\nYour choice [Y/e/r/a/n]: "
    read -r REPLY
    
    # Convert to lowercase using tr
    REPLY=$(echo "$REPLY" | tr '[:upper:]' '[:lower:]')
    
    case "$REPLY" in
      y|yes|"")
        # Commit with message
        if git commit -m "$commit_message"; then
          log_success "\n✨ Committed successfully!"
          # Show what was committed
          echo -e "\n${DIM}$(git log -1 --oneline)${NC}"
        else
          log_error "Commit failed"
          exit 1
        fi
        break
        ;;
      e|edit)
        # Edit message
        tmpfile=$(mktemp)
        echo "$commit_message" > "$tmpfile"
        ${EDITOR:-vi} "$tmpfile"
        commit_message=$(cat "$tmpfile")
        rm -f "$tmpfile"
        
        # Re-validate
        if ! validate_commit_message "$commit_message"; then
          log_warning "Edited message doesn't match conventional format"
        fi
        
        echo -e "\n${BOLD}Updated message:${NC}"
        echo "$commit_message"
        ;;
      r|regenerate)
        log_info "Regenerating commit message..."
        commit_message=$(generate_commit_message "$staged_files" "$staged_diff" "$context" "$model" "$use_local")
        if [[ -z "$commit_message" ]]; then
          log_error "Failed to regenerate message"
          continue
        fi
        echo -e "\n${BOLD}New message:${NC}"
        echo "$commit_message"
        ;;
      a|add)
        read -p "Additional context: " new_context
        context="${context:+$context. }$new_context"
        log_info "Regenerating with context..."
        commit_message=$(generate_commit_message "$staged_files" "$staged_diff" "$context" "$model" "$use_local")
        if [[ -z "$commit_message" ]]; then
          log_error "Failed to regenerate message"
          continue
        fi
        echo -e "\n${BOLD}New message with context:${NC}"
        echo "$commit_message"
        ;;
      n|no|cancel)
        log_info "Commit cancelled"
        exit 0
        ;;
      *)
        log_warning "Invalid option. Please choose Y/e/r/a/n"
        ;;
    esac
  done
}

# Run main function
main "$@" || { echo "Script failed with exit code: $?" >&2; exit 1; }
