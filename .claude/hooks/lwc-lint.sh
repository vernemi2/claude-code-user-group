#!/bin/bash
# Post-edit hook: runs ESLint on LWC JavaScript files

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path')

# Only check LWC JS files
if [[ "$FILE_PATH" != */lwc/*.js ]]; then
  exit 0
fi

# Skip test files
if [[ "$FILE_PATH" == *__tests__* ]]; then
  exit 0
fi

# Run ESLint
cd "$(echo "$INPUT" | jq -r '.cwd')"
OUTPUT=$(npx eslint "$FILE_PATH" 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  cat <<EOF
{
  "decision": "block",
  "reason": "ESLint errors in $FILE_PATH:\n$OUTPUT\n\nFix these issues before proceeding."
}
EOF
  exit 2
fi

exit 0
