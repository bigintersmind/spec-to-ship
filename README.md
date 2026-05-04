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

## Execution: `ralph/once.sh` and `ralph/afk.sh`

Triage gets your tickets to `ready-for-agent`; execution is what actually consumes them. If you opt in during `setup-skills`, two shell scripts get written to your repo at `ralph/`:

- **`ralph/once.sh`** — runs a single interactive `claude` iteration. The model reads the prompt, picks the next `ready-for-agent` ticket, and works it with you in the loop. Useful for HITL execution and for sanity-checking the prompt before turning it loose.
- **`ralph/afk.sh <N>`** — a bespoke ralph-style loop. Iterates up to `N` times inside a persistent git worktree on a `ralph` branch, each pass spawning a non-interactive `claude --print --output-format stream-json` with the prompt, the last few commits, and the open issue list piped in. Exits early when the model emits `<promise>NO MORE TASKS</promise>`. On GitHub/GitLab it pushes the branch and opens/updates a PR/MR at the end; for the local-markdown tracker it leaves the commits in the worktree for you to merge.

These scripts are **bespoke shell harnesses that shell out to the `claude` CLI** — they're not Claude Code's built-in `/loop` skill, and they're not the `ralph-loop` plugin. The loop logic is plain bash that lives in your repo, so you can read it, tweak it, and check it into git alongside the prompt.

## Install

```sh
/plugin marketplace add bigintersmind/spec-to-ship
/plugin install spec-to-ship@spec-to-ship
```

After install, skills are available namespaced as `spec-to-ship:spec`, `spec-to-ship:prd`, etc. Claude triggers them automatically based on the description in each `SKILL.md`; you can also invoke them by name.

## Local development

Skills live under `skills/`. Edit a `SKILL.md` and reload the plugin (or restart Claude Code) to pick up changes. The author runs this repo via symlinks from `~/.claude/skills/` so edits apply live without an install/reload cycle.

## Contributing

This is a workflow built from the author's day-to-day; collaborators are welcome to file issues or PRs proposing refinements. Keep skills:

- **Single-purpose** — one stage of the workflow per skill.
- **Triggerable** — the description should make it obvious when Claude should invoke it.
- **Boundary-respecting** — `spec` interviews, `prd` writes, `issues` decomposes; resist letting one skill bleed into the next.
