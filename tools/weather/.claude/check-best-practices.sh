#!/bin/bash

# Read the tool data from stdin
TOOL_DATA=$(cat)

# Extract tool name
TOOL_NAME=$(echo "$TOOL_DATA" | jq -r '.tool_name')

# State file to track if best_practices was checked
# Store checkpoint in .claude folder for persistence
STATE_FILE="$PWD/.claude/best_practices_checkpoint"

# Delete checkpoint if it's older than 10 minutes (600 seconds)
# This ensures fresh context in each session
if [[ -f "$STATE_FILE" ]]; then
    FILE_AGE=$(($(date +%s) - $(stat -c %Y "$STATE_FILE" 2>/dev/null || stat -f %m "$STATE_FILE" 2>/dev/null)))
    if [[ $FILE_AGE -gt 600 ]]; then
        rm -f "$STATE_FILE"
    fi
fi

# If this is a best_practices tool call, mark it as checked
if [[ "$TOOL_NAME" == "mcp__best_practices__get_best_practices" ]]; then
    touch "$STATE_FILE"
    exit 0
fi

# If this is an Edit or Write tool, check if best_practices was consulted
if [[ "$TOOL_NAME" == "Edit" ]] || [[ "$TOOL_NAME" == "Write" ]]; then
    if [[ ! -f "$STATE_FILE" ]]; then
        # Best practices not checked, block the operation
        echo "ERROR: You must check the best_practices MCP server before making code changes." >&2
        echo "Please use mcp__best_practices__get_best_practices to check relevant best practices first." >&2
        exit 2  # Exit code 2 blocks the tool use
    fi
    # Best practices was checked, allow the operation (checkpoint persists)
    exit 0
fi

# For all other tools, allow
exit 0
