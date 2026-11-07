"""World props: vegetation, vehicles, containers, clutter. Exports to assets/props.

Blender +Z up, model origin at ground centre. Proportions match the
collision volumes MapBase builds for each prop kind.

    blender -b -P tools/blender/build_props.py -- [ids...]
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.append(os.path.dirname(__file__))
import gunlib as g  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "props")
R = math.radians


def M():
    return {
        "bark": g.material("Bark", (0.2, 0.13, 0.08), 0.0, 0.9),
        "leaf": g.material("Leaves", (0.16, 0.26, 0.09), 0.0, 0.8),
        "leaf_dry": g.material("LeavesDry", (0.3, 0.32, 0.12), 0.0, 0.85),
        "pine": g.material("PineNeedles", (0.08, 0.17, 0.1), 0.0, 0.85),
        "paint_red": g.material("CarRed", (0.45, 0.04, 0.03), 0.5, 0.3),
        "paint_blue": g.material("CarBlue", (0.05, 0.14, 0.35), 0.5, 0.3),
        "paint_white": g.material("CarWhite", (0.75, 0.75, 0.73), 0.4, 0.35),
        "paint_tan": g.material("CarTan", (0.55, 0.47, 0.32), 0.3, 0.45),
        "rust": g.material("Rust", (0.3, 0.13, 0.06), 0.3, 0.9),
        "glass": g.material("CarGlass", (0.05, 0.08, 0.1), 0.9, 0.05),
        "tire": g.material("Tire", (0.03, 0.03, 0.03), 0.0, 0.9),
        "chrome": g.material("Chrome", (0.6, 0.6, 0.62), 1.0, 0.2),
        "dark": g.material("DarkMetal", (0.06, 0.06, 0.065), 0.7, 0.5),
        "wood": g.material("CrateWood", (0.42, 0.3, 0.16), 0.0, 0.85),
        "wood_dark": g.material("CrateWoodDark", (0.28, 0.19, 0.1), 0.0, 0.85),
        "steel": g.material("Steel", (0.35, 0.36, 0.37), 0.8, 0.45),
        "barrel_blue": g.material("BarrelBlue", (0.08, 0.2, 0.45), 0.4, 0.5),
        "barrel_red": g.material("BarrelRed", (0.5, 0.08, 0.05), 0.4, 0.55),
        "olive": g.material("OliveDrab", (0.18, 0.2, 0.12), 0.2, 0.7),
        "sand": g.material("Sandbag", (0.55, 0.47, 0.32), 0.0, 1.0),
        "concrete": g.material("Concrete", (0.5, 0.49, 0.46), 0.0, 0.9),
        "green": g.material("DumpsterGreen", (0.1, 0.25, 0.14), 0.4, 0.6),
        "light": g.material("LampGlow", (1.0, 0.85, 0.6), 0.0, 0.3, emission=(1.0, 0.8, 0.5)),
        "canvas_r": g.material("CanvasRed", (0.5, 0.1, 0.08), 0.0, 0.95),
        "canvas_b": g.material("CanvasBlue", (0.12, 0.22, 0.42), 0.0, 0.95),
        "canvas_t": g.material("CanvasTan", (0.65, 0.56, 0.4), 0.0, 0.95),
        "rock": g.material("Rock", (0.4, 0.38, 0.34), 0.0, 0.95),
    }


def blob(name, radius, loc, mat, seed, detail=2, squash=1.0):
    """Irregular rounded blob: icosphere with noise displacement."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=detail, radius=radius)
    rnd = random.Random(seed)
    for v in bm.verts:
        n = v.co.normalized()
        v.co += n * radius * (rnd.random() - 0.5) * 0.35
        v.co.z *= squash
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    obj.data.materials.append(mat)
    for p in obj.data.polygons:
        p.use_smooth = False
    return obj


# --- Vegetation ------------------------------------------------------------------

def tree():
    m = M()
    trunk = g.cyl("Trunk", 0.22, 3.6, (0, 0, 1.8), m["bark"], axis="Z", verts=10, radius2=0.14)
    for i, (a, h, l) in enumerate([(0, 2.6, 1.4), (2.1, 3.0, 1.2), (4.0, 3.3, 1.1)]):
        b = g.cyl("Branch%d" % i, 0.07, l, (math.cos(a) * l * 0.4, math.sin(a) * l * 0.4, h), m["bark"], verts=6, radius2=0.03,
                  rot=(R(55) * math.sin(a), R(55) * -math.cos(a), 0))
    rnd = random.Random(random.random())
    for i in range(9):
        a = rnd.random() * math.tau
        d = rnd.uniform(0.3, 1.5)
        blob("Leaves%d" % i, rnd.uniform(0.9, 1.4), (math.cos(a) * d, math.sin(a) * d, rnd.uniform(3.6, 5.0)), m["leaf"] if i % 3 else m["leaf_dry"], i, 2, 0.75)


def pine():
    m = M()
    g.cyl("Trunk", 0.2, 6.5, (0, 0, 3.25), m["bark"], axis="Z", verts=8, radius2=0.05)
    for i in range(6):
        r = 2.1 - i * 0.32
        z = 1.6 + i * 0.95
        cone = g.cyl("Tier%d" % i, r, 1.6, (0, 0, z + 0.6), m["pine"], axis="Z", verts=9, radius2=0.05)
        for v in cone.data.vertices:
            if v.co.z < 0:
                v.co.z += random.Random(i * 31 + int(v.co.x * 100)).uniform(-0.25, 0.1)


def bush():
    m = M()
    for i in range(4):
        blob("Bush%d" % i, 0.6 + i * 0.05, ((i % 2) * 0.5 - 0.25, (i // 2) * 0.5 - 0.25, 0.45), m["leaf"], 40 + i, 2, 0.7)


def rock():
    m = M()
    blob("Rock", 1.2, (0, 0, 0.5), m["rock"], random.randint(0, 999), 2, 0.6).scale = (1.1, 0.85, 1.0)
    blob("RockB", 0.6, (0.9, 0.4, 0.25), m["rock"], 10, 1, 0.7)


# --- Vehicles --------------------------------------------------------------------

def sedan(paint, wrecked=False):
    m = M()
    body = m[paint] if not wrecked else m["rust"]
    # Lower body (Blender Y = car length)
    g.profile("Body", [(-2.2, 0.35), (2.2, 0.35), (2.25, 0.75), (1.4, 0.85), (-1.9, 0.88), (-2.22, 0.75)], 1.82, (0, 0, 0), body, 0.06)
    g.profile("Cabin", [(-1.25, 0.86), (1.15, 0.86), (0.55, 1.4), (-0.95, 1.42)] if not wrecked else [(-1.25, 0.86), (1.15, 0.86), (0.55, 1.15), (-0.95, 1.2)], 1.62, (0, 0, 0), body, 0.05)
    if not wrecked:
        g.profile("Windows", [(-1.18, 0.9), (1.06, 0.9), (0.52, 1.36), (-0.92, 1.38)], 1.66, (0, 0, 0), m["glass"], 0.01)
    for x in (-0.86, 0.86):
        for y in (-1.38, 1.4):
            g.cyl("Wheel", 0.34, 0.24, (x, y, 0.34), m["tire"], axis="X", verts=20)
            g.cyl("Hub", 0.2, 0.25, (x, y, 0.34), m["chrome"] if not wrecked else m["rust"], axis="X", verts=12)
    g.box("BumperF", (1.84, 0.15, 0.2), (0, 2.24, 0.45), m["chrome"] if not wrecked else m["dark"], 0.03)
    g.box("BumperR", (1.84, 0.15, 0.2), (0, -2.24, 0.45), m["chrome"] if not wrecked else m["dark"], 0.03)
    for x in (-0.65, 0.65):
        g.box("Headlight", (0.32, 0.04, 0.14), (x, 2.23, 0.68), m["light"] if not wrecked else m["dark"], 0.02)
        g.box("Taillight", (0.3, 0.04, 0.12), (x, -2.23, 0.7), m["paint_red"], 0.02)
    if wrecked:
        # Burnt interior and a crumpled bonnet.
        g.box("Interior", (1.5, 2.0, 0.3), (0, -0.1, 0.95), m["dark"], 0.05)
        g.box("Bonnet", (1.7, 1.0, 0.08), (0.1, 1.5, 0.95), m["rust"], 0.02, rot=(R(-12), R(6), 0))


def car():
    sedan(random.choice(["paint_red", "paint_blue", "paint_white", "paint_tan"]))


def car_wreck():
    sedan("paint_red", True)


def container():
    m = M()
    col = random.choice([g.material("ContRed", (0.45, 0.1, 0.07), 0.5, 0.6), g.material("ContBlue", (0.1, 0.22, 0.42), 0.5, 0.6),
                         g.material("ContGreen", (0.12, 0.3, 0.18), 0.5, 0.6), g.material("ContYellow", (0.65, 0.48, 0.1), 0.5, 0.6)])
    g.box("Box", (2.44, 6.06, 2.59), (0, 0, 1.295), col, 0.03)
    for i in range(24):
        y = -2.9 + i * 0.25
        for x in (-1.23, 1.23):
            g.box("Rib", (0.04, 0.12, 2.35), (x, y, 1.3), col, 0.01)
    for x in (-1.15, 1.15):
        for y in (-2.98, 2.98):
            for z in (0.08, 2.5):
                g.box("Corner", (0.18, 0.18, 0.18), (x, y, z), m["dark"], 0.01)
    for x in (-0.45, 0.45):
        g.box("DoorBar", (0.05, 0.05, 2.4), (x, 3.04, 1.3), m["steel"], 0.01)


def crate():
    m = M()
    g.box("Crate", (1.2, 1.2, 1.2), (0, 0, 0.6), m["wood"], 0.02)
    for z in (0.08, 1.12):
        for s in ((0, 0.61), (0, -0.61)):
            g.box("Plank", (1.24, 0.03, 0.14), (s[0], s[1], z), m["wood_dark"], 0.01)
        for s in ((0.61, 0), (-0.61, 0)):
            g.box("Plank", (0.03, 1.24, 0.14), (s[0], s[1], z), m["wood_dark"], 0.01)
    for s in (0.61, -0.61):
        g.box("Diag", (0.03, 1.5, 0.12), (s, 0, 0.6), m["wood_dark"], 0.01, rot=(R(45), 0, 0))


def crate_small():
    crate()
    for o in bpy.context.scene.objects:
        o.scale = (0.667, 0.667, 0.667)
        o.location = o.location * 0.667


def barrel():
    m = M()
    mat = random.choice([m["barrel_blue"], m["barrel_red"], m["rust"]])
    g.cyl("Barrel", 0.3, 0.9, (0, 0, 0.45), mat, axis="Z", verts=24)
    for z in (0.15, 0.45, 0.75):
        g.cyl("Hoop", 0.31, 0.04, (0, 0, z), m["dark"], axis="Z", verts=24)
    g.cyl("Cap", 0.05, 0.02, (0.15, 0, 0.91), m["dark"], axis="Z", verts=12)


def dumpster():
    m = M()
    g.profile("Body", [(-0.6, 0.15), (0.6, 0.15), (0.6, 1.25), (-0.6, 1.1)], 2.0, (0, 0, 0), m["green"], 0.03)
    g.box("Lid", (2.05, 1.25, 0.05), (0, 0, 1.2), m["dark"], 0.01, rot=(R(-7), 0, 0))
    for x in (-0.85, 0.85):
        for y in (-0.45, 0.45):
            g.cyl("Caster", 0.08, 0.06, (x, y, 0.08), m["tire"], axis="X")


def sandbags():
    m = M()
    for row in range(3):
        n = 6 - row
        for i in range(n):
            x = (i - (n - 1) / 2) * 0.42
            bag = g.box("Bag", (0.44, 0.6, 0.3), (x, 0, 0.15 + row * 0.28), m["sand"], 0.08)
            mod = bag.modifiers.new("Sub", "SUBSURF")
            mod.levels = 1


def barrier():
    m = M()
    g.profile("Jersey", [(-0.4, 0.0), (0.4, 0.0), (0.25, 0.25), (0.12, 0.9), (-0.12, 0.9), (-0.25, 0.25)], 2.0, (0, 0, 0), m["concrete"], 0.02)


def lamp():
    m = M()
    g.cyl("Pole", 0.08, 5.0, (0, 0, 2.5), m["steel"], axis="Z", verts=12, radius2=0.05)
    g.cyl("Base", 0.16, 0.4, (0, 0, 0.2), m["steel"], axis="Z", verts=12)
    g.box("Arm", (0.06, 0.9, 0.06), (0, 0.4, 4.95), m["steel"], 0.01)
    g.box("Head", (0.3, 0.5, 0.12), (0, 0.85, 4.9), m["dark"], 0.02)
    g.box("Glow", (0.24, 0.4, 0.02), (0, 0.85, 4.83), m["light"], 0.0)


def pallets():
    m = M()
    for i in range(4):
        for j in range(5):
            g.box("Slat", (1.2, 0.14, 0.02), (0, -0.43 + j * 0.215, 0.13 + i * 0.15), m["wood"], 0.003, rot=(0, 0, R(i * 3)))
        for x in (-0.55, 0, 0.55):
            g.box("Block", (0.1, 1.0, 0.1), (x, 0, 0.07 + i * 0.15), m["wood_dark"], 0.005, rot=(0, 0, R(i * 3)))


def tires():
    m = M()
    for i in range(3):
        t = g.cyl("Tire", 0.4, 0.24, (i * 0.05, 0, 0.12 + i * 0.25), m["tire"], axis="Z", verts=20)


def stall():
    m = M()
    canvas = random.choice([m["canvas_r"], m["canvas_b"], m["canvas_t"]])
    for x in (-1.2, 1.2):
        for y in (-1.0, 1.0):
            g.cyl("Post", 0.05, 2.5, (x, y, 1.25), m["wood_dark"], axis="Z", verts=8)
    awn = g.box("Awning", (2.9, 2.5, 0.04), (0, 0, 2.45), canvas, 0.01, rot=(R(6), 0, 0))
    g.box("Counter", (2.4, 0.8, 0.9), (0, 0.6, 0.45), m["wood"], 0.02)
    rnd = random.Random(5)
    for i in range(6):
        g.box("Goods", (0.3, 0.25, 0.2), (-0.9 + i * 0.35, 0.6, 1.0), random.choice([m["canvas_t"], m["wood"], m["barrel_red"]]), 0.03)


def water_tower():
    m = M()
    for x in (-1.5, 1.5):
        for y in (-1.5, 1.5):
            g.cyl("Leg", 0.15, 8.0, (x, y, 4.0), m["rust"], axis="Z", verts=8)
    for z in (2.5, 5.5):
        for rot in (0, 90):
            g.box("Brace", (3.2, 0.08, 0.08), (0, 0, z), m["rust"], 0.01, rot=(0, R(30), R(rot)))
    g.cyl("Tank", 2.4, 3.5, (0, 0, 9.75), m["rust"], axis="Z", verts=24)
    g.cyl("Roof", 2.5, 0.8, (0, 0, 11.9), m["rust"], axis="Z", verts=24, radius2=0.2)


PROPS = {
    "tree": tree, "pine": pine, "bush": bush, "rock": rock, "car": car, "car_wreck": car_wreck,
    "container": container, "crate": crate, "crate_small": crate_small, "barrel": barrel, "dumpster": dumpster,
    "sandbags": sandbags, "barrier": barrier, "lamp": lamp, "pallets": pallets, "tires": tires,
    "stall": stall, "water_tower": water_tower,
}


VARIANTS = {"car": 4, "container": 4, "barrel": 3, "stall": 3, "tree": 3, "pine": 2, "rock": 2}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    os.makedirs(OUT, exist_ok=True)
    random.seed(11)
    for name, fn in PROPS.items():
        if argv and name not in argv:
            continue
        for v in range(1, VARIANTS.get(name, 1) + 1):
            g.reset_scene()
            random.seed(hash(name) % 1000 + v * 17)
            try:
                fn()
                suffix = "_%d" % v if name in VARIANTS else ""
                g.export(os.path.join(OUT, name + suffix + ".glb"))
                print("BUILT", name + suffix)
            except Exception as e:
                import traceback
                traceback.print_exc()
                print("FAILED", name, e)


main()
