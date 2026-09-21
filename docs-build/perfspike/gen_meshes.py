#!/usr/bin/env python3
"""Generates the stand-in mesh kit for the mobile performance spike (build step 0B).

Throwaway: delete docs-build/perfspike/ when the spike is done.

Why this exists: the spike must test REAL triangle counts on a phone
(docs/13-build-guide.md § Part A, "one exception"). Roblox can't make
arbitrary-triangle meshes from a script in a way that replicates to clients,
so we generate .obj files here, you import them once in Studio, and the
spike clones them. Every file's triangle count is exact and asserted below.

Usage:  python3 gen_meshes.py        (writes ./meshes/*.obj and manifest.json)

Keep TRIS in sync with Config.PerfSpike.Kit in src/shared/Config.luau.
"""

import json
import math
import os
import random

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "meshes")

Vec = tuple  # (x, y, z)


def sub(a: Vec, b: Vec) -> Vec:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def cross(a: Vec, b: Vec) -> Vec:
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a: Vec, b: Vec) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


class Mesh:
    def __init__(self) -> None:
        self.verts: list[Vec] = []
        self._index: dict[Vec, int] = {}
        self.tris: list[tuple[int, int, int]] = []

    def vert(self, p: Vec) -> int:
        key = (round(p[0], 5), round(p[1], 5), round(p[2], 5))
        found = self._index.get(key)
        if found is None:
            found = len(self.verts)
            self.verts.append(key)
            self._index[key] = found
        return found

    def tri(self, a: Vec, b: Vec, c: Vec) -> None:
        self.tris.append((self.vert(a), self.vert(b), self.vert(c)))

    def orient_outward(self) -> None:
        """Flip any triangle whose normal points toward the origin.

        All our shapes are star-shaped around the origin, so this is enough to
        make winding consistent (a wrongly wound triangle is invisible in Roblox).
        """
        fixed = []
        for (a, b, c) in self.tris:
            va, vb, vc = self.verts[a], self.verts[b], self.verts[c]
            normal = cross(sub(vb, va), sub(vc, va))
            centroid = ((va[0] + vb[0] + vc[0]) / 3, (va[1] + vb[1] + vc[1]) / 3, (va[2] + vb[2] + vc[2]) / 3)
            fixed.append((a, b, c) if dot(normal, centroid) >= 0 else (a, c, b))
        self.tris = fixed

    def recenter(self) -> None:
        """Bounding-box centre -> origin, so MeshPart placement is unambiguous."""
        mins = [min(v[i] for v in self.verts) for i in range(3)]
        maxs = [max(v[i] for v in self.verts) for i in range(3)]
        centre = [(mins[i] + maxs[i]) / 2 for i in range(3)]
        self.verts = [(v[0] - centre[0], v[1] - centre[1], v[2] - centre[2]) for v in self.verts]

    def signed_volume(self) -> float:
        total = 0.0
        for (a, b, c) in self.tris:
            total += dot(self.verts[a], cross(self.verts[b], self.verts[c]))
        return total / 6


# ── Shapes. Each returns a Mesh with EXACTLY the requested triangle count. ──


def uv_sphere(segments: int, rings: int, shape) -> Mesh:
    """tris = 2 * segments * (rings - 1). `shape(x,y,z,i,j)` may deform a unit-sphere point."""
    m = Mesh()

    def point(i: int, j: int) -> Vec:
        theta = math.pi * j / rings  # 0..pi, pole to pole
        phi = 2 * math.pi * (i % segments) / segments
        x, y, z = math.sin(theta) * math.cos(phi), math.cos(theta), math.sin(theta) * math.sin(phi)
        return shape(x, y, z, i, j)

    for i in range(segments):
        m.tri(point(0, 0), point(i + 1, 1), point(i, 1))  # top fan
        m.tri(point(i, rings - 1), point(i + 1, rings - 1), point(0, rings))  # bottom fan
        for j in range(1, rings - 1):
            a, b, c, d = point(i, j), point(i + 1, j), point(i + 1, j + 1), point(i, j + 1)
            m.tri(a, b, c)
            m.tri(a, c, d)
    assert len(m.tris) == 2 * segments * (rings - 1)
    return m


def cylinder(segments: int, bands: int, radius_at) -> Mesh:
    """tris = 2 * segments * (bands + 1). `radius_at(t)` with t in 0..1 bottom->top."""
    m = Mesh()

    def ring(i: int, t: float) -> Vec:
        phi = 2 * math.pi * (i % segments) / segments
        r = radius_at(t)
        return (r * math.cos(phi), t - 0.5, r * math.sin(phi))

    bottom, top = (0.0, -0.5, 0.0), (0.0, 0.5, 0.0)
    for i in range(segments):
        m.tri(bottom, ring(i, 0), ring(i + 1, 0))
        m.tri(top, ring(i + 1, 1), ring(i, 1))
        for j in range(bands):
            t0, t1 = j / bands, (j + 1) / bands
            a, b, c, d = ring(i, t0), ring(i + 1, t0), ring(i + 1, t1), ring(i, t1)
            m.tri(a, b, c)
            m.tri(a, c, d)
    assert len(m.tris) == 2 * segments * (bands + 1)
    return m


def box_grid(nx: int, ny: int, nz: int) -> Mesh:
    """tris = 4 * (nx*ny + ny*nz + nz*nx). Unit box subdivided per face."""
    m = Mesh()

    def face(n_u: int, n_v: int, place) -> None:
        for u in range(n_u):
            for v in range(n_v):
                p = lambda uu, vv: place(uu / n_u, vv / n_v)
                m.tri(p(u, v), p(u + 1, v), p(u + 1, v + 1))
                m.tri(p(u, v), p(u + 1, v + 1), p(u, v + 1))

    face(nx, ny, lambda a, b: (a - 0.5, b - 0.5, 0.5))
    face(nx, ny, lambda a, b: (a - 0.5, b - 0.5, -0.5))
    face(nz, ny, lambda a, b: (0.5, b - 0.5, a - 0.5))
    face(nz, ny, lambda a, b: (-0.5, b - 0.5, a - 0.5))
    face(nx, nz, lambda a, b: (a - 0.5, 0.5, b - 0.5))
    face(nx, nz, lambda a, b: (a - 0.5, -0.5, b - 0.5))
    assert len(m.tris) == 4 * (nx * ny + ny * nz + nz * nx)
    return m


def find_box(target: int, aspect: tuple) -> tuple:
    """Integer (nx,ny,nz) with 4*(nx*ny+ny*nz+nz*nx) == target, closest to `aspect`."""
    ax, ay, az = aspect
    best, best_err = None, 1e9
    for nx in range(1, 90):
        for ny in range(1, 90):
            rest = target / 4 - nx * ny
            if rest <= 0 or rest % (nx + ny) != 0:
                continue
            nz = int(rest / (nx + ny))
            if nz < 1:
                continue
            err = abs(math.log(nx / ny) - math.log(ax / ay)) + abs(math.log(nz / ny) - math.log(az / ay))
            if err < best_err:
                best, best_err = (nx, ny, nz), err
    if best is None:
        raise SystemExit(f"no box grid gives exactly {target} triangles for aspect {aspect}")
    return best


# ── Piece definitions (name, target triangles). Match Config.PerfSpike.Kit. ──


def island(rng: random.Random) -> Mesh:
    """Floating rock: flat-ish top, tapering underside, lumpy. 5000 tris."""
    phase = [rng.uniform(0, math.tau) for _ in range(4)]

    def shape(x: float, y: float, z: float, i: int, j: int) -> Vec:
        lump = 1 + 0.08 * math.sin(3 * math.atan2(z, x) + phase[0]) * (1 - abs(y)) + 0.05 * math.sin(7 * y + phase[1])
        if y >= 0:
            return (x * lump, y * 0.12, z * lump)  # near-flat top surface
        taper = 1 + 0.75 * y  # y is negative: narrows toward the bottom point
        return (x * lump * taper, y * 0.9, z * lump * taper)

    return uv_sphere(50, 51, shape)


def vault_core() -> Mesh:
    """Ridged drum. 4000 tris."""
    return cylinder(40, 49, lambda t: 0.5 + 0.04 * math.sin(t * 40) + (0.05 if 0.2 < t < 0.3 else 0))


def defense() -> Mesh:
    """Tapered tower. 800 tris."""
    return cylinder(20, 19, lambda t: 0.5 - 0.15 * t)


def decor(rng: random.Random) -> Mesh:
    """Boulder. 400 tris."""
    phase = rng.uniform(0, math.tau)
    return uv_sphere(20, 11, lambda x, y, z, i, j: tuple(c * (1 + 0.1 * math.sin(5 * x + 3 * y + phase)) * 0.5 for c in (x, y, z)))


def node(rng: random.Random) -> Mesh:
    """Crystal-ish rock. 300 tris."""
    phase = rng.uniform(0, math.tau)
    return uv_sphere(15, 11, lambda x, y, z, i, j: (x * 0.4 * (1 + 0.2 * math.sin(4 * y + phase)), y * 0.5, z * 0.4 * (1 + 0.2 * math.sin(4 * y + phase))))


def make_kit() -> dict:
    rng = random.Random(1337)
    return {
        "Island": (5000, island(rng)),
        "Vault": (4000, vault_core()),
        "Wall": (500, box_grid(*find_box(500, (8, 5, 1)))),
        "Gate": (1000, box_grid(*find_box(1000, (8, 7, 2)))),
        "Defense": (800, defense()),
        "Workshop": (2500, box_grid(*find_box(2500, (10, 6, 8)))),
        "Decor": (400, decor(rng)),
        "Node": (300, node(rng)),
    }


def write_obj(path: str, mesh: Mesh) -> None:
    with open(path, "w") as f:
        f.write("# Vaultbreakers perf spike stand-in (throwaway)\n")
        for (x, y, z) in mesh.verts:
            f.write(f"v {x:.5f} {y:.5f} {z:.5f}\n")
        for (x, y, z) in mesh.verts:  # simple planar UVs so the importer has some
            f.write(f"vt {x % 1.0:.4f} {z % 1.0:.4f}\n")
        for (a, b, c) in mesh.tris:
            f.write(f"f {a + 1}/{a + 1} {b + 1}/{b + 1} {c + 1}/{c + 1}\n")


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    manifest = {}
    for name, (target, mesh) in make_kit().items():
        mesh.orient_outward()
        mesh.recenter()
        assert len(mesh.tris) == target, f"{name}: {len(mesh.tris)} != {target}"
        volume = mesh.signed_volume()
        assert volume > 0, f"{name}: triangles wound inward (volume {volume})"
        path = os.path.join(OUT_DIR, f"spike_{name.lower()}.obj")
        write_obj(path, mesh)
        with open(path) as f:
            written = sum(1 for line in f if line.startswith("f "))
        assert written == target, f"{name}: file has {written} faces, wanted {target}"
        manifest[name] = {"file": os.path.basename(path), "triangles": written, "vertices": len(mesh.verts)}
        print(f"{name:9s} {written:5d} tris  {len(mesh.verts):5d} verts  -> {os.path.basename(path)}")
    with open(os.path.join(OUT_DIR, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2)


if __name__ == "__main__":
    main()
