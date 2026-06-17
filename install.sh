#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"

# ── HELPERS ───────────────────────────────────────────────────────────────────

link_skills() {
  local target_dir="$1"
  local linked=0 skipped=0

  mkdir -p "$target_dir"

  for skill in "$SKILLS_SRC"/*/; do
    [ -d "$skill" ] || continue
    name="$(basename "$skill")"
    dest="$target_dir/$name"

    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
      echo "  SKIP (real dir, not a symlink): $dest"
      skipped=$((skipped + 1))
    else
      ln -sfn "$skill" "$dest"
      echo "  LINKED: $dest"
      linked=$((linked + 1))
    fi
  done

  echo "  → $linked linked, $skipped skipped"
}

# ── ARGUMENT PARSING ──────────────────────────────────────────────────────────

SCOPE=""
TOOL=""
PROJECT_PATH=""

for arg in "$@"; do
  case "$arg" in
    --scope=user)    SCOPE="user" ;;
    --scope=project) SCOPE="project" ;;
    --tool=claude)   TOOL="claude" ;;
    --tool=copilot)  TOOL="copilot" ;;
    --tool=all)      TOOL="all" ;;
    /*)              PROJECT_PATH="$arg" ;;
    *)               PROJECT_PATH="$(pwd)/$arg" ;;
  esac
done

echo ""
echo "agentic-skills install.sh"
echo "──────────────────────────────────────────────────────"

# ── VALIDATION ────────────────────────────────────────────────────────────────

if [ -z "$SCOPE" ] || [ -z "$TOOL" ]; then
  echo ""
  echo "Usage:"
  echo "  ./install.sh --scope=user    --tool=claude|copilot|all"
  echo "  ./install.sh --scope=project --tool=claude|copilot|all  /path/to/your-project"
  echo ""
  echo "  --tool=claude    Claude Code, OpenCode, Cursor  (~/.claude/skills/ or .claude/skills/)"
  echo "  --tool=copilot   GitHub Copilot                 (~/.copilot/skills/ or .github/skills/)"
  echo "  --tool=all       Both tools"
  echo ""
  echo "  --scope=user     Install globally, available in all projects"
  echo "  --scope=project  Install into the given project directory only"
  echo ""
  exit 1
fi

if [ "$SCOPE" = "project" ] && [ -z "$PROJECT_PATH" ]; then
  echo ""
  echo "Error: --scope=project requires a project path."
  echo "Usage: ./install.sh --scope=project --tool=<tool> /path/to/your-project"
  echo ""
  exit 1
fi

if [ "$SCOPE" = "project" ] && [ ! -d "$PROJECT_PATH" ]; then
  echo ""
  echo "Error: project path does not exist: $PROJECT_PATH"
  echo ""
  exit 1
fi

# ── INSTALL ───────────────────────────────────────────────────────────────────

install_claude_user() {
  echo ""
  echo "[claude / user scope] $HOME/.claude/skills/"
  link_skills "$HOME/.claude/skills"
}

install_claude_project() {
  echo ""
  echo "[claude / project scope] $PROJECT_PATH/.claude/skills/"
  link_skills "$PROJECT_PATH/.claude/skills"
}

install_copilot_user() {
  echo ""
  echo "[copilot / user scope] $HOME/.copilot/skills/"
  link_skills "$HOME/.copilot/skills"
}

install_copilot_project() {
  echo ""
  echo "[copilot / project scope] $PROJECT_PATH/.github/skills/"
  link_skills "$PROJECT_PATH/.github/skills"
}

case "$TOOL-$SCOPE" in
  claude-user)    install_claude_user ;;
  claude-project) install_claude_project ;;
  copilot-user)   install_copilot_user ;;
  copilot-project) install_copilot_project ;;
  all-user)       install_claude_user; install_copilot_user ;;
  all-project)    install_claude_project; install_copilot_project ;;
esac

# ── DEPENDENCY CHECK ──────────────────────────────────────────────────────────

SUPERPOWERS_DIR="$HOME/.claude/plugins/cache/claude-plugins-official/superpowers"
if [ ! -d "$SUPERPOWERS_DIR" ]; then
  echo ""
  echo "WARNING: superpowers plugin not found at $SUPERPOWERS_DIR"
  echo "  This workflow composes superpowers skills at several pipeline steps:"
  echo "  test-driven-development, systematic-debugging, verification-before-completion,"
  echo "  using-git-worktrees, dispatching-parallel-agents, finishing-a-development-branch."
  echo "  Install it in Claude Code:"
  echo "    /plugin install superpowers@claude-plugins-official"
  echo "  Or visit: https://claude.com/plugins/superpowers"
fi

echo ""
echo "Note: agentic-skills contains engineering craft skills only."
echo "For personal skills (voice, career, interview prep), also install:"
echo "  https://github.com/mhihasan/exocortex"
echo ""
echo "Done."
