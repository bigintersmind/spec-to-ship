# Issue tracker: Local Markdown

Issues and PRDs for this repo live as markdown files under `.scratch/`.

Commit `.scratch/` to git despite the name — these files *are* the issue tracker. If `.scratch/` is gitignored (a common default), remove that entry or scope it to other paths, otherwise issues won't be visible to teammates or to AFK agents working in a worktree.

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`
- The PRD is `.scratch/<feature-slug>/PRD.md`
- Implementation issues are `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`
- Triage state is recorded as a `Status:` line near the top of each implementation issue file (see `docs/agents/triage-labels.md` for the canonical role strings, and use the actual string from the right-hand column there). PRDs (`PRD.md`) don't carry a `Status:` line — the filename is their kind marker.
- Cross-references between issues and the PRD use relative paths (e.g. `../PRD.md`, `./03-other-issue.md`)
- Comments and conversation history append to the bottom of the file under a `## Comments` heading, each entry timestamped

## When a skill says "publish to the issue tracker"

Create a new markdown file under `.scratch/<feature-slug>/` (creating the directory if needed). For PRDs use `PRD.md`; for issues use `.scratch/<feature-slug>/issues/<NN>-<slug>.md` with the next available number.

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user will normally pass the path directly.

## When a skill says "apply the `<role>` triage label"

Look up the actual string in `docs/agents/triage-labels.md` for that canonical role, then set or update the `Status:` line near the top of the file. There is no central "create label" step for local markdown – the string is whatever the file says.

For the `prd` kind role, this is a no-op — the filename `PRD.md` already declares the kind. Don't add a `Status: prd` line; recognize PRDs by their filename pattern instead.

## Feature slug

When publishing the first artifact for a new feature, ask the user for a short slug (kebab-case, no spaces). Don't auto-generate one from the title – the slug becomes a directory name and ends up in cross-references, so the user should pick it deliberately.
