#!/bin/bash
# Post-edit hook: checks Apex files for common anti-patterns
# Runs after every Write/Edit on .cls or .trigger files

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path')

# Only check Apex files
if [[ "$FILE_PATH" != *.cls && "$FILE_PATH" != *.trigger ]]; then
  exit 0
fi

# Skip test classes — they may legitimately have patterns we'd flag
if [[ "$FILE_PATH" == *Test.cls ]]; then
  exit 0
fi

ISSUES=""

# Check for SOQL in loops
if grep -n 'for\s*(' "$FILE_PATH" | head -20 > /dev/null 2>&1; then
  # Look for SOQL keywords near loop constructs
  if awk '/for\s*\(|while\s*\(|do\s*\{/{loop=1} loop && /\[.*SELECT/{print NR": SOQL inside loop: "$0; found=1} /\}/{if(loop) loop--} END{exit !found}' "$FILE_PATH" 2>/dev/null; then
    ISSUES="${ISSUES}\n- SOQL query detected inside a loop"
  fi
fi

# Check for DML in loops
if awk '/for\s*\(|while\s*\(|do\s*\{/{loop=1} loop && /(insert|update|delete|upsert|undelete|merge)\s/{print NR": DML inside loop: "$0; found=1} /\}/{if(loop) loop--} END{exit !found}' "$FILE_PATH" 2>/dev/null; then
  ISSUES="${ISSUES}\n- DML operation detected inside a loop"
fi

# Check for hardcoded IDs (15 or 18 char Salesforce IDs)
if grep -nE "'[a-zA-Z0-9]{15}'|'[a-zA-Z0-9]{18}'" "$FILE_PATH" | grep -vE "Assert|Test|@" > /dev/null 2>&1; then
  ISSUES="${ISSUES}\n- Possible hardcoded Salesforce ID detected"
fi

# Check for missing WITH SECURITY_ENFORCED on SOQL
if grep -n '\[.*SELECT' "$FILE_PATH" | grep -v 'SECURITY_ENFORCED' | grep -v '//' > /dev/null 2>&1; then
  ISSUES="${ISSUES}\n- SOQL query missing WITH SECURITY_ENFORCED"
fi

if [ -n "$ISSUES" ]; then
  cat <<EOF
{
  "decision": "block",
  "reason": "Apex anti-patterns detected in $FILE_PATH:$ISSUES\n\nFix these issues before proceeding."
}
EOF
  exit 2
fi

exit 0
