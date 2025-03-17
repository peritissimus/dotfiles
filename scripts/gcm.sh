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
Generate a precise and meaningful conventional commit message strictly following the Conventional Commits specification (https://www.conventionalcommits.org/).
${context_section}${nx_section}
COMMIT STRUCTURE REQUIREMENTS:
1. HEADER (REQUIRED):
   <type>(<scope>): <description>
2. BODY (CONDITIONAL):
   [blank line]
   <body>
3. FOOTER (OPTIONAL for breaking changes):
   [blank line]
   BREAKING CHANGE: <description>
TYPE (REQUIRED) - Analyze the diff carefully to determine the most accurate type:
- feat: A new feature or functionality that didn't exist before. Look for new functions, components, API endpoints, or user-facing capabilities.
- fix: A bug fix addressing incorrect behavior. Look for condition corrections, edge case handling, or changes that restore intended functionality.
- docs: Documentation changes only. Look for updates to comments, README files, documentation files, or JSDoc/TSDoc annotations with no functional code changes.
- style: Formatting changes that don't affect code meaning. Look for whitespace, semicolon, indentation, or code style changes without logic modifications.
- refactor: Code restructuring without behavior changes. Look for method extractions, file reorganizations, or code simplifications that maintain the same functionality.
- perf: Performance improvements. Look for optimizations, algorithm improvements, caching mechanisms, or changes that make the code run faster.
- test: Changes to test files or testing infrastructure. Look for new tests, test fixes, or test infrastructure updates.
- build: Changes affecting build system or external dependencies. Look for package.json, webpack, gradle, or dependency version changes.
- ci: Changes to CI configuration. Look for updates to GitHub Actions, Jenkins, Travis, CircleCI files, or other CI pipeline configurations.
- chore: Other changes that don't modify src or test files. Look for maintenance tasks, tooling updates, or changes not fitting other categories.
SCOPE (RECOMMENDED):
- Specific component, module, or area affected (e.g., auth, api, ui)
- Use filename or directory when the scope is clear from the file context
- Use 'deps' for dependency updates
- Omit scope when changes affect multiple areas with no clear primary component
DESCRIPTION (REQUIRED):
- Use imperative, present tense (\"add\" not \"added\" or \"adds\")
- Start with lowercase
- No period at the end
- Keep under 72 characters
- Be specific about what changed, not why it changed
BODY (ONLY INCLUDE WHEN):
1. Changes affect multiple components requiring explanation of relationships
2. Complex implementation details need clarification
3. Breaking changes require migration instructions
4. Bug fixes should explain root cause and solution approach
5. Architectural decisions with significant impacts need justification
BREAKING CHANGES:
- Mark in header: <type>(<scope>)!: <description>
- AND/OR add footer: BREAKING CHANGE: <description with migration instructions>
Context Information:
Modified Files: ${files}
Project Languages: ${project_languages}
Project Structure:
${project_structure}
Changes:
\`\`\`diff
${diff}
\`\`\`
OUTPUT FORMAT:
- Return ONLY the commit message text
- Do not include any markdown tags or backticks in the output
- NEVER prefix with 'commit message:' or similar text
- Include body ONLY when the criteria above are met

WORKFLOW:
-Identify the change.
-Consider all the types of commit for the change and choose the most appropriate based on the definitions provied above.
-Revalidate the the selected type and move ahead with scope and description.
"
  echo "$prompt" | llm --no-stream -m "$model"
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
      print_banner
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
