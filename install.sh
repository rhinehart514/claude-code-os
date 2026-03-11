#!/usr/bin/env bash
set -euo pipefail

# install.sh — One-command setup for rhino-os.
# Idempotent — safe to re-run.
#
# Usage:
#   ./install.sh           # install everything
#   ./install.sh --check   # dry-run, show what would happen

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RHINO_DIR="$SCRIPT_DIR"
CLAUDE_DIR="$HOME/.claude"
DRY_RUN=false

for arg in "$@"; do
    case "$arg" in
        --check|--dry-run) DRY_RUN=true ;;
    esac
done

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

action() {
    if $DRY_RUN; then
        echo -e "  ${DIM}[dry-run]${NC} $1"
    else
        echo -e "  ${GREEN}✓${NC} $1"
    fi
}

skip() {
    echo -e "  ${DIM}[skip]${NC} $1 (already exists)"
}

# --- 1. Create directories ---
echo -e "${BOLD}Setting up rhino-os...${NC}"
echo ""

for dir in \
    "$CLAUDE_DIR/state" \
    "$CLAUDE_DIR/state/brains" \
    "$CLAUDE_DIR/knowledge" \
    "$CLAUDE_DIR/knowledge/meta" \
    "$CLAUDE_DIR/knowledge/sessions" \
    "$CLAUDE_DIR/logs" \
    "$CLAUDE_DIR/programs" \
    "$CLAUDE_DIR/agents" \
    "$CLAUDE_DIR/agents/refs" \
    "$CLAUDE_DIR/agents/docs" \
    "$CLAUDE_DIR/commands" \
    "$CLAUDE_DIR/plans"; do
    if [[ ! -d "$dir" ]]; then
        $DRY_RUN || mkdir -p "$dir"
        action "mkdir $dir"
    fi
done

# --- 2. Symlink programs ---
echo ""
echo -e "${BOLD}Programs:${NC}"
for prog in "$RHINO_DIR"/programs/*.md; do
    [[ ! -f "$prog" ]] && continue
    name="$(basename "$prog")"
    target="$CLAUDE_DIR/programs/$name"
    if [[ -L "$target" && "$(readlink "$target")" == "$prog" ]]; then
        skip "programs/$name"
    else
        $DRY_RUN || ln -sf "$prog" "$target"
        action "programs/$name -> $prog"
    fi
done

# --- 3. Symlink agents ---
echo ""
echo -e "${BOLD}Agents:${NC}"
for agent in "$RHINO_DIR"/agents/*.md; do
    [[ ! -f "$agent" ]] && continue
    name="$(basename "$agent")"
    target="$CLAUDE_DIR/agents/$name"
    if [[ -L "$target" && "$(readlink "$target")" == "$agent" ]]; then
        skip "agents/$name"
    else
        $DRY_RUN || ln -sf "$agent" "$target"
        action "agents/$name -> $agent"
    fi
done

# Agent refs
for ref in "$RHINO_DIR"/agents/refs/*.md; do
    [[ ! -f "$ref" ]] && continue
    name="$(basename "$ref")"
    target="$CLAUDE_DIR/agents/refs/$name"
    if [[ -L "$target" && "$(readlink "$target")" == "$ref" ]]; then
        skip "agents/refs/$name"
    else
        $DRY_RUN || ln -sf "$ref" "$target"
        action "agents/refs/$name -> $ref"
    fi
done

# Agent docs
if [[ -d "$RHINO_DIR/agents/docs" ]]; then
    for doc in "$RHINO_DIR"/agents/docs/*.md; do
        [[ ! -f "$doc" ]] && continue
        name="$(basename "$doc")"
        target="$CLAUDE_DIR/agents/docs/$name"
        if [[ -L "$target" && "$(readlink "$target")" == "$doc" ]]; then
            skip "agents/docs/$name"
        else
            $DRY_RUN || ln -sf "$doc" "$target"
            action "agents/docs/$name -> $doc"
        fi
    done
fi

# --- 4. Symlink skills as commands ---
echo ""
echo -e "${BOLD}Skills:${NC}"
for skill_dir in "$RHINO_DIR"/skills/*/; do
    [[ ! -d "$skill_dir" ]] && continue
    skill_name="$(basename "$skill_dir")"
    skill_file="$skill_dir/SKILL.md"
    [[ ! -f "$skill_file" ]] && continue

    cmd_dir="$CLAUDE_DIR/commands/$skill_name"
    cmd_file="$cmd_dir/SKILL.md"

    if [[ -L "$cmd_file" && "$(readlink "$cmd_file")" == "$skill_file" ]]; then
        skip "commands/$skill_name"
    else
        $DRY_RUN || mkdir -p "$cmd_dir"
        $DRY_RUN || ln -sf "$skill_file" "$cmd_file"
        action "commands/$skill_name -> $skill_file"
    fi
done

# --- 5. Symlink hooks to ~/.claude/hooks ---
echo ""
echo -e "${BOLD}Hooks:${NC}"
HOOKS_DIR="$CLAUDE_DIR/hooks"
$DRY_RUN || mkdir -p "$HOOKS_DIR"

for hook in "$RHINO_DIR"/hooks/*.sh; do
    [[ ! -f "$hook" ]] && continue
    name="$(basename "$hook")"
    target="$HOOKS_DIR/$name"
    if [[ -L "$target" && "$(readlink "$target")" == "$hook" ]]; then
        skip "hooks/$name"
    else
        $DRY_RUN || ln -sf "$hook" "$target"
        $DRY_RUN || chmod +x "$hook"
        action "hooks/$name -> $hook"
    fi
done

# --- 6. Symlink bin tools to ~/bin ---
echo ""
echo -e "${BOLD}CLI tools:${NC}"
LOCAL_BIN="$HOME/bin"
$DRY_RUN || mkdir -p "$LOCAL_BIN"

for tool in score.sh taste.mjs gen-dashboard.sh; do
    src="$RHINO_DIR/bin/$tool"
    [[ ! -f "$src" ]] && continue
    dest="$LOCAL_BIN/$tool"
    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
        skip "~/bin/$tool"
    else
        $DRY_RUN || ln -sf "$src" "$dest"
        action "~/bin/$tool -> $src"
    fi
done

# Symlink rhino itself
rhino_dest="$LOCAL_BIN/rhino"
if [[ -L "$rhino_dest" && "$(readlink "$rhino_dest")" == "$RHINO_DIR/bin/rhino" ]]; then
    skip "~/bin/rhino"
else
    $DRY_RUN || ln -sf "$RHINO_DIR/bin/rhino" "$rhino_dest"
    action "~/bin/rhino -> $RHINO_DIR/bin/rhino"
fi

# --- 7. Merge settings.json ---
echo ""
echo -e "${BOLD}Settings:${NC}"
SETTINGS_SRC="$RHINO_DIR/config/settings.json"
SETTINGS_DEST="$CLAUDE_DIR/settings.json"

if [[ -f "$SETTINGS_DEST" ]]; then
    if command -v jq &>/dev/null; then
        if grep -q "session_context.sh" "$SETTINGS_DEST" 2>/dev/null; then
            skip "settings.json (rhino-os hooks already present)"
        else
            $DRY_RUN || {
                tmp="$(mktemp)"
                jq -s '.[0] * .[1]' "$SETTINGS_DEST" "$SETTINGS_SRC" > "$tmp" && mv "$tmp" "$SETTINGS_DEST"
            }
            action "settings.json (merged rhino-os hooks)"
        fi
    else
        echo -e "  ${YELLOW}[warn]${NC} jq not found — cannot merge settings.json. Copy manually."
    fi
else
    $DRY_RUN || cp "$SETTINGS_SRC" "$SETTINGS_DEST"
    action "settings.json (copied)"
fi

# --- 8. Set RHINO_DIR in shell profile ---
echo ""
echo -e "${BOLD}Environment:${NC}"
PROFILE=""
if [[ -f "$HOME/.zshrc" ]]; then
    PROFILE="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
    PROFILE="$HOME/.bashrc"
fi

if [[ -n "$PROFILE" ]]; then
    if grep -q "RHINO_DIR" "$PROFILE" 2>/dev/null; then
        skip "RHINO_DIR in $PROFILE"
    else
        $DRY_RUN || echo "export RHINO_DIR=\"$RHINO_DIR\"" >> "$PROFILE"
        action "RHINO_DIR=$RHINO_DIR added to $PROFILE"
    fi
fi

# --- Done ---
echo ""
if $DRY_RUN; then
    echo -e "${BOLD}Dry run complete.${NC} Run without --check to apply."
else
    echo -e "${BOLD}Done.${NC} Open any project and run ${BLUE}/setup${NC} to onboard it."
    echo ""
    echo -e "${DIM}Reload your shell: source $PROFILE${NC}"
fi
