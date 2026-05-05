# Issue tracker: GitLab

Issues and PRDs for this repo live as GitLab issues. Use the [`glab`](https://gitlab.com/gitlab-org/cli) CLI for all operations.

## Required labels

The skills assume these labels already exist on the project. If any are missing when a skill tries to apply them, surface the gap to the user — don't silently create them. To create the full set up front:

```bash
for label in prd bug enhancement needs-triage needs-info ready-for-agent ready-for-human wontfix; do
  glab label create --name "$label" 2>/dev/null || true
done
```

If the user has overridden the canonical role → label string mapping in `docs/agents/triage-labels.md`, use those strings instead.

## Conventions

- **Create an issue**: `glab issue create --title "..." --description "..."`. Use a heredoc for multi-line descriptions. Pass `--description -` to open an editor.
- **Read an issue**: `glab issue view <number> --comments`. Use `-F json` for machine-readable output.
- **List issues**: `glab issue list --state opened -F json` with appropriate `--label` filters. Note that GitLab uses `opened` (not `open`) for the state value.
- **Comment on a ticket**: `glab issue note <number> --message "..."`. GitLab calls comments "notes".
- **Apply / remove labels**: `glab issue update <number> --label "..."` / `--unlabel "..."`. Multiple labels can be comma-separated or by repeating the flag.
- **Close**: `glab issue close <number>`. `glab issue close` does not accept a closing comment, so post the explanation first with `glab issue note <number> --message "..."`, then close.
- **Merge requests**: GitLab calls PRs "merge requests". Use `glab mr create`, `glab mr view`, `glab mr note`, etc. – the same shape as `gh pr ...` with `mr` in place of `pr` and `note`/`--message` in place of `comment`/`--body`.

Infer the repo from `git remote -v` – `glab` does this automatically when run inside a clone.

## When a skill says "publish to the issue tracker"

Create a GitLab issue.

## When a skill says "fetch the relevant ticket"

Run `glab issue view <number> --comments`.

## When a skill says "apply the `<role>` triage label"

Look up the actual label string in `docs/agents/triage-labels.md` for that canonical role, then `glab issue update <number> --label "<actual-string>"`. If the configured label doesn't exist on the project, surface the discrepancy to the user before applying – don't silently create labels.
