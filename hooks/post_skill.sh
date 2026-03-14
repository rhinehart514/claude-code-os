#!/usr/bin/env bash
# post_skill.sh — PostToolUse hook for Edit/Write on skill output artifacts
# Validates schema of .claude/plans/ files after skills write them.
# Warns (never blocks). Must be fast (<200ms).

INPUT="$(cat)"
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"

[[ -z "$FILE_PATH" ]] && exit 0
[[ ! -f "$FILE_PATH" ]] && exit 0

# Only validate skill output artifacts in .claude/plans/
[[ "$FILE_PATH" != *".claude/plans/"* ]] && exit 0

BASENAME="$(basename "$FILE_PATH")"
WARNINGS=""

case "$BASENAME" in
    active-plan.md)
        # Check for unchecked tasks
        task_count=$(grep -c '^\- \[' "$FILE_PATH" 2>/dev/null || echo "0")
        unchecked=$(grep -c '^\- \[ \]' "$FILE_PATH" 2>/dev/null || echo "0")

        if (( task_count == 0 )); then
            WARNINGS+="⚠ active-plan.md has no tasks (expected - [ ] items).
"
        fi

        # Check for Value: field (v6 format) — warn if tasks exist but none have Value:
        if (( unchecked > 0 )); then
            value_count=$(grep -c '^\s*Value:' "$FILE_PATH" 2>/dev/null || echo "0")
            if (( value_count == 0 )); then
                WARNINGS+="⚠ active-plan.md tasks missing Value: field — every task should articulate user value.
"
            fi
        fi
        ;;

    product-model.md)
        # Must have a bottleneck section
        if ! grep -q '## .*[Bb]ottleneck\|[Bb]ottleneck.*:' "$FILE_PATH" 2>/dev/null; then
            WARNINGS+="⚠ product-model.md missing bottleneck diagnosis — /plan can't find the constraint.
"
        fi
        ;;

    learning-agenda.md)
        # Validate learning-agenda has at least one unknown listed
        unknown_count=$(sed -n '/What We Don.*Know/,/^## \|^#.*Experiment\|^#.*First/p' "$FILE_PATH" 2>/dev/null | grep -cE '^\s*[0-9]+\.' || echo "0")
        if (( unknown_count == 0 )); then
            WARNINGS+="⚠ learning-agenda.md has no unknowns in 'What We Don't Know' section.
"
        fi
        ;;
esac

if [[ -n "$WARNINGS" ]]; then
    echo "--- skill artifact validation ---"
    echo "$WARNINGS"
    echo "--- end validation ---"
fi

exit 0
