#!/usr/bin/env bash

# kaze.sh - Unified tool for creating and querying embeddings for project files
# Version: 1.0.0

# DEFAULTS {{{
set -e

# Colors for better formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default settings
MODEL="text-embedding-3-small"
MAX_FILE_SIZE=8 # in KB
BATCH_SIZE=10
DEFAULT_COLLECTION="files"
# }}}

# HELP MESSAGE {{{
show_help() {
  echo -e "${BLUE}kaze.sh${NC} - Unified tool for creating and querying embeddings for project files"
  echo
  echo -e "${GREEN}Usage:${NC}"
  echo "  $0 [command] [options] <project_path>"
  echo
  echo -e "${GREEN}Commands:${NC}"
  echo "  create      Create embeddings for files in the project (default if no command specified)"
  echo "  query       Search for similar content across project files (returns JSON by default)"
  echo "  list        List files in the embeddings database"
  echo "  info        Show information about the embeddings database"
  echo
  echo -e "${GREEN}Common Options:${NC}"
  echo "  -h, --help         Show this help message and exit"
  echo "  -d, --dir DIR      Project directory (default: current directory)"
  echo "  -o, --output DIR   Output directory (default: .kaze in project directory)"
  echo
  echo -e "${GREEN}Create Options:${NC}"
  echo "  -m, --model MODEL     Embedding model to use (default: $MODEL)"
  echo "  -s, --size SIZE       Maximum file size in KB (default: $MAX_FILE_SIZE)"
  echo "  -b, --batch BATCH     Batch size for processing (default: $BATCH_SIZE)"
  echo "  -c, --collection NAME Collection name (default: $DEFAULT_COLLECTION)"
  echo "  -f, --force           Force recreation of embeddings database"
  echo "  --include PATTERN     Additional files to include (glob pattern)"
  echo "  --exclude PATTERN     Additional files to exclude (glob pattern)"
  echo
  echo -e "${GREEN}Query Options:${NC}"
  echo "  -q, --query TEXT      Text to search for"
  echo "  -n, --limit NUM       Maximum number of results (default: 10)"
  echo "  -t, --threshold FLOAT Similarity threshold (0.0-1.0, default: 0.2)"
  echo "  -c, --collection NAME Collection to search in (default: $DEFAULT_COLLECTION)"
  echo "  --show-content        Show file content in results"
  echo "  --human               Display human-readable output instead of JSON"
  echo
  echo -e "${GREEN}List Options:${NC}"
  echo "  -p, --pattern PATTERN File pattern to list (default: *)"
  echo "  -c, --collection NAME Collection to list from (default: $DEFAULT_COLLECTION)"
  echo
  echo -e "${GREEN}Examples:${NC}"
  echo "  $0 create -d ~/myproject                # Create embeddings for all files in ~/myproject"
  echo "  $0 query -q \"database connection\" -n 5   # Find top 5 files related to database connections (JSON)"
  echo "  $0 query -q \"database connection\" --human # Same search with human-readable output"
  echo "  $0 list -p \"*.js\"                        # List all JavaScript files in the database"
  echo "  $0 info                                  # Show database information"
}
# }}}

# HELPER METHODS {{{
# Check if LLM CLI is installed
check_llm_cli() {
  if ! command -v llm &>/dev/null; then
    echo -e "${RED}Error: llm command not found.${NC}" >&2
    echo "Please install LLM CLI tool by running: pip install llm" >&2
    exit 1
  fi
}

# Check if sqlite3 is installed
check_sqlite() {
  if ! command -v sqlite3 &>/dev/null; then
    echo -e "${RED}Error: sqlite3 command not found.${NC}" >&2
    echo "Please install SQLite to use this script." >&2
    exit 1
  fi
}

# Set up the project paths
setup_paths() {
  local project_dir="$1"

  # Check if the project directory exists
  if [ ! -d "$project_dir" ]; then
    echo -e "${RED}Error: Project directory '$project_dir' does not exist.${NC}" >&2
    exit 1
  fi
  # Set up the output directory
  if [ -z "$OUTPUT_DIR" ]; then
    KAZE_DIR="${project_dir}/.kaze"
  else
    KAZE_DIR="${OUTPUT_DIR}"
  fi

  # Create output directory if it doesn't exist
  mkdir -p "$KAZE_DIR"

  # Set the database path
  DB_PATH="${KAZE_DIR}/embeddings.db"
}

# Function to check if a file should be processed (based on size and type)
should_process_file() {
  local file="$1"

  echo -e "${BLUE}🔍 DEBUG: should_process_file checking: ${CYAN}$file${NC}" >&2

  # Skip if file doesn't exist
  if [[ ! -f "$file" ]]; then
    echo -e "${BLUE}🔍 DEBUG: File doesn't exist: ${CYAN}$file${NC}" >&2
    return 1
  fi

  # Skip if file is not readable
  if [[ ! -r "$file" ]]; then
    echo -e "${BLUE}🔍 DEBUG: File not readable: ${CYAN}$file${NC}" >&2
    return 1
  fi

  # Skip files that are too large
  local file_size=$(du -k "$file" 2>/dev/null | cut -f1)
  if [[ -z "$file_size" ]]; then
    echo -e "${BLUE}🔍 DEBUG: Couldn't determine file size: ${CYAN}$file${NC}" >&2
    return 1
  fi

  if [[ "$file_size" -gt $MAX_FILE_SIZE ]]; then
    echo -e "${BLUE}🔍 DEBUG: File too large (${CYAN}${file_size}KB${BLUE}): ${CYAN}$file${NC}" >&2
    return 1
  fi

  # Check if file appears to be a text file
  if file "$file" 2>/dev/null | grep -i -E "text|ascii|utf-8|empty" >/dev/null; then
    echo -e "${BLUE}🔍 DEBUG: File identified as text: ${CYAN}$file${NC}" >&2
    return 0
  fi

  # Check file extension for common text formats
  if [[ "$file" =~ \.(txt|md|js|py|html|css|json|yaml|yml|xml|csv|sh|bash|conf|cfg|ini|rs|go|java|c|cpp|h|hpp|jsx|tsx|vue|rb|php|sql|swift|kt|scala|ts)$ ]]; then
    echo -e "${BLUE}🔍 DEBUG: File has recognized text extension: ${CYAN}$file${NC}" >&2
    return 0
  fi

  echo -e "${BLUE}🔍 DEBUG: File rejected, not a recognized text type: ${CYAN}$file${NC}" >&2
  return 1
}

# Function to get the list of files to process
get_file_list() {
  local PROJECT_PATH="$1"
  local TEMP_DIR="$2"
  local FILE_LIST="${TEMP_DIR}/files_to_process.txt"
  local FILTERED_LIST="${TEMP_DIR}/filtered_files.txt"

  echo -e "${BLUE}🔍 DEBUG: Project path: ${CYAN}$PROJECT_PATH${NC}" >&2
  echo -e "${BLUE}🔍 DEBUG: Temp directory: ${CYAN}$TEMP_DIR${NC}" >&2
  echo -e "${BLUE}🔍 DEBUG: File list path: ${CYAN}$FILE_LIST${NC}" >&2

  # Make sure the temp directory exists
  mkdir -p "$TEMP_DIR"
  echo -e "${BLUE}🔍 DEBUG: Created temp directory${NC}" >&2

  # Make sure the filtered list exists
  touch "$FILE_LIST"
  touch "$FILTERED_LIST"
  echo -e "${BLUE}🔍 DEBUG: Created empty file lists${NC}" >&2

  # Determine if we should use git for file listing
  if [ -f "${PROJECT_PATH}/.gitignore" ] && [ -d "${PROJECT_PATH}/.git" ]; then
    echo -e "${BLUE}📋 Found ${YELLOW}.gitignore${BLUE} in git repository - will respect exclusion patterns${NC}" >&2
    echo -e "${BLUE}🔍 DEBUG: Using git to list files${NC}" >&2

    # Change to the project directory to use git commands
    pushd "$PROJECT_PATH" >/dev/null
    echo -e "${BLUE}🔍 DEBUG: Changed to project directory${NC}" >&2

    # Get list of files using git commands (respects .gitignore automatically)
    echo -e "${BLUE}🔍 DEBUG: Running git ls-files${NC}" >&2
    git ls-files >"$FILE_LIST" 2>/dev/null || true
    echo -e "${BLUE}🔍 DEBUG: Running git ls-files --others${NC}" >&2
    git ls-files --others --exclude-standard >>"$FILE_LIST" 2>/dev/null || true

    # Include additional files if specified
    if [ -n "$INCLUDE_PATTERN" ]; then
      echo -e "${BLUE}🔍 Adding files matching pattern: ${YELLOW}$INCLUDE_PATTERN${NC}" >&2
      echo -e "${BLUE}🔍 DEBUG: Running additional find for include pattern${NC}" >&2
      find . -type f -name "$INCLUDE_PATTERN" | grep -v "^\./\.git/" >>"$FILE_LIST" || true
    fi

    # Return to original directory
    popd >/dev/null
  else
    # If not a git repository or no .gitignore, use find
    if [ -f "${PROJECT_PATH}/.gitignore" ]; then
      echo -e "${BLUE}📋 Found ${YELLOW}.gitignore${BLUE} but not a git repository - using basic exclusions${NC}" >&2
    else
      echo -e "${YELLOW}⚠️ No .gitignore found - using basic exclusions${NC}" >&2
    fi
    echo -e "${BLUE}🔍 DEBUG: Using find command to list files${NC}" >&2

    # Build the find command with exclusions
    local FIND_CMD="find \"$PROJECT_PATH\" -type f"
    echo -e "${BLUE}🔍 DEBUG: Base find command: ${CYAN}$FIND_CMD${NC}" >&2

    FIND_CMD="$FIND_CMD ! -path \"*/\\.git/*\""
    FIND_CMD="$FIND_CMD ! -path \"*/\\.kaze/*\""
    FIND_CMD="$FIND_CMD ! -path \"*/node_modules/*\""
    FIND_CMD="$FIND_CMD ! -path \"*/\\.DS_Store\""
    FIND_CMD="$FIND_CMD ! -path \"*/build/*\""
    FIND_CMD="$FIND_CMD ! -path \"*/dist/*\""
    FIND_CMD="$FIND_CMD ! -path \"*/venv/*\""
    FIND_CMD="$FIND_CMD ! -path \"*/__pycache__/*\""
    FIND_CMD="$FIND_CMD ! -path \"*/\\.*cache/*\""

    echo -e "${BLUE}🔍 DEBUG: Complete find command: ${CYAN}$FIND_CMD${NC}" >&2

    # Execute the find command
    echo -e "${BLUE}🔍 DEBUG: Executing find command${NC}" >&2
    eval "$FIND_CMD" >"$FILE_LIST" 2>/dev/null || true

    echo -e "${BLUE}🔍 DEBUG: Find command result status: $?${NC}" >&2
    echo -e "${BLUE}🔍 DEBUG: File list size: $(wc -l <"$FILE_LIST" 2>/dev/null || echo "0") files${NC}" >&2

    # Include additional files if specified
    if [ -n "$INCLUDE_PATTERN" ]; then
      echo -e "${BLUE}🔍 Adding files matching pattern: ${YELLOW}$INCLUDE_PATTERN${NC}" >&2
      echo -e "${BLUE}🔍 DEBUG: Running additional find for include pattern${NC}" >&2
      find "$PROJECT_PATH" -type f -name "$INCLUDE_PATTERN" >>"$FILE_LIST" 2>/dev/null || true
      echo -e "${BLUE}🔍 DEBUG: After adding include patterns: $(wc -l <"$FILE_LIST" 2>/dev/null || echo "0") files${NC}" >&2
    fi
  fi

  # Check if we found any files
  if [ ! -s "$FILE_LIST" ]; then
    echo -e "${YELLOW}⚠️ No files found in the project directory${NC}" >&2
    echo -e "${BLUE}🔍 DEBUG: File list is empty${NC}" >&2
    echo "" >&2
    return 1
  fi

  echo -e "${BLUE}🔍 DEBUG: Found $(wc -l <"$FILE_LIST") files before filtering${NC}" >&2

  # Print a sample of files found
  echo -e "${BLUE}🔍 DEBUG: Sample of files found (first 5):${NC}" >&2
  head -n 5 "$FILE_LIST" | while read -r sample_file; do
    echo -e "${BLUE}🔍 DEBUG: Sample file: ${CYAN}$sample_file${NC}" >&2
  done

  # Filter the list for processable files
  echo -e "${BLUE}👀 Filtering files by type and size...${NC}" >&2
  while IFS= read -r file; do
    echo -e "${BLUE}🔍 DEBUG: Checking file: ${CYAN}$file${NC}" >&2
    if should_process_file "$file"; then
      echo -e "${BLUE}🔍 DEBUG: File passed filter: ${CYAN}$file${NC}" >&2
      echo "$file" >>"$FILTERED_LIST"
    else
      echo -e "${BLUE}🔍 DEBUG: File excluded by filter: ${CYAN}$file${NC}" >&2
    fi
  done <"$FILE_LIST"

  # Check if we have files to process
  if [ -s "$FILTERED_LIST" ]; then
    echo -e "${BLUE}🔍 DEBUG: Found $(wc -l <"$FILTERED_LIST") files after filtering${NC}" >&2
    echo -e "${BLUE}🔍 DEBUG: Moving filtered list to file list${NC}" >&2
    mv "$FILTERED_LIST" "$FILE_LIST"

    local FILE_COUNT=$(wc -l <"$FILE_LIST")
    echo -e "${GREEN}📊 Found ${YELLOW}$FILE_COUNT${GREEN} files to process after filtering${NC}" >&2

    # Print the full path to the file list
    echo -e "${BLUE}🔍 DEBUG: Final file list at: ${CYAN}$(realpath "$FILE_LIST")${NC}" >&2

    # Only output the path to the file list as the last line of output
    echo "$FILE_LIST"
    return 0
  else
    echo -e "${YELLOW}⚠️ No suitable files found to process after filtering${NC}" >&2
    echo -e "${BLUE}🔍 DEBUG: Filtered list is empty${NC}" >&2
    return 1
  fi
}

# Function to process a single file for embedding
process_file() {
  local file="$1"
  local id="$2"
  local db="$3"
  local collection="$4"

  # Make sure the file exists
  if [ ! -f "$file" ]; then
    echo -e "${YELLOW}⚠️ File not found: $file${NC}" >&2
    return 1
  fi

  # Get file content
  local content
  content=$(cat "$file" 2>/dev/null)

  # Check if we could read the file
  if [ $? -ne 0 ]; then
    echo -e "${YELLOW}⚠️ Could not read file: $file${NC}" >&2
    return 1
  fi

  # Skip empty files
  if [ -z "$content" ]; then
    echo -e "${YELLOW}⚠️ Empty file: $file${NC}" >&2
    return 0
  fi

  # Use silent error handling
  if llm embed "$collection" "$id" -m "$MODEL" -c "$content" -d "$db" --store >/dev/null 2>&1; then
    return 0 # Success
  else
    echo -e "${YELLOW}⚠️ Failed to embed: $file${NC}" >&2
    return 1 # Failed
  fi
}

# }}}

# CREATE EMBEDDINGS {{{
create_embeddings() {
  local PROJECT_PATH="$1"

  echo -e "${BLUE}🔍 DEBUG: Starting create_embeddings with project path: ${CYAN}$PROJECT_PATH${NC}"

  # Check if force flag is set or if the database doesn't exist
  if [ "$FORCE" = true ] && [ -f "$DB_PATH" ]; then
    echo -e "${YELLOW}⚠️ Force flag set - removing existing database${NC}"
    rm -f "$DB_PATH"
  elif [ -f "$DB_PATH" ]; then
    echo -e "${YELLOW}⚠️ Embeddings database already exists at ${CYAN}$DB_PATH${NC}"
    echo -e "   Use ${GREEN}--force${NC} to recreate the database"
    return 0
  fi

  echo -e "${BLUE}🔍 Processing files in ${CYAN}$PROJECT_PATH${NC}"
  echo -e "${BLUE}💾 Embeddings will be saved to ${CYAN}$DB_PATH${NC}"
  echo -e "${BLUE}🧠 Using model: ${CYAN}$MODEL${NC}"

  # Create a temporary directory for processing
  TEMP_DIR=$(mktemp -d)
  echo -e "${BLUE}🔍 DEBUG: Created temporary directory: ${CYAN}$TEMP_DIR${NC}"

  # Make sure we clean up on exit
  trap 'echo -e "${BLUE}🔍 DEBUG: Cleaning up temp dir $TEMP_DIR${NC}"; rm -rf "$TEMP_DIR"' EXIT

  # Get the list of files to process - using a separate file to store the path
  echo -e "${BLUE}🔍 DEBUG: Calling get_file_list${NC}"

  # Clean way to handle return path
  FILE_LIST_PATH="${TEMP_DIR}/file_list_path.txt"
  touch "$FILE_LIST_PATH"

  # Run get_file_list and store result status
  get_file_list "$PROJECT_PATH" "$TEMP_DIR" >"$FILE_LIST_PATH"
  FILE_LIST_STATUS=$?

  # Get the actual file list path from the output
  FILE_LIST=$(tail -n 1 "$FILE_LIST_PATH")

  echo -e "${BLUE}🔍 DEBUG: get_file_list returned status: ${CYAN}$FILE_LIST_STATUS${NC}"
  echo -e "${BLUE}🔍 DEBUG: FILE_LIST value: ${CYAN}$FILE_LIST${NC}"

  # Check if we got a valid file list
  if [ $FILE_LIST_STATUS -ne 0 ] || [ -z "$FILE_LIST" ] || [ ! -f "$FILE_LIST" ]; then
    echo -e "${RED}Error: Failed to generate file list${NC}"
    echo -e "${BLUE}🔍 DEBUG: File list validation failed:${NC}"
    echo -e "${BLUE}🔍 DEBUG: - Status code: ${CYAN}$FILE_LIST_STATUS${NC}"
    echo -e "${BLUE}🔍 DEBUG: - FILE_LIST set: ${CYAN}$([ -n "$FILE_LIST" ] && echo "yes" || echo "no")${NC}"
    echo -e "${BLUE}🔍 DEBUG: - FILE_LIST is a file: ${CYAN}$([ -f "$FILE_LIST" ] && echo "yes" || echo "no")${NC}"
    return 1
  fi

  FILE_COUNT=$(wc -l <"$FILE_LIST")
  echo -e "${BLUE}🔍 DEBUG: File count: ${CYAN}$FILE_COUNT${NC}"

  # Process files in batches
  echo -e "${BLUE}🧠 Processing files in batches of ${YELLOW}$BATCH_SIZE${BLUE} to optimize performance...${NC}"

  # Create a progress counter
  COUNTER=0
  SUCCESS_COUNT=0
  FAIL_COUNT=0

  # Process each file individually
  while read -r file; do
    COUNTER=$((COUNTER + 1))
    PERCENTAGE=$((COUNTER * 100 / FILE_COUNT))

    # Show progress
    printf "${BLUE}Processing: [%3d/%3d] %3d%% - %s${NC}\r" "$COUNTER" "$FILE_COUNT" "$PERCENTAGE" "${file:0:40}"

    # Get file ID (relative path)
    if [[ "$file" == "$PROJECT_PATH/"* ]]; then
      # Remove project path prefix
      FILE_ID="${file#$PROJECT_PATH/}"
    else
      # Use file path as is if we're already in the project directory
      FILE_ID="$file"
    fi

    # Skip empty file ID
    if [ -z "$FILE_ID" ]; then
      continue
    fi

    # Process the file
    if process_file "$file" "$FILE_ID" "$DB_PATH" "$COLLECTION"; then
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi

    # Add a small delay to avoid API rate limits
    sleep 0.2

  done <"$FILE_LIST"

  echo -e "\n${GREEN}Processing complete! Successfully processed ${YELLOW}$SUCCESS_COUNT${GREEN} files, failed to process ${YELLOW}$FAIL_COUNT${GREEN} files.${NC}"

  # Check if the database was created successfully
  if [ -f "$DB_PATH" ]; then
    echo -e "${GREEN}✅ Embeddings successfully created and saved to ${CYAN}$DB_PATH${NC}"
    echo -e "${GREEN}🔢 Database size: ${YELLOW}$(du -h "$DB_PATH" | cut -f1)${NC}"

    # Show some information about the collections
    echo -e "${GREEN}📚 Collections in database:${NC}"
    llm collections list -d "$DB_PATH" 2>/dev/null || echo "No collections found."
  else
    echo -e "${RED}❌ Error: Failed to create embeddings database${NC}"
    return 1
  fi

  echo -e "${GREEN}🎉 All done!${NC}"
}

#}}}

# QUERY EMBEDDINGS {{{
query_embeddings() {
  local PROJECT_PATH="$1"
  local QUERY_TEXT="$2"
  local HUMAN_OUTPUT="$3"

  # Only show important logs in non-debug mode
  if [ "${DEBUG:-false}" = true ]; then
    echo -e "${BLUE}🔍 Project path: ${CYAN}$PROJECT_PATH${NC}" >&2
    echo -e "${BLUE}🔍 Query text: ${CYAN}$QUERY_TEXT${NC}" >&2
    echo -e "${BLUE}🔍 Human output: ${CYAN}$HUMAN_OUTPUT${NC}" >&2
    echo -e "${BLUE}🔍 DB path: ${CYAN}$DB_PATH${NC}" >&2
    echo -e "${BLUE}🔍 Collection: ${CYAN}$COLLECTION${NC}" >&2
    echo -e "${BLUE}🔍 Threshold: ${CYAN}$THRESHOLD${NC}" >&2
    echo -e "${BLUE}🔍 Limit: ${CYAN}$LIMIT${NC}" >&2
  fi

  # Check if the database exists
  if [ ! -f "$DB_PATH" ]; then
    if [ "${DEBUG:-false}" = true ]; then
      echo -e "${BLUE}🔍 Database not found at path: ${CYAN}$DB_PATH${NC}" >&2
    fi

    if [ "$HUMAN_OUTPUT" = false ]; then
      echo "{\"error\": \"Database not found\", \"path\": \"$DB_PATH\"}"
    else
      echo -e "${RED}Error: Embeddings database not found at ${CYAN}$DB_PATH${NC}"
      echo -e "Run ${GREEN}$0 create${NC} first to generate embeddings."
    fi
    return 1
  fi

  # Check if query is provided
  if [ -z "$QUERY_TEXT" ]; then
    if [ "$HUMAN_OUTPUT" = false ]; then
      echo "{\"error\": \"No query provided\"}"
    else
      echo -e "${RED}Error: No query text provided.${NC}"
      echo -e "Use ${GREEN}-q \"your query\"${NC} to specify a search query."
    fi
    return 1
  fi

  # Show search parameters if human output
  if [ "$HUMAN_OUTPUT" = true ]; then
    echo -e "${BLUE}🔍 Searching for: ${CYAN}\"$QUERY_TEXT\"${NC}"
    echo -e "${BLUE}📊 Using collection: ${CYAN}$COLLECTION${NC}"
    echo -e "${BLUE}📚 Maximum results: ${CYAN}$LIMIT${NC}"
    echo -e "${BLUE}🎯 Similarity threshold: ${CYAN}$THRESHOLD${NC}"
  fi

  # Run the query
  TEMP_RESULTS=$(mktemp)
  if [ "${DEBUG:-false}" = true ]; then
    echo -e "${BLUE}🔍 Created temp file for results: ${CYAN}$TEMP_RESULTS${NC}" >&2
    echo -e "${BLUE}🔍 Running: llm similar \"$COLLECTION\" -c \"$QUERY_TEXT\" -d \"$DB_PATH\"${NC}" >&2
  fi

  # Execute the llm similar command
  llm similar "$COLLECTION" -c "$QUERY_TEXT" -d "$DB_PATH" >"$TEMP_RESULTS" 2>/dev/null
  QUERY_STATUS=$?

  if [ $QUERY_STATUS -ne 0 ]; then
    if [ "$HUMAN_OUTPUT" = false ]; then
      echo "{\"error\": \"Query failed\", \"status\": $QUERY_STATUS}"
    else
      echo -e "${RED}Error: Failed to query embeddings. llm similar command returned code $QUERY_STATUS${NC}"
    fi
    rm -f "$TEMP_RESULTS"
    return 1
  fi

  # Load results
  RESULTS=$(cat "$TEMP_RESULTS")
  RESULTS_COUNT=$(echo "$RESULTS" | grep -c ".")
  if [ "${DEBUG:-false}" = true ]; then
    echo -e "${BLUE}🔍 Query returned ${CYAN}$RESULTS_COUNT${BLUE} raw results${NC}" >&2
  fi

  # Check if we have results
  if [ -z "$RESULTS" ]; then
    if [ "$HUMAN_OUTPUT" = false ]; then
      echo "[]"
    else
      echo -e "${YELLOW}⚠️ No results found matching your query.${NC}"
    fi
    rm -f "$TEMP_RESULTS"
    return 0
  fi

  # For JSON output, we parse the text output and convert to JSON
  if [ "$HUMAN_OUTPUT" = false ]; then
    # Initialize JSON array
    TEMP_JSON=$(mktemp)
    echo "[" >"$TEMP_JSON"
    FIRST_ITEM=true

    # Process each line of the results
    while IFS= read -r line; do
      # Skip empty lines
      [ -z "$line" ] && continue

      # Parse the JSON line to extract information
      if echo "$line" | grep -q '"id":'; then
        # Extract the ID and score with proper JSON parsing
        id=$(echo "$line" | sed -n 's/.*"id": "\([^"]*\)".*/\1/p')
        score=$(echo "$line" | sed -n 's/.*"score": \([0-9.]*\).*/\1/p')

        # Initialize content and metadata as null
        content="null"
        metadata="null"

        # Check if we have content
        if echo "$line" | grep -q '"content":' && ! echo "$line" | grep -q '"content": null'; then
          # Extract content and properly escape it for JSON
          raw_content=$(echo "$line" | sed -n 's/.*"content": "\([^"]*\)".*/\1/p')
          # Escape backslashes first, then quotes
          escaped_content=$(echo "$raw_content" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
          content="\"$escaped_content\""
        fi

        # Check if we need to add content from file
        if [ "$SHOW_CONTENT" = true ] && [ "$content" = "null" ]; then
          file_path="$id"
          if [ ! -f "$file_path" ] && [ -f "$PROJECT_PATH/$id" ]; then
            file_path="$PROJECT_PATH/$id"
          fi

          if [ -f "$file_path" ]; then
            # Read first 5 lines of the file and properly escape for JSON
            file_content=$(head -n 5 "$file_path" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ')
            content="\"$file_content\""
          fi
        fi

        # Extract metadata if available
        if echo "$line" | grep -q '"metadata":' && ! echo "$line" | grep -q '"metadata": null'; then
          metadata_raw=$(echo "$line" | sed -n 's/.*"metadata": \({[^}]*}\).*/\1/p')
          if [ -n "$metadata_raw" ]; then
            metadata="$metadata_raw"
          fi
        fi

        # Add comma if not the first item
        if [ "$FIRST_ITEM" = true ]; then
          FIRST_ITEM=false
        else
          echo "," >>"$TEMP_JSON"
        fi

        # Create properly formatted JSON object
        echo -n "{\"id\":\"$id\",\"score\":$score,\"content\":$content,\"metadata\":$metadata}" >>"$TEMP_JSON"

        if [ "${DEBUG:-false}" = true ]; then
          echo -e "${BLUE}🔍 Added result: ${CYAN}$id${NC}" >&2
        fi
      fi
    done <"$TEMP_RESULTS"

    # Close JSON array
    echo "" >>"$TEMP_JSON" # Add newline before closing bracket
    echo "]" >>"$TEMP_JSON"

    # Read the properly formatted JSON array
    RESULTS=$(cat "$TEMP_JSON")
    rm -f "$TEMP_JSON"
  fi

  # Check if jq is available for filtering
  if command -v jq &>/dev/null; then
    if [ "$HUMAN_OUTPUT" = false ]; then
      # Filter by threshold and limit
      FILTERED_RESULTS=$(echo "$RESULTS" | jq --arg threshold "$THRESHOLD" -c '[.[] | select(.score >= ($threshold | tonumber))]')

      if [ "${DEBUG:-false}" = true ]; then
        FILTERED_COUNT=$(echo "$FILTERED_RESULTS" | jq 'length')
        echo -e "${BLUE}🔍 ${CYAN}$FILTERED_COUNT${BLUE} results after threshold filtering${NC}" >&2
      fi

      # Apply limit
      LIMITED_RESULTS=$(echo "$FILTERED_RESULTS" | jq --arg limit "$LIMIT" -c 'limit(($limit | tonumber); .)')

      # Return properly formatted JSON array
      echo "$LIMITED_RESULTS"
    else
      # Human-readable output
      # Convert raw results to JSON first for easier processing
      FILTERED_RESULTS=$(echo "$RESULTS" | jq --arg threshold "$THRESHOLD" '[.[] | select(.score >= ($threshold | tonumber))]')
      LIMITED_RESULTS=$(echo "$FILTERED_RESULTS" | jq --arg limit "$LIMIT" 'limit(($limit | tonumber); .)')

      LIMITED_COUNT=$(echo "$LIMITED_RESULTS" | jq 'length')

      echo -e "${GREEN}📋 Search results:${NC}"
      echo -e "-------------------------------------------"

      # Use jq to iterate through results
      for i in $(seq 0 $(($LIMITED_COUNT - 1))); do
        RESULT=$(echo "$LIMITED_RESULTS" | jq --arg i "$i" '.[$i | tonumber]')

        id=$(echo "$RESULT" | jq -r '.id')
        score=$(echo "$RESULT" | jq -r '.score')

        # Format score as percentage
        score_percent=$(printf "%.1f" $(echo "$score * 100" | bc -l 2>/dev/null || echo "$score * 100" | awk '{printf "%.1f", $1}'))

        content=$(echo "$RESULT" | jq -r '.content')
        metadata=$(echo "$RESULT" | jq -r '.metadata')

        # Get file path
        file_path="$id"
        if [ ! -f "$file_path" ] && [ -f "$PROJECT_PATH/$id" ]; then
          file_path="$PROJECT_PATH/$id"
        fi

        echo -e "${CYAN}$id${NC} (${YELLOW}${score_percent}%${NC} match)"

        if [ "$SHOW_CONTENT" = true ]; then
          # Show content if available
          if [ "$content" != "null" ]; then
            echo -e "${PURPLE}--- Content Preview:${NC}"
            echo "$content" | head -n 5
            if [ $(echo "$content" | wc -l) -gt 5 ]; then
              echo -e "${PURPLE}...${NC}"
            fi
            echo -e "${PURPLE}---${NC}"
          elif [ -f "$file_path" ]; then
            echo -e "${PURPLE}--- File Preview:${NC}"
            head -n 5 "$file_path"
            if [ $(wc -l <"$file_path") -gt 5 ]; then
              echo -e "${PURPLE}...${NC}"
            fi
            echo -e "${PURPLE}---${NC}"
          fi

          # Show metadata if available
          if [ "$metadata" != "null" ] && [ "$metadata" != "{}" ]; then
            echo -e "${BLUE}Metadata:${NC} $metadata"
          fi
        fi
      done

      echo -e "-------------------------------------------"
      echo -e "${GREEN}🎉 Search complete!${NC}"
    fi
  else
    # No jq available - this is a fallback for both modes
    if [ "$HUMAN_OUTPUT" = false ]; then
      # In JSON mode, we've already created a simple JSON array above
      echo "$RESULTS"
      echo -e "${YELLOW}⚠️ Warning: jq not installed. Results are not filtered by threshold.${NC}" >&2
    else
      echo -e "${YELLOW}⚠️ Warning: jq not found - cannot filter by threshold${NC}"
      echo -e "${YELLOW}   Install jq for better filtering capabilities${NC}"

      # Basic display of results for human-readable mode without jq
      # Apply only limit
      TOTAL_RESULTS=$(echo "$RESULTS" | wc -l)

      if [ $TOTAL_RESULTS -gt $LIMIT ]; then
        RESULTS=$(echo "$RESULTS" | head -n $LIMIT)
      fi

      # Basic display of results
      echo -e "${GREEN}📋 Search results (unfiltered):${NC}"
      echo -e "-------------------------------------------"
      echo "$RESULTS" | while read -r line; do
        id=$(echo "$line" | grep -o '"id": "[^"]*"' | sed 's/"id": "\(.*\)"/\1/')
        score=$(echo "$line" | grep -o '"score": [0-9.]*' | sed 's/"score": \(.*\)/\1/')

        file_path="$id"
        if [ ! -f "$file_path" ] && [ -f "$PROJECT_PATH/$id" ]; then
          file_path="$PROJECT_PATH/$id"
        fi

        echo -e "${CYAN}$id${NC} (score: ${YELLOW}$score${NC})"

        if [ "$SHOW_CONTENT" = true ] && [ -f "$file_path" ]; then
          echo -e "${PURPLE}--- File Preview:${NC}"
          head -n 5 "$file_path"
          if [ $(wc -l <"$file_path") -gt 5 ]; then
            echo -e "${PURPLE}...${NC}"
          fi
          echo -e "${PURPLE}---${NC}"
        fi
      done

      echo -e "-------------------------------------------"
      echo -e "${GREEN}🎉 Search complete!${NC}"
    fi
  fi

  # Clean up
  rm -f "$TEMP_RESULTS"
  return 0
}
# }}}

# LIST FILES {{{
list_files() {
  local PROJECT_PATH="$1"
  local PATTERN="$2"

  echo -e "${BLUE}🔍 DEBUG: Starting list_files function${NC}" >&2
  echo -e "${BLUE}🔍 DEBUG: Project path: ${CYAN}$PROJECT_PATH${NC}" >&2
  echo -e "${BLUE}🔍 DEBUG: Pattern: ${CYAN}$PATTERN${NC}" >&2
  echo -e "${BLUE}🔍 DEBUG: DB path: ${CYAN}$DB_PATH${NC}" >&2
  echo -e "${BLUE}🔍 DEBUG: Collection: ${CYAN}$COLLECTION${NC}" >&2

  # Check if the database exists
  if [ ! -f "$DB_PATH" ]; then
    echo -e "${RED}Error: Embeddings database not found at ${CYAN}$DB_PATH${NC}"
    echo -e "Run ${GREEN}$0 create${NC} first to generate embeddings."
    return 1
  fi

  # First, verify that the collection exists and get all collections
  echo -e "${BLUE}🔍 DEBUG: Checking available collections in database${NC}" >&2
  ALL_COLLECTIONS=$(sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
  echo -e "${BLUE}🔍 DEBUG: Found collections: ${CYAN}$ALL_COLLECTIONS${NC}" >&2

  echo "$ALL_COLLECTIONS"

  # Check if our specified collection exists
  if ! echo "$ALL_COLLECTIONS"; then
    echo -e "${BLUE}🔍 DEBUG: Collection ${CYAN}$COLLECTION${BLUE} not found${NC}" >&2

    # If the collection doesn't exist, but there's only one collection, use that one
    if [ "$(echo "$ALL_COLLECTIONS" | wc -l)" -eq 1 ]; then
      COLLECTION="$ALL_COLLECTIONS"
      echo -e "${YELLOW}⚠️ Collection '${CYAN}$COLLECTION${YELLOW}' not found, but found only one collection. Using '${CYAN}$COLLECTION${YELLOW}' instead.${NC}"
    else
      echo -e "${RED}Error: Collection '${CYAN}$COLLECTION${RED}' not found in database.${NC}"
      echo -e "${BLUE}🔍 Available collections:${NC}"
      echo "$ALL_COLLECTIONS" | while read -r coll; do
        echo -e "   - ${CYAN}$coll${NC}"
      done
      echo -e "Use ${GREEN}-c collection_name${NC} to specify which collection to use."
      return 1
    fi
  fi

  echo -e "${BLUE}📊 Using collection: ${CYAN}$COLLECTION${NC}"
  echo -e "${BLUE}🔍 Listing files matching pattern: ${CYAN}'$PATTERN'${NC}"
  echo -e "-------------------------------------------"

  # Check if the pattern is "*" and query the database to get all IDs
  echo -e "${BLUE}🔍 DEBUG: Querying database for IDs matching pattern: ${CYAN}$PATTERN${NC}" >&2

  # Handle wildcard pattern differently to avoid SQL injection and pattern issues
  if [ "$PATTERN" = "*" ]; then
    echo -e "${BLUE}🔍 DEBUG: Using query for all IDs${NC}" >&2
    IDS=$(sqlite3 "$DB_PATH" "SELECT id FROM \"$COLLECTION\" ORDER BY id;")
  else
    # Escape special characters in pattern for SQL LIKE
    ESCAPED_PATTERN=$(echo "$PATTERN" | sed 's/[%_]/\\&/g')
    echo -e "${BLUE}🔍 DEBUG: Using query with LIKE pattern: %${CYAN}$ESCAPED_PATTERN${BLUE}%${NC}" >&2
    IDS=$(sqlite3 "$DB_PATH" "SELECT id FROM \"$COLLECTION\" WHERE id LIKE '%$ESCAPED_PATTERN%' ORDER BY id;")
  fi

  # Debug the SQL results
  ID_COUNT=$(echo "$IDS" | grep -c "." || echo 0)
  echo -e "${BLUE}🔍 DEBUG: Query returned ${CYAN}$ID_COUNT${BLUE} IDs${NC}" >&2

  # Check if we got any results
  if [ -z "$IDS" ]; then
    echo -e "${BLUE}🔍 DEBUG: No IDs found matching pattern${NC}" >&2
    echo -e "${YELLOW}❌ No files found matching pattern: '$PATTERN'${NC}"
    # Give a hint about what's in the database
    TOTAL_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM \"$COLLECTION\";")
    echo -e "${BLUE}ℹ️ The database contains ${YELLOW}$TOTAL_COUNT${BLUE} total files.${NC}"

    # Show a few examples
    if [ "$TOTAL_COUNT" -gt 0 ]; then
      echo -e "${BLUE}ℹ️ Here are a few examples of what's in the database:${NC}"
      sqlite3 "$DB_PATH" "SELECT id FROM \"$COLLECTION\" LIMIT 5;" |
        while read -r id; do
          echo -e "   - ${CYAN}$id${NC}"
        done
    fi
    return 0
  fi

  # Count results
  COUNT=$(echo "$IDS" | wc -l)
  echo -e "${BLUE}🔍 DEBUG: Found ${CYAN}$COUNT${BLUE} matching files${NC}" >&2
  echo -e "${GREEN}📋 Found ${YELLOW}$COUNT${GREEN} files matching pattern:${NC}"

  # Display results
  echo "$IDS" | while read -r id; do
    echo -e "   - ${CYAN}$id${NC}"
  done

  echo -e "-------------------------------------------"
  echo -e "${GREEN}🎉 Listing complete!${NC}"

  # Provide a sample command to search
  echo -e "${BLUE}ℹ️ To search these files, use:${NC}"
  echo -e "   ${GREEN}$0 query -q \"your search query\"${NC}"

  echo -e "${BLUE}🔍 DEBUG: list_files function complete${NC}" >&2
}
# }}}

# SHOW DATABASE INFORMATION {{{
show_info() {
  local PROJECT_PATH="$1"

  # Check if the database exists
  if [ ! -f "$DB_PATH" ]; then
    echo -e "${RED}Error: Embeddings database not found at ${CYAN}$DB_PATH${NC}"
    echo -e "Run ${GREEN}$0 create${NC} first to generate embeddings."
    return 1
  fi

  echo -e "${GREEN}📊 Embeddings Database Information:${NC}"
  echo -e "-------------------------------------------"
  echo -e "${BLUE}📁 Database Path: ${CYAN}$DB_PATH${NC}"
  echo -e "${BLUE}📏 Database Size: ${YELLOW}$(du -h "$DB_PATH" | cut -f1)${NC}"

  # Get collections
  echo -e "${BLUE}📚 Collections:${NC}"
  COLLECTIONS=$(llm collections list -d "$DB_PATH" 2>/dev/null)

  if [ -z "$COLLECTIONS" ]; then
    echo -e "   ${YELLOW}No collections found${NC}"
  else
    echo "$COLLECTIONS" | while read -r collection; do
      # Get count of entries in collection
      COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM ${collection};")
      echo -e "   - ${CYAN}$collection${NC}: ${YELLOW}$COUNT${NC} files"
    done
  fi

  # Get database schema
  echo -e "${BLUE}🗂 Table Schema:${NC}"
  TABLES=$(sqlite3 "$DB_PATH" ".tables")

  for table in $TABLES; do
    echo -e "   ${CYAN}$table${NC}:"
    sqlite3 "$DB_PATH" ".schema $table" | sed 's/^/      /'
  done

  echo -e "-------------------------------------------"
}
# }}}

# MAIN{{{
main() {
  # Default values
  COMMAND="create"
  PROJECT_DIR="."
  OUTPUT_DIR=""
  COLLECTION="$DEFAULT_COLLECTION"
  QUERY_TEXT=""
  LIMIT=200
  THRESHOLD=0.2
  PATTERN="*"
  FORCE=false
  SHOW_CONTENT=false
  INCLUDE_PATTERN=""
  EXCLUDE_PATTERN=""
  HUMAN_OUTPUT=false

  # Parse command if provided
  if [ $# -gt 0 ] && [[ "$1" != -* ]]; then
    COMMAND="$1"
    shift
  fi

  # Parse options
  while [ $# -gt 0 ]; do
    case "$1" in
    -h | --help)
      show_help
      exit 0
      ;;
    -d | --dir)
      PROJECT_DIR="$2"
      shift 2
      ;;
    -o | --output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -m | --model)
      MODEL="$2"
      shift 2
      ;;
    -s | --size)
      MAX_FILE_SIZE="$2"
      shift 2
      ;;
    -b | --batch)
      BATCH_SIZE="$2"
      shift 2
      ;;
    -c | --collection)
      COLLECTION="$2"
      shift 2
      ;;
    -f | --force)
      FORCE=true
      shift
      ;;
    -q | --query)
      QUERY_TEXT="$2"
      shift 2
      ;;
    -n | --limit)
      LIMIT="$2"
      shift 2
      ;;
    -t | --threshold)
      THRESHOLD="$2"
      shift 2
      ;;
    -p | --pattern)
      PATTERN="$2"
      shift 2
      ;;
    --show-content)
      SHOW_CONTENT=true
      shift
      ;;
    --include)
      INCLUDE_PATTERN="$2"
      shift 2
      ;;
    --exclude)
      EXCLUDE_PATTERN="$2"
      shift 2
      ;;
    --human)
      HUMAN_OUTPUT=true
      shift
      ;;
    *)
      PROJECT_DIR="$1"
      shift
      ;;
    esac
  done

  # Make sure PROJECT_DIR is an absolute path
  PROJECT_DIR=$(realpath "$PROJECT_DIR")

  # Set up paths based on project directory
  setup_paths "$PROJECT_DIR"

  # Check requirements based on command
  check_llm_cli

  case "$COMMAND" in
  create)
    create_embeddings "$PROJECT_DIR"
    ;;
  query)
    if [ -z "$QUERY_TEXT" ]; then
      if [ "$HUMAN_OUTPUT" = false ]; then
        echo '{"error": "No query specified. Use -q \"your query\" to search."}'
      else
        echo -e "${YELLOW}No query specified. Use -q \"your query\" to search.${NC}"
      fi
      exit 1
    fi
    check_sqlite
    query_embeddings "$PROJECT_DIR" "$QUERY_TEXT" "$HUMAN_OUTPUT"
    ;;
  list)
    check_sqlite
    list_files "$PROJECT_DIR" "$PATTERN"
    ;;
  info)
    check_sqlite
    show_info "$PROJECT_DIR"
    ;;
  *)
    if [ "$HUMAN_OUTPUT" = false ]; then
      echo "{\"error\": \"Unknown command: $COMMAND\"}"
    else
      echo -e "${RED}Unknown command: $COMMAND${NC}"
      show_help
    fi
    exit 1
    ;;
  esac
}
# }}}

main "$@"
