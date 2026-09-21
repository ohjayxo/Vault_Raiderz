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
  / `.DefaultBannerColor`, `Config.Bank.HudStartupTries` / `.HudStartupRetrySeconds`.
- **L3: Terrain and line of sight.** NodeService's line-of-sight ray only
  checks `Workspace.World`. If Terrain is ever used, add
  `workspace.Terrain` to `losParams.FilterDescendantsInstances`.
