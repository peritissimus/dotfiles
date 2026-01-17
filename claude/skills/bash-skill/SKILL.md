---
name: bash-skill
description: Expert system for generating production-grade, secure, and maintainable Bash scripts. Focuses on strict error handling, portability, and enterprise standards.
allowed-tools: Read, Grep, Glob, Bash
---

# Bash Scripting Specialist

## When to Apply
- Creating production/enterprise automation scripts
- Writing CI/CD pipeline steps
- Developing CLI tools for team distribution
- Performing complex system administration tasks
- Debugging or refactoring legacy shell scripts

## Core Principles (The "Strict Mode")
All scripts **MUST** start with the following safety preamble to fail fast and loudly:

```bash
#!/usr/bin/env bash
set -euo pipefail
set -E
```

1.  **`set -e`**: Exit immediately if a command exits with a non-zero status.
2.  **`set -u`**: Treat unset variables as an error.
3.  **`set -o pipefail`**: Catch errors in piped commands (e.g., `cmd1 | cmd2` fails if `cmd1` fails).
4.  **`set -E`**: Inherit trap handlers for shell functions and subshells.

## Best Practices

### 1. Robustness & Safety
- **Always Quote Variables:** Use `"$var"` to prevent word splitting and globbing issues.
- **Check Dependencies:** Verify required tools (`command -v cmd`) at the start of the script.
- **Use `printf` over `echo`:** `printf` is more portable and reliable for formatted output.
- **Avoid `eval`:** It is a security risk. Use arrays or functions instead.
- **Immutable Variables:** Use `readonly` for constants (e.g., `readonly LOG_FILE="/tmp/log"`).

### 2. Code Style & Structure
- **Shebang:** Always use `#!/usr/bin/env bash` for portability across systems (e.g., macOS vs Linux).
- **Naming:**
    - `UPPER_CASE` for exported environment variables and constants.
    - `lower_case` for local variables and function names.
    - `_leading_underscore` for private/internal variables.
- **Functions:** Wrap logic in functions. Use `main` as the entry point.
- **Scope:** Always declare function variables with `local`.

### 3. Error Handling & Logging
- **Structured Logging:** Use timestamps and log levels (INFO, WARN, ERROR).
- **StdErr:** Print logs and interactive messages to stderr (`>&2`), keeping stdout clean for piping data.
- **Traps:** Use `trap cleanup EXIT` to ensure temporary files/locks are removed, even on failure.

### 4. Input Validation
- **Argument Parsing:** Use a `while` loop with `case` (or `getopts`) to handle flags clearly.
- **Validate Assumptions:** Check if files exist, variables are set, and arguments are valid numbers/strings before proceeding.

### 5. Security
- **Secrets:** Never hardcode secrets. Read them from environment variables or a secure vault.
- **Temp Files:** Use `mktemp` to create secure temporary files with restricted permissions.
- **Sudo:** Avoid using `sudo` inside scripts. Check if `EUID` is 0 if root is required, or let the user invoke the script with `sudo`.

## Common Workflow
1.  **Initialize:** Start with the **Enterprise Script Template** (see PATTERNS.md).
2.  **Plan:** Define the inputs, outputs, and dependencies.
3.  **Implement:** Write functions for distinct tasks (SRP - Single Responsibility Principle).
4.  **Verify:** Run `shellcheck` (if available) to catch common pitfalls.
5.  **Test:** Use "dry-run" logic to test without side effects.

## Quick Reference
- **Check String Empty:** `[[ -z "$var" ]]`
- **Check String Not Empty:** `[[ -n "$var" ]]`
- **File Exists:** `[[ -f "$file" ]]`
- **Dir Exists:** `[[ -d "$dir" ]]`
- **Math:** `(( count++ ))` or `result=$(( a + b ))`
- **Arrays:** `arr=("a" "b"); echo "${arr[0]}"`
