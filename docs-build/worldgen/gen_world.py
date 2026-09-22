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


# ── Islands ─────────────────────────────────────────────────────────────────
# Each island: Hitbox = the walkable slab (code + physics), Visual = ground
# look + decor. SpawnLocation and NodeSpawns are gameplay, beside them.

HOMESTEAD_C = (0, 0)
HOMESTEAD_SIZE = 220
REACHES_C = (0, -430)
REACHES_SIZE = 150

homestead_spawns = []
for i, (x, z) in enumerate(ring(8, 60, *HOMESTEAD_C, start_deg=112.5)):
    homestead_spawns.append(spawn_point(f"Stone{i + 1}", x, z, "Stone"))
for i, (x, z) in enumerate(ring(4, 88, *HOMESTEAD_C, start_deg=225)):
    homestead_spawns.append(spawn_point(f"Ore{i + 1}", x, z, "Ore"))

remove_old(os.path.join(WORLD_DIR, "Homestead.model.json"))
template(WORLD_DIR, "Homestead", attributes={"Zone": "Homestead"},
         children=[
             hitbox_part("Hitbox", (HOMESTEAD_SIZE, 10, HOMESTEAD_SIZE), (0, GROUND_TOP - 5, 0)),
             part("SpawnLocation", (8, 1, 8), (0, GROUND_TOP + 0.5, 70), rgb(163, 162, 165), cls="SpawnLocation",
                  Neutral=True, Duration=0),
             folder("NodeSpawns", homestead_spawns),
         ],
         visuals=[
             visual_part("Ground", (HOMESTEAD_SIZE, 10, HOMESTEAD_SIZE), (0, GROUND_TOP - 5.02, 0), rgb(106, 127, 63), "Grass"),
             visual_part("Underside", (HOMESTEAD_SIZE - 40, 30, HOMESTEAD_SIZE - 40), (0, GROUND_TOP - 25, 0), rgb(99, 95, 98), "Slate"),
             decor_part("Rock1", (10, 7, 9), (-30, GROUND_TOP + 3.5, 25), rgb(120, 118, 115), "Slate", yaw=20),
             decor_part("Rock2", (7, 5, 8), (35, GROUND_TOP + 2.5, -15), rgb(120, 118, 115), "Slate", yaw=-35),
             decor_part("Tree1Trunk", (2, 12, 2), (-80, GROUND_TOP + 6, 70), rgb(105, 64, 40), "Wood"),
             decor_part("Tree1Top", (10, 8, 10), (-80, GROUND_TOP + 15, 70), rgb(75, 151, 75), "Grass"),
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

# Walkable bridge from Homestead's north edge to the Reaches' south edge.
z_start = -HOMESTEAD_SIZE / 2
z_end = rz + REACHES_SIZE / 2
length = z_start - z_end
mid = (z_start + z_end) / 2
template(WORLD_DIR, "Bridge",
         children=[hitbox_part("Hitbox", (12, 1, length), (0, GROUND_TOP - 0.5, mid))],
         visuals=[
             visual_part("Deck", (12, 1, length), (0, GROUND_TOP - 0.52, mid), rgb(124, 92, 70), "WoodPlanks"),
             decor_part("RailLeft", (1, 3, length), (-6.5, GROUND_TOP + 1.5, mid), rgb(91, 93, 105), "Metal"),
             decor_part("RailRight", (1, 3, length), (6.5, GROUND_TOP + 1.5, mid), rgb(91, 93, 105), "Metal"),
         ])


# ── Player plots (step 4) ───────────────────────────────────────────────────
# 02-core-loop.md § World Structure: the Homestead Ring holds player plots.
# One small floating island per plot, in an arc around the Homestead (the
# north side is left free for the Reaches bridge), each with its own bridge.
# PLOT_COUNT and PLOT_SIZE must match Config.Plots (Count, SizeStuds).
PLOT_COUNT = 8        # [PH] invented
PLOT_SIZE = 48        # [PH] invented: 12 x 12 cells of 4 studs
PLOT_RING = 200       # [PH] invented: studs from the Homestead centre
PLOT_ARC = (-30.0, 210.0)  # degrees; x = cos, z = sin, so north (-z) = 270 stays free

PLOTS_DIR = os.path.join(WORLD_DIR, "Plots")
remove_old(os.path.join(WORLD_DIR, "Plots.model.json"))
write(os.path.join(PLOTS_DIR, "init.meta.json"), {"className": "Model"})

lo, hi = PLOT_ARC
for i in range(PLOT_COUNT):
    index = i + 1
    angle = lo + (hi - lo) * i / (PLOT_COUNT - 1)
    a = math.radians(angle)
    cx, cz = round(PLOT_RING * math.cos(a), 2), round(PLOT_RING * math.sin(a), 2)
    top = GROUND_TOP
    template(PLOTS_DIR, f"Plot{index}", tags=["Plot"], attributes={"PlotIndex": index},
             children=[hitbox_part("Hitbox", (PLOT_SIZE, 2, PLOT_SIZE), (cx, top - 1, cz))],
             visuals=[
                 visual_part("Ground", (PLOT_SIZE, 2, PLOT_SIZE), (cx, top - 1.02, cz), rgb(120, 140, 80), "Grass"),
                 visual_part("Underside", (PLOT_SIZE - 10, 16, PLOT_SIZE - 10), (cx, top - 10, cz), rgb(99, 95, 98), "Slate"),
                 visual_part("Marker", (4, 0.2, 4), (cx, top + 0.1, cz), rgb(200, 200, 90), "Neon"),
             ])

    # Bridge: where the radial line leaves the square Homestead to where it
    # meets the (axis-aligned) plot's near edge.
    dx, dz = math.cos(a), math.sin(a)
    start = (HOMESTEAD_SIZE / 2) / max(abs(dx), abs(dz)) - 2  # overlap so there's no gap
    end = PLOT_RING - (PLOT_SIZE / 2) / max(abs(dx), abs(dz)) + 2
    blen = end - start
    bmid = (start + end) / 2
    yaw = 90 - angle  # a part's length runs along local Z; yaw a points it at (sin a, cos a)
    bpos = (round(dx * bmid, 2), GROUND_TOP - 0.5, round(dz * bmid, 2))
    template(PLOTS_DIR, f"Bridge{index}",
             children=[hitbox_part("Hitbox", (8, 1, round(blen, 2)), bpos, yaw=yaw)],
             visuals=[visual_part("Deck", (8, 1, round(blen, 2)), (bpos[0], bpos[1] - 0.02, bpos[2]),
                                  rgb(124, 92, 70), "WoodPlanks", yaw=yaw)])


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
