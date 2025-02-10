#!/bin/bash
# Exit on error
set -e

# Check if git repository exists
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: Not a git repository"
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
  else
    echo "..."
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

# Function to generate commit message using LLM
generate_commit_message() {
  local files="$1"
  local diff="$2"
  local project_structure="$3"
  local project_languages="$4"

  local prompt="Analyze these changes and generate a conventional commit message following the spec exactly.

Commit Types:
- feat: New features
- fix: Bug fixes
- docs: Documentation only
- style: Changes not affecting code
- refactor: Code changes neither fixing bugs nor adding features
- perf: Performance improvements
- test: Adding/updating tests
- build: Build system or dependencies
- ci: CI configuration
- chore: Maintenance tasks

Requirements:
- Format: <type>[optional scope]: <description>
- Use imperative mood
- Description under 72 chars
- No period at end
- Add '!' before ':' for breaking changes
- Add 'BREAKING CHANGE: <description>' in footer for breaking changes
- Dont add markdown syntax

Changes to analyze:
Files modified:
$files

Diff:
$diff

Project context:
Languages: $project_languages
Structure:
$project_structure

Output ONLY the commit message, nothing else."

  echo "$prompt" | llm --no-stream -m gpt-4o-mini
}

# Main script logic
main() {
  check_llm
  check_openai_key

  staged_files=$(get_staged_files)
  if [ -z "$staged_files" ]; then
    echo "No staged changes found. Stage your changes using 'git add' first."
    exit 1
  fi

  staged_diff=$(get_staged_changes)
  if [ -z "$staged_diff" ]; then
    echo "No changes detected in staged files."
    exit 1
  fi

  echo "Analyzing project structure..."
  project_structure=$(get_project_structure)
  project_languages=$(get_project_languages)
  relevant_docs=$(get_relevant_docs "$staged_files")

  echo "Generating commit message..."
  commit_message=$(generate_commit_message "$staged_files" "$staged_diff" "$project_structure" "$project_languages" "$relevant_docs")

  if [ "$1" = "--preview" ]; then
    echo "Preview of commit message:"
    echo "$commit_message"
  else
    git commit -m "$commit_message"
    echo "Successfully created commit: $commit_message"
  fi
}

# Run the script
main "$@"
