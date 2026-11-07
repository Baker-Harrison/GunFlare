"""Parametric hard-surface modelling helpers for weapons, run inside Blender.

Conventions (Blender space): +Y is the muzzle direction, +Z up, +X right,
origin at the pistol grip. glTF export converts this to Godot's -Z forward.
Marker empties (Muzzle, Optic, Underbarrel, Mag, ADS, LeftHand) are read by
the game for attachments, effects and animation.
"""
import math

import os

import bpy
import bmesh
from mathutils import Vector, Matrix

import texlib

_MATS = {}


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()


def _infer_kind(name, metallic, alpha, emission):
    n = name.lower()
    if emission:
        return "emissive"
    if alpha < 1.0:
        return "translucent" if "mag" in n else "glass"
    if "lens" in n:
        return "lens"
    if "wood" in n or "plum" in n:
        return "wood"
    if "rubber" in n:
        return "rubber"
    if "brass" in n:
        return "brass"
    if metallic >= 0.6:
        return "metal"
    if "olive" in n or "c4" in n or "gel" in n:
        return "paint"
    return "polymer"


def material(name, color, metallic=0.0, roughness=0.5, alpha=1.0, emission=None, kind=None, **extra):
    if name in _MATS:
        return _MATS[name]
    m = bpy.data.materials.new(name)
    texlib.tag(m, kind or _infer_kind(name, metallic, alpha, emission), color, roughness, metallic, **extra)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        for attr, val in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
            try:
                setattr(m, attr, val)
                break
            except (AttributeError, TypeError):
                pass
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 4.0
    _MATS[name] = m
    return m


def mats():
    return {
        "metal": material("Metal", (0.045, 0.047, 0.05), 0.85, 0.38),
        "metal_worn": material("MetalWorn", (0.12, 0.12, 0.13), 0.9, 0.3),
        "camo": material("Camo_Body", (0.05, 0.052, 0.055), 0.7, 0.45),
        "polymer": material("Polymer", (0.035, 0.035, 0.035), 0.0, 0.62),
        "polymer_tan": material("PolymerTan", (0.42, 0.34, 0.22), 0.0, 0.65),
        "polymer_od": material("PolymerOD", (0.16, 0.18, 0.12), 0.0, 0.65),
        "wood": material("Wood", (0.2, 0.085, 0.032), 0.0, 0.42),
        "wood_light": material("WoodLight", (0.3, 0.16, 0.07), 0.0, 0.48),
        "rubber": material("Rubber", (0.02, 0.02, 0.02), 0.0, 0.85),
        "brass": material("Brass", (0.75, 0.55, 0.22), 1.0, 0.3),
        "glass": material("Glass", (0.1, 0.18, 0.22), 0.3, 0.05, 0.4),
        "lens": material("Lens", (0.05, 0.12, 0.2), 0.8, 0.02),
        "red": material("RedDot", (1.0, 0.05, 0.03), 0.0, 0.3, emission=(1.0, 0.05, 0.03)),
        "translucent": material("MagTranslucent", (0.12, 0.12, 0.12), 0.0, 0.2, 0.7),
        "olive": material("Olive", (0.2, 0.22, 0.14), 0.1, 0.6),
    }


def _link(obj, parent=None):
    bpy.context.collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
    return obj


def _finish(obj, mat, bevel, segments=3, parent=None):
    if mat is not None:
        obj.data.materials.append(mat)
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(40)
        mod.harden_normals = True
    if parent is not None:
        obj.parent = parent
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def box(name, size, loc, mat, bevel=0.002, rot=(0, 0, 0), parent=None, taper=None):
    """Axis-aligned box centred at loc. taper=(sx, sz) scales the +Y end face."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if taper:
        for v in bm.verts:
            if v.co.y > 0:
                v.co.x *= taper[0]
                v.co.z *= taper[1]
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    _link(obj)
    obj.location = loc
    obj.rotation_euler = rot
    return _finish(obj, mat, bevel, parent=parent)


def cyl(name, radius, length, loc, mat, axis="Y", verts=24, bevel=0.0008, radius2=None, parent=None, rot=None):
    """Cylinder along an axis, centred at loc. Barrels get a turned, stepped contour."""
    if name.startswith("Barrel") and axis == "Y" and rot is None and radius2 is None and length > 0.12:
        r = radius
        prof = [(r * 1.15, 0.0), (r * 1.15, length * 0.16), (r * 1.0, length * 0.18), (r, length * 0.6), (r * 0.94, length * 0.62),
                (r * 0.94, length * 0.985), (r * 0.84, length)]
        return lathe(name, prof, (loc[0], loc[1] - length / 2, loc[2]), mat, verts=32, parent=parent)
    verts = max(int(verts * 1.5), 12)
    bm = bmesh.new()
    r2 = radius if radius2 is None else radius2
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=verts, radius1=radius, radius2=r2, depth=length)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    _link(obj)
    obj.location = loc
    if rot is not None:
        obj.rotation_euler = rot
    elif axis == "Y":
        obj.rotation_euler = (math.radians(-90), 0, 0)
    elif axis == "X":
        obj.rotation_euler = (0, math.radians(90), 0)
    return _finish(obj, mat, bevel, parent=parent)


def tube(name, r_out, r_in, length, loc, mat, verts=24, parent=None):
    o = cyl(name, r_out, length, loc, mat, verts=verts, parent=parent)
    inner = cyl(name + "_bore", r_in, length * 1.1, loc, None, verts=verts)
    mod = o.modifiers.new("Bore", "BOOLEAN")
    mod.object = inner
    mod.operation = "DIFFERENCE"
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier="Bore")
    bpy.data.objects.remove(inner, do_unlink=True)
    return o


def chaikin(points, iterations=2, ratio=0.22):
    """Rounds the corners of a closed polygon (Chaikin corner cutting)."""
    pts = list(points)
    for _ in range(iterations):
        out = []
        n = len(pts)
        for i in range(n):
            a = Vector(pts[i])
            b = Vector(pts[(i + 1) % n])
            out.append(tuple(a.lerp(b, ratio)))
            out.append(tuple(a.lerp(b, 1 - ratio)))
        pts = out
    return pts


SMOOTH_PROFILES = ("grip", "stock", "cheek", "handguard", "foregrip", "pump")


def profile(name, points_yz, width, loc, mat, bevel=0.002, parent=None, smooth=None):
    """Extrude a side profile (list of (y, z)) along X by width. Good for stocks, grips, receivers.
    Grips, stocks and handguards get rounded corners and a moulded, pillowed section."""
    if smooth is None:
        smooth = name.lower().startswith(SMOOTH_PROFILES)
    if smooth:
        points_yz = chaikin(points_yz, 2, 0.18)
        bevel = max(bevel, min(width * 0.28, 0.009))
    bm = bmesh.new()
    hw = width / 2
    left = [bm.verts.new((-hw, y, z)) for (y, z) in points_yz]
    right = [bm.verts.new((hw, y, z)) for (y, z) in points_yz]
    bm.faces.new(left[::-1])
    bm.faces.new(right)
    n = len(points_yz)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((left[i], left[j], right[j], right[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    _link(obj)
    obj.location = loc
    if smooth:
        _finish(obj, mat, 0.0, parent=parent)
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 5
        mod.profile = 0.6
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(50)
        mod.harden_normals = True
        return obj
    return _finish(obj, mat, bevel, parent=parent)


def lathe(name, profile_ry, loc, mat, axis="Y", verts=40, parent=None, rot=None):
    """Solid of revolution. profile_ry: list of (radius, position along the axis)
    from one end to the other. Good for barrels, muzzle devices, tubes and optics."""
    bm = bmesh.new()
    rows = []
    for r, y in profile_ry:
        row = []
        for k in range(verts):
            a = 2 * math.pi * k / verts
            row.append(bm.verts.new((math.cos(a) * r, y, math.sin(a) * r)))
        rows.append(row)
    for i in range(len(rows) - 1):
        for k in range(verts):
            k2 = (k + 1) % verts
            bm.faces.new((rows[i][k], rows[i][k2], rows[i + 1][k2], rows[i + 1][k]))
    bm.faces.new(rows[0][::-1])
    bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    _link(obj)
    obj.location = loc
    if rot is not None:
        obj.rotation_euler = rot
    elif axis == "Z":
        obj.rotation_euler = (math.radians(90), 0, 0)
    elif axis == "X":
        obj.rotation_euler = (0, 0, math.radians(-90))
    _finish(obj, mat, 0.0, parent=parent)
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = 0.0006
    mod.segments = 2
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(35)
    mod.harden_normals = True
    return obj


def cut(obj, cutter):
    """Boolean difference, then removes the cutter. Bevel modifiers run after the cut."""
    mod = obj.modifiers.new("Cut", "BOOLEAN")
    mod.object = cutter
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter, do_unlink=True)
    return obj


def rail(name, length, loc, mat, parent=None, axis="Y"):
    """Picatinny rail: base plus repeated cross slots."""
    base = box(name, (0.021, length, 0.006), loc, mat, 0.0008, parent=parent)
    slots = int(length / 0.01)
    teeth = box(name + "_teeth", (0.022, 0.0052, 0.004), (loc[0], loc[1] - length / 2 + 0.005, loc[2] + 0.005), mat, 0.0004, parent=parent)
    arr = teeth.modifiers.new("Array", "ARRAY")
    arr.count = max(slots, 1)
    arr.relative_offset_displace = (0, 1.92, 0)
    if axis != "Y":
        base.rotation_euler = (0, math.radians(90), 0)
    return base


def bend(obj, angle_deg, axis="X"):
    mod = obj.modifiers.new("Bend", "SIMPLE_DEFORM")
    mod.deform_method = "BEND"
    mod.angle = math.radians(angle_deg)
    mod.deform_axis = axis
    return obj


def empty(name, loc, parent=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.02
    _link(e)
    e.location = loc
    if parent is not None:
        e.parent = parent
    return e


def apply_obj(obj):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for mod in list(obj.modifiers):
        try:
            bpy.ops.object.modifier_apply(modifier=mod.name)
        except RuntimeError:
            obj.modifiers.remove(mod)
    obj.select_set(False)
    return obj


def apply_all():
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            continue
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        for mod in list(obj.modifiers):
            try:
                bpy.ops.object.modifier_apply(modifier=mod.name)
            except RuntimeError:
                obj.modifiers.remove(mod)
        obj.select_set(False)


def export_glb(path):
    """Plain GLB export without baking (equipment models)."""
    apply_all()
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_apply=True,
                              export_materials="EXPORT", use_selection=False)


STOCK_PREFIXES = ("stock", "buttpad", "buffertube", "cheek", "foldstock", "wirestock")


def _mag_root(obj):
    p = obj.parent
    while p is not None:
        if p.type == "EMPTY" and p.name.split(".")[0] == "Mag":
            return p
        p = p.parent
    return None


def export(path, res=2048, bake=True):
    """Applies modifiers, joins parts, bakes PBR textures and writes a glTF.

    The parts become: Frame (static body), Stock (hidden by the game when
    aiming), Mag_body under the Mag marker (moved by reload animations).
    Glass, lenses and emissive parts stay separate with plain materials.
    """
    apply_all()
    base = os.path.splitext(path)[0]
    name = os.path.basename(base)
    out_dir = os.path.dirname(path)
    groups = {}
    for o in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
        for p in o.data.polygons:
            p.use_smooth = True
        if not texlib.bakeable(o):
            continue
        mag = _mag_root(o)
        if mag is not None:
            key = ("Mag_body", mag.name)
        elif o.name.lower().startswith(STOCK_PREFIXES):
            key = ("Stock", None)
        else:
            key = ("Frame", None)
        groups.setdefault(key, []).append(o)
    joined = []
    for (nm, parent), objs in groups.items():
        res_obj = texlib.join(objs, nm, bpy.data.objects.get(parent) if parent else None)
        if res_obj:
            joined.append(res_obj)
    if bake and joined:
        texlib.bake_textures(joined, os.path.join(out_dir, "textures"), name, res=res, profile="weapon")
    for ext in (".glb", ".gltf", ".bin"):
        if os.path.exists(base + ext):
            os.remove(base + ext)
    texlib.export_gltf(base + ".gltf")


# --- Common sub-assemblies ------------------------------------------------------

def pistol_grip(name, loc, mat, angle=18, height=0.11, depth=0.042, width=0.03, parent=None):
    # Front strap with three finger grooves, a palm swell and a beavertail.
    d, h = depth, height
    pts = [(0.0, 0.02), (d, 0.02), (d, 0.0)]
    for i in range(3):
        z0 = -h * (0.12 + i * 0.27)
        pts += [(d * 0.97, z0), (d * 1.04, z0 - h * 0.08), (d * 0.95, z0 - h * 0.2)]
    pts += [(d * 0.86, -h), (d * 0.3, -h * 1.05), (-d * 0.06, -h * 1.02), (-d * 0.2, -h * 0.62), (-d * 0.16, -h * 0.25),
            (-d * 0.3, 0.0), (-d * 0.2, 0.02)]
    g = profile(name, pts, width, loc, mat, 0.004, parent=parent)
    g.rotation_euler = (math.radians(-angle), 0, 0)
    return g


def trigger_group(loc, m, parent=None):
    x, y, z = loc
    # Guard
    box("TriggerGuardBottom", (0.012, 0.055, 0.004), (x, y + 0.03, z - 0.032), m, 0.001, parent=parent)
    box("TriggerGuardFront", (0.012, 0.004, 0.034), (x, y + 0.058, z - 0.016), m, 0.001, parent=parent)
    t = box("Trigger", (0.004, 0.006, 0.02), (x, y + 0.03, z - 0.014), m, 0.001, parent=parent)
    t.rotation_euler = (math.radians(15), 0, 0)


def mag_straight(name, loc, height, width, depth, mat, angle=0, parent=None):
    root = empty("Mag", loc, parent)
    body = box(name, (width, depth, height), (0, 0, -height / 2), mat, 0.0025, parent=root)
    box(name + "_base", (width * 1.15, depth * 1.08, 0.008), (0, 0, -height - 0.002), mat, 0.002, parent=root)
    # Ribs
    for i in range(3):
        box(name + "_rib%d" % i, (width * 1.04, 0.004, height * 0.6), (0, -depth * 0.3 + i * depth * 0.3, -height * 0.55), mat, 0.001, parent=root)
    root.rotation_euler = (math.radians(-angle), 0, 0)
    return root


def _bendable_box(name, size, loc, mat, bevel, parent, cuts=12):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    vertical = [e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > 1e-4]
    bmesh.ops.subdivide_edges(bm, edges=vertical, cuts=cuts, use_grid_fill=True)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    _link(obj)
    obj.location = loc
    _finish(obj, mat, bevel, parent=parent)
    return obj


def mag_curved(name, loc, height, width, depth, mat, curve=30, parent=None):
    """Magazine that curves forward (+Y) as it goes down, bent around the mag root."""
    root = empty("Mag", loc, parent)
    parts = [
        _bendable_box(name, (width, depth, height), (0, 0, -height / 2), mat, 0.002, root),
    ]
    for i in range(2):
        parts.append(_bendable_box(name + "_rib%d" % i, (width * 1.05, 0.004, height * 0.75), (0, -depth * 0.2 + i * depth * 0.4, -height * 0.5), mat, 0.001, root))
    for p in parts:
        mod = p.modifiers.new("Curve", "SIMPLE_DEFORM")
        mod.deform_method = "BEND"
        mod.deform_axis = "X"
        mod.origin = root
        mod.angle = math.radians(curve)
    return root


def sphere(name, radius, loc, mat, parent=None, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=radius)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    _link(obj)
    obj.location = loc
    obj.scale = scale
    return _finish(obj, mat, 0.0, parent=parent)

def mag_drum(name, loc, radius, width, mat, parent=None):
    root = empty("Mag", loc, parent)
    cyl(name, radius, width, (0, 0, -radius * 1.05), mat, axis="X", verts=32, parent=root)
    box(name + "_neck", (width * 0.6, 0.04, 0.05), (0, 0, -0.01), mat, 0.002, parent=root)
    cyl(name + "_hub", radius * 0.3, width * 1.1, (0, 0, -radius * 1.05), mat, axis="X", parent=root)
    return root


def front_sight_post(loc, m, parent=None, height=0.05):
    x, y, z = loc
    box("FSBase", (0.022, 0.02, 0.012), (x, y, z), m, 0.002, parent=parent)
    box("FSPostL", (0.004, 0.012, height), (x - 0.008, y, z + height / 2), m, 0.0008, parent=parent)
    box("FSPostR", (0.004, 0.012, height), (x + 0.008, y, z + height / 2), m, 0.0008, parent=parent)
    box("FSPost", (0.002, 0.004, height * 0.7), (x, y, z + height * 0.35), m, 0.0004, parent=parent)


def rear_sight(loc, m, parent=None):
    x, y, z = loc
    box("RSBase", (0.022, 0.03, 0.01), (x, y, z), m, 0.002, parent=parent)
    box("RSEarL", (0.004, 0.02, 0.022), (x - 0.009, y, z + 0.014), m, 0.0008, parent=parent)
    box("RSEarR", (0.004, 0.02, 0.022), (x + 0.009, y, z + 0.014), m, 0.0008, parent=parent)
    box("RSAperture", (0.012, 0.004, 0.012), (x, y, z + 0.014), m, 0.0006, parent=parent)


def scope(loc, length, r, m, lens, parent=None):
    x, y, z = loc
    tube("ScopeTube", r, r * 0.8, length, (x, y, z), m, 32, parent=parent)
    cyl("ScopeBell", r * 1.5, length * 0.25, (x, y + length * 0.45, z), m, radius2=r, verts=32, parent=parent)
    cyl("ScopeEye", r * 1.35, length * 0.18, (x, y - length * 0.45, z), m, verts=32, parent=parent)
    cyl("ScopeTurretT", r * 0.45, r * 1.4, (x, y, z + r * 1.2), m, axis="Z", parent=parent)
    cyl("ScopeTurretS", r * 0.45, r * 1.4, (x + r * 1.2, y, z), m, axis="X", parent=parent)
    cyl("ScopeLensF", r * 1.38, 0.002, (x, y + length * 0.58, z), lens, verts=32, parent=parent)
    cyl("ScopeLensR", r * 1.2, 0.002, (x, y - length * 0.55, z), lens, verts=32, parent=parent)
    for oy in (-length * 0.25, length * 0.25):
        box("ScopeRing", (r * 2.6, 0.012, r * 2.6), (x, y + oy, z), m, 0.002, parent=parent)
        box("ScopeRingBase", (0.024, 0.014, r * 1.2), (x, y + oy, z - r * 1.4), m, 0.002, parent=parent)
