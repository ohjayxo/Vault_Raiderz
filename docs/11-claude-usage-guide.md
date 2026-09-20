# 11 — Claude Model & Effort Usage Guide

**Status:** Living document — update as the project moves phases.
**Purpose:** A quick-reference so you're not guessing which model/setting
to reach for, and not burning Opus-level usage on a task Haiku could
handle. Ordered by where the project actually is (now → later).

This is a **prediction**, not a rulebook. Vaultbreakers is pre-production
(v5.5) — the vertical slice is locked (D107) and the build phase is
documented in `13-build-guide.md`, but nothing is built yet. Everything past "Phase 0" below is my best guess at what work
is coming, based on `10-roadmap.md`'s build order and scope. Revise this
file once real phases start.

---

## How to read the tables

- **Model** — Opus 5 (deepest reasoning, most expensive), Sonnet 5
  (default workhorse), Haiku
  4.5 (fastest/cheapest, best for volume or low-stakes work).
- **Thinking** — whether it's worth turning on extended thinking (if
  your plan/model shows that toggle) or asking me to "think it through
  carefully." **Standard** = don't bother, it just adds latency/cost for
  no benefit. **Extended** = the task genuinely benefits from deliberate
  multi-step reasoning before answering.
- These are defaults, not laws. If a "Standard" task starts feeling
  hard (a doc edit that's actually a structural rewrite), bump up.

---

## Quick reference — Phase 0: Planning & Design (where we are now)

| Scenario | Model | Thinking | Why |
|---|---|---|---|
| Bouncing ideas / freeform brainstorming | Sonnet | Standard | Conversational, cheap, no benefit from deliberation overhead |
| "Look up how [other game] handles X" + discuss | Sonnet | Standard | Search-heavy, not reasoning-heavy — Sonnet synthesizes fine |
| Answering a **low-stakes** open question (`08-questions.md`) | Sonnet | Standard | e.g. Q26 case tier visibility — easy to change later |
| Answering a **high-priority/hard-to-reverse** question (Q44 tech path wipe, Q49 Riftsalt tradeable, Q38 scrap banking) | Opus | Extended | These ripple across multiple systems and are expensive to reverse once players are in it |
| Quick fact check (a stat, a rule, "did I say X already") | Sonnet or Haiku | Standard | Pure retrieval |
| Editing one section of an existing doc | Sonnet | Standard | Routine |
| **Cross-file consistency check** ("does 06-economy contradict 05-items?") | Opus | Extended | Multi-document reasoning across the whole set — this is where subtle contradictions hide |
| **Rescoring the design against the rubric** (`01-pillars.md`) | Opus | Extended | 12 weighted criteria across 11 files — genuinely hard, worth the cost since it's rare |
| "Catch me up" / session recap for a new chat | Sonnet | Standard | Retrieval + synthesis, not novel reasoning |

**Efficiency tip for this phase specifically:** don't re-paste the design
docs into new chats — they're already in the project, so any new
conversation in this project can see them. Just ask the question. If you
want me to pull from a chat we had *outside* this project, say so and
I'll search past conversations rather than you retyping it.

---

## Quick reference — Documentation & Deliverables

These come up whenever something needs to leave the design-doc set and
become a shareable artifact (for a collaborator, a future teammate, your
own reference).

| Scenario | Model | Thinking | Why |
|---|---|---|---|
| Export a doc/section as a Word file (to send someone) | Sonnet | Standard | Formatting is mechanical |
| One-pager or handout as a PDF | Sonnet | Standard | Same |
| Reading a reference PDF (Roblox policy doc, a competitor's patch notes) | Sonnet | Standard | Haiku is fine if it's short and you just need a fact pulled out |
| Pitch deck / onboarding deck (pptx) for a collaborator | Sonnet | Standard (Extended if it's investor-facing and the *narrative* matters) | Slide mechanics are easy; the story arc is the hard part when it matters |
| **Economy/balance math** — sink/faucet ratios, drop-rate spreadsheets, Grade odds tuning | Opus | Extended | Numbers interact (raid % × market tax × Key sink, etc.) — an error compounds silently and this is the system already flagged as `[OPEN — known gap]` |
| Scope map / roadmap diagram | Sonnet | Standard | I can render this inline as a diagram — no need to leave chat |
| "What changed between v4 and v4.2" style summary breakdown | Sonnet | Standard | Retrieval + diff, not deep reasoning |

---

## Quick reference — Vertical Slice Build (next phase, per `10-roadmap.md`)

This is the phase where Claude Code becomes the main tool instead of
chat. Worth knowing now so you're not surprised later.

| Scenario | Model | Thinking | Why |
|---|---|---|---|
| **Server-authoritative data layer design** (MemoryStore/DataStore reconciliation, R5) | Opus | Extended | Explicitly flagged as "cannot be retrofitted" — the single most expensive place to get wrong |
| Routine Luau scripting (node collection, UI panels, movement) | Sonnet | Standard | This is most of the actual build |
| Boilerplate / repetitive code (tweens, placeholder test data, simple config) | Haiku | Standard | High volume, low stakes — don't spend Sonnet/Opus budget here |
| Writing test suites | Sonnet | Standard | — |
| **Debugging a subtle bug / suspected exploit / race condition** | Opus | Extended | Exploit resistance is already the lowest-scored rubric criterion (6/10) — this is worth the spend |
| Pre-ship exploit-resistance review of a finished system | Opus | Extended | Same reasoning — cheap insurance against the thing the docs call "the most attractive exploit target possible" |
| Syntax fixes, linting, formatting passes | Haiku | Standard | Mechanical |

**When you get here:** Claude Code (desktop, or terminal/VS Code if
that's your setup) is the right tool for the actual scripting — not
chat. I can flag this again when the slice build actually starts.

---

## Quick reference — Art, UI & 3D Pipeline

Noted per your workflow: **your girlfriend is doing the 3D models**, and
you're considering the **SketchUp connector** for basic base/architecture
geometry (per `10-roadmap.md`, SketchUp is already the planned tool for
base/architectural geometry, Blender for characters). I checked — a
Trimble SketchUp connector exists and can be connected when you're ready
for that workflow (not connected yet). Claude isn't a substitute for
either artist's actual modeling work — its role here is prep and
iteration support, not asset creation.

| Scenario | Model | Thinking | Why |
|---|---|---|---|
| UI/HUD mockup ideation (menus, Bank/Exposed meter, etc.) | Sonnet | Standard | I can render a visual mockup inline to react to |
| Figma work (already connected for you) | Sonnet | Standard | Use the connector directly rather than describing in prose |
| SketchUp geometry work (once connected) | Sonnet | Standard | Basic structure generation, not a reasoning-heavy task |
| Reference/mood-board image gathering for your girlfriend | Sonnet | Standard | Image search, not generation — useful for "here's what Rust's HQM workbench looks like" type asks |
| Actual 3D asset creation | — | — | Not a Claude task. Flagging so this doc stays honest about scope. |

---

## Quick reference — Playtest & Launch Prep (later)

| Scenario | Model | Thinking | Why |
|---|---|---|---|
| Synthesizing playtest feedback into themes | Sonnet (Opus if the volume/nuance is high) | Standard, bump to Extended for large messy datasets | Clustering scattered feedback into actionable signal gets harder with volume |
| Re-verifying Roblox monetization policy before shipping Cases/Keys | Sonnet + web search | Standard | Always search live — `09-research.md` explicitly flags this as something that "moves fast," don't trust memory here |
| Store page / marketing copy | Sonnet | Standard | — |

---

## General rules of thumb (credit efficiency)

1. **Default to Sonnet.** It's the right call for ~80% of what this
   project will need — chat, doc edits, routine code, search synthesis.
   Only reach for Opus when the task is genuinely multi-step,
   high-stakes, or spans many files/numbers at once.
2. **Reserve Opus + extended thinking for irreversible or compounding
   decisions:** economy math, server-authoritative architecture,
   exploit review, cross-document consistency, rubric rescoring. These
   are exactly the places `07-decisions.md` and `10-roadmap.md` already
   flag as high-stakes — the docs are telling you where to spend.
3. **Use Haiku for volume, not for judgment calls.** Boilerplate code,
   simple formatting, batch renaming, quick lookups. Anything where
   "good enough, fast" beats "deliberated."
4. **Keep design-doc questions inside this project** rather than
   starting fresh chats outside it — you lose the automatic file access
   and end up re-explaining context, which costs more than the answer
   itself.
5. **One topic per session where it's a long working session** (e.g. a
   full Tech Path balancing pass). Long, sprawling chats that drift
   across unrelated topics make every subsequent message reprocess more
   context than it needs to.
6. **For Claude Code later:** treat model selection the same way — plan
   / architecture steps warrant a stronger model and a beat of thinking;
   grinding out the next 200 lines of an established pattern doesn't.
7. **Don't pre-optimize this document.** It's a prediction. Once the
   vertical slice actually starts, real usage patterns will tell you
   more than this guess does — come back and edit it then.

---

## Changelog

- **2026-09-19** — Initial draft, written during pre-production (v4.2),
  before vertical slice scope is confirmed (Q23). Predictive for
  everything past Phase 0.
- **2026-09-19** — Version reference updated to v5.2; removed stale
  "this is what's answering you" model note.
- **2026-09-19** — Version reference updated to v5.5; slice now locked.
