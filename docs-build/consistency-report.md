# Docs consistency report (2026-09-22)

A read-only check of `docs/` against itself, `docs-build/design-changes.md`,
CLAUDE.md and the code. 3 parallel readers produced 48 findings. The skeptic
stage stalled, so Claude Code did the verification by hand:
all 173 quoted locations were confirmed at the cited lines, each finding was
checked against the decisions it relies on, and 3 duplicates were merged
(#44 into #3, #41 into #16, #38 into #13). **Result: 45 real issues, 0
refuted.**

- **Part A: 38 doc fixes** that follow decisions already made. They
  need Josh's double confirmation (CLAUDE.md), then the same edits in the
  design project.
- **Part B: 5 items that need a decision from Josh.**
- **Part C: 2 build-note fixes** in `docs-build/` (Claude Code's own notes, applied directly).

---

## Part A: doc fixes that follow existing decisions

### #15 Prototype blueprints still described as wearing out, contradicting D77
*contradiction, High*

**Where:**
  - `docs/03-progression.md:325` — "| **Prototype** | Rift bosses, Static Secrets, seasonal | Yes, but 1-per-player | **Wears out — must be relearned**; also resets every 3 wee"
  - `docs/03-progression.md:331` — "**High-tier (Advanced and Prototype) blueprints wear out with repeated use and must eventually be relearned or replaced.**"
  - `docs/03-progression.md:336` — "A veteran Engineer with a worn Prototype blueprint has to go back out and re-earn it"
  - `docs/05-items.md:525` — "**wears out and must be relearned**"
  - `docs/06-economy.md:183` — "Advanced and Prototype blueprints **wear out and must be relearned**"
  - `docs/07-decisions.md:986` — "Prototype blueprints no longer wear out with use (D33); D72's 3-week reset is their only churn."

**Why:** D77 (LOCKED) exempts Prototype from D33 wear-out. 03's Blueprints table cell contradicts itself: it says the item wears out and, in the same cell, that wear-out doesn't apply. 03 § Tiered durability, the 05 Blueprints summary and 06 Interdependence #2 all still say Prototype wears out. The 07 D33 heading also doesn't say it was amended by D77.

**Fix:** 03:325 cell → "**Resets every 3 weeks** (D72) — its only churn; D33 wear-out does not apply (D77)". 03:331-337 → "**Advanced blueprints wear out with repeated use** and must be relearned; Prototype is exempt (D77), its 3-week reset is its only churn", and change the example to "a worn Advanced blueprint". 05:525 → "**resets every 3 weeks; no wear-out (D77)**". 06:182-184 → "Advanced blueprints **wear out and must be relearned**, and Advanced/Prototype reset on the D72 clock". Optionally tag the D33 heading "[LOCKED — Prototype exempted by D77]".

### #36 Escort (and PvP-protected) hits don't knock loot loose, but docs say any player's hit does
*build-drift, High*

**Where:**
  - `docs/02-core-loop.md:269` — "5. **Any player who lands a hit** knocks the loot loose; it returns to"
  - `docs/13-build-guide.md:368` — "- [ ] Any player's hit knocks loot loose back to the owner"
  - `docs/14-claude-code-prompts.md:244` — "offline via raid log), server-wide marker + trail, any player's hit"
  - `docs-build/design-changes.md:185` — "Their hits don't knock the loot loose; defenses treat them"
  - `docs-build/design-changes.md:111` — "PvP-protected players (FTUE rule 3) can neither hit nor be hit by players."
  - `src/server/Services/RaidService.luau:1133` — "attacker ~= raid.raider and attacker ~= raid.escort then"

**Why:** 02 § The Chase point 5 is [LOCKED] and is called 'the key design choice'. The build exempts the raider's escort (and players with PvP protection can't hit at all), and nothing in docs/ says so. The step 7 checklist and prompt repeat the unqualified rule, so a re-test or later step would flag the correct build as a bug, or 'fix' it.

**Fix:** 02 line 269: "5. **Any player who lands a hit** (except the raider's own escort, D101) knocks the loot loose; it returns to". Add one line to § Raid escort: "The escort's own hits never knock the loot loose." 13 line 368: "- [ ] Any player's hit (not the escort's) knocks loot loose back to the owner". Both need Josh's double confirmation, and the change also has to be copied to the design project.

### #1 01-pillars cites a decision section "§ Q9" that doesn't exist in 07-decisions
*broken-ref, Medium*

**Where:**
  - `docs/01-pillars.md:30` — "efficient, not required. (`07-decisions.md § Q9`)"
  - `docs/08-questions.md:72` — "| Q9 | Viable solo paths? | All three pillars | D8 |"
  - `docs/07-decisions.md:100` — "## D8 — All three pillars viable solo `[LOCKED]`"

**Why:** 07-decisions.md has only D-numbered entries. Q9 lives in 08-questions and was answered as D8, so the pointer leads nowhere.

**Fix:** Replace with "(`07-decisions.md § D8`)".

### #2 README glossary defines Level, Marks and Pattern twice, and the old Level/Marks rows still say "proposed"
*contradiction, Medium*

**Where:**
  - `docs/00-README.md:140` — "| **Marks** | Working name (proposed) for the cosmetic-only currency Scrap converts into each season. |"
  - `docs/00-README.md:154` — "| **Marks** | Cosmetic-only currency Research Scrap converts to at season end (D68, D84). Account-bound. |"
  - `docs/00-README.md:143` — "| **Level** | Proposed permanent account level; gates system reveals (e.g. trading). |"
  - `docs/00-README.md:153` — "| **Level** | Permanent account level fed by Reputation; gates trading at Level 10 (D82). |"
  - `docs/00-README.md:136` — "| **Pattern** | Roll (1–1000) on gear/cosmetics, formerly called "Seed" (D93). The CS "paint seed" analog. |"
  - `docs/00-README.md:151` — "| **Pattern** | Formerly "Seed" — the 1–1000 collector roll on gear/cosmetics (D93). |"

**Why:** Each term has two rows. The earlier Marks and Level rows call them proposed, but D84 and D82 locked them, so the glossary contradicts itself. Pattern is a plain duplicate.

**Fix:** Delete lines 140 (Marks, proposed), 143 (Level, proposed) and 151 (the second Pattern row). Keep lines 136, 153 and 154.

### #3 README status still says nothing is built (also covers #44)
*stale, Medium*

**Where:**
  - `docs/00-README.md:6` — "**Status:** Pre-production. Nothing built yet. Vertical slice design locked (v5.5); ready to begin the build (`13-build-guide.md`)."
  - `docs-build/design-changes.md:179` — "## Step 7 design-gap answers (2026-09-22) — NOT yet in `docs/`"

**Why:** The slice is being built: steps 0–7 are logged in design-changes.md, and v5.7–v5.10 are build-phase doc changes. A new session reading the README's status line would think no code exists.

**Fix:** "**Status:** Building the vertical slice (design locked v5.5; build in progress per `13-build-guide.md`; build-time design calls logged in `docs-build/design-changes.md`)."

### #4 D8 still says Mastery tracks, which D81 replaced; nexus still routes "Mastery" to 03
*stale, Medium*

**Where:**
  - `docs/07-decisions.md:107` — "**Implementation:** three Mastery tracks; ranked points weighted across"
  - `docs/07-decisions.md:1034` — "## D81 — Reputation tracks replace Mastery tracks `[LOCKED]`"
  - `docs/12-nexus.md:49` — "| Workshops, Tech Path, Research Bench, Blueprints (full spec), Mastery, Rebirth, ranks/seasons | `03-progression.md` |"

**Why:** D8 is `[LOCKED]` with no amendment note, but D81 replaced its implementation (Mastery tracks) with Reputation tracks. The nexus ownership row says "Mastery" and doesn't list Reputation tracks or Level, both of which 03 now owns (§ Reputation tracks, § Level).

**Fix:** D8: "**Implementation:** three Reputation tracks (Miner/Trader/Raider — D81, which replaced the original Mastery tracks); ranked points weighted across all three." Nexus row: "Workshops, Tech Path, Research Bench, Blueprints (full spec), Blueprint Mastery, Reputation tracks, Level, Rebirth, ranks/seasons".

### #5 D66 still lists the gear-score formula and sharding metric as open; D56 header doesn't flag D79
*stale, Medium*

**Where:**
  - `docs/07-decisions.md:856` — "**Open:** the gear score formula. **Consistency note `[PROPOSED]`:**"
  - `docs/07-decisions.md:857` — "neighborhood sharding (D56) is keyed on vault tier — it should likely use"
  - `docs/07-decisions.md:749` — "## D56 — The Homestead is sharded into vault-tier-matched neighborhoods `[LOCKED]`"
  - `docs/07-decisions.md:1006` — "## D79 — Homestead sharding keyed to the D66 band, not raw vault tier `[LOCKED]`"
  - `docs/02-core-loop.md:113` — "## Server sharding `[LOCKED — D56, metric switched to D66 by D79]`"

**Why:** D92 locked the gear-score formula and D79 switched sharding to the D66 band. D66 still says both are open and "Not changed without confirmation", and D56's header still says vault-tier-matched. 02 already reflects D79, so the log disagrees with the body text that cites it.

**Fix:** D66: replace lines 856–859 with "**Resolved:** gear score formula — D92; sharding uses this same band — D79." D56 header: "`[LOCKED — metric switched to the D66 band by D79]`".

### #6 D33 and D35 still state their original rules, which later decisions overturned, with no pointer to the change
*stale, Medium*

**Where:**
  - `docs/07-decisions.md:424` — "## D33 — Blueprint durability is tiered by rarity, inverted from the naive default `[LOCKED]`"
  - `docs/07-decisions.md:425` — "**Decision:** **Common blueprints are permanent once learned.** **Advanced"
  - `docs/07-decisions.md:986` — "**Decision:** Prototype blueprints no longer wear out with use (D33);"
  - `docs/07-decisions.md:456` — "## D35 — Learning a rare blueprint announces publicly `[LOCKED]`"
  - `docs/07-decisions.md:998` — "fires for Prototype only. Advanced no longer announces."

**Why:** D33 says Prototype blueprints wear out, and D35 says Advanced learns announce. D77 and D78 reversed both. Other amended entries (D2, D5, D15, D48) carry an "amended by" tag in the header, but these two show only `[LOCKED]`, so a reader of D33 or D35 alone gets the old rule.

**Fix:** D33 header: "`[LOCKED — Prototype exempted from wear-out by D77]`". D35 header: "`[LOCKED — narrowed to Prototype only by D78]`".

### #12 Band metric compares raw gear score with vault tier; the build converts gear score to tier units first
*build-drift, Medium*

**Where:**
  - `docs/02-core-loop.md:218` — "- Target must be within the raider's matchmaking band — the **highest of"
  - `docs/02-core-loop.md:219` — "current vault tier, lifetime peak vault tier, or gear score** (R6,"
  - `docs/07-decisions.md:844` — "**Decision:** matchmaking uses the highest of current vault tier,"
  - `docs-build/design-changes.md:72` — "1. **Band metric scales (D66 / D79 / D92):** gear score is converted to tier"
  - `src/server/Util/BandMetric.luau:52` — "local gearTiers = math.floor(BandMetric.gearScore(inputs.Gear, inputs.Armor) / Config.Sharding.GearScorePerBandTier)"

**Why:** D92 puts gear score on a ×10 scale (Wooden pickaxe = 10), while vault tier runs 1–10. Read literally, the locked rule in D66, R6 and 02 compares the raw numbers, so gear score always wins. The build (Josh's step-4 call) divides by 10 first. Anyone re-implementing matchmaking or sharding from the docs would get it wrong.

**Fix:** Add to D66 and 02 § Preconditions: "Gear score is converted to tier units, floor(gear score / 10) [PH], before taking the highest." Same scale note in 01 R6. Josh already made the call; the docs edit needs his double confirmation.

### #16 Voltstone trickle says Grade is per node; the build rolls Grade per hit (also covers #41)
*build-drift, Medium*

**Where:**
  - `docs/05-items.md:103` — "**Stacks with Grade:** a Volatile-grade Ore node paying 10× is a"
  - `docs/05-items.md:152` — "- Every tap is a lottery ticket"
  - `docs-build/design-changes.md:38` — "**Grade is rolled per hit**, not per node"

**Why:** Josh decided in step 2 that Grade is rolled per hit, and the build does this. The Voltstone line still describes a whole node having a Grade, which also contradicts "every tap is a lottery ticket" in the same file. design-changes.md already suggests the replacement wording.

**Fix:** 05:103 → "**Stacks with Grade:** a Volatile-grade Ore hit paying 10× is a"

### #17 Condition/Pattern rolls still said to apply to gear, which D111 made a per-player tier
*contradiction, Medium*

**Where:**
  - `docs/05-items.md:179` — "## Roll 2 — CONDITION (gear & cosmetics) — *the float analog*"
  - `docs/05-items.md:188` — "## Roll 3 — SEED (gear & cosmetics) — *the pattern analog*"
  - `docs/05-items.md:316` — "The 1–1000 collector roll on gear"
  - `docs/05-items.md:15` — "| **Gear / Pickaxes** | No — a per-player tier, not an item |"
  - `docs/05-items.md:16` — "| **Armor** | No — tier fixed when crafted |"

**Why:** The Taxonomy says gear and armor are not rolled (D111: the pickaxe is a tier, not an item), and § Loss rules says only pickaxe skins roll Condition + Pattern. The Roll 2/Roll 3 headings and the Pattern definition still say gear rolls, so a builder could attach Condition/Pattern to pickaxes or armor. (07 D93 repeats "on gear and cosmetics".)

**Fix:** Change "(gear & cosmetics)" to "(cosmetics, incl. pickaxe/armor skins)" at 05:179 and 05:188. At 05:316 change "on gear and cosmetics" to "on cosmetics (including pickaxe and armor skins)".

### #18 05 § Loss rules says gear is never stolen, but spare armor (in § Gear) is stealable
*contradiction, Medium*

**Where:**
  - `docs/05-items.md:305` — "- **Gear is never stolen or traded** (R1, D111); see the Taxonomy table above"
  - `docs/05-items.md:290` — "**worn piece is never stealable** (R1); **spare pieces are stealable** in"
  - `docs/01-pillars.md:61` — "- **Never lootable:** cosmetics, base structures, equipped gear"

**Why:** Armor is a subsection of § GEAR, and D112 makes spare pieces stealable. R1 protects only *equipped* gear. The Loss rules bullet makes the blanket claim "gear is never stolen" and doesn't mention armor, so it contradicts D112 in the same section.

**Fix:** 05:305 → "- **Pickaxes are never stolen or traded** (R1, D111). **Armor:** the worn piece is never stolen; spare pieces are stealable; armor never trades (D112). See the Taxonomy table above"

### #19 05 says pickaxe skins are out of the slice; D111, 04 and the build put them in it
*contradiction, Medium*

**Where:**
  - `docs/05-items.md:306` — "- Pickaxe **skins** roll Condition + Pattern for looks only (cosmetics;"
  - `docs/05-items.md:307` — "out of the vertical slice)"
  - `docs/07-decisions.md:1389` — "In the slice, skins trade through the direct trade window only (no global Exchange) and carry no Condition/Pattern"
  - `docs/04-world-content.md:15` — "**Captain pickaxe skin** (the Captain's Signature drop, name [PH])"
  - `docs/10-roadmap.md:46` — "| **Scavs + Scav Captain** | Teaches combat and defense safely |"

**Why:** Pickaxe skins are in the slice: D111 gives their slice trading rule, the Scav Captain (in the slice) drops one (v5.8), and the skin system is built. 05 either says skins roll Condition + Pattern (the slice has no rolls) or that skins are out of the slice. Either reading contradicts D111. The 10 slice table also has no row for the minimal skin system.

**Fix:** 05:306-307 → "- Pickaxe **skins** are cosmetics. In the slice they exist (the Scav Captain's Signature drop) but carry no Condition/Pattern roll and trade via the direct trade window only (D111); rolls arrive with v1.0". Optionally add to the 10 in-scope table: "| **Minimal pickaxe skins** (D111, v5.8) | The Scav Captain's Signature drop; no rolls, direct trade only |".

### #20 Slice table says "NPC flat-price selling", but D94 and Build Order step 9 add price decay
*contradiction, Medium*

**Where:**
  - `docs/10-roadmap.md:47` — "| **NPC flat-price selling** | Economy without full market infrastructure |"
  - `docs/10-roadmap.md:268` — "9. **NPC selling (with price decay, D94) + direct trade + Level/Reputation"
  - `docs/06-economy.md:46` — "The formerly flat NPC buy price was an **unlimited Credits faucet**"

**Why:** D94 (LOCKED) replaced the flat NPC price with a per-sale daily decay, and the same file's build order uses it. The slice scope table, which CLAUDE.md names as the scope wall, still says flat-price. That could mislead build step 9.

**Fix:** 10:47 → "| **NPC selling** (price diminishes per sale, resets daily — D94) | Economy without full market infrastructure |"

### #21 03 ties the Advanced-announcement cut to Tier 3's 3-week reset; Advanced is Tier 2 (6 weeks)
*contradiction, Medium*

**Where:**
  - `docs/03-progression.md:353` — "longer announces (D78)** — with Tier 3 resetting every 3 weeks (D72),"
  - `docs/03-progression.md:192` — "(Common ↔ T1, Advanced ↔ T2, Prototype ↔ T3)"
  - `docs/07-decisions.md:1000` — "**Why:** with Tier 2/Advanced now resetting every 6 weeks (D72), keeping"

**Why:** Advanced blueprints follow the Tier 2 clock (6 weeks), per 03's own mapping and D78's rationale. The text gives the wrong reason for D78.

**Fix:** 03:353 → "longer announces (D78)** — with Tier 2/Advanced resetting every 6 weeks (D72),"

### #22 Blueprint Mastery example makes a crafter's pickaxes the product, which D111 removed
*stale, Medium*

**Where:**
  - `docs/03-progression.md:417` — "guy who makes the good Voltsteel picks," and that identity is worth more"
  - `docs/05-items.md:302` — "A crafter's product is now the look, not the tool."

**Why:** Under D111 pickaxes are a per-player tier: they can't be traded or sold and aren't crafted items that carry a maker's mark. The Signature example still describes the D21-era market in crafted pickaxes.

**Fix:** 03:417 → "guy who makes the good Riftedge skins," and that identity is worth more"

### #39 13 build guide says docs/ are read-only and copied in from the design project; CLAUDE.md and the actual workflow edit docs/ in the repo
*contradiction, Medium*

**Where:**
  - `docs/13-build-guide.md:201` — "docs/                     (design files — read-only for Claude Code)"
  - `docs/13-build-guide.md:185` — "Bring the
question back to this Claude.ai project, decide it, update the docs, and
copy the updated file into `docs/`."
  - `CLAUDE.md:9` — "**Edit `docs/` only with double confirmation from Josh**"
  - `docs-build/design-changes.md:4` — "**The separate design project still has the old text**: make
the same changes there before the next copy-in, or it will overwrite them."

**Why:** Since v5.7, docs/ has been edited in the repo first (D111–D114, v5.8–v5.10), and the design project lags behind (it is still missing D110–D112). Following 13's 'copy the updated file into docs/' literally would overwrite those repo-only edits. This already caused the D110/D111 number collision.

**Fix:** 13 line 201: "(design files — Claude Code edits only with Josh's double confirmation, see CLAUDE.md)". 13 lines 185–186: "...decide it, then either have Claude Code make the same edit (double confirmation) or copy the file in, but only after the design project has every repo-side change logged in docs-build/design-changes.md."

### #7 Decision entries still carry "Open", "[PROPOSED]" or "Still undesigned" notes that later decisions resolved
*stale, Low*

**Where:**
  - `docs/07-decisions.md:652` — "**Still undesigned:** exact deposit/withdraw permission tiers and the"
  - `docs/07-decisions.md:869` — "**Open:** whether the 30-minute post-offline-raid shield is also exempt."
  - `docs/07-decisions.md:873` — "into a cosmetic-only currency (working name **Marks** `[PROPOSED]`,"
  - `docs/07-decisions.md:918` — "**Guardrails `[PROPOSED]`:** band + 48-hour shield apply; per-target"
  - `docs/07-decisions.md:934` — "the Tier 3 reset. **Proposed mitigation:** Tier 3 re-buys cost a Rift"
  - `docs/07-decisions.md:951` — "sink — partly restored by the proposed rare-seed vendor."
  - `docs/07-decisions.md:955` — "Names/colors and "Mythic is earned-only" are `[PROPOSED]`."

**Why:** Each of these was later locked: D49 by D90/D91, D67 by D75, D68 by D84, D71 by D88, D72 by D76, D73 by D95 and D74 by D85. The leftover "open" and "proposed" wording reads as if they're still undecided.

**Fix:** Add "(resolved by D##)" after each, e.g. D67: "**Open:** … — **resolved: yes, D75.**"; D49: "**Resolved by D90 (permissions) and D91 (disband split).**"; D68: "`[PROPOSED]` → locked by D84"; D71: "locked by D88"; D72: "locked by D76"; D73: "locked by D95"; D74: "locked by D85".

### #8 Nexus ownership index still calls the third rarity roll "Seed"
*stale, Low*

**Where:**
  - `docs/12-nexus.md:51` — "| Item taxonomy, Resources, the three rarity rolls (Grade/Condition/Seed), Gear, Cosmetics, Cases, Keys, Components, Fragments | `05-items.m"
  - `docs/12-nexus.md:179` — ""Seed" for the CS comparison — any new text should say "Pattern.""

**Why:** D93 renamed the roll to Pattern, and the nexus's own drift list says to use "Pattern", but the ownership index still says Seed. The index also doesn't mention Armor (D112), which 05 now owns.

**Fix:** "Item taxonomy, Resources, the three rarity rolls (Grade/Condition/Pattern), Gear (pickaxe + armor), Cosmetics, Cases, Keys, Components, Fragments".

### #9 README glossary: gear score leaves out armor and sharding; Condition and Pattern still said to roll on gear
*stale, Low*

**Where:**
  - `docs/00-README.md:155` — "| **Gear score** | Pickaxe tier + upgrade-node count; used only for raid matchmaking band (D66, D92). |"
  - `docs/07-decisions.md:1153` — "the highest armor tier owned × 10** [PH] (D112)"
  - `docs/00-README.md:135` — "| **Condition** | Cosmetic wear roll on gear/cosmetics (0.00–1.00). The CS "float" analog. |"
  - `docs/05-items.md:15` — "| **Gear / Pickaxes** | No — a per-player tier, not an item | **No — D111** |"

**Why:** D112 added armor to gear score, and 05 § Gear score says it also keys Homestead sharding (D79). Since D111, the pickaxe is a tier, not an item: 05 says gear isn't rolled, and only pickaxe skins, which are cosmetics, roll Condition and Pattern.

**Fix:** Gear score: "Pickaxe tier + upgrade-node count + highest armor tier owned; used only for the raid matchmaking band and Homestead sharding (D66, D79, D92, D112)." Condition and Pattern: replace "on gear/cosmetics" with "on cosmetics (incl. pickaxe skins)".

### #10 Nexus still describes a set of 11 files and its reading order omits 11/13/14, which the README lists
*stale, Low*

**Where:**
  - `docs/12-nexus.md:4` — "no mechanics, no numbers. Its only job is to keep the other 11 files"
  - `docs/12-nexus.md:139` — "short, and together they replace needing to read all 11 files for a"
  - `docs/00-README.md:46` — "- `13-build-guide.md` + `14-claude-code-prompts.md` — the build phase: how to turn the slice into a playable alpha"
  - `docs/00-README.md:26` — "Mirrors `12-nexus.md § Reading Order`, which is canonical. If the two"

**Why:** The set is now 00–14: 14 files besides the nexus, including 13 and 14 (added in nexus v1.5). The README's reading order is supposed to mirror the canonical nexus list, but it adds 11/13/14 as references and the nexus reading order doesn't.

**Fix:** Line 4: "keep the other files honest". Line 139: "replace needing to read the whole set". Nexus § Reading Order "Reference as needed": add "`11-claude-usage-guide.md` (process) and `13-build-guide.md` + `14-claude-code-prompts.md` (build phase)."

### #11 Nexus dependency graph's Chase row doesn't point to D114 and still cites superseded D5
*stale, Low*

**Where:**
  - `docs/12-nexus.md:73` — "| Raid theft percentages, timing, or the Chase | `06-economy` (sinks table), `07-decisions` D1/D3/D4/D5, `09-research` (Rust warning it's mo"
  - `docs/07-decisions.md:1452` — "## D114 — Chase escape is a radius around the victim's plot `[LOCKED — radius PH]`"

**Why:** D114 now defines how the Chase ends, and its radius depends on the slice layout (D113). Someone editing the Chase from this row wouldn't be sent to D114. D5 is superseded at elite tiers by D23.

**Fix:** "`06-economy` (sinks table), `07-decisions` D1/D3/D4/D23/D114, `02 § Slice layout` (escape radius vs. plot/bridge sizes), `09-research` (Rust warning it's modeled against)".

### #14 Escape rule in 02 doesn't state the build's grounded-only condition
*build-drift, Low*

**Where:**
  - `docs/02-core-loop.md:278` — "The Chase ends in escape when the carrier leaves the escape radius"
  - `docs-build/design-changes.md:232` — "- **Escape needs solid ground:** the radius only counts while the carrier is"
  - `src/server/Services/RaidService.luau:435` — "return horizontal > raidCfg.EscapeRadiusStuds and humanoid.FloorMaterial ~= Enum.Material.Air"

**Why:** D114's fall-exploit fix depends on escape counting only while the carrier is on the ground. The locked doc text says crossing the radius ends the Chase. Someone re-implementing or testing from 02 would bring the mid-fall escape exploit back.

**Fix:** 02 § Escape and carrier death: "The Chase ends in escape when the carrier is outside the escape radius while standing on solid ground (not mid-jump or falling)."

### #23 03 Seasons points to a Rift Fragment "proposal" under the wrong section
*stale, Low*

**Where:**
  - `docs/03-progression.md:528` — "conversion — see `§ Staggered tier reset` for the Rift Fragment re-buy"
  - `docs/03-progression.md:529` — "proposal that keeps that reset meaningful."
  - `docs/03-progression.md:200` — "## Tier 3 re-buy cost `[LOCKED — D76]`"

**Why:** The re-buy cost is LOCKED (D76), not a proposal, and it lives in its own § Tier 3 re-buy cost, not § Staggered tier reset.

**Fix:** 03:528-529 → "conversion — see `§ Tier 3 re-buy cost` (D76) for the Rift Fragment re-buy that keeps that reset meaningful."

### #24 "Seed" still used for the Pattern roll in 03 and 05 (D93)
*stale, Low*

**Where:**
  - `docs/03-progression.md:365` — "- **Unstable Finish cosmetics** (the seed-sensitive ones — the entire"
  - `docs/03-progression.md:542` — "(feeding the seed meta), a rotating world event, an exclusive rank"
  - `docs/05-items.md:193` — "### The critical rule — only some skins are seed-sensitive"
  - `docs/05-items.md:218` — "number of finishes beats a diluted one where no single seed becomes"
  - `docs/05-items.md:236` — "**Decision (D63):** prototype the pre-baked seed-variant model in Studio"
  - `docs/05-items.md:253` — "matters. The practical build is: bucket the 1,000 seed values into a"

**Why:** D93 renamed the roll to Pattern, and 05:320 says every other reference "should read 'Pattern' going forward". These lines describe our own system, not CS, and keep the word "seed" that D93 reserved for crops. (The heading "Roll 3 — SEED" is kept on purpose as a link name, per 05:317.)

**Fix:** Replace with Pattern: 03:365 "Pattern-sensitive", 03:542 "feeding the Pattern meta", 05:193 "only some skins are Pattern-sensitive", 05:218-219 "no single Pattern becomes legendary. Of the ~1,000 Patterns on each finish", 05:222 "which Patterns", 05:236 "pre-baked Pattern-variant model", 05:253 "the 1,000 Pattern values". Also 05:205-207 ("float and seed" / "dull seed" / "legendary seed") → Condition/Pattern.

### #25 09/10 use "Seed" for our system outside the CS section; 09 cites a non-existent § Seed
*stale, Low*

**Where:**
  - `docs/09-research.md:310` — "base, active Grade particle effects, and any procedural Seed cosmetics —"
  - `docs/09-research.md:322` — "# NO CUSTOM SHADERS — confirmed, with a sharper caveat for the Seed system `[UPDATED]`"
  - `docs/09-research.md:327` — ""reliable fallback" recommendation in `05-items.md § Seed`."
  - `docs/09-research.md:335` — "**Consequence for the Seed implementation:** hue/tint-driven seed"
  - `docs/09-research.md:353` — "performance, for the ambitious Seed implementation (`05-items.md`)"
  - `docs/09-research.md:68` — "| Economy depth, Tech Path, seeds |"
  - `docs/10-roadmap.md:164` — "Persistent plots + visible bases + Grade particles + procedural seeds is"
  - `docs/10-roadmap.md:224` — "pre-baked texture variants selected by seed bucket, with tint layered on"

**Why:** 12-nexus allows "Seed" in 09 only for the CS comparison (§ CS2, which has its own terminology note). These lines are about our roll. 05 has no "§ Seed" section (it is "§ Roll 3" / "§ Roll feasibility").

**Fix:** Replace "Seed"/"seed" with "Pattern" at 09:68, 310, 322, 335-342, 353-355 and 10:164, 224. Change the 09:327 ref to `05-items.md § Roblox feasibility`.

### #26 "D111 round" labels the Level curve, but D111 is the pickaxe decision
*broken-ref, Low*

**Where:**
  - `docs/03-progression.md:495` — "**Level curve `[PH — placeholder, D111 round]`:**"
  - `docs/07-decisions.md:1382` — "## D111 — Pickaxes are not tradeable; pickaxe skins are `[LOCKED]`"

**Why:** The Level curve has nothing to do with D111. "D111 round" means the v5.7 build round, but a reader following the D# lands on the pickaxe decision. (07 uses the same label in the D80 build note and in D92.)

**Fix:** 03:495 → "**Level curve `[PH — placeholder, v5.7 build round; D80 note]`:**"

### #27 08 status line gives the decided-directly range as D65–D110; the log runs to D114
*stale, Low*

**Where:**
  - `docs/08-questions.md:9` — "in v5.5 — see D107, D108. Rule-leak fixes and follow-ups → D65–D110"
  - `docs/12-nexus.md:131` — "| **D (locked decisions)** | `07-decisions.md` | D1–D114 | **D115** |"

**Why:** D111–D114 were decided directly (D111 also answers Q17 on the same page). The range is stale.

**Fix:** 08:9 → "Rule-leak fixes, follow-ups and build-phase calls → D65–D114"

### #28 08 Answered table doesn't show later amendments to Q28, Q32 and Q23
*stale, Low*

**Where:**
  - `docs/08-questions.md:98` — "| Q28 | Blueprints permanent or consumable? | Tiered: low-tier permanent, high-tier wears out | D33 |"
  - `docs/08-questions.md:101` — "| Q32 | Does learning a blueprint announce publicly? | Yes | D35 |"
  - `docs/08-questions.md:139` — "| Q23 | Vertical slice scope — final line? | Locked as listed in `10-roadmap`, plus raid escort and a minimal Level gate; Workshop II/Fragme"

**Why:** Other rows note amendments (Q14 "amended by D68, D72", Q17 "was Yes, D21"). These three don't. D77 exempts Prototype from wear-out, D78 limits announcements to Prototype, and D112 added armor to the "final" D107 slice.

**Fix:** Q28 → "Tiered: Common permanent, Advanced wears out (Prototype exempt — D77) | D33 → D77". Q32 → "Yes — Prototype only (narrowed) | D35 → D78". Q23 → "... Workshop II/Fragments stay out; armor added later | D53 → D107 → D112".

### #29 Q13 (first Robux prompt) cites D15, which is about Cases/Keys
*broken-ref, Low*

**Where:**
  - `docs/08-questions.md:76` — "| Q13 | First Robux prompt? | At global trading unlock | D15, `06-economy.md` |"
  - `docs/07-decisions.md:186` — "## D15 — Option A on Cases and Keys"

**Why:** D15 says nothing about when the first Robux prompt fires. The rule lives in 06 § First Robux prompt, and D82 ties it to the Level-10 gate.

**Fix:** 08:76 See column → "`06-economy.md § First Robux prompt`, D82"

### #31 09 says 01-pillars names an under-9 segment; 01 says under 13
*broken-ref, Low*

**Where:**
  - `docs/09-research.md:180` — "target audience, particularly the under-9 segment `01-pillars.md`"
  - `docs/01-pillars.md:36` — "Assume a meaningful share under 13."

**Why:** The cited file doesn't say what 09 attributes to it.

**Fix:** 09:180-181 → "target audience, particularly under-9 players within the under-13 share `01-pillars.md` names."

### #32 Section references to headings that don't exist (§ D33, § D52, § D24, § Specialization)
*broken-ref, Low*

**Where:**
  - `docs/06-economy.md:184` — "(`03-progression.md § D33`)"
  - `docs/04-world-content.md:73` — "`03-progression.md § D52`"
  - `docs/09-research.md:175` — "(`03-progression.md § D24`)"
  - `docs/03-progression.md:96` — "a menu. That is cut (`07-decisions.md § Specialization`). Instead:"

**Why:** The § names don't match any heading. The targets are 03 § Tiered durability, § Blueprint drops are visible before pickup, § Workshop access as a service, and 07 § D11.

**Fix:** 06:184 → `03-progression.md § Tiered durability`. 04:73 → `03-progression.md § Blueprint drops are visible before pickup`. 09:175 → `03-progression.md § Workshop access as a service`. 03:96 → `07-decisions.md § D11`.

### #33 06 lists five interdependence mechanisms, then says "the remaining four"
*contradiction, Low*

**Where:**
  - `docs/06-economy.md:174` — "themselves. Five mechanisms enforce that:"
  - `docs/06-economy.md:203` — "remaining four mechanisms above still keep genuine scarcity in the"

**Why:** Five mechanisms are listed and none is removed by the Fragments paragraph, so "remaining four" is wrong.

**Fix:** 06:203 → "five mechanisms above still keep genuine scarcity in the"

### #34 10 Next actions and 11 still describe the pre-build state
*stale, Low*

**Where:**
  - `docs/10-roadmap.md:310` — "1. **Start the build** — `§ Build Order`, step 0, in Claude Code"
  - `docs/10-roadmap.md:311` — "2. Rescore v5.5 against the rubric (`01-pillars.md § Design rubric`) —"
  - `docs/11-claude-usage-guide.md:8` — "This is a **prediction**, not a rulebook. Vault Raiderz is pre-production"
  - `docs/11-claude-usage-guide.md:10` — "documented in `13-build-guide.md`, but nothing is built yet."
  - `docs/11-claude-usage-guide.md:38` — "(Q44 tech path wipe, Q49 Riftsalt tradeable, Q38 scrap banking)"

**Why:** The docs are at v5.10 and build steps 0–6 are committed (7 is in progress), but 10 says to start step 0 and rescore v5.5. 11 says v5.5, "nothing is built yet", and Phase 0 is "where we are now". 11's example open questions (Q44, Q49, Q38, and Q26 at line 37) were all answered long ago.

**Fix:** 10 Next actions: replace item 1 with "Continue the build from the current step (see docs-build/)" and make item 2 "Rescore the current version (v5.10)". 11:8-10: "Vault Raiderz is in the vertical-slice build (docs v5.10)" and change the Phase 0 heading to "(done)". Replace the Q examples at 11:37-38 with the open Q33/Q34 or generic wording.

### #42 Step 3 checklist and Prompt 3 still describe automatic banking with 'overflow' to Exposed
*stale, Low*

**Where:**
  - `docs/13-build-guide.md:332` — "- [ ] Overflow goes to Exposed; Prismatic/Vaultborn auto-bank if room"
  - `docs/14-claude-code-prompts.md:174` — "Build VaultService: Vault Core capacity, overflow to Exposed, the"
  - `docs/02-core-loop.md:181` — "Mined resources land in **Exposed**. The player banks them by using their"

**Why:** 02 § Bank vs Exposed was updated on 2026-09-21: everything mined lands in Exposed and banking is manual, best-first. 'Overflow goes to Exposed' implies resources auto-bank until the cap, which is the old model.

**Fix:** 13 line 332: "- [ ] Mined resources land in Exposed; using the Vault Core banks best-first up to the cap; Prismatic/Vaultborn auto-bank if room". 14 line 174: "Build VaultService: Vault Core capacity, manual best-first banking from Exposed, the"

### #43 Build docs say Level is stored in the profile; D80 build note says it is derived, not stored
*stale, Low*

**Where:**
  - `docs/13-build-guide.md:230` — "blueprints, crew membership, Level/Reputation all live in the profile."
  - `docs/14-claude-code-prompts.md:133` — "Reputation tracks + Level, lifetime peak vault tier, shields,"
  - `docs/07-decisions.md:1023` — "**Build note (D111 round):** Level is not stored — it is"

**Why:** A future step (step 9, ReputationService) could add a stored Level field, which is exactly the drift the D80 note rules out.

**Fix:** 13 line 230: "...crew membership, Reputation XP (Level is derived from it, D80) all live in the profile." 14 line 133: "Reputation track XP (Level derived, not stored), lifetime peak vault tier, shields,"

### #45 Prompt 7 calls it a '90s escape window'; the build and 02 § Defenses treat 90 s as the whole raid from breach
*stale, Low*

**Where:**
  - `docs/14-claude-code-prompts.md:241` — "grab from Exposed only, 90s escape
  window."
  - `docs/02-core-loop.md:333` — "| Decoy Vault | Wastes ~20s [PH] of the 90s window |"
  - `docs-build/design-changes.md:210` — "the 90 s window
   starts at breach"

**Why:** 'Escape window' reads as a timer that starts at the grab. The build, and the Decoy row, start it at breach, so the lockpick eats into it. A rerun or review of step 7 could 'fix' the timer to start at the grab.

**Fix:** 14 lines 241–242: "grab from Exposed only, a 90s raid window from breach (the Decoy wastes part of it)."

### #47 Prompt 2 still describes the pre-D113 island layout
*stale, Low*

**Where:**
  - `docs/14-claude-code-prompts.md:158` — "- A greybox Homestead island and a small Reaches island (placeholder"
  - `docs/02-core-loop.md:93` — ""Main Street": the slice Homestead is a straight street with plots in"

**Why:** The world is now the D113 Main Street layout, generated by docs-build/worldgen/gen_world.py. Anyone re-running or reviewing step 2 from the prompt would rebuild or expect a generic island.

**Fix:** 14 line 158: "- The greybox Homestead (the Main Street layout, 02 § Slice layout, D113) and a small Reaches island (placeholder"

---

## Part B: decisions needed

### #13 Build allows one offline raid per absence; docs imply a 30-min shield, then raidable again (also covers #38)
*build-drift, Medium*

**Where:**
  - `docs/02-core-loop.md:241` — "| Offline raid | **8% [PH]** | 30-min shield triggers after |"
  - `docs/07-decisions.md:13` — "**Decision:** offline raids permitted, 8% [PH] of Exposed, 30-min shield after."
  - `docs-build/design-changes.md:215` — "an offline base can be raided **at most once per absence**:"
  - `src/shared/Config.luau:1005` — "-- After an offline raid the victim is "theft pending" until their"

**Why:** The docs say an offline victim is shielded for 30 minutes after a raid, which implies they can be raided again during the same absence. The code blocks any further offline theft until the victim logs in (up to 7 days), so D1/D75's 30-minute offline shield never takes effect for offline victims. design-changes.md marks this "needs your OK / design project", and it is already built.

**Fix:** If Josh approves: in 02 § Theft math and D1, change "30-min shield triggers after" to "no further offline raid until the owner's next login; 30-min shield [PH] after that" (or state how the two interact). Otherwise change the code.

### #37 Spare armor is never stolen in raids, despite LOCKED D112 'spare pieces are stealable'
*build-drift, High*

**Where:**
  - `docs/07-decisions.md:1408` — "**worn piece is never stealable** (R1); **spare pieces are stealable** in"
  - `docs/05-items.md:16` — "**Spare pieces: yes · worn piece: no (R1)**"
  - `src/server/Services/RaidService.luau:903` — "local loot: Loot = { Resources = {}, Scrap = math.floor(scrap * share) }"
  - `src/server/Services/ArmorService.luau:9` — "It is never stealable (R1); spares are (step 7)."
  - `docs-build/estimate.md:383` — "spare-armor theft
in step 7"
  - `docs/13-build-guide.md:366` — "- [ ] Online raid: breach → lockpick → grab Exposed → escape in the window"

**Why:** D112 is LOCKED and gives the step-7 theft math the job of deciding how many spares a raid takes. Step 7 is marked done, but raid loot is only Resources + Scrap. Spare armor can already exist (Studio grants, and Iron armor was the Captain stand-in drop), so the 'loss stake' D112 adds never happens. No backlog entry records this as deferred.

**Fix:** Implement it, or log it as deferred in docs-build/backlog.md. Add a step 7 checklist line in 13: "- [ ] Spare (unworn) armor pieces can be grabbed; the worn piece never is (D112, R1)". Josh needs to set the rule: how many spares one grab takes, whether they count toward CapByTier, and whether the ~20% in-transit destruction applies to them.

### #40 Lockpicks and gadgets 'crafted at Workshop I' vs Tech Path Breaching branch that 'buys' lockpick tools and gadgets; step 10 checklist has no crafting
*build-drift, Medium*

**Where:**
  - `docs-build/design-changes.md:202` — "**Lockpicks are items** crafted from Ore at Workshop I (step 10)."
  - `docs-build/design-changes.md:103` — "**Iron pickaxe, armor and gadgets are crafted at Workshop I** (step 10);"
  - `docs/03-progression.md:148` — "| **Breaching** | Breach charges, lockpick tools, gadgets, carry-speed gear | Raiders |"
  - `docs/13-build-guide.md:400` — "- [ ] Workshop I placeable; opens the Tier 1 tree (vertical mobile UI — D60)"

**Why:** The build makes lockpicks, gadgets, the Iron pickaxe and armor plain Workshop I crafts from resources. 03 § Branches (LOCKED, D108) puts lockpick tools and gadgets behind Tech Path Breaching nodes, and the example tree prices 'Smoke bomb' at 140 scrap. Step 10 has to pick one of these, and 13 Step 10 / Prompt 10 never mention crafting these items at all.

**Fix:** Josh decides whether the basic lockpick and gadgets are ungated Workshop I recipes, with Breaching nodes unlocking better versions, or are gated by Breaching. Then add a step 10 checklist line in 13: "- [ ] Workshop I crafts Iron pickaxe, chest armor, gadgets and lockpicks (costs [PH])".

### #35 Skin-hides-tier build call conflicts with "infer build/value from worn gear"
*build-drift, Low*

**Where:**
  - `docs-build/design-changes.md:166` — "**An equipped skin replaces the whole pickaxe look;** the tier isn't shown"
  - `docs/03-progression.md:103` — "- **Readable** — others infer your build from gear and behavior"
  - `docs/05-items.md:420` — "gear worn by the base's owner, and defense investment. This keeps"

**Why:** Josh decided (NOT yet in docs/) that a skin hides pickaxe tier to keep it a private power stat. 03 and 05 § D32 still rely on other players reading power or value from the gear someone wears. Worn armor stays visible, so the conflict is partial, but the docs should say which signal survives.

**Fix:** Either add "(armor and behavior; pickaxe tier is hidden under skins)" to 03:103 and 05:420, or reconsider the build call. Needs Josh's call on whether hidden pickaxe tier is intended to weaken gear-based scouting.

### #30 Q42 is missing from 08, though the status line counts it as answered
*broken-ref, Low*

**Where:**
  - `docs/08-questions.md:6` — "**Status:** Q1–Q13 answered in v4 · Q14–Q58 answered in v5,"

**Why:** Every Q from Q1 to Q70 appears somewhere in 08 except Q42 (no hit anywhere in docs/). Q-numbers are "permanent and never reused", so a retired or cut Q42 should still be recorded.

**Fix:** Add a row for Q42 with its question and answer, or a "Q42 — retired/merged into …" line.

---

## Part C: build notes (applied)

### #46 Tier 5–7 sabotage built for defenses only; Workshop target from D23 has no follow-up
*build-drift, Low*

**Where:**
  - `docs/02-core-loop.md:377` — "| 5–7 | Steal + knock one defense or Workshop **offline** 15 min [PH], free repair |"
  - `docs/14-claude-code-prompts.md:251` — "- Tiers 5–7: knock a defense or Workshop offline 15 min [PH]."
  - `docs-build/design-changes.md:211` — "tiers 5–7
   sabotage = one defense offline 15 min"

**Why:** This is reasonable for now, because Workshop I only arrives in step 10. But neither the backlog nor 13 Step 10 / Prompt 10 says to add the Workshop as a sabotage target, so LOCKED D23 will stay half-built.

**Fix:** Add to docs-build/backlog.md under Step 10: "Workshop I becomes a tier 5–7 sabotage target (D23; RaidService.sabotage)". Optionally add a matching line to the 13 Step 10 checklist.

### #48 design-changes.md has stale entries: Captain stand-in and an 'answered' section still saying 'Not decided yet'
*stale, Low*

**Where:**
  - `docs-build/design-changes.md:128` — "Rare = 40 Research Scrap, Signature =
   Iron chest armor."
  - `docs-build/design-changes.md:152` — "Needs a minimal
   skin system; Iron armor stays the stand-in until then."
  - `src/server/Services/ScavWaveService.luau:125` — "-- Signature (~5-8%): the Captain pickaxe skin (v5.8)."
  - `docs-build/design-changes.md:251` — "Not decided yet. Take these to the design project; the build keeps the
current behavior until then."

**Why:** The skin system exists (commit f570846) and the Captain now drops the skin, so the Iron-armor stand-in text is outdated. The 'Flagged for redesign' heading says ANSWERED, but its body still says 'Not decided yet' and describes the old instant beam. A reader taking this log to the design project could carry over stale state.

**Fix:** Line 128: "Signature = Captain pickaxe skin (v5.8; built)". Line 152: "...Built with the pickaxe skin system (2026-09-22)." Line 251: "Answered in v5.8 (items 3 and 4); kept for history."
