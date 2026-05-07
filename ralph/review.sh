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

# When HEAD is on the base branch itself (e.g. once.sh-on-main work that hasn't
# been pushed yet), ${BASE_BRANCH}..HEAD is tautologically empty. Compare
# against origin/${BASE_BRANCH} instead so unpushed commits are reviewable.
MAIN_BRANCH=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)
MAIN_COMPARE_REF=""
MAIN_COMMITS_AHEAD=0
MAIN_BASE_FAILURE=""

if [ "$MAIN_BRANCH" = "$BASE_BRANCH" ]; then
  if ! git -C "$REPO_ROOT" remote get-url origin >/dev/null 2>&1; then
    MAIN_BASE_FAILURE="no-origin"
  elif ! git -C "$REPO_ROOT" rev-parse --verify --quiet "origin/${BASE_BRANCH}" >/dev/null 2>&1; then
    MAIN_BASE_FAILURE="no-origin-ref"
  else
    MAIN_COMPARE_REF="origin/${BASE_BRANCH}"
    MAIN_COMMITS_AHEAD=$(git -C "$REPO_ROOT" rev-list --count "${MAIN_COMPARE_REF}..HEAD" 2>/dev/null || echo 0)
    if [ "$MAIN_COMMITS_AHEAD" -eq 0 ]; then
      MAIN_BASE_FAILURE="already-pushed"
    fi
  fi
else
  if ! git -C "$REPO_ROOT" rev-parse --verify --quiet "$BASE_BRANCH" >/dev/null 2>&1; then
    MAIN_BASE_FAILURE="no-base-ref"
  else
    MAIN_COMPARE_REF="$BASE_BRANCH"
    MAIN_COMMITS_AHEAD=$(git -C "$REPO_ROOT" rev-list --count "${MAIN_COMPARE_REF}..HEAD" 2>/dev/null || echo 0)
  fi
fi

print_main_status() {
  case "$MAIN_BASE_FAILURE" in
    already-pushed)
      echo "  Main checkout ($REPO_ROOT): on base branch ${BASE_BRANCH}; HEAD matches origin/${BASE_BRANCH} (appears already pushed)."
      ;;
    no-origin)
      echo "  Main checkout ($REPO_ROOT): on base branch ${BASE_BRANCH}; no 'origin' remote configured, can't compare against origin/${BASE_BRANCH}."
      ;;
    no-origin-ref)
      echo "  Main checkout ($REPO_ROOT): on base branch ${BASE_BRANCH}; origin/${BASE_BRANCH} ref not found locally — try 'git fetch origin'."
      ;;
    no-base-ref)
      echo "  Main checkout ($REPO_ROOT): base branch '${BASE_BRANCH}' not found locally — check whether setup-skills picked the wrong base for this repo."
      ;;
    *)
      echo "  Main checkout ($REPO_ROOT): 0 commits ahead of ${BASE_BRANCH}."
      ;;
  esac
}

if [ "$MAIN_COMMITS_AHEAD" -gt 0 ]; then
  TARGET_PATH="$REPO_ROOT"
  TARGET_LABEL="main checkout"
  COMPARE_REF="$MAIN_COMPARE_REF"
else
  if [ ! -d "$WORKTREE_PATH" ]; then
    echo "Error: nothing to review."
    print_main_status
    echo "  AFK worktree ($WORKTREE_PATH): worktree absent."
    echo "Run ./ralph/once.sh, ./ralph/afk.sh <N>, or commit work directly, then re-run."
    exit 1
  fi
  if ! git -C "$WORKTREE_PATH" rev-parse --verify --quiet "$BASE_BRANCH" >/dev/null 2>&1; then
    echo "Error: nothing to review."
    print_main_status
    echo "  AFK worktree ($WORKTREE_PATH): base branch '${BASE_BRANCH}' not found in worktree — check whether setup-skills picked the wrong base for this repo."
    exit 1
  fi
  WT_COMMITS_AHEAD=$(git -C "$WORKTREE_PATH" rev-list --count "${BASE_BRANCH}..HEAD" 2>/dev/null || echo 0)
  if [ "$WT_COMMITS_AHEAD" -eq 0 ]; then
    echo "Error: nothing to review."
    print_main_status
    echo "  AFK worktree ($WORKTREE_PATH): worktree empty (0 commits ahead of $BASE_BRANCH)."
    echo "Run ./ralph/once.sh, ./ralph/afk.sh <N>, or commit work directly, then re-run."
    exit 1
  fi
  echo "Main checkout has nothing to review; falling back to AFK worktree."
  print_main_status
  TARGET_PATH="$WORKTREE_PATH"
  TARGET_LABEL="AFK worktree at $WORKTREE_PATH"
  COMPARE_REF="$BASE_BRANCH"
fi

cd "$TARGET_PATH"

# Pin timestamp and commit range in bash so the prompt can't drift between
# what was reviewed and what got reported in the comment header. Three-dot
# diff matches the GitHub/GitLab PR view.
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BASE_SHA=$(git rev-parse --short "$COMPARE_REF")
HEAD_SHA=$(git rev-parse --short HEAD)
RANGE="${BASE_SHA}..${HEAD_SHA}"
BRANCH=$(git rev-parse --abbrev-ref HEAD)

echo "Reviewing ${TARGET_LABEL} (branch ${BRANCH}) against ${COMPARE_REF} — range ${RANGE}"

DIFF=$(git diff "${COMPARE_REF}...HEAD")
COMMITS=$(git log "${COMPARE_REF}..HEAD" --format="%H%n%ad%n%B---" --date=short)

prompt=$(cat ralph/review-prompt.md)

# jq filter to extract streaming text from assistant messages — kept in sync
# with afk.sh so both scripts render claude output identically.
stream_text='select(.type == "assistant").message.content[]? | select(.type == "text").text // empty | gsub("\n"; "\r\n") | . + "\r\n\n"'

prompt_arg="PRD ref: $PRD_REF
Timestamp: $TIMESTAMP
Range: $RANGE

$prompt

---
Commits in range:
$COMMITS

---
Diff (${COMPARE_REF}...HEAD):
$DIFF"

# `if !` lets the pipeline's failure surface a diagnostic instead of `set -e`
# aborting silently — the most common case is grep finding zero JSON lines
# because claude printed a banner/error to stdout instead of streamed events.
if ! claude \
  --verbose \
  --print \
  --output-format stream-json \
  "$prompt_arg" \
| grep --line-buffered '^{' \
| jq --unbuffered -rj "$stream_text"; then
  echo "Error: claude streaming pipeline failed (no JSON output or non-zero exit)." >&2
  echo "To debug, re-run claude directly: claude --print --output-format stream-json '<prompt>'" >&2
  exit 1
fi
