"""Soldier characters and first-person arms for both factions.

    blender -b -P tools/blender/build_characters.py -- [soldier] [arms] [sentinel] [militia]

Soldier: one skinned mesh on a 12-bone armature. The bones match the joints
that scripts/game/soldier_model.gd animates (Pelvis, Torso, Chest, Head,
ShoulderL/R, ElbowL/R, HipL/R, KneeL/R). The game copies each joint transform
onto its bone every frame, and onto the ragdoll bodies after death. The rest
pose is the rig's zero pose: standing, arms straight down.

Arms: first-person arms in weapon space (origin at the pistol grip, +Y to the
muzzle). ArmR holds the pistol grip. ArmL holds a handguard; its origin is the
LeftHand marker, so the game can put it on each weapon's marker. ArmLPistol is
the support hand for pistols.

Every limb is a loft of super-elliptical rings with per-ring bone weights, so
the deformation at each joint is smooth and fully controlled. Hands wrap
procedurally around a cylinder (grip or handguard). Textures are baked by
texlib: camouflage, fabric weave, MOLLE webbing, wrinkles, wear and grime.
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.append(os.path.dirname(__file__))
sys.path.append(os.path.join(os.path.dirname(__file__), ".."))
import gunlib as g  # noqa: E402
import texlib  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "characters")
R = math.radians

# Joint rest positions in Blender space (x right, y forward, z up).
JOINTS = {
    "Pelvis": ((0, 0, 0.95), None),
    "Torso": ((0, 0, 1.03), "Pelvis"),
    "Chest": ((0, 0, 1.55), "Torso"),
    "Head": ((0, 0, 1.73), "Torso"),
    "ShoulderL": ((-0.23, 0, 1.57), "Chest"),
    "ElbowL": ((-0.23, 0, 1.28), "ShoulderL"),
    "ShoulderR": ((0.23, 0, 1.57), "Chest"),
    "ElbowR": ((0.23, 0, 1.28), "ShoulderR"),
    "HipL": ((-0.11, 0, 0.89), "Pelvis"),
    "KneeL": ((-0.11, 0, 0.45), "HipL"),
    "HipR": ((0.11, 0, 0.89), "Pelvis"),
    "KneeR": ((0.11, 0, 0.45), "HipR"),
}

FACTIONS = {
    "sentinel": {
        "uniform": dict(color=(0.5, 0.45, 0.33), base2=(0.33, 0.35, 0.24), base3=(0.42, 0.33, 0.22), base4=(0.2, 0.18, 0.12), pattern=0),
        "gear": (0.4, 0.34, 0.24), "gear2": (0.33, 0.35, 0.25), "helmet": (0.38, 0.35, 0.26), "skin": (0.62, 0.44, 0.33),
        "boots": (0.42, 0.33, 0.22), "gloves": (0.3, 0.27, 0.2), "face": "gaiter",
    },
    "militia": {
        "uniform": dict(color=(0.26, 0.27, 0.28), base2=(0.16, 0.17, 0.18), base3=(0.38, 0.38, 0.37), base4=(0.08, 0.08, 0.09), pattern=1),
        "gear": (0.075, 0.075, 0.08), "gear2": (0.12, 0.12, 0.11), "helmet": (0.1, 0.1, 0.105), "skin": (0.52, 0.38, 0.29),
        "boots": (0.06, 0.06, 0.06), "gloves": (0.06, 0.06, 0.065), "face": "balaclava",
    },
}


# --- Materials -----------------------------------------------------------------

def _lin(c):
    """sRGB colour to the linear values that Blender materials use."""
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


def faction_mats(f):
    f = {k: (_lin(v) if isinstance(v, tuple) and len(v) == 3 else v) for k, v in f.items()}
    u = {k: (_lin(v) if isinstance(v, tuple) else v) for k, v in f["uniform"].items()}
    return {
        "uniform": g.material("Uniform", u["color"], 0.0, 0.88, kind="fabric", base2=u["base2"], base3=u["base3"], base4=u["base4"], pattern=u["pattern"]),
        "gear": g.material("Gear", f["gear"], 0.0, 0.85, kind="webbing"),
        "gear2": g.material("GearAlt", f["gear2"], 0.0, 0.85, kind="webbing", seed=2.0),
        "plain": g.material("Fabric", tuple(c * 0.9 for c in f["gear"]), 0.0, 0.9, kind="fabric", seed=4.0),
        "helmet": g.material("Helmet", f["helmet"], 0.0, 0.62, kind="paint", wear=0.8),
        "skin": g.material("Skin", f["skin"], 0.0, 0.5, kind="skin"),
        "boots": g.material("Boots", f["boots"], 0.0, 0.62, kind="leather"),
        "gloves": g.material("Gloves", f["gloves"], 0.0, 0.7, kind="leather", seed=3.0),
        "sole": g.material("Sole", (0.03, 0.03, 0.03), 0.0, 0.85, kind="rubber"),
        "kit": g.material("Kit", (0.03, 0.03, 0.032), 0.0, 0.55, kind="polymer"),
        "metal": g.material("Hardware", (0.08, 0.08, 0.085), 0.8, 0.4, kind="metal"),
        "lens": g.material("Lens", (0.06, 0.07, 0.05), 0.9, 0.06, kind="lens"),
        "balaclava": g.material("Balaclava", (0.05, 0.05, 0.055), 0.0, 0.92, kind="fabric", seed=5.0),
    }


# --- Geometry helpers ----------------------------------------------------------

def _frame(t, ref):
    t = Vector(t).normalized()
    y = Vector(ref) - t * Vector(ref).dot(t)
    if y.length < 1e-5:
        y = Vector((0, 0, 1)) - t * t.z
    y.normalize()
    x = t.cross(y)
    return x, y


def _ring_point(a, rx, ryf, ryb, pw):
    c, s = math.cos(a), math.sin(a)
    e = 2.0 / pw
    px = rx * math.copysign(abs(c) ** e, c)
    py = (ryf if s > 0 else ryb) * math.copysign(abs(s) ** e, s)
    return px, py


def loft(name, rings, mat, seg=20, ref=(0, 1, 0), cap0=True, cap1=True, subdiv=1, rigid=None):
    """Loft through rings. Each ring: dict(p=centre, rx, ry or ryf/ryb, pw=2,
    w={bone: weight}, rot=angle offset). Returns the object.
    The ring plane is perpendicular to the path; ring +y points along ref."""
    bm = bmesh.new()
    rows = []
    pts = [Vector(r["p"]) for r in rings]
    weights = []
    for i, r in enumerate(rings):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == len(rings) - 1:
            t = pts[-1] - pts[-2]
        else:
            t = pts[i + 1] - pts[i - 1]
        x, y = _frame(t, r.get("ref", ref))
        rx = r.get("rx", r.get("r"))
        ryf = r.get("ryf", r.get("ry", rx))
        ryb = r.get("ryb", r.get("ry", rx))
        pw = r.get("pw", 2.0)
        off = Vector(r.get("off", (0, 0, 0)))
        row = []
        for k in range(seg):
            a = 2 * math.pi * k / seg + r.get("rot", 0.0)
            px, py = _ring_point(a, rx, ryf, ryb, pw)
            row.append(bm.verts.new(pts[i] + off + x * px + y * py))
            weights.append(r.get("w", {rigid: 1.0} if rigid else {}))
        rows.append(row)
    for i in range(len(rows) - 1):
        a, b = rows[i], rows[i + 1]
        for k in range(seg):
            k2 = (k + 1) % seg
            bm.faces.new((a[k], a[k2], b[k2], b[k]))
    ends = []
    if cap0:
        ends.append((rows[0], rings[0], True))
    if cap1:
        ends.append((rows[-1], rings[-1], False))
    cap_w = []
    for row, r, first in ends:
        c = sum((v.co for v in row), Vector()) / len(row)
        cv = bm.verts.new(c)
        cap_w.append((cv, r.get("w", {rigid: 1.0} if rigid else {})))
        for k in range(seg):
            k2 = (k + 1) % seg
            f = (row[k2], row[k], cv) if first else (row[k], row[k2], cv)
            bm.faces.new(f)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.verts.index_update()
    vw = weights + [w for _, w in cap_w]
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for i, w in enumerate(vw):
        for bone, val in w.items():
            if bone is None or val <= 0:
                continue
            vg = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
            vg.add([i], val, "REPLACE")
    for p in obj.data.polygons:
        p.use_smooth = True
    if subdiv:
        m = obj.modifiers.new("Sub", "SUBSURF")
        m.levels = subdiv
        m.render_levels = subdiv
    return obj


def rigid(obj, bone):
    obj.vertex_groups.clear()
    vg = obj.vertex_groups.new(name=bone)
    vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    return obj


def rbox(name, size, loc, mat, bone, bevel=0.01, rot=(0, 0, 0), subdiv=0, taper=None):
    o = g.box(name, size, loc, mat, bevel, rot=rot, taper=taper)
    if subdiv:
        mod = o.modifiers.new("Sub", "SUBSURF")
        mod.levels = subdiv
    g.apply_obj(o)
    return rigid(o, bone)


def rcyl(name, r, length, loc, mat, bone, axis="Z", verts=16, r2=None, rot=None, bevel=0.002):
    o = g.cyl(name, r, length, loc, mat, axis=axis, verts=verts, radius2=r2, rot=rot, bevel=bevel)
    g.apply_obj(o)
    return rigid(o, bone)


def blend(z, z0, z1, a, b):
    """Weights that move from bone a (below z0) to bone b (above z1)."""
    t = min(max((z - z0) / (z1 - z0), 0.0), 1.0)
    t = t * t * (3 - 2 * t)
    w = {}
    if 1 - t > 0.001:
        w[a] = 1 - t
    if t > 0.001:
        w[b] = w.get(b, 0) + t
    return w


# --- Hands -----------------------------------------------------------------------

FINGERS = [  # name, proximal, middle, distal lengths, radius
    ("Index", 0.044, 0.026, 0.022, 0.0098),
    ("Middle", 0.048, 0.03, 0.023, 0.0102),
    ("Ring", 0.045, 0.028, 0.022, 0.0098),
    ("Pinky", 0.036, 0.021, 0.019, 0.0086),
]


def _capsule_chain(name, pts, radii, mat, bone, seg=12, ref=(0.0, 0.31, 0.95)):
    rings = []
    n = len(pts)
    for i in range(n):
        rings.append({"p": pts[i], "rx": radii[i] * 1.06, "ry": radii[i] * 0.9, "w": {bone: 1.0}, "pw": 2.2})
        if i < n - 1:
            # Knuckle swell between the joints.
            mid = (Vector(pts[i]) + Vector(pts[i + 1])) * 0.5
            rr = (radii[i] + radii[i + 1]) * 0.5 * 0.93
            rings.append({"p": mid, "rx": rr * 1.04, "ry": rr * 0.86, "w": {bone: 1.0}, "pw": 2.2})
    # Round the ends with extra shrinking rings.
    d0 = (Vector(pts[0]) - Vector(pts[1])).normalized()
    d1 = (Vector(pts[-1]) - Vector(pts[-2])).normalized()
    start = [{"p": Vector(pts[0]) + d0 * radii[0] * 0.6, "r": radii[0] * 0.75, "w": {bone: 1.0}}]
    end = [{"p": Vector(pts[-1]) + d1 * radii[-1] * 0.55, "r": radii[-1] * 0.78, "w": {bone: 1.0}},
           {"p": Vector(pts[-1]) + d1 * radii[-1] * 0.9, "r": radii[-1] * 0.4, "w": {bone: 1.0}}]
    return loft(name, start + rings + end, mat, seg=seg, ref=ref, subdiv=1)


def wrap_hand(name, centre, axis, side_dir, radius, mat, bone, handed=1, palm_arc=1.25,
              finger_start=None, finger_curl=None, index_straight=False, thumb=("wrap", 1.0), scale=1.0):
    """Builds a gloved hand wrapped around a cylinder.

    centre/axis: cylinder centre point and unit axis (fingers are spaced along
    it, index first towards +axis). side_dir: direction from the axis to the
    middle of the palm. handed=+1 wraps the fingers counter-clockwise about
    the axis, -1 clockwise. Returns a list of objects; the wrist point is
    stored on the first object as "wrist" for the forearm.
    """
    axis = Vector(axis).normalized()
    side = (Vector(side_dir) - axis * Vector(side_dir).dot(axis)).normalized()
    other = axis.cross(side) * handed
    c = Vector(centre)
    objs = []

    def at(theta, rad, along):
        return c + axis * along + (side * math.cos(theta) + other * math.sin(theta)) * rad

    # Palm: curved shell from the wrist side (-arc/2) to the knuckles (+arc/2).
    pr = radius + 0.012 * scale
    palm_rings = []
    width = 0.084 * scale
    top = width * 0.55
    steps = 6
    for i in range(steps + 1):
        th = -palm_arc * 0.5 + palm_arc * i / steps
        p = at(th, pr, 0.0)
        palm_rings.append(p)
    # Build palm as a loft along the arc with a flat-ish elliptical section.
    rings = []
    for i, p in enumerate(palm_rings):
        th = -palm_arc * 0.5 + palm_arc * i / steps
        radial = (p - c - axis * (p - c).dot(axis)).normalized()
        rings.append({"p": p - axis * 0.004, "rx": width * 0.5 * (0.92 if i == 0 else 1.0), "ry": 0.0135 * scale,
                      "ref": tuple(radial), "w": {bone: 1.0}, "pw": 3.0})
    palm = loft(name + "_Palm", rings, mat, seg=20, subdiv=1)
    objs.append(palm)
    # Heel of the hand extends straight past the wrist side of the arc.
    th0 = -palm_arc * 0.5
    tangent = -(side * -math.sin(th0) + other * math.cos(th0))
    heel = palm_rings[0] + tangent * 0.03 * scale
    wrist = palm_rings[0] + tangent * 0.05 * scale
    radial0 = (palm_rings[0] - c - axis * (palm_rings[0] - c).dot(axis)).normalized()
    rings = [
        {"p": palm_rings[1], "rx": width * 0.5, "ry": 0.0135 * scale, "ref": tuple(radial0), "w": {bone: 1.0}, "pw": 3.0},
        {"p": heel - axis * 0.004, "rx": width * 0.46, "ry": 0.019 * scale, "ref": tuple(radial0), "w": {bone: 1.0}, "pw": 2.6},
        {"p": wrist - axis * 0.004 - radial0 * 0.004, "rx": 0.031 * scale, "ry": 0.022 * scale, "ref": tuple(radial0), "w": {bone: 1.0}, "pw": 2.2},
    ]
    objs.append(loft(name + "_Heel", rings, mat, seg=20, subdiv=1, cap0=False))
    # Fingers.
    spacing = 0.0205 * scale
    starts = finger_start or [palm_arc * 0.5] * 4
    curls = finger_curl or [1.0] * 4
    for fi, (fname, l1, l2, l3, fr) in enumerate(FINGERS):
        along = top - 0.012 * scale - fi * spacing
        fr *= scale * 1.08
        rad = radius + fr
        th = starts[fi]
        if index_straight and fi == 0:
            # Trigger finger: along the side of the frame, the tip curled onto the trigger.
            fwd, inward, down = (Vector(v).normalized() for v in index_straight)
            p0 = at(th, rad, along)
            p1 = p0 + fwd * l1 * scale
            p2 = p1 + (fwd * 0.55 + inward * 0.75 + down * 0.2).normalized() * l2 * scale
            p3 = p2 + (fwd * 0.05 + inward * 0.75 + down * 0.65).normalized() * l3 * scale
            pts = [p0, p1, p2, p3]
        else:
            pts = [at(th, rad, along)]
            for L in (l1, l2, l3):
                L *= scale
                step = 2 * math.asin(min(L / (2 * rad), 0.99)) * curls[fi]
                th += step
                pts.append(at(th, rad, along))
        radial = (Vector(pts[0]) - c - axis * (Vector(pts[0]) - c).dot(axis)).normalized()
        objs.append(_capsule_chain(name + "_" + fname, pts, [fr * 1.05, fr, fr * 0.93, fr * 0.84], mat, bone, ref=tuple(radial)))
        # Knuckle pad.
        k = at(starts[fi] - 0.05, rad + fr * 0.6, along)
        kp = g.sphere(name + "_Knuckle" + fname, fr * 0.95, tuple(k), mat)
        g.apply_obj(kp)
        objs.append(rigid(kp, bone))
    # Thumb.
    mode, amount = thumb
    tr = 0.0105 * scale
    t_base = at(-palm_arc * 0.5 + 0.25, pr + 0.004, top - 0.004 * scale)
    if mode == "wrap":
        th = -palm_arc * 0.5 - 0.1
        rad = radius + tr
        pts = [t_base, at(th, rad, top + 0.01 * scale)]
        for L in (0.032, 0.026):
            step = 2 * math.asin(min(L * scale / (2 * rad), 0.99)) * amount
            th -= step
            pts.append(at(th, rad, top + 0.014 * scale))
    else:
        # Thumb lies straight along the axis (forward), e.g. on a handguard.
        th = -palm_arc * 0.5 - 0.35
        rad = radius + tr
        p1 = at(th, rad, top + 0.012 * scale)
        p2 = p1 + axis * 0.03 * scale
        p3 = p2 + axis * 0.024 * scale + (c - p2).normalized() * 0.004
        pts = [t_base, p1, p2, p3]
    objs.append(_capsule_chain(name + "_Thumb", pts, [tr * 1.35, tr * 1.1, tr, tr * 0.88], mat, bone))
    objs[0]["wrist"] = tuple(wrist)
    objs[0]["wrist_dir"] = tuple(tangent)
    return objs


def forearm(name, wrist, elbow, mats, bone_w, bone_e=None, cuff=True, ref=(0, 0, 1), scale=1.0):
    """Glove cuff + sleeve from the wrist to the elbow (and a bit beyond)."""
    w = Vector(wrist)
    e = Vector(elbow)
    d = (e - w)
    L = d.length
    d.normalize()
    objs = []
    wb = {bone_w: 1.0}
    cuff_rings = [
        {"p": w - d * 0.01, "rx": 0.03 * scale, "ry": 0.024 * scale, "w": wb},
        {"p": w + d * 0.03, "rx": 0.034 * scale, "ry": 0.029 * scale, "w": wb},
        {"p": w + d * 0.055, "rx": 0.037 * scale, "ry": 0.032 * scale, "w": wb},
    ]
    objs.append(loft(name + "_Cuff", cuff_rings, mats["gloves"], seg=20, ref=ref, subdiv=1))
    sl = []
    prof = [(0.04, 0.036, 0.031), (0.12, 0.043, 0.038), (0.3, 0.05, 0.045), (0.55, 0.055, 0.05), (0.8, 0.058, 0.052), (1.0, 0.06, 0.054), (1.15, 0.064, 0.058)]
    for t, rx, ry in prof:
        wt = wb if bone_e is None else blend(t, 0.85, 1.05, bone_w, bone_e)
        sl.append({"p": w + d * (L * t), "rx": rx * scale, "ry": ry * scale, "w": wt})
    objs.append(loft(name + "_Sleeve", sl, mats["uniform"], seg=24, ref=ref, subdiv=1, cap0=False))
    # Sleeve hem fold near the wrist.
    hem = [{"p": w + d * (L * 0.045), "rx": 0.038 * scale, "ry": 0.034 * scale, "w": wb},
           {"p": w + d * (L * 0.075), "rx": 0.041 * scale, "ry": 0.037 * scale, "w": wb},
           {"p": w + d * (L * 0.105), "rx": 0.039 * scale, "ry": 0.035 * scale, "w": wb}]
    objs.append(loft(name + "_Hem", hem, mats["uniform"], seg=24, ref=ref, subdiv=1, cap0=False, cap1=False))
    return objs


# --- Soldier body ------------------------------------------------------------------

def build_soldier(fname):
    f = FACTIONS[fname]
    m = faction_mats(f)
    parts = []

    # Legs.
    for s, hip, knee in ((-1, "HipL", "KneeL"), (1, "HipR", "KneeR")):
        x = 0.11 * s
        prof = [  # z, rx, ryf, ryb
            (1.0, 0.1, 0.1, 0.11), (0.93, 0.098, 0.095, 0.105), (0.84, 0.09, 0.09, 0.095), (0.72, 0.08, 0.08, 0.082),
            (0.6, 0.069, 0.07, 0.068), (0.5, 0.058, 0.064, 0.058), (0.45, 0.056, 0.062, 0.056), (0.4, 0.057, 0.056, 0.062),
            (0.32, 0.06, 0.054, 0.07), (0.24, 0.054, 0.05, 0.062), (0.17, 0.047, 0.047, 0.05), (0.12, 0.05, 0.05, 0.052),
        ]
        rings = []
        for z, rx, ryf, ryb in prof:
            if z > 0.88:
                w = blend(z, 0.9, 1.0, hip, "Pelvis")
            else:
                w = blend(z, 0.41, 0.5, knee, hip)
            rings.append({"p": (x + (0.006 * s if z < 0.6 else 0), 0.0, z), "rx": rx, "ryf": ryf, "ryb": ryb, "w": w, "pw": 2.1})
        parts.append(loft("Leg", rings, m["uniform"], seg=24, ref=(0, 1, 0), cap0=False, cap1=False))
        # Cargo pocket and knee pad.
        parts.append(rbox("Cargo", (0.03, 0.12, 0.15), (x + 0.08 * s, 0.0, 0.7), m["uniform"], hip, 0.012, subdiv=1))
        parts.append(rbox("PocketFlap", (0.034, 0.124, 0.03), (x + 0.082 * s, 0.0, 0.775), m["uniform"], hip, 0.008, subdiv=1))
        parts.append(rbox("KneePad", (0.1, 0.05, 0.13), (x, 0.065, 0.45), m["gear"], knee, 0.02, subdiv=2))
        parts.append(rbox("KneeStrapT", (0.13, 0.12, 0.018), (x, 0.0, 0.5), m["gear2"], knee, 0.006, subdiv=1))
        parts.append(rbox("KneeStrapB", (0.125, 0.115, 0.018), (x, 0.0, 0.4), m["gear2"], knee, 0.006, subdiv=1))
        # Boot: shaft + foot + sole.
        sh = [(0.2, 0.054, 0.054, 0.058), (0.15, 0.057, 0.06, 0.062), (0.1, 0.058, 0.07, 0.066), (0.07, 0.056, 0.08, 0.066)]
        parts.append(loft("BootShaft", [{"p": (x, 0, z), "rx": a, "ryf": b, "ryb": c, "w": {knee: 1.0}} for z, a, b, c in sh],
                          m["boots"], seg=24, cap0=False))
        foot = []
        for y, w_, h, z in ((-0.075, 0.05, 0.045, 0.055), (-0.02, 0.056, 0.055, 0.06), (0.05, 0.058, 0.045, 0.05),
                            (0.12, 0.055, 0.034, 0.042), (0.165, 0.045, 0.028, 0.038), (0.19, 0.03, 0.02, 0.036)):
            foot.append({"p": (x, y, z), "rx": w_, "ry": h, "w": {knee: 1.0}, "pw": 2.4})
        parts.append(loft("BootFoot", foot, m["boots"], seg=24, ref=(0, 0, 1), subdiv=1))
        parts.append(rbox("Sole", (0.118, 0.285, 0.026), (x, 0.055, 0.013), m["sole"], knee, 0.008, subdiv=1, taper=(0.86, 1.0)))
        parts.append(rbox("Heel", (0.105, 0.075, 0.03), (x, -0.06, 0.016), m["sole"], knee, 0.006))
        for i in range(4):
            parts.append(rbox("Lace", (0.062, 0.006, 0.006), (x, 0.06 + 0.017 * i, 0.088 + 0.014 * i - (0.01 if i > 1 else 0)), m["kit"], knee, 0.002))

    # Hips and torso: one loft from the crotch to the neck.
    prof = [  # z, rx, ryf, ryb
        (0.84, 0.13, 0.09, 0.1), (0.9, 0.165, 0.105, 0.115), (0.97, 0.175, 0.11, 0.12), (1.04, 0.165, 0.105, 0.11),
        (1.12, 0.155, 0.1, 0.1), (1.2, 0.16, 0.105, 0.1), (1.3, 0.172, 0.115, 0.105), (1.4, 0.182, 0.12, 0.11),
        (1.48, 0.19, 0.115, 0.11), (1.55, 0.2, 0.105, 0.1), (1.6, 0.2, 0.092, 0.09), (1.64, 0.175, 0.08, 0.078),
        (1.67, 0.12, 0.066, 0.066), (1.69, 0.064, 0.056, 0.054),
    ]
    rings = []
    for z, rx, ryf, ryb in prof:
        if z < 1.1:
            w = blend(z, 0.98, 1.1, "Pelvis", "Torso")
        else:
            w = blend(z, 1.47, 1.58, "Torso", "Chest")
        rings.append({"p": (0, 0.0, z), "rx": rx, "ryf": ryf, "ryb": ryb, "w": w, "pw": 2.3})
    parts.append(loft("Body", rings, m["uniform"], seg=32, cap0=True, cap1=False))
    # Belt.
    belt = [{"p": (0, 0, z), "rx": rx, "ryf": 0.12, "ryb": 0.128, "w": blend(z, 0.98, 1.1, "Pelvis", "Torso"), "pw": 2.4}
            for z, rx in ((0.99, 0.183), (1.015, 0.186), (1.04, 0.181))]
    parts.append(loft("Belt", belt, m["gear2"], seg=32, cap0=False, cap1=False))
    parts.append(rbox("Buckle", (0.06, 0.012, 0.036), (0, 0.128, 1.015), m["metal"], "Pelvis", 0.004))
    parts.append(rbox("DumpPouch", (0.15, 0.06, 0.11), (0.05, -0.15, 0.95), m["gear"], "Pelvis", 0.02, subdiv=1))
    for s in (-1, 1):
        parts.append(rbox("HipPouch", (0.06, 0.09, 0.1), (0.175 * s, -0.04, 0.96), m["gear"], "Pelvis", 0.014, subdiv=1))
    # Pistol holster on the right thigh.
    parts.append(rbox("Holster", (0.05, 0.1, 0.18), (0.19, -0.01, 0.76), m["kit"], "HipR", 0.014, subdiv=1))
    parts.append(rbox("HolsterStrap", (0.03, 0.16, 0.022), (0.17, 0.0, 0.72), m["gear2"], "HipR", 0.006))

    # Plate carrier: cummerbund shell and front/back plate bags.
    cb = [{"p": (0, 0, z), "rx": rx, "ryf": 0.128, "ryb": 0.122, "w": {"Torso": 1.0}, "pw": 2.6}
          for z, rx in ((1.08, 0.186), (1.16, 0.195), (1.25, 0.203), (1.32, 0.205))]
    parts.append(loft("Cummerbund", cb, m["gear"], seg=32, cap0=False, cap1=False, subdiv=1))
    for yy, nm in ((0.135, "PlateFront"), (-0.13, "PlateBack")):
        parts.append(rbox(nm, (0.33, 0.06, 0.38), (0, yy, 1.31), m["gear"], "Torso", 0.024, subdiv=1))
    for s in (-1, 1):
        parts.append(rbox("ShoulderStrap", (0.06, 0.25, 0.025), (0.11 * s, 0.0, 1.535), m["gear"], "Chest", 0.01, subdiv=1))
        parts.append(rbox("StrapPad", (0.07, 0.12, 0.03), (0.11 * s, 0.0, 1.545), m["gear2"], "Chest", 0.012, subdiv=1))
    # Mag pouches with mags, admin pouch, radio and hydration carrier.
    for i, x in enumerate((-0.1, 0.0, 0.1)):
        parts.append(rbox("MagPouch", (0.092, 0.056, 0.135), (x, 0.19, 1.24), m["gear"], "Torso", 0.012, subdiv=1))
        parts.append(rbox("MagInPouch", (0.06, 0.03, 0.06), (x, 0.188, 1.32), m["kit"], "Torso", 0.006))
        parts.append(rbox("Bungee", (0.066, 0.038, 0.008), (x, 0.19, 1.345), m["kit"], "Torso", 0.003))
    parts.append(rbox("AdminPouch", (0.2, 0.04, 0.1), (0, 0.185, 1.43), m["gear2"], "Torso", 0.012, subdiv=1))
    parts.append(rbox("Patch", (0.07, 0.004, 0.045), (0.05, 0.206, 1.44), m["plain"], "Torso", 0.002))
    parts.append(rbox("Radio", (0.06, 0.05, 0.14), (-0.2, 0.02, 1.38), m["kit"], "Torso", 0.01))
    parts.append(rbox("RadioPouch", (0.068, 0.056, 0.1), (-0.2, 0.02, 1.34), m["gear"], "Torso", 0.012, subdiv=1))
    parts.append(rcyl("Antenna", 0.005, 0.3, (-0.21, 0.0, 1.58), m["kit"], "Torso", verts=8, r2=0.002))
    parts.append(rbox("Hydration", (0.24, 0.06, 0.3), (0, -0.18, 1.33), m["gear2"], "Torso", 0.03, subdiv=1))
    parts.append(rbox("Tourniquet", (0.035, 0.035, 0.1), (0.12, 0.17, 1.44), m["kit"], "Torso", 0.012))

    # Arms.
    for s, sh, el in ((-1, "ShoulderL", "ElbowL"), (1, "ShoulderR", "ElbowR")):
        x = 0.23 * s
        prof = [  # z, rx, ryf, ryb
            (1.655, 0.03, 0.035, 0.035), (1.64, 0.05, 0.056, 0.054), (1.615, 0.061, 0.068, 0.066), (1.58, 0.063, 0.068, 0.066),
            (1.54, 0.06, 0.064, 0.062), (1.44, 0.055, 0.06, 0.057),
            (1.35, 0.051, 0.055, 0.055), (1.3, 0.049, 0.052, 0.055), (1.25, 0.049, 0.053, 0.051), (1.17, 0.048, 0.053, 0.049),
            (1.08, 0.044, 0.046, 0.044), (1.04, 0.038, 0.04, 0.037),
        ]
        rings = []
        for z, rx, ryf, ryb in prof:
            if z > 1.5:
                w = blend(z, 1.55, 1.64, sh, "Chest")
            else:
                w = blend(z, 1.24, 1.32, el, sh)
            rings.append({"p": (x - (0.01 * s if z > 1.6 else 0), 0, z), "rx": rx, "ryf": ryf, "ryb": ryb, "w": w})
        parts.append(loft("Arm", rings, m["uniform"], seg=22, cap0=True, cap1=True))
        # Sleeve pocket, flag patch, elbow pad.
        parts.append(rbox("SleevePocket", (0.02, 0.08, 0.1), (x + 0.056 * s, 0.0, 1.47), m["uniform"], sh, 0.01, subdiv=1))
        parts.append(rbox("Flag", (0.004, 0.06, 0.04), (x + 0.067 * s, 0.0, 1.49), m["plain"], sh, 0.002))
        parts.append(rbox("ElbowPad", (0.085, 0.06, 0.09), (x, -0.045, 1.28), m["gear"], el, 0.018, subdiv=2))
        # Glove: wrist cuff and a gripping fist.
        cuff = [{"p": (x, 0, z), "rx": a, "ry": b, "w": {el: 1.0}} for z, a, b in ((1.08, 0.044, 0.044), (1.04, 0.042, 0.04), (1.01, 0.038, 0.034))]
        parts.append(loft("GloveCuff", cuff, m["gloves"], seg=20, cap0=False, cap1=False))
        # The fist wraps a cylinder that points forward (+Y) in front of the palm.
        hand = wrap_hand("Hand", (x - 0.004 * s, 0.025, 0.95), (0, 1, 0), (s, -0.4, 0.3), 0.017, m["gloves"], el,
                         handed=s, palm_arc=1.1, scale=0.95, thumb=("wrap", 0.8))
        parts.extend(hand)

    # Neck and head.
    neck = [{"p": (0, 0.0, z), "rx": r, "ry": r * 1.05, "w": blend(z, 1.68, 1.76, "Chest", "Head")} for z, r in ((1.64, 0.062), (1.69, 0.05), (1.73, 0.05), (1.76, 0.056))]
    parts.append(loft("Neck", neck, m["skin"] if f["face"] == "gaiter" else m["balaclava"], seg=20, cap0=False, cap1=False))
    head_prof = [  # z, rx, ryf, ryb, y offset
        (1.735, 0.05, 0.062, 0.048, 0.012), (1.76, 0.066, 0.088, 0.068, 0.014), (1.795, 0.074, 0.098, 0.082, 0.008),
        (1.85, 0.077, 0.1, 0.094, 0.0), (1.89, 0.078, 0.098, 0.098, -0.004), (1.93, 0.072, 0.086, 0.094, -0.006),
        (1.96, 0.058, 0.066, 0.076, -0.006), (1.98, 0.032, 0.036, 0.044, -0.006),
    ]
    head_mat = m["skin"] if f["face"] == "gaiter" else m["balaclava"]
    hr = [{"p": (0, yo, z), "rx": rx, "ryf": ryf, "ryb": ryb, "w": {"Head": 1.0}, "pw": 2.2} for z, rx, ryf, ryb, yo in head_prof]
    head = loft("HeadMesh", hr, head_mat, seg=28, cap0=False, subdiv=1)
    parts.append(head)
    # Nose and brow under the eyewear.
    parts.append(rbox("Nose", (0.024, 0.03, 0.04), (0, 0.098, 1.825), head_mat, "Head", 0.01, subdiv=2, taper=(0.6, 0.7)))
    parts.append(rbox("Brow", (0.12, 0.03, 0.022), (0, 0.088, 1.868), m["skin"], "Head", 0.008, subdiv=2))
    if f["face"] == "gaiter":
        g_rings = [{"p": (0, yo, z), "rx": rx, "ryf": ryf, "ryb": ryb, "w": blend(z, 1.68, 1.76, "Chest", "Head")} for z, rx, ryf, ryb, yo in
                   ((1.655, 0.08, 0.08, 0.075, 0.0), (1.7, 0.064, 0.072, 0.062, 0.006), (1.75, 0.074, 0.098, 0.074, 0.014),
                    (1.8, 0.083, 0.112, 0.09, 0.009), (1.838, 0.086, 0.114, 0.097, 0.004))]
        parts.append(loft("Gaiter", g_rings, m["plain"], seg=28, cap0=False, cap1=False))
    else:
        parts.append(rbox("EyeBand", (0.13, 0.03, 0.036), (0, 0.088, 1.86), m["skin"], "Head", 0.01, subdiv=2))
    # Eyewear.
    if f["face"] == "gaiter":
        parts.append(rbox("GoggleFrame", (0.17, 0.045, 0.055), (0, 0.098, 1.862), m["kit"], "Head", 0.014, subdiv=1))
        lens = rbox("GoggleLens", (0.15, 0.01, 0.04), (0, 0.122, 1.862), m["lens"], "Head", 0.006, subdiv=1)
        parts.append(lens)
        gs = [{"p": (0, -0.004, z), "rx": 0.088, "ryf": 0.11, "ryb": 0.1, "w": {"Head": 1.0}} for z in (1.852, 1.872)]
        parts.append(loft("GoggleStrap", gs, m["gear2"], seg=28, cap0=False, cap1=False))
    else:
        for s in (-1, 1):
            parts.append(rbox("GlassLens", (0.05, 0.006, 0.026), (0.032 * s, 0.112, 1.862), m["lens"], "Head", 0.006, subdiv=1))
            parts.append(rbox("GlassArm", (0.004, 0.11, 0.006), (0.078 * s, 0.05, 1.868), m["kit"], "Head", 0.002))
        parts.append(rbox("GlassBridge", (0.11, 0.008, 0.008), (0, 0.112, 1.876), m["kit"], "Head", 0.003))
    # Helmet: shell with brim cut, cover band, NVG shroud, rails and counterweight.
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=24, radius=1.0)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.12], context="VERTS")
    for v in bm.verts:
        v.co.x *= 0.112
        v.co.y *= 0.128
        v.co.z *= 0.1
        # Raise the front edge (ballistic helmet cut).
        if v.co.y > 0 and v.co.z < 0.0:
            v.co.z += (v.co.y / 0.128) ** 2 * 0.022
    me = bpy.data.meshes.new("Helmet")
    bm.to_mesh(me)
    bm.free()
    helm = bpy.data.objects.new("Helmet", me)
    bpy.context.collection.objects.link(helm)
    helm.location = (0, -0.006, 1.902)
    helm.data.materials.append(m["helmet"])
    sol = helm.modifiers.new("Shell", "SOLIDIFY")
    sol.thickness = 0.01
    sol.offset = 1.0
    bev = helm.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.003
    bev.segments = 3
    for p in me.polygons:
        p.use_smooth = True
    g.apply_obj(helm)
    parts.append(rigid(helm, "Head"))
    band = [{"p": (0, -0.006, z), "rx": 0.119, "ryf": 0.135, "ryb": 0.134, "w": {"Head": 1.0}} for z in (1.9, 1.918)]
    parts.append(loft("HelmetBand", band, m["kit"] if fname == "sentinel" else m["gear2"], seg=40, cap0=False, cap1=False))
    parts.append(rbox("Shroud", (0.05, 0.02, 0.038), (0, 0.128, 1.93), m["kit"], "Head", 0.006, rot=(R(-18), 0, 0)))
    for s in (-1, 1):
        parts.append(rbox("HelmetRail", (0.014, 0.11, 0.022), (0.113 * s, -0.004, 1.895), m["kit"], "Head", 0.004, rot=(0, R(-10 * s), 0)))
    parts.append(rbox("Counterweight", (0.09, 0.03, 0.05), (0, -0.138, 1.905), m["gear"], "Head", 0.012, subdiv=1, rot=(R(20), 0, 0)))
    parts.append(rbox("Strobe", (0.022, 0.02, 0.016), (0, -0.085, 1.995), m["kit"], "Head", 0.004))
    # Chin strap.
    cs = [{"p": (0, 0.01, z), "rx": rx, "ryf": ryf, "ryb": 0.06, "w": {"Head": 1.0}} for z, rx, ryf in ((1.76, 0.07, 0.096), (1.775, 0.072, 0.1))]
    parts.append(loft("ChinStrap", cs, m["gear2"], seg=24, cap0=False, cap1=False, subdiv=0))
    if fname == "sentinel":
        for s in (-1, 1):
            parts.append(rcyl("EarCup", 0.038, 0.03, (0.085 * s, -0.005, 1.86), m["kit"], "Head", axis="X", verts=20))
            parts.append(rcyl("EarPad", 0.033, 0.012, (0.072 * s, -0.005, 1.86), m["plain"], "Head", axis="X", verts=20))
        parts.append(rcyl("BoomMic", 0.004, 0.08, (0.07, 0.055, 1.81), m["kit"], "Head", axis="Y", verts=8, rot=(R(-90), R(-35), 0)))
    else:
        parts.append(rbox("Shemagh", (0.2, 0.12, 0.05), (0, -0.02, 1.64), m["plain"], "Chest", 0.024, subdiv=2))
    return parts


def build_armature(name="Rig"):
    arm = bpy.data.armatures.new(name)
    obj = bpy.data.objects.new(name, arm)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    eb = {}
    children = {}
    for bn, (pos, parent) in JOINTS.items():
        children.setdefault(parent, []).append(bn)
    for bn, (pos, parent) in JOINTS.items():
        b = arm.edit_bones.new(bn)
        b.head = pos
        kids = children.get(bn, [])
        if bn in ("ElbowL", "ElbowR"):
            tail = (pos[0], pos[1], pos[2] - 0.28)
        elif bn in ("KneeL", "KneeR"):
            tail = (pos[0], pos[1], pos[2] - 0.38)
        elif bn == "Head":
            tail = (pos[0], pos[1], pos[2] + 0.2)
        elif bn in ("ShoulderL", "ShoulderR", "HipL", "HipR"):
            c = JOINTS[kids[0]][0]
            tail = c
        elif bn == "Chest":
            tail = (pos[0], pos[1], pos[2] + 0.1)
        elif bn == "Torso":
            tail = JOINTS["Chest"][0]
        else:
            tail = JOINTS["Torso"][0]
        b.tail = tail
        b.roll = 0.0
        eb[bn] = b
    for bn, (pos, parent) in JOINTS.items():
        if parent:
            eb[bn].parent = eb[parent]
            eb[bn].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def finish_soldier(fname, parts):
    g.apply_all()
    rig = build_armature()
    baked = [p for p in parts if texlib.bakeable(p)]
    others = [p for p in parts if not texlib.bakeable(p)]
    body = texlib.join(baked, "Soldier")
    lens = texlib.join(others, "SoldierLens") if others else None
    for o in [body, lens]:
        if o is None:
            continue
        mod = o.modifiers.new("Armature", "ARMATURE")
        mod.object = rig
        o.parent = rig
    out = os.path.join(OUT, "soldier_%s.gltf" % fname)
    texlib.bake_textures([body], os.path.join(OUT, "textures"), "soldier_%s" % fname, res=2048, profile="character")
    _clean(out)
    texlib.export_gltf(out)


# --- First-person arms -----------------------------------------------------------
# The arms come from the anatomy in tools/hand_anatomy.py: anatomical parts in
# a signed distance field, meshed with surface nets at 0.45 mm. That detailed
# mesh gives the normal map. A decimated copy is the game mesh. Glove zones
# (palm leather, back fabric, knuckle armour, cuff) are separate materials in
# one baked texture atlas. tools/rig_arms.py adds the skeleton after export.

LEFT_REF = Vector((0.0, 0.25, 0.04))  # typical LeftHand marker (bottom of the handguard)
GLOVE_H = 0.00045
SLEEVE_H = 0.0011
GLOVE_TRIS = 26000
SLEEVE_TRIS = 7000
GLOVE_COLOURS = {
    "sentinel": {"palm": (0.27, 0.22, 0.16), "back": (0.4, 0.35, 0.26), "pad": (0.2, 0.18, 0.14), "cuff": (0.3, 0.27, 0.2)},
    "militia": {"palm": (0.05, 0.05, 0.052), "back": (0.085, 0.085, 0.09), "pad": (0.035, 0.035, 0.037), "cuff": (0.06, 0.06, 0.065)},
}


def _mesh_obj(name, verts, quads, mats, zones=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], [tuple(int(i) for i in q) for q in quads])
    me.update()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    for m in mats:
        obj.data.materials.append(m)
    if zones is not None:
        me.polygons.foreach_set("material_index", np.asarray(zones, dtype=np.int32))
    me.polygons.foreach_set("use_smooth", np.ones(len(me.polygons), dtype=bool))
    me.update()
    return obj


def _decimated(src, name, tris):
    obj = src.copy()
    obj.data = src.data.copy()
    obj.name = name
    bpy.context.collection.objects.link(obj)
    current = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    mod = obj.modifiers.new("Decimate", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = min(1.0, tris / max(current, 1))
    mod.use_collapse_triangulate = True
    g.apply_obj(obj)
    return obj


def _glove_mats(fname, m):
    c = {k: _lin(v) for k, v in GLOVE_COLOURS[fname].items()}
    return [
        g.material("Gloves", c["palm"], 0.0, 0.62, kind="leather", seed=3.0),
        g.material("GloveFabric", c["back"], 0.0, 0.85, kind="fabric", seed=6.0, pattern=-1),
        g.material("GlovePad", c["pad"], 0.0, 0.5, kind="rubber", seed=7.0),
        g.material("GloveCuff", c["cuff"], 0.0, 0.8, kind="nylon", seed=8.0, pattern=-1),
    ]


def build_arms(fname):
    import hand_anatomy as ha
    m = faction_mats(FACTIONS[fname])
    glove_mats = _glove_mats(fname, m)
    lows = []
    high = {}
    for prefix, name in (("R", "ArmR"), ("L", "ArmL"), ("P", "ArmLPistol")):
        arm = ha.Arm(prefix)
        v, q = ha.build_mesh(arm.glove_sdf, *arm.glove_bounds(), GLOVE_H)
        centres = v[q].mean(axis=1)
        zones = np.minimum(arm.glove_zones(centres), 3)
        hi_g = _mesh_obj(name + "_HiGlove", v, q, glove_mats, zones)
        v, q = ha.build_mesh(arm.sleeve_sdf, *arm.sleeve_bounds(), SLEEVE_H)
        hi_s = _mesh_obj(name + "_HiSleeve", v, q, [m["uniform"]])
        lo_g = _decimated(hi_g, name + "_Glove", GLOVE_TRIS)
        lo_s = _decimated(hi_s, name + "_Sleeve", SLEEVE_TRIS)
        low = texlib.join([lo_g, lo_s], name)
        low.vertex_groups.clear()
        lows.append(low)
        high[name] = [hi_g, hi_s]
        print("arm %s: glove %d faces, sleeve %d faces, game mesh %d faces" % (
            name, len(hi_g.data.polygons), len(hi_s.data.polygons), len(low.data.polygons)))
    out = os.path.join(OUT, "arms_%s.gltf" % fname)
    texlib.bake_textures(lows, os.path.join(OUT, "textures"), "arms_%s" % fname, res=2048, profile="arms", high=high)
    for objs in high.values():
        for o in objs:
            bpy.data.objects.remove(o, do_unlink=True)
    # ArmL origin at the reference marker so the game can place it on any weapon.
    left = bpy.data.objects["ArmL"]
    left.data.transform(Matrix.Translation(-LEFT_REF))
    left.location = LEFT_REF
    _clean(out)
    texlib.export_gltf(out)


def _watch(m, wrist, elbow, side=1):
    d = (Vector(elbow) - Vector(wrist)).normalized()
    p = Vector(wrist) + d * 0.075
    x, y = _frame(d, (0, 0, 1))
    rings = []
    for t, r in ((-0.012, 0.0385), (0.0, 0.04), (0.012, 0.0385)):
        rings.append({"p": p + d * t, "rx": r, "ry": r * 0.9, "w": {}})
    band = loft("WatchBand", rings, m["kit"], seg=24, ref=(0, 0, 1), cap0=False, cap1=False, subdiv=1)
    face = g.cyl("WatchFace", 0.017, 0.01, tuple(p + y * 0.036), m["kit"], axis="Z", verts=24)
    face.rotation_euler = y.to_track_quat("Z", "Y").to_euler()
    g.apply_obj(face)
    return texlib.join([band, face], "Watch")


def _clean(path):
    base = os.path.splitext(path)[0]
    for ext in (".glb", ".gltf", ".bin"):
        if os.path.exists(base + ext):
            os.remove(base + ext)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    kinds = [a for a in argv if a in ("soldier", "arms")] or ["soldier", "arms"]
    factions = [a for a in argv if a in FACTIONS] or list(FACTIONS)
    os.makedirs(OUT, exist_ok=True)
    for fname in factions:
        if "soldier" in kinds:
            g.reset_scene()
            finish_soldier(fname, build_soldier(fname))
            print("BUILT soldier", fname)
        if "arms" in kinds:
            g.reset_scene()
            build_arms(fname)
            print("BUILT arms", fname)


main()
