#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v gh >/dev/null 2>&1; then
  echo "Missing GitHub CLI (gh). On Linux Mint/Ubuntu: sudo apt install gh"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI is not logged in. Run: gh auth login"
  exit 1
fi

if [ ! -d .git ]; then
  git init
  git branch -M main
fi

git add .
if ! git diff --cached --quiet; then
  git commit -m "AirTranslate iPhone MVP with Linux-to-iPhone build"
fi

if git remote get-url origin >/dev/null 2>&1; then
  echo "Using existing origin: $(git remote get-url origin)"
  git push -u origin main
else
  gh repo create AirTranslate13Mini --private --source=. --remote=origin --push
fi

echo
echo "Pushed. GitHub Actions will build the unsigned IPA."
echo "Open the repo -> Actions -> Build unsigned iPhone IPA -> latest run -> Artifacts."
