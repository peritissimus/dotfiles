#!/bin/bash
# Exit on error
set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
NC='\033[0m' # No Color

# Logging utilities
log_header() {
  echo -e "${BOLD}${BLUE}⚡️ $1${NC}"
}

log_info() {
  echo -e "${CYAN}$1${NC}"
}

log_success() {
  echo -e "${GREEN}$1${NC}"
}

log_warning() {
  echo -e "${YELLOW}$1${NC}"
}

log_error() {
  echo -e "${RED}❌ $1${NC}"
}

log_debug() {
  echo -e "${DIM}${ITALIC} $1${NC}"
}

# Function to print fancy ASCII banner
print_banner() {
  echo -e "${BOLD}${CYAN}"
  cat <<"EOF"
 ░▒▓██████▓▒░ ░▒▓██████▓▒░░▒▓██████████████▓▒░  
░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ 
░▒▓█▓▒░      ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ 
░▒▓█▓▒▒▓███▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ 
░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ 
░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ 
 ░▒▓██████▓▒░ ░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ 
                                                
                                                
EOF
  echo -e "${NC}"
}

# Check if git repository exists
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  log_error "Not a git repository"
  exit 1
fi

# Function to check if LLM CLI is installed, install if not
check_llm() {
  if ! command -v llm &>/dev/null; then
    echo "LLM CLI is not installed. Installing now..."
    brew install llm || {
      echo "Error: Failed to install LLM CLI"
      exit 1
    }
  fi
}

check_openai_key() {
  # Check if the 'openai' key is set in the llm CLI
  if ! llm keys get openai &>/dev/null; then
    echo "OpenAI API key is not set in the llm CLI."
    read -p "Please enter your OpenAI API key: " openai_key
    # Set the 'openai' key in the llm CLI
    llm keys set openai --value "$openai_key"
    echo "OpenAI API key has been set in the llm CLI."
  fi
}

# Function to get project structure (respecting .gitignore)
get_project_structure() {
  git ls-files |
    while IFS= read -r file; do
      dirname "$file"
    done |
    sort -u |
    while IFS= read -r dir; do
      if [ "$dir" != "." ]; then
        depth=$(echo "$dir" | tr -cd '/' | wc -c)
        padding=$(printf '%*s' $((depth * 2)) '')
        echo "${padding}├── ${dir##*/}"
      fi
    done
}

# Function to get the primary language(s) of the project
get_project_languages() {
  git ls-files |
    while IFS= read -r file; do
      extension="${file##*.}"
      if [ "$extension" != "$file" ]; then
        echo "$extension"
      fi
    done |
    sort | uniq -c | sort -rn | head -5 |
    awk '{print $2}' | tr '\n' ',' | sed 's/,$//'
}

# Function to get staged files
get_staged_files() {
  git diff --cached --name-only
}

# Function to get staged changes
get_staged_changes() {
  git diff --cached
}

# Function to check if nx is available and get project graph
get_nx_graph() {
  if [ -f "nx.json" ]; then
    echo "Nx project detected, generating dependency graph..."
    nx graph --file=project-graph.json >/dev/null 2>&1
    if [ -f "project-graph.json" ]; then
      jq '{
        nodes: (
          .graph.nodes | to_entries | map({
            name: .value.name,
            type: .value.type
          })
        ),
        dependencies: (
          .graph.dependencies | to_entries | map({
            source: .key,
            targets: (.value | map(.target))
          })
        )
      }' project-graph.json >simplified-graph.json
      cat simplified-graph.json
      rm project-graph.json simplified-graph.json
    else
      echo "Failed to generate Nx project graph"
      return 1
    fi
  else
    echo "No Nx project detected"
    return 1
  fi
}

# Function to count tokens in prompt
count_tokens() {
  local input="$1"
  local word_count=$(echo "$input" | wc -w)
  local estimated_tokens=$(echo "scale=0; $word_count * 1.3 / 1" | bc)
  log_debug "\nEstimated tokens in prompt: $estimated_tokens"
}

# Function to generate commit message using LLM
generate_commit_message() {
  local files="$1"
  local diff="$2"
  local project_structure="$3"
  local project_languages="$4"
  local additional_context="$5"
  local model="$6"

  # Add context section to prompt if provided
  local context_section=""
  if [ -n "$additional_context" ]; then
    context_section="Additional Context: $additional_context\n\n"
  fi

  # Get Nx graph if available
  local nx_graph=$(get_nx_graph || echo "")
  local nx_section=""
  if [ -n "$nx_graph" ]; then
    nx_section="Project Graph:\n$nx_graph\n\n"
  fi

  local prompt="
Generate a concise and informative conventional commit message based on the changes provided. Follow the Conventional Commits specification strictly.
${context_section}${nx_section}
Commit Message Format: <type>(<scope>): <description>

Header Requirements:
- Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore
- Scope: (Optional) Area of codebase affected (e.g., auth, user-profile, api)
- Description: Lowercase, imperative mood, under 72 chars, no period, write about the change/diff

Body Requirements:
- Generate a body ONLY when:
  1. The changes affect multiple components or files in different areas
  2. There are breaking changes that need detailed explanation
  3. The changes introduce complex features that need clarification
  4. The commit fixes a bug that requires context about the root cause
  5. The changes involve important architectural decisions

- Body format:
  - Separate from header with a blank line
  - Wrap at 72 characters
  - Explain the what and why of changes, not the how
  - Use bullet points for multiple items
  - Reference issues/tickets where applicable

Breaking Changes:
- Option A: <type>(<scope>)!: <description>
- Option B: Add footer 'BREAKING CHANGE: <description>'
- Always include detailed explanation in body for breaking changes

Context:
Modified Files: ${files}
Project Languages: ${project_languages}
Project Structure:
${project_structure}
Changes:
\`\`\`diff
${diff}
\`\`\`
"
  echo "$prompt" | llm --no-stream -m "$model"
  count_tokens "$prompt"
}

# Function to print usage
print_usage() {
  echo "Usage: $0 [-p|--preview] [-c|--context \"context\"] [-m|--model MODEL]"
  echo
  echo "Options:"
  echo "  -p, --preview    Preview the commit message without creating a commit"
  echo "  -c, --context    Provide additional context to help generate a more accurate commit message"
  echo "  -m, --model      Specify the LLM model to use (default: gpt-4o-mini)"
  echo
  echo "Example:"
  echo "  $0 -c \"This change is part of the authentication refactoring sprint\""
  echo "  $0 -p -c \"Fixing bug reported in issue #123\""
  echo "  $0 -m gpt-4-1106-preview"
}

# Main script logic
main() {
  log_header "Git Commit Message Generator"
  check_llm
  check_openai_key
  local preview=false
  local context=""
  local model="gpt-4o-mini"

  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
    -p | --preview)
      preview=true
      shift
      ;;
    -c | --context)
      if [[ -z "$2" ]]; then
        log_error "--context requires an argument"
        print_usage
        exit 1
      fi
      context="$2"
      shift 2
      ;;
    -m | --model)
      if [[ -z "$2" ]]; then
        log_error "--model requires an argument"
        print_usage
        exit 1
      fi
      model="$2"
      shift 2
      ;;
    -h | --help)
      print_usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      print_usage
      exit 1
      ;;
    esac
  done

  staged_files=$(get_staged_files)
  if [ -z "$staged_files" ]; then
    log_error "No staged changes found. Stage your changes using 'git add' first."
    exit 1
  fi

  staged_diff=$(get_staged_changes)
  if [ -z "$staged_diff" ]; then
    log_error "No changes detected in staged files."
    exit 1
  fi

  log_info " Analyzing repository..."
  log_debug " ├─ Scanning project structure"
  project_structure=$(get_project_structure)
  log_debug " ├─ Detecting languages"
  project_languages=$(get_project_languages)
  log_debug " └─ Finding relevant documentation"

  commit_message=$(generate_commit_message "$staged_files" "$staged_diff" "$project_structure" "$project_languages" "$context" "$model")

  if [ "$preview" = true ]; then
    log_info "Preview of commit message:"
    echo -e "${YELLOW}${BOLD}$commit_message${NC}"
  else
    git commit -m "$commit_message"
    log_success "\nCommit created successfully!"
    echo -e "${DIM}$commit_message${NC}"
  fi
}

# Run the script
main "$@"
