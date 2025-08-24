#!/bin/bash

# Read JSON input from Claude Code
input=$(cat)

# Extract basic info
model_name=$(echo "$input" | jq -r '.model.display_name // .model.id // "Claude"')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "."')
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')
session_id=$(echo "$input" | jq -r '.session_id // ""')

# Get folder name
folder_name=$(basename "$current_dir")

# Get git branch
git_branch=""
if [ -d "$current_dir/.git" ]; then
  git_branch=$(cd "$current_dir" && git branch --show-current 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "")
fi

# Function to format numbers
format_number() {
  local num=$1
  if [ "$num" -lt 1000 ]; then
    echo "$num"
  elif [ "$num" -lt 1000000 ]; then
    echo "$((num / 1000))K"
  else
    echo "$((num / 1000000))M"
  fi
}

# Try to get usage from the transcript file
context_info=""
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  # Get the last line with usage information
  last_usage=$(tail -100 "$transcript_path" 2>/dev/null | grep '"usage"' | tail -1)
  
  if [ -n "$last_usage" ]; then
    # Extract token counts
    input_tokens=$(echo "$last_usage" | sed -n 's/.*"input_tokens":\s*\([0-9]*\).*/\1/p')
    output_tokens=$(echo "$last_usage" | sed -n 's/.*"output_tokens":\s*\([0-9]*\).*/\1/p')
    cache_read=$(echo "$last_usage" | sed -n 's/.*"cache_read_input_tokens":\s*\([0-9]*\).*/\1/p')
    cache_creation=$(echo "$last_usage" | sed -n 's/.*"cache_creation_input_tokens":\s*\([0-9]*\).*/\1/p')
    
    # Default to 0 if empty
    input_tokens=${input_tokens:-0}
    output_tokens=${output_tokens:-0}
    cache_read=${cache_read:-0}
    cache_creation=${cache_creation:-0}
    
    # Calculate total
    total_tokens=$((input_tokens + output_tokens + cache_read + cache_creation))
    
    if [ "$total_tokens" -gt 0 ]; then
      # Assume 200K context window for Opus
      max_tokens=200000
      percentage=$((total_tokens * 100 / max_tokens))
      
      # Format numbers
      total_fmt=$(format_number $total_tokens)
      max_fmt=$(format_number $max_tokens)
      
      # Create progress bar
      bar_length=10
      filled=$((percentage * bar_length / 100))
      bar=""
      for ((i=0; i<bar_length; i++)); do
        if [ $i -lt $filled ]; then
          bar="${bar}●"
        else
          bar="${bar}○"
        fi
      done
      
      context_info=" | [${bar}] ${percentage}% (${total_fmt}/${max_fmt})"
    fi
  fi
fi

# If no transcript, try to read from ccusage data
if [ -z "$context_info" ] && [ -n "$session_id" ]; then
  # Check if ccusage is available and has data
  if command -v ccusage &> /dev/null; then
    # Pass the input to ccusage and extract just the context part
    ccusage_output=$(echo "$input" | ccusage statusline 2>/dev/null | grep -o '🧠[^|]*' | sed 's/🧠 //')
    if [ -n "$ccusage_output" ] && [ "$ccusage_output" != "N/A" ]; then
      context_info=" | 🧠 ${ccusage_output}"
    fi
  fi
fi

# Build output
output="${model_name} | ${folder_name}"
[ -n "$git_branch" ] && output="${output} | ${git_branch}"
[ -n "$context_info" ] && output="${output}${context_info}"

echo "$output"