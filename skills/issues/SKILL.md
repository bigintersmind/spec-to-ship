---
name: issues
description: Break a plan, spec, or PRD into independently-grabbable issues on the project issue tracker using tracer-bullet vertical slices, classified as HITL (human-in-the-loop) or AFK (autonomous-ready). Use when user wants to convert a plan into issues, create implementation tickets, break down work into tracer bullets, or prep tickets for an AFK loop to pick up.
---

# Issues

Break a plan into independently-grabbable issues using vertical slices (tracer bullets), classified HITL or AFK so an autonomous loop can safely pick up the AFK ones.

## Process

### 1. Load the per-repo conventions

This skill speaks in stable verbs — "publish to the issue tracker", "fetch the relevant ticket", "apply the `needs-triage` triage label". The concrete behavior for *this* repo lives in two files:

- `docs/agents/issue-tracker.md` – defines the tracker (GitHub, GitLab, local markdown, or other) and the CLI/file-write conventions for each verb
- `docs/agents/triage-labels.md` – maps the canonical role `needs-triage` to the actual label string this repo uses

Read both files before doing any tracker operations. If either is missing, tell the user to run `/setup-skills` first and stop.

Also read `docs/agents/domain.md` if it exists (and the `CONTEXT.md`/ADRs it points to). Issue titles and descriptions should use the project's domain glossary vocabulary, and respect any ADRs in the area you're touching.

### 2. Gather context

Work from whatever is already in the conversation context. If the user passed an issue reference (issue number, URL, or path) as an argument, **fetch the relevant ticket** following the conventions in `docs/agents/issue-tracker.md` and read its full body and comments. Treat that ticket as the parent.

### 3. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code.

### 4. Draft vertical slices

Break the plan into **tracer bullet** issues. Each issue is a thin vertical slice that cuts through ALL integration layers end-to-end, NOT a horizontal slice of one layer.

<vertical-slice-rules>
- Each slice delivers a narrow but COMPLETE path through every layer (schema, API, UI, tests)
- A completed slice is demoable or verifiable on its own
- Prefer many thin slices over few thick ones
</vertical-slice-rules>

**HITL vs AFK classification.** Each slice is either:

- **AFK** – an agent can implement and merge this without human interaction. The acceptance criteria are fully specified, the design decisions are settled, and verification is automatable (tests, type checks, lint).
- **HITL** – requires a human in the loop. Use this when the slice involves an architectural decision not yet made, a design or UX review, a security/privacy judgment call, an irreversible change (data migration, public API), or any step where "looks right" is the verification.

Prefer AFK over HITL where possible, but do not optimistically mark something AFK to keep the autonomous loop fed. A wrongly-AFK slice is worse than a correctly-HITL one – it produces work that gets reverted. When in doubt, mark HITL and explain what would need to be settled to make it AFK.

### 5. Quiz the user

Present the proposed breakdown as a numbered list. For each slice, show:

- **Title** – short descriptive name
- **Type** – HITL or AFK (with one-line reason if HITL)
- **Blocked by** – which other slices (if any) must complete first
- **User stories covered** – which user stories this addresses (if the source material has them)

Then walk the user through these questions **one at a time** – present, get an answer, move on:

1. Does the granularity feel right? (too coarse / too fine / good)
2. Are the dependency relationships correct?
3. Are the HITL vs AFK classifications correct?
4. Should any slices be merged or split?

Iterate until the user approves the breakdown.

### 6. Publish the issues

For each approved slice, **publish to the issue tracker** following the conventions in `docs/agents/issue-tracker.md`, using the body template below. **Apply the `needs-triage` triage label** using the actual label string from `docs/agents/triage-labels.md`.

Publish in dependency order (blockers first) so you can reference real issue identifiers in the "Blocked by" field.

If a parent ticket was provided in step 2, after publishing all children, post a single comment on the parent listing the child references. Do NOT close or modify the parent's body.

### 7. Hand off

Tell the user the next step is `/triage` — walk through the new tickets and promote each to `ready-for-agent` (with a durable agent brief that the AFK loop can implement against) or `ready-for-human`. The AFK loop watches for `ready-for-agent` only; until triage runs, the new tickets sit in `needs-triage`.

The HITL/AFK distinction made here in step 4 is the planner's *intent*. Triage is where it becomes the tracker's *state* — you can override at triage time if your understanding has shifted.

<issue-template>
## Parent

A reference to the parent ticket (omit this section if there is no parent).

## What to build

A concise description of this vertical slice. Describe the end-to-end behavior, not layer-by-layer implementation.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

Each criterion should be observable and testable from outside the system – an input/output pair, an externally-visible state change, or a check a CI step could run. Avoid restating the title ("- [ ] Feature works") and avoid implementation details ("- [ ] Uses Redis"). A reader should be able to tell, with no further context, whether the criterion is met.

## Blocked by

- A reference to the blocking ticket (if any)

Or "None – can start immediately" if no blockers.

</issue-template>
