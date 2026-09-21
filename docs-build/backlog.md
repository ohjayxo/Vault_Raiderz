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
  MovementService. Sprint recovery needs a sprint to exist (not in the docs
  yet: design question when step 7 arrives).
- **Step 10:** Workshop I crafts the Iron pickaxe (`PickaxeService.setTier`),
  armor (`ArmorService.grant`) and gadgets (`InventoryService.add`). Until then
  only Studio keys K / U / J give them.
- **Step 14:** `Config.Combat.Ui.ShowBeforeFtue = false` (Gear button); set the
  `PvpProtected` attribute until the player's first Scav kill (FTUE rule 3).
- **L5: pickaxe grip.** The greybox Tool uses the classic-sword grip
  (`CombatService.buildTool`). If the pickaxe looks sideways in the hand,
  adjust GripForward/Right/Up there. Look only.
