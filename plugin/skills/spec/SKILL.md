---
name: spec
description: Use when the user wants to plan or stress-test a new feature, design, or implementation before writing code. Triggers on phrases like "spec this out," "let's plan X," "grill me on this," "walk me through this design," or any signal the user wants alignment before building. Interviews one question at a time, walks the decision tree, recommends an answer for each, and checks the codebase before asking anything the code can answer.
---

# Spec

Interview the user relentlessly about every aspect of this plan until you reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

## Process

Ask the questions **one at a time**. Bundling questions makes the conversation shallow — the user can't react to your recommendation, and follow-up questions that depend on the answer don't get asked. One at a time forces real engagement.

Before asking, check whether the codebase already answers the question. Only ask what the code can't tell you.

If `docs/agents/domain.md` exists, read it (and the `CONTEXT.md`/ADRs it points to) so your questions and recommendations use the project's domain glossary vocabulary and respect existing architectural decisions. If it doesn't exist, proceed silently.

When you believe we've covered the tree, summarize the agreed-upon plan and wait for the user's explicit confirmation.

## When the spec is settled

Once the user confirms the plan, suggest `/prd` as the next step to capture the alignment as a written PRD published to the issue tracker. From there, `/issues` breaks the PRD into tracer-bullet vertical slices.

If the user wants to skip the PRD and go straight to issues (small/obvious work), `/issues` accepts a settled plan from the conversation directly.
