#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: ./pr_summary.sh <PR_NUMBER>"
  exit 1
fi

PR_NUM=$1
CURRENT_DATE=$(date +"%Y-%m-%d")

gh pr view $PR_NUM --json title,body,files | llm "Format this PR data into:

[AI Generated Summary - $CURRENT_DATE]

## Description
[Extract key points from title/body]

## Files Changed
[List changed files with paths, additions, deletions]

## API To Test
[Generate API testing steps based on changes]

## Test Case
### Output before this change
[Expected previous behavior]
### Output after this change
[Expected new behavior]

## Database Migration
[Note any DB changes needed]" >pr_summary_$PR_NUM.md

echo "AI generated PR summary written to pr_summary_$PR_NUM.md"
