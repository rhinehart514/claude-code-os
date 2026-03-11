#!/usr/bin/env bash
# session_context.sh — PreToolUse hook: the mind of rhino-os
# Fires once per session (30min cooldown). Not a status dump — an opinionated
# briefing that tells the agent what it should do and why, citing evidence.
# The thinking protocol in action: observe → model → recommend.

# MUST drain stdin first — hook protocol requires it
cat > /dev/null

CLAUDE_DIR="$HOME/.claude"
STATE_DIR="$CLAUDE_DIR/state"
KNOWLEDGE_DIR="$CLAUDE_DIR/knowledge"
LOG_DIR="$CLAUDE_DIR/logs"
MARKER="$STATE_DIR/.session-context-injected"

# Fast exit: if marker exists and is less than 30 minutes old, skip
if [[ -f "$MARKER" ]]; then
    MARKER_AGE=$(( $(date +%s) - $(stat -f %m "$MARKER" 2>/dev/null || stat -c %Y "$MARKER" 2>/dev/null || echo "0") ))
    if (( MARKER_AGE < 1800 )); then
        exit 0
    fi
fi

# Create/update marker
mkdir -p "$STATE_DIR"
date +%s > "$MARKER"

# --- Detect current project ---
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

# --- Assemble session context ---
CONTEXT=""

# 0. Workspace context — show portfolio focus and autonomy level
WORKSPACE_FILE="$STATE_DIR/workspace.json"
if [[ -f "$WORKSPACE_FILE" ]] && command -v jq &>/dev/null; then
    ws_focus=$(jq -r '.focus // empty' "$WORKSPACE_FILE" 2>/dev/null)
    ws_autonomy=$(jq -r --arg pwd "$PROJECT_DIR" \
        '[.projects | to_entries[] | select(.value.path == $pwd or ($pwd | startswith(.value.path + "/")))] | sort_by(.value.path | length) | reverse | .[0].value.autonomy // empty' \
        "$WORKSPACE_FILE" 2>/dev/null)
    ws_experimentation=$(jq -r --arg pwd "$PROJECT_DIR" \
        '[.projects | to_entries[] | select(.value.path == $pwd or ($pwd | startswith(.value.path + "/")))] | sort_by(.value.path | length) | reverse | .[0].value.experimentation // empty' \
        "$WORKSPACE_FILE" 2>/dev/null)
    ws_stage=$(jq -r --arg pwd "$PROJECT_DIR" \
        '[.projects | to_entries[] | select(.value.path == $pwd or ($pwd | startswith(.value.path + "/")))] | sort_by(.value.path | length) | reverse | .[0].value.stage // empty' \
        "$WORKSPACE_FILE" 2>/dev/null)

    # Check session autonomy override
    SESSION_AUTONOMY_FILE="$STATE_DIR/.session-autonomy"
    if [[ -f "$SESSION_AUTONOMY_FILE" ]]; then
        sa_age=$(( $(date +%s) - $(stat -f %m "$SESSION_AUTONOMY_FILE" 2>/dev/null || stat -c %Y "$SESSION_AUTONOMY_FILE" 2>/dev/null || echo "0") ))
        if (( sa_age < 7200 )); then
            ws_autonomy="$(head -1 "$SESSION_AUTONOMY_FILE") (session override)"
        fi
    fi

    if [[ -n "$ws_autonomy" ]]; then
        CONTEXT+="## Workspace
Project: $PROJECT_NAME ($ws_stage) | autonomy: $ws_autonomy | experimentation: $ws_experimentation"
        [[ -n "$ws_focus" && "$ws_focus" != "$PROJECT_NAME" ]] && CONTEXT+=" | portfolio focus: $ws_focus"
        CONTEXT+="
"
    fi
fi

# 1. Last session summary for this project
SESSION_FILE="$KNOWLEDGE_DIR/sessions/${PROJECT_NAME}.md"
if [[ -f "$SESSION_FILE" ]]; then
    # Get last session entry (last ## block) — no tac on macOS
    LAST_SESSION=$(tail -30 "$SESSION_FILE" | awk '/^## /{buf=""} {buf=buf"\n"$0} END{print buf}')
    if [[ -n "$LAST_SESSION" ]]; then
        CONTEXT+="## Last Session ($PROJECT_NAME)
$LAST_SESSION
"
    fi
fi

# 2. Active plan (check project-local first, then global)
PLAN_FILE=""
for plan_path in \
    "$PROJECT_DIR/.claude/plans/active-plan.md" \
    "$CLAUDE_DIR/plans/active-plan.md"; do
    if [[ -f "$plan_path" ]]; then
        PLAN_FILE="$plan_path"
        break
    fi
done
if [[ -n "$PLAN_FILE" ]]; then
    # First 5 lines of the plan for quick context
    PLAN_HEADER=$(head -5 "$PLAN_FILE")
    CONTEXT+="
## Active Plan
$PLAN_HEADER
(full plan at $PLAN_FILE)
"
else
    # Phase 3: If no plan but learning agenda exists, show it instead (self-terminating)
    LEARNING_AGENDA="$PROJECT_DIR/.claude/plans/learning-agenda.md"
    if [[ -f "$LEARNING_AGENDA" ]]; then
        # Check if graduation criteria are all met — if so, stop showing
        unchecked=$(grep -c '^\- \[ \]' "$LEARNING_AGENDA" 2>/dev/null || echo "0")
        if [[ "$unchecked" -gt 0 ]]; then
            AGENDA_HEADER=$(head -8 "$LEARNING_AGENDA")
            CONTEXT+="
## Learning Agenda (no active plan yet)
$AGENDA_HEADER
($unchecked graduation criteria remaining — full agenda at $LEARNING_AGENDA)
Run /experiment to start learning (NOT /strategy yet).
"
        fi
    fi
fi

# 2b. Latest taste eval (visual product quality — feeds into builder)
TASTE_REPORT=""
for taste_dir in "$PROJECT_DIR/.claude/evals/reports" "$PROJECT_DIR/docs/evals/reports"; do
    if [[ -d "$taste_dir" ]]; then
        TASTE_REPORT=$(ls -t "$taste_dir"/taste-*.json 2>/dev/null | head -1)
        [[ -n "$TASTE_REPORT" ]] && break
    fi
done
if [[ -n "$TASTE_REPORT" ]] && command -v jq &>/dev/null; then
    taste_score=$(jq -r '.score_100 // empty' "$TASTE_REPORT" 2>/dev/null)
    taste_weakest=$(jq -r '.weakest_dimension // empty' "$TASTE_REPORT" 2>/dev/null)
    taste_one_thing=$(jq -r '.one_thing // empty' "$TASTE_REPORT" 2>/dev/null)
    taste_return=$(jq -r '.would_return // empty' "$TASTE_REPORT" 2>/dev/null)
    taste_recommend=$(jq -r '.would_recommend // empty' "$TASTE_REPORT" 2>/dev/null)
    taste_date=$(jq -r '.meta.timestamp // empty' "$TASTE_REPORT" 2>/dev/null | head -c10)
    # Taste integrity warnings (from last eval)
    taste_warnings=$(jq -r '.integrity_warnings // [] | .[]' "$TASTE_REPORT" 2>/dev/null)

    if [[ -n "$taste_score" ]]; then
        CONTEXT+="
## Taste Eval ($taste_date): ${taste_score}/100"
        [[ -n "$taste_weakest" ]] && CONTEXT+=" · weakest: $taste_weakest"
        [[ -n "$taste_return" ]] && CONTEXT+="
Return? $taste_return"
        [[ -n "$taste_recommend" ]] && CONTEXT+="
Recommend? $taste_recommend"
        [[ -n "$taste_one_thing" ]] && CONTEXT+="
One thing: $taste_one_thing"

        # Taste trend from taste-history.tsv
        TASTE_HISTORY=""
        for th_dir in "$PROJECT_DIR/.claude/evals" "$PROJECT_DIR/docs/evals"; do
            if [[ -f "$th_dir/taste-history.tsv" ]]; then
                TASTE_HISTORY="$th_dir/taste-history.tsv"
                break
            fi
        done
        if [[ -n "$TASTE_HISTORY" ]]; then
            taste_eval_count=$(tail -n +2 "$TASTE_HISTORY" | grep -cv '^$' 2>/dev/null || echo "0")
            if [[ "$taste_eval_count" -gt 1 ]]; then
                # Compare first and last overall scores to determine direction
                first_overall=$(tail -n +2 "$TASTE_HISTORY" | head -1 | cut -f2)
                last_overall=$(tail -1 "$TASTE_HISTORY" | cut -f2)
                if [[ -n "$first_overall" && -n "$last_overall" ]]; then
                    if awk "BEGIN { exit !($last_overall > $first_overall) }" 2>/dev/null; then
                        taste_direction="improving"
                    elif awk "BEGIN { exit !($last_overall < $first_overall) }" 2>/dev/null; then
                        taste_direction="declining"
                    else
                        taste_direction="flat"
                    fi
                    CONTEXT+="
Taste trend: $taste_direction ($taste_eval_count evals, $first_overall -> $last_overall)"
                fi
            fi

            # Show weakest feature if features.yml exists
            FEATURES_YML=""
            for fy in "$PROJECT_DIR/.claude/features.yml" "$PROJECT_DIR/.claude/features.yaml"; do
                [[ -f "$fy" ]] && FEATURES_YML="$fy" && break
            done
            if [[ -n "$FEATURES_YML" ]]; then
                # Get the most recent feature-specific eval (non-"all")
                weakest_feature=$(tail -n +2 "$TASTE_HISTORY" | awk -F'\t' '$5 != "all" && $5 != "" {print $5, $2}' | sort -k2 -n | head -1 | cut -d' ' -f1)
                if [[ -n "$weakest_feature" ]]; then
                    CONTEXT+="
Weakest feature: $weakest_feature"
                fi
            fi
        fi

        # Surface taste integrity warnings in session context
        if [[ -n "$taste_warnings" ]]; then
            CONTEXT+="
⚠ Taste Integrity: $taste_warnings
Taste scores with integrity warnings should not drive decisions until re-evaluated."
        fi

        CONTEXT+="
"
    fi
fi

# 3. Taste profile summary (top signals by strength)
TASTE_FILE="$KNOWLEDGE_DIR/taste.jsonl"
if [[ -f "$TASTE_FILE" ]] && command -v jq &>/dev/null; then
    STRONG_SIGNALS=$(grep '"strong"' "$TASTE_FILE" 2>/dev/null | jq -r '.signal' 2>/dev/null | head -5)
    if [[ -n "$STRONG_SIGNALS" ]]; then
        CONTEXT+="
## Founder Taste (strong signals)
$STRONG_SIGNALS
"
    fi
fi

# 3b. Taste knowledge summary — show which dimensions have researched knowledge
TASTE_KNOWLEDGE_DIR="$KNOWLEDGE_DIR/taste-knowledge"
if [[ -d "$TASTE_KNOWLEDGE_DIR" ]]; then
    INDEX_FILE="$TASTE_KNOWLEDGE_DIR/_index.md"
    if [[ -f "$INDEX_FILE" ]]; then
        researched_count=0
        stale_count=0
        for dim_file in "$TASTE_KNOWLEDGE_DIR"/*.md; do
            [[ "$(basename "$dim_file")" == "_index.md" ]] && continue
            [[ ! -f "$dim_file" ]] && continue
            researched_count=$((researched_count + 1))
            # Check staleness (>14 days since last modified)
            dim_age=$(( ($(date +%s) - $(stat -f %m "$dim_file" 2>/dev/null || stat -c %Y "$dim_file" 2>/dev/null || echo "0")) / 86400 ))
            if (( dim_age > 14 )); then
                stale_count=$((stale_count + 1))
            fi
        done
        if (( researched_count > 0 )); then
            CONTEXT+="
## Taste Knowledge: ${researched_count}/11 dimensions researched"
            if (( stale_count > 0 )); then
                CONTEXT+=" (${stale_count} stale — run /research-taste stale)"
            fi
            CONTEXT+="
"
        fi
    fi
fi

# 3c. Founder taste preferences (structured, persistent)
FOUNDER_TASTE_FILE="$KNOWLEDGE_DIR/founder-taste.md"
if [[ -f "$FOUNDER_TASTE_FILE" ]]; then
    # Count preferences (lines starting with "- [")
    pref_count=$(grep -c '^\- \[' "$FOUNDER_TASTE_FILE" 2>/dev/null || echo "0")
    # Show strong preferences
    strong_prefs=$(grep -A1 'Strength: strong' "$FOUNDER_TASTE_FILE" 2>/dev/null | grep '^\- ' | head -3)
    if [[ "$pref_count" -gt 0 ]]; then
        CONTEXT+="
## Founder Taste: ${pref_count} preferences captured"
        if [[ -n "$strong_prefs" ]]; then
            CONTEXT+="
$strong_prefs"
        fi
        CONTEXT+="
"
    fi
fi

# 4. Portfolio focus
PORTFOLIO_FILE="$KNOWLEDGE_DIR/portfolio.json"
if [[ -f "$PORTFOLIO_FILE" ]] && command -v jq &>/dev/null; then
    FOCUS=$(jq -r '.focus.primary // empty' "$PORTFOLIO_FILE" 2>/dev/null)
    if [[ -n "$FOCUS" ]]; then
        CONTEXT+="
## Portfolio Focus: $FOCUS
"
    fi
fi

# 5. Sweep state (if recent)
SWEEP_FILE="$STATE_DIR/sweep-latest.md"
if [[ -f "$SWEEP_FILE" ]]; then
    SWEEP_AGE=$(( ( $(date +%s) - $(stat -f %m "$SWEEP_FILE" 2>/dev/null || stat -c %Y "$SWEEP_FILE" 2>/dev/null || echo "0") ) / 3600 ))
    if (( SWEEP_AGE < 48 )); then
        SWEEP_HEADER=$(head -3 "$SWEEP_FILE")
        CONTEXT+="
## Recent Sweep (${SWEEP_AGE}h ago)
$SWEEP_HEADER
"
    fi
fi

# 5b. Prediction accuracy (the system's learning signal)
PREDICTIONS_FILE="$KNOWLEDGE_DIR/predictions.tsv"
if [[ -f "$PREDICTIONS_FILE" ]]; then
    pred_total=$(tail -n +2 "$PREDICTIONS_FILE" | grep -cv '^$' 2>/dev/null || echo "0")
    if [[ "$pred_total" -gt 0 ]]; then
        pred_correct=$(tail -n +2 "$PREDICTIONS_FILE" | awk -F'\t' '$6 == "yes"' | wc -l | tr -d ' ')
        pred_pct=$(( pred_correct * 100 / pred_total ))
        CONTEXT+="
## Prediction Accuracy: ${pred_correct}/${pred_total} (${pred_pct}%)"
        if [[ "$pred_pct" -gt 90 ]]; then
            CONTEXT+=" — too safe, make riskier calls"
        elif [[ "$pred_pct" -lt 30 ]]; then
            CONTEXT+=" — model may be broken"
        fi
        CONTEXT+="
"
    fi
fi

# 5c. Agent Suggestions — show each agent's next_move + bias_awareness (Phase 4: cross-agent knowledge)
BRAINS_DIR="$STATE_DIR/brains"
if [[ -d "$BRAINS_DIR" ]] && command -v jq &>/dev/null; then
    SUGGESTIONS=""
    LATEST_TS="0"
    for brain_file in "$BRAINS_DIR"/*.json; do
        [[ ! -f "$brain_file" ]] && continue
        ba=$(jq -r '.agent // ""' "$brain_file" 2>/dev/null)
        baction=$(jq -r '.next_move // "" | if type == "object" then .action // "" else . end' "$brain_file" 2>/dev/null || true)
        bbias=$(jq -r '.bias_awareness // "" | if type == "object" then .warning // "" else . end' "$brain_file" 2>/dev/null || true)
        bupdated=$(jq -r '.updated // ""' "$brain_file" 2>/dev/null || true)
        if [[ -n "$baction" && "$baction" != "null" && "$baction" != "" ]]; then
            SUGGESTIONS+="- ${ba}: ${baction}"
            [[ -n "$bbias" && "$bbias" != "null" && "$bbias" != "" ]] && SUGGESTIONS+=" [bias: ${bbias}]"
            SUGGESTIONS+="
"
        fi
    done
    if [[ -n "$SUGGESTIONS" ]]; then
        CONTEXT+="
## Agent Suggestions
${SUGGESTIONS}"
    fi
fi

# 5d. Thinking health feedback (Phase 1: cross-session prediction enforcement)
THINKING_HEALTH_FILE="$LOG_DIR/thinking-health.tsv"
if [[ -f "$THINKING_HEALTH_FILE" ]]; then
    th_last=$(tail -1 "$THINKING_HEALTH_FILE")
    th_pred_rate=$(echo "$th_last" | awk -F'\t' '{print $7}')
    th_edits=$(echo "$th_last" | awk -F'\t' '{print $2}')
    if [[ "$th_pred_rate" == "0" && "$th_edits" -gt 5 ]] 2>/dev/null; then
        CONTEXT+="
## Thinking Health
Last session: ${th_edits} edits, 0 predictions. The thinking protocol is not active.
Read \`agents/refs/thinking.md\` — predict before you act.
"
    fi
fi

# 5e. Learning engine health (Phase 5: meta learning health surfaced)
GRADES_FILE="$KNOWLEDGE_DIR/meta/grades.jsonl"
if [[ -f "$GRADES_FILE" ]] && command -v jq &>/dev/null; then
    lh_line=$(tail -5 "$GRADES_FILE" | grep 'learning_health' | tail -1)
    if [[ -n "$lh_line" ]]; then
        lh_pred=$(echo "$lh_line" | jq -r '.learning_health.prediction_volume // "?"' 2>/dev/null)
        lh_discard=$(echo "$lh_line" | jq -r '.learning_health.discard_rate // "?"' 2>/dev/null)
        lh_status=$(echo "$lh_line" | jq -r '.learning_health.status // ""' 2>/dev/null)
        CONTEXT+="
## Learning Engine: pred ${lh_pred} | discard ${lh_discard}"
        if [[ "$lh_status" == "CRITICAL" || ("$lh_pred" == "0%" && "$lh_discard" == "0%") ]]; then
            CONTEXT+=" — DEAD. Predict before acting. Discard bad experiments."
        fi
        CONTEXT+="
"
    fi
fi

# 6. Eval state — check project-local eval history first, then global
EVAL_HISTORY=""
for eval_path in \
    "$PROJECT_DIR/.claude/evals/reports/history.jsonl" \
    "$PROJECT_DIR/docs/evals/reports/history.jsonl" \
    "$CLAUDE_DIR/evals/reports/history.jsonl"; do
    if [[ -f "$eval_path" ]]; then
        EVAL_HISTORY="$eval_path"
        break
    fi
done

if [[ -n "$EVAL_HISTORY" ]] && command -v jq &>/dev/null; then
    # Get latest eval entry
    LATEST_EVAL=$(tail -1 "$EVAL_HISTORY")
    if [[ -n "$LATEST_EVAL" ]]; then
        eval_verdict=$(echo "$LATEST_EVAL" | jq -r '.verdict // empty' 2>/dev/null)
        eval_feature=$(echo "$LATEST_EVAL" | jq -r '.feature // empty' 2>/dev/null)
        eval_date=$(echo "$LATEST_EVAL" | jq -r '.date // empty' 2>/dev/null)
        eval_type=$(echo "$LATEST_EVAL" | jq -r '.type // "feature-eval"' 2>/dev/null)

        if [[ -n "$eval_verdict" ]]; then
            CONTEXT+="
## Latest Eval ($eval_date)
$eval_feature · $eval_verdict"

            # For product evals, show key scores dynamically
            if [[ "$eval_type" == "product-eval" ]]; then
                overall=$(echo "$LATEST_EVAL" | jq -r '.overall // empty' 2>/dev/null)
                CONTEXT+=" · overall: $overall"
                # Show lowest-scoring dimensions (the bottlenecks)
                lowest=$(echo "$LATEST_EVAL" | jq -r 'to_entries | map(select(.value | type == "number" and . <= 1 and . >= 0)) | map(select(.key | IN("date","overall","type","feature") | not)) | sort_by(.value) | .[0:3] | map("\(.key): \(.value)") | join(" · ")' 2>/dev/null)
                [[ -n "$lowest" ]] && CONTEXT+=" · $lowest"
            else
                ceiling=$(echo "$LATEST_EVAL" | jq -r '.ceiling // empty' 2>/dev/null)
                [[ -n "$ceiling" ]] && CONTEXT+=" · ceiling: $ceiling"
            fi

            # Show top gaps (the most important part — what to fix)
            top_gaps=$(echo "$LATEST_EVAL" | jq -r '(.top_gaps // .ceiling_gaps // [])[:3][]' 2>/dev/null)
            if [[ -n "$top_gaps" ]]; then
                CONTEXT+="
Gaps: $top_gaps"
            fi
            CONTEXT+="
"
        fi
    fi
fi

# 7. Active experiments — show branches and recent results
EXP_BRANCHES=$(git -C "$PROJECT_DIR" branch 2>/dev/null | grep 'exp/' | sed 's/^[* ]*//' | head -5)
if [[ -n "$EXP_BRANCHES" ]]; then
    CONTEXT+="
## Active Experiments"
    while read -r branch; do
        commit_count=$(git -C "$PROJECT_DIR" rev-list --count "main..$branch" 2>/dev/null || echo "?")
        CONTEXT+="
$branch ($commit_count commits)"
    done <<< "$EXP_BRANCHES"
    CONTEXT+="
"
fi

# Check for experiment TSVs
for exp_dir in "$PROJECT_DIR/.claude/experiments" "$PROJECT_DIR/docs/experiments"; do
    if [[ -d "$exp_dir" ]]; then
        for tsv in "$exp_dir"/*.tsv; do
            [[ -f "$tsv" ]] || continue
            ename=$(basename "$tsv" .tsv)
            ekept=$(grep -c 'keep' "$tsv" 2>/dev/null || echo "0")
            etotal=$(tail -n +2 "$tsv" | grep -cv '^---\|^$' 2>/dev/null || echo "0")
            elast=$(tail -1 "$tsv" | cut -f4-5 2>/dev/null)
            CONTEXT+="
## Experiment: $ename — $ekept/$etotal kept, last: $elast"
        done
        break
    fi
done

# 8. Score integrity warnings (from last score run)
for cache_path in "$PROJECT_DIR/.claude/cache/score-cache.json"; do
    if [[ -f "$cache_path" ]] && command -v jq &>/dev/null; then
        warnings=$(jq -r '.integrity_warnings // [] | .[]' "$cache_path" 2>/dev/null)
        if [[ -n "$warnings" ]]; then
            CONTEXT+="
## Score Integrity Warnings
$warnings
Scores are diagnostic instruments, not goals. Address warnings before chasing numbers.
"
        fi
    fi
done

# 9. Compaction timing guidance
# Prevents the common failure of compacting mid-implementation and losing context
TOOL_COUNT=0
if [[ -f "$LOG_DIR/usage.jsonl" ]]; then
    thirty_min_ago=$(date -u -v-30M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")
    if [[ -n "$thirty_min_ago" ]]; then
        TOOL_COUNT=$(awk -v cutoff="$thirty_min_ago" '
            { if (match($0, /"ts":"[^"]+"/)) { ts=substr($0,RSTART+6,RLENGTH-7); if (ts>=cutoff) c++ } }
            END { print c+0 }
        ' "$LOG_DIR/usage.jsonl")
    fi
fi
if (( TOOL_COUNT > 50 )); then
    CONTEXT+="
## Context Window
${TOOL_COUNT} tool calls this session. Consider compacting — but:
- Do NOT compact during active implementation (you lose variable names, file paths, intermediate reasoning)
- Compact AFTER: research phase, planning→implementation transition, debugging sessions, abandoned approaches
- After compacting: re-read active plan + relevant files before continuing
"
fi

# 10. Cost awareness — show session patterns if cost-history exists
COST_FILE="$LOG_DIR/cost-history.tsv"
if [[ -f "$COST_FILE" ]]; then
    last_session_agents=$(tail -1 "$COST_FILE" | cut -f7 2>/dev/null || echo "0")
    if [[ "$last_session_agents" -gt 5 ]]; then
        CONTEXT+="
## Cost Note
Last session spawned ${last_session_agents} agents. Consider if all were necessary.
"
    fi
fi

# 11. Graduated patterns (from extract_patterns.sh)
PATTERNS_FILE="$KNOWLEDGE_DIR/patterns.tsv"
if [[ -f "$PATTERNS_FILE" ]]; then
    hot_files=$(awk -F'\t' '$2 == "hot_file" && $6 == "confirmed" { print $1 }' "$PATTERNS_FILE" 2>/dev/null | head -5)
    if [[ -n "$hot_files" ]]; then
        CONTEXT+="
## Hot Files (edited frequently across sessions)
$hot_files
"
    fi
fi

# 12. Context documents — first line of each documents/*.md
DOCS_DIR="$PROJECT_DIR/documents"
if [[ -d "$DOCS_DIR" ]]; then
    DOC_SUMMARIES=""
    for doc in "$DOCS_DIR"/*.md; do
        [[ ! -f "$doc" ]] && continue
        doc_name=$(basename "$doc" .md)
        # Skip HTML comment header, get first real content line
        doc_header=$(grep -v '^<!--' "$doc" | grep -v '^$' | head -1 | sed 's/^# //')
        [[ -n "$doc_header" ]] && DOC_SUMMARIES+="- $doc_name: $doc_header
"
    done
    if [[ -n "$DOC_SUMMARIES" ]]; then
        CONTEXT+="
## Project Context (documents/)
$DOC_SUMMARIES"
    fi
fi

# 13. Continuous build state (from rhino go)
GO_STATE="$PROJECT_DIR/.claude/state/go-state.json"
if [[ -f "$GO_STATE" ]] && command -v jq &>/dev/null; then
    go_iteration=$(jq -r '.iteration // 0' "$GO_STATE" 2>/dev/null)
    go_focus=$(jq -r '.focus // "none"' "$GO_STATE" 2>/dev/null)
    go_last_score=$(jq -r '.last_score // 0' "$GO_STATE" 2>/dev/null)
    go_updated=$(jq -r '.last_updated // ""' "$GO_STATE" 2>/dev/null | head -c10)
    if [[ "$go_iteration" -gt 0 ]]; then
        CONTEXT+="
## Continuous Build ($go_updated)
Iteration $go_iteration | score: $go_last_score | focus: $go_focus
"
    fi
fi

# 14. The Mind — opinionated recommendation based on all signals
# This is what makes rhino-os proactive, not just informative.
RECOMMENDATION=""
LEARNINGS_FILE="$KNOWLEDGE_DIR/experiment-learnings.md"

# Determine what to recommend based on priority
if [[ -n "$warnings" && "$warnings" != "" ]]; then
    # Integrity warnings = highest priority
    RECOMMENDATION="Integrity warnings active. Fix scoring honesty before building anything."
elif [[ -n "$taste_score" ]] && (( ${taste_score%%.*} < 30 )); then
    # Taste critically low
    if [[ -f "$LEARNINGS_FILE" ]]; then
        # Pull the highest-confidence pattern from learnings
        top_pattern=$(grep -A1 "Known Patterns\|high confidence" "$LEARNINGS_FILE" 2>/dev/null | grep "^- " | head -1 | sed 's/^- //')
        [[ -n "$top_pattern" ]] && RECOMMENDATION="Taste at ${taste_score}/100. Known pattern to try: ${top_pattern}"
    fi
    [[ -z "$RECOMMENDATION" ]] && RECOMMENDATION="Taste at ${taste_score}/100. Run strategy to diagnose the bottleneck."
elif [[ -n "$taste_weakest" && "$taste_weakest" != "null" ]]; then
    # We know the weakest dimension — recommend targeting it
    # Check if learnings have something relevant
    if [[ -f "$LEARNINGS_FILE" ]]; then
        relevant=$(grep -i "$taste_weakest" "$LEARNINGS_FILE" 2>/dev/null | head -1)
        if [[ -n "$relevant" ]]; then
            RECOMMENDATION="Weakest: ${taste_weakest}. Learnings say: $(echo "$relevant" | sed 's/^- //' | head -c 120)"
        else
            unknown_check=$(grep -c "Unknown Territory" "$LEARNINGS_FILE" 2>/dev/null || echo "0")
            if (( unknown_check > 0 )); then
                RECOMMENDATION="Weakest: ${taste_weakest}. No learnings on this dimension — explore it. High information value."
            else
                RECOMMENDATION="Weakest: ${taste_weakest}. Target this dimension."
            fi
        fi
    else
        RECOMMENDATION="Weakest: ${taste_weakest}. Target this dimension."
    fi
fi

# If predictions exist, add calibration note
if [[ -f "$PREDICTIONS_FILE" ]]; then
    pred_total_rec=$(tail -n +2 "$PREDICTIONS_FILE" | grep -cv '^$' 2>/dev/null || echo "0")
    if [[ "$pred_total_rec" -eq 0 ]]; then
        RECOMMENDATION="${RECOMMENDATION:+$RECOMMENDATION | }No predictions logged yet. Start predicting outcomes before acting."
    fi
fi

# Add recommendation to context
if [[ -n "$RECOMMENDATION" ]]; then
    CONTEXT="## rhino-os recommends
${RECOMMENDATION}
Read \`agents/refs/thinking.md\` — predict before you act. Cite evidence or explore.

${CONTEXT}"
fi

# After compaction guidance — re-read thinking protocol
CONTEXT+="
## After Compaction
Re-read: (1) \`agents/refs/thinking.md\`, (2) active plan, (3) \`~/.claude/knowledge/experiment-learnings.md\`, (4) relevant files. The model resets on compaction — rebuild it from these files.
"

# Only output if we have meaningful context
if [[ -n "$CONTEXT" ]]; then
    echo "--- rhino-os ---"
    echo "$CONTEXT"
    echo "---"
fi

exit 0
