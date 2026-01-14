---
name: bash-skill
description: Use when working with bash scripts, shell commands, terminal automation, or system administration tasks. Applies to .sh files, shell scripting, CLI tools, and Unix/Linux operations.
allowed-tools: Read, Grep, Glob, Bash
---

# Bash Scripting Expert

## When to Apply
- Writing or debugging bash/shell scripts
- Creating CLI tools or automation scripts
- System administration tasks
- Working with .sh, .bash, or shell configuration files

## Best Practices

### Script Structure
- Always start with a shebang: `#!/usr/bin/env bash`
- Use `set -euo pipefail` for safer scripts
- Add meaningful comments for complex logic

### Variables
- Quote variables: `"$var"` not `$var`
- Use `${var}` for clarity in strings
- Prefer `local` for function variables
- Use lowercase for local vars, UPPERCASE for exports

### Conditionals
- Use `[[ ]]` instead of `[ ]` for tests
- Quote string comparisons: `[[ "$a" == "$b" ]]`
- Use `-n` and `-z` for string length checks

### Functions
```bash
my_function() {
    local arg1="$1"
    # function body
}
```

### Error Handling
- Check command exit codes
- Use `|| exit 1` or `|| return 1` for critical commands
- Provide meaningful error messages to stderr: `echo "Error: ..." >&2`

### Common Patterns

**Safe file reading:**
```bash
while IFS= read -r line; do
    echo "$line"
done < "$file"
```

**Default values:**
```bash
name="${1:-default_value}"
```

**Check if command exists:**
```bash
if command -v git &>/dev/null; then
    echo "git is installed"
fi
```

**Parse arguments:**
```bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) show_help; exit 0 ;;
        -v|--verbose) VERBOSE=1; shift ;;
        *) args+=("$1"); shift ;;
    esac
done
```

## Security
- Never use `eval` with user input
- Validate and sanitize inputs
- Avoid hardcoding secrets
- Use `mktemp` for temporary files
