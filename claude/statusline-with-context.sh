#!/bin/bash

# Efficient bash status line for Claude Code
# Reads JSON from stdin and outputs status information

# Read JSON input
input=$(cat)

# Extract basic info using jq (fast single pass)
model_name=$(echo "$input" | jq -r '.model.display_name // .model.id')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')

# Get folder name
folder_name=$(basename "$current_dir")

# Get git branch (suppress errors)
git_branch=""
if git -C "$current_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git_branch=$(git -C "$current_dir" branch --show-current 2>/dev/null)
  if [ -z "$git_branch" ]; then
    git_branch=$(git -C "$current_dir" rev-parse --short HEAD 2>/dev/null)
  fi
fi

# Try to get context info from the input JSON first (direct from Claude Code)
context_info=""
usage_data=$(echo "$input" | jq -r '.usage // empty' 2>/dev/null)

# If no usage in input, try context.usage
if [ -z "$usage_data" ] || [ "$usage_data" = "null" ]; then
  usage_data=$(echo "$input" | jq -r '.context.usage // empty' 2>/dev/null)
fi

# If still no usage, try the transcript file
if ([ -z "$usage_data" ] || [ "$usage_data" = "null" ]) && [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  # Look for the last assistant message with usage data
  # Use tail -r for efficient reverse reading on macOS, find lines with "type":"assistant"
  usage_line=$(tail -r "$transcript_path" 2>/dev/null | grep -m 1 '"type":"assistant"' | head -1)

  if [ -n "$usage_line" ]; then
    # Extract usage object from the line using jq
    usage_data=$(echo "$usage_line" | jq -r '.message.usage // empty' 2>/dev/null)
  fi
fi

# Process usage data if we found it
if [ -n "$usage_data" ] && [ "$usage_data" != "null" ]; then
  # Extract individual token counts
  input_tokens=$(echo "$usage_data" | jq -r '.input_tokens // 0' 2>/dev/null)
  cache_creation_tokens=$(echo "$usage_data" | jq -r '.cache_creation_input_tokens // 0' 2>/dev/null)
  cache_read_tokens=$(echo "$usage_data" | jq -r '.cache_read_input_tokens // 0' 2>/dev/null)
  output_tokens=$(echo "$usage_data" | jq -r '.output_tokens // 0' 2>/dev/null)

  # Sum all tokens using bash arithmetic
  total_tokens=$((input_tokens + cache_creation_tokens + cache_read_tokens + output_tokens))

  # Get max tokens from model config or default to 200000
  max_tokens=$(echo "$input" | jq -r '.model.max_tokens // .model.context_window // 200000' 2>/dev/null)
  if [ -z "$max_tokens" ] || [ "$max_tokens" = "null" ]; then
    max_tokens=200000
  fi

  if [ "$total_tokens" -gt 0 ]; then
    # Calculate percentage using bash arithmetic (multiply by 1000 for one decimal place)
    percentage_x10=$((total_tokens * 1000 / max_tokens))
    percentage_int=$((percentage_x10 / 10))
    percentage_dec=$((percentage_x10 % 10))

    # Create clean-style progress bar
    create_progress_bar() {
      local percent=$1
      local bar_length=10
      local filled_length=$((percent * bar_length / 100))
      local empty_length=$((bar_length - filled_length))

      local bar=""
      # Add filled dots
      for ((i = 0; i < filled_length; i++)); do
        bar="${bar}●"
      done
      # Add empty dots
      for ((i = 0; i < empty_length; i++)); do
        bar="${bar}○"
      done

      echo "[${bar}]"
    }

    # Function to compress numbers
    compress_number() {
      local num=$1
      if [ "$num" -lt 1000 ]; then
        echo "$num"
      elif [ "$num" -lt 1000000 ]; then
        # Convert to K format
        local k_int=$((num / 1000))
        local k_dec=$(((num % 1000) / 100))
        if [ "$k_dec" -eq 0 ]; then
          echo "${k_int}K"
        else
          echo "${k_int}.${k_dec}K"
        fi
      else
        # Convert to M format
        local m_int=$((num / 1000000))
        local m_dec=$(((num % 1000000) / 100000))
        if [ "$m_dec" -eq 0 ]; then
          echo "${m_int}M"
        else
          echo "${m_int}.${m_dec}M"
        fi
      fi
    }

    # Compress token numbers
    compressed_total=$(compress_number "$total_tokens")
    compressed_max=$(compress_number "$max_tokens")

    # Create progress bar using integer percentage
    progress_bar=$(create_progress_bar "$percentage_int")

    context_info="  󰚩 ${progress_bar} ${percentage_int}.${percentage_dec}% (${compressed_total}/${compressed_max})"
    
    # Add breakdown if we have details
    if [ "$cache_read_tokens" -gt 0 ] || [ "$cache_creation_tokens" -gt 0 ]; then
      compressed_cache_read=$(compress_number "$cache_read_tokens")
      compressed_cache_creation=$(compress_number "$cache_creation_tokens")
      compressed_input=$(compress_number "$input_tokens")
      compressed_output=$(compress_number "$output_tokens")
      # Add cache info with Nerd Font icons for visual clarity
      # Nerd Font icons: 󰇚 (download/input), 󰆼 (database/cache), 󰕒 (upload/output)
      context_info="${context_info} [󰇚${compressed_input} 󰆼${compressed_cache_read} 󰕒${compressed_output}]"
    fi
  fi
fi

# Build output with ANSI colors and Nerd Font icons (from starship config)
# Hacker green: \033[92m, Cyan: \033[96m, Orange-red: \033[91m, Reset: \033[0m
# Nerd Font icons:  (folder), (git branch),  (robot/AI)
output="\033[92m $model_name\033[0m  \033[96m$folder_name\033[0m"
if [ -n "$git_branch" ]; then
  output="$output  \033[92m$git_branch\033[0m"
fi

# Add context info with colors if available
if [ -n "$context_info" ]; then
  # Color the context section - icon in yellow, rest in dimmed yellow
  colored_context=$(echo "$context_info" | sed 's/󰚩/\\033[93m󰚩\\033[0m\\033[33m/' | sed 's/$$/\\033[0m/')
  output="$output$colored_context"
else
  output="$output$context_info"
fi

echo -e "$output"