#!/usr/bin/env python3
"""Generates the greybox world + node templates as Rojo .model.json files.

Run from the repo root:  python3 docs-build/worldgen/gen_world.py
Outputs (overwritten every run - edit THIS file, not the JSON):
  src/world/*.model.json                -> Workspace.World (Rojo)
  src/assets/NodeTemplates/*.model.json -> ServerStorage.NodeTemplates
  src/assets/PieceTemplates/*.model.json -> ServerStorage.PieceTemplates

Step 2 (nodes), step 4 (plots + base pieces) (docs/13-build-guide.md § Part E). Placeholder parts only (greybox
contract, CLAUDE.md). All positions/sizes are [PH] invented layout.
"""
import json
import math
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
WORLD_DIR = os.path.join(ROOT, "src", "world")
TEMPLATE_DIR = os.path.join(ROOT, "src", "assets", "NodeTemplates")
PIECE_DIR = os.path.join(ROOT, "src", "assets", "PieceTemplates")

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


# ── Islands ─────────────────────────────────────────────────────────────────

HOMESTEAD_C = (0, 0)
HOMESTEAD_SIZE = 220
REACHES_C = (0, -430)
REACHES_SIZE = 150

homestead_spawns = []
for i, (x, z) in enumerate(ring(8, 60, *HOMESTEAD_C, start_deg=112.5)):
    homestead_spawns.append(spawn_point(f"Stone{i + 1}", x, z, "Stone"))
for i, (x, z) in enumerate(ring(4, 88, *HOMESTEAD_C, start_deg=225)):
    homestead_spawns.append(spawn_point(f"Ore{i + 1}", x, z, "Ore"))

homestead = {
    "className": "Model",
    "attributes": {"Zone": "Homestead"},
    "children": [
        part("Ground", (HOMESTEAD_SIZE, 10, HOMESTEAD_SIZE), (0, GROUND_TOP - 5, 0), rgb(106, 127, 63), "Grass"),
        part("Underside", (HOMESTEAD_SIZE - 40, 30, HOMESTEAD_SIZE - 40), (0, GROUND_TOP - 25, 0), rgb(99, 95, 98), "Slate"),
        part("SpawnLocation", (8, 1, 8), (0, GROUND_TOP + 0.5, 70), rgb(163, 162, 165), cls="SpawnLocation",
             Neutral=True, Duration=0),
        part("Rock1", (10, 7, 9), (-30, GROUND_TOP + 3.5, 25), rgb(120, 118, 115), "Slate", yaw=20),
        part("Rock2", (7, 5, 8), (35, GROUND_TOP + 2.5, -15), rgb(120, 118, 115), "Slate", yaw=-35),
        part("Tree1Trunk", (2, 12, 2), (-80, GROUND_TOP + 6, 70), rgb(105, 64, 40), "Wood"),
        part("Tree1Top", (10, 8, 10), (-80, GROUND_TOP + 15, 70), rgb(75, 151, 75), "Grass"),
        {"name": "NodeSpawns", "className": "Folder", "children": homestead_spawns},
    ],
}

rx, rz = REACHES_C
reaches_spawns = []
for i, (x, z) in enumerate(ring(6, 55, rx, rz, start_deg=0)):
    reaches_spawns.append(spawn_point(f"Ore{i + 1}", x, z, "Ore"))
for i, (x, z) in enumerate(ring(5, 28, rx, rz, start_deg=36)):
    reaches_spawns.append(spawn_point(f"Riftsalt{i + 1}", x, z, "Riftsalt"))

reaches = {
    "className": "Model",
    "attributes": {"Zone": "Reaches"},
    "children": [
        part("Ground", (REACHES_SIZE, 10, REACHES_SIZE), (rx, GROUND_TOP - 5, rz), rgb(86, 66, 54), "Ground"),
        part("Underside", (REACHES_SIZE - 30, 40, REACHES_SIZE - 30), (rx, GROUND_TOP - 30, rz), rgb(60, 55, 65), "Basalt"),
        part("Spire1", (6, 26, 6), (rx - 62, GROUND_TOP + 13, rz - 60), rgb(70, 60, 80), "Basalt", yaw=15),
        part("Spire2", (5, 18, 5), (rx + 64, GROUND_TOP + 9, rz - 55), rgb(70, 60, 80), "Basalt", yaw=-20),
        {"name": "NodeSpawns", "className": "Folder", "children": reaches_spawns},
    ],
}


# ── Player plots (step 4) ───────────────────────────────────────────────────
# 02-core-loop.md § World Structure: the Homestead Ring holds player plots.
# One small floating island per plot, in an arc around the Homestead (the
# north side is left free for the Reaches bridge), each with its own bridge.
# PLOT_COUNT and PLOT_SIZE must match Config.Plots (Count, SizeStuds).
# Greybox contract: Hitbox = the build/walk surface code uses; Visual = looks.
PLOT_COUNT = 8        # [PH] invented
PLOT_SIZE = 48        # [PH] invented: 12 x 12 cells of 4 studs
PLOT_RING = 200       # [PH] invented: studs from the Homestead centre
PLOT_ARC = (-30.0, 210.0)  # degrees; x = cos, z = sin, so north (-z) = 270 stays free


def plot_model(index, cx, cz):
    top = GROUND_TOP
    hitbox = part("Hitbox", (PLOT_SIZE, 2, PLOT_SIZE), (cx, top - 1, cz), rgb(255, 0, 0),
                  Transparency=1, CanCollide=True, CanQuery=True, CanTouch=False, CastShadow=False)
    visuals = [
        visual_part("Ground", (PLOT_SIZE, 2, PLOT_SIZE), (cx, top - 1.02, cz), rgb(120, 140, 80), "Grass"),
        visual_part("Underside", (PLOT_SIZE - 10, 16, PLOT_SIZE - 10), (cx, top - 10, cz), rgb(99, 95, 98), "Slate"),
        visual_part("Marker", (4, 0.2, 4), (cx, top + 0.1, cz), rgb(200, 200, 90), "Neon"),
    ]
    return {
        "name": f"Plot{index}",
        "className": "Model",
        "attributes": {"PlotIndex": index},
        "properties": {"Tags": ["Plot"]},
        "children": [hitbox, {"name": "Visual", "className": "Folder", "children": visuals}],
    }


def plot_bridge(index, angle_deg):
    a = math.radians(angle_deg)
    dx, dz = math.cos(a), math.sin(a)
    # Where the radial line leaves the square Homestead, and where it meets
    # the (axis-aligned) plot's near edge.
    half_h = HOMESTEAD_SIZE / 2
    start = half_h / max(abs(dx), abs(dz))
    end = PLOT_RING - (PLOT_SIZE / 2) / max(abs(dx), abs(dz))
    start -= 2  # overlap each island slightly so there's no gap to fall in
    end += 2
    length = end - start
    mid = (start + end) / 2
    # A part's length runs along its local Z; yaw a points it at (sin a, cos a).
    yaw = 90 - angle_deg
    return part(f"Bridge{index}", (8, 1, round(length, 2)),
                (round(dx * mid, 2), GROUND_TOP - 0.5, round(dz * mid, 2)),
                rgb(124, 92, 70), "WoodPlanks", yaw=yaw)


plot_children = []
lo, hi = PLOT_ARC
for i in range(PLOT_COUNT):
    angle = lo + (hi - lo) * i / (PLOT_COUNT - 1)
    a = math.radians(angle)
    cx, cz = round(PLOT_RING * math.cos(a), 2), round(PLOT_RING * math.sin(a), 2)
    plot_children.append(plot_model(i + 1, cx, cz))
    plot_children.append(plot_bridge(i + 1, angle))
plots = {"className": "Model", "children": plot_children}

# Walkable bridge from Homestead's north edge to the Reaches' south edge.
z_start = -HOMESTEAD_SIZE / 2
z_end = rz + REACHES_SIZE / 2
length = z_start - z_end
mid = (z_start + z_end) / 2
bridge = {
    "className": "Model",
    "children": [
        part("Deck", (12, 1, length), (0, GROUND_TOP - 0.5, mid), rgb(124, 92, 70), "WoodPlanks"),
        part("RailLeft", (1, 3, length), (-6.5, GROUND_TOP + 1.5, mid), rgb(91, 93, 105), "Metal"),
        part("RailRight", (1, 3, length), (6.5, GROUND_TOP + 1.5, mid), rgb(91, 93, 105), "Metal"),
    ],
}

write(os.path.join(WORLD_DIR, "Homestead.model.json"), homestead)
write(os.path.join(WORLD_DIR, "Reaches.model.json"), reaches)
write(os.path.join(WORLD_DIR, "Bridge.model.json"), bridge)
write(os.path.join(WORLD_DIR, "Plots.model.json"), plots)

# ── Node templates (greybox contract: Hitbox + Visual) ─────────────────────
# Pivot/Hitbox sit at the origin, bottom at Y=0; NodeService moves the clone.
HITBOX = (5, 6, 5)


templates = {
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

for node_type, visuals in templates.items():
    hitbox = part("Hitbox", HITBOX, (0, HITBOX[1] / 2, 0), rgb(255, 0, 0),
                  Transparency=1, CanCollide=True, CanQuery=True, CanTouch=False, CastShadow=False)
    model = {
        "className": "Model",
        "attributes": {"NodeType": node_type},
        "properties": {"Tags": ["ResourceNode"]},
        "children": [hitbox, {"name": "Visual", "className": "Folder", "children": visuals}],
    }
    write(os.path.join(TEMPLATE_DIR, f"{node_type}Node.model.json"), model)

# ── Base piece templates (step 4; greybox contract: Hitbox + Visual) ────────
# Hitbox bottom at Y=0, centred on X/Z; PlotService moves the clone. The
# footprint in grid cells lives in Config.Base.Pieces (Cells); Hitbox sizes
# here must fit inside it. Budget cost / price are Config, not art.
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
}
PIECE_TAGS = {"Wall": ["BasePiece"], "Gate": ["BasePiece", "BaseGate"], "VaultCore": ["BasePiece", "VaultCore"]}

for kind, spec in PIECES.items():
    hb = spec["hitbox"]
    hitbox = part("Hitbox", hb, (0, hb[1] / 2, 0), rgb(255, 0, 0),
                  Transparency=1, CanCollide=True, CanQuery=True, CanTouch=False, CastShadow=False)
    model = {
        "className": "Model",
        "attributes": {"Kind": kind},
        "properties": {"Tags": PIECE_TAGS[kind]},
        "children": [hitbox, {"name": "Visual", "className": "Folder", "children": spec["visuals"]}],
    }
    write(os.path.join(PIECE_DIR, f"{kind}.model.json"), model)
