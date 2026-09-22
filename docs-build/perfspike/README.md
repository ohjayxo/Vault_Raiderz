# Perf spike (build step 0B): how to run it

**Throwaway.** Tests whether a phone can draw your base + 8 neighbors inside the
render budget in `docs/09-research.md § Rendering & Mobile Performance Budget`
(~1,000 draw calls, ~1,000,000 triangles). Delete it all when you have the
numbers (checklist at the bottom).

## Read this first: your phone is a flagship

`docs/13-build-guide.md § Step 0` asks for a **real, cheap phone**. An iPhone 14
Pro Max is one of the fastest phones there is. So:

- If it **fails** a preset, a cheap phone certainly does. That result is solid.
- If it **passes**, that tells you very little about the phones most of your
  audience has. Treat it as a best case, not a pass.
- Step 0's checklist item ("tested on a real, cheap phone") is **not met** by
  this device alone. Before step 4, repeat on an older/cheaper phone (an old
  iPhone SE/8, or a budget Android). Borrowing one for 30 minutes is enough.

## What the scene is

- **Your base in the middle of a 3×3 grid of floating islands**, 8 neighbors.
- **Stand-in "mid-tier base"** (my assumption; no doc gives piece counts):
  28 pieces and **25,100 triangles**: island 5,000 · Vault Core 4,000 ·
  12 walls × 500 · 2 gates × 1,000 · 3 defenses × 800 · workshop 2,500 ·
  8 decor × 400. No piece is over 5,000 triangles (the doc's hard cap is ~20,000).
- **12 resource nodes** (300 triangles each) with 2 built-in particle emitters
  each (~700 live particles), and **4 default R15 NPCs** wandering.
- Everything is tagged `PerfSpikeBase` / `PerfSpikeNode` / `PerfSpikeNpc`, each
  a Model with a `Hitbox` and a `Visual` folder, so real systems never pick it up.

## Step 1: import the meshes (once, in Studio, ~10 minutes)

The 8 files are already generated in `docs-build/perfspike/meshes/`
(`python3 docs-build/perfspike/gen_meshes.py` regenerates them and checks every
triangle count).

1. Open your Vault Raiderz place in Studio.
2. **Explorer** → hover **ServerStorage** → click **+** → **Folder**. Name it
   exactly **`PerfSpikeKit`**.
3. **Home** tab → **Import 3D** (if you can't find it: **View → Asset Manager**
   → **Bulk Import**). Select all 8 `spike_*.obj` files.
4. Leave the defaults and click **Import**. Studio uploads them (free) and the
   results appear as models in the Workspace.
5. Drag **every imported model** into **ServerStorage → PerfSpikeKit**.
   Workspace should end up with none of them. The names come from the
   files (`spike_wall` etc.); **don't rename them**: the code finds pieces by name.
6. **Save** (Cmd+S). The meshes live in your place file, not in git.

Nothing to copy or paste: no asset IDs. If any step doesn't match what you
see, tell me what's on screen.

## Step 2: run it in Studio (desktop) first

1. Terminal 1: `cd ~/vaultbreakers && rojo serve`. Studio: Rojo plugin → **Connect**.
2. Press **Play**. Open **Output**. You should see:

   `[PerfSpike] preset Solo: 1 bases, 40 art parts, 0 emitters, 28700 triangles (kit: Imported)`

   - `kit: Primitives` or `Partial` → the meshes weren't found; the scene still
     builds with plain blocks but the triangle numbers are **not valid** (the
     HUD says so in red). Recheck Step 1.
   - If pieces look **inside-out or invisible**, the importer flipped the
     triangle direction: tell me and I'll flip the generator (one-line change).
3. You spawn on your island. Top-left is the readout; the buttons are top-right.
   Try **View** (Overview shows all 9 islands), **Next preset**, **Record**.
   In Studio you can trigger everything, since Studio is always allowed.

### What the HUD shows now

- **`Scene` / `Shadow` / `REAL`** lines: the engine's own draw-call and triangle counts
  (`Stats.SceneDrawcallCount` etc.), the same measures as the docs' ~1,000 / ~1,000,000
  budget. `REAL` = scene + shadows, compared with that budget. `~DC guess` is my old
  estimate, kept so we can see how wrong it was.
- **`CPU` / `GPU` (raw)**: engine frame-time counters. Unlike FPS they keep moving below
  the frame-rate cap, so they show how much headroom is left. `FT` is `Stats.FrameTime`,
  shown so the unit can be checked: at 60 FPS one frame is 0.0167 if seconds (16.7 if ms).
  I haven't confirmed these are filled in on iOS.
- **`QL`** now shows the saved graphics setting and Roblox's own `harmony` level (the
  real level can't be read by scripts).
- **Record** results are now 2 lines: `avg|low verdict mem tris/parts`, then
  `cpu gpu dc tri` averaged over the 15 s (dc/tri = scene + shadows).

### What the HUD should say per preset (to check the scene built right)

| Preset | Bases | Pieces/base | Triangles | Art parts | ~Draw calls (guess) |
|---|---|---|---|---|---|
| Solo | 1 | 28 | 28,700 (3%) | 40 | 40 |
| Baseline | 9 | 28 | 229,500 (23%) | 264 | 348 |
| Varied | 9 | 28 | 229,500 (23%) | 264 | 348 |
| Extreme | 9 | 103 | 596,700 (60%) | 939 | 1,023 |
| Limit | 9 | 203 | 1,086,300 (109%) | 1,839 | 1,923 |
| Over | 9 | 403 | 2,065,500 (207%) | 3,639 | 3,723 |
| *Heavy* | 9 | 53 | 351,900 (35%) | 489 | 573 |
| *NoFx* | 9 | 28 | 229,500 (23%) | 264 | 264 |
| *Shard* | 4 | 28 | 104,000 (10%) | 124 | 208 |
| *Precise* | 9 | 28 | 229,500 (23%) | 264 | 348 |

The `~Draw calls` column is my old guess and was far too high (the real Baseline/Ground
reading in Studio was 92); use the HUD's `REAL` line instead. Italic presets are extras.

Presets, in the order the button steps through them: **Solo** = only your base, no effects
(the phone's floor). **Baseline** = 9 bases with effects and NPCs. **Varied** = exactly
Baseline (same pieces, same layout) but every piece gets one of 12 different built-in
materials. Each different material is a separate draw batch, so this shows how real draw
calls climb once pieces stop being identical. It is capped at (8 meshes x 12 materials),
so it shows the trend, not the full cost of hundreds of truly unique models.
**Extreme** = 4x the walls, gates, defenses and decor (the thing D57's build budget will
cap). **Limit/Over** = 8x/16x, deliberately past the docs' budget (~109% / ~207% of the
triangle number) to find where the phone gives in. **Over** may crash the app or get it
killed: that is a result, so note it and don't retry it in a loop. (At 16x the outer wall
rings hang past the island edge; cosmetic only.) Extras after that: Heavy (2x), NoFx,
Shard (you + 3 neighbors) and Precise (identical to Baseline, see "LOD comparison").

## Step 3: publish privately and join from the phone

1. Studio: **File → Publish to Roblox** (updates your existing private
   Vault Raiderz; don't choose "as new"). Rojo's code and the mesh kit are in the
   place, so they publish with it.
2. Check it's private: Creator Hub (create.roblox.com) → **Creations** →
   Vault Raiderz → **Settings → Privacy** should say **Private**. Only you can join.
3. Get the Place ID: Studio → **View → Command Bar**, type `print(game.PlaceId)`,
   Enter, read the number in Output.
4. On the iPhone, **log into the same Roblox account** in the Roblox app. Then
   open Safari to `https://www.roblox.com/games/<PlaceId>` (your number) and
   tap **Play**. (Once you've played it, it also shows under Recently Played.)
5. Hold the phone in **landscape**. Leave graphics on **Automatic** (that's
   what real players get). Battery saver **off**.

The **Next preset** button only works for the place owner (that's you) because it
rebuilds the world for everyone. It works the same on the phone.

## Step 4: the test run on the phone (~10 minutes)

1. Play 2–3 minutes first (a warm phone throttles; you want realistic numbers).
2. Run these presets in this order (each tap of **Next preset** moves to the next):
   **Solo → Baseline → Varied → Extreme → Limit → Over**. For each one:
   - Tap **View** until it says **Overview** (the worst case: all 9 islands in
     frame). Wait for ">> SETTLING" to disappear (8 s). Tap **Record** and
     don't touch anything for 15 s. Then tap **View** back to **Ground**, wait for
     settling, **Record** again.
   - Recordings cancel themselves if the scene changes mid-way; just redo.
   - `CPU`/`GPU` are the engine's own frame-time counters (4 decimals now). The unit isn't
     confirmed: seconds look likely (at 60 FPS `FT` should be about 0.0167). Just screenshot them.
3. The list under the stats (top-left) shows the last 6 results (2 lines each); **screenshot it** after
   every 3 presets (iPhone: side button + volume up). Each line reads:
   `# preset/view avgFPS|1%low verdict mem tris/parts` then `cpu gpu dc tri`.
4. If the app **crashes or the phone gets hot**, stop; note which preset. A crash
   is a result.

Send me the screenshots (or type the lines), plus any red text from Studio's Output.

## LOD comparison (do this AFTER the main run)

Scripts can't set `RenderFidelity` (it needs Plugin capability), so the LOD test is
a second pass with the setting baked into the kit meshes:

1. Finish the whole main run first (kit left on its default, Automatic).
2. Studio → **View → Command Bar**, paste this and press Enter (the command bar
   is allowed to write it):

   ```lua
   local n = 0
   for _, d in game.ServerStorage.PerfSpikeKit:GetDescendants() do
       if d:IsA("MeshPart") then d.RenderFidelity = Enum.RenderFidelity.Precise; n += 1 end
   end
   print("set Precise on", n, "meshes")
   ```

   It should print `set Precise on 8 meshes`.
3. **Save**, **File → Publish to Roblox**, rejoin on the phone.
4. Run **Baseline only**, Overview then Ground, as in Step 4. HUD will still say
   `LOD Automatic` (it shows the preset's label, not the mesh setting); the
   results list is what matters. Note these two lines as "Baseline / LOD Precise".
5. Compare with your earlier Baseline lines. Same scene, only LOD differs.
6. To undo, run the same snippet with `Enum.RenderFidelity.Automatic`, then save
   and publish again.

## How to read the results

Frame-rate lines are `[PH] invented` (the docs give none): **PASS** = average ≥ 30
and 1% low ≥ 20; **GOOD** = average ≥ 45. Judge on a **cheap** phone.

| Compare | It tells you |
|---|---|
| **Solo** vs **Baseline** | What 8 neighbors cost. If Solo is already poor, the base itself is too heavy |
| **Baseline** vs **NoFx** | What particles + NPCs cost (Grade effects, Scavs) |
| **Baseline** (Automatic) vs **Baseline** (kit set to Precise) | What LOD (Roblox's automatic detail reduction) saves. Docs call LOD load-bearing. See "LOD comparison" |
| **Baseline → Heavy → Extreme** | Where the piece budget (D57) should sit: the biggest per-base piece count that still passes |
| **Shard** vs **Baseline** | Whether a bounded neighborhood (D56) buys back headroom |
| **Overview** vs **Ground** | Scouting from the air is the worst case; Ground is the everyday case |

Memory: the docs set **no** memory number. Watch for the app being killed
rather than a specific MB figure. The kit uses only Roblox's built-in materials
(no custom textures), so memory here reads **low** compared with real art.

What this test does **not** cover: custom textures, lighting/shadow settings, the
real UI and effects, network lag. Treat a pass as "not ruled out", not "safe".

## Delete it when you're done

1. `src/server/PerfSpike/` (folder)
2. `src/client/PerfSpikeHud.client.luau`
3. `Config.PerfSpike` in `src/shared/Config.luau`
4. `PerfSpikeSetPreset` in `src/shared/Remotes.luau`
5. The `PerfSpike` lines in `src/server/Main.server.luau`
6. `docs-build/perfspike/` and `ServerStorage/PerfSpikeKit` in the place file
   (keep `docs-build/perfspike/results.md` if you save results there)

`luau-lsp` was added to `rokit.toml` for type-checking. That is permanent and unrelated.
