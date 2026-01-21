#!/opt/homebrew/bin/bash
# gcm.sh - Git Commit Message Generator using LLM
# Requires: bash 4+, llm CLI, git

# Bootstrap bash-oo-framework
source "$( cd "${BASH_SOURCE[0]%/*}" && pwd )/lib/oo-bootstrap.sh"

import util/exception util/tryCatch UI/Color

#################
### NAMESPACE ###
#################

namespace gcm

#################
### CONSTANTS ###
#################

readonly VERSION="2.0.0"
readonly DEFAULT_MODEL="gpt-4o-mini"

###############
### HELPERS ###
###############

# Logging with colors
log_header() {
  echo -e "$(UI.Color.Bold)$(UI.Color.Blue)⚡️ $1$(UI.Color.Default)"
}

log_info() {
  echo -e "$(UI.Color.Cyan)$1$(UI.Color.Default)"
}

log_success() {
  echo -e "$(UI.Color.Green)$1$(UI.Color.Default)"
}

log_warning() {
  echo -e "$(UI.Color.Yellow)$1$(UI.Color.Default)"
}

log_error() {
  echo -e "$(UI.Color.Red)❌ $1$(UI.Color.Default)"
}

log_debug() {
  echo -e "$(UI.Color.DarkGray) $1$(UI.Color.Default)"
}

# Print fancy ASCII banner
print_banner() {
  echo -e "$(UI.Color.Bold)$(UI.Color.Cyan)"
  cat <<'EOF'
 ░▒▓██████▓▒░ ░▒▓██████▓▒░░▒▓██████████████▓▒░
░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
░▒▓█▓▒░      ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
░▒▓█▓▒▒▓███▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
 ░▒▓██████▓▒░ ░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░

EOF
  echo -e "$(UI.Color.Default)"
}

# Check if LLM CLI is installed
check_llm() {
  if ! command -v llm &>/dev/null; then
    log_info "LLM CLI is not installed. Installing now..."
    brew install llm || {
      e="Failed to install LLM CLI" throw
    }
  fi
}

# Check if OpenAI API key is set
check_openai_key() {
  if ! llm keys get openai &>/dev/null; then
    log_warning "OpenAI API key is not set in the llm CLI."
    read -p "Please enter your OpenAI API key: " openai_key
    llm keys set openai --value "$openai_key"
    log_success "OpenAI API key has been set in the llm CLI."
  fi
}

# Get project structure (respecting .gitignore)
get_project_structure() {
  git ls-files |
    while IFS= read -r file; do
      dirname "$file"
    done |
    sort -u |
    while IFS= read -r dir; do
      if [[ "$dir" != "." ]]; then
        depth=$(echo "$dir" | tr -cd '/' | wc -c)
        padding=$(printf '%*s' $((depth * 2)) '')
        echo "${padding}├── ${dir##*/}"
      fi
    done
}

# Get primary language(s) of the project
get_project_languages() {
  git ls-files |
    while IFS= read -r file; do
      extension="${file##*.}"
      if [[ "$extension" != "$file" ]]; then
        echo "$extension"
      fi
    done |
    sort | uniq -c | sort -rn | head -5 |
    awk '{print $2}' | tr '\n' ',' | sed 's/,$//'
}

# Get staged files
get_staged_files() {
  git diff --cached --name-only
}

# Get staged changes
get_staged_changes() {
  git diff --cached
}

# Get Nx project graph if available
get_nx_graph() {
  if [[ -f "nx.json" ]]; then
    log_info "Nx project detected, generating dependency graph..."
    nx graph --file=project-graph.json >/dev/null 2>&1
    if [[ -f "project-graph.json" ]]; then
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
      return 1
    fi
  else
    return 1
  fi
}

#############################
### COMMIT MESSAGE PROMPT ###
#############################

generate_commit_message() {
  local files="$1"
  local diff="$2"
  local project_structure="$3"
  local project_languages="$4"
  local additional_context="$5"
  local model="$6"

  # Add context section to prompt if provided
  local context_section=""
  if [[ -n "$additional_context" ]]; then
    context_section="Additional Context: $additional_context\n\n"
  fi

  # Get Nx graph if available
  local nx_graph
  nx_graph=$(get_nx_graph 2>/dev/null || echo "")
  local nx_section=""
  if [[ -n "$nx_graph" ]]; then
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
- feat: A new feature or functionality that didn't exist before
- fix: A bug fix addressing incorrect behavior
- docs: Documentation changes only
- style: Formatting changes that don't affect code meaning
- refactor: Code restructuring without behavior changes
- perf: Performance improvements
- test: Changes to test files or testing infrastructure
- build: Changes affecting build system or external dependencies
- ci: Changes to CI configuration
- chore: Other changes that don't modify src or test files

SCOPE (RECOMMENDED):
- Specific component, module, or area affected
- Use filename or directory when the scope is clear
- Omit scope when changes affect multiple areas

DESCRIPTION (REQUIRED):
- Use imperative, present tense (\"add\" not \"added\")
- Start with lowercase
- No period at the end
- Keep under 72 characters

BODY (ONLY INCLUDE WHEN):
1. Changes affect multiple components requiring explanation
2. Complex implementation details need clarification
3. Breaking changes require migration instructions
4. Bug fixes should explain root cause and solution

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
- Do not include any markdown tags or backticks
- Include body ONLY when criteria above are met
"
  echo "$prompt" | llm --no-stream -m "$model"
}

################
### COMMANDS ###
################

print_usage() {
  echo "Usage: $0 [-p|--preview] [-c|--context \"context\"] [-m|--model MODEL]"
  echo
  echo "Options:"
  echo "  -p, --preview    Preview the commit message without creating a commit"
  echo "  -c, --context    Provide additional context for the commit message"
  echo "  -m, --model      Specify the LLM model to use (default: $DEFAULT_MODEL)"
  echo "  -h, --help       Show this help message"
  echo
  echo "Examples:"
  echo "  $0 -c \"This change is part of the auth refactoring\""
  echo "  $0 -p -c \"Fixing bug from issue #123\""
  echo "  $0 -m gpt-4o"
}

##############
### MAIN  ###
##############

main() {
  log_header "Git Commit Message Generator v${VERSION}"

  # Check if we're in a git repository
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log_error "Not a git repository"
    exit 1
  fi

  check_llm
  check_openai_key

  local preview=false
  local context=""
  local model="$DEFAULT_MODEL"

  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -p|--preview)
        preview=true
        shift
        ;;
      -c|--context)
        if [[ -z "$2" ]]; then
          log_error "--context requires an argument"
          print_usage
          exit 1
        fi
        context="$2"
        shift 2
        ;;
      -m|--model)
        if [[ -z "$2" ]]; then
          log_error "--model requires an argument"
          print_usage
          exit 1
        fi
        model="$2"
        shift 2
        ;;
      -h|--help)
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

  # Check for staged changes
  local staged_files
  staged_files=$(get_staged_files)
  if [[ -z "$staged_files" ]]; then
    log_error "No staged changes found. Stage your changes using 'git add' first."
    exit 1
  fi

  local staged_diff
  staged_diff=$(get_staged_changes)
  if [[ -z "$staged_diff" ]]; then
    log_error "No changes detected in staged files."
    exit 1
  fi

  log_info " Analyzing repository..."
  log_debug " ├─ Scanning project structure"
  local project_structure
  project_structure=$(get_project_structure)

  log_debug " ├─ Detecting languages"
  local project_languages
  project_languages=$(get_project_languages)

  log_debug " └─ Generating commit message"

  local commit_message
  commit_message=$(generate_commit_message "$staged_files" "$staged_diff" "$project_structure" "$project_languages" "$context" "$model")

  if [[ "$preview" == true ]]; then
    log_info "Preview of commit message:"
    echo -e "$(UI.Color.Yellow)$(UI.Color.Bold)$commit_message$(UI.Color.Default)"
  else
    git commit -m "$commit_message" -n
    log_success "\nCommit created successfully!"
    echo -e "$(UI.Color.DarkGray)$commit_message$(UI.Color.Default)"
  fi
}

# Run the script
main "$@"
