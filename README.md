# spec-to-ship

An opinionated pre-code workflow for Claude Code, packaged as a plugin. Takes a fuzzy idea and walks it through alignment, written artifact, and grabbable tickets — landing in a state where an AFK (autonomous) loop can pick up work without further human input.

## The arc

```
setup-skills → spec → prd → issues → triage → ralph/once.sh | ralph/afk.sh
```

| Skill          | What it does                                                                                  |
| -------------- | --------------------------------------------------------------------------------------------- |
| `setup-skills` | Bootstraps the workflow's dependencies and conventions in a new project. Optionally installs the `ralph/` execution scripts described below. |
| `spec`         | Stress-tests a feature idea by interviewing one question at a time before any code is written.|
| `prd`          | Converts the conversation into a PRD published to your issue tracker.                         |
| `issues`       | Breaks a PRD into independently-grabbable tracer-bullet issues (HITL vs. AFK classified).     |
| `triage`       | Moves issues through the canonical state machine: needs-triage → ready-for-agent / -human.    |
| `diagnose`     | Companion skill — disciplined approach to hard bugs (repro, hypothesize, instrument, fix).    |
| `tdd`          | Companion skill — vertical-slice TDD for implementing tickets.                                |

Companion skills (`diagnose`, `tdd`) auto-trigger from their description's trigger phrases; invoke directly with `/diagnose` or `/tdd` if you want to drive them explicitly.

> Not to be confused with Claude Code's built-in `/loop` skill or the `ralph-loop` plugin. spec-to-ship's optional execution layer (`ralph/`) is plain bash that ships into your repo — see the Execution section below.

## Execution: `ralph/once.sh`, `ralph/afk.sh`, and `ralph/review.sh`

Triage gets your tickets to `ready-for-agent`; execution is what actually consumes them. If you opt in during `setup-skills`, three shell scripts get written to your repo at `ralph/`:

- **`ralph/once.sh`** — runs a single interactive `claude` iteration. The model reads the prompt, picks the next `ready-for-agent` ticket, and works it with you in the loop. Useful for HITL execution and for sanity-checking the prompt before turning it loose.
- **`ralph/afk.sh <N>`** — a bespoke ralph-style loop. Iterates up to `N` times inside a persistent git worktree on a `ralph` branch, each pass spawning a non-interactive `claude --print --output-format stream-json` with the prompt, the last few commits, and the open issue list piped in. Exits early when the model emits `<promise>NO MORE TASKS</promise>`. On GitHub/GitLab it pushes the branch and opens/updates a PR/MR at the end; for the local-markdown tracker it leaves the commits in the worktree for you to merge. For bd (beads), it dispatches at runtime based on the origin remote's host — GitHub/GitLab origins push and open a PR/MR; otherwise it leaves commits in the worktree.
- **`ralph/review.sh <prd-ref>`** — post-loop review companion. Works for PRDs completed via `afk.sh`, `once.sh`, or hand work — runs one non-interactive `claude --verbose --print --output-format stream-json` pass (output streams live, same `jq` filter as `afk.sh`) that diffs against base, fetches the PRD body and each child's agent brief, and posts a structured comment on the PRD ticket. The comment answers five questions:
  - **PRD coverage** — what shipped vs. what the PRD asked for.
  - **Acceptance criteria status** — each AC marked met / partial / missing.
  - **Brief-vs-PRD fidelity** — whether per-child agent briefs stayed faithful to the PRD's scope.
  - **Out-of-scope drift** — anything that shipped that the PRD didn't ask for.
  - **Follow-ups** — gaps or new tickets the review surfaces.

  Auto-detects which checkout has the implementation: main checkout wins when it has commits ahead of base; otherwise it falls back to the `${REPO_ROOT}-afk` worktree. When HEAD is on the base branch itself (e.g. `once.sh` work committed to `main` before pushing), the main-checkout range switches to `origin/<base>..HEAD` so unpushed commits stay reviewable. Idempotent — re-runs append a fresh comment with a timestamp + commit-range header so the PRD's history is a chronological log of what each pass found. Existing AFK-installed repos pick up `review.sh` by re-running `/setup-skills`, which will offer an incremental install when `ralph/` is missing only the new files.

These scripts are **bespoke shell harnesses that shell out to the `claude` CLI** — they're not Claude Code's built-in `/loop` skill, and they're not the `ralph-loop` plugin. The loop logic is plain bash that lives in your repo, so you can read it, tweak it, and check it into git alongside the prompt.

## Install

### Prerequisites

- The `claude` CLI (you already have this if you're reading this README inside Claude Code).
- Issue-tracker CLI for your choice: `gh` (GitHub), `glab` (GitLab), or `bd` (beads). The local-markdown tracker needs nothing beyond a writable repo.
- `jq` if you plan to use `ralph/afk.sh` or `ralph/review.sh` (they parse `claude --output-format stream-json`).

```sh
/plugin marketplace add bigintersmind/spec-to-ship
/plugin install spec-to-ship@bigintersmind
```

After install, skills are available namespaced as `spec-to-ship:spec`, `spec-to-ship:prd`, etc. Claude triggers them automatically based on the description in each `SKILL.md`; you can also invoke them by name. This README uses the short form (`/spec`); reach for the namespaced form (`/spec-to-ship:spec`) only if another plugin claims the same name.

## Quickstart

A typical session, from empty repo to a ticket an AFK loop can pick up:

### 1. One-time per-repo setup

```sh
/setup-skills
```

Interactively scaffolds `docs/agents/issue-tracker.md`, `docs/agents/triage-labels.md`, and `docs/agents/domain.md` (detects bd from `.beads/`, GitHub/GitLab from `git remote`, falls back to local markdown). Optionally also installs `ralph/once.sh`, `ralph/afk.sh`, and `ralph/review.sh` for AFK execution and post-loop review. Run once when adopting the workflow; re-run if you change trackers, want to add the ralph harness later, or need to pull in newly-shipped harness files via incremental install.

### 2. Stress-test the idea

```sh
/spec build a webhook signature verifier with HMAC-SHA256
/spec @docs/notes/webhook-verifier.md
/spec
```

Three equivalent forms: a one-liner argument, an `@` reference to a file, or a bare invocation followed by describing the idea conversationally. The skill interviews one question at a time and recommends an answer at each step until you confirm the plan.

### 3. Capture alignment as a PRD

```sh
/prd
```

Synthesizes the just-completed `/spec` conversation into a PRD and publishes it to the issue tracker (labelled `prd`). Run in the **same conversation** as `/spec` — it reads context, it doesn't re-interview.

### 4. Break the PRD into tickets

```sh
/issues
/issues #42
```

Turns the PRD (or a settled plan in the conversation) into vertical-slice tracer-bullet tickets, labelled `needs-triage`. The `#42` form points at an existing ticket to break that one down instead.

### 5. Triage to ready-for-agent

```sh
/triage
/triage #42
```

Walks the `needs-triage` queue and moves each issue to `ready-for-agent` (with a durable agent brief comment), `ready-for-human`, `needs-info`, or `wontfix`. Target a specific ticket with `/triage #42`.

### 6. Execute (optional)

```sh
bash ralph/once.sh        # one interactive iteration, HITL
bash ralph/afk.sh 5       # up to 5 unattended iterations in a worktree
bash ralph/review.sh 42   # post-loop PRD review against PRD #42
```

`once.sh` keeps you in the loop; `afk.sh` runs unattended through the `ready-for-agent` queue and opens a PR/MR with the result; `review.sh` runs after the loop to compare what shipped against the PRD and post a review comment on the PRD ticket. See the Execution section above for details.

## Local development

Skills live under `plugin/skills/`. Edit a `SKILL.md` and reload the plugin (or restart Claude Code) to pick up changes. The author runs this repo via symlinks from `~/.claude/skills/<name>` → `plugin/skills/<name>` so edits apply live without an install/reload cycle.

The plugin is nested under `plugin/` because marketplace install copies only the directory pointed to by `marketplace.json`'s `source` field — keeping `plugin/` as the boundary means repo-only files (this README, dogfood artifacts under `docs/agents/` and `ralph/`, etc.) don't ship to consumers.

## Contributing

This is a workflow built from the author's day-to-day; collaborators are welcome to file issues or PRs proposing refinements. Keep skills:

- **Single-purpose** — one stage of the workflow per skill.
- **Triggerable** — the description should make it obvious when Claude should invoke it.
- **Boundary-respecting** — `spec` interviews, `prd` writes, `issues` decomposes; resist letting one skill bleed into the next.

## License

See [LICENSE](LICENSE).
