#!/usr/bin/env bash
# Construct the git state for: crafting-commits → proposes-clean-conventional-history (core).
# A feature branch with messy, non-conventional commits ahead of `develop`, and an APPROVED
# reviewing-code stamp present so the gate passes.
set -euo pipefail
DIR="${1:?usage: SETUP.sh <scratch-dir>}"
rm -rf "$DIR"; mkdir -p "$DIR"; cd "$DIR"
git init -q -b develop
git config user.email eval@brightcart.test; git config user.name "Eval Bot"
echo "# BrightCart" > README.md
git add README.md; git commit -qm "chore: init"
git checkout -q -b feat/SHOP-88/add-auth
mkdir -p local-dev/tickets/SHOP-88
{
  printf '> **Human Review:** APPROVED — 2026-06-22 — implementing-tasks-T1\n'
  printf '> **Human Review:** APPROVED — 2026-06-23 — reviewing-code\n'
} > local-dev/tickets/SHOP-88/REVIEW-LOG.md
# Messy history: vague messages, mixed concerns
echo "auth a" > auth.py; git add .; git commit -qm "wip"
echo "ui x" > settings.css; echo "auth b" >> auth.py; git add .; git commit -qm "stuff and fixes"
echo "test t" > test_auth.py; git add .; git commit -qm "more"
echo "Done. Branch feat/SHOP-88/add-auth off develop, 3 messy commits, reviewing-code APPROVED."
