#!/usr/bin/env bash

# Script to create embeddings of a project using LLM CLI, respecting .gitignore
# Usage: ./create_embeddings.sh <project_path>

set -e

# Check if a project path was provided
if [ $# -ne 1 ]; then
  echo "Usage: $0 <project_path>"
  exit 1
fi

PROJECT_PATH="$1"
KAZE_DIR="${PROJECT_PATH}/.kaze"
DB_PATH="${KAZE_DIR}/embeddings.db"

# Check if the project path exists
if [ ! -d "$PROJECT_PATH" ]; then
  echo "Error: Project directory '$PROJECT_PATH' does not exist."
  exit 1
fi

# Create .kaze directory if it doesn't exist
mkdir -p "$KAZE_DIR"

echo "🔍 Processing files in $PROJECT_PATH..."
echo "💾 Embeddings will be saved to $DB_PATH"

# Check if .gitignore exists
GITIGNORE_PATH="${PROJECT_PATH}/.gitignore"
GITIGNORE_CMD=""

if [ -f "$GITIGNORE_PATH" ]; then
  echo "📋 Found .gitignore - will respect exclusion patterns"

  # Create a temporary file with patterns to exclude
  TEMP_EXCLUDE=$(mktemp)

  # Add standard git patterns
  cat "$GITIGNORE_PATH" >"$TEMP_EXCLUDE"

  # Always exclude .git directory and .kaze directory
  echo ".git/" >>"$TEMP_EXCLUDE"
  echo ".kaze/" >>"$TEMP_EXCLUDE"

  # Build command to respect gitignore
  GITIGNORE_CMD="--exclude-patterns-file $TEMP_EXCLUDE"
else
  echo "⚠️ No .gitignore found - will only exclude .git and .kaze directories"

  # Create minimal exclusion patterns
  TEMP_EXCLUDE=$(mktemp)
  echo ".git/" >>"$TEMP_EXCLUDE"
  echo ".kaze/" >>"$TEMP_EXCLUDE"

  GITIGNORE_CMD="--exclude-patterns-file $TEMP_EXCLUDE"
fi

# Run the LLM CLI command to create embeddings
echo "🧠 Generating embeddings..."
llm embed files "$PROJECT_PATH" \
  $GITIGNORE_CMD \
  --recursive \
  --output-db "$DB_PATH" \
  --batch-size 10

# Clean up temporary files
if [ -f "$TEMP_EXCLUDE" ]; then
  rm "$TEMP_EXCLUDE"
fi

# Check if the database was created successfully
if [ -f "$DB_PATH" ]; then
  echo "✅ Embeddings successfully created and saved to $DB_PATH"
  echo "🔢 Database size: $(du -h "$DB_PATH" | cut -f1)"
else
  echo "❌ Error: Failed to create embeddings database"
  exit 1
fi

echo "🎉 All done!"
