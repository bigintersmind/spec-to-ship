# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Claude Code **plugin** distributed via the plugin marketplace. There is no build, test, lint, or runtime — every artifact under `plugin/` is a prompt or template that ships as-is to consumers. "Editing the codebase" means editing markdown.

### Repo layout

The plugin is nested under `plugin/` so the rest of the repo (this `CLAUDE.md`, `README.md`, `LICENSE`, dogfood artifacts under `docs/agents/` and `ralph/`) does **not** ship to consumers. Marketplace install copies only the directory pointed to by `source`.

Manifests:

- `.claude-plugin/marketplace.json` — marketplace listing at the repo root. Its `source: "./plugin"` is the boundary between repo-only files and what ships.
- `plugin/.claude-plugin/plugin.json` — plugin metadata (name, version, description). Lives inside the plugin directory.

Bumping `version` in `plugin/.claude-plugin/plugin.json` is the release knob; there is no separate publish step beyond pushing to the marketplace-referenced repo.

## Local development

The author edits via symlinks from `~/.claude/skills/` (each pointing at the corresponding `plugin/skills/<name>/`) so changes apply live. Otherwise: edit a `SKILL.md`, then reload the plugin or restart Claude Code. There is nothing to compile or run.

## Skill anatomy

Each skill is a directory under `plugin/skills/<name>/` containing a `SKILL.md` with YAML frontmatter:

```yaml
---
name: <skill-name>            # must match directory name
description: <when-to-trigger> # Claude reads this to decide auto-invocation
disable-model-invocation: true # optional; setup-skills uses this
---
```

`description` is load-bearing: it's the only signal Claude has for *when* to fire the skill, so it lists trigger phrases verbatim. `disable-model-invocation: true` makes a skill user-invocable only (used by `setup-skills` because it shouldn't fire mid-conversation).

A skill may include companion docs (`tdd/tests.md`, `tdd/mocking.md`, etc.) that the `SKILL.md` links to and reads on demand — keeps the always-loaded portion small.

A skill may also ship template files (`plugin/skills/setup-skills/ralph-templates/*.template`, `plugin/skills/diagnose/scripts/hitl-loop.template.sh`) that get *copied into a consumer repo* during setup, not executed in this repo.

## The workflow arc and skill boundaries

```
setup-skills → spec → prd → issues → triage → (AFK execution via ralph/)
```

Companions: `diagnose` (hard bugs), `tdd` (vertical-slice TDD).

Each skill is intentionally single-purpose; resist letting one bleed into the next when editing:

- `spec` interviews one question at a time to reach alignment. Does not write artifacts.
- `prd` synthesizes a settled conversation into a PRD on the issue tracker. Does not re-interview the spec.
- `issues` decomposes a PRD/plan into vertical-slice tracer-bullet tickets, classified HITL vs AFK.
- `triage` moves tickets through the canonical state machine (`needs-triage` → `needs-info` / `ready-for-agent` / `ready-for-human` / `wontfix`) and writes the durable **agent brief** that the AFK loop will read instead of the ticket body.

If you find yourself adding interview logic to `prd`, or ticket-creation logic to `spec`, you're crossing a boundary the workflow depends on.

## The setup-skills / consumer-skill contract

This is the most important architectural pattern. Consumer skills (`prd`, `issues`, `triage`) **never branch on issue tracker type**. They speak in stable verbs:

- "publish to the issue tracker"
- "fetch the relevant ticket"
- "comment on a ticket"
- "apply the `<role>` triage label"

The concrete meaning of each verb is resolved per-repo by files that `setup-skills` writes into the *consumer* repo:

- `docs/agents/issue-tracker.md` — defines tracker (bd via the `bd` CLI, GitHub via `gh`, GitLab via `glab`, local markdown under `.scratch/`, or freeform "other") and its CLI conventions.
- `docs/agents/triage-labels.md` — maps the canonical roles to actual label strings used in that repo.
- `docs/agents/domain.md` — points to `CONTEXT.md` and ADRs so skills use the project's domain vocabulary.

Seed versions of those docs live in `plugin/skills/setup-skills/issue-tracker-{beads,github,gitlab,local}.md`, `plugin/skills/setup-skills/triage-labels.md`, `plugin/skills/setup-skills/domain.md`. `setup-skills` copies and customizes them.

**When editing a consumer skill:** keep tracker-specific logic out. If a skill needs new behavior from the tracker, express it as a new stable verb and add the resolution to the seed docs in `setup-skills/` — don't hardcode `gh` or `glab` in the consumer skill.

## The AFK loop (ralph/) — opt-in execution layer

`setup-skills` optionally writes a bespoke ralph-style harness into the consumer repo at `ralph/`, sourced from `plugin/skills/setup-skills/ralph-templates/`:

- `ralph/once.sh` — single interactive `claude` iteration; HITL.
- `ralph/afk.sh <N>` — up to N non-interactive iterations in a persistent worktree on a `ralph` branch, each spawning `claude --print --output-format stream-json`. Exits early on `<promise>NO MORE TASKS</promise>`. On GitHub/GitLab it pushes and opens/updates a PR/MR; on local-markdown it leaves commits in the worktree; on bd it dispatches at runtime on the origin remote's host (GitHub or GitLab → push + PR/MR; otherwise → leave commits in the worktree).
- `ralph/prompt.md` — the prompt fed to each iteration.
- `ralph/review.sh <prd-ref>` — post-loop review companion. Runs a single `claude --print` iteration in the same worktree, diffs against base, fetches the PRD and per-child agent briefs, and posts a structured five-question review comment on the PRD ticket. Idempotent (re-runs append). Existing AFK-installed consumer repos pick this up via `setup-skills`'s incremental install path when `ralph/` is missing the new files.
- `ralph/review-prompt.md` — the prompt fed to `review.sh`.

These are **plain bash that ships into the consumer repo** — not Claude Code's `/loop` skill, not the `ralph-loop` plugin. They live in the consumer's git history so the user can read and tweak them. When editing the templates here, remember they'll be checked into someone else's repo.

The contract between `triage` and the AFK loop is the **agent brief** comment, designed to survive codebase churn that would invalidate file-path references in the original ticket body.

## Conventions when editing skills

- The `description` field's trigger phrases are the auto-invocation signal — extending a skill's scope means updating those phrases, not just the body.
- A skill that depends on per-repo config should read the relevant `docs/agents/*.md` files and **stop with a pointer to `/setup-skills` if missing**, rather than guessing.
- Triage comments and artifacts must be prefixed with `> *This was generated by AI during triage.*` so maintainers can scan AI activity in tracker history.
- Every skill that touches the codebase should read `docs/agents/domain.md` (and the `CONTEXT.md`/ADRs it points to) when present so output uses the project's domain glossary.

## Agent skills

### Issue tracker

GitHub issues via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Canonical role names used as label strings. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context. See `docs/agents/domain.md`.

### AFK loop

Installed at `ralph/`. Run `./ralph/afk.sh <N>` to loop on `ready-for-agent` tickets, or `./ralph/once.sh` for a single iteration. After the loop exits, run `./ralph/review.sh <prd-ref>` to review the implementation against a PRD. Worktree-isolated on the `ralph` branch.
