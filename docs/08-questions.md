# 08 — Questions

Q-numbers are permanent and never reused. Answered questions move to the
bottom with a pointer into `07-decisions.md`.

**Status:** Q1–Q13 answered in v4 · Q14–Q58 answered in v5,
except Q33, Q34 (explicitly left open). Q59–Q69 (platform/technical limitations)
answered — see D54–D64. Q70 answered — see D93. Q23 and Q48 answered
in v5.5 — see D107, D108. Rule-leak fixes, follow-ups and build-phase calls → D65–D114
(not Q-numbered; decided directly). **Only Q33/Q34 remain open, both
parked and neither blocks the slice.**

---

# OPEN QUESTIONS

## PvE & LOOT DISTRIBUTION

### Q33 — Boss loot to killer or on the ground? `[OPEN — explicitly parked]`
- **Direct to killer:** clean, no drama
- **Ground drop:** a third party can swoop the kill — chaotic and
  memorable, but deeply frustrating
- **Open sub-question, raised when this was discussed:** if a crew
  downs a boss together, does "to the killer" mean the player who landed
  the final hit, or does it need its own crew-specific rule layered on
  top of D50's contribution-weighted split?

### Q34 — Boss loot instanced per participant or shared? `[OPEN — explicitly parked]`
- **Instanced:** kills loot drama inside crews entirely
- **Shared pool:** crew negotiates the split via D50's contribution-
  weighted + gift-option model, but creates real crew politics either way

**Both explicitly left open for further thought — not yet ready to
decide.**

---

## UNRESOLVED SECONDARY DETAIL (raised but not directly asked)

These surfaced while answering other questions and don't have a clean
bubble-question shape yet — flagged for a future conversational pass
rather than answered here.

- **Blueprint Mastery vs. the D33 wear-out rule** — does relearning a
  worn-out **Advanced** blueprint preserve accumulated Mastery, or reset
  it? (Prototype no longer wears out — D77.) v1.0 scope, not slice.
- **Scrap → Marks conversion rate** (D68, D84) — v1.0 scope (seasons are
  out of the slice).

Resolved in v5.4–v5.5 and removed from this list: Crew Vault
permissions/disband (D90, D91), crew tenure duration and respec refund
starting values (D109), gear score formula (D92), sharding metric
(D79), 30-minute shield vs. Blackout (D75), Marks name (D84), rebirth
incentive (moot — D86).

---

# ANSWERED

## From v4 (original)

| Q | Question | Answer | See |
|---|---|---|---|
| Q1 | Offline raiding? | Keep, 8% cap | D1 |
| Q2 | Rebirth model? | Hybrid | D2 |
| Q3 | Lockpick skill ceiling? | High, expressed as speed | D3 |
| Q4 | Solo or crew raids? | Solo low tier, crew high tier | D4 |
| Q5 | Market scope? | Global, CS-style rarity | D9, D10 |
| Q6 | Destruction? | Steal-only 1–7, real destruction 8–10 | D5, D23 |
| Q7 | Plot persistence? | Persistent | D6 |
| Q8 | Session length? | 45+ min deep sessions | D7 |
| Q9 | Viable solo paths? | All three pillars | D8 |
| Q10 | Trading gate? | Progress-gated | `06-economy.md` |
| Q11 | Vaultborn announcement? | Zone radius, decaying signal | `05-items.md` |
| Q12 | Crew size? | Min 2, max 4 | `01-pillars.md` |
| Q13 | First Robux prompt? | At global trading unlock | `06-economy.md § First Robux prompt`, D82 |
| — | Cases/Keys model? | Option A — gameplay currency only | D15 |
| — | Hunger? | Cut | D17 |
| — | Teas? | Deferred to Season 2 | D17 |
| — | Resource count? | Four, Rust-style | D14 |
| — | Class system? | Replaced by Tech Path | D11 |

## From this round (v4.2 → v5 questionnaire)

| Q | Question | Answer | See |
|---|---|---|---|
| Q14 | Do seasons wipe anything beyond rank? | Rank + Tech Path wipe; economy persists | D48 (reconciled with Q44/D19; amended by D68, D72) |
| Q15 | Publish Grade odds? | No — kept hidden | D46 |
| Q16 | Seed-sensitive skins at launch? | 2–3 | D47 |
| Q17 | Is gear tradeable? | No — pickaxe skins trade instead (was Yes, D21) | D111 |
| Q18 | Crew vaults? | Yes, shared Crew Vault | D49 |
| Q19 | Crew raid loot split? | Contribution-weighted + gift option | D50 |
| Q20 | Revisit tiered destruction | Too soft — real destruction added at tiers 8–10 | D23 |
| Q22 | Solo-friendly Rift access? | Yes, much harder | D27 |
| Q24 | One key type or tiered? | Tiered — Standard/Rift/Event | D30 |
| Q25 | Do Cases expire? | No — permanent | D31 |
| Q26 | Case tier visible before opening? | No — total mystery, read the base instead | D32 |
| Q28 | Blueprints permanent or consumable? | Tiered: Common permanent, Advanced wears out (Prototype exempt — D77) | D33 → D77 |
| Q30 | Prototype recipes server-unique or shared? | Not server-unique; capped 1-per-player, never crew-shared | D34 |
| Q31 | Blueprint drops visible before pickup? | Yes, for Advanced+ | D52 |
| Q32 | Does learning a blueprint announce publicly? | Yes — Prototype only (narrowed) | D35 → D78 |
| Q35 | A world boss above Rift tier? | Yes | D28 |
| Q36 | Can mobs raid bases beyond Scavs? | Yes, higher-tier mobs at high-tier bases | D29 |
| Q37 | Do bosses scale with group size? | Soft curve; ~95% solo-impossible at top tier, improvable with gear/skill | D26 |
| Q38 | Can Research Scrap be banked at all? | Yes, small separate cap (confirmed current design) | `02-core-loop.md § Bank vs Exposed` |
| Q39 | Should the Research Bench consume the item? | Yes, no softened version | D51 |
| Q41 | Workshop rental: automated or manual? | Manual | D24 |
| Q43 | Are Fragments tradeable? | Yes | D22 |
| Q44 | Does the Tech Path reset at season? | Yes, fully wipes — **superseded:** staggered by tier | D19 → D72 |
| Q45 | Are other players' Tech Path nodes visible? | Visible to crewmates only | D36 |
| Q46 | Crew-shared tech nodes? | Yes, with a join/leave tenure lockout | D25 |
| Q47 | Refund on Tech Path respec? | Partial refund | D37 |
| Q49 | Is Riftsalt tradeable? | Yes | D20 |
| Q50 | Do Voltstone rich-nodes announce themselves? | Yes, visible landmark | D39 |
| Q51 | Should base upgrades cost Voltstone at high tiers? | Yes | D40 |
| Q52 | Node respawn: timer or depletion? | Depletion/migration (Reaches+); Homestead stays fixed-timer | D38 |
| Q54 | Do crops need tending, or pure timer? | Pure timer | D41 |
| Q55 | Are Greenhouses raidable separately from the vault? | Yes, lower-stakes raid type | D42 |
| Q56 | Should a rare crop only grow in contested zones? | No — all crops safe anywhere | D43 |
| Q57 | Tea duration: fixed or scaling? | Scales with Workshop tier | D44 |
| Q58 | Can teas be crew-shared? | No — always personal | D45 |

## From technical limitations audit (this round)

| Q | Question | Answer | See |
|---|---|---|---|
| Q59 | Per-player data vs. DataStore's cap? | Defer compression until real usage data exists | D54 |
| Q60 | Plot lifecycle when inactive? | Archive/hibernate, restore on return | D55 |
| Q61 | Homestead: shared world or sharded? | Sharded neighborhoods by vault tier | D56 |
| Q62 | Build-piece budget per plot? | Hard tier-scaled cap, Decor included | D57 |
| Q63 | Broadcast volume vs. message cap? | One prioritized event queue | D58 |
| Q64 | Concurrent Scav Wave cap? | Server-wide ceiling, queue overflow | D59 |
| Q65 | Tech Path UI on mobile? | Single mobile-first vertical tree | D60 |
| Q66 | Trade/crew negotiation without chat? | Zero chat required everywhere | D61 |
| Q67 | Workshop rental across shards? | Cross-shard directory, built now | D62 |
| Q68 | Lock seed variants or prototype first? | Prototype first | D63 |
| Q69 | HUD stacking during a raid? | Unified threat-priority strip | D64 |
| Q70 | Crop "seeds" vs. the "Seed" pattern roll? | Renamed the roll to "Pattern" | D93 |
| Q23 | Vertical slice scope — final line? | Locked as listed in `10-roadmap`, plus raid escort and a minimal Level gate; Workshop II/Fragments stay out; armor added later | D53 → D107 → D112 |
| Q48 | Is the full Tech Path tree visible before affordable? | Yes | D108 |

## Already-proposed items confirmed by implication (not directly re-asked)

| Q | Question | Status |
|---|---|---|
| Q21 | Reason to visit a base peacefully? | Partially answered — Workshop rental (D24) covers it; Trophy Hall viewing/crew hangouts still an open enhancement |
| Q27 | Case reveal on a delay? | Still `[PROPOSED — likely yes]`, not directly re-asked this round |
| Q29 | Blueprint duplication at high Mastery? | Still `[PROPOSED — no]`, not directly re-asked this round |
| Q40 | Include an Experiment gamble? | Still `[PROPOSED — yes]`, not directly re-asked this round |
| Q53 | Does Stone stay relevant late-game? | Still `[PROPOSED — yes]`, not directly re-asked this round |
