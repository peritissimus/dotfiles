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
  echo -e "\n${BOLD}${BLUE}⚡️ $1${NC}\n"
}

log_info() {
  echo -e "${CYAN}ℹ️  $1${NC}"
}

log_success() {
  echo -e "${GREEN}✨ $1${NC}"
}

log_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
  echo -e "${RED}❌ $1${NC}"
}

log_debug() {
  echo -e "${DIM}${ITALIC}🔍 $1${NC}"
}

# Function to print fancy ASCII banner
print_banner() {
  echo -e "${BOLD}${CYAN}"
  cat <<"EOF"
 _____  _ _    _____                      _ _   
|   __>|_| |  |     |___ _____ _____ ___|_| |_ 
|   __>| | |  |   --| . |     |     | .'| |  _|
|__|  |_|_|  |_____|___|_|_|_|_|_|_|__,|_|_|  
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

# Function to get relevant documentation
get_relevant_docs() {
  local changed_files="$1"
  local docs=""

  for file in $changed_files; do
    dir=$(dirname "$file")
    while [ "$dir" != "." ] && [ "$dir" != "/" ]; do
      if [ -f "$dir/README.md" ]; then
        docs="$docs\nREADME from $dir:\n$(head -n 10 "$dir/README.md")"
      fi
      dir=$(dirname "$dir")
    done
  done

  echo "$docs"
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
      # Process with jq to get simplified graph
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
  # Rough estimation: split into words and multiply by 1.3 for safety
  local word_count=$(echo "$input" | wc -w)
  local estimated_tokens=$(echo "scale=0; $word_count * 1.3 / 1" | bc)
  echo "Estimated tokens in prompt: $estimated_tokens"
}

# Function to generate commit message using LLM
generate_commit_message() {
  local files="$1"
  local diff="$2"
  local project_structure="$3"
  local project_languages="$4"
  local additional_context="$5"

  # Add context section to prompt if provided
  local context_section=""
  if [ -n "$additional_context" ]; then
    context_section="**Additional Context Provided:**
$additional_context

"
  fi

  # Get Nx graph if available
  local nx_graph=$(get_nx_graph || echo "")
  local nx_section=""
  if [ -n "$nx_graph" ]; then
    nx_section="**Nx Project Graph:**
\`\`\`json
$nx_graph
\`\`\`

"
  fi

  local prompt="Generate a concise and informative conventional commit message based on the changes provided. Follow the Conventional Commits specification strictly.

${context_section}
${nx_section}

**Commit Message Requirements:**
1. **Format:** '<type>(<scope>): <description>'
   - **Types:** feat, fix, docs, style, refactor, perf, test, build, ci, chore
   - **Scope:** (Optional, but highly recommended) Indicate the area of the codebase affected (e.g., auth, user-profile, api). Infer from file paths and project structure.
   - **Description:**
     - Lowercase, imperative mood, under 72 chars, no period at the end. Briefly describe the change.

2. **Breaking Changes:** Indicate with either:
   - **Option A (Prefix):** '<type>(<scope>)!: <description>'
   - **Option B (Footer):** 'BREAKING CHANGE: <description>'
   - If '!' prefix is used, BREAKING CHANGE footer is optional for redundancy.

3. **Body (For changes affecting multiple files or requiring more detail):**
   - Blank line after the description.
   - List changed files with a brief explanation of changes per file if helpful for clarity.
   - Format: '* filename: Briefly describe the change in this file'
   - Keep lines under 72 chars, wrap text as needed.

**Context for Commit Message Generation:**
* **Modified Files:** ${files}
* **Diff:**
\`\`\`diff
${diff}
\`\`\`
* **Project Languages:** ${project_languages}
* **Project Structure:**
\`\`\`
${project_structure}
\`\`\`

**Instructions:**
- Analyze the provided diff and file changes to understand the *intent* of the changes.
- Infer the appropriate commit type and scope based on the context and changes.
- **Prioritize clarity and conciseness.**
- **Output ONLY the conventional commit message. Do not add any extra text, explanations, or markdown syntax.**

**Example Commit Messages (for inspiration):**
* \`feat(auth): implement password reset functionality\`
* \`fix(user-profile): correct display of user avatar on profile page\`
* \`refactor(api): extract common error handling logic\`
* \`docs: update README with installation instructions\`
* \`chore(deps): upgrade axios to latest version\`
* \`feat!: remove deprecated payment gateway (BREAKING CHANGE: Users must use the new payment gateway)\`
* \`ci(github): add node.js workflow for automated testing\`
* \`ci(jenkins): configure multi-stage pipeline for deployment\`
* \`ci(gitlab): setup container scanning in CI pipeline\`
* \`ci(actions): add caching for npm dependencies\`
* \`ci(azure): configure release pipeline for staging environment\`
* \`ci(circle): optimize test execution with parallel jobs\`"

  # Count tokens before sending to LLM
  count_tokens "$prompt"

  echo "$prompt" | llm --no-stream -m gpt-4o-mini
}

# Function to print usage
print_usage() {
  echo "Usage: $0 [--preview] [--context \"Additional context for the commit\"]"
  echo
  echo "Options:"
  echo "  --preview    Preview the commit message without creating a commit"
  echo "  --context    Provide additional context to help generate a more accurate commit message"
  echo
  echo "Example:"
  echo "  $0 --context \"This change is part of the authentication refactoring sprint\""
  echo "  $0 --preview --context \"Fixing bug reported in issue #123\""
}

# Main script logic
main() {

  log_header "Git Commit Message Generator"
  check_llm
  check_openai_key
  local preview=false
  local context=""

  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
    -p | --preview)
      preview=true
      shift
      ;;
    -c | --context)
      if [[ -z "$2" ]]; then
        echo "Error: --context requires an argument"
        print_usage
        exit 1
      fi
      context="$2"
      shift 2
      ;;
    -h | --help)
      print_banner
      print_usage
      exit 0
      ;;
    *)
      echo "Error: Unknown option $1"
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

  log_info "Analyzing repository..."
  log_debug "├─ Scanning project structure"
  project_structure=$(get_project_structure)
  log_debug "├─ Detecting languages"
  project_languages=$(get_project_languages)
  log_debug "└─ Finding relevant documentation"
  relevant_docs=$(get_relevant_docs "$staged_files")

  log_header "Generating Commit Message"
  commit_message=$(generate_commit_message "$staged_files" "$staged_diff" "$project_structure" "$project_languages" "$context")

  if [ "$preview" = true ]; then
    log_info "Preview of commit message:"
    echo -e "${CYAN}${BOLD}$commit_message${NC}"
  else
    git commit -m "$commit_message"
    log_success "Commit created successfully! 🎉"
    echo -e "${DIM}$commit_message${NC}"
  fi
}

# Run the script
main "$@"
