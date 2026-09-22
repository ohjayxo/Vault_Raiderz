# Vault Raiderz: art guide

For whoever makes the game look good. You can replace the look of almost
everything without touching code, and nothing will overwrite your work.

Last updated 2026-09-22 (art-ready pass). Ask Josh (or Claude) when
something here doesn't match what you see.

---

## 1. The one rule

Every game object is a **Model** with two kinds of children:

| Child | Who owns it | What you may do |
|---|---|---|
| **`Hitbox`** (or `Handle` / `Attach`, see the table below) | the code | **Don't rename, move, resize or delete it.** It's the invisible shape the game uses for collision, clicking and placement. |
| **`Visual`** (a Folder) | **you** | **Anything.** Replace every part in it with meshes, textures, decals, particles, lights, more parts. The code never looks inside it. |

That's the whole contract. If the Visual looks right around the Hitbox, the
game plays exactly the same.

Tips:
- Keep the look roughly the size of the Hitbox (players click and bump
  the Hitbox, so a much bigger look feels wrong).
- For base pieces, nodes and plots: set Visual parts **Anchored = true**,
  **CanCollide = false**, **CanQuery = false**, **CanTouch = false** (the
  Hitbox already collides).
- For islands and bridges: decor in Visual (rocks, trees, rails) may
  collide if you want players to bump into it.
- For things held or worn (pickaxes, skins, armor): anything goes; the code
  welds your Visual to the Handle/Attach and makes it weightless.

---

## 2. How to save your work (Studio + Rojo)

The game's files live in the repo folder `src/`. Rojo copies them into
Studio. So edits you make **only** in Studio are temporary; saving them to a
file is what makes them permanent.

1. In Studio, find the object (see the table in section 3).
   Tip: templates live in **ServerStorage**. To see one in 3D, copy it into
   **Workspace**, edit there, then save its Visual and delete the copy.
2. Edit its **Visual** folder.
3. Right-click the **Visual** folder → **Save to File…** → save it as
   **`Visual.rbxm`** in that object's folder in the repo (path in section 3),
   replacing any existing `Visual.rbxm`.
4. **The first time** you do this for an object, delete the grey
   placeholder `Visual.model.json` in the same folder (or ask Josh to run
   `python3 docs-build/worldgen/gen_world.py`, which does it for you). If
   both exist, the object gets two Visual folders.
5. Tell Josh, who commits it.

The generator script (`gen_world.py`) rewrites `init.meta.json` and the
Hitbox files, but **never touches a `Visual.rbxm`**.

If something you saved doesn't show up in Studio: Rojo needs a restart
(`rojo serve`, then Disconnect/Connect in the Rojo plugin).

---

## 3. Everything you can reskin

`Studio location` is where it is while editing; `Repo folder` is where the
files live.

### World

| Object | Studio location | Repo folder | Gameplay part (don't touch) |
|---|---|---|---|
| Homestead island (spawn island) | Workspace › World › Homestead | `src/world/Homestead/` | `Hitbox` = the walkable slab (220 × 10 × 220). Also keep `SpawnLocation` and `NodeSpawns`. |
| Reaches island (danger zone) | Workspace › World › Reaches | `src/world/Reaches/` | `Hitbox` (150 × 10 × 150), `NodeSpawns` |
| Bridge Homestead → Reaches | Workspace › World › Bridge | `src/world/Bridge/` | `Hitbox` = the deck |
| Player plots 1-8 | Workspace › World › Plots › Plot1… | `src/world/Plots/Plot1/` … | `Hitbox` = build surface (48 × 2 × 48). The build grid is on its top face. |
| Plot bridges 1-8 | Workspace › World › Plots › Bridge1… | `src/world/Plots/Bridge1/` … | `Hitbox` = the deck |

### Resource nodes (the things you tap to mine)

| Object | Studio location | Repo folder | Gameplay part |
|---|---|---|---|
| Stone node | ServerStorage › NodeTemplates › StoneNode | `src/assets/NodeTemplates/StoneNode/` | `Hitbox` 5 × 6 × 5, bottom at ground |
| Ore node | … › OreNode | `…/OreNode/` | same |
| Riftsalt node | … › RiftsaltNode | `…/RiftsaltNode/` | same |

### Base pieces and defenses

All in ServerStorage › PieceTemplates, repo `src/assets/PieceTemplates/<Name>/`.
`Hitbox` bottom sits on the plot surface. One grid cell = 4 × 4 studs.

| Object | Hitbox size | Note |
|---|---|---|
| VaultCore | 8 × 8 × 8 | The safe players bank into. 2 × 2 cells. |
| Wall | 4 × 6 × 1 | Sits on the line between cells. |
| Gate | 4 × 6 × 1 | Owner walks through it. |
| TripwireAlarm | 1 × 2 × 1 | |
| SpikeFloor | 7.6 × 0.6 × 7.6 | Players walk on it. 2 × 2 cells. |
| ShockFence | 4 × 5 × 0.6 | Sits on the line between cells. |
| DecoyVault | 7 × 7 × 7 | Should look like the VaultCore (it's a fake). |
| GuardDrone | 2 × 6 × 2 | The drone hovers near the top; zaps come from ~1 stud below the top. |
| LockUpgrade | 2 × 2 × 2 | |

### The pickaxe, skins and armor (held/worn)

| Object | Studio location | Repo folder | Gameplay part |
|---|---|---|---|
| Plain pickaxe per tier (Wooden, Iron, Voltsteel, Riftedge) | ServerStorage › PickaxeTiers › Wooden… | `src/assets/PickaxeTiers/Wooden/` … | `Handle` 0.3 × 0.3 × 3.5 = where the hand grips; the head end is +Z |
| Pickaxe skins | ServerStorage › PickaxeSkins › CaptainsCleaver | `src/assets/PickaxeSkins/CaptainsCleaver/` | `Handle`, same as above |
| Chest armor per tier | ServerStorage › ArmorTemplates › WoodenChest… | `src/assets/ArmorTemplates/WoodenChest/` … | `Attach` = where the wearer's UpperTorso centre goes |

### Characters and gadget objects

| Object | Studio location | Repo | Notes |
|---|---|---|---|
| Scav, Scav Captain | ServerStorage › NpcTemplates › **Scav** / **Captain** | `src/assets/NpcTemplates/Scav.rbxm`, `Captain.rbxm` | Empty until you add one; the game uses grey placeholder rigs meanwhile. Must be an **R15 rig** with a `Humanoid` and a `HumanoidRootPart`, all parts **unanchored**. Save the whole rig (not just a Visual) with Save to File. The game sets health and speed. |
| Shock Trap | ServerStorage › GadgetTemplates › ShockTrap | `src/assets/GadgetTemplates/ShockTrap/` | `Hitbox` 3 × 0.4 × 3 = the pad that stuns. The model gets an `Armed` attribute once it's live (0.5 s after landing) if you want the look to react. |

---

## 4. Adding a new pickaxe skin

1. Copy the `src/assets/PickaxeSkins/CaptainsCleaver/` folder and rename
   it, e.g. `GoldenPick/`. In `init.meta.json` change `SkinId` to the new
   name.
2. Replace its Visual with your art (section 2). Keep the `Handle`.
3. Ask Josh/Claude to add one line to `Config.Cosmetics.PickaxeSkins` (the
   name players see) and decide how players get it.

---

## 5. Performance budget (mobile first)

Most players are on phones. From the step 0B test on Josh's phone
(`docs-build/perfspike/results.md`) and `docs/09-research.md § Rendering &
Mobile Performance Budget`:
- About **1,000,000 triangles on screen** in total, across up to 9 bases.
- **No MeshPart over ~20,000 triangles** (Roblox's import cap).
- **Reuse the same meshes and materials.** Identical pieces are nearly free
  (Roblox draws them together); every *different* material or texture
  costs more. A kit of shared textures beats unique ones per piece.
- Base pieces are placed many times per base, so keep walls, gates and
  floors cheap; the Vault Core and trophies can be richer.
- Test on a phone, ideally an older one.

---

## 6. Not reskinnable yet (needs a code pass)

- **Particle effects**: Grade bursts and beams at nodes, hit flashes,
  Guard Drone zaps, Smoke Bomb cloud. Their colours/sizes are numbers in
  `src/shared/Config.luau`; an effects pass will turn them into templates.
- **The UI** (buttons, menus, meters, banners): built in code; a UI pass
  comes before the FTUE.
- **Roblox Terrain**: Rojo can't sync Terrain, so it would live in the
  place file. Talk to Josh first.
- **Animations** (Scav walk/attack, custom swings).
- **Changing a gameplay shape** (a bigger Vault Core, a longer wall) or
  adding a new kind of object: that's a code change.
