# 07 — Decisions & Rationale

**Read this before changing anything.** Every entry records what was
decided, why, and **what was rejected**. The rejected column is the point
— it prevents re-litigating settled questions and prevents a future
session "helpfully" reverting a deliberate choice.

---

# CORE STRUCTURE

## D1 — Offline raiding stays, capped at 8% `[LOCKED]`
**Decision:** offline raids permitted, 8% [PH] of Exposed, 30-min shield after.

**Why:** offline raiding is the strongest return hook available —
"you were raided" is a reason to log in, and it makes defenses matter 24/7.

**Why capped so hard:** in Rust roughly 90% of raids occur offline
because it's safer, easier, and more profitable, and the player
frustration is extensively documented — long threads about being raided
seven days running, and arguments that easy raiding kills server
populations. **The incentive gradient must actively push toward online
raids**, or offline becomes dominant and the world empties out.

**Rejected:** online-only raiding (loses the pull-back hook); uncapped
offline (Rust's outcome).

**Still open:** a "revenge marker" letting victims counter-raid at a
bonus, converting a loss into a quest.

## D2 — Hybrid rebirth `[LOCKED — rewards amended by D70]`
**Decision:** reset resources and vault tier; keep cosmetics, trophies,
titles, rank history.

**Why:** full reset (Steal a Brainrot model) has a bigger payoff but real
quit risk at the reset moment. Soft prestige has no teeth. The hybrid
applies R1 — lose the fungible, keep the identity.

**Rejected:** full wipe; cosmetic-preserving soft prestige with no reset.

## D3 — High-skill lockpick, expressed as speed `[LOCKED]`
**Decision:** high ceiling, but skill determines **how fast** you get in,
not whether you succeed.

**Why:** a pure success/fail skill gate locks content behind reflexes for
young and mobile players. Speed-as-skill preserves accessibility while
genuinely rewarding mastery — skilled raiders escape before the owner
reacts.

**Rejected:** binary success/fail; cosmetic-only difficulty.

## D4 — Solo raids low tier, crew raids high tier `[LOCKED]`
**Decision:** solo by default; crew raids unlock only against high-tier vaults.

**Why:** gives players a reason to grind toward playing with friends, and
scales the social layer in as players mature. High-tier defenders have
the tools to handle a group; new players never face one.

**Rejected:** solo-only (loses social ceiling); crews at all tiers
(5-on-1 against beginners).

## D5 — Steal-only, tiered soft destruction `[SUPERSEDED at elite tiers by D23]`
**Original decision:** nothing permanently destroyed. Tiers 5–7 allow
temporary disable; 8–10 allow repairable damage.

**Why originally:** R2. Destruction crosses the identity line and is the
fastest path to rage-quitting in a young audience. High-tier players
opted into higher stakes by climbing.

**What changed:** Q20 revisited whether "damage, never destroy" was too
soft for elite play. Answer: yes, too soft. **D23 now allows real,
permanent structural destruction at tiers 8–10 only.** Tiers 1–7 are
unchanged from this original decision. See D23 for the full rationale.

**Rejected:** Rust-style structure destruction at all tiers; pure
steal-only at all tiers (this file's original tiers 5-10 model, now
partially superseded).

## D6 — Persistent plots `[LOCKED]`
**Decision:** cross-server persistent player plots.

**Why:** ownership drives investment. Matches Grow a Garden's model where
offline growth guarantees something waiting on login.

**Rejected:** per-session plots (trivial infrastructure, no investment).

**Cost:** meaningfully more engineering. Accepted.

## D7 — Deep sessions, 45+ minutes `[LOCKED]`
**Decision:** target the deep-session lane.

**Why:** places the game alongside Blox Fruits, Fisch, and 99 Nights in
the Forest, where players spend 45+ minutes per session, rather than the
short-session lane.

**Consequence:** requires multiple activity types with different rhythms.
A single-activity game fatigues at ~15 minutes. Drove the five-phase
session structure and the PvE ladder.

## D8 — All three pillars viable solo `[LOCKED]`
**Decision:** pure miner, pure trader, and pure raider can each reach top
rank. Hybrid is more efficient, never required.

**Why:** maximizes addressable audience and lowers churn for
conflict-averse players.

**Implementation:** three Mastery tracks; ranked points weighted across
all three.

---

# SYSTEMS

## D9 — Global market, not server-local `[LOCKED]`
**Why:** real price discovery, deep liquidity, an actual economy. Server-
local would be safer to build and enable arbitrage gameplay, but the
global version is the more compelling product.

**Confirmed feasible** — Roblox documents cross-server trading and global
marketplaces as a MemoryStoreService use case.

**Constraint accepted:** MemoryStore is authority, MessagingService is
hint-only.

## D10 — CS-style Condition + Seed `[LOCKED — the Seed roll renamed "Pattern" by D93]`
**Decision:** three independent rarity rolls — Grade (value), Condition
(wear, cosmetic only), Seed (pattern, 1–1000).

**Why:** infinite collector depth at near-zero content cost. CS's value
hierarchy is community-generated rather than developer-assigned, which
makes it self-sustaining content.

**Key implementation rule:** only a handful of "Unstable Finishes" are
seed-sensitive, mirroring CS where most finishes are uniform and seed is
irrelevant. Scarcity comes from ~1,000 seeds where only a dozen produce
something spectacular.

**Rejected:** Condition affecting stats (pay-to-win-by-luck); every skin
being seed-sensitive (dilutes any single seed becoming legendary).

**Open risk:** Roblox lacks custom shaders. Reliable fallback is
seed-driven hue/UV-offset/accent/overlay. Needs prototyping.

## D11 — Tech Path replaces the class system `[LOCKED]`
**Decision:** cut menu-based specialization (Prospector/Engineer/Raider/
Trader). Your tech path is your class.

**Why:** emergent rather than declared, gradual rather than locked at
minute 10, and readable by other players. The mechanism is scarcity —
Rust's full tree costs ~10,820 scrap and almost nobody clears a tier, so
everyone beelines.

**Rejected:** menu-selected classes with perks `[CUT]`.

## D12 — Workshop as physical tiered structure `[LOCKED]`
**Decision:** research is a place. Three tiers, each adjacent to the
previous, gated by Fragments.

**Why:** Rust's Meta Shift moved T2/T3 benches onto looted Blueprint
Fragments specifically to push progression from solo farming to contested
runs. This is the mechanic that forces world engagement.

**Rejected:** inventory-based research with no physical structure
(the earlier v4 model) `[CUT]`.

## D13 — Both Research Bench and Tech Path `[LOCKED]`
**Why:** they solve different problems, and Rust players use both —
research what you loot (cheaper, needs the item), tech-tree the gaps
(costlier, guaranteed). Looting and grinding feed one progression from
two directions.

## D14 — Four resources with distinct jobs `[LOCKED]`
**Decision:** Stone / Ore / Voltstone / Riftsalt, modeled on Rust's
stone/metal/HQM/sulfur.

**Why:** the previous nine-resource model was a single ladder in nine
costumes — every resource meant "higher tier = better," which contains no
decisions. Rust's four each create a genuine tradeoff.

**The Riftsalt rule is the key consequence:** raid material only spawns
in contested zones, so **you cannot be a safe farmer and a raider**
(amended by D20 — see below).

**Rejected:** nine-resource tier ladder `[CUT]`.

## D15 — Option A on Cases and Keys `[LOCKED, tiering amended by D30, Robux-cosmetic leak closed by D65]`
**Decision:** Cases drop from the world and are purchasable with Credits;
Keys cost Credits. **Robux cannot buy Credits.** Both Cases and Keys
trade.

**Why:** preserves every interesting economic behavior — case trading,
key demand, speculation, the save-up loop — while sitting entirely
outside Roblox's Paid Random Items policy, which explicitly covers
indirect purchases and names keys-for-boxes.

**Rejected:**
- **Option B (Robux keys)** — highest revenue, proven CS model, but
  requires full odds-disclosure UI in an actively shifting regulated area,
  with a heavily under-13 audience.
- **Option C (no keys)** — kills the case market entirely; an
  instantly-openable case is a delayed reward, not a tradeable good.

## D16 — Cases stealable while sealed `[LOCKED]`
**Why:** a sealed case is Schrödinger's loot. Stealing resources is
stealing a number; stealing a sealed case is stealing a possibility.
Best single upgrade to raid emotional payoff.

## D17 — Hunger cut, teas deferred to Season 2 `[LOCKED]`
**Decision:** no hunger mechanic ever. Farming ships at launch; teas ship
Season 2+.

**Why hunger is cut:** hunger is a *punishment* mechanic — you lose
something for not doing a chore. Rust's audience accepts deprivation
because it's the genre's point; a young mobile audience experiences it as
nagging, and it punishes the casual player the game can least afford to
lose. Teas are a *reward* mechanic — same content, inverted psychology.

**Why teas are deferred:** shipping everything at launch leaves nothing
to announce in month three. The tea layer is held as a content drop for
exactly the moment veterans run out of things to do — which is also when
its newcomer-supplies-veteran reconciliation matters most.

## D18 — Farming ships at launch `[LOCKED]`
**Why:** provides the safe zero-combat income path, offline content with
visible state change, and a raid target that isn't a number. Grow a
Garden proves the loop carries the platform's biggest game.

---

# ROUND 2 — post-draft-v4.2 questionnaire (this session)

Every decision below came from a rapid-fire questionnaire. Two of them
(D19, D48) touch the same underlying question about what seasons reset —
see the note under D48 for how they were reconciled.

## D19 — The Tech Path wipes at every season reset `[SUPERSEDED by D72]`
**Decision:** the Tech Path resets fully every 6 weeks. Everyone
restarts the tree equal.

**Why:** prevents veterans from compounding tree advantage forever and
creates genuine land-rush energy at season start, mirroring why Rust
periodically wipes blueprints.

**Rejected:** keeping the Tech Path permanent (friendlier, but a
season-1 player stays permanently ahead of a season-5 newcomer).

**Reconciliation note:** see D48 — this answers a narrower question than
Q14 did, and the two are resolved together.

## D20 — Riftsalt is tradeable `[LOCKED]`
**Decision:** Riftsalt can be bought and sold on the market.

**Why:** creates a genuine arms-supplier role — a safe Trader or Miner
can fund a raider without personally entering danger. More economically
interesting than the untradeable alternative.

**Rejected:** untradeable Riftsalt (maximum honesty — every raider
personally earns their raids — but less market depth).

**Consequence:** the "can't be a safe farmer and a raider" rule softens
to "can't manufacture Riftsalt safely, but can buy it" — see
`05-items.md § The Riftsalt rule`.

## D21 — Gear (pickaxes) is tradeable `[LOCKED — Robux-cosmetic route closed by D65]`
**Decision:** pickaxes can be bought and sold, though never stolen while
equipped.

**Why:** deepens the economy substantially — a master crafter's output
becomes a real product. This was originally left cosmetic-only to avoid
a pay-adjacent power market; that concern is judged manageable because
Credits still can't be bought with Robux (R3/R7 intact).

**Rejected:** cosmetic-and-resources-only trading (safer, but shallower
economy; the original v4.2 default).

## D22 — Fragments are tradeable `[LOCKED]`
**Decision:** Core and Rift Fragments can be sold between players, though
never purchased from an NPC vendor and never Robux-purchasable.

**Why:** lets non-combat players buy their way into Workshop progression,
strengthening the pacifist-viability path. Someone on the server must
still loot the Fragment first — the world-engagement pressure survives
at the server level even if it loosens at the individual level.

**Rejected:** untradeable Fragments (strongest possible world-engagement
gating, but blocks a legitimate non-combat progression route).

## D23 — Elite-tier raids (vault 8–10) allow real, permanent destruction `[LOCKED]`
**Decision:** "damage, never destroy" (D5's original model) applies at
tiers 1–7. At **tiers 8–10, a raider may permanently destroy one targeted
structure** per successful raid.

**Why:** Q20 flagged the original softer model as possibly too weak for
elite play — top-tier raiding needs stakes that feel real, and the
existing "always repairable" rule was judged to remove too much tension
at the ceiling of the game. High-tier players have opted into this by
climbing; new players never encounter it.

**Rejected:** keeping "never destroy" uniform at all tiers (D5's
original scope); Rust-style destruction at every tier (crosses the
identity line for new players — R1/R2 still fully protect tiers 1–7 and
all cosmetics/gear at every tier).

**This revises R2's rule (`01-pillars.md`) with a narrow, explicit
carve-out.** R1 is unaffected — cosmetics and equipped gear remain
permanently protected even at elite tiers; only base structures can be
destroyed, and destruction is never looting.

## D24 — Workshop III access rental is manual only `[LOCKED]`
**Decision:** granting a visitor timed crafting access requires a manual
action each time, not an automated listing.

**Why:** an automated rental turns the Workshop into a passive vending
machine and strips out the trust interaction that makes the mechanic
socially interesting. Manual granting keeps "letting someone into your
base" a real, felt decision.

**Rejected:** automated rental (a genuine passive-income business, but
loses the social/trust layer that's the actual point of the mechanic).

## D25 — Tech Path nodes are crew-shared, with a join/leave lockout `[LOCKED]`
**Decision:** any crew member's unlocked node is usable by the whole
current crew, but shared access requires minimum crew tenure and is
revoked immediately on leaving.

**Why:** massive incentive to form and stay in crews — a 4-person crew
can cover in one season what a solo takes four seasons to clear. Without
the lockout, this is trivially exploitable: Rust crews are documented
joining a team purely to inherit its unlocked blueprints, then leaving.
The tenure requirement and instant revocation on departure close that
hole.

**Rejected:** unrestricted instant sharing (exploitable exactly as
above); no sharing at all (removes the single strongest mechanical
reason to have a crew).

**Exclusion:** Prototype Blueprints are explicitly never covered by this
rule — see D34.

## D26 — Bosses scale with group size on a soft curve, not a hard gate `[LOCKED]`
**Decision:** difficulty rises steeply as group size drops, with a
~95% [PH] solo failure rate at the highest tier under baseline gear —
but that percentage genuinely improves with better gear, Mastery, and
skill. No group size is mechanically locked out entirely.

**Why:** incentivizes crews without punishing players who genuinely
can't find others to play with. A hard gate ("2-person minimum, full
stop") would make solo players feel like the game actively excludes
them; a flat difficulty regardless of group size would remove any reason
to group up at all.

**Rejected:** hard group-size gating (excludes solos entirely); fully
flat difficulty regardless of group size (removes the incentive to
group).

## D27 — A solo path into The Rift exists, much harder `[LOCKED]`
**Decision:** Rift bosses remain crew content by design, but a
sufficiently geared/skilled solo player can attempt one.

**Why:** keeps the deepest content from being a pure friendship-gate,
consistent with D8's principle that all three pillars stay viable solo,
even though hybrid/crew play remains more efficient.

**Rejected:** Rift access strictly crew-gated with no solo path at all.

## D28 — A World Boss exists above Rift tier `[LOCKED]`
**Decision:** a rare, server-wide boss event sits above the Rift boss
rotation, on a long cooldown, dropping a seasonal-exclusive Prototype and
a unique cosmetic.

**Why:** a genuine spectacle event gives the whole server something to
plan around and adds a ceiling above the existing content ladder.

**Rejected:** no content above Rift tier (simpler to build, but leaves
the absolute endgame with a hard ceiling and nothing left to chase).

**Cost accepted:** meaningfully more engineering for something that fires
rarely by design.

## D29 — Higher-tier mobs, not just Scavs, can raid player bases `[LOCKED]`
**Decision:** Prowlers and Husks can attack high-tier player bases as
players advance, not only the Homestead-tier Scavs.

**Why:** makes late-game defense meaningful against PvE too, not solely
against other players — a maxed-out pure builder still has something to
defend against even if they never engage in PvP.

**Rejected:** PvE base attacks capped at Scav Waves only (simpler, but
leaves high-tier defenses purely decorative against PvE).

## D30 — Keys are tiered: Standard, Rift, Event `[LOCKED]`
**Decision:** three separate key tiers instead of one universal key.

**Why:** segments the market and allows price discrimination between
case grades, and lets Event keys function as a genuine limited-time good.

**Rejected:** a single universal key (simpler, more liquid, one clear
price — but flattens all case tiers onto one market).

## D31 — Cases are permanent, never expire `[LOCKED]`
**Decision:** sealed and opened cases both persist indefinitely; no case
type has a forced expiry.

**Why:** lets cases become genuine appreciating collectibles, mirroring
why old CS cases hold long-term value.

**Rejected:** expiring cases (forces circulation and prevents hoarding,
but sacrifices long-term collector value entirely).

## D32 — Case contents are a total mystery before opening `[LOCKED]`
**Decision:** no UI element reveals a case's tier or contents before it's
opened. Players infer value the same way they scout a raid target — from
visual signals like base size, gear, and defense investment — never from
a menu readout.

**Why:** keeps raid targeting a genuine scouting skill and preserves the
opening moment as the single point where the payoff is revealed, mirrors
Rust's "you never know exactly what a base holds until you breach it."

**Rejected:** visible tier before opening (builds anticipation and makes
targeting more calculated, but flattens the mystery that makes opening a
case exciting).

## D33 — Blueprint durability is tiered by rarity, inverted from the naive default `[LOCKED]`
**Decision:** **Common blueprints are permanent once learned.** **Advanced
and Prototype blueprints wear out with use and must be relearned or
replaced.**

**Why:** ongoing demand belongs exactly where the economy is deepest.
Low-tier permanence keeps the game friendly and low-stakes for new
players; high-tier wear-out means even a veteran Engineer with elite
recipes has to keep returning to the source content, so a boss-farming
crew's manufacturing advantage never becomes a one-time, permanently
solved unlock.

**Rejected:** uniform permanence at all tiers (friendlier, but the
economy's top end eventually stops needing anything from the world);
uniform wear-out at all tiers (too harsh for new players learning Common
recipes).

## D34 — Prototype recipes are not server-unique, but are capped at 1-per-player and never crew-shared `[LOCKED]`
**Decision:** many players across a server can independently learn the
same Prototype blueprint (no server-wide monopoly), but each individual
player can only ever hold one copy, and Prototype blueprints are
explicitly excluded from the D25 crew-sharing rule.

**Why:** keeps elite recipes genuinely personally-earned even inside a
crew that otherwise shares Tech Path access, while avoiding the harsher
model where one crew could corner an entire recipe server-wide.

**Rejected:** server-unique Prototypes (intense scarcity and real
monopolies, but likely too harsh and creates first-mover lock-out);
crew-shared Prototypes (would undercut the "personally earned" identity
of elite recipes entirely).

## D35 — Learning a rare blueprint announces publicly `[LOCKED]`
**Decision:** learning an Advanced or Prototype blueprint triggers a
server-visible announcement, similar to the Vaultborn Grade
announcement.

**Why:** strong social proof and flex value (rubric criterion 7), and
gives crafters a real, visible reputation.

**Rejected:** keeping blueprint learning private (protects producers from
being targeted, but loses a meaningful flex/social moment).

**Accepted cost:** it paints a target on producers of valuable goods —
raiders now know who to hit. This is treated as a feature, not a bug,
consistent with how Vaultborn announcements already work.

## D36 — Other players' Tech Path nodes are visible to crewmates only `[LOCKED]`
**Decision:** you can see what your own crewmates have unlocked; you
cannot see this for players outside your crew.

**Why:** lets crews coordinate tree-splitting internally (the whole
point of D25's sharing rule) while keeping build information private
leverage against the rest of the server.

**Rejected:** fully public visibility (helps the market find specialists
server-wide, but removes any information advantage from crew
membership); fully hidden even within a crew (defeats the coordination
purpose of D25).

## D37 — Tech Path respec grants a partial Scrap refund `[LOCKED]`
**Decision:** respeccing refunds a portion of spent Scrap [PH — suggest
50%], not the full amount and not zero.

**Why:** lets players correct a genuinely bad build without making every
tree choice fully reversible, which would cheapen the scarcity that
makes the Tech Path function as a class system.

**Rejected:** full refund (removes weight from every choice); no refund
(Rust's model, judged too harsh for a younger audience experimenting
with builds for the first time).

## D38 — Resource nodes deplete and migrate rather than respawning on a timer `[LOCKED]`
**Decision:** nodes in the Reaches and deeper zones exhaust and relocate
over time, forcing continuous re-exploration. Homestead nodes (used
during the FTUE) are exempt and keep fixed respawns.

**Why:** prevents players from settling into a single static farming
route in contested zones, keeping exploration relevant long-term.
Predictability is preserved exactly where new players need it most
(the FTUE), while the harder zones stay dynamic.

**Rejected:** fixed timers everywhere (predictable and routine-friendly
server-wide, but lets veterans fully solve contested-zone farming and
never move).

## D39 — Voltstone rich-nodes announce themselves `[LOCKED]`
**Decision:** a rich Voltstone node is a visible glowing landmark in the
Reaches, similar in spirit to a mini-Riftfall.

**Why:** converts rich nodes into contested points other players
actively fight over, adding a recurring source of Reaches-zone PvP
tension beyond raiding.

**Rejected:** keeping rich nodes quiet (rewards pure exploration
knowledge, but removes a recurring contested-zone flashpoint).

## D40 — High-tier base upgrades require Voltstone `[LOCKED]`
**Decision:** upgrades past a certain base tier cost Voltstone in
addition to Ore and Stone.

**Why:** closes the "never leave home" loophole — even a pure builder
who avoids all combat and trading eventually has to make a Reaches trip
(or buy Voltstone from someone who did) to keep progressing their base.

**Rejected:** leaving building as the one fully safe, fully
self-sufficient path (friendlier to the most risk-averse players, but
lets one entire pillar opt out of world engagement completely).

## D41 — Crops grow on a pure timer, no tending `[LOCKED]`
**Decision:** no watering or weeding mechanic. Plant, wait, harvest.

**Why:** matches the proven Grow a Garden model and stays friendlier
than an active-tending system that would reward only players who can
check in constantly throughout the day.

**Rejected:** active tending (gives engaged players more to do and more
edge, but disadvantages players who can't be online frequently).

## D42 — Greenhouses are raidable as a separate, lower-stakes raid type `[LOCKED — cost set by D71]`
**Decision:** a dedicated Greenhouse raid exists, distinct from and
lower-stakes than a full Vault raid.

**Why:** gives newer or more cautious players a gentler on-ramp into
experiencing raiding for the first time, since losing some crops carries
much lower stakes than a full vault breach.

**Rejected:** folding crop theft entirely into standard Vault raiding
(simpler, but removes the gentle-onramp option).

## D43 — No crop, including tea ingredients, is contested-zone-locked `[LOCKED]`
**Decision:** every crop, now and in the Season 2 tea system, can be
grown safely on a player's own plot. None require venturing into
contested zones.

**Why:** farming's entire job in the design is to be the fully safe
income path (`04-world-content.md § Farming`). Introducing even one
contested-zone-only crop would compromise that guarantee for whichever
player wants the tea layer.

**Rejected:** a Riftsalt-style rare tea ingredient locked to contested
zones (would force brewers into danger, mirroring the raiding self-
balancing logic — but breaks farming's core safety promise).

## D44 — Tea duration scales with Workshop tier (S2) `[LOCKED]`
**Decision:** higher Workshop tiers unlock longer tea durations.

**Why:** gives veterans a natural, systemic upgrade path within the
consumable layer itself, reusing the existing Workshop-tier structure
rather than inventing a new progression axis.

**Rejected:** fixed duration regardless of tier (keeps the veteran/
newcomer gap flatter, but removes a natural upgrade path from the
Workshop investment veterans have already made).

## D45 — Teas are always personal, never crew-shared (S2) `[LOCKED]`
**Decision:** a brewed tea buffs only the player who drinks it, even
though Tech Path nodes are crew-shared under D25.

**Why:** protects the veteran/newcomer reconciliation model
(`04-world-content.md § The veteran/newcomer reconciliation`) — a
crew-shared buff would let one skilled brewer trivially boost an entire
crew at once, widening exactly the gap the reconciliation mechanisms are
designed to prevent.

**Rejected:** crew-shared teas (a strong social moment before a boss
fight, and a real argument for crew brewer roles — but too strong a
compounding effect on top of everything else crews already share).

## D46 — Grade odds are not published in-game `[LOCKED]`
**Decision:** exact Grade percentages stay internal; no in-game
disclosure UI.

**Why:** creates community wiki culture and discovery-driven mystery,
consistent with the genre. Not a compliance requirement here — Credits
are gameplay-only, so Roblox's Paid Random Items disclosure rule doesn't
apply (`06-economy.md § Platform policy`) — this is a pure design choice.

**Rejected:** publishing exact odds (builds trust and matches the norm
for paid randomness elsewhere, but this system doesn't touch Robux, so
that norm doesn't obligate disclosure).

## D47 — Launch ships with 2–3 Unstable Finishes `[LOCKED]`
**Decision:** only 2–3 seed-sensitive cosmetics exist at launch, not a
broader set.

**Why:** maximizes focus. A small number of intensely-discussed finishes
produces a more legible community meta than a diluted set where no
single seed becomes as mythologized as CS's Blue Gem.

**Rejected:** ~10 seed-sensitive skins at launch (more breadth, but
dilutes any one seed's chance of becoming legendary).

## D48 — Seasons reset rank and the Tech Path; the economy persists `[LOCKED — reconciles Q14 and Q44; amended by D68, D72]`
**Decision:** at each 6-week season boundary, **Rank and the Tech Path
reset. Resources, Credits, Scrap, the global market, plots, and
cosmetics all persist.**

**Why this reconciliation:** two questions were answered in the same
session that read as contradictory taken literally — Q44 said the Tech
Path should wipe every season ("everyone restarts equal"), while Q14
said seasons should reset rank only and "the economy stays intact." The
working interpretation here is that Q14's "economy" refers to resources,
currency, and the market specifically, while Q44 addresses the Tech Path
as its own, separate progression system that the higher-priority
question explicitly called out for a full wipe. **This is an inferred
reconciliation, not a re-confirmed decision** — if the intent was that
literally nothing but rank resets (Tech Path included), this is the
single easiest entry in this document set to flip. See
`03-progression.md § Ranked Ladder and Seasons` for where this plays out
mechanically.

**Rejected (if the reconciliation above is wrong):** a pure rank-only
reset with the Tech Path also persisting — flag this explicitly on the
next design pass if that was the actual intent.

## D49 — Crews get a shared Crew Vault `[LOCKED]`
**Decision:** each crew has a Crew Vault distinct from individual player
vaults, with its own bank/exposed split and its own permission tiers.

**Why:** a strong social anchor and a legitimately great raid target —
successful raids against it hit a whole crew's morale at once, a bigger
emergent moment than any single-player raid.

**Rejected:** no shared vault, crew resources always stay individually
owned (simpler, but removes a meaningful reason to deepen crew
cohesion).

**Still undesigned:** exact deposit/withdraw permission tiers and the
disband-split rule. Flagged for a follow-up pass.

## D50 — Crew raid loot splits by contribution, with a gift option `[LOCKED]`
**Decision:** default split is contribution-weighted; any member can
choose to gift their share to a specific crewmate instead of keeping it.

**Why:** avoids both failure modes of a rigid rule — pure equal-split
under-rewards whoever did the actual lockpicking or tanking, and pure
leader-allocation breeds resentment. The gift option lets a crew
self-organize around whoever needs an item most without forcing every
edge case into one formula.

**Rejected:** pure equal split (simplest, least drama, but ignores
contribution); pure leader-allocated (creates a single point of
resentment).

## D51 — The Research Bench consumes the physical item `[LOCKED]`
**Decision:** no softened version. Learning a blueprint at the Research
Bench destroys the item that taught it, full stop.

**Why:** the sacrifice is the entire point of the mechanic — "a looted
item in your hands is one item; a researched item is every one you'll
ever have materials for." Softening it with a partial-materials-back
version would blunt the decision that makes the Bench interesting.

**Rejected:** consuming the item but returning a fraction of materials
(protects a young player from an avoidable mistake, but removes the
weight of the trade-off).

## D52 — Advanced+ blueprint drops are visible on the ground before pickup `[LOCKED]`
**Decision:** a dropped Advanced or Prototype blueprint is labeled and
visible before anyone picks it up. Common blueprints are not labeled
this way.

**Why:** turns a contested Riftfall or boss kill into a real fight over a
known prize rather than a surprise discovered afterward — directly
strengthens the PvP-bait design of bosses and Riftfall
(`04-world-content.md`).

**Rejected:** keeping all blueprint drops a surprise (preserves
discovery, but removes a strong source of in-the-moment conflict).

## D53 — Vertical slice scope: "richer," not minimal `[LOCKED — final scope set by D107]`
**Decision:** the vertical slice now includes **Workshop I, Tier 1 Tech
Path, the Research Bench, Common-tier Blueprints, and Crews (2–4, with a
shared Crew Vault and crew-shared Tier 1 nodes)**, in addition to the
original minimal-slice systems. See `10-roadmap.md § Vertical Slice` for
the full updated in/out scope tables.

**Why:** these systems are judged cheap relative to their payoff because
they mostly reuse infrastructure the minimal slice already needed (the
Bank/Exposed split, the raiding loop, server-authoritative validation).
Including them lets early playtesting validate crew formation and
progression pacing — two of the design's biggest open bets — much
earlier than a fully minimal slice would allow.

**Rejected:** the original minimal slice (2 resources, one zone, no
market/tech tree/crews at all) — judged too conservative once the owner
weighed in that the added systems were worth the extra build cost. Also
rejected: including the *entire* design in the slice (Workshop II/III,
the full Tech Path, Advanced/Prototype blueprints, the global Exchange,
Cases/Keys, and Seeds remain deferred to full launch — see roadmap for
the line).

---

# ROUND 3 — platform limitations audit (Q59–Q69)

These answers were assigned D54–D64 in `08-questions.md` and applied in
`02`/`06` before their entries existed here. **Entries below were
reconstructed in v5.3 from the questions' argued options** — confirm the
rationale reads right.

## D54 — Data compaction is deferred until real usage data exists `[LOCKED]`
**Decision:** keep the current rich data shape (tenure timestamps,
durability counters, etc.) and compress once real usage patterns are
known.

**Why:** avoids optimizing a schema before knowing which fields actually
grow.

**Rejected:** designing compact now (bitpacked Tech Path state, capped
raid logs) — the lean at the time, because retrofitting after live data
exists is the expensive path. **Risk accepted:** that retrofit cost, under
DataStore's 2026 storage cap (`09-research.md § Data Architecture`).

## D55 — Inactive plots archive, never delete `[LOCKED]`
**Decision:** plots inactive past ~1 year [PH] move to compressed cold
storage and restore fully on return (`02-core-loop.md § Plot lifecycle`).

**Why:** keeps R2's "nothing lost" promise in spirit while giving the
storage cap real headroom.

**Rejected:** never touching plots (honors D6 literally, but leaves
storage growth unbounded).

## D56 — The Homestead is sharded into vault-tier-matched neighborhoods `[LOCKED]`
**Decision:** each server hosts a bounded, tier-matched set of plots;
cross-neighborhood scouting uses a lighter map view
(`02-core-loop.md § Server sharding`).

**Why:** R6 already implied tier-banded groupings; this protects the
mobile render budget.

**Rejected:** one shared world per server (truest to "fly over and
scout," but caps active bases before LOD becomes mandatory).

## D57 — Hard tier-scaled build budget, Decor included `[LOCKED]`
**Decision:** every buildable counts against a tier-scaled piece/draw-call
budget enforced at placement (`02-core-loop.md § Build budget`).

**Rejected:** no explicit cap (trusting tier gating — but Decor was
unbounded).

## D58 — One prioritized broadcast queue `[LOCKED]`
**Decision:** all server-wide announcements share one rate-limited,
prioritized queue; raid alerts and Chase pings outrank flex
announcements (`06-economy.md § Broadcast priority queue`).

**Why:** MessagingService drops silently past 60 msg/min/topic; "owner
alerted instantly" cannot be the message that gets dropped.

**Rejected:** independent broadcasts per system.

## D59 — Server-wide cap on concurrent Scav Waves `[LOCKED]`
**Decision:** overflow waves queue with a short delay
(`04-world-content.md § Concurrent wave ceiling`).

**Rejected:** no cap, tune empirically.

## D60 — Single mobile-first vertical Tech Path tree `[LOCKED]`
**Decision:** one collapsible vertical tree per Workshop tier, large tap
targets (`03-progression.md § Structure`).

**Rejected:** a filtered list/search view with the visual tree as a
secondary toggle (two UIs to maintain).

## D61 — Zero chat required anywhere `[LOCKED]`
**Decision:** fixed-price listings only, invite/accept crews; no
negotiation UI for anyone (`06-economy.md § Zero-chat trade`,
`03-progression.md § Zero-chat crew invites`).

**Why:** chat is off by default under age 9; the loop must work
identically with or without chat.

**Rejected:** an optional preset-phrase/emoji negotiation layer on top.

## D62 — Cross-shard workshop directory, built at launch `[LOCKED]`
**Decision:** a lightweight "workshops open" directory spans shards
(`03-progression.md § Cross-shard workshop directory`). Granting stays
manual (D24).

**Rejected:** accepting local-only reputation for launch and adding the
directory in v1.0+ (the lean at the time, on scope grounds).

## D63 — Prototype seed variants before locking the model `[LOCKED]`
**Decision:** build a narrow Studio prototype of pre-baked seed variants
before committing (`05-items.md § Roblox feasibility`).

**Rejected:** committing to the pre-baked model immediately.

## D64 — Unified threat strip on the HUD `[LOCKED]`
**Decision:** one priority-ordered alert strip
(`02-core-loop.md § HUD Priority`).

**Rejected:** one HUD element per system, relying on rare overlap.

---

# ROUND 4 — v5.3 rule-leak fixes

## D65 — Robux-bought cosmetics trade only in a separate swap pool `[LOCKED]`
**Decision:** a Robux-bought cosmetic can be swapped only for another
Robux-bought cosmetic **of the same rarity tier** (D74). It can never be
sold for Credits, used on Cases/Keys, or fed into any random-outcome
mechanic. Earned cosmetics trade freely.

**Why:** the previous state let Robux → cosmetic → Credits → Keys, gear,
and Fragments. Roblox's Paid Random Items policy covers goods purchased
with Robux, and R3 covers gear/Fragments now that they trade (D21, D22).

**Rejected:** fully tradeable Robux cosmetics (the pre-D65 state —
leaks); swap-for-any-same-tier cosmetic (still leaks: the earned item
received in the swap can be sold); taint propagation (airtight, but a
"swap-only" badge spreading between items confuses young players);
fully account-bound (safest, but removes Robux cosmetic trading
entirely).

**Amends:** D15, D21, R3, R7.

## D66 — Raid band = highest of vault tier, lifetime peak, or gear score `[LOCKED]`
**Decision:** matchmaking uses the highest of current vault tier,
lifetime peak vault tier, or gear score.

**Why:** rebirth resets vault tier, and gear is tradeable (D21) — either
alone let a veteran or a geared alt into the beginner band.

**Rejected:** vault tier only (original R6); gear score only (misses a
rebirthed veteran who parks their gear); higher of tier or gear score
(misses lifetime peak).

**Open:** the gear score formula. **Consistency note `[PROPOSED]`:**
neighborhood sharding (D56) is keyed on vault tier — it should likely use
the same band metric, or a rebirthed veteran is placed among neighbors
they can't raid. Not changed without confirmation.

**Amends:** R6.

## D67 — Blackout never drops new-account shields `[LOCKED]`
**Why:** a server-wide shield drop that includes 48-hour shields directly
breaks R6.

**Rejected:** Blackout dropping every shield (the original event text).

**Open:** whether the 30-minute post-offline-raid shield is also exempt.

## D68 — Research Scrap converts to a cosmetic-only currency at season end `[LOCKED]`
**Decision:** at each season boundary, all Scrap converts at a rate [PH]
into a cosmetic-only currency (working name **Marks** `[PROPOSED]`,
spent in a seasonal cosmetic shop). Marks and Marks-bought items are
account-bound `[PROPOSED]` so they never become a Credits source.

**Why:** with Scrap persisting (original D48), veterans entered every
season with a stockpile and instantly rebought their tree — the reset was
fictional.

**Rejected:** Scrap persists (original D48); Scrap wiped to zero (harsh,
feels like theft by the game); Scrap → Credits (an inflation faucet).

**Amends:** D48.

## D69 — No Credits → Scrap route `[LOCKED]`
**Decision:** NPC sales are removed as a Scrap faucet; market-acquired
items recycle at a heavy loss [PH], tracked by a server-side flag.

**Why:** "Why Scrap is separate from Credits" (`06-economy.md`) was
unenforced — Credits could buy goods that recycled into Scrap.

**Rejected:** status quo; no recycling of market items at all (punishes
legitimate players who bought gear they later outgrew).

## D70 — Rebirth is prestige-only; the Robux skip token is cut `[LOCKED]`
**Decision:** rebirth grants a tier marker, exclusive cosmetics, and
titles — no multipliers. No Robux skip.

**Why:** permanent multipliers were power (R3), and combined with the
vault-tier reset they created the smurfing hole D66 closes.

**Rejected:** multipliers (original D2); keeping the skip token as
"convenience."

**Open:** whether prestige alone is enough incentive to rebirth.

**Amends:** D2, R3.

## D71 — Greenhouse raids cost no Breach Charges `[LOCKED]`
**Decision:** Greenhouse raids are free; once teas ship (S2), raids that
can take teas cost charges.

**Why:** keeps the gentle on-ramp (D42) from being gated behind Riftsalt.

**Rejected:** requiring Breach Charges for every Greenhouse raid.

**Guardrails `[PROPOSED]`:** band + 48-hour shield apply; per-target
cooldown; daily cap. **Amends:** D42.

## D72 — Staggered tier resets for the Tech Path and learned blueprints `[LOCKED]`
**Decision:** Tier 1 never resets; Tier 2 resets every 6 weeks (season
boundary); Tier 3 every 3 weeks [PH]. Applies to Tech Path trees and
learned blueprints of the matching tier (Common/Advanced/Prototype).
Workshop structures never reset.

**Why:** a permanent Tier 1 gives new players progress that always
sticks; faster churn at the top mirrors D33 and keeps boss content
contested.

**Rejected:** full wipe every season (D19); no reset at all.

**Risk:** a player reaching Workshop III in week 2 gets one week before
the Tier 3 reset. **Proposed mitigation:** Tier 3 re-buys cost a Rift
Fragment (`03-progression.md § Staggered tier reset`).

**Supersedes:** D19. **Amends:** D48.

## D73 — Seeds come from wild plants and cache seed packs `[LOCKED]`
**Decision:** crop seeds are foraged from wild plants across the world;
seed packs are a low-tier World Cache reward.

**Why:** makes farming feed exploration, and keeps seeds off a
Credits-faucet vendor loop.

**Rejected:** a vendor seed shop as the primary source (the Grow a
Garden model).

**Guardrail `[PROPOSED]`:** every crop obtainable in the Homestead
(D43). **Accepted cost:** loses what would have been the largest Credits
sink — partly restored by the proposed rare-seed vendor.

## D74 — Cosmetics get rarity tiers `[LOCKED]`
**Decision:** six tiers, Common → Mythic (`05-items.md § Rarity tiers`).
Names/colors and "Mythic is earned-only" are `[PROPOSED]`.

**Why:** case pools, D65's same-tier swap rule, and any future trade-up
all need a tier key. Grade covers resources only.

**Rejected:** no tiers (Condition + Seed alone can't express rarity).

---

# ROUND 5 — v5.4 (32 remaining calls from the Part 1/2/3/4 discussion)

## D75 — 30-minute post-raid shield is also exempt from Blackout `[LOCKED]`
**Decision:** the temporary shield after an offline raid carries the
same exemption D67 gave the 48-hour new-account shield.

**Why:** the same R6 logic applies — a server-wide shield drop shouldn't
be able to strip a shield the game just granted for the same reason.

**Amends:** D67.

## D76 — Tier 3 re-buy costs a Rift Fragment `[LOCKED]`
**Decision:** re-buying a Tier 3 Tech Path node after its 3-week reset
(D72) costs a Rift Fragment in addition to Scrap.

**Why:** Scrap converts to Marks only at the season boundary (D68), so
without this a veteran's Scrap stockpile lets them instantly rebuy Tier
3 after the mid-season reset — the reset means nothing.

**Rejected:** Scrap-only re-buy (the D72 default, now closed).

## D77 — Prototype exempted from D33 wear-out `[LOCKED]`
**Decision:** Prototype blueprints no longer wear out with use (D33);
D72's 3-week reset is their only churn.

**Why:** the two mechanics stacked — a boss-farming player got hit by
both use-based wear-out and the calendar reset for the same item class.

**Rejected:** keeping both (double churn on the hardest-to-earn tier).

**Amends:** D33.

## D78 — Blueprint-learned announcement narrowed to Prototype only `[LOCKED]`
**Decision:** D35's public announcement on learning a rare blueprint now
fires for Prototype only. Advanced no longer announces.

**Why:** with Tier 2/Advanced now resetting every 6 weeks (D72), keeping
Advanced in the announcement would flood the broadcast queue (D58) with
routine relearns.

**Amends:** D35.

## D79 — Homestead sharding keyed to the D66 band, not raw vault tier `[LOCKED]`
**Decision:** D56's neighborhood sharding uses the same highest-of
tier/lifetime-peak/gear-score metric as raid matchmaking (D66).

**Why:** D66 changed who a player can raid without changing which
neighborhood they're placed in — a rebirthed veteran could end up
surrounded by neighbors outside their own raid band.

**Amends:** D56.

## D80 — Minimal bitpacking now for v5.3's new small fields `[LOCKED]`
**Decision:** the handful of new per-item/per-player flags added this
round (Robux-pool marker, market-acquired flag, lifetime peak tier,
Vaultbreaker Level, Reputation values) are bitpacked from the start.
Full payload compression for larger fields (Tech Path state, raid logs)
still waits on real usage data, per D54.

**Why:** cheap insurance for small, cheap-to-pack fields; doesn't
contradict D54's actual concern (over-engineering the *complex* fields
before real data exists).

**Amends:** D54 (narrows its scope, doesn't reverse it).

## D81 — Reputation tracks replace Mastery tracks `[LOCKED]`
**Decision:** locks the `03-progression.md § Reputation tracks`
proposal — Miner/Trader/Raider XP tracks, cosmetic-and-title rewards
only, no stat effects.

**Why:** the old Mastery tracks duplicated Tech Path branches and
"combat perks" edged into R3/R8 territory.

**Rejected:** keeping Mastery tracks as originally written.

## D82 — Vaultbreaker Level locked, trading gates at Level 10 `[LOCKED]`
**Decision:** locks the permanent Vaultbreaker Level (sum of Reputation
tracks, never resets) and sets the market/Exchange access gate
(`06-economy.md § Access gating`) at Level 10 [PH].

**Why:** gives R4's reveal gate a concrete, server-validated trigger
instead of an undefined "progress gate," and gives the game a spine
that survives every reset in the doc set.

**Amends:** `06-economy.md § Access gating` (fills in the previously
undefined gate).

## D83 — Season track ships free plus premium `[LOCKED]`
**Decision:** each season's cosmetic track has a free tier and a
premium tier; both hold only account-bound, non-random cosmetics.

**Why:** premium revenue without touching R3/R7 — premium is a faster
cosmetic path, never a different reward category.

**Rejected:** free track only (leaves revenue on the table without a
clear R3/R7 conflict to justify it).

## D84 — Scrap-conversion currency named Marks, account-bound `[LOCKED]`
**Decision:** D68's cosmetic-only currency is named **Marks**. Marks and
Marks-bought items are account-bound.

**Why:** account-binding closes the last route by which a converted
currency could re-enter Credits circulation.

**Amends:** D68.

## D85 — Rarity tier names and the Mythic rule locked `[LOCKED]`
**Decision:** D74's six tiers keep the proposed names and colors
(Common/grey → Mythic/red); **the Robux shop never sells Mythic.**

**Why:** without an earned-only top tier, Robux purchases could
eventually out-flex drops and Cases, undermining D65's whole point.

**Amends:** D74.

## D86 — Rebirth deferred to S2+ `[LOCKED]`
**Decision:** Rebirth (`03-progression.md § Rebirth`) moves out of the
slice and v1.0 entirely, to Season 2 or later.

**Why:** D70 made rebirth prestige-only, which means it now resets a
player's progress in exchange for looks alone. That's a much weaker
value proposition than the original multiplier version, and it isn't
worth building until the base game has enough cosmetic depth to make
the trade genuinely appealing.

**Rejected:** keeping it in the slice/v1.0 as originally scheduled.

## D87 — Mobs never trigger permanent structure destruction `[LOCKED]`
**Decision:** at vault tiers 8–10, mob raids (D29) can knock a structure
offline but never trigger D23's permanent destruction.

**Why:** permanent loss should be a price paid to a player who
outplayed you, not to an NPC encounter.

**Amends:** D23, D29.

## D88 — Free Greenhouse raid guardrails `[LOCKED]`
**Decision:** free Greenhouse raids (D71) get a per-target cooldown [PH]
and a daily cap per raider [PH], in addition to the existing
matchmaking band and 48-hour shield.

**Why:** a raid with no Breach Charge cost needs some other brake, since
R6 depends on raid cost making low-value targets unprofitable.

**Amends:** D71.

## D89 — Robux-pool swaps happen in the direct trade window `[LOCKED]`
**Decision:** D65's same-tier Robux cosmetic swaps take place in the
direct player-to-player trade window, not as Exchange listings.

**Why:** the Exchange is fixed-price listings (D61); a swap is
item-for-item and doesn't fit that shape. The trade window already
exists and can visibly separate the two pools.

**Amends:** D61, D65.

## D90 — Crew Vault permissions `[LOCKED]`
**Decision:** the crew leader has full access (deposit, withdraw,
invite, disband). Members deposit freely but withdraw only up to a
daily cap [PH].

**Rejected:** all-members-equal access (no brake on a member emptying
the Vault); leader-full/members-deposit-only (too restrictive for a
2–4 person crew that's supposed to feel cooperative).

**Amends:** D49.

## D91 — Crew disband splits by contribution `[LOCKED]`
**Decision:** each member reclaims exactly what they personally
deposited (tracked per-member). Any remainder splits equally.

**Why:** keeps R2's "nothing lost" spirit for crew play, and avoids
rewarding whoever happens to be leader at disband time.

**Rejected:** splitting everything equally regardless of who deposited
what; the leader keeping the remainder.

**Amends:** D49.

## D92 — Gear score formula `[LOCKED]`
**Decision:** `pickaxe tier index × 10, plus 1 point per purchased
Tech Path upgrade node across all three branches` [PH — coefficients to
be tuned]. Used only for the D66 matchmaking band, never exposed to
players as a number, never affecting actual combat power.

**Why:** both inputs are already tracked server-side; no new state
needed to compute it.

## D93 — The pattern roll renamed "Pattern" (resolves Q70) `[LOCKED]`
**Decision:** the 1–1000 collector roll on gear and cosmetics
(formerly "Seed," D10) is renamed **Pattern**. "Seed" now refers only
to crop seeds (D73).

**Why:** a young player seeing "Seed 661" next to "Dense Seed pack"
would reasonably assume they're related. Comprehension (rubric #1)
outweighs preserving the CS-fidelity term; the collector community will
name notable patterns themselves regardless of the field's label.

**Rejected:** renaming crop seeds instead (e.g. Sprouts) — keeps "Seed"
for the roll, but "Seed" is also the more natural farming word (Grow a
Garden's own term), so the roll was the better one to rename.

**Amends:** D10. **Resolves:** Q70.

## D94 — NPC buy price diminishes per sale, resets daily `[LOCKED]`
**Decision:** the NPC flat-price buyer's price per unit now decreases
with each sale to that NPC within a day, resetting at the day boundary.

**Why:** a flat price with no cap was an unlimited Credits faucet —
identified as the single biggest inflation risk in the doc set.

**Rejected:** status quo (flat price, no decay).

**Amends:** `06-economy.md § Two tiers of selling`.

## D95 — Rare-seed vendor added `[LOCKED]`
**Decision:** a small 5-minute rotating stock of rare seeds, purchasable
with Credits. Common seeds stay free to forage (D73).

**Why:** D73's foraging-first model removed what would have been the
largest natural Credits sink; this restores a sink without reversing
D73's intent.

**Amends:** D73.

## D96 — Bounties added, with guardrails `[LOCKED]`
**Decision:** a player can post a Credits bounty on a raider who hit
them, visible only within that raider's matchmaking band, capped,
expiring in 24 hours, one active per target, poster anonymous, taxed on
posting.

**Why:** creator-friendly content and a Credits sink, but band-limiting
and capping prevent it from becoming a tool for a mob to dogpile one
player — a real risk given the young audience.

**Rejected:** server-wide visibility with no band limit (dogpile risk);
no cap (a large bounty could itself become a farming incentive against
a specific player).

## D97 — Trade-up contracts added `[LOCKED]`
**Decision:** ten same-tier cosmetics consume into one random
next-tier cosmetic. Earned pool only.

**Why:** a genuine Credits-free sink that makes retired case series
(D31) scarcer over time even with no active selling — authentically
CS-style.

**Rejected:** allowing Robux-pool items into trade-ups (would leak
Robux value through the random outcome, undermining D65).

## D98 — Value-threshold trade holds added `[LOCKED]`
**Decision:** items above a value threshold [PH] carry a short trade
hold (a few hours at most) before they can be re-traded. Below the
threshold, trading stays instant.

**Why:** targets rapid high-value flipping (rubric #11) without adding
friction to ordinary trading.

**Rejected:** a universal hold on all trades (unnecessary friction for
low-stakes trading).

## D99 — Name Tags built from a word bank only `[LOCKED]`
**Decision:** the Credits-purchasable Name Tag cosmetic uses a preset
word bank with no free-text entry.

**Why:** chat is off by default under age 9; a free-text field carries
the same moderation risk chat does, and a filter will eventually miss
something a closed word bank simply can't produce.

**Rejected:** free text with a profanity filter.

## D100 — Pets added, cosmetic-only, Season 2 `[LOCKED]`
**Decision:** Boss Pets (ultra-rare Mythic drop), Case pets, and
Tripwire Alarm pet skins. No boosters, no multipliers, no stat effects,
ever.

**Why:** the standard Roblox booster-pet model is a paid random item
(R7) whose luck effects would need numerically disclosed odds
(conflicting with D46), and multipliers would widen the exact gap D45
exists to prevent. The cosmetic-only version gets the flex and
creator-content value without any of that.

**Rejected:** Robux egg pets; Credits eggs with yield multipliers.

## D101 — Raid escort added to the vertical slice `[LOCKED]`
**Decision:** a friend can body-block interceptors during a solo
raider's Chase, without being able to carry or grab loot themselves.
Ships in the slice.

**Why:** cheap, and gives early friend play something to do together
without reopening D4's crew-raid tier gate.

## D102 — Resonance nodes added, bonus-only `[LOCKED]`
**Decision:** nodes that give a Grade-odds boost when two players mine
them simultaneously — never required, always minable solo at normal
odds. Scope: v1.0.

**Why:** gives friends a reason to mine together without creating a
wall solo players hit.

**Rejected:** making any node require two players (excludes solo play).

## D103 — NPC contracts and Collection Log added `[LOCKED]`
**Decision:** named Exchange NPCs offer daily/weekly Credits-and-
Reputation contracts; a personal Collection Log tracks every distinct
cosmetic, Pattern, Boss Pet, and drop-only item ever found. Scope: v1.0.

**Why:** both reuse data and pipelines the game already has (existing
resources, existing NPC-sale mechanics minus the D69 Scrap faucet,
existing drop tracking), making them a cheap long-session investment.

## D104 — Provenance tags added, name opt-in `[LOCKED]`
**Decision:** drops/Cases/crafts carry a provenance tag showing method
and season. The original owner's name is opt-in and off by default.

**Why:** showing a kid's name by default on an item that gets traded to
a stranger is a real social-safety risk; opt-in keeps the flex value for
players who want it without the default exposure.

**Rejected:** name shown by default (the original ask).

## D105 — Raid log gets a path-line map `[LOCKED]`
**Decision:** the raid log includes a path-line map of the raider's
route and where they triggered defenses. Not a full replay.

**Why:** cheap to render, gives the victim something concrete, and is
inherently shareable/streamable content.

**Rejected:** full raid replays (too costly for the value added).

## D106 — Community Beacon added, Season 2 `[LOCKED]`
**Decision:** the server pools Credits toward a threshold that triggers
a Riftfall or Ion Storm early.

**Why:** a Credits sink that scales with server population rather than
individual wealth, and a genuine streamer/community moment.

---

# ROUND 6 — v5.5 slice lock

## D107 — Vertical slice scope is final (resolves Q23) `[LOCKED]`
**Decision:** the slice is exactly the `10-roadmap.md § Vertical Slice`
in-scope table, which now also includes raid escort (D101) and a minimal
Vaultbreaker Level + Reputation (required because D82 gates direct
trading, and direct trading is in the slice).

**Why:** every open item Q23 was waiting on has since been decided
(Crew Vault permissions — D90/D91; gear score — D92; placeholders —
D109). The engineering estimate becomes build step 0, not a design gate:
if it runs over, cut from the bottom of the build order rather than
reopening design.

**Clarification:** the Scav Captain is solo base-wave content, so its
loot goes to the defending base owner. Q33/Q34 stay parked and only
matter for Reaches-tier bosses (v1.0).

**Rejected:** moving Workshop II + Fragments into the slice (Fragments
come from Reaches-tier and higher bosses, none of which are in the
slice); waiting on an estimate before locking scope.

**Amends:** D53.

## D108 — Slice-system sections locked `[LOCKED]`
**Decision:** these sections move from `[PROPOSED]` to locked, with any
numbers inside them staying `[PH]`: Session Structure, Pickaxe upgrade
tree, Combat feel, Gadgets, Theft math (structure), Defenses (principle
and list) — `02-core-loop`; Tech Path Structure, Branches, Crews split
the tree — `03-progression`; PvE Ladder (direction), Loot table
structure, Scav Waves — `04-world-content`; Success criteria and Build
Order — `10-roadmap`. Also resolves Q48: the full tree is visible before
nodes are affordable.

**Why:** every one of these is built in the slice. Code can't start on
a system whose shape can still change.

**Not locked (not in the slice):** Ally Pass, Experiment, Blueprint
Mastery, Ranked Ladder & Seasons, Bosses are PvP bait, World Caches,
Dynamic Events, Riftshard, Signal decay, Environmental modifiers, market
manipulation defenses, Launch Scope, Season Plan.

## D109 — Starting values for slice placeholders `[LOCKED]`
**Decision:** crew tenure lockout starts at **24 hours**; Tech Path
respec refund starts at **50%**. Both remain `[PH]` and tune from
playtest data.

**Why:** these were the last two numbers flagged as needed "before
build." A starting value in code is all the slice needs.

**Rejected:** "since season start" for tenure (seasons aren't in the
slice).

---

## D110 — The slice ships one craftable Harvester Drone `[LOCKED]`
**Decision:** offline production in the vertical slice comes from a
single craftable Harvester Drone. The Robux gamepass drone and any
further automation stay out of the slice.

**Why:** the build order included offline production while the slice's
out-of-scope list excluded "Automation," and the docs deliver offline
production through drones. Offline production is mandatory
(`02-core-loop.md § Automation`) and is the D1 pull-back hook — exactly
what the slice exists to measure.

**Rejected:** a passive trickle with no drones (a new mechanic that
doesn't exist in the design); cutting offline production from the slice
(would test D1 without its main return hook).

**Amends:** D107.

---

# NON-NEGOTIABLES — rationale

## R1 — Identity is never lootable
Players tolerate losing stuff; they quit over losing identity. Break this
once and the retention curve never recovers. **Holds even at elite raid
tiers (D23) — only base structures can be destroyed there, never
cosmetics or equipped gear.**

## R2 — Nothing permanently destroyed, except at the top (D23)
The punishment for being raided must be time and momentum, not erasure —
for the vast majority of players, at the vast majority of vault tiers.
Tiers 8–10 are now a deliberate, narrow exception (D23): high-tier
players opted into higher stakes by climbing, and the ceiling of the
game needed real consequence to feel earned.

## R3 — Money buys convenience and looks, never power or safety
Steal a Brainrot is publicly criticized for pay-to-win, with the best
items available only for cash and purchasable server-admin abilities.
This is the differentiator. **Remains fully intact even though gear and
Fragments are now tradeable (D21, D22) — Robux still never buys Credits,
gear, or Fragments directly; only cosmetics and convenience.** The
indirect route (Robux cosmetic → Credits) is closed by D65; the rebirth
skip token is cut by D70.

## R4 — Depth invisible in the first ten minutes
Criterion #1 is weighted heaviest in the rubric. Most Roblox games lose
over half their players before Day 2, and the #1 churn cause is poor
FTUE. **This constraint gets harder to hold as the richer vertical slice
(D53) adds Workshop I, Tech Path, and Crews earlier in the build — every
one of those systems must still stay invisible in session one.**

## R5 — Server is the only authority
Steal a Brainrot's cheater problem is documented — automation scripts for
cash collection and stealing. A theft economy is an exploit magnet and
the community will find every hole within days of launch.

## R6 — New players cannot be farmed
The single most common way raid games die in month one: new players get
farmed, churn, and the game strangles its own funnel. Enforced three
ways — band matchmaking (highest of tier, lifetime peak, or gear score —
D66), a 48-hour shield no event can remove (D67), and Breach Charge cost
making low-value targets structurally unprofitable.

## R7 — No randomness behind real money
See D15, D30, D65.

## R8 — Consumables never boost combat damage
A buffed veteran out-earning a newcomer is progression. A buffed veteran
one-shotting them in a chase is churn.

---

# THINGS CONSIDERED AND CUT `[CUT]`

| Cut | Why |
|---|---|
| **Hunger / food requirement** | Punishment mechanic; wrong audience (D17) |
| **Nine-resource tier ladder** | No decisions; one ladder in nine costumes (D14) |
| **Menu-selected classes** | Tech Path does it better and emergently (D11) |
| **Inventory-based research** | Physical Workshop is better (D12) |
| **Robux-purchasable keys** | Regulatory risk + audience age (D15) |
| **Rust-style decay / upkeep** | Punishing players for not logging in is correct for Rust, catastrophic here |
| **Structure destruction in raids (tiers 1–7)** | Crosses the identity line (D5); allowed only at elite tiers 8–10 (D23) |
| **Firearms** | Mobile aiming; moderation and age-rating surface |
| **Condition affecting stats** | Pay-to-win-by-luck (D10) |
| **Permanent leaderboards** | One whale owns #1 forever; everyone else disengages |
| **Cosmetic-and-resources-only trading** | Superseded — gear and Fragments now tradeable (D21, D22) |
| **Untradeable Riftsalt** | Superseded — now tradeable, creates an arms-supplier role (D20) |
| **Unrestricted instant Tech Path sharing in crews** | Exploitable via join-then-leave (D25's lockout fixes this) |
| **Server-unique Prototype recipes** | Too harsh, first-mover lock-out; capped-per-player instead (D34) |
| **Uniform blueprint durability at all tiers** | Flattens the design; tiered/inverted durability serves both audiences (D33) |
| **Automated Workshop rental** | Loses the trust/social interaction that's the point (D24) |
| **A minimal vertical slice** | Superseded by the richer slice (D53) once core systems were judged cheap relative to payoff |
| **Rebirth multipliers** | Power, and enabled smurfing via the vault-tier reset (D70) |
| **Robux rebirth skip token** | Buying progress (D70) |
| **Selling Robux-bought cosmetics for Credits** | Indirect Robux → Credits → Keys route (D65) |
| **Scrap from NPC sales** | Indirect Credits → Scrap route (D69) |
| **Full Tech Path wipe every season** | Superseded by staggered tier resets (D72) |
