#!/bin/bash
set -eo pipefail

if [ -z "$1" ]; then
  echo "Usage: $0 <prd-ref>"
  exit 1
fi

PRD_REF="$1"

# review.sh auto-detects whether the work to review lives in the main checkout
# or in afk.sh's persistent worktree. The main checkout wins when it has
# commits ahead of base; otherwise we fall back to ${REPO_ROOT}-afk. PRDs
# completed via once.sh, hand work, or any path that produces commits are
# reviewable here — not just afk.sh output.
REPO_ROOT=$(git rev-parse --show-toplevel)
WORKTREE_PATH="${REPO_ROOT}-afk"
BASE_BRANCH="main"

MAIN_COMMITS_AHEAD=$(git -C "$REPO_ROOT" rev-list --count "${BASE_BRANCH}..HEAD" 2>/dev/null || echo 0)

if [ "$MAIN_COMMITS_AHEAD" -gt 0 ]; then
  TARGET_PATH="$REPO_ROOT"
  TARGET_LABEL="main checkout"
else
  if [ ! -d "$WORKTREE_PATH" ]; then
    echo "Error: nothing to review."
    echo "  Main checkout ($REPO_ROOT): 0 commits ahead of $BASE_BRANCH."
    echo "  AFK worktree ($WORKTREE_PATH): worktree absent."
    echo "Run ./ralph/once.sh, ./ralph/afk.sh <N>, or commit work directly, then re-run."
    exit 1
  fi
  WT_COMMITS_AHEAD=$(git -C "$WORKTREE_PATH" rev-list --count "${BASE_BRANCH}..HEAD" 2>/dev/null || echo 0)
  if [ "$WT_COMMITS_AHEAD" -eq 0 ]; then
    echo "Error: nothing to review."
    echo "  Main checkout ($REPO_ROOT): 0 commits ahead of $BASE_BRANCH."
    echo "  AFK worktree ($WORKTREE_PATH): worktree empty (0 commits ahead of $BASE_BRANCH)."
    echo "Run ./ralph/once.sh, ./ralph/afk.sh <N>, or commit work directly, then re-run."
    exit 1
  fi
  TARGET_PATH="$WORKTREE_PATH"
  TARGET_LABEL="AFK worktree at $WORKTREE_PATH"
fi

cd "$TARGET_PATH"

# Pin timestamp and commit range in bash so the prompt can't drift between
# what was reviewed and what got reported in the comment header. Three-dot
# diff matches the GitHub/GitLab PR view.
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BASE_SHA=$(git rev-parse --short "$BASE_BRANCH")
HEAD_SHA=$(git rev-parse --short HEAD)
RANGE="${BASE_SHA}..${HEAD_SHA}"
BRANCH=$(git rev-parse --abbrev-ref HEAD)

echo "Reviewing ${TARGET_LABEL} (branch ${BRANCH}) against ${BASE_BRANCH} — range ${RANGE}"

DIFF=$(git diff "${BASE_BRANCH}...HEAD")
COMMITS=$(git log "${BASE_BRANCH}..HEAD" --format="%H%n%ad%n%B---" --date=short)

prompt=$(cat ralph/review-prompt.md)

claude \
  --print \
  "PRD ref: $PRD_REF
Timestamp: $TIMESTAMP
Range: $RANGE

$prompt

---
Commits in range:
$COMMITS

---
Diff (${BASE_BRANCH}...HEAD):
$DIFF"
