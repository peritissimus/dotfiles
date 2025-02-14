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
  local prompt="Generate a concise and informative conventional commit message based on the changes provided. Follow the Conventional Commits specification strictly.

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
* \`feat!: remove deprecated payment gateway (BREAKING CHANGE: Users must use the new payment gateway)\`"

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
