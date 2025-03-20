#!/bin/bash

# Set your GitHub username
USERNAME="zocakushal"

# Set the projects directory
PROJECTS_DIR="/Users/peritissimus/projects"

# Calculate yesterday's date in YYYY-MM-DD format
YESTERDAY=$(date -v-1d +%Y-%m-%d)

echo "📊 Work Summary for $USERNAME on $YESTERDAY"
echo "=================================================="

# Function to check commits in a repository
check_repo_commits() {
  local repo_path=$1
  local repo_name=$(basename "$repo_path")

  cd "$repo_path"

  # Get all unique commits from yesterday by the specified user across all branches
  local unique_commits=$(git log --author="$USERNAME" --since="$YESTERDAY 00:00" --until="$YESTERDAY 23:59" --all --format="%h|%s" | sort -u)

  if [ -n "$unique_commits" ]; then
    echo -e "\n📁 $repo_name"
    echo "-------------------"

    # Output unique commits
    echo "$unique_commits" | while IFS='|' read -r hash message; do
      echo "  • ${hash}: ${message}"
    done

    return 0
  else
    return 1
  fi
}

# Initialize counters
TOTAL_REPOS=0
REPOS_WITH_COMMITS=0
TOTAL_COMMITS=0

# Process each project directory
for project in "$PROJECTS_DIR"/*; do
  if [ -d "$project/.git" ]; then
    TOTAL_REPOS=$((TOTAL_REPOS + 1))

    if check_repo_commits "$project"; then
      REPOS_WITH_COMMITS=$((REPOS_WITH_COMMITS + 1))
      # Count unique commits in this repo
      cd "$project"
      repo_commits=$(git log --author="$USERNAME" --since="$YESTERDAY 00:00" --until="$YESTERDAY 23:59" --all --format="%H %s" | sort -u | wc -l)
      TOTAL_COMMITS=$((TOTAL_COMMITS + repo_commits))
    fi
  fi
done

echo -e "\n📊 Summary"
echo "-------------------"
echo "Projects checked: $TOTAL_REPOS"
echo "Projects with activity: $REPOS_WITH_COMMITS"
echo "Total commits: $TOTAL_COMMITS"
echo -e "\nReport generated on $(date)"
