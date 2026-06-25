#!/usr/bin/env bash
# Construct the git state for: crafting-commits → halts-without-reviewing-code-stamp (gate).
# A feature branch with commits ahead of the default branch, but NO reviewing-code stamp in
# REVIEW-LOG.md. crafting-commits must HALT at input validation.
set -euo pipefail
DIR="${1:?usage: SETUP.sh <scratch-dir>}"
rm -rf "$DIR"; mkdir -p "$DIR"; cd "$DIR"
git init -q -b main
git config user.email eval@brightcart.test; git config user.name "Eval Bot"
echo "# BrightCart" > README.md
git add README.md; git commit -qm "chore: init"
git checkout -q -b feat/SHOP-88/dark-mode-toggle
mkdir -p local-dev/tickets/SHOP-88
# REVIEW-LOG exists but has NO reviewing-code stamp (gate must fail)
printf '> **Human Review:** APPROVED — 2026-06-22 — implementing-tasks-T1\n' \
  > local-dev/tickets/SHOP-88/REVIEW-LOG.md
echo "toggle code" > toggle.txt
git add .; git commit -qm "wip toggle"
echo "Done. Branch feat/SHOP-88/dark-mode-toggle, 1 commit ahead, NO reviewing-code stamp."
