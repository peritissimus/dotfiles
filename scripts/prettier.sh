#!/bin/bash

# Run prettier on all modified files shown in git status
# This script should be run from the git root directory

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo -e "${RED}❌ Error: Not in a git repository${NC}"
  exit 1
fi

# Get to git root directory
cd "$(git rev-parse --show-toplevel)" || exit 1

# Get list of modified files (both staged and unstaged)
FILES=$(git status --porcelain | grep -E '^(M|A|MM|AM| M)' | awk '{print $2}')

if [ -z "$FILES" ]; then
  echo -e "${YELLOW}⚠️  No modified files found in git status${NC}"
  exit 0
fi

# Count files
FILE_COUNT=$(echo "$FILES" | wc -l | tr -d ' ')

echo -e "${BLUE}🎨 Running Prettier on ${FILE_COUNT} modified file(s)...${NC}"
echo ""

# Counters
SUCCESS_COUNT=0
SKIP_COUNT=0

# Process each file
echo "$FILES" | while read -r file; do
  if [ -f "$file" ]; then
    # Try to format the file
    if npx prettier --write "$file" 2>/dev/null; then
      echo -e "  ${GREEN}✓${NC} $file"
      ((SUCCESS_COUNT++))
    else
      echo -e "  ${YELLOW}−${NC} $file ${YELLOW}(not supported)${NC}"
      ((SKIP_COUNT++))
    fi
  fi
done

echo ""
echo -e "${GREEN}✨ Prettier formatting complete!${NC}"
echo -e "${BLUE}ℹ️  Files have been formatted in place.${NC}"
