# Design Principles

This document is a decision aid for maintainers of `spec-to-ship`. It is not a manifesto and not a contract — it exists to keep the project simple as it grows.

It answers a different question than [`skill-craft.md`](skill-craft.md): that doc is *how to write a skill well*; this one is *whether a piece of surface area should exist at all*. Reach for this before adding a flag, a config step, a trigger phrase, or a new skill; reach for `skill-craft.md` once you've decided something should exist and are writing it.

The unifying idea: *simplicity is not the absence of capability — it's the careful arrangement of capability so the user only meets it when they're ready.*

---

## Principle 1 — Design the defaults of the defaults

The out-of-box experience disproportionately shapes the user's mental model of what the project *is*. First impressions of the install flow, the seed templates, and the empty states are load-bearing — get them right and the rest can be deeper without feeling overwhelming.

For this project that means:

- The first-run experience is `setup-skills` running against a fresh consumer repo. Treat that single command as the most important piece of UX in the codebase.
- Seed templates (`plugin/skills/setup-skills/issue-tracker-*.md`, `triage-labels.md`, `domain.md`) are not boilerplate — they're the project's worked example of what "good" looks like. Edit them with the same care as a `SKILL.md`.
- "Empty state" = a consumer skill running before `docs/agents/*.md` exists. The skill must **stop with a pointer to `/setup-skills`**, never guess. A confused first-run is worse than a halted one.
- The first action a new user takes should produce a tangible artifact (a configured tracker, a triaged ticket, a working PRD), not a settings screen.

**Decision heuristics:**

- For any new feature, ask: *what does a brand-new user see, and what is the shortest path from install to a real artifact?* If that path got worse, the feature has to earn it.
- New configuration steps in `setup-skills` are expensive. Prefer detection (probe the environment, propose a default) over interrogation (ask abstractly).
- Onboarding flows are ordered: the most common path requires the fewest decisions. Rare paths are reachable but never on the critical path.

---

## Principle 2 — Progressive disclosure

Show the minimum needed to be useful. Push depth behind explicit asks: companion docs, additional commands, escape hatches that don't appear until you look for them.

For this project that means:

- The auto-loaded surface (skill `description` fields, `MEMORY.md`, top-level READMEs) is precious context budget. Anything optional belongs in a file the skill reads when it needs to. (The `SKILL.md`-lean side of this — one screen of attention, companion files on demand — is covered as authoring mechanics in `skill-craft.md` §6.)
- Niche skills earn explicit invocation — `disable-model-invocation: true` is the project's "long-press menu." Auto-invocation is reserved for broadly useful skills.
- The arc (`setup-skills → spec → prd → issues → triage → AFK`) progressively discloses itself: a user can run `/spec` without ever knowing `/triage` exists. Each step references the next; none requires the whole map up front.

**Decision heuristics:**

- Before adding a parameter, knob, or trigger phrase: *would 80% of users ever change/use this?* If no, hard-code the default and document the override deeper.
- Don't surface a knob in trigger phrases unless turning it changes the user's mental model. Internal knobs stay internal.
- If a new skill seems to need three new verbs, you're probably crossing a boundary — see the contract in `CLAUDE.md`.

---

## Principle 3 — Sensible defaults over configuration

Configuration is paid for by every user, every time they encounter it. Defaults are paid for once, by the maintainer. A wrong default is the maintainer's bug to fix — not the user's responsibility to avoid.

For this project that means:

- Every config option begins with the question: *can we eliminate this by picking one?*
- Where context-dependence is real (per-repo tracker, per-repo labels), narrow the question first by detecting context (`gh` available? `origin` is GitHub? `bd` initialized?). Then propose, don't ask.
- Defaults must **compose**. Default tracker + default labels + default agent-brief format have to work together with no coordinating choices required. Shipping a set of defaults that need to be aligned by the user defeats the purpose.
- The canonical triage labels are *the actual label strings* by default. Mapping is an override, not a starting point.

**Decision heuristics:**

- "It depends" is a smell. If something genuinely depends on user context, detect the context — don't ask.
- If two defaults conflict in the common case, one of them is wrong. Fix the default; don't add a "preference."
- A confirmation prompt for something we can already infer is a configuration question in disguise.

---

## Adapted supporting principles

Visual/interaction principles (direct manipulation, performance-as-UX, skeuomorphism) don't translate. These do:

- **Consistency as a force multiplier.** Reuse before invention — every new vocabulary item is a tax on every user and on Claude's pattern-matching. The mechanics of this (speaking in stable verbs, resolving them per-repo) live in `skill-craft.md` §5; the *principle* is that consistency is a design goal worth saying "no" to novelty for.
- **Constraints as a feature.** Each skill stays single-purpose. Saying "no, that belongs in the next skill" *is* the design work — see `skill-craft.md` §1 and the boundaries in `CLAUDE.md`.
- **Obvious → Easy → Possible.** Walking the arc should be obvious. Customizing per-repo behavior via `docs/agents/*.md` should be easy. Forking the AFK loop, writing your own skill, editing the seed templates should be possible. Don't try to make rare tasks obvious — that's what clutters the surface.

---

## Anti-patterns to push back on

- A new flag whose value 95% of users will never change.
- A configuration option added to serve a single edge case.
- A "helpful" prompt asking the user to confirm what we can already detect.
- New trigger phrases that overlap with an existing skill (creates auto-invocation ambiguity).
- A cross-cutting feature that taxes every skill to serve one.
- Documentation that re-narrates what the code does instead of why a decision was made.
- A skill description that grows past one screen because new behavior was bolted on instead of split out.

---

## When in doubt

Before adding something, score it against:

1. Does this degrade the first-run experience for new users?
2. Does it expose complexity that 80%+ of users will ignore?
3. Does it ask the user a question we could answer for them?
4. Does it introduce vocabulary that overlaps with what's already there?
5. Does it push a single-purpose skill toward being two skills?

If the answers don't justify the addition, the simpler path is almost certainly right — even if it leaves a real-but-rare need unmet. **Rare needs become escape hatches, not first-class features.**
