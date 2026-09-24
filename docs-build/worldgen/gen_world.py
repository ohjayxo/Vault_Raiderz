#!/usr/bin/env python3
"""Generates the greybox world and the gameplay templates for Rojo.

Run from the repo root:  python3 docs-build/worldgen/gen_world.py

ART-SAFE (art-ready pass, 2026-09-22; artist guide: docs-build/art-guide.md).
Every object is a FOLDER on disk that Rojo turns into a Model:

  <Name>/init.meta.json      name, tags, attributes          (always rewritten)
  <Name>/Hitbox.model.json   gameplay shape the code uses     (always rewritten)
  <Name>/Visual.rbxm         the ARTIST's file                (never touched)
  <Name>/Visual.model.json   greybox look, written ONLY while no Visual.rbxm /
                             Visual.rbxmx exists; deleted once one does

So re-running this never overwrites art. Outputs:
  src/world/...                 -> Workspace.World
  src/assets/NodeTemplates/...  -> ServerStorage.NodeTemplates
  src/assets/PieceTemplates/... -> ServerStorage.PieceTemplates
  src/assets/PickaxeTiers/...   -> ServerStorage.PickaxeTiers   (Handle + Visual)
  src/assets/ArmorTemplates/... -> ServerStorage.ArmorTemplates (Attach + Visual)
  src/assets/GadgetTemplates/...-> ServerStorage.GadgetTemplates
(src/assets/PickaxeSkins and NpcTemplates are artist-owned: not generated.)

Steps 2, 4, 5, 6 (docs/13-build-guide.md § Part E). Placeholder parts only.
All positions/sizes are [PH] invented layout.
"""
import json
import math
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
WORLD_DIR = os.path.join(ROOT, "src", "world")
ASSETS = os.path.join(ROOT, "src", "assets")
NODE_DIR = os.path.join(ASSETS, "NodeTemplates")
PIECE_DIR = os.path.join(ASSETS, "PieceTemplates")
TIER_DIR = os.path.join(ASSETS, "PickaxeTiers")
ARMOR_DIR = os.path.join(ASSETS, "ArmorTemplates")
GADGET_DIR = os.path.join(ASSETS, "GadgetTemplates")

GROUND_TOP = 50  # every island's walkable surface is at Y = 50


def rgb(r, g, b):
    return [round(r / 255, 4), round(g / 255, 4), round(b / 255, 4)]


def cframe(x, y, z, yaw_deg=0.0):
    a = math.radians(yaw_deg)
    c, s = round(math.cos(a), 6), round(math.sin(a), 6)
    # Rotation about Y, rows of the rotation matrix.
    return {"CFrame": {"position": [x, y, z], "orientation": [[c, 0, s], [0, 1, 0], [-s, 0, c]]}}


def part(name, size, pos, color, material="SmoothPlastic", yaw=0.0, cls="Part", **extra):
    props = {
        "Anchored": True,
        "Size": list(size),
        "CFrame": cframe(*pos, yaw),
        "Color": color,
        "Material": material,
        "TopSurface": "Smooth",
        "BottomSurface": "Smooth",
    }
    props.update(extra)
    return {"name": name, "className": cls, "properties": props}


def visual_part(name, size, pos, color, material, yaw=0.0, cls="Part"):
    # Visual parts never collide or catch clicks: the Hitbox does both.
    return part(name, size, pos, color, material, yaw=yaw, cls=cls,
                CanCollide=False, CanQuery=False, CanTouch=False, CastShadow=True)


def decor_part(name, size, pos, color, material, yaw=0.0):
    # World decor (rocks, trees, rails) inside a Visual: solid to walk into,
    # like the art that will replace it. Code never reads it.
    return part(name, size, pos, color, material, yaw=yaw)


def hitbox_part(name, size, pos, yaw=0.0):
    return part(name, size, pos, rgb(255, 0, 0), yaw=yaw,
                Transparency=1, CanCollide=True, CanQuery=True, CanTouch=False, CastShadow=False)


def held_part(name, size, pos, color, material, transparency=0):
    # Parts of held/worn things (pickaxe, armor): unanchored, weightless.
    return part(name, size, pos, color, material, Anchored=False, Massless=True,
                CanCollide=False, CanQuery=False, CanTouch=False, Transparency=transparency)


def spawn_point(name, x, z, node_type):
    # Invisible marker at ground level. NodeService reads its position and
    # NodeType attribute; nothing collides with or clicks it.
    p = part(name, (2, 1, 2), (x, GROUND_TOP, z), rgb(255, 0, 255),
             Transparency=1, CanCollide=False, CanQuery=False, CanTouch=False)
    p["attributes"] = {"NodeType": node_type}
    return p


def ring(n, radius, cx, cz, start_deg=0.0):
    for i in range(n):
        a = math.radians(start_deg + 360 * i / n)
        yield round(cx + radius * math.cos(a), 2), round(cz + radius * math.sin(a), 2)


def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print("wrote", os.path.relpath(path, ROOT))


def remove_old(path):
    # Old single-file templates (before the art-ready pass).
    if os.path.exists(path):
        os.remove(path)
        print("removed old", os.path.relpath(path, ROOT))


def template(folder, name, tags=None, attributes=None, children=None, visuals=None, class_name="Model"):
    """One art-safe template folder. `children` are gameplay parts/folders
    (always rewritten); `visuals` is the greybox look, written only while the
    artist hasn't saved a Visual.rbxm/.rbxmx."""
    d = os.path.join(folder, name)
    remove_old(os.path.join(folder, f"{name}.model.json"))
    meta = {"className": class_name}
    if tags:
        meta["properties"] = {"Tags": tags}
    if attributes:
        meta["attributes"] = attributes
    write(os.path.join(d, "init.meta.json"), meta)
    for child in children or []:
        write(os.path.join(d, f"{child['name']}.model.json"), {k: v for k, v in child.items() if k != "name"})
    if visuals is None:
        return
    greybox = os.path.join(d, "Visual.model.json")
    has_art = any(os.path.exists(os.path.join(d, f)) for f in ("Visual.rbxm", "Visual.rbxmx"))
    if has_art:
        if os.path.exists(greybox):
            os.remove(greybox)
            print("art found, removed greybox", os.path.relpath(greybox, ROOT))
        else:
            print("kept art", os.path.relpath(d, ROOT))
    else:
        write(greybox, {"className": "Folder", "children": visuals})


def folder(name, children):
    return {"name": name, "className": "Folder", "children": children}


# ── Slice layout: "Main Street" (02-core-loop.md § Slice layout, D113) ──────
# A straight street (the Homestead) with plots in two facing rows of four,
# the Reaches off the north end, a south plaza for the step-9 NPC buyer and
# the step-14 FTUE derelict vault. Space south of the plaza is reserved for
# the Exchange, north of the Reaches for the Rift (nothing built there).
# All sizes [PH]. 12-nexus § Known drift risks: after this build, THIS file
# and Config hold the live values; the doc keeps the rules.
#
# Rules this layout must keep (checked at the bottom of this section):
#   * every plot bridge is the same length (same Scav lane, same approach);
#   * every plot is rotated so its FRONT (local -Z edge = build-grid row
#     z = 0, PlotGrid.front) faces its bridge, so a saved base reads the
#     same on any plot;
#   * spawn faces a node mid-street (FTUE 0:00);
#   * no walkable surface above a plot sits within DROP_IN_CLEARANCE of it
#     (all ground is one height here, so this holds trivially);
#   * a carrier on the victim's plot or bridge is inside the Chase escape
#     radius (D114), and Scavs have bridge ground at SpawnDistance.
# Each island: Hitbox = the walkable slab (code + physics), Visual = ground
# look + decor. SpawnLocation, NodeSpawns and slots are gameplay, beside them.

STREET_SIZE = (240, 320)       # X by Z. Zone "Homestead", not contested. 24 road + 108 grass
                               # each side (Josh 2026-09-23: 3x the grass, "open space, not a runway")
                               # Back to double: (168, 320) + PLAZA_SIZE (176, 96); original: (96, 320).
                               # See docs-build/design-changes.md § Wider Main Street.
PLAZA_SIZE = (240, 96)         # as wide as the street, so it doesn't read as a notch
PLAZA_C = (0, STREET_SIZE[1] / 2 + PLAZA_SIZE[1] / 2)  # (0, 208): touches the street's south edge
REACHES_SIZE = 150
REACHES_BRIDGE = (12, 75)      # width, length: street north edge -> Reaches south edge
REACHES_C = (0, -(STREET_SIZE[1] / 2 + REACHES_BRIDGE[1] + REACHES_SIZE / 2))  # (0, -310)
SPAWN = (0, 10)                # faces north (-Z) at FTUE_NODE
FTUE_NODE = (0, -18)
NPC_BUYER_SLOT = (-40, 215)    # step 9: position + tag only
DERELICT_VAULT_SLOT = (40, 215)  # step 14: position + tag only
DROP_IN_CLEARANCE = 25

# Player plots (step 4). PLOT_COUNT and PLOT_SIZE must match Config.Plots
# (checked below against Config.luau).
PLOT_SIZE = 48                 # 12 x 12 cells of 4 studs
PLOT_ROW_X = STREET_SIZE[0] / 2 + 64 + PLOT_SIZE / 2  # 208: street edge + 64-stud bridge + half a plot
PLOT_ROW_Z = (-114, -38, 38, 114)  # 76 apart
PLOT_BRIDGE_WIDTH = 8
PLOT_COUNT = 2 * len(PLOT_ROW_Z)

sx, sz = STREET_SIZE
homestead_spawns = [spawn_point("Stone1", *FTUE_NODE, "Stone")]  # the FTUE's first node
# Along the street, clear of the spawn and of every bridge mouth.
for i, (x, z) in enumerate([(-24, -76), (24, -76), (-24, 0), (24, 0), (-24, 76), (24, 76), (0, 120)]):
    homestead_spawns.append(spawn_point(f"Stone{i + 2}", x, z, "Stone"))
for i, (x, z) in enumerate([(-24, -138), (24, -138), (-24, 145), (24, 145)]):
    homestead_spawns.append(spawn_point(f"Ore{i + 1}", x, z, "Ore"))

# Mock scenery on the street's grass (Josh 2026-09-23: "get a feel for the
# environment"). Placeholder only: the artist replaces the Visual. Seeded, so
# every run writes the same layout. Kept clear of the road + node spawns
# (|x| < 36), each bridge's lane to the road (|z - row z| < 14), the street's
# edges and each other. Trees are solid like real ones; bushes walk-through.
def street_scenery():
    import random
    rng = random.Random(113)  # D113 street; any fixed seed works
    placed = [(-80, 150), (-70, -100), (75, 60)]  # Tree1, Rock1, Rock2 above
    out = []
    edge_x, edge_z = sx / 2 - 8, sz / 2 - 10

    def free(x, z, gap):
        if abs(x) < 36 or abs(x) > edge_x or abs(z) > edge_z:
            return False
        if any(abs(z - rz_) < 14 for rz_ in PLOT_ROW_Z) and abs(x) > sx / 2 - 30:
            return False
        return all(math.hypot(x - px_, z - pz_) >= gap for px_, pz_ in placed)

    def scatter(count, gap, make):
        n, tries = 0, 0
        while n < count and tries < 5000:
            tries += 1
            x = rng.uniform(-edge_x, edge_x)
            z = rng.uniform(-edge_z, edge_z)
            if free(x, z, gap):
                placed.append((x, z))
                n += 1
                out.extend(make(n, x, z))

    def tree(n, x, z):
        h = rng.uniform(10, 16)
        w = rng.uniform(8, 12)
        green = rgb(*rng.choice([(75, 151, 75), (62, 128, 62), (88, 160, 80)]))
        return [
            decor_part(f"Tree{n + 1}Trunk", (2, h, 2), (x, GROUND_TOP + h / 2, z), rgb(105, 64, 40), "Wood"),
            decor_part(f"Tree{n + 1}Top", (w, w * 0.8, w), (x, GROUND_TOP + h + w * 0.3, z), green, "Grass",
                       yaw=rng.uniform(0, 90)),
        ]

    def bush(n, x, z):
        w = rng.uniform(3, 5.5)
        green = rgb(*rng.choice([(70, 140, 60), (58, 120, 55), (95, 150, 70)]))
        return [
            part(f"Bush{n}", (w, w * 0.7, w * 0.9), (x, GROUND_TOP + w * 0.35, z), green, "Grass",
                 yaw=rng.uniform(0, 90), CanCollide=False, CanQuery=False, CanTouch=False),
        ]

    scatter(22, 16, tree)
    scatter(36, 7, bush)
    return out


template(WORLD_DIR, "Homestead", attributes={"Zone": "Homestead"},
         children=[
             hitbox_part("Hitbox", (sx, 10, sz), (0, GROUND_TOP - 5, 0)),
             # Rotation 0 = facing north (-Z), straight at the FTUE node.
             part("SpawnLocation", (8, 1, 8), (SPAWN[0], GROUND_TOP + 0.5, SPAWN[1]), rgb(163, 162, 165),
                  cls="SpawnLocation", Neutral=True, Duration=0),
             folder("NodeSpawns", homestead_spawns),
         ],
         visuals=[
             visual_part("Ground", (sx, 10, sz), (0, GROUND_TOP - 5.02, 0), rgb(106, 127, 63), "Grass"),
             visual_part("Underside", (sx - 20, 30, sz - 40), (0, GROUND_TOP - 25, 0), rgb(99, 95, 98), "Slate"),
             visual_part("Road", (24, 0.2, sz), (0, GROUND_TOP + 0.1, 0), rgb(150, 135, 110), "Cobblestone"),
             decor_part("Rock1", (8, 6, 7), (-70, GROUND_TOP + 3, -100), rgb(120, 118, 115), "Slate", yaw=20),
             decor_part("Rock2", (7, 5, 8), (75, GROUND_TOP + 2.5, 60), rgb(120, 118, 115), "Slate", yaw=-35),
             decor_part("Tree1Trunk", (2, 12, 2), (-80, GROUND_TOP + 6, 150), rgb(105, 64, 40), "Wood"),
             decor_part("Tree1Top", (10, 8, 10), (-80, GROUND_TOP + 15, 150), rgb(75, 151, 75), "Grass"),
             *street_scenery(),
         ])


def slot_part(name, pos, tag):
    # Invisible marker for a later step: position + tag, no behaviour.
    p = part(name, (4, 1, 4), (pos[0], GROUND_TOP + 0.5, pos[1]), rgb(0, 255, 255),
             Transparency=1, CanCollide=False, CanQuery=False, CanTouch=False)
    p["properties"]["Tags"] = [tag]
    return p


px, pz = PLAZA_SIZE
pcx, pcz = PLAZA_C
template(WORLD_DIR, "Plaza", attributes={"Zone": "Homestead"},
         children=[
             hitbox_part("Hitbox", (px, 10, pz), (pcx, GROUND_TOP - 5, pcz)),
             # Tags must match Config.World.Slots.
             slot_part("NpcBuyerSlot", NPC_BUYER_SLOT, "NpcBuyerSlot"),
             slot_part("DerelictVaultSlot", DERELICT_VAULT_SLOT, "DerelictVaultSlot"),
         ],
         visuals=[
             visual_part("Ground", (px, 10, pz), (pcx, GROUND_TOP - 5.02, pcz), rgb(140, 132, 110), "Cobblestone"),
             visual_part("Underside", (px - 30, 30, pz - 20), (pcx, GROUND_TOP - 25, pcz), rgb(99, 95, 98), "Slate"),
         ])

# Step 9: the NPC buyer's stall. Hitbox = solid stall + the "Sell" prompt
# (EconomyService); Visual = the look (the artist swaps it, Visual.rbxm).
# Tag must match Config.NpcSelling.BuyerTag. Stands on the NpcBuyerSlot spot.
bx, bz = NPC_BUYER_SLOT
template(os.path.join(WORLD_DIR, "Plaza"), "NpcBuyer", tags=["NpcBuyer"], attributes={"Kind": "NpcBuyer"},
         children=[
             hitbox_part("Hitbox", (8, 6, 4), (bx, GROUND_TOP + 3, bz)),
         ],
         visuals=[
             visual_part("Counter", (8, 3.2, 4), (bx, GROUND_TOP + 1.6, bz), rgb(120, 84, 52), "Wood"),
             visual_part("PostL", (0.6, 6, 0.6), (bx - 3.7, GROUND_TOP + 3, bz - 1.6), rgb(90, 62, 40), "Wood"),
             visual_part("PostR", (0.6, 6, 0.6), (bx + 3.7, GROUND_TOP + 3, bz - 1.6), rgb(90, 62, 40), "Wood"),
             visual_part("Awning", (9, 0.5, 5), (bx, GROUND_TOP + 6.2, bz - 0.4), rgb(214, 170, 60), "Fabric"),
             visual_part("Goods", (2, 1.2, 1.6), (bx - 2, GROUND_TOP + 3.8, bz), rgb(160, 160, 170), "Slate"),
         ])

rx, rz = REACHES_C
reaches_spawns = []
for i, (x, z) in enumerate(ring(6, 55, rx, rz, start_deg=0)):
    reaches_spawns.append(spawn_point(f"Ore{i + 1}", x, z, "Ore"))
for i, (x, z) in enumerate(ring(5, 28, rx, rz, start_deg=36)):
    reaches_spawns.append(spawn_point(f"Riftsalt{i + 1}", x, z, "Riftsalt"))

template(WORLD_DIR, "Reaches", attributes={"Zone": "Reaches"},
         children=[
             hitbox_part("Hitbox", (REACHES_SIZE, 10, REACHES_SIZE), (rx, GROUND_TOP - 5, rz)),
             folder("NodeSpawns", reaches_spawns),
         ],
         visuals=[
             visual_part("Ground", (REACHES_SIZE, 10, REACHES_SIZE), (rx, GROUND_TOP - 5.02, rz), rgb(86, 66, 54), "Ground"),
             visual_part("Underside", (REACHES_SIZE - 30, 40, REACHES_SIZE - 30), (rx, GROUND_TOP - 30, rz), rgb(60, 55, 65), "Basalt"),
             decor_part("Spire1", (6, 26, 6), (rx - 62, GROUND_TOP + 13, rz - 60), rgb(70, 60, 80), "Basalt", yaw=15),
             decor_part("Spire2", (5, 18, 5), (rx + 64, GROUND_TOP + 9, rz - 55), rgb(70, 60, 80), "Basalt", yaw=-20),
         ])

# Walkable bridge from the street's north edge to the Reaches' south edge.
bw, blen_r = REACHES_BRIDGE
mid = -(sz / 2 + blen_r / 2)
template(WORLD_DIR, "Bridge",
         children=[hitbox_part("Hitbox", (bw, 1, blen_r), (0, GROUND_TOP - 0.5, mid))],
         visuals=[
             visual_part("Deck", (bw, 1, blen_r), (0, GROUND_TOP - 0.52, mid), rgb(124, 92, 70), "WoodPlanks"),
             decor_part("RailLeft", (1, 3, blen_r), (-bw / 2 - 0.5, GROUND_TOP + 1.5, mid), rgb(91, 93, 105), "Metal"),
             decor_part("RailRight", (1, 3, blen_r), (bw / 2 + 0.5, GROUND_TOP + 1.5, mid), rgb(91, 93, 105), "Metal"),
         ])


# ── Player plots ────────────────────────────────────────────────────────────
PLOTS_DIR = os.path.join(WORLD_DIR, "Plots")
write(os.path.join(PLOTS_DIR, "init.meta.json"), {"className": "Model"})

plot_bridges = []  # (index, plot centre, bridge length, far-end distance) for the checks below
index = 0
for side in (-1, 1):  # west row, then east row
    for pz_ in PLOT_ROW_Z:
        index += 1
        cx, cz = side * PLOT_ROW_X, pz_
        # Front (local -Z) faces the street: yaw -90 turns it to +X (west
        # row), +90 to -X (east row). cframe()'s look vector = (-sin, 0, -cos).
        yaw = -90 if side == -1 else 90
        top = GROUND_TOP
        template(PLOTS_DIR, f"Plot{index}", tags=["Plot"], attributes={"PlotIndex": index},
                 children=[hitbox_part("Hitbox", (PLOT_SIZE, 2, PLOT_SIZE), (cx, top - 1, cz), yaw=yaw)],
                 visuals=[
                     visual_part("Ground", (PLOT_SIZE, 2, PLOT_SIZE), (cx, top - 1.02, cz), rgb(120, 140, 80), "Grass", yaw=yaw),
                     visual_part("Underside", (PLOT_SIZE - 10, 16, PLOT_SIZE - 10), (cx, top - 10, cz), rgb(99, 95, 98), "Slate", yaw=yaw),
                     visual_part("Marker", (4, 0.2, 4), (cx, top + 0.1, cz), rgb(200, 200, 90), "Neon"),
                 ])
        # Bridge: street edge to the plot's front edge, straight along X.
        x_street = side * (sx / 2)
        x_plot = side * (PLOT_ROW_X - PLOT_SIZE / 2)
        blen = abs(x_plot - x_street)
        bx = (x_street + x_plot) / 2
        template(PLOTS_DIR, f"Bridge{index}",
                 children=[hitbox_part("Hitbox", (blen, 1, PLOT_BRIDGE_WIDTH), (bx, GROUND_TOP - 0.5, cz))],
                 visuals=[visual_part("Deck", (blen, 1, PLOT_BRIDGE_WIDTH), (bx, GROUND_TOP - 0.52, cz),
                                      rgb(124, 92, 70), "WoodPlanks")])
        far = abs(cx - x_street)
        plot_bridges.append((index, (cx, cz), blen, math.hypot(far, PLOT_BRIDGE_WIDTH / 2)))


# ── Layout checks (02 § Slice layout rules, D114) ──────────────────────────
def config_number(pattern):
    import re
    with open(os.path.join(ROOT, "src", "shared", "Config.luau")) as f:
        m = re.search(pattern, f.read())
    assert m, f"Config.luau: couldn't find {pattern}"
    return float(m.group(1))


lengths = {round(b[2], 3) for b in plot_bridges}
assert len(lengths) == 1, f"plot bridges must all be the same length, got {sorted(lengths)}"
assert PLOT_COUNT == config_number(r"Plots = \{[^}]*?Count = (\d+)"), "PLOT_COUNT != Config.Plots.Count"
assert PLOT_SIZE == config_number(r"Plots = \{[^}]*?SizeStuds = (\d+)"), "PLOT_SIZE != Config.Plots.SizeStuds"
escape = config_number(r"EscapeRadiusStuds = (\d+)")
spawn_distance = config_number(r"SpawnDistance = (\d+)")
# Raid log map points are saved shifted by LogCoordOffset (no negatives in a profile).
assert config_number(r"LogCoordOffset = (\d+)") > escape, "Config.Raiding.LogCoordOffset must exceed EscapeRadiusStuds"
blen_plot = lengths.pop()
for idx, _, _, far in plot_bridges:
    # Standing anywhere on your own plot or bridge never counts as escaped.
    assert far < escape, f"Bridge{idx}'s street end is {far:.0f} studs from its plot centre: outside the {escape:.0f}-stud escape radius"
# Scavs start on bridge ground (not the plot-edge fallback).
assert PLOT_SIZE / 2 < spawn_distance < PLOT_SIZE / 2 + blen_plot, "Scav SpawnDistance must land on the plot bridge"
# Neighbouring plots in a row are far enough apart that nobody jumps between them.
row_gap = min(b - a for a, b in zip(PLOT_ROW_Z, PLOT_ROW_Z[1:])) - PLOT_SIZE
assert row_gap >= DROP_IN_CLEARANCE, f"plots in a row are only {row_gap} studs apart"
print(f"layout ok: {PLOT_COUNT} plots, bridges {blen_plot:.0f} long, escape radius {escape:.0f}, row gap {row_gap:.0f}")


# ── Node templates ──────────────────────────────────────────────────────────
# Pivot/Hitbox sit at the origin, bottom at Y=0; NodeService moves the clone.
NODE_HITBOX = (5, 6, 5)
NODE_VISUALS = {
    "Stone": [
        visual_part("Rock", (4.5, 4, 4.5), (0, 2, 0), rgb(140, 140, 136), "Slate", yaw=18),
        visual_part("Chunk", (2.5, 2.5, 2.5), (1.2, 4.5, -0.6), rgb(125, 125, 120), "Slate", yaw=-30),
    ],
    "Ore": [
        visual_part("Rock", (4.5, 4.5, 4.5), (0, 2.25, 0), rgb(72, 70, 68), "Basalt", yaw=10),
        visual_part("Vein1", (1.2, 1.2, 4.7), (1, 3, 0), rgb(196, 112, 60), "Metal", yaw=30),
        visual_part("Vein2", (4.7, 1, 1.2), (-0.5, 1.6, 0.8), rgb(196, 112, 60), "Metal", yaw=-15),
    ],
    "Riftsalt": [
        visual_part("Base", (4, 1.5, 4), (0, 0.75, 0), rgb(60, 50, 70), "Basalt"),
        visual_part("Crystal1", (1.6, 5, 1.6), (0, 3.5, 0), rgb(170, 90, 255), "Neon", yaw=25),
        visual_part("Crystal2", (1.1, 3.2, 1.1), (1.3, 2.6, 0.7), rgb(200, 130, 255), "Glass", yaw=-10),
    ],
}
for node_type, visuals in NODE_VISUALS.items():
    template(NODE_DIR, f"{node_type}Node", tags=["ResourceNode"], attributes={"NodeType": node_type},
             children=[hitbox_part("Hitbox", NODE_HITBOX, (0, NODE_HITBOX[1] / 2, 0))],
             visuals=visuals)


# ── Base piece templates (steps 4 + 6) ──────────────────────────────────────
# Hitbox bottom at Y=0, centred on X/Z; PlotService moves the clone. The
# footprint lives in Config.Base.Pieces; Hitbox sizes here must fit it.
PIECES = {
    "Wall": {
        "hitbox": (4, 6, 1),
        "visuals": [visual_part("Panel", (4, 6, 1), (0, 3, 0), rgb(160, 160, 155), "Concrete")],
    },
    "Gate": {
        "hitbox": (4, 6, 1),
        "visuals": [
            visual_part("PostL", (0.6, 6.5, 1.2), (-1.7, 3.25, 0), rgb(91, 93, 105), "Metal"),
            visual_part("PostR", (0.6, 6.5, 1.2), (1.7, 3.25, 0), rgb(91, 93, 105), "Metal"),
            visual_part("Door", (2.8, 5, 0.4), (0, 2.5, 0), rgb(140, 100, 60), "WoodPlanks"),
        ],
    },
    "VaultCore": {
        "hitbox": (8, 8, 8),
        "visuals": [
            visual_part("Plinth", (8, 1.5, 8), (0, 0.75, 0), rgb(90, 90, 100), "DiamondPlate"),
            visual_part("Safe", (6, 6, 6), (0, 4.5, 0), rgb(150, 150, 165), "Metal"),
            visual_part("Door", (4, 4, 0.4), (0, 4.5, 3.1), rgb(70, 170, 230), "Neon"),
        ],
    },
    # Step 6 defenses (02-core-loop.md § Defenses); ranges are Config.Defenses.
    "TripwireAlarm": {
        "hitbox": (1, 2, 1),
        "visuals": [
            visual_part("Post", (0.6, 2, 0.6), (0, 1, 0), rgb(91, 93, 105), "Metal"),
            visual_part("Lamp", (0.8, 0.5, 0.8), (0, 2.1, 0), rgb(255, 60, 60), "Neon"),
        ],
    },
    "SpikeFloor": {
        "hitbox": (7.6, 0.6, 7.6),
        "visuals": [visual_part("Plate", (7.6, 0.3, 7.6), (0, 0.15, 0), rgb(70, 70, 75), "DiamondPlate")]
        + [visual_part(f"Spike{i}", (0.4, 0.8, 0.4), (-2.7 + (i % 4) * 1.8, 0.55, -2.7 + (i // 4) * 1.8),
                       rgb(180, 180, 185), "Metal") for i in range(16)],
    },
    "ShockFence": {
        "hitbox": (4, 5, 0.6),
        "visuals": [
            visual_part("PostL", (0.5, 5, 0.5), (-1.75, 2.5, 0), rgb(91, 93, 105), "Metal"),
            visual_part("PostR", (0.5, 5, 0.5), (1.75, 2.5, 0), rgb(91, 93, 105), "Metal"),
            visual_part("Wire1", (3.2, 0.15, 0.15), (0, 1.5, 0), rgb(120, 200, 255), "Neon"),
            visual_part("Wire2", (3.2, 0.15, 0.15), (0, 3, 0), rgb(120, 200, 255), "Neon"),
            visual_part("Wire3", (3.2, 0.15, 0.15), (0, 4.5, 0), rgb(120, 200, 255), "Neon"),
        ],
    },
    "DecoyVault": {
        "hitbox": (7, 7, 7),
        "visuals": [
            visual_part("Plinth", (7, 1.2, 7), (0, 0.6, 0), rgb(90, 90, 100), "DiamondPlate"),
            visual_part("Safe", (5.5, 5.5, 5.5), (0, 3.95, 0), rgb(140, 140, 150), "Metal"),
            visual_part("Door", (3.5, 3.5, 0.4), (0, 3.95, 2.85), rgb(230, 160, 60), "Neon"),
        ],
    },
    "GuardDrone": {
        "hitbox": (2, 6, 2),
        "visuals": [
            visual_part("Pad", (2, 0.4, 2), (0, 0.2, 0), rgb(91, 93, 105), "Metal"),
            visual_part("Drone", (1.6, 0.8, 1.6), (0, 5, 0), rgb(60, 60, 70), "Metal"),
            visual_part("Eye", (0.6, 0.6, 0.6), (0, 4.5, 0), rgb(255, 80, 80), "Neon"),
        ],
    },
    "LockUpgrade": {
        "hitbox": (2, 2, 2),
        "visuals": [
            visual_part("Box", (1.8, 1.8, 1.8), (0, 0.9, 0), rgb(60, 70, 90), "Metal"),
            visual_part("Dial", (1, 1, 0.2), (0, 1.1, 0.95), rgb(220, 200, 80), "Neon"),
        ],
    },
}
PIECE_TAGS = {"Wall": ["BasePiece"], "Gate": ["BasePiece", "BaseGate"], "VaultCore": ["BasePiece", "VaultCore"]}
for defense in ("TripwireAlarm", "SpikeFloor", "ShockFence", "DecoyVault", "GuardDrone", "LockUpgrade"):
    PIECE_TAGS[defense] = ["BasePiece", "Defense"]

for kind, spec in PIECES.items():
    hb = spec["hitbox"]
    template(PIECE_DIR, kind, tags=PIECE_TAGS[kind], attributes={"Kind": kind},
             children=[hitbox_part("Hitbox", hb, (0, hb[1] / 2, 0))],
             visuals=spec["visuals"])


# ── Pickaxe per tier (step 5; same contract as a skin) ──────────────────────
# Handle = the grip CombatService holds (keep its size); Visual = the art.
# Sizes match Config.Combat.ToolLook. Head colours = the tier colours.
HANDLE = (0.3, 0.3, 3.5)
TIER_COLORS = {
    "Wooden": rgb(150, 110, 70),
    "Iron": rgb(170, 170, 180),
    "Voltsteel": rgb(90, 200, 255),
    "Riftedge": rgb(190, 90, 255),
}
for tier_index, (tier, color) in enumerate(TIER_COLORS.items(), start=1):
    template(TIER_DIR, tier, attributes={"Tier": tier_index},
             children=[held_part("Handle", HANDLE, (0, 0, 0), rgb(255, 0, 0), "SmoothPlastic", transparency=1)],
             visuals=[
                 held_part("Shaft", HANDLE, (0, 0, 0), rgb(150, 110, 70), "Wood"),
                 held_part("Head", (0.5, 2.4, 0.5), (0, 0, HANDLE[2] / 2), color, "Metal"),
             ])


# ── Armor per tier (step 5, D112; one chest slot) ───────────────────────────
# Attach = where the wearer's UpperTorso centre goes (ArmorService lines it
# up and welds); Visual = the art, around it. Sized for a default R15 torso.
for tier_index, (tier, color) in enumerate(TIER_COLORS.items(), start=1):
    template(ARMOR_DIR, f"{tier}Chest", attributes={"Tier": tier_index, "Slot": "Chest"},
             children=[held_part("Attach", (1, 1, 1), (0, 0, 0), rgb(255, 0, 0), "SmoothPlastic", transparency=1)],
             visuals=[held_part("Plate", (2.3, 1.3, 1.3), (0, 0.1, 0), color, "Metal")])


# ── Gadget objects (step 5) ─────────────────────────────────────────────────
# Shock Trap: Hitbox = the pad that stuns on touch (bottom at Y=0).
template(GADGET_DIR, "ShockTrap",
         children=[hitbox_part("Hitbox", (3, 0.4, 3), (0, 0.2, 0))],
         visuals=[visual_part("Pad", (3, 0.4, 3), (0, 0.2, 0), rgb(255, 220, 60), "Neon")])
