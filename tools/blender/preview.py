"""Renders side-view previews of GLB models into a contact sheet.

    blender -b -P tools/blender/preview.py -- out.png model1.glb model2.glb ...
"""
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
out = argv[0]
files = argv[1:]
tmp_dir = os.path.join(os.path.dirname(out), "_prev")
os.makedirs(tmp_dir, exist_ok=True)
paths = []

for f in files:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=f)
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not objs:
        continue
    mn = Vector((1e9, 1e9, 1e9))
    mx = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            mn = Vector(map(min, mn, w))
            mx = Vector(map(max, mx, w))
    center = (mn + mx) / 2
    size = max((mx - mn).length, 0.1)
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = size * 1.05
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    # glTF import: model forward is -Y in Blender after Y-up conversion; view from the right side (+X).
    cam.location = center + Vector((size * 2, -size * 0.25, size * 0.25))
    direction = center - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    for i, (loc, energy) in enumerate([((1, -1, 2), 4.0), ((-2, 1, 1), 1.5), ((1, 2, -1), 1.0)]):
        ld = bpy.data.lights.new("l%d" % i, "SUN")
        ld.energy = energy
        lo = bpy.data.objects.new("l%d" % i, ld)
        lo.rotation_euler = (Vector(loc).normalized() * -1).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(lo)
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.57, 0.6, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    scene.world = world
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
    scene.render.resolution_x = 800
    scene.render.resolution_y = 400
    scene.render.film_transparent = False
    p = os.path.join(tmp_dir, os.path.basename(f) + ".png")
    scene.render.filepath = p
    bpy.ops.render.render(write_still=True)
    paths.append(p)

# Contact sheet
imgs = [bpy.data.images.load(p) for p in paths]
cols = 2
rows = (len(imgs) + cols - 1) // cols
W, H = 800, 400
sheet = bpy.data.images.new("sheet", W * cols, H * rows)
px = [0.0] * (W * cols * H * rows * 4)
for idx, im in enumerate(imgs):
    data = list(im.pixels)
    cx = (idx % cols) * W
    cy = (rows - 1 - idx // cols) * H
    for y in range(H):
        row_src = y * W * 4
        row_dst = ((cy + y) * W * cols + cx) * 4
        px[row_dst:row_dst + W * 4] = data[row_src:row_src + W * 4]
sheet.pixels = px
sheet.filepath_raw = out
sheet.file_format = "PNG"
sheet.save()
print("SHEET", out)
