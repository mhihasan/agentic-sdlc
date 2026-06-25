#!/usr/bin/env bash
set -euo pipefail

# ── MODE DETECTION ────────────────────────────────────────────────────────────
# BASH_SOURCE is unset when piped from curl — use that to detect remote mode.
here=""
if [ -n "${BASH_SOURCE[0]:-}" ]; then
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || here=""
fi
IS_LOCAL=false
[ -n "$here" ] && [ -d "$here/skills" ] && IS_LOCAL=true

# ── INFINITE RE-EXEC GUARD ────────────────────────────────────────────────────
# If we were already re-exec'd from a remote clone and skills/ is still absent,
# the clone is incomplete. Abort instead of looping forever.
if [ "${AGENTIC_SDLC_REMOTE:-}" = "1" ] && [ "$IS_LOCAL" = false ]; then
  echo "agentic-sdlc: install failed — cloned repo at $HOME/.agentic-sdlc is missing the skills/ directory." >&2
  echo "  Fix: rm -rf $HOME/.agentic-sdlc and retry." >&2
  exit 1
fi

if [ "$IS_LOCAL" = false ]; then
  # ── REMOTE MODE: clone/pull, then re-exec local copy ──────────────────────
  if ! command -v git >/dev/null 2>&1; then
    echo "agentic-sdlc: git required. Install git and retry." >&2
    exit 1
  fi

  CLONE_DIR="$HOME/.agentic-sdlc"

  if [ -d "$CLONE_DIR" ] && [ ! -d "$CLONE_DIR/.git" ]; then
    echo "agentic-sdlc: $CLONE_DIR exists but is not a git repo (partial clone?)." >&2
    echo "  Fix: rm -rf $CLONE_DIR and retry." >&2
    exit 1
  elif [ -d "$CLONE_DIR/.git" ]; then
    echo "Updating agentic-sdlc in $CLONE_DIR ..."
    if ! git -C "$CLONE_DIR" pull --ff-only; then
      echo "agentic-sdlc: update failed — local clone may have diverged." >&2
      echo "  Fix: rm -rf $CLONE_DIR and retry." >&2
      exit 1
    fi
  else
    echo "Cloning agentic-sdlc to $CLONE_DIR ..."
    git clone https://github.com/mhihasan/agentic-sdlc "$CLONE_DIR" || { rm -rf "$CLONE_DIR"; exit 1; }
  fi

  # Apply default args if none given
  if [ "$#" -eq 0 ]; then
    set -- --scope=user --tool=all
  fi

  export AGENTIC_SDLC_REMOTE=1
  exec bash "$CLONE_DIR/install.sh" "$@"
fi

# ── LOCAL MODE ────────────────────────────────────────────────────────────────
REPO_DIR="$here"
SKILLS_SRC="$REPO_DIR/skills"
COMMANDS_SRC="$REPO_DIR/commands"

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
      # Real dir — safe to replace only if it looks like a managed skill install
      # (contains SKILL.md). User-created directories without SKILL.md are left alone.
      if [ -f "$dest/SKILL.md" ]; then
        rm -rf "$dest"
        ln -sfn "$skill" "$dest"
        echo "  UPDATED (replaced real dir with symlink): $dest"
        linked=$((linked + 1))
      else
        echo "  SKIP (real dir, no SKILL.md — not a managed install): $dest"
        skipped=$((skipped + 1))
      fi
    else
      ln -sfn "$skill" "$dest"
      echo "  LINKED: $dest"
      linked=$((linked + 1))
    fi
  done

  echo "  → $linked linked, $skipped skipped"
}

link_commands() {
  local target_dir="$1"
  local linked=0 skipped=0

  if [ ! -d "$COMMANDS_SRC" ]; then
    echo "  (no commands/ source directory — skipping)"
    return 0
  fi

  # Broken symlink at target — can't mkdir through it; warn and skip.
  if [ -L "$target_dir" ] && [ ! -d "$target_dir" ]; then
    echo "  SKIP (broken symlink at $target_dir — remove it and re-run to install commands)"
    return 0
  fi

  mkdir -p "$target_dir"

  for cmd in "$COMMANDS_SRC"/*.md; do
    [ -f "$cmd" ] || continue
    name="$(basename "$cmd")"
    dest="$target_dir/$name"

    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
      echo "  SKIP (real file, not a symlink): $dest"
      skipped=$((skipped + 1))
    else
      ln -sfn "$cmd" "$dest"
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
    --*)             echo "Unknown option: $arg" >&2; exit 1 ;;
    /*)              PROJECT_PATH="$arg" ;;
    *)               PROJECT_PATH="$(pwd)/$arg" ;;
  esac
done

echo ""
echo "agentic-sdlc install.sh"
echo "──────────────────────────────────────────────────────"

# ── VALIDATION ────────────────────────────────────────────────────────────────

if [ -z "$SCOPE" ] || [ -z "$TOOL" ]; then
  echo ""
  echo "Usage:"
  echo "  ./install.sh --scope=user    --tool=claude|copilot|all"
  echo "  ./install.sh --scope=project --tool=claude|copilot|all  /path/to/your-project"
  echo ""
  echo "  --tool=claude    Claude Code, OpenCode, Cursor  (~/.claude/skills/ + commands/ or .claude/skills/ + commands/)"
  echo "  --tool=copilot   GitHub Copilot                 (~/.copilot/skills/ + commands/ or .github/skills/ + commands/)"
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
  echo "[claude / user scope] $HOME/.claude/commands/"
  link_commands "$HOME/.claude/commands"
}

install_claude_project() {
  echo ""
  echo "[claude / project scope] $PROJECT_PATH/.claude/skills/"
  link_skills "$PROJECT_PATH/.claude/skills"
  echo "[claude / project scope] $PROJECT_PATH/.claude/commands/"
  link_commands "$PROJECT_PATH/.claude/commands"
}

install_copilot_user() {
  echo ""
  echo "[copilot / user scope] $HOME/.copilot/skills/"
  link_skills "$HOME/.copilot/skills"
  echo "[copilot / user scope] $HOME/.copilot/commands/"
  link_commands "$HOME/.copilot/commands"
}

install_copilot_project() {
  echo ""
  echo "[copilot / project scope] $PROJECT_PATH/.github/skills/"
  link_skills "$PROJECT_PATH/.github/skills"
  echo "[copilot / project scope] $PROJECT_PATH/.github/commands/"
  link_commands "$PROJECT_PATH/.github/commands"
}

case "$TOOL-$SCOPE" in
  claude-user)    install_claude_user ;;
  claude-project) install_claude_project ;;
  copilot-user)   install_copilot_user ;;
  copilot-project) install_copilot_project ;;
  all-user)       install_claude_user; install_copilot_user ;;
  all-project)    install_claude_project; install_copilot_project ;;
esac

echo ""
echo "Done."
