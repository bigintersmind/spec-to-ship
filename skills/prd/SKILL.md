---
name: prd
description: Use when the user wants to convert the current conversation and codebase context into a PRD published to the issue tracker. Triggers on phrases like "write this up as a PRD," "turn this into a ticket," "draft a PRD," "let's get this on the board," or any signal the planning phase is done and the user wants a written artifact. Synthesizes existing context rather than re-interviewing — designed to follow /spec or other alignment work.
---

# PRD

Convert the current conversation context and codebase understanding into a PRD published to the project issue tracker. Do not re-litigate the spec — assume alignment on the feature itself has already happened. Limited interviewing is allowed for module decomposition and test scope (step 3 below), since those decisions often only become legible while drafting.

If the conversation lacks alignment on the feature itself, recommend `/spec` first instead of drafting cold. This skill is for capturing settled understanding, not building it.

## Process

### 1. Load the per-repo conventions

This skill speaks in stable verbs — "publish to the issue tracker", "apply the `prd` triage label". The concrete behavior for *this* repo lives in two files:

- `docs/agents/issue-tracker.md` – defines the tracker (GitHub, GitLab, local markdown, or other) and the CLI/file-write conventions for each verb
- `docs/agents/triage-labels.md` – maps the canonical roles (including `prd`) to the actual label strings this repo uses

Read both files before doing any tracker operations. If either is missing, tell the user to run `/setup-skills` first and stop.

Also read `docs/agents/domain.md` if it exists (and the `CONTEXT.md`/ADRs it points to). Use the project's domain glossary vocabulary throughout the PRD, and respect any ADRs in the area you're touching.

### 2. Explore the codebase

Explore the repo to understand the current state of the code, if you haven't already.

### 3. Sketch the modules

Sketch the major modules you will need to build or modify. Actively look for opportunities to extract deep modules — modules that encapsulate substantial functionality behind a simple, testable interface that rarely changes — over shallow ones.

Then walk the user through these questions **one at a time** – present, get an answer, move on:

1. Does the proposed module decomposition match your expectations?
2. Which of these modules do you want tests written for?

These are the only questions this skill should ask. Everything else should already be settled by `/spec` or the prior conversation.

### 4. Draft the PRD

Write the PRD using the template below. The Step 3 module decomposition and test-scope answers feed directly into the "Implementation Decisions" and "Testing Decisions" sections — don't restart from a blank page.

### 5. Confirm and publish

Show the user a one-line summary of where you're about to publish (per `docs/agents/issue-tracker.md`) and which triage label you'll apply (per `docs/agents/triage-labels.md`). Confirm before acting.

Then **publish to the issue tracker** following the conventions in `docs/agents/issue-tracker.md`, and **apply the `prd` triage label** using the actual label string from `docs/agents/triage-labels.md`. The `prd` label marks the artifact as a planning doc — a PRD doesn't carry a state label like `needs-triage` because there's no implementation work in the PRD itself, just children waiting to be spawned by `/issues`.

### 6. Hand off

Print the published PRD's identifier (URL, issue number, or file path) and tell the user the next step is `/issues <ref>` to break it into tracer-bullet vertical slices. The `issues` skill expects this PRD as the parent and will post a comment back on it listing the child issues once they're published.

<prd-template>

## Problem Statement

The problem the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A numbered list of user stories in the format:

1. As an <actor>, I want <feature>, so that <benefit>

<user-story-example>
1. As a mobile bank customer, I want to see balances on my accounts, so that I can make better-informed decisions about my spending.
</user-story-example>

Cover every distinct user-facing capability the feature delivers. Err toward more stories rather than fewer, but each story must capture a distinct piece of value — do not pad with rephrasings of the same story.

## Implementation Decisions

A list of implementation decisions made during planning. This can include:

- The modules that will be built or modified (from step 3)
- The interfaces of those modules
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do not include specific file paths or code snippets. PRDs outlive the code layout they were written against, and stale paths erode trust in the document.

## Testing Decisions

For each module the user wants tested (from step 3), describe the test surface in terms of external behavior — inputs, outputs, observable side effects — not implementation details. Reference prior art in the codebase where similar tests exist.

## Out of Scope

Things explicitly excluded from this PRD. When the exclusion isn't obvious, briefly note why — otherwise this section becomes a graveyard of unexplained omissions.

## Further Notes

Any further notes about the feature.

</prd-template>
