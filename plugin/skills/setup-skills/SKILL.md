---
name: setup-skills
description: Sets up an `## Agent skills` index block in CLAUDE.md/AGENTS.md and per-repo reference docs in `docs/agents/` so the engineering skills know this repo's issue tracker (bd / beads, GitHub, GitLab, or local markdown), triage label vocabulary, and domain doc layout. Optionally also installs the AFK ("away from keyboard") loop in `ralph/` for autonomous ticket execution. Run before first use of `spec`, `prd`, or `issues` – or if those skills appear to be missing context about the issue tracker, triage labels, or domain docs – or to wire up the AFK loop.
disable-model-invocation: true
---

# Setup Skills

Scaffold the per-repo configuration that the engineering skills assume:

- **Issue tracker** – where issues live and how to publish/fetch them (bd / beads, GitHub, GitLab, local markdown, or a freeform "other" workflow you describe)
- **Triage labels** – the strings used for the five canonical triage roles
- **Domain docs** – where `CONTEXT.md` and ADRs live, and how consumer skills should use them
- **AFK loop (optional)** – `ralph/once.sh` for one Claude iteration, `ralph/afk.sh` for a multi-iteration worktree-isolated loop that opens a PR with the result. Skip this if you only want triage and briefs without autonomous execution.

The configuration lives in two places (three if the AFK loop is installed):

- A short index block under `## Agent skills` in `CLAUDE.md` (or `AGENTS.md`) – just one-line pointers
- Detailed reference docs in `docs/agents/` – the actual content consumer skills read
- (Optional) The AFK loop harness in `ralph/` – worker scripts and prompt, only if the user opted in

Consumer skills (`prd`, `issues`) talk in **stable verbs** like "publish to the issue tracker" and "fetch the relevant ticket". The reference docs in `docs/agents/` define what those verbs mean concretely for this repo. This means consumer skills don't branch on tracker type – per-repo customization happens by editing `docs/agents/issue-tracker.md`, not by editing the global skills.

This is a prompt-driven skill, not a deterministic script. Explore, present what you found, confirm with the user, then write.

## Process

### 1. Explore

Look at the current repo to understand its starting state. Read whatever exists; don't assume:

- `git remote -v` and `.git/config` – is this a GitHub or GitLab repo? Which one?
- `CLAUDE.md` and `AGENTS.md` at the repo root – does either exist? Is there already an `## Agent skills` section in either?
- `docs/agents/` – does this skill's prior output already exist?
- `CONTEXT.md` and `CONTEXT-MAP.md` at the repo root
- `docs/adr/` and any `src/*/docs/adr/` directories
- `.scratch/` – sign that a local-markdown issue tracker convention is already in use
- `ralph/` – sign that the AFK loop is already installed. Check whether all expected files are present (see Section D for the list); a partial install is the migration path for repos that installed the loop before later additions shipped, and Section D's default flips from "skip" to "incremental install" in that case.

### 2. Present findings and ask

Summarise what's present and what's missing. Then walk the user through the decisions below **one at a time** – present a section, get the user's answer, then move to the next. Don't dump them all at once. Section D (AFK loop) is optional – ask whether to install it; the rest of the setup works without it.

Assume the user does not know what these terms mean. Each section starts with a short explainer (what it is, why these skills need it, what changes if they pick differently). Then show the choices and the default.

Note for the user up front: the triage label vocabulary is set up for skills that may not yet be installed (a future `triage` skill consumes the full five-label state machine). Setting them now keeps the config consistent for when those skills land – it's not a sign you're missing something.

**Section A – Issue tracker.**

> Explainer: The "issue tracker" is where issues live for this repo. Skills like `prd` and `issues` read from and write to it – they need to know whether to call `gh issue create`, `glab issue create`, `bd create`, or write a markdown file under `.scratch/`. Pick the place you actually track work for this repo.

Default posture, in priority order:

1. If `[ -d "$REPO_ROOT/.beads" ]` (the user has run `bd init`), propose **bd**. Active opt-in beats default state — every repo has remotes, so a `.beads/` directory is the stronger signal.
2. Else if a `git remote` points at GitHub, propose **GitHub**.
3. Else if a `git remote` points at GitLab (host is `gitlab.com` or contains `gitlab`, matching the AFK template's runtime check for self-hosted instances), propose **GitLab**.
4. Otherwise, propose **local markdown**.

Detection for bd is just the `.beads/` directory check above — don't try to read bd's internal state to distinguish stealth mode (`bd init --stealth`). Stealth-mode users can override at the prompt.

Supported options:

- **bd (beads)** – issues live in `.beads/` at the repo root, a local-first dependency-graph tracker (uses the `bd` CLI). Seed: [issue-tracker-beads.md](./issue-tracker-beads.md).
- **GitHub** – issues live in the repo's GitHub Issues (uses the `gh` CLI). Seed: [issue-tracker-github.md](./issue-tracker-github.md).
- **GitLab** – issues live in the repo's GitLab Issues (uses the `glab` CLI). Seed: [issue-tracker-gitlab.md](./issue-tracker-gitlab.md).
- **Local markdown** – issues live as files under `.scratch/<feature-slug>/` in this repo (good for solo projects or repos without a remote). Seed: [issue-tracker-local.md](./issue-tracker-local.md).
- **Other** (Jira, Linear, etc.) – ask the user to describe the workflow in one paragraph; record it as freeform prose in `docs/agents/issue-tracker.md`. Make sure they cover the verbs consumer skills depend on: "publish to the issue tracker", "fetch the relevant ticket", "comment on a ticket", "apply a label / set status".

**Section B – Triage label vocabulary.**

> Explainer: Skills move issues through a state machine – needs evaluation, waiting on reporter, ready for an AFK agent to pick up, ready for a human, or won't fix. To do that, they apply labels (or set status, in local markdown) using strings *you've actually configured*. If your repo already uses different label names (e.g. `bug:triage` instead of `needs-triage`), map them here so skills apply the right ones instead of creating duplicates.

The five canonical roles:

- `needs-triage` – maintainer needs to evaluate
- `needs-info` – waiting on reporter
- `ready-for-agent` – fully specified, AFK-ready (an agent can pick it up with no human context)
- `ready-for-human` – needs human implementation
- `wontfix` – will not be actioned

Default: each role's string equals its name. Ask the user if they want to override any. If their issue tracker has no existing labels, the defaults are fine.

**Section C – Domain docs.**

> Explainer: Some skills read a `CONTEXT.md` file to learn the project's domain language, and `docs/adr/` for past architectural decisions. They need to know whether the repo has one global context or multiple (e.g. a monorepo with separate frontend/backend contexts) so they look in the right place.

Confirm the layout:

- **Single-context** – one `CONTEXT.md` + `docs/adr/` at the repo root. Most repos are this.
- **Multi-context** – `CONTEXT-MAP.md` at the root pointing to per-context `CONTEXT.md` files (typically a monorepo).

**Section D – AFK loop (optional).**

> Explainer: Once the foundation above is in place, you can install the AFK ("away from keyboard") loop. `ralph/once.sh` runs a single Claude iteration — useful for testing the prompt. `ralph/afk.sh <N>` loops up to N iterations inside a persistent git worktree on a `ralph` branch; each iteration picks the next `ready-for-agent` ticket, implements it, commits, and the loop ends by pushing the branch and (for GitHub/GitLab) opening or updating a PR/MR. After the loop exits, `ralph/review.sh <prd-ref>` runs a single Claude iteration that compares the diff against the PRD and posts a structured five-question review comment on the PRD ticket. Requires `git`, the chosen tracker's CLI authenticated, and a remote configured for push (or local merge if the tracker is local markdown).

The full set of files this step installs into `ralph/`:

- `once.sh` — one-shot interactive iteration
- `afk.sh` — multi-iteration loop
- `prompt.md` — the prompt fed to each loop iteration
- `review.sh` — post-loop PRD review wrapper
- `review-prompt.md` — the prompt fed to `review.sh`

Default behaviour depends on what's already in `ralph/`:

- **`ralph/` does not exist** — ask whether to install. Skipping is fine; the rest of the setup works without it.
- **`ralph/` exists and contains every expected file** — default to "skip". Offer "reinstall (overwrite all)" as the alternative. Reinstall clobbers any local edits (including to `prompt.md`), so it's the explicit-opt-in path, not the default.
- **`ralph/` exists but is missing one or more expected files** — default to "incremental install": copy only the missing files, leave all existing files untouched. This is the migration route for repos that installed the AFK loop before later additions (e.g. `review.sh`) shipped. "Reinstall (overwrite all)" remains available; "skip" leaves the repo with an incomplete `ralph/` and is rarely what the user wants.

If the user opts in (full or incremental), auto-detect everything; don't ask follow-up questions unless detection fails:

- **Base branch**: `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'`. If no remote, fall back to whatever `git config init.defaultBranch` returns, or `main`.
- **Ticket-fetch command**: depends on the tracker chosen in Section A.
    - **GitHub**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`
    - **GitLab**: `glab issue list --state opened -F json`
    - **Local markdown**: `cat .scratch/*/issues/*.md`
    - **bd (beads)**: `bd ready --json`
    - **Other** (freeform tracker): skip the install. The custom workflow needs decisions (fetch command, PR creation) that aren't safe to guess. Point the user at `<this-skill-dir>/ralph-templates/` to adapt by hand.
- **Test commands**: scan project files for the obvious verifications and assemble a bullet list:
    - `package.json` scripts: include any of `npm run test`, `npm run typecheck`, `npm run lint`, `npm run build` that match scripts that actually exist.
    - `pyproject.toml` / `setup.cfg`: if pytest is a dev dep, include `pytest`. If mypy / pyright, include the matching command. If ruff / black, include `ruff check .` / `black --check .`.
    - `Makefile`: if there's a `test:` or `check:` target, include `make test` / `make check`.
    - `Cargo.toml`: include `cargo test` and `cargo check`.
    - `go.mod`: include `go test ./...` and `go vet ./...`.
    - If nothing detected, write a placeholder bullet (`- _TODO: maintainer should add this project's verification commands here_`) and surface to the user that they need to fill it in.

Pick the matching `afk.sh.<tracker>.template`. Don't ask the user to confirm individual values — show the final substituted files in step 3 instead.

### 3. Confirm and edit

Show the user a draft of:

- The `## Agent skills` index block to add to `CLAUDE.md` / `AGENTS.md`
- The contents of `docs/agents/issue-tracker.md`, `docs/agents/triage-labels.md`, and `docs/agents/domain.md` (built from the seed templates with the user's choices applied)
- If installing the AFK loop: the substituted contents of `ralph/once.sh`, `ralph/afk.sh`, `ralph/prompt.md`, `ralph/review.sh`, and `ralph/review-prompt.md`, plus the detected base branch, ticket-fetch command, and test commands list. For an incremental install, only show the files that will actually be written.

Let them edit before writing.

### 4. Write

**Pick the file to edit:**

- If `CLAUDE.md` exists, edit it.
- Else if `AGENTS.md` exists, edit it.
- If neither exists, default to creating `CLAUDE.md` – this is a Claude Code workflow. Confirm with the user before creating.

Never create `AGENTS.md` when `CLAUDE.md` already exists (or vice versa) – always edit the one that's already there.

If an `## Agent skills` block already exists in the chosen file, update its contents in-place rather than appending a duplicate. Don't overwrite user edits to the surrounding sections.

**The index block to write:**

```markdown
## Agent skills

### Issue tracker

[One-line summary]. See `docs/agents/issue-tracker.md`.

### Triage labels

[One-line summary]. See `docs/agents/triage-labels.md`.

### Domain docs

[Single-context or multi-context]. See `docs/agents/domain.md`.
```

**Then write the three reference docs to `docs/agents/`:**

- `docs/agents/issue-tracker.md` – copy the matching seed (`issue-tracker-beads.md`, `issue-tracker-github.md`, `issue-tracker-gitlab.md`, or `issue-tracker-local.md`) from this skill's directory. For "other" trackers, write from scratch using the user's description.
- `docs/agents/triage-labels.md` – copy [triage-labels.md](./triage-labels.md), filling in the right-hand column with whatever overrides the user chose.
- `docs/agents/domain.md` – copy [domain.md](./domain.md), trimming or adjusting the file structure section to match single- vs multi-context.

Create the `docs/agents/` directory if it doesn't exist.

**If installing the AFK loop** (full or incremental — see Section D), also:

- Create `<repo-root>/ralph/` if it doesn't exist.
- Read each template from this skill's `ralph-templates/` directory and write the substituted version to `ralph/`. Use Read + Write to do the substitution, not `sed` — the GitHub ticket-fetch command has nested quotes that get fiddly under shell escaping.
    - `once.sh.template` → `ralph/once.sh` (substitute `__TICKET_FETCH_CMD__`)
    - `afk.sh.<tracker>.template` → `ralph/afk.sh` (substitute `__BASE_BRANCH__`, `__TICKET_FETCH_CMD__`). Templates ship for `bd` (`afk.sh.beads.template`), `github`, `gitlab`, and `local`; pick the one matching the tracker chosen in Section A.
    - `prompt.md.template` → `ralph/prompt.md` (substitute `__TEST_COMMANDS__`)
    - `review.sh.template` → `ralph/review.sh` (substitute `__BASE_BRANCH__`)
    - `review-prompt.md.template` → `ralph/review-prompt.md` (no substitution today; follows the same pattern in case future variables are added)
- For an **incremental install**, write only the files that are missing from `ralph/`. Leave all existing files untouched — they may carry user customizations (especially to `prompt.md`).
- `chmod +x` the shell scripts that were just written: `ralph/once.sh`, `ralph/afk.sh`, `ralph/review.sh` (run only against files that exist after the previous step).
- Add a fourth section to the `## Agent skills` index block:

```markdown
### AFK loop

Installed at `ralph/`. Run `./ralph/afk.sh <N>` to loop on `ready-for-agent` tickets, or `./ralph/once.sh` for a single iteration. After the loop (or any other completion path — `once.sh`, hand work) exits, run `./ralph/review.sh <prd-ref>` to review the implementation against a PRD; the script auto-detects whether to review the main checkout or the AFK worktree. Worktree-isolated on the `ralph` branch.
```

- Tell the user to commit `ralph/` to the base branch — the AFK loop reads its prompt from inside the worktree, so the scripts need to be tracked in git for the `ralph` branch to inherit them.

### 5. Done

Tell the user the setup is complete. Mention:

- Consumer skills (`prd`, `issues`) will now read `docs/agents/*.md` automatically when they need tracker-specific behavior.
- They can edit `docs/agents/*.md` directly later (per-repo customization lives there) – re-running this skill is only necessary if they want to switch issue trackers or restart from scratch.
- The `## Agent skills` block in CLAUDE.md is just an index pointing at those docs; don't put workflow content there directly.
- If the AFK loop was installed: test it with `./ralph/once.sh` (single interactive iteration) before running `./ralph/afk.sh <N>` for the multi-iteration loop. The first afk.sh run creates the worktree at `<repo>-afk/`. After `afk.sh` exits, run `./ralph/review.sh <prd-ref>` against any PRD whose children just shipped — it posts a structured five-question review comment on the PRD ticket. To clean up later: `git worktree remove <repo>-afk` and `git branch -D ralph` from the main checkout.
- If this was an **incremental install** (i.e. `ralph/` already existed and was missing one or more files) and a `<repo>-afk` worktree from a prior `afk.sh` run exists, that worktree's `ralph` branch tip predates the newly-installed files — `review.sh` will fail there with "No such file or directory" trying to read `ralph/review-prompt.md`. Either rebase the `ralph` branch onto the base branch so it picks up the new files, or `git worktree remove <repo>-afk && git branch -D ralph` so the next `afk.sh` recreates them from a current base.
