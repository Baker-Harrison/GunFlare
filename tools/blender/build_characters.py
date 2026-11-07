"""Soldier body parts for both factions, modelled in each rig joint's local
space (origin at the joint, limb extending down -Z). The game attaches each
named part to its procedural joint.

Parts: Pelvis, Torso, Head, UpperArm, Forearm, Thigh, Shin.

    blender -b -P tools/blender/build_characters.py
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
OUT = os.path.join(ROOT, "assets", "characters")
R = math.radians

FACTIONS = {
    "sentinel": {"vest": (0.22, 0.21, 0.15), "helmet": (0.25, 0.25, 0.18), "skin": (0.62, 0.45, 0.34),
                 "boots": (0.2, 0.15, 0.1), "gloves": (0.15, 0.14, 0.11), "face": "goggles"},
    "militia": {"vest": (0.08, 0.08, 0.085), "helmet": (0.1, 0.1, 0.1), "skin": (0.5, 0.37, 0.28),
                "boots": (0.05, 0.05, 0.05), "gloves": (0.04, 0.04, 0.04), "face": "balaclava"},
}


def smooth_box(name, size, loc, mat, parent, subdiv=2, taper=None, rot=(0, 0, 0)):
    o = g.box(name, size, loc, mat, 0.0, rot=rot, taper=taper)
    o.parent = parent
    mod = o.modifiers.new("Sub", "SUBSURF")
    mod.levels = subdiv
    mod.render_levels = subdiv
    return o


def capsule(name, r, length, loc, mat, parent, r2=None):
    o = g.cyl(name, r, length, loc, mat, axis="Z", verts=14, radius2=r2 if r2 else r)
    o.parent = parent
    cap1 = g.sphere(name + "_capT", r, (loc[0], loc[1], loc[2] + length / 2), mat, parent=parent)
    cap2 = g.sphere(name + "_capB", r2 if r2 else r, (loc[0], loc[1], loc[2] - length / 2), mat, parent=parent)
    return o


def build(faction):
    f = FACTIONS[faction]
    fat = g.material("Fatigue", (0.3, 0.32, 0.22), 0.0, 0.9)
    vest = g.material("Vest", f["vest"], 0.0, 0.8)
    webbing = g.material("Webbing", tuple(c * 0.75 for c in f["vest"]), 0.0, 0.85)
    helmet = g.material("Helmet", f["helmet"], 0.1, 0.55)
    skin = g.material("Skin", f["skin"], 0.0, 0.55)
    boots = g.material("Boots", f["boots"], 0.0, 0.6)
    gloves = g.material("Gloves", f["gloves"], 0.0, 0.7)
    black = g.material("BlackKit", (0.03, 0.03, 0.03), 0.2, 0.5)
    lens = g.material("GoggleLens", (0.1, 0.12, 0.05), 0.8, 0.1)

    # Each part has an empty root at the joint pivot.
    def root(name):
        return g.empty(name, (0, 0, 0))

    # Pelvis: hips/belt. Joint at hip centre.
    p = root("Pelvis")
    smooth_box("PelvisBody", (0.36, 0.22, 0.22), (0, 0, 0.0), fat, p, 2)
    g.box("Belt", (0.38, 0.24, 0.06), (0, 0, 0.08), webbing, 0.01, parent=p)
    g.box("Buckle", (0.06, 0.02, 0.04), (0, 0.125, 0.08), black, 0.005, parent=p)
    for x in (-0.16, 0.16):
        g.box("HipPouch", (0.08, 0.12, 0.1), (x, -0.06, 0.03), vest, 0.01, parent=p)
    g.box("DumpPouch", (0.14, 0.06, 0.12), (0.06, -0.13, 0.0), webbing, 0.012, parent=p)

    # Torso: joint at waist; chest up to ~0.66.
    t = root("Torso")
    smooth_box("Chest", (0.36, 0.22, 0.56), (0, 0, 0.3), fat, t, 2, taper=(1.0, 1.0))
    smooth_box("Shoulders", (0.44, 0.2, 0.12), (0, 0, 0.52), fat, t, 2)
    g.box("PlateFront", (0.32, 0.05, 0.36), (0, 0.13, 0.36), vest, 0.02, parent=t)
    g.box("PlateBack", (0.32, 0.05, 0.38), (0, -0.13, 0.36), vest, 0.02, parent=t)
    g.box("Cummerbund", (0.38, 0.26, 0.14), (0, 0, 0.22), vest, 0.02, parent=t)
    for x in (-0.11, 0.0, 0.11):
        g.box("MagPouch", (0.09, 0.05, 0.13), (x, 0.17, 0.3), webbing, 0.012, parent=t)
        g.box("MagTop", (0.08, 0.02, 0.03), (x, 0.17, 0.38), black, 0.005, parent=t)
    g.box("AdminPouch", (0.18, 0.04, 0.1), (0, 0.165, 0.47), webbing, 0.01, parent=t)
    g.box("Radio", (0.06, 0.05, 0.14), (-0.17, 0.02, 0.4), black, 0.01, parent=t)
    g.cyl("Antenna", 0.005, 0.3, (-0.18, 0.0, 0.6), black, axis="Z", verts=6, radius2=0.002).parent = t
    g.box("Hydration", (0.24, 0.06, 0.3), (0, -0.18, 0.36), webbing, 0.03, parent=t)
    for x in (-0.12, 0.12):
        g.box("Strap", (0.05, 0.3, 0.02), (x, 0.0, 0.58), webbing, 0.005, parent=t)

    # Head: joint at the base of the neck.
    h = root("Head")
    capsule("Neck", 0.055, 0.08, (0, 0, -0.02), skin, h)
    head = g.sphere("Skull", 0.105, (0, 0.005, 0.08), skin, parent=h, scale=(0.95, 1.05, 1.12))
    g.sphere("Jaw", 0.085, (0, 0.035, 0.03), skin, parent=h, scale=(0.95, 1.0, 0.8))
    g.box("Nose", (0.025, 0.035, 0.04), (0, 0.105, 0.07), skin, 0.01, parent=h)
    if f["face"] == "balaclava":
        g.sphere("Balaclava", 0.112, (0, 0.005, 0.07), black, parent=h, scale=(0.97, 1.06, 1.15))
        g.box("EyeSlot", (0.11, 0.02, 0.03), (0, 0.11, 0.1), skin, 0.008, parent=h)
    helm = g.sphere("Helmet", 0.135, (0, -0.005, 0.12), helmet, parent=h, scale=(1.0, 1.08, 0.85))
    bm_cut = g.box("HelmetCut", (0.4, 0.4, 0.2), (0, 0.0, 0.02), None, 0.0)
    mod = helm.modifiers.new("Cut", "BOOLEAN")
    mod.object = bm_cut
    mod.operation = "DIFFERENCE"
    bpy.context.view_layer.objects.active = helm
    bpy.ops.object.modifier_apply(modifier="Cut")
    bpy.data.objects.remove(bm_cut, do_unlink=True)
    g.box("NVGMount", (0.05, 0.03, 0.04), (0, 0.13, 0.16), black, 0.006, parent=h)
    for x in (-0.12, 0.12):
        g.box("Rail", (0.015, 0.12, 0.02), (x, 0.0, 0.13), black, 0.004, parent=h)
    if f["face"] == "goggles":
        g.box("GoggleStrap", (0.27, 0.27, 0.025), (0, 0.0, 0.18), webbing, 0.01, parent=h)
        g.box("Goggles", (0.16, 0.04, 0.05), (0, 0.13, 0.19), black, 0.012, parent=h)
        g.box("GoggleLens", (0.14, 0.01, 0.035), (0, 0.15, 0.19), lens, 0.004, parent=h)
        g.box("Headset", (0.24, 0.07, 0.07), (0, 0.0, 0.08), black, 0.02, parent=h)

    # Upper arm: joint at shoulder, extends down 0.29.
    ua = root("UpperArm")
    capsule("Bicep", 0.062, 0.2, (0, 0, -0.14), fat, ua, 0.055)
    g.box("ShoulderPouch", (0.09, 0.1, 0.08), (0, 0, -0.06), webbing, 0.015, parent=ua)
    g.box("Patch", (0.002, 0.06, 0.05), (0.064, 0, -0.08), vest, 0.0, parent=ua)

    # Forearm: joint at elbow, extends down 0.3 to the hand.
    fa = root("Forearm")
    capsule("Arm", 0.052, 0.2, (0, 0, -0.12), fat, fa, 0.045)
    smooth_box("ElbowPad", (0.09, 0.09, 0.07), (0, -0.03, -0.01), vest, fa, 1)
    smooth_box("Hand", (0.075, 0.09, 0.1), (0, 0.01, -0.3), gloves, fa, 2)
    smooth_box("Thumb", (0.03, 0.05, 0.05), (0.03, 0.04, -0.28), gloves, fa, 1)

    # Thigh: joint at hip, extends down 0.44.
    th = root("Thigh")
    capsule("Leg", 0.085, 0.3, (0, 0, -0.22), fat, th, 0.072)
    g.box("CargoPocket", (0.03, 0.12, 0.14), (0.09, 0.0, -0.2), fat, 0.015, parent=th)
    g.box("LegHolster", (0.04, 0.09, 0.16), (-0.09, -0.01, -0.16), webbing, 0.012, parent=th)

    # Shin: joint at knee, extends down 0.44, boot at the bottom.
    sh = root("Shin")
    capsule("Calf", 0.07, 0.3, (0, 0, -0.2), fat, sh, 0.058)
    smooth_box("KneePad", (0.11, 0.06, 0.12), (0, 0.065, -0.02), vest, sh, 1)
    smooth_box("Boot", (0.11, 0.27, 0.12), (0, 0.04, -0.43), boots, sh, 2)
    smooth_box("BootTop", (0.1, 0.12, 0.12), (0, 0.0, -0.36), boots, sh, 1)
    g.box("Sole", (0.115, 0.28, 0.025), (0, 0.04, -0.49), black, 0.005, parent=sh)


def main():
    os.makedirs(OUT, exist_ok=True)
    for faction in FACTIONS:
        g.reset_scene()
        build(faction)
        g.export(os.path.join(OUT, "soldier_%s.glb" % faction))
        print("BUILT", faction)


main()
