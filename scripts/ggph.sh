#!/bin/bash

# Check if a repository path is provided
if [ -z "$1" ]; then
  echo "Usage: $0 /path/to/git/repo"
  exit 1
fi

REPO_PATH="$1"

# Check if the path is a valid Git repository
if ! [ -d "$REPO_PATH/.git" ]; then
  echo "Error: '$REPO_PATH' is not a Git repository"
  exit 1
fi

# Check if Gnuplot is installed
if ! command -v gnuplot >/dev/null 2>&1; then
  echo "Error: Gnuplot is not installed. Install it with 'brew install gnuplot'."
  exit 1
fi

# Change to the repository directory
cd "$REPO_PATH" || exit 1

# Temporary files for data
COMMITS_FILE="commits.dat"
LOC_FILE="loc.dat"

# --- Commits vs. Time ---
echo "Generating commits vs. time data..."
git log --pretty=format:'%ad' --date=short | sort | uniq -c | awk '{print $2 " " $1}' >"$COMMITS_FILE"

# Plot commits vs. time with Gnuplot (ASCII in terminal)
echo "Plotting commits vs. time..."
gnuplot <<EOF
set terminal dumb
set xdata time
set timefmt '%Y-%m-%d'
set format x '%Y-%m-%d'
set title 'Commits Over Time'
set xlabel 'Date'
set ylabel 'Number of Commits'
plot '$COMMITS_FILE' using 1:2 with lines title 'Commits'
EOF

# --- Lines of Code vs. Time ---
echo "Generating lines of code vs. time data..."
echo "Date Lines" >"$LOC_FILE"
# Store the current branch to return to it later
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
for commit in $(git rev-list --reverse HEAD); do
  git checkout -q "$commit"
  date=$(git show -s --format=%ci "$commit" | cut -d' ' -f1)
  # Count lines in all tracked files, ignoring errors (e.g., binary files)
  lines=$(git ls-files | xargs cat 2>/dev/null | wc -l | awk '{print $1}')
  echo "$date $lines" >>"$LOC_FILE"
done
# Return to the original branch
git checkout -q "$CURRENT_BRANCH"

# Plot lines of code vs. time with Gnuplot (ASCII in terminal)
echo "Plotting lines of code vs. time..."
gnuplot <<EOF
set terminal dumb
set xdata time
set timefmt '%Y-%m-%d'
set format x '%Y-%m-%d'
set title 'Lines of Code Over Time'
set xlabel 'Date'
set ylabel 'Lines of Code'
plot '$LOC_FILE' using 1:2 with lines title 'Lines'
EOF

# Clean up temporary files
rm -f "$COMMITS_FILE" "$LOC_FILE"

echo "Done!"
