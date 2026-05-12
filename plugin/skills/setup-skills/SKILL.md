---
name: setup-skills
description: Sets up an `## Agent skills` index block in CLAUDE.md/AGENTS.md and per-repo reference docs in `docs/agents/` so the engineering skills know this repo's issue tracker (bd / beads, GitHub, GitLab, or local markdown), triage label vocabulary, and domain doc layout. Optionally also installs the AFK ("away from keyboard") loop in `ralph/` for autonomous ticket execution. Run before first use of `spec`, `prd`, or `issues` – or if those skills appear to be missing context about the issue tracker, triage labels, or domain docs – or to wire up the AFK loop – or to update an existing install against the current plugin output (run as `/setup-skills update`).
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

This skill has two modes, picked by the argument:

- **No argument** — install mode. Walk Sections A–D under "Process" below to scaffold the configuration from scratch. This is the existing behaviour.
- **`update`** — update mode. Skip "Process" entirely; jump to ["Update mode"](#update-mode) and surface drift between the installed artifacts and the current upstream seeds. Recover install-time choices from the installed files rather than re-prompting.

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

> Explainer: Once the foundation above is in place, you can install the AFK ("away from keyboard") loop. `ralph/once.sh` runs a single Claude iteration — useful for testing the prompt. `ralph/afk.sh <N>` loops up to N iterations inside a persistent git worktree on a `ralph` branch; each iteration picks the next `ready-for-agent` ticket, implements it, commits, and the loop ends by pushing the branch and (for GitHub/GitLab) opening or updating a PR/MR. After completion via any path (`afk.sh`, `once.sh`, hand work), `ralph/review.sh <prd-ref>` auto-detects which checkout to review (main wins when ahead of base; AFK worktree otherwise; on the base branch, unpushed commits are reviewed against `origin/<base>`), streams claude output live, and posts a structured five-question review comment on the PRD ticket. Requires `git`, the chosen tracker's CLI authenticated, and a remote configured for push (or local merge if the tracker is local markdown).

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

Installed at `ralph/`. Run `./ralph/afk.sh <N>` to loop on `ready-for-agent` tickets (worktree-isolated on the `ralph` branch), or `./ralph/once.sh` for a single iteration. After the loop (or any other completion path — `once.sh`, hand work) exits, run `./ralph/review.sh <prd-ref>` to review the implementation against a PRD; the script auto-detects which checkout to review (main wins when ahead of base; AFK worktree otherwise; on the base branch, unpushed commits are reviewed against `origin/<base>`) and streams claude output live.
```

- Tell the user to commit `ralph/` to the base branch — the AFK loop reads its prompt from inside the worktree, so the scripts need to be tracked in git for the `ralph` branch to inherit them.

### 5. Done

Tell the user the setup is complete. Mention:

- Consumer skills (`prd`, `issues`) will now read `docs/agents/*.md` automatically when they need tracker-specific behavior.
- They can edit `docs/agents/*.md` directly later (per-repo customization lives there) – re-running this skill is only necessary if they want to switch issue trackers or restart from scratch.
- The `## Agent skills` block in CLAUDE.md is just an index pointing at those docs; don't put workflow content there directly.
- If the AFK loop was installed: test it with `./ralph/once.sh` (single interactive iteration) before running `./ralph/afk.sh <N>` for the multi-iteration loop. The first afk.sh run creates the worktree at `<repo>-afk/`. After completion via any path (`afk.sh`, `once.sh`, hand work), run `./ralph/review.sh <prd-ref>` against any PRD whose children just shipped — it auto-detects which checkout to review (main wins when ahead of base; AFK worktree otherwise; on the base branch, unpushed commits are reviewed against `origin/<base>`), streams claude output live, and posts a structured five-question review comment on the PRD ticket. To clean up later: `git worktree remove <repo>-afk` and `git branch -D ralph` from the main checkout.
- If this was an **incremental install** (i.e. `ralph/` already existed and was missing one or more files) and a `<repo>-afk` worktree from a prior `afk.sh` run exists, that worktree's `ralph` branch tip predates the newly-installed files — `review.sh` will fail there with "No such file or directory" trying to read `ralph/review-prompt.md`. Either rebase the `ralph` branch onto the base branch so it picks up the new files, or `git worktree remove <repo>-afk && git branch -D ralph` so the next `afk.sh` recreates them from a current base.

## Update mode

Reached via `/setup-skills update`. Surfaces drift between installed artifacts and the current upstream seeds, lets the user resolve drift per-file (take upstream / keep local / merge interactively), reports orphans (installed files with no upstream counterpart) with an ask-don't-delete prompt, reinstalls missing canonical seeds via the existing Section D logic, and prints a summary at the end.

Update mode covers:

- **Drift detection** on the three `docs/agents/*.md` files (`issue-tracker.md`, `triage-labels.md`, `domain.md`), the `## Agent skills` index block in `CLAUDE.md` (or `AGENTS.md`), and the five `ralph/*` AFK-loop artifacts (`once.sh`, `afk.sh`, `prompt.md`, `review.sh`, `review-prompt.md`) when `ralph/` is present in the repo. When `ralph/` is absent, skip the `ralph/*` set entirely (no error, no prompt); the index-block and `docs/agents/` diffs still run.
- **Orphan detection** on direct children of installed `docs/agents/` and (when present) `ralph/`: any file whose name is not in the canonical seed list (see sub-step 3f) is flagged for the user with a per-file keep-or-delete prompt. Update mode never auto-deletes.
- **Missing-seed detection** on the canonical `ralph/*` set (only when `ralph/` is present): any canonical seed with no installed counterpart is reinstalled by reusing Section D's incremental-install logic. The user is informed of each file added; no per-file decision.

Do **not** run any of Sections A–D in "Process". Update mode never re-prompts for tracker / labels / context layout — those are install-time user choices and silently flipping them would be a surprise. Install-time *measurements* (base branch, test commands) are re-detected from the live repo in sub-step 2d so genuine repo changes propagate.

### 1. Subcommand dispatch

If the user invoked `/setup-skills update`, you are in update mode. Continue with sub-step 2.

If the argument is anything other than `update` or empty, say so and stop — don't guess. (Today, only `update` is recognised.)

### 2. Configuration recovery

Sub-steps 2a–2c recover the three install-time **choices** (tracker, label vocab, context layout) from the installed `docs/agents/*.md` files. Never re-detect any of these from live repo state — that would silently flip a decision the user made at install time. If any of the three files is **missing**, tell the user to run `/setup-skills` (no argument) and stop. If any of the three files is **present but unparseable** through the rules below, route to the "I can't recover" path between 2c and 2d.

Sub-step 2d re-detects install-time **measurements** (base branch, test commands list) from the live repo so genuine repo changes propagate through the `ralph/*` drift comparison.

#### 2a. Tracker selection (from `docs/agents/issue-tracker.md`)

Read the level-1 heading and map it to the matching upstream seed:

| Heading                           | Upstream seed              |
| --------------------------------- | -------------------------- |
| `# Issue tracker: bd (beads)`     | `issue-tracker-beads.md`   |
| `# Issue tracker: GitHub`         | `issue-tracker-github.md`  |
| `# Issue tracker: GitLab`         | `issue-tracker-gitlab.md`  |
| `# Issue tracker: Local Markdown` | `issue-tracker-local.md`   |

**Fingerprint fallback** when the heading is missing, malformed, or not in the table above (corrupted file, "other" freeform tracker, hand-edited heading): scan the installed file's body for a tracker-specific CLI fingerprint:

| Fingerprint substring (any occurrence)             | Tracker  |
| -------------------------------------------------- | -------- |
| `bd create`, `bd ready`, `bd dep`, or `.beads/`    | beads    |
| `gh issue` or `gh label`                           | github   |
| `glab issue`                                       | gitlab   |
| `.scratch/`                                        | local    |

If fingerprints for exactly one tracker appear, recover that tracker. If fingerprints for zero or multiple trackers appear (ambiguous), route to the "I can't recover" path.

#### 2b. Triage label vocabulary (from `docs/agents/triage-labels.md`)

Parse the right-hand column of the three tables (`## Kind roles`, `## Category roles`, `## State roles`) to recover the user's mapping for the eight canonical roles:

- Kind: `prd`
- Category: `bug`, `enhancement`
- State: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`

For each table, find the row whose **first column** matches the canonical role (the role name appears in backticks, e.g. `` `bug` ``) and capture the **second column** verbatim (the user's label string, also typically in backticks). If any of the eight canonical roles can't be located — table missing, row missing, columns malformed — route to the "I can't recover" path.

The resulting eight-entry mapping is the substitution input for sub-step 3b.

#### 2c. Single-vs-multi-context (from `docs/agents/domain.md`)

Read the `## File structure` section of the installed file and detect the shape from its fenced code block(s):

- If a tree block mentions `CONTEXT-MAP.md` → **multi-context**.
- If a tree block has `CONTEXT.md` at the root and no `CONTEXT-MAP.md` → **single-context**.
- If the section is missing, contains no recognisable tree block, or contains a tree that fits neither shape → route to the "I can't recover" path.

#### "I can't recover" path

When a recovery step above hits the failure cases described in 2a / 2b / 2c, surface this exact message and pause for direction (substituting `<file>` with the offending path):

> I can't recover the install-time choice for `<file>` — please confirm the value or re-run `/setup-skills` from scratch.

Do **not** fall back to live re-detection of tracker / labels / context layout. Wait for the user to either confirm a value (in which case continue update mode with that value) or exit.

When the user supplies a value and update mode continues, **record the file path and a one-line description of how recovery succeeded** (e.g. `recovered after the user re-supplied the <field> mapping`). The list of recovery warnings is consumed in sub-step 5's `Warnings:` block at the bottom of the summary; omit that block when no warnings fired.

#### 2d. Re-detect install-time measured values

The `ralph/*` artifacts ship as templates carrying three `__VAR__` placeholders that the install path substitutes from live repo state. Update mode re-runs that detection so genuine repo changes (a renamed default branch, a newly added `lint` script) flow through to the drift comparison.

Do this only if `ralph/` exists in the repo — otherwise the values aren't needed.

- **`__BASE_BRANCH__`** — run `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'`. If no remote, fall back to whatever `git config init.defaultBranch` returns, or `main`. Same fallback chain as Section D.
- **`__TICKET_FETCH_CMD__`** — derived from the tracker recovered in 2a (no live detection; the tracker decision is install-time, not a measurement):
    - **GitHub**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`
    - **GitLab**: `glab issue list --state opened -F json`
    - **Local markdown**: `cat .scratch/*/issues/*.md`
    - **bd (beads)**: `bd ready --json`
- **`__TEST_COMMANDS__`** — re-run the same scan Section D performs:
    - `package.json` scripts: include any of `npm run test`, `npm run typecheck`, `npm run lint`, `npm run build` matching scripts that actually exist.
    - `pyproject.toml` / `setup.cfg`: pytest, mypy / pyright, ruff / black if configured as dev deps.
    - `Makefile`: `make test` / `make check` when those targets exist.
    - `Cargo.toml`: `cargo test` and `cargo check`.
    - `go.mod`: `go test ./...` and `go vet ./...`.
    - If nothing detected, use the placeholder bullet `- _TODO: maintainer should add this project's verification commands here_`.
    Assemble the result as a bullet list with the same shape Section D writes.

If the recovered tracker is "other" (freeform), `ralph/` shouldn't be installed (Section D skips the install for "other" trackers). If `ralph/` exists alongside an "other" tracker the user installed manually, skip the `ralph/*` drift comparison and note it under "Out of scope this run" — the same posture Section D takes.

### 3. Drift detection

For each artifact in scope, build a **substituted upstream** using the recovered choices / re-detected measurements from sub-step 2, then compare against the installed artifact. Classify each as **clean** or **drifted**. Sub-steps 3a–3c cover the three `docs/agents/*.md` files (plain byte-identical compare after substitution; no `__VAR__` placeholders in those seeds). Sub-step 3d covers the five `ralph/*` artifacts and adds the substitution-aware diff filter. Sub-step 3e covers the `## Agent skills` index block.

#### 3a. `docs/agents/issue-tracker.md`

The upstream is the seed identified in 2a. The four `issue-tracker-*.md` seeds have no `__VAR__` placeholders, so the substituted upstream is just the seed verbatim — plain compare against the installed file.

#### 3b. `docs/agents/triage-labels.md`

Start from the upstream `triage-labels.md` seed in this skill's directory. For each of the eight canonical roles recovered in 2b, find the matching row in the seed (its first column is the canonical role in backticks) and replace its **second column** with the user's recovered value, preserving the row's column widths so the substituted seed still parses as a valid markdown table. The first column (canonical role) and the third column (meaning) are not modified.

Compare the substituted seed against the installed file.

#### 3c. `docs/agents/domain.md`

Start from the upstream `domain.md` seed in this skill's directory. Trim it to match the shape recovered in 2c:

- **Single-context**: drop the `CONTEXT-MAP.md` bullet from `## Before exploring, read these`; drop the "In multi-context repos..." sub-clause from the remaining `docs/adr/` bullet (keep the rest of that bullet intact); in `## File structure`, change "Single-context repo (most repos):" to "Single-context repo:"; remove the entire "Multi-context repo" subsection (its heading line and the code fence beneath it, plus the blank line separating them).
- **Multi-context**: keep the three bullets of `## Before exploring, read these` as-is; in `## File structure`, remove the "Single-context repo (most repos):" heading and the code fence beneath it (keep only the multi-context tree, with its heading line trimmed to "Multi-context repo:" — i.e. drop the "(presence of `CONTEXT-MAP.md` at the root)" parenthetical the way single-context trims the "(most repos)" parenthetical).

Compare the trimmed seed against the installed file.

#### 3d. `ralph/*` artifacts

Skip this entire sub-step when `ralph/` does not exist in the repo (no error, no prompt). When it does, compare each of the five files below.

If an expected `ralph/*` file is missing on disk, do **not** classify it as drift here — defer it to sub-step 3g (missing-seed detection), which will reinstall it via Section D's incremental-install logic.

Pair each installed file with the matching template from this skill's `ralph-templates/` directory:

| Installed file          | Upstream template                                  |
| ----------------------- | -------------------------------------------------- |
| `ralph/once.sh`         | `once.sh.template`                                 |
| `ralph/afk.sh`          | `afk.sh.<tracker>.template` (selected by 2a)       |
| `ralph/prompt.md`       | `prompt.md.template`                               |
| `ralph/review.sh`       | `review.sh.template`                               |
| `ralph/review-prompt.md`| `review-prompt.md.template`                        |

For each pair:

1. Read the upstream template.
2. Substitute the re-detected values from 2d for every `__VAR__` placeholder it contains. The full list of placeholders today is `__BASE_BRANCH__`, `__TICKET_FETCH_CMD__`, `__TEST_COMMANDS__`. Adding a new placeholder to a template requires extending this list and 2d together.
3. Apply the **substitution-aware diff filter** (below) when comparing the substituted upstream against the installed file. Classify per-file as **clean** (no surviving differences after the filter) or **drifted** (one or more surviving differences).

**Substitution-aware diff filter.** A line that differs solely because of a placeholder's substituted value is config drift, not template drift, and is suppressed. Concretely:

- Locate every line in the upstream template that contains a `__VAR__` placeholder. For each such template line, the substituted upstream produces one or more output lines (one for scalar placeholders like `BASE_BRANCH="__BASE_BRANCH__"`, potentially many for block placeholders like a standalone `__TEST_COMMANDS__` line that expands to a bullet list).
- A diff hunk is **suppressed** when *both* sides of the hunk, line-for-line, are valid renderings of the same template line — i.e. they match the template line exactly with the placeholder treated as a wildcard, and the number of lines on each side matches the number of lines that template line produced when substituted.
- A diff hunk **surfaces** when the template line's substitution produces a different number of lines on each side (e.g. `__TEST_COMMANDS__` expanded to 3 bullets in substituted upstream but only 2 bullets in installed — re-detection found a new `lint` script), or when the surrounding context differs from the template (e.g. upstream added a real line above the substituted block).

Examples:

- Installed `afk.sh` has `BASE_BRANCH="master"`; re-detected base branch is `main`; substituted upstream has `BASE_BRANCH="main"`. Both sides match the template line `BASE_BRANCH="__BASE_BRANCH__"` with the placeholder as wildcard, and both are single-line — **suppressed**, file classified clean for this hunk.
- Installed `prompt.md` has a 2-bullet test-commands list; re-detection added a third bullet (`- npm run lint`); substituted upstream has 3 bullets. Both sides occupy the position the `__TEST_COMMANDS__` line expanded into, but line counts differ — **surfaces** as drift.
- Upstream `prompt.md.template` gained a brand-new paragraph above the test-commands block. The new paragraph is outside any substitution region, so it diffs unconditionally — **surfaces** as drift.

#### 3e. `## Agent skills` index block

Diff the installed `## Agent skills` block against the canonical block that the install path's step 4 writes.

Pick the host file the same way step 4 does:

- If `CLAUDE.md` exists, the block lives there.
- Else if `AGENTS.md` exists, the block lives there.
- If neither exists, treat the block as missing — report drift "no host file present" and offer the user the chance to delegate to install mode (out of scope for this slice; advise re-running `/setup-skills` without arguments).

Extract the installed block: from the line `## Agent skills` (inclusive) up to the next `## ` heading or end-of-file (exclusive). Build the **canonical block** by combining:

1. The three fixed `### Issue tracker` / `### Triage labels` / `### Domain docs` subsections from step 4, with their `[One-line summary]` placeholders left as-is in the canonical (see filter below).
2. The `### AFK loop` subsection from step 4 — included only when `ralph/` exists in the repo, omitted otherwise. If installed has an `### AFK loop` subsection but `ralph/` doesn't exist, that surfaces as drift (the section is now extra) and the user resolves it via the standard three-option UX in sub-step 4.

Apply a **summary-line filter** before classifying drift: each subsection's content line has the shape `<one-line summary>. See \`docs/agents/<file>\`.`. Treat the `<one-line summary>` (everything before `. See `) as a wildcard for the purpose of drift detection — users customize that prose during install, and re-running update mode shouldn't reclassify those customizations as drift. The `See \`docs/agents/<file>\`.` pointer and every heading line are compared exactly. The `### AFK loop` subsection's full paragraph is compared exactly (no wildcard there).

Classify the index block as **clean** when, after the filter, no lines differ. Otherwise **drifted** — show the diff with the user's actual summary prose visible, not the wildcard.

#### 3f. Orphan detection

Catalog installed files in `docs/agents/` and (when present) `ralph/` that have no corresponding upstream seed. Reported in sub-step 4 with an ask-don't-delete prompt; never auto-deleted.

Build the **canonical filename set** the same way sub-step 3 pairs installed files with seeds:

- `docs/agents/`: `issue-tracker.md`, `triage-labels.md`, `domain.md`.
- `ralph/` (only when `ralph/` exists in the repo): `once.sh`, `afk.sh`, `prompt.md`, `review.sh`, `review-prompt.md`.

Walk the **direct children** of each installed directory. For each regular file whose name is not in the canonical set, record it as an orphan with its full repo-relative path. Subdirectories (and any files inside them) are skipped — out of scope this run.

If `ralph/` doesn't exist, only the `docs/agents/` walk runs (sub-step 2 already guaranteed the directory exists with the three canonical files inside; orphans there are anything extra the user has added).

The resulting orphan list — possibly empty — is consumed in sub-step 4 and counted in sub-step 5.

#### 3g. Missing-seed detection

Catalog canonical seeds for which no installed counterpart exists. Today this is `ralph/*`-scoped: sub-step 2 exits early if any of the three `docs/agents/*.md` files is missing, so the `docs/agents/` side of the canonical seed list never has missing entries at this point.

Skip this sub-step entirely when `ralph/` doesn't exist in the repo. When it does, for each canonical `ralph/*` entry (`once.sh`, `afk.sh`, `prompt.md`, `review.sh`, `review-prompt.md`), check whether the matching installed file is present. Record missing entries.

The resulting missing-seed list — possibly empty — is consumed in sub-step 4: each missing seed is reinstalled by reusing Section D's incremental-install logic (read the matching `ralph-templates/*.template`, substitute the placeholders re-detected in 2d, write to `ralph/`, then `chmod +x` for shell scripts). No per-file user decision; the user is informed which files were added in sub-step 4 and counted in sub-step 5.

### 4. Per-file decision UX

Walk the artifacts in this stable order (skip any that don't apply to the current run — `ralph/*` when ralph/ is absent, index block when its host file is missing):

1. `docs/agents/issue-tracker.md`
2. `docs/agents/triage-labels.md`
3. `docs/agents/domain.md`
4. `## Agent skills` index block (in whichever of `CLAUDE.md` / `AGENTS.md` hosts it)
5. `ralph/once.sh`
6. `ralph/afk.sh`
7. `ralph/prompt.md`
8. `ralph/review.sh`
9. `ralph/review-prompt.md`

For each **clean** artifact, skip to the next. For each **drifted** artifact, walk this exact shape — one artifact at a time, never a bulk-decision dialog:

1. **Header line.** Name the artifact and summarise the drift in one sentence: net line counts plus a short description of the primary change. The substitution-aware filter has already run, so the counts reflect surviving drift only (config-only swaps are not counted). Example:

   > `docs/agents/triage-labels.md` — upstream added 2 lines, removed 0; primary change: clarified the meaning column for `ready-for-agent`.

   For the index block, name it as `## Agent skills` block in `CLAUDE.md` (or `AGENTS.md`) rather than a file path.

2. **Diff.** Show the diff in chat. Non-negotiable: no decision is offered without it. Use a unified-diff format the user can read directly. Show the user's actual one-line summaries (not the wildcard placeholders) so the diff is concrete.

3. **Three options**, labelled exactly as below — present them as a numbered list so the user can answer "1", "2", or "3":

   - **Take upstream** — overwrite the installed artifact with the substituted upstream. For the index block, overwrite only the `## Agent skills` block inside the host file (don't touch the surrounding content). Before writing, surface a one-line warning: `Local customization will be lost.` Wait for explicit confirmation, then write.
   - **Keep local** — leave the installed artifact untouched. Drift remains; the user has explicitly opted into it.
   - **Merge interactively** — the diff is already loaded in this conversation. Ask the user, per region, which side to take (e.g. "take upstream's heading change, keep my added paragraph in the Conventions section"). Write the merged result. **Re-display the full merged artifact in chat** and wait for confirmation before treating it as final. If the user wants further edits, iterate before writing again. For the index block, the merged result replaces the `## Agent skills` block in-place; everything else in the host file is preserved.

After the nine-artifact drift walk completes, walk the **orphan list** from sub-step 3f, then the **missing-seed list** from sub-step 3g — in that order, so the user resolves contested per-file decisions before the loop announces any unilateral file additions.

**Orphan walk.** For each orphan recorded in 3f, one at a time:

1. **Header line.** Name the orphan by repo-relative path and state that no upstream seed corresponds to it. Example:

   > `docs/agents/glossary.md` — no upstream seed; this file is either a manual addition or a removed-upstream seed.

2. **Two options**, labelled exactly as below — present them as a numbered list so the user can answer "1" or "2":

   - **Keep** — leave the file untouched. The orphan stays in place; counted as flagged-and-kept in the summary.
   - **Delete** — request explicit per-file confirmation before removing: `Delete <path>? This cannot be undone. [y/N]`. Default is no. Only on an affirmative reply does the file get removed; counted as flagged-and-deleted in the summary.

   Never auto-delete; deletion is always an explicit per-file action requested by the user, even when "delete" is the chosen option.

**Missing-seed walk.** For each missing seed recorded in 3g:

1. Announce the install in one line, e.g. `Installing missing ralph/review.sh from upstream seed.`
2. Run the same write logic Section D's incremental-install path uses for that file: read `<this-skill-dir>/ralph-templates/<file>.template` (for `ralph/afk.sh`, pick the variant matching the tracker recovered in 2a), substitute the `__VAR__` placeholders from 2d, write to `ralph/<file>`, then `chmod +x` for shell scripts (`once.sh`, `afk.sh`, `review.sh`).
3. No per-file decision is offered — the missing-seed contract is "the canonical seed is what's installed". Users who want to opt out of an artifact can delete it after the run (the next update would re-flag it as missing; that's the expected feedback loop until install-state tracking lands as a future enhancement — see PRD #21's Out-of-Scope section).

### 5. Summary

Print a two-part summary at the end of every run: a per-artifact line list followed by a multi-line totals block.

**Per-artifact lines.** Print the canonical artifacts first in the stable order from sub-step 4 (skipping any that didn't apply this run — `ralph/*` lines omitted when ralph/ is absent; the index-block line omitted when no host file exists). Each canonical line is either `clean`, the chosen drift resolution (`took upstream` / `kept local` / `merged interactively`), or the missing-seed disposition (`missing — installed`). After the canonical artifacts, list orphans in the order they were walked in sub-step 4, each as `orphan (kept)` or `orphan (deleted)`.

**Totals block.** Five lines under an `Update complete:` header. Counts cover only the artifacts that actually ran this invocation:

```
Update complete:
  - <C> clean
  - <D> drifted: <T> took upstream, <K> kept local, <M> merged interactively
  - <O> orphans flagged (none deleted unless explicitly confirmed; <X> deleted on user request)
  - <S> missing seeds installed
```

Counts:

- **`<C>` clean** — artifacts classified clean in sub-step 3 (drift detection plus index block).
- **`<D>` drifted** — total = `<T>` + `<K>` + `<M>`. Each per-choice count reflects how the user resolved a drifted artifact in sub-step 4.
- **`<O>` orphans flagged** — total orphan count from sub-step 3f. The "(none deleted unless explicitly confirmed; `<X>` deleted on user request)" footnote makes the always-confirm contract visible in the summary. Use exactly `none deleted unless explicitly confirmed; 0 deleted on user request` when `<X>` is zero.
- **`<S>` missing seeds installed** — count of files written by the missing-seed walk in sub-step 4.

**Warnings block (conditional).** If any malformed-file recovery warning fired in sub-step 2's "I can't recover" path and the user supplied a value to continue, append a `Warnings:` block listing each warning by file path, one per line, after the totals. Omit the block when no warnings fired.

Worked example with mixed outcomes:

```
docs/agents/issue-tracker.md: clean
docs/agents/triage-labels.md: took upstream
docs/agents/domain.md: kept local
## Agent skills block (CLAUDE.md): clean
ralph/once.sh: clean
ralph/afk.sh: took upstream
ralph/prompt.md: merged interactively
ralph/review.sh: missing — installed
ralph/review-prompt.md: clean
docs/agents/glossary.md: orphan (kept)
ralph/my-helper.sh: orphan (deleted)

Update complete:
  - 5 clean
  - 3 drifted: 1 took upstream, 1 kept local, 1 merged interactively
  - 2 orphans flagged (none deleted unless explicitly confirmed; 1 deleted on user request)
  - 1 missing seed installed

Warnings:
  - docs/agents/triage-labels.md: recovered after the user re-supplied the `ready-for-agent` label mapping
```
