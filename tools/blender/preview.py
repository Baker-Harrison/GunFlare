"""Renders previews of glTF/GLB models into a contact sheet.

    blender -b -P tools/blender/preview.py -- out.png [--size 900x500] [--close] model1.gltf ...

Each model is framed in a three-quarter view with a studio light rig.
--close frames the rear half of the model, as the first-person view shows it.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
out = argv.pop(0)
W, H = 900, 500
close = False
side = False
files = []
i = 0
while i < len(argv):
    a = argv[i]
    if a == "--size":
        W, H = [int(v) for v in argv[i + 1].split("x")]
        i += 2
        continue
    if a == "--close":
        close = True
    elif a == "--side":
        side = True
    elif a == "--front":
        side = "front"
    else:
        files.append(a)
    i += 1
tmp_dir = os.path.join(os.path.dirname(os.path.abspath(out)), "_prev")
os.makedirs(tmp_dir, exist_ok=True)
paths = []


def look(obj, target):
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


for f in files:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=f)
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not objs:
        continue
    bpy.context.view_layer.update()
    mn = Vector((1e9, 1e9, 1e9))
    mx = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            mn = Vector(map(min, mn, w))
            mx = Vector(map(max, mx, w))
    center = (mn + mx) / 2
    size = max((mx - mn).length, 0.1)
    sc = bpy.context.scene
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = 70
    cam = bpy.data.objects.new("cam", cam_data)
    sc.collection.objects.link(cam)
    if side == "front":
        d = Vector((0.55, 1.0, 0.18))
    elif side:
        d = Vector((1.0, 0.0, 0.08))
    else:
        d = Vector((1.0, -0.55, 0.35))
    dist = size * 1.55
    target = center
    if close:
        target = Vector((center.x, center.y * 0.4 + mx.y * 0.6, center.z))
        dist = size * 0.75
        d = Vector((0.7, 1.0, 0.45))
    cam.location = target + d.normalized() * dist
    look(cam, target)
    sc.camera = cam
    for nm, loc, energy, sz in (("key", (1.2, -1.0, 1.6), 260, 1.2), ("fill", (-1.5, -0.6, 0.6), 70, 2.0), ("rim", (-0.4, 1.6, 1.2), 220, 1.0)):
        ld = bpy.data.lights.new(nm, "AREA")
        ld.energy = energy * size * size
        ld.size = sz * size
        lo = bpy.data.objects.new(nm, ld)
        lo.location = center + Vector(loc) * size * 1.4
        look(lo, center)
        sc.collection.objects.link(lo)
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    sky = world.node_tree.nodes.new("ShaderNodeTexGradient")
    ramp = world.node_tree.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0.05, 0.05, 0.055, 1)
    ramp.color_ramp.elements[1].color = (0.5, 0.52, 0.56, 1)
    tc = world.node_tree.nodes.new("ShaderNodeTexCoord")
    mp = world.node_tree.nodes.new("ShaderNodeMapping")
    mp.inputs["Rotation"].default_value = (0, math.radians(-90), 0)
    world.node_tree.links.new(tc.outputs["Generated"], mp.inputs[0])
    world.node_tree.links.new(mp.outputs[0], sky.inputs[0])
    world.node_tree.links.new(sky.outputs[1], ramp.inputs[0])
    world.node_tree.links.new(ramp.outputs[0], bg.inputs[0])
    bg.inputs[1].default_value = 0.5
    sc.world = world
    sc.render.engine = "BLENDER_EEVEE"
    try:
        sc.eevee.use_raytracing = True
    except AttributeError:
        pass
    sc.view_settings.view_transform = "AgX"
    sc.render.resolution_x = W
    sc.render.resolution_y = H
    p = os.path.join(tmp_dir, os.path.basename(f) + ".png")
    sc.render.filepath = p
    bpy.ops.render.render(write_still=True)
    paths.append(p)

imgs = [bpy.data.images.load(p) for p in paths]
cols = 2 if len(imgs) > 1 else 1
rows = (len(imgs) + cols - 1) // cols
sheet = bpy.data.images.new("sheet", W * cols, H * rows)
import numpy as np  # noqa: E402
px = np.zeros((H * rows, W * cols, 4), dtype=np.float32)
for idx, im in enumerate(imgs):
    data = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4)
    cx = (idx % cols) * W
    cy = (rows - 1 - idx // cols) * H
    px[cy:cy + H, cx:cx + W] = data
sheet.pixels = px.ravel()
sheet.filepath_raw = out
sheet.file_format = "PNG"
sheet.save()
print("SHEET", out)
