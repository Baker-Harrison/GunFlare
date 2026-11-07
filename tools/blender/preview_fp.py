"""Renders a weapon with the first-person arms from the game's viewmodel camera.

    blender -b -P tools/blender/preview_fp.py -- out.png arms.gltf weapon.gltf [weapon2.gltf ...] [--pistol]

The camera matches scripts/player/viewmodel.gd: the weapon sits at
HIP_OFFSET from the camera, with a 62 degree vertical field of view.
"""
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
out = argv.pop(0)
arms = argv.pop(0)
W, H = 1280, 720
views = []
for a in list(argv):
    if a.startswith("--view="):
        c, t = a[7:].split(":")
        views.append((Vector([float(v) for v in c.split(",")]), Vector([float(v) for v in t.split(",")])))
weapons = [a for a in argv if not a.startswith("--")]
tmp = os.path.join(os.path.dirname(os.path.abspath(out)), "_prevfp")
os.makedirs(tmp, exist_ok=True)
paths = []
for wp in weapons:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=wp)
    lh = bpy.data.objects.get("LeftHand")
    left = lh.matrix_world.translation.copy() if lh else Vector((0, 0.25, 0.04))
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=arms)
    new = [o for o in bpy.data.objects if o not in before]
    pistol = "--pistol" in argv or any(k in os.path.basename(wp) for k in ("m9", "usp45", "p226", "m93r", "magnum"))
    for o in new:
        base = o.name.split(".")[0]
        if base == "ArmL":
            o.location = left
            o.hide_render = pistol
        elif base == "ArmLPistol":
            o.hide_render = not pistol
    sc = bpy.context.scene
    cam_d = bpy.data.cameras.new("cam")
    cam_d.sensor_fit = "VERTICAL"
    cam_d.angle_y = math.radians(62)
    cam_d.clip_start = 0.01
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    # Godot HIP_OFFSET (0.15, -0.155, -0.36) -> camera at -offset in weapon space.
    cam.location = (-0.15, -0.36, 0.155)
    cam.rotation_euler = (math.radians(90), 0, 0)
    if views:
        cam_d.angle_y = math.radians(40)
        cam.location = views[0][0]
        cam.rotation_euler = (views[0][1] - views[0][0]).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    for nm, loc, e in (("key", (0.6, -0.4, 1.2), 60), ("fill", (-1.0, -0.6, 0.3), 15), ("rim", (0.2, 1.2, 0.6), 40)):
        ld = bpy.data.lights.new(nm, "AREA")
        ld.energy = e
        ld.size = 0.8
        lo = bpy.data.objects.new(nm, ld)
        lo.location = loc
        lo.rotation_euler = (Vector((0, 0.1, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(lo)
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.34, 0.38, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    sc.world = world
    sc.render.engine = "BLENDER_EEVEE"
    sc.view_settings.view_transform = "AgX"
    sc.render.resolution_x = W
    sc.render.resolution_y = H
    p = os.path.join(tmp, os.path.basename(wp) + ".png")
    sc.render.filepath = p
    bpy.ops.render.render(write_still=True)
    paths.append(p)

import numpy as np  # noqa: E402
imgs = [bpy.data.images.load(p) for p in paths]
cols = 2 if len(imgs) > 1 else 1
rows = (len(imgs) + cols - 1) // cols
sheet = bpy.data.images.new("sheet", W * cols, H * rows)
px = np.zeros((H * rows, W * cols, 4), dtype=np.float32)
for i, im in enumerate(imgs):
    d = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4)
    px[(rows - 1 - i // cols) * H:(rows - i // cols) * H, (i % cols) * W:(i % cols + 1) * W] = d
sheet.pixels = px.ravel()
sheet.filepath_raw = out
sheet.file_format = "PNG"
sheet.save()
print("SHEET", out)
