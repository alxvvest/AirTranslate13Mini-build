#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
REPO="${AIRTRANSLATE_REPO:-alxvvest/AirTranslate13Mini}"
WORKFLOW="build-ipa.yml"
ARTIFACT="AirTranslate13Mini-unsigned-ipa"
OUT="${AIRTRANSLATE_OUTPUT_DIR:-$PWD/build-output}"

for cmd in git gh; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing $cmd"
    echo "On Linux Mint/Ubuntu: sudo apt install -y git gh"
    exit 1
  }
done

gh auth status >/dev/null 2>&1 || {
  echo "GitHub CLI is not authenticated. Run: gh auth login"
  exit 1
}

if [ ! -d .git ]; then
  echo "This folder is not a git clone."
  echo "Clone your repo first:"
  echo "  cd ~/Downloads"
  echo "  gh repo clone $REPO AirTranslate13Mini"
  echo "Then copy this corrected package over that clone and rerun this script."
  exit 1
fi

CURRENT_REMOTE="$(git remote get-url origin 2>/dev/null || true)"
if [ -z "$CURRENT_REMOTE" ]; then
  git remote add origin "https://github.com/$REPO.git"
fi

git add AirTranslate AirTranslateTests .github project.yml README.md LINUX_TO_IPHONE.md scripts MAKE_XCODE_PROJECT.sh PROJECT_STATUS.txt CODEX_BUILD_PROMPT.txt 2>/dev/null || true
if ! git diff --cached --quiet; then
  git commit -m "Fix iOS 18 compatibility and Linux IPA build"
  git push -u origin HEAD:main
  SHA="$(git rev-parse HEAD)"
  echo "Waiting for push-triggered GitHub Actions run for $SHA ..."
  RUN_ID=""
  for _ in $(seq 1 30); do
    RUN_ID="$(gh run list --repo "$REPO" --workflow "$WORKFLOW" --branch main --commit "$SHA" --limit 1 --json databaseId --jq '.[0].databaseId // empty' 2>/dev/null || true)"
    [ -n "$RUN_ID" ] && break
    sleep 2
  done
else
  echo "No source changes to push; triggering a fresh build manually."
  gh workflow run "$WORKFLOW" --repo "$REPO" --ref main
  RUN_ID=""
  for _ in $(seq 1 30); do
    RUN_ID="$(gh run list --repo "$REPO" --workflow "$WORKFLOW" --branch main --event workflow_dispatch --limit 1 --json databaseId,status --jq '.[0].databaseId // empty' 2>/dev/null || true)"
    [ -n "$RUN_ID" ] && break
    sleep 2
  done
fi

if [ -z "${RUN_ID:-}" ]; then
  echo "Could not locate the GitHub Actions run."
  echo "Open: https://github.com/$REPO/actions"
  exit 1
fi

echo "Watching run $RUN_ID ..."
gh run watch "$RUN_ID" --repo "$REPO" --exit-status

rm -rf "$OUT"
mkdir -p "$OUT"
gh run download "$RUN_ID" --repo "$REPO" --name "$ARTIFACT" --dir "$OUT"

echo
echo "BUILD=PASS"
echo "IPA=$OUT/AirTranslate13Mini-unsigned.ipa"
echo "SHA256=$OUT/AirTranslate13Mini-unsigned.ipa.sha256"
echo
echo "Next: open iloader -> select your iPhone -> Import IPA -> choose that IPA."
