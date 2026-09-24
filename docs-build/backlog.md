# Build backlog

Engineering follow-ups found during the build that aren't design questions.
Design questions go in `design-changes.md`. Remove an entry when it's done.

## From the step 2 review (2026-09-20)

- **M1: movement / position trust. Do in step 7 at the latest.** Each
  player's client controls their own character position, so an exploiter can
  teleport next to any node and pass NodeService's distance check
  (`src/server/Services/NodeService.luau`, distance check in
  `onMineRequest`). The mine cooldown still caps income; the hole is
  *where* they can mine (and later: raids, the Chase, escaping). Fix: a
  server-side movement check (max speed / teleport detection) that other
  services can ask "is this player's position trustworthy?".
  `13-build-guide.md § Anti-exploit baseline`; `10-roadmap.md § Known Risks #1`.
- **L2: client look numbers are `[PH] invented`. Revisit with real art/UI.**
  Moved into Config and tagged "REVISIT (step 2 review L2)":
  `Config.Nodes.PickRangeStuds`, `.WalkCloserHintSeconds`,
  `Config.Grade.FxLook` (particles, light, beam), `Config.Broadcast.BannerColors`
  / `.DefaultBannerColor`, `Config.Bank.HudStartupTries` / `.HudStartupRetrySeconds`,
  `Config.Bank.Meter` look values (Width, BarHeight, colours).
- **L3: Terrain and line of sight.** NodeService's line-of-sight ray only
  checks `Workspace.World`. If Terrain is ever used, add
  `workspace.Terrain` to `losParams.FilterDescendantsInstances`.

## From step 3 (2026-09-20)

- **FTUE (step 14):** set `Config.Bank.Meter.ShowBeforeFtue = false` and call
  `VaultService.setMeterVisible(player, true)` at 2:30. The "Bank" prompt
  label is text; check it against FTUE hard rule 1 (no text before 2:30).

## From step 4 (2026-09-21)

- **Offline bases → step 7.** Plots and pieces exist only while their owner
  is on the server (PlotService spawns on join, clears on leave). Offline
  raids need the victim's base built from their saved `Base.Pieces` on the
  raider's server (13-build-guide.md § Part D pattern). Also, a player joining
  a full server (more players than `Config.Plots.Count`) gets no plot: set the
  place's Max Players to 8 until real sharding exists.
- **Budget numbers wait on the cheap-phone test** (step 0 still not fully
  met). `Config.Base.Pieces[*].BudgetCost` and `.BudgetByTier` are render
  weight [PH]; set them from real triangle/material numbers once measured.
- **FTUE (step 14):** `Config.Base.BuildUi.ShowBeforeFtue = false`, show the
  Build button via `PlotService.setBuildUiVisible` at 0:45 ("BUILD VAULT").
  Build-mode messages are text; check against FTUE hard rule 1.

## From step 5 (2026-09-21)

- **L4 (NodeInput tap ray) is fixed** in step 5.
- **Step 6 hooks:** Scavs must be Models tagged `Config.Combat.CombatTag`
  with a Humanoid + HumanoidRootPart, so swings, aim assist and Shock Traps
  hit them. The Disruptor is refused ("NoDefense", not consumed) until
  defenses exist: wire it in GadgetService. Silent movement (Mobility) should
  lower Tripwire detection.
- **Step 7 hooks:** set the Player attribute `Config.Gadgets.CarryingLootAttribute`
  while carrying loot (gadgets already refuse). Loot slow and Carry speed go
  through `MovementService.setMultiplier`. "Any player who lands a hit knocks
  the loot loose" = listen to `CombatService.Hit`. M1 movement check lives in
  MovementService. (Sprint recovery became Stun recovery, 2026-09-21: built.)
- **Step 10:** Workshop I crafts the Iron pickaxe (`PickaxeService.setTier`),
  armor (`ArmorService.grant`) and gadgets (`InventoryService.add`). Until then
  only Studio keys K / U / J give them.
- **Step 14:** `Config.Combat.Ui.ShowBeforeFtue = false` (Gear button); set the
  `PvpProtected` attribute until the player's first Scav kill (FTUE rule 3).
- **L5: pickaxe grip.** The greybox Tool uses the classic-sword grip
  (`CombatService.buildTool`). If the pickaxe looks sideways in the hand,
  adjust GripForward/Right/Up there. Look only.

## From step 6 (2026-09-21)

- **Wall corners don't join (found while testing step 4).** Walls sit in the
  middle of their grid cell, so two rotated walls leave a ~1.5-stud gap at a
  corner that a player could squeeze through (walls are meant to funnel
  raiders). Suggested fix: snap walls/gates to cell edges in `PlotGrid`.
  Waiting for Josh's go-ahead; must be settled before step 7 raiding.
- **Scavs don't animate** (greybox): server NPCs made with
  `CreateHumanoidModelFromDescription` glide without walk/swing animations.
  Add a server-side animation script with real art.
- **Scav pathing is straight-line + hop.** A Scav walks straight at its goal
  and hops over whatever stops it for `Config.Scavs.StuckSeconds`. Fine for
  greybox; PathfindingService would look smarter (still must never block).
- **Step 7 hooks: done** (RaidingAttribute, useLockUpgrades). The Decoy
  Vault only distracts Scavs; it doesn't waste a raider's time yet (it's a
  physical decoy: a raider can simply ignore it). Design question if it
  should do more.
- **Step 9:** Scav Wave success should grant Reputation (logged for now).
- **Step 10:** Captain Rare = Research Scrap is a TEMPORARY stand-in
  (`Config.ScavWaves.CaptainRareScrap`); swap it for Common blueprints.
  (Signature is now the real Captain's Cleaver skin, 2026-09-22.)
- **Step 14:** waves start once a Vault Core exists; the FTUE's scripted
  1:00 Scav (02 § FTUE spec) is separate and should not trigger the timer
  early.
- **D64 threat strip:** base alerts use a simple banner (`BaseAlerts.client`);
  the priority strip is due when raids add more alerts (step 7).

## Pickaxe skins (2026-09-22)

- **Art-ready pass done (2026-09-22):** see `docs-build/art-guide.md`.
  Still to do, as their own passes: **effects** (Grade bursts/beams, hit
  flash, zaps, smoke) and **UI** templates before step 14; Scav animations.
- **Rule for new gameplay objects from now on:** add them to `gen_world.py`
  with `template(...)` (Hitbox + Visual) and to the art guide's table.
- **Step 9:** direct trading must move skin counts (`Cosmetics.PickaxeSkins`)
  between players; never let a raid touch them (R1).
- **Step 14:** the FTUE's free cosmetic can be a skin via
  `CosmeticService.grantSkin`.

## From the raid review workflow (2026-09-22)

Prompt R as a workflow: 3 parallel reviewers (duplication, client trust,
rules + layout) and 1 skeptic that tried to refute each finding.

**Fixed (uncommitted until Josh's Studio test):**
- **#6/#8 Chase skipped by teleport/speed hacks.** Raid participants now
  have a distance budget at their real server WalkSpeed (carry slow
  included), and a carrier's position is checked (`MovementService.checkNow`)
  right before every escape check. Knockback grants allowance
  (`expectPush`). Simulated: honest carriers with 0.6 s lag bursts or a
  finisher hit are never snapped back; 14 and 50 studs/s hacks are pinned.
- **#7 escort + breach overlap.** JoinEscort is refused while your own
  breach is starting; breach re-checks `raidOf` after its waits;
  `releaseParticipant` only clears a player still in THAT raid.
- **#1 login during an offline raid.** The raid wait now runs BEFORE the
  save loads, and again after; if a raid slipped in during the load, the
  profile saves once (pulling the theft message) before the message
  handler, so the theft applies before the player can act.
- **#2 raid lock lapsing mid-raid.** Lock renewed right before the raid
  starts and for the whole raid (`keepLockAlive`); escape re-checks it
  before sending the theft and fails the raid if it's gone.
- **#12** lock acquire is safe to retry. **#9** a same-frame release still
  springs the lock back. **#10** lockpick feel values are rounded
  (`FeelAngleStep`, `FeelClosenessStep`). **#13** flagged numbers moved to
  Config (`CarrierMark`, `BreachRecheckRange`, `Lock.ReleasedTtlSeconds`,
  raid UI timings).

**Deferred:**
- **#4 (Medium): server shutdown mid-Chase loses a leaving victim's loot.**
  `victimLeft` debits their save, and the RaidReturn message can't be sent
  once ProfileStore is closing. Fix idea: keep the taken loot as a "held"
  record in the victim's own save (same write as the debit), cleared by
  escape, refunded on their next login otherwise.
- **#3 (Low): a raider who quits during the 1-2 s offline payout loses their
  80%.** Fix idea: send the credit as a `RaidPayout` message (deduped by
  raid id) when they aren't loaded.
- **#5 (Low): a server up 7+ days can raid a stale save once "pending"
  expires.** Fix idea: stop showing an offline base when its RecentlyOffline
  entry expires, or re-check the pending key's age.
- **Carrier marker on the client:** draw the Highlight/label/trail from the
  CarryingLoot attribute in a client script (CLAUDE.md: visuals are
  client-side); the server keeps only the attribute.
- **Vertical movement isn't checked** (flying). Escape already needs solid
  ground; a rise check would also stop flying over walls.

## From step 7 (2026-09-22)

- **M1 movement check: done** (MovementService). Logs impossible moves for
  everyone; snaps back raid participants only. Numbers in
  `Config.Raiding.Movement` are [PH]; watch the logs for false positives.
- **Can't be tested in Studio, test on a live private server** (two devices
  or a friend): victim rejoins mid-raid; two raiders on different servers
  hit the same offline base; MemoryStore/DataStore failure paths.
- **Residual risk (low):** if MemoryStore fails to mark a finished offline
  raid "pending" after the theft message was sent, the raid lock expires in
  150 s and a second offline raid could read the old save. Needs a
  MemoryStore write failure right after a DataStore success.
- **Step 10:** Workshop I becomes a tier 5-7 **sabotage target** (D23;
  `RaidService.sabotage` only targets defenses today). Consistency report #46.
- **Step 10:** Workshop I crafts **lockpicks** from Ore
  (`Config.Raiding.Lockpick.ItemId`, item "Lockpick"); Studio key 9 grants
  them until then.
- The raid log map shows path dots + defense trigger markers; greybox.
- **Step 14:** the "your plot" marker (`PlotMarker.client`) follows the
  Build UI attribute; the FTUE's 0:45 BUILD VAULT beat should turn both on.
  Its beam/arrow are code-made look stand-ins: include them in the effects
  pass (Config.Base.BuildUi.PlotMarker, REVISIT).
- **Launch:** credit the CC-BY pickaxe model in the game description or a
  credits screen (`docs-build/credits.md`).

## From step 8 (2026-09-23)

- **Built:** `RaidService.checkBreach` / `consumeBreach`, RaidProtectionService
  (band, 48-h + 30-min shields, `dropAllShields` honouring
  `ExemptFromDropAll`), CraftingService (Breach Charges), band-matched
  offline bases.
- **Breach Charges aren't stealable yet** (05 § Taxonomy says they are, like
  gadgets). Needs a Banked/Exposed split for Items first. Design + build later.
- **Step 9:** direct trade must move Riftsalt and Breach Charges (both
  tradeable, D20); the band never shows as a number (D92).
- **Step 10:** Workshop I recipes go in `CraftingService.recipes` (lockpicks,
  gadgets, Iron gear); decide whether Breach Charges then need the Workshop.
- **Step 14:** the FTUE's guided NPC vault raid (4:00) must not need a
  Breach Charge or end the 48-h shield. `RaidProtectionService.forfeit` is
  for real players' bases only.
- **Blackout (post-slice):** call `RaidProtectionService.dropAllShields`;
  any new shield kind needs its own `ExemptFromDropAll` in Config.
- **Live-server test:** 48-h shield on a truly new account (the phone), and
  an offline raid followed by the victim's login (30-min shield starts).
- **Step 8 review workflow (2026-09-23):** 3 reviewers + 1 skeptic, 7
  findings. Confirmed and fixed: two rate-limit numbers missing their [PH]
  tag. Confirmed, then approved by Josh: the escort band check (design-changes.md
  step 8 item 7). Refuted: forfeit / post-raid shield writes can't fail
  alone (the handler's writes succeed or fail together); the confirm window
  carrying over to another target is intended (it's consent to lose your own
  shield); the Studio clock skip is server-wide on purpose; the Craft row fits
  the Bag.
