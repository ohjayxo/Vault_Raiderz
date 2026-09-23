# Handoff to the design project: Vault Raiderz build status (2026-09-23)

**For:** Claude in the claude.ai design project.
**From:** Claude Code, which builds the game in Josh's repo (`~/vaultbreakers`,
GitHub `ohjayxo/Vault_Raiderz`).
**Why:** Josh is bringing you design questions. The repo has moved ahead of
your copy of the docs, so read this first to get to where the build is.

---

## 1. Read this first: your docs are behind the repo

Build-time decisions are applied to the repo's `docs/` first, with Josh's
double confirmation, and copied to this project later. So **your copy is
probably stale.**

- **Repo docs are at README v5.10 and nexus v1.9. The registry runs D1–D114,
  so the next free number is D115.** If your copy stops at D109, D110 or
  so, it's behind.
- **Best fix:** Josh re-uploads the repo's `docs/` files (00–14) here. They
  include everything in §3 below. One caveat: the repo's `08-questions.md`
  has no **Q42** (consistency report #30). If your copy has a Q42, keep it
  and tell Josh.
- **Numbering collision already happened once.** The "Main Street" handoff
  arrived numbered D110/D111, but the repo had already used those (D110
  Harvester Drone, D111 pickaxes untradeable, D112 armor). It was applied as
  **D113/D114**. If your copy calls Main Street "D110/D111", rename them.

**When you write a handoff back:** start new decisions at **D115** (ask Josh
to confirm the repo registry first). Name the exact file and section for
each edit, give the exact new text, and mark invented numbers `[PH]`. Claude
Code applies `docs/` edits only after Josh confirms twice.

---

## 2. Build status

Build steps are in `13-build-guide.md`; scope is `10-roadmap.md § Vertical
Slice` (D107).

| Step | What | Status |
|---|---|---|
| S | Scaffold (Rojo, Config, Remotes, ProfileStore) | Done |
| 0 | Estimate + mobile perf spike | Done **except the cheap-phone test** (only run on an iPhone 14 Pro Max, the best case; Josh accepted moving on) |
| 1 | Server-authoritative data layer | Done |
| 2 | Node collection + Grade rolls | Done |
| 3 | Vault Core + Bank/Exposed | Done |
| 4 | Plots, base building, build budget | Done |
| 5 | Combat, pickaxe, upgrade tree, armor, gadgets | Done |
| 6 | Defenses, Scav Waves, Scav Captain | Done |
| 7 | Raiding, lockpick, Chase, raid escort, offline raids | Done (tested in Studio; a few multi-server cases can only be tested on a live server) |
| **8** | **Breach Charges, Riftsalt, raid band, shields** | **Next** (Opus) |
| 9 | NPC selling (price decay), direct trade, Level/Reputation gate | Not started |
| 10 | Workshop I, Tier 1 Tech Path, Research Bench, Common Blueprints | Not started |
| 11 | Crews | Not started |
| 12 | Offline production (one Harvester Drone, D110) | Not started |
| 13 | Analytics | Not started |
| 14 | FTUE polish | Not started |

Also built outside the numbered steps: a pickaxe skin system (the Scav
Captain drops "Captain's Cleaver"), an art-ready pass (every visible
object is a Hitbox + Visual template so an artist can reskin in Studio
without code), the Bag inventory panel, and a mock environment (trees and
bushes).

**The game is greybox.** Parts, default rigs and placeholder colours. Josh's
girlfriend (an art designer) will reskin it later. The pickaxe now uses an
imported mesh (CC-BY-4.0, by aaronsilvagrandon on Sketchfab; must be
credited in the game before launch).

**Step 8 context:** the raid code already has empty hooks for it
(`checkBreach` / `consumeBreach`). Step 8 fills in Breach Charges (crafted
from Riftsalt, which only spawns in the Contested Reaches), the raid band
(D66/D79/D92), the 48-hour new-account shield and the 30-minute post-raid
shield (D75). Offline bases shown on free plots don't match by band yet;
step 8 adds that. **Watch for:** charges are "crafted", but Workshop I
doesn't arrive until step 10. Josh may ask you how players make charges
before then.

---

## 3. What changed. Part A: already in the repo's `docs/`, maybe not in yours

Copy these across if Josh doesn't re-upload the docs.

- **v5.7:** **D111** pickaxes aren't tradeable, pickaxe skins are
  (supersedes D21). **D92** wording: gear score counts *pickaxe upgrade
  nodes*, not Tech Path nodes. **Level curve [PH]:** XP to reach track
  level n = floor(100 × n^1.5); Level = sum of track levels, derived from
  XP. **D112 armor:** craftable, one chest slot, tiers named like the
  pickaxe (Wooden → Iron → Voltsteel → Riftedge), knockback resistance and
  small damage reduction [PH]. Spare pieces are stealable, the worn piece
  never (R1). Not tradeable (armor skins are). Gear score adds highest owned
  armor tier × 10.
- **v5.8:** "Sprint recovery" became **"Stun recovery"** (the docs never had
  a sprint). Scav Captain Signature drop = **a Captain pickaxe skin**.
  **Vaultborn beam** is faint, fading and blinking: missable when scanning,
  visible to a watchful player. **Zones carry a Contested flag:** the
  Reaches (later the Rift) are Contested, the Homestead never is.
  Riftsalt spawns are refused outside Contested zones.
- **v5.9:** game renamed **Vaultbreakers → Vault Raiderz**; "Vaultbreaker
  Level" is now just **"Level"**.
- **v5.10:** **D113 Main Street layout:** the Homestead is a straight
  street with two facing rows of 4 plots, equal-length bridges, plots
  rotated so their gate side faces their bridge, the Reaches off the north
  end, and a south plaza for the NPC buyer and the FTUE derelict vault.
  **D114:** the Chase escape = about 140 studs [PH] from the victim plot's
  centre; a carrier who dies (falling included) drops the loot home.
- **Step 3 banking rules** (in `02 § Bank vs Exposed`): banking is manual at
  the Vault Core; capacity counts total units; when not everything fits,
  the best goes in first (highest Grade, then rarest resource).
- **Lockpick** is now "Skyrim-style" (in `02 § The raid sequence` and
  Prompt 7), no longer a "timing bar". Details in Part B, step 7.
- **Consistency pass (2026-09-23):** 38 small doc fixes that follow
  decisions already made (e.g. Prototype blueprints don't wear out per D77;
  "Seed" → "Pattern" leftovers; README status; nexus file list). Josh has
  the full list in `docs-build/consistency-report.md` Part A.
  Decisions from it: **#13** an offline base can be raided **once per
  absence**, and the 30-min post-raid shield starts at the victim's next
  login. **#37** one grab takes the victim's **best spare armor piece**,
  whole. **#40** Workshop I crafts **basic** lockpicks and gadgets for
  everyone; Tech Path **Breaching** nodes unlock **better** ones.

## 4. What changed. Part B: Josh's build-time calls, NOT in any `docs/` yet

These are decided and built, but no doc says them yet. **Treat them as
current design.** Where they amend a doc, propose the wording in your next
handoff.

**Step 2 (nodes + Grade)**
1. Grade is rolled **per hit**, not per node. Reword `05 § The Voltstone
   trickle` "a Volatile-grade Ore node" → "a Volatile-grade Ore hit".
2. Grade effects are **seen by everyone** as a short burst at the node.
3. Vaultborn sits in the **middle of the D58 broadcast queue**: below raid
   alerts and Chase pings, above cosmetic flex.
4. The Vaultborn announcement goes out **~30 s [PH] after** the strike (the
   head start).
5. Nodes (D38): a depleted Reaches node returns after a random 45–90 s [PH]
   at a *different* spawn point. Homestead nodes return at the same spot
   after a fixed 30 s [PH].

**Step 4 (plots + building)**
1. **Band metric:** gear score is converted to tier units, floor(gear score
   / 10), before taking the highest of vault tier, lifetime peak and gear
   score. Otherwise raw gear score (a Wooden pickaxe alone = 10) always wins.
   Belongs in `02 § Preconditions` or D66.
2. Removing a base piece **refunds 50% [PH]** (a full refund would let
   players hide resources in walls). The Vault Core can move but never be
   removed.
3. Spending takes **Exposed before Banked, lowest Grade first**.
4. Placing the Vault Core = vault tier 1; tiers 2–7 are bought with
   **"Upgrade Vault"** (costs [PH]).
5. The owner walks through their own gates; everyone else is blocked.
6. **Perf finding for D57:** "piece count" is the wrong budget unit.
   Identical pieces render almost free (batched); triangles and unique
   materials cost frame time. The build uses a per-piece render-weight
   `BudgetCost` [PH]. Suggest rewording D57 to "render-weight budget
   (triangles + unique materials)". Real numbers wait on a cheap-phone test.

**Step 5 (combat + gear)**
1. **Death costs time only:** respawn ~5 s [PH] beside your own plot, lose
   nothing (outside a raid).
2. Upgrade points come with the pickaxe tier (Wooden 3, Iron 6 [PH]). Each
   node rank costs 1 point + resources. Respec returns all points for a fee.
3. The Iron pickaxe, armor and gadgets are **crafted at Workshop I** (step
   10); there's no buy menu.
4. **Shock Trap:** thrown ahead, lands, arms, and stuns the first other
   player or Scav to touch it (~1.5 s [PH], lasts 30 s [PH]).
5. Interpretations: Smoke Bomb = a cloud at your feet (no targeting you
   from more than 4 studs inside it); walls block hits; PvP-protected
   players can neither hit nor be hit by players.

**Step 6 (defenses + Scavs)**
1. A Scav Wave **fails when a Scav survives ~10 s [PH] at the Vault Core**.
   It takes 2% [PH] of Exposed and leaves. Kill every Scav = success.
2. Defenses fire only at Scavs and at raiders of that base, never at
   visitors.
3. Waves every 8–12 min [PH] while online, once you have a Vault Core; the
   Captain leads ~1 in 4 [PH].
4. Captain drops: Rare = 40 Research Scrap (**temporary** until step 10
   blueprints); Signature = the Captain's Cleaver skin.
5. Interpretations: defenses count against the build budget plus a
   per-tier defense-slot cap (2–5 [PH]); Scavs go for a charged Decoy Vault
   first; a Scav blocked by walls hops over after 3 s (never hard-blocked).

**Pickaxe skins**
1. An equipped skin replaces the whole pickaxe look, so the tier isn't
   visible (keeps tier a private power stat).
2. A duplicate skin drop is kept as a spare (tradeable in step 9).

**Step 7 (raiding)**
1. **Offline bases appear on free plots** (recent leavers, up to 7 days
   [PH]), so scouting stays visual.
2. **Escort** = one Roblox friend of the raider who opts in at breach
   (D101). Their hits don't knock loot loose; defenses treat them as
   intruders.
3. **One grab takes the whole theft share** (25% online / 8% offline,
   capped per tier [PH]).
4. **Lockpick:** Skyrim-style. Aim the pick, hold Turn. Each of the **3
   stages** has a hidden sweet spot; near it the lock turns part way ("getting
   warm"). Forcing it shakes the lock and wears the pick until it snaps.
   Vault tier and Lock Upgrades narrow the sweet spots and break picks
   sooner, but never add stages. The raider can't move while picking.
   **Lockpicks are items** crafted from Ore at Workshop I; with none left
   you improvise at ~35% speed (never blocked, so "speed, not
   success/failure" holds). The sweet spot lives only on the server (R5).
5. The 90 s raid window starts at breach. Tiers 5–7 sabotage = one defense
   offline for 15 min. A failed raid (knocked loose, died, left, timed out)
   ends the raid.
6. **Escape needs solid ground:** the 140-stud radius only counts while the
   carrier stands on something (closes the jump-off-and-die exploit).

**UI + Chase feedback (2026-09-23)**
1. **The Bag:** one panel with tabs Resources | Gear | Items, split into
   SAFE (banked / worn) vs AT RISK (exposed / spare armor).
2. **Chase progress:** raider, victim and escort banners show the carrier's
   distance ("70/140 studs"). The victim gets one alert at halfway. There's
   no server-wide halfway ping (the Chase is ~15 s; the D58 queue would lag).
3. **Raid log for both sides:** the raider gets an entry too ("You raided
   X: Got ..." / "Failed: <reason>").

**Wider Main Street (2026-09-23)**
- Josh felt the street was a runway, so the grass each side of the road
  was **tripled**: street 96 × 320 → **240 × 320**, plaza → **240 × 96**.
  Bridges still 64, plots, escape radius and Scav lanes unchanged.
  Costs: crossing to the opposite plot ~15 s (was ~6 s); facing plots are
  368 studs apart (was 224); plot-to-Reaches walk ~+2–3 s against D113's
  ~25 s target. `02 § Slice layout` "Starting sizes [PH]" is out of date.
  Easy to revert to double (168) or the original.
- Mock trees and bushes added (placeholder).

---

## 5. Open design questions and flags

- **Q33 / Q34** (boss loot: killer vs ground, instanced vs shared): still
  parked. Only the Scav Captain is in the slice.
- **Q42** is missing from the repo's `08-questions.md`; check your copy.
- **Decoy Vault vs raiders:** it only distracts Scavs today. A raider can
  just ignore it, but the docs say it "wastes ~20 s of the 90 s window".
  Should it do more against raiders?
- **D57 budget unit** (Part B, step 4.6): needs rewording, and real numbers
  need a cheap-phone test.
- **Step 8:** how Breach Charges are crafted before Workshop I (step 10)
  exists.
- **Known engineering limits** that may bear on design: plots only exist
  while the owner is on the server (offline bases are rebuilt from saves);
  8 plots per server, so max 8 players until real sharding; Scavs have no
  walk animations yet (greybox).

---

## 6. Rules that shape answers (from the repo's `CLAUDE.md`)

- **Scope wall (D107).** Not in the slice: global Exchange, Cases/Keys,
  Condition/Pattern rolls, seasons, Marks, Workshop II/III, Fragments,
  bosses beyond the Scav Captain, world events, farming, pets, rebirth,
  Robux purchases. Designs for later are fine, but mark them post-slice.
- **Non-negotiables R1–R8** (`01-pillars.md`), especially **R5: the
  server is the only authority** (clients send intents only; odds never
  reach clients) and **R6: new players can't be farmed**.
- **Missing numbers** are fine to invent as `[PH]`. **Missing behaviour**
  is Josh's call: give him 2–3 options and a recommendation.
- Josh is new to Roblox development: plain language, short sentences.

## 7. Model notes

Per `11-claude-usage-guide.md`: exploit-sensitive or cross-file design
questions (raid rules, band/shield logic for step 8, economy math) deserve
Opus with extended thinking.
