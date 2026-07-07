---
name: spec
description: Use when the user wants to plan or stress-test a new feature, design, or implementation before writing code — aligning on the hard decisions before building. Triggers on phrases like "spec this out," "let's plan X," "grill me on this," "walk me through this design," or any signal the user wants alignment before building. Comes before /prd and /issues in the workflow, and produces alignment rather than a written artifact.
---

# Spec

Interview the user about a design until you reach genuine shared understanding — walking every branch of the decision tree, resolving dependencies one at a time, recommending an answer at each step. This is a grilling, not a neutral survey: you hold a point of view and press it. The skill builds alignment; it does **not** write artifacts — when the design is settled, hand off to `/prd`.

## The rule that makes this work: one question at a time

Ask exactly one question, then stop and wait for the answer. This is the whole discipline — everything else is mechanical.

Bundling questions destroys the session. When you ask three at once, the user answers at the surface and reacts to the batch instead of engaging each decision. Worse, the follow-up questions that *depend* on an answer never get asked — you've committed to a branch of the tree before learning which branch you're on.

**Red flags that you're about to break it:**

| Thought | Reality |
|---------|---------|
| "Let me ask a few quick things to save round-trips" | The round-trips are the point. One question. |
| "These are related, so I'll group them" | Related means dependent. Dependencies are the reason to ask them separately, not together. |
| "The user seems to be in a hurry" | A shallow spec is what wastes their time — it ships the wrong thing. |

## Process

If `docs/agents/domain.md` exists, read it (and the `CONTEXT.md`/ADRs it points to) before you start, so your questions and recommendations use the project's domain glossary vocabulary and respect existing architectural decisions. If it doesn't exist, proceed silently.

Then, for each decision on the tree, in dependency order:

1. **Check the codebase first.** Before asking anything, look — the answer may already be in the code. Only ask what the code can't tell you. A question the repo already answers erodes the user's trust that you're paying attention.
2. **Ask one question, with your recommendation.** Don't interview neutrally — state the answer you'd choose and why. A recommendation gives the user something to push against, which surfaces disagreement far faster than an open-ended prompt.
3. **Absorb the answer and let it reshape the tree.** The answer may open new branches or prune others. Re-rank what to ask next based on what you just learned, rather than marching through a pre-baked list.

## When the spec is settled

When you believe the tree is covered, summarize the agreed-upon plan and wait for the user's **explicit** confirmation — don't treat silence as assent.

Once confirmed, suggest `/prd` as the next step: it captures this alignment as a written PRD published to the issue tracker, and from there `/issues` breaks the PRD into tracer-bullet vertical slices. If the work is small and obvious and the user wants to skip the PRD, `/issues` accepts a settled plan straight from this conversation.
