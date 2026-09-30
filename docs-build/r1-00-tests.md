# R1-00 movement trust: remaining Studio tests

## Where we are (2026-09-29)

**Passed:** A, B, C2 and E (except E3), on 625a512.

**Changed since** (so these need re-running):
- `Push 3` (0635dce, committed): saved-up catch-up distance now follows
  real ping, so a blink of more than ~12 studs fails at low ping. It also
  adds a new C script, new D steps and Studio `[WallDebug]` lines.
- **Uncommitted** ultrareview fixes, on disk: the Breach shield warning
  now lasts 10 s (the server's window), and the Credits row start-up
  backup now knows "has sold to NPC". The escape ground-check nit is in
  backlog.md.

**Still to run, in this order:**
1. **W. Can you jump a Base Wall?** (below). Decides whether D1's result
   is fine.
2. **C** with the new script (not reported yet).
3. **D1 on a Vault Core** (last run hit a Base Wall instead: 8-stud blink,
   `[WallDebug] … Wall.Hitbox: low enough to jump`), then **D2**.
4. **E3** (new start distance: 15–30 studs, standing still).
5. **R. Review fixes** (below).
6. **F**, then **I**.

When all pass, tell Claude: it commits everything and ticks R1-00 in
REWORK.md §14. G and H stay in the backlog.

## 0. Setup (every time)
1. `rojo serve` running; Studio Plugins tab → Rojo says **Connected**.
2. Output open, search box empty, filter showing Client **and** Server.
3. Play, mine one node: you must see `[MineDebug] <name>: mined …`. If
   not, Studio runs old code: reconnect Rojo.

Messages (Studio only): `[Movement]` = a move was caught; `[MovementTrust]`
= an action refused, with why; `[MineDebug]` = what the server did with a
mine click; `[ClickDebug]` = what the client did with a left click.

Cheat lines: Play (1 player): Test tab → switch **Current: Server** to
**Current: Client**, then View → Command Bar. Clients and Servers: click
into the **Player1**/**Player2** window and use its Command Bar, never the
Server window. After using the Command Bar, click empty ground once before
clicking a node (the Command Bar can keep the click).

## B. Teleport and mine (Play, 1 player)
Stand away from nodes, run:
`local n=workspace.Nodes:GetChildren()[1] game.Players.LocalPlayer.Character:PivotTo(n:GetPivot()+Vector3.new(5,2,0)) game.ReplicatedStorage.Remotes.MineNode:FireServer(n)`
Expect: snapped back, no resources, `[Movement] … teleported`.

## C. Flying
`task.spawn(function() local r=game.Players.LocalPlayer.Character.HumanoidRootPart for i=1,60 do r.AssemblyLinearVelocity=Vector3.zero r.CFrame+=Vector3.new(0,1,0) task.wait(0.03) end end)`
Expect: pulled down, `rose higher than a jump`. (The old script didn't
clear your fall speed, so gravity cancelled it after ~3 studs.)

## C2. Teleport up onto a ledge
Next to a high ledge or tall rock:
`local c=game.Players.LocalPlayer.Character c:PivotTo(c:GetPivot()+Vector3.new(3,25,0))`
Expect: snapped back, `rose higher than a jump` (may say `landed`).

## D. Through things
Only fixed world/base parts wider than ~6 studs and taller than a jump
count as walls. Passing these is **expected** (a `[WallDebug]` line says
why): tree trunks (thin, could go around), Base Walls/Gates (6 tall,
jumpable), nodes (not walls). A 6-stud teleport into a Vault Core only
puts you inside it; Roblox pushes you out.
1. Stand against a Vault Core's side, facing it:
   `local c=game.Players.LocalPlayer.Character c:PivotTo(c:GetPivot()*CFrame.new(0,0,-11))`
   Expect: snapped back on your side, `moved faster than possible` or
   `walked through a wall`.
2. Any teleport of 12+ studs, through anything or nothing:
   `local c=game.Players.LocalPlayer.Character c:PivotTo(c:GetPivot()*CFrame.new(0,0,-14))`
   Expect: snapped back, `moved faster than possible`.
3. If you get through something and there's no `[Movement]` line, send
   the `[WallDebug]` line (it names what you passed and why it allowed it).

## W. Base Wall jump check (Play, 1 player)
Walk up to one of your Base Walls and try to jump over it normally, a few
times. Can get over = D1 on a Base Wall is fine (the server treats it as
jumpable). Can't = tell Claude; the "jumpable" height needs tightening.

## E. Raid (Clients and Servers, 2 players; P1 raider, P2 owner)
1. P1 window: press 5 (Breach Charges) and 9 (lockpicks). P2 shielded:
   press - in P2's window.
2. P1 breaches P2's base.
3. P1 15–30 studs from P2's core, standing still, in P1's window:
   `local p2=game.Players:FindFirstChild("Player2") local v for _,m in game:GetService("CollectionService"):GetTagged("VaultCore") do if m:GetAttribute("OwnerUserId")==p2.UserId then v=m end end game.Players.LocalPlayer.Character:PivotTo(v:GetPivot()+Vector3.new(4,2,0))`
   then lockpick at once. Expect: snapped back, "Get closer".
4. P1 walks to the core, lockpicks, grabs.
5. P1: `local c=game.Players.LocalPlayer.Character c:PivotTo(c:GetPivot()*CFrame.new(0,0,-150))`
   Expect: snapped back, no escape, chase continues.
6. P2 walks up to P1 and swings. Expect: hit lands, grip drops.
7. P2 ~30 studs away, in P2's window:
   `local t=workspace:FindFirstChild("Player1") local c=game.Players.LocalPlayer.Character c:PivotTo(t:GetPivot()*CFrame.new(0,0,3))`
   then swing at once. Expect: swing plays, no hit, no grip lost.
8. P1 walks out 140 studs onto solid ground. Expect: escape works.

## R. Ultrareview fixes
Shield warning (Clients and Servers, 2 players):
1. P1's window: press `-` (P1 shielded).
2. P1 walks to P2's base, taps **Breach** once. Expect: button turns
   warn-coloured, "Confirm: ends shield".
3. Don't tap. Expect: it stays ~10 s, then back to "Breach".
4. Tap Breach after it reverted. Expect: the warning again, no raid.

Credits row (Play, 1 player):
1. Sell something to the NPC buyer. Expect: the Credits row appears.
2. Stop, Play again. Expect: the Credits row is there right after joining.
   (This only checks the normal case still works. The actual bug was a
   start-up timing race you can't easily trigger on purpose.)

## F. Normal play never trips it (no `[Movement]`/`[MovementTrust]` lines)
1. Mine and walk ~5 min. 2. Sprint Serum (J for gadgets). 3. Jump onto a
node and off. 4. Stand at a ledge edge, walk off. 5. Slopes, steps, kerbs.
6. Die and respawn. 7. Two players: full combo with finisher; hit while
carrying; Shock Trap stun; stand on the other player's head. 8. Full
lockpick.

## I. UI fix
Play: Raids/Bag/Trade/Gear/Debug sit just under the vault panel, Credits
row fully visible. Shorter window + Device Emulator phone: still below it.

## Later (in backlog)
- G: Studio Settings → Network → Incoming Replication Lag 0.3, repeat F1,
  F2, F5, F7; nothing rubber-bands; set back to 0.
- H: publish, private server, phone + second device, full raid + mining;
  note any pull-back without cheating.

If something fails: letter + step, and the `[Movement]`, `[MovementTrust]`,
`[MineDebug]`, `[ClickDebug]` lines.
