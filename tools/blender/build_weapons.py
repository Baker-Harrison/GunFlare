"""Builds every weapon, attachment and equipment model and exports GLBs.

    blender -b -P tools/blender/build_weapons.py -- [ids...]
"""
import math
import os
import sys

import bpy

sys.path.append(os.path.dirname(__file__))
import gunlib as g  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_W = os.path.join(ROOT, "assets", "weapons")
OUT_A = os.path.join(ROOT, "assets", "attachments")
OUT_E = os.path.join(ROOT, "assets", "equipment")
R = math.radians


def markers(muzzle, optic, under, left, ads):
    g.empty("Muzzle", muzzle)
    g.empty("Optic", optic)
    g.empty("Underbarrel", under)
    g.empty("LeftHand", left)
    g.empty("ADS", ads)


def flash_hider(y, z, m, r=0.011, length=0.05, style="birdcage"):
    """Muzzle device turned on a lathe, with real cut slots."""
    if style == "brake":
        fh = g.lathe("FlashHider", [(r * 0.75, 0.0), (r * 0.8, 0.004), (r, 0.006), (r, length - 0.003), (r * 0.9, length)],
                     (0, y, z), m, verts=32)
        for i, t in enumerate((0.3, 0.55, 0.8)):
            c = g.box("BrakeCut%d" % i, (r * 3, length * 0.13, r * 0.7), (0, y + length * t, z), None, 0.0)
            g.cut(fh, c)
        return fh
    prof = [(r * 0.7, 0.0), (r * 0.72, 0.006), (r * 0.95, 0.009), (r * 0.95, 0.016), (r, 0.018), (r, length - 0.002),
            (r * 0.92, length)]
    fh = g.lathe("FlashHider", prof, (0, y, z), m, verts=40)
    bore = g.cyl("FHBore", r * 0.55, length * 0.8, (0, y + length * 0.62, z), None, verts=24, bevel=0.0)
    g.cut(fh, bore)
    for i in range(6):
        if style == "birdcage" and i == 4:
            continue  # A2 style: closed at the bottom
        a = i * math.pi / 3 + math.pi / 6
        c = g.box("Slot%d" % i, (r * 0.36, length * 0.55, r * 0.9), (math.cos(a) * r * 0.85, y + length * 0.64, z + math.sin(a) * r * 0.85), None, 0.0,
                  rot=(0, -a + math.pi / 2, 0))
        g.cut(fh, c)
    return fh


def barrel(name, y0, length, z, r, m, profile="rifle"):
    """Turned barrel with a stepped contour, a gas-block journal and a crown."""
    if profile == "heavy":
        prof = [(r * 1.15, 0.0), (r * 1.15, length * 0.35), (r * 1.05, length * 0.38), (r, length * 0.95), (r * 0.9, length)]
    else:
        prof = [(r * 1.18, 0.0), (r * 1.18, length * 0.18), (r * 1.0, length * 0.2), (r, length * 0.55), (r * 0.94, length * 0.57),
                (r * 0.94, length * 0.98), (r * 0.85, length)]
    return g.lathe(name, prof, (0, y0, z), m, verts=32)


def pins(m, spots, r=0.0028, width=0.026):
    """Cross pins and screws through both sides of a receiver."""
    for i, (y, z) in enumerate(spots):
        g.cyl("Pin%d" % i, r, width, (0, y, z), m, axis="X", verts=16, bevel=0.0004)


# --- AR-15 family ----------------------------------------------------------------

def ar15(name, barrel_len=0.36, handguard=0.18, quad_rail=True, carry=False, stock="collapsible", piston=False):
    m = g.mats()
    camo = m["camo"]
    # Lower receiver
    g.profile("Lower", [(-0.07, 0.04), (0.11, 0.04), (0.11, 0.02), (0.095, -0.005), (0.055, -0.005), (0.04, 0.012), (-0.05, 0.012), (-0.07, 0.02)], 0.024, (0, 0, 0), camo, 0.0025)
    g.box("Magwell", (0.028, 0.07, 0.035), (0, 0.075, 0.002), camo, 0.002)
    # Upper
    g.box("Upper", (0.03, 0.2, 0.04), (0, 0.025, 0.06), camo, 0.003)
    g.box("EjectionPort", (0.002, 0.06, 0.015), (0.016, 0.03, 0.06), m["metal_worn"], 0.0005)
    g.cyl("ForwardAssist", 0.006, 0.02, (0.016, -0.02, 0.07), m["metal"], axis="Y")
    g.box("ChargingHandle", (0.03, 0.02, 0.01), (0, -0.075, 0.075), m["metal"], 0.002)
    if not carry:
        g.rail("TopRail", 0.19, (0, 0.025, 0.083), m["metal"])
    else:
        g.box("CarryHandle", (0.018, 0.14, 0.012), (0, 0.02, 0.112), camo, 0.002)
        g.box("CarryFront", (0.018, 0.02, 0.03), (0, 0.08, 0.095), camo, 0.002)
        g.box("CarryRear", (0.022, 0.03, 0.035), (0, -0.04, 0.095), camo, 0.002)
        g.box("RearAperture", (0.012, 0.006, 0.012), (0, -0.045, 0.118), m["metal"], 0.0006)
    # Buffer tube and stock
    g.cyl("BufferTube", 0.0145, 0.2, (0, -0.17, 0.062), m["metal"], verts=20)
    if stock == "collapsible":
        g.profile("Stock", [(-0.33, 0.08), (-0.21, 0.08), (-0.2, 0.05), (-0.22, 0.03), (-0.33, 0.0)], 0.04, (0, 0, 0), m["polymer"], 0.004)
        g.box("Buttpad", (0.042, 0.012, 0.085), (0, -0.335, 0.04), m["rubber"], 0.003)
    else:
        g.profile("Stock", [(-0.4, 0.085), (-0.07, 0.08), (-0.07, 0.04), (-0.4, -0.02)], 0.042, (0, 0, 0), m["polymer"], 0.005)
        g.box("Buttpad", (0.044, 0.012, 0.11), (0, -0.405, 0.032), m["rubber"], 0.003)
    g.pistol_grip("Grip", (0, -0.04, 0.012), m["polymer"])
    g.trigger_group((0, -0.01, 0.012), m["metal"])
    # Handguard
    y0 = 0.125
    if quad_rail:
        g.box("Handguard", (0.044, handguard, 0.044), (0, y0 + handguard / 2, 0.062), camo, 0.003)
        g.rail("HGTop", handguard - 0.01, (0, y0 + handguard / 2, 0.087), m["metal"])
        rb = g.rail("HGBottom", handguard - 0.03, (0, y0 + handguard / 2, 0.037), m["metal"])
        rb.rotation_euler = (0, R(180), 0)
        for s in (-1, 1):
            rs = g.rail("HGSide", handguard - 0.04, (s * 0.025, y0 + handguard / 2, 0.062), m["metal"])
            rs.rotation_euler = (0, R(90 * s), 0)
    else:
        g.cyl("Handguard", 0.024, handguard, (0, y0 + handguard / 2, 0.062), m["polymer"], verts=20)
        for i in range(6):
            g.box("HGVent%d" % i, (0.05, 0.012, 0.004), (0, y0 + 0.02 + i * handguard / 6, 0.086), m["polymer"], 0.0008)
        g.cyl("DeltaRing", 0.027, 0.012, (0, y0, 0.062), m["metal"], verts=24)
    # Receiver hardware.
    pins(m["metal"], [(0.1, 0.03), (-0.055, 0.03), (0.0, 0.018), (0.018, 0.018)], width=0.0255)
    g.box("MagRelease", (0.004, 0.012, 0.012), (0.0135, 0.052, 0.022), m["metal"], 0.0012)
    g.box("BoltCatch", (0.003, 0.03, 0.01), (-0.0135, 0.07, 0.035), m["metal"], 0.0008)
    g.cyl("Selector", 0.006, 0.004, (-0.0135, -0.03, 0.03), m["metal"], axis="X", verts=16)
    g.box("SelectorLever", (0.003, 0.016, 0.005), (-0.015, -0.036, 0.03), m["metal"], 0.0008)
    g.box("DustCoverDoor", (0.0016, 0.058, 0.014), (0.0158, 0.03, 0.06), m["metal"], 0.0004)
    # Barrel, gas block, front sight
    barrel("Barrel", y0, barrel_len, 0.062, 0.0075, m["metal"])
    fs_y = y0 + handguard + 0.03
    if carry or not quad_rail:
        g.box("GasBlock", (0.02, 0.025, 0.024), (0, fs_y, 0.065), m["metal"], 0.002)
        g.profile("FSB", [(fs_y - 0.012, 0.07), (fs_y + 0.012, 0.07), (fs_y + 0.006, 0.112), (fs_y - 0.006, 0.112)], 0.012, (0, 0, 0), m["metal"], 0.001)
        g.box("FSPost", (0.003, 0.003, 0.012), (0, fs_y, 0.118), m["metal"], 0.0003)
        sight_z = 0.118
    else:
        g.box("GasBlock", (0.02, 0.02, 0.022), (0, fs_y, 0.065), m["metal"], 0.002)
        # Folding back-up sights
        g.box("BUISFront", (0.012, 0.012, 0.03), (0, y0 + handguard - 0.01, 0.1), m["metal"], 0.0015)
        g.box("BUISRearBase", (0.022, 0.016, 0.012), (0, -0.06, 0.092), m["metal"], 0.0015)
        g.box("BUISRearL", (0.004, 0.01, 0.026), (-0.008, -0.06, 0.11), m["metal"], 0.0008)
        g.box("BUISRearR", (0.004, 0.01, 0.026), (0.008, -0.06, 0.11), m["metal"], 0.0008)
        sight_z = 0.113
    if piston:
        g.box("PistonHousing", (0.02, 0.06, 0.012), (0, y0 + handguard - 0.03, 0.08), m["metal"], 0.002)
    muzzle_y = y0 + barrel_len
    flash_hider(muzzle_y, 0.062, m["metal"], 0.0105)
    g.mag_curved("Mag_body", (0, 0.075, -0.012), 0.15, 0.024, 0.06, m["metal"], curve=10)
    markers((0, muzzle_y + 0.05, 0.062), (0, 0.01, 0.087), (0, y0 + handguard * 0.55, 0.035), (0, y0 + handguard * 0.5, 0.04),
            (0, -0.07 if not carry else -0.045, sight_z))


def m4a1():
    ar15("m4a1", barrel_len=0.36, handguard=0.18, quad_rail=True)


def m16a4():
    ar15("m16a4", barrel_len=0.5, handguard=0.3, quad_rail=False, carry=True, stock="fixed")


def hk416():
    ar15("hk416", barrel_len=0.36, handguard=0.24, quad_rail=True, piston=True)


# --- AK family ------------------------------------------------------------------

def ak(name, wood=True, folding=False, barrel=0.41, rpk=False):
    m = g.mats()
    furn = m["wood"] if wood else m["polymer"]
    if name == "ak74":
        furn = g.material("Plum", (0.18, 0.08, 0.06), 0.0, 0.55)
    camo = m["camo"]
    g.box("Receiver", (0.032, 0.27, 0.045), (0, 0.06, 0.045), camo, 0.0025)
    g.cyl("DustCover", 0.016, 0.24, (0, 0.05, 0.068), camo, verts=20)
    g.box("RearTrunnion", (0.034, 0.03, 0.05), (0, -0.075, 0.045), camo, 0.003)
    g.box("SafetyLever", (0.003, 0.09, 0.01), (0.018, 0.03, 0.05), m["metal_worn"], 0.0008)
    g.box("ChargingHandle", (0.03, 0.012, 0.01), (0.022, 0.11, 0.055), m["metal"], 0.002)
    # Rear tangent sight
    g.box("RearSightBlock", (0.026, 0.05, 0.018), (0, 0.19, 0.075), camo, 0.002)
    g.box("RearSightLeaf", (0.02, 0.06, 0.004), (0, 0.205, 0.087), m["metal"], 0.0008)
    g.box("RearNotch", (0.012, 0.005, 0.008), (0, 0.18, 0.091), m["metal"], 0.0006)
    # Furniture
    hg_len = 0.2 if not rpk else 0.24
    g.box("LowerHandguard", (0.044, hg_len, 0.04), (0, 0.22 + hg_len / 2, 0.042), furn, 0.006, taper=(0.9, 0.9))
    g.cyl("UpperHandguard", 0.018, hg_len * 0.75, (0, 0.24 + hg_len * 0.37, 0.078), furn, verts=20)
    g.cyl("GasTube", 0.009, hg_len, (0, 0.22 + hg_len / 2, 0.078), m["metal"], verts=16)
    g.pistol_grip("Grip", (0, -0.035, 0.022), furn, angle=22)
    g.trigger_group((0, -0.005, 0.022), m["metal"])
    if folding:
        g.box("FoldStockTop", (0.008, 0.25, 0.01), (0, -0.21, 0.065), m["metal"], 0.002)
        g.box("FoldStockBottom", (0.008, 0.22, 0.01), (0, -0.2, 0.0), m["metal"], 0.002)
        g.box("FoldStockPad", (0.02, 0.015, 0.08), (0, -0.335, 0.03), m["metal"], 0.003)
    else:
        g.profile("Stock", [(-0.09, 0.07), (-0.42, 0.05), (-0.42, -0.06), (-0.33, -0.04), (-0.09, 0.025)], 0.04, (0, 0, 0), furn, 0.006)
        g.box("Buttplate", (0.042, 0.008, 0.115), (0, -0.425, -0.005), m["metal"], 0.002)
    # Barrel
    y0 = 0.19
    g.cyl("Barrel", 0.0085 if not rpk else 0.011, barrel, (0, y0 + barrel / 2, 0.062), m["metal"], verts=16)
    fsb_y = y0 + barrel - 0.03
    g.box("GasBlock", (0.022, 0.03, 0.03), (0, 0.22 + hg_len + 0.015, 0.07), m["metal"], 0.002)
    g.box("FSBlock", (0.02, 0.03, 0.022), (0, fsb_y, 0.068), m["metal"], 0.002)
    g.cyl("FSHood", 0.012, 0.02, (0, fsb_y, 0.092), m["metal"], axis="Y", verts=16)
    g.box("FSPost", (0.003, 0.003, 0.016), (0, fsb_y, 0.09), m["metal"], 0.0003)
    muzzle_y = y0 + barrel
    if name == "ak74":
        g.cyl("MuzzleBrake", 0.012, 0.07, (0, muzzle_y + 0.035, 0.062), m["metal"], verts=16)
        g.box("BrakePort", (0.026, 0.008, 0.008), (0, muzzle_y + 0.04, 0.062), m["metal_worn"], 0.001)
        muzzle_y += 0.07
    else:
        g.cyl("SlantBrake", 0.011, 0.03, (0, muzzle_y + 0.015, 0.062), m["metal"], verts=16)
        muzzle_y += 0.03
    if rpk:
        g.mag_drum("Mag_body", (0, 0.11, 0.01), 0.075, 0.07, m["metal"])
        g.box("BipodL", (0.006, 0.006, 0.17), (-0.02, muzzle_y - 0.08, -0.02), m["metal"], 0.001, rot=(R(-35), R(10), 0))
        g.box("BipodR", (0.006, 0.006, 0.17), (0.02, muzzle_y - 0.08, -0.02), m["metal"], 0.001, rot=(R(-35), R(-10), 0))
    else:
        mag_mat = g.material("AKMag", (0.3, 0.12, 0.05), 0.0, 0.5) if name == "ak74" else m["metal"]
        g.mag_curved("Mag_body", (0, 0.1, 0.022), 0.19, 0.026, 0.07, mag_mat, curve=48)
    markers((0, muzzle_y, 0.062), (0, 0.06, 0.088), (0, 0.32, 0.02), (0, 0.32, 0.03), (0, 0.17, 0.093))


def ak47():
    ak("ak47", wood=True)


def ak74():
    ak("ak74", wood=False, folding=True)


def rpk():
    ak("rpk", wood=True, barrel=0.59, rpk=True)


# --- Other rifles ----------------------------------------------------------------

def scar_h():
    m = g.mats()
    tan = m["polymer_tan"]
    camo = m["camo"]
    g.box("Upper", (0.04, 0.42, 0.05), (0, 0.13, 0.065), camo, 0.004)
    g.rail("TopRail", 0.4, (0, 0.12, 0.093), m["metal"])
    g.box("Lower", (0.032, 0.17, 0.035), (0, 0.02, 0.025), tan, 0.004)
    g.box("Magwell", (0.034, 0.07, 0.04), (0, 0.08, 0.0), tan, 0.003)
    for s in (-1, 1):
        r = g.rail("SideRail", 0.12, (s * 0.022, 0.27, 0.065), m["metal"])
        r.rotation_euler = (0, R(90 * s), 0)
    g.rail("BottomRail", 0.12, (0, 0.27, 0.037), m["metal"]).rotation_euler = (0, R(180), 0)
    g.box("ChargingHandle", (0.012, 0.02, 0.012), (-0.026, 0.2, 0.075), m["metal"], 0.002)
    g.pistol_grip("Grip", (0, -0.03, 0.01), tan, angle=18)
    g.trigger_group((0, 0.0, 0.01), m["metal"])
    g.profile("Stock", [(-0.32, 0.09), (-0.08, 0.09), (-0.08, 0.04), (-0.2, 0.02), (-0.32, -0.01)], 0.044, (0, 0, 0), tan, 0.006)
    g.box("Cheek", (0.04, 0.12, 0.015), (0, -0.22, 0.098), tan, 0.004)
    g.cyl("Barrel", 0.0095, 0.33, (0, 0.34 + 0.165, 0.065), m["metal"], verts=16)
    flash_hider(0.67, 0.065, m["metal"], 0.012)
    g.box("BUISF", (0.004, 0.008, 0.03), (0, 0.32, 0.11), m["metal"], 0.0008)
    g.box("BUISRL", (0.004, 0.01, 0.026), (-0.008, -0.06, 0.11), m["metal"], 0.0008)
    g.box("BUISRR", (0.004, 0.01, 0.026), (0.008, -0.06, 0.11), m["metal"], 0.0008)
    g.mag_straight("Mag_body", (0, 0.08, -0.02), 0.12, 0.028, 0.068, m["metal"], angle=6)
    markers((0, 0.72, 0.065), (0, 0.05, 0.096), (0, 0.27, 0.03), (0, 0.27, 0.035), (0, -0.065, 0.122))


def g36c():
    m = g.mats()
    camo = m["camo"]
    g.profile("Body", [(-0.08, 0.1), (0.25, 0.1), (0.28, 0.04), (0.06, 0.02), (0.03, -0.0), (-0.08, 0.02)], 0.042, (0, 0, 0), camo, 0.005)
    g.box("CarryHandle", (0.03, 0.22, 0.014), (0, 0.08, 0.142), m["polymer"], 0.004)
    g.box("HandleFront", (0.03, 0.02, 0.04), (0, 0.18, 0.12), m["polymer"], 0.003)
    g.box("HandleRear", (0.03, 0.03, 0.04), (0, -0.02, 0.12), m["polymer"], 0.003)
    for i in range(5):
        g.box("Vent%d" % i, (0.046, 0.012, 0.006), (0, 0.15 + i * 0.024, 0.06), m["polymer"], 0.001)
    g.pistol_grip("Grip", (0, -0.03, 0.02), m["polymer"], angle=15)
    g.trigger_group((0, 0.0, 0.02), m["metal"])
    g.box("StockArm", (0.02, 0.24, 0.05), (0, -0.2, 0.065), m["polymer"], 0.004)
    g.box("StockPad", (0.04, 0.02, 0.1), (0, -0.32, 0.05), m["polymer"], 0.004)
    g.cyl("Barrel", 0.0085, 0.16, (0, 0.33, 0.07), m["metal"], verts=16)
    flash_hider(0.41, 0.07, m["metal"], 0.011)
    g.mag_curved("Mag_body", (0, 0.09, 0.01), 0.15, 0.026, 0.065, m["translucent"], curve=12)
    markers((0, 0.45, 0.07), (0, 0.08, 0.15), (0, 0.22, 0.02), (0, 0.22, 0.03), (0, -0.02, 0.156))


def famas():
    m = g.mats()
    camo = m["camo"]
    g.profile("Body", [(-0.3, 0.11), (0.18, 0.11), (0.25, 0.07), (0.25, 0.04), (-0.3, 0.0)], 0.05, (0, 0, 0), camo, 0.006)
    g.profile("Handle", [(-0.12, 0.11), (0.16, 0.11), (0.22, 0.16), (-0.06, 0.16)], 0.016, (0, 0, 0), m["polymer"], 0.004)
    g.box("Buttpad", (0.05, 0.015, 0.11), (0, -0.305, 0.055), m["rubber"], 0.004)
    g.box("TriggerGuardFull", (0.012, 0.13, 0.03), (0, 0.04, -0.01), m["polymer"], 0.004)
    g.pistol_grip("Grip", (0, 0.02, 0.01), m["polymer"])
    g.cyl("Barrel", 0.008, 0.18, (0, 0.33, 0.06), m["metal"], verts=16)
    flash_hider(0.42, 0.06, m["metal"], 0.011)
    g.box("Bipod", (0.03, 0.12, 0.01), (0, 0.2, 0.025), m["metal"], 0.002)
    g.mag_straight("Mag_body", (0, -0.14, 0.0), 0.12, 0.024, 0.06, m["metal"], angle=8)
    markers((0, 0.47, 0.06), (0, 0.02, 0.165), (0, 0.18, 0.0), (0, 0.18, 0.01), (0, -0.1, 0.17))


def aug():
    m = g.mats()
    green = m["camo"]
    # Bullpup stock shell: action behind the grip, magazine behind the trigger.
    g.profile("Stock", [(-0.33, 0.105), (0.12, 0.105), (0.15, 0.085), (0.12, 0.03), (0.04, 0.02), (-0.33, 0.0)], 0.062, (0, 0, 0), green, 0.012)
    g.box("Buttpad", (0.064, 0.012, 0.105), (0, -0.335, 0.052), m["rubber"], 0.004)
    # Integrated optic housing / carry handle
    g.box("OpticHousing", (0.036, 0.2, 0.035), (0, 0.0, 0.124), green, 0.006)
    g.box("OpticFront", (0.034, 0.04, 0.03), (0, 0.11, 0.12), green, 0.006)
    g.cyl("OpticTube", 0.02, 0.18, (0, 0.0, 0.158), m["metal"], verts=24)
    g.cyl("OpticLensF", 0.019, 0.003, (0, 0.091, 0.158), m["lens"], verts=24)
    g.cyl("OpticEye", 0.022, 0.03, (0, -0.095, 0.158), m["rubber"], verts=24)
    # Folded front grip and trigger guard
    g.box("TriggerGuardFull", (0.016, 0.16, 0.012), (0, 0.11, -0.035), green, 0.004)
    g.box("Foregrip", (0.03, 0.035, 0.11), (0, 0.19, -0.03), green, 0.008, rot=(R(-8), 0, 0))
    g.pistol_grip("Grip", (0, 0.08, 0.02), green, angle=12)
    g.cyl("BarrelShroud", 0.016, 0.08, (0, 0.17, 0.075), m["metal"], verts=20)
    g.cyl("Barrel", 0.0085, 0.38, (0, 0.33, 0.075), m["metal"], verts=16)
    flash_hider(0.52, 0.075, m["metal"], 0.011)
    g.mag_straight("Mag_body", (0, -0.08, 0.01), 0.13, 0.026, 0.064, m["translucent"], angle=10)
    markers((0, 0.57, 0.075), (0, 0.0, 0.142), (0, 0.22, 0.02), (0, 0.19, -0.02), (0, -0.08, 0.158))

def fal():
    m = g.mats()
    camo = m["camo"]
    g.box("Upper", (0.036, 0.25, 0.04), (0, 0.06, 0.075), camo, 0.003)
    g.box("Lower", (0.032, 0.21, 0.04), (0, 0.05, 0.035), camo, 0.003)
    g.box("CarryHandleFold", (0.012, 0.08, 0.012), (0.024, 0.12, 0.09), m["metal"], 0.002)
    g.box("Handguard", (0.05, 0.22, 0.05), (0, 0.3, 0.065), m["wood"], 0.008, taper=(0.9, 0.9))
    for i in range(5):
        g.box("HGVent%d" % i, (0.052, 0.02, 0.006), (0, 0.22 + i * 0.04, 0.09), m["metal_worn"], 0.001)
    g.pistol_grip("Grip", (0, -0.04, 0.015), m["wood"], angle=16)
    g.trigger_group((0, -0.01, 0.015), m["metal"])
    g.profile("Stock", [(-0.07, 0.085), (-0.45, 0.07), (-0.45, -0.06), (-0.35, -0.04), (-0.07, 0.03)], 0.042, (0, 0, 0), m["wood"], 0.008)
    g.cyl("Barrel", 0.0095, 0.45, (0, 0.41 + 0.18, 0.068), m["metal"], verts=16)
    g.front_sight_post((0, 0.77, 0.076), m["metal"], height=0.04)
    g.rear_sight((0, -0.05, 0.095), m["metal"])
    flash_hider(0.83, 0.068, m["metal"], 0.012, 0.06)
    g.mag_straight("Mag_body", (0, 0.06, 0.012), 0.12, 0.028, 0.075, m["metal"], angle=4)
    markers((0, 0.89, 0.068), (0, 0.02, 0.095), (0, 0.3, 0.035), (0, 0.3, 0.04), (0, -0.05, 0.11))


def m14ebr():
    m = g.mats()
    tan = m["polymer_tan"]
    g.box("Chassis", (0.05, 0.5, 0.055), (0, 0.15, 0.06), m["camo"], 0.004)
    g.rail("TopRail", 0.46, (0, 0.13, 0.092), m["metal"])
    for s in (-1, 1):
        g.rail("SideRail", 0.2, (s * 0.027, 0.32, 0.06), m["metal"]).rotation_euler = (0, R(90 * s), 0)
    g.box("Receiver", (0.03, 0.2, 0.03), (0, 0.04, 0.085), m["metal"], 0.002)
    g.box("OpRod", (0.006, 0.18, 0.01), (0.018, 0.1, 0.075), m["metal_worn"], 0.001)
    g.pistol_grip("Grip", (0, -0.04, 0.03), m["polymer"], angle=18)
    g.trigger_group((0, -0.01, 0.03), m["metal"])
    g.cyl("BufferTube", 0.015, 0.2, (0, -0.18, 0.065), m["metal"], verts=20)
    g.profile("Stock", [(-0.38, 0.09), (-0.22, 0.09), (-0.21, 0.05), (-0.25, 0.02), (-0.38, 0.0)], 0.044, (0, 0, 0), tan, 0.005)
    g.cyl("Barrel", 0.0095, 0.46, (0, 0.4 + 0.23, 0.065), m["metal"], verts=16)
    flash_hider(0.86, 0.065, m["metal"], 0.012)
    g.scope((0, 0.06, 0.13), 0.28, 0.016, m["metal"], m["lens"])
    g.box("Bipod", (0.03, 0.04, 0.02), (0, 0.38, 0.025), m["metal"], 0.002)
    g.mag_straight("Mag_body", (0, 0.06, 0.03), 0.11, 0.028, 0.08, m["metal"], angle=3)
    markers((0, 0.91, 0.065), (0, 0.05, 0.095), (0, 0.32, 0.03), (0, 0.32, 0.03), (0, -0.09, 0.13))


def svd():
    m = g.mats()
    wood = m["wood"]
    g.box("Receiver", (0.032, 0.28, 0.042), (0, 0.06, 0.05), m["camo"], 0.0025)
    g.cyl("DustCover", 0.015, 0.24, (0, 0.05, 0.07), m["camo"], verts=20)
    g.box("Handguard", (0.045, 0.25, 0.045), (0, 0.33, 0.06), wood, 0.007)
    for i in range(6):
        g.box("HGVent%d" % i, (0.047, 0.018, 0.006), (0, 0.23 + i * 0.035, 0.08), m["metal_worn"], 0.001)
    # Skeleton thumbhole stock
    g.profile("StockTop", [(-0.08, 0.075), (-0.45, 0.07), (-0.45, 0.04), (-0.08, 0.05)], 0.036, (0, 0, 0), wood, 0.005)
    g.profile("StockBottom", [(-0.12, 0.01), (-0.45, -0.06), (-0.45, -0.03), (-0.12, 0.035)], 0.036, (0, 0, 0), wood, 0.005)
    g.box("StockRear", (0.038, 0.03, 0.14), (0, -0.44, 0.005), wood, 0.005)
    g.box("Cheekrest", (0.034, 0.12, 0.02), (0, -0.25, 0.09), m["polymer"], 0.004)
    g.pistol_grip("Grip", (0, -0.05, 0.03), wood, angle=12, height=0.08)
    g.trigger_group((0, -0.015, 0.03), m["metal"])
    g.cyl("Barrel", 0.009, 0.55, (0, 0.44 + 0.2, 0.062), m["metal"], verts=16)
    flash_hider(0.92, 0.062, m["metal"], 0.011, 0.07, "birdcage")
    g.scope((0.0, 0.05, 0.13), 0.24, 0.017, m["metal"], m["lens"])
    g.mag_curved("Mag_body", (0, 0.1, 0.03), 0.11, 0.028, 0.075, m["metal"], curve=14)
    markers((0, 0.99, 0.062), (0, 0.05, 0.095), (0, 0.33, 0.03), (0, 0.33, 0.035), (0, -0.09, 0.13))


def m24():
    m = g.mats()
    stock = m["camo"]
    g.profile("Stock", [(-0.45, 0.06), (-0.05, 0.065), (0.1, 0.06), (0.55, 0.055), (0.55, 0.02), (0.12, 0.015), (0.04, -0.02), (-0.02, -0.025), (-0.12, 0.0), (-0.45, -0.07)], 0.048, (0, 0, 0), stock, 0.01)
    g.box("Buttpad", (0.05, 0.015, 0.13), (0, -0.455, -0.005), m["rubber"], 0.004)
    g.cyl("Receiver", 0.016, 0.22, (0, 0.06, 0.075), m["metal"], verts=24)
    g.cyl("Bolt", 0.009, 0.12, (0.012, -0.02, 0.08), m["metal_worn"], verts=16)
    g.cyl("BoltHandle", 0.004, 0.05, (0.035, -0.04, 0.07), m["metal"], axis="X")
    g.box("BoltKnob", (0.014, 0.014, 0.014), (0.058, -0.04, 0.066), m["metal"], 0.006)
    g.trigger_group((0, 0.0, 0.0), m["metal"])
    g.cyl("Barrel", 0.011, 0.62, (0, 0.17 + 0.31, 0.072), m["metal"], verts=16, radius2=0.0085)
    g.scope((0, 0.06, 0.125), 0.33, 0.018, m["metal"], m["lens"])
    g.empty("Mag", (0, 0.05, 0.02))
    markers((0, 0.79, 0.072), (0, 0.06, 0.092), (0, 0.35, 0.02), (0, 0.35, 0.03), (0, -0.09, 0.125))


def m107():
    m = g.mats()
    camo = m["camo"]
    g.box("UpperReceiver", (0.06, 0.5, 0.07), (0, 0.12, 0.085), camo, 0.006)
    g.rail("TopRail", 0.42, (0, 0.1, 0.124), m["metal"])
    g.box("LowerReceiver", (0.05, 0.36, 0.045), (0, 0.0, 0.03), camo, 0.005)
    g.profile("Stock", [(-0.5, 0.12), (-0.17, 0.12), (-0.17, 0.04), (-0.5, -0.04)], 0.05, (0, 0, 0), camo, 0.008)
    g.box("Monopod", (0.02, 0.02, 0.08), (0, -0.4, -0.04), m["metal"], 0.002)
    g.pistol_grip("Grip", (0, -0.06, 0.01), m["polymer"], angle=12)
    g.trigger_group((0, -0.03, 0.01), m["metal"])
    g.cyl("Barrel", 0.016, 0.74, (0, 0.37 + 0.37, 0.085), m["metal"], verts=20)
    g.box("MuzzleBrakeBody", (0.06, 0.09, 0.035), (0, 1.15, 0.085), m["metal"], 0.006)
    for i in range(3):
        g.box("BrakeBaffle%d" % i, (0.062, 0.012, 0.037), (0, 1.12 + i * 0.03, 0.085), m["metal_worn"], 0.002)
    g.box("BipodL", (0.01, 0.01, 0.22), (-0.04, 0.5, 0.0), m["metal"], 0.002, rot=(R(-30), R(15), 0))
    g.box("BipodR", (0.01, 0.01, 0.22), (0.04, 0.5, 0.0), m["metal"], 0.002, rot=(R(-30), R(-15), 0))
    g.scope((0, 0.05, 0.17), 0.36, 0.021, m["metal"], m["lens"])
    g.mag_straight("Mag_body", (0, 0.1, 0.01), 0.1, 0.04, 0.1, m["metal"])
    markers((0, 1.2, 0.085), (0, 0.05, 0.13), (0, 0.4, 0.05), (0, 0.42, 0.05), (0, -0.14, 0.17))


# --- SMGs --------------------------------------------------------------------------

def mp5():
    m = g.mats()
    camo = m["camo"]
    g.cyl("ReceiverTube", 0.022, 0.32, (0, 0.06, 0.068), camo, verts=24)
    g.box("ReceiverBottom", (0.036, 0.28, 0.03), (0, 0.06, 0.045), camo, 0.003)
    g.cyl("CockingTube", 0.011, 0.2, (0, 0.27, 0.088), m["metal"], verts=16)
    g.box("CockingHandle", (0.004, 0.02, 0.012), (-0.018, 0.25, 0.09), m["metal"], 0.001)
    g.box("Handguard", (0.044, 0.14, 0.045), (0, 0.27, 0.045), m["polymer"], 0.008, taper=(0.9, 0.85))
    g.box("TriggerHousing", (0.03, 0.1, 0.05), (0, -0.02, 0.01), m["polymer"], 0.005)
    g.pistol_grip("Grip", (0, -0.05, 0.0), m["polymer"], angle=15)
    g.box("StockTube", (0.012, 0.22, 0.012), (0.016, -0.18, 0.07), m["metal"], 0.002)
    g.box("StockTube2", (0.012, 0.22, 0.012), (-0.016, -0.18, 0.07), m["metal"], 0.002)
    g.box("StockPad", (0.044, 0.015, 0.07), (0, -0.29, 0.058), m["rubber"], 0.004)
    # Drum rear sight and hooded front
    g.cyl("RearDrum", 0.014, 0.024, (0, -0.07, 0.098), m["metal"], axis="X")
    g.box("RearMount", (0.02, 0.03, 0.012), (0, -0.07, 0.085), m["metal"], 0.002)
    g.box("FrontMount", (0.016, 0.02, 0.03), (0, 0.33, 0.1), m["metal"], 0.002)
    g.cyl("FrontHood", 0.012, 0.018, (0, 0.33, 0.112), m["metal"], verts=16)
    g.box("FSPost", (0.003, 0.003, 0.014), (0, 0.33, 0.108), m["metal"], 0.0003)
    g.cyl("Barrel", 0.009, 0.07, (0, 0.38, 0.068), m["metal"], verts=16)
    g.cyl("BarrelLugs", 0.012, 0.02, (0, 0.4, 0.068), m["metal"], verts=16)
    g.mag_curved("Mag_body", (0, 0.07, 0.035), 0.16, 0.022, 0.035, m["metal"], curve=22)
    markers((0, 0.42, 0.068), (0, 0.02, 0.095), (0, 0.27, 0.02), (0, 0.27, 0.03), (0, -0.075, 0.112))


def ump45():
    m = g.mats()
    camo = m["camo"]
    g.profile("Body", [(-0.07, 0.1), (0.32, 0.1), (0.34, 0.06), (0.32, 0.03), (0.1, 0.03), (0.08, 0.0), (-0.07, 0.0)], 0.048, (0, 0, 0), camo, 0.006)
    g.rail("TopRail", 0.25, (0, 0.12, 0.103), m["metal"])
    g.box("GripAperture", (0.05, 0.03, 0.03), (0, 0.02, -0.01), camo, 0.005)
    g.pistol_grip("Grip", (0, -0.04, 0.0), m["polymer"])
    g.box("FoldStock", (0.02, 0.3, 0.05), (0.03, -0.2, 0.06), m["polymer"], 0.005)
    g.cyl("Barrel", 0.01, 0.05, (0, 0.36, 0.07), m["metal"], verts=16)
    g.box("BUISF", (0.004, 0.008, 0.025), (0, 0.24, 0.12), m["metal"], 0.0008)
    g.box("BUISRL", (0.004, 0.01, 0.022), (-0.008, -0.02, 0.12), m["metal"], 0.0008)
    g.box("BUISRR", (0.004, 0.01, 0.022), (0.008, -0.02, 0.12), m["metal"], 0.0008)
    g.mag_straight("Mag_body", (0, 0.13, 0.02), 0.13, 0.026, 0.05, m["polymer"], angle=6)
    markers((0, 0.39, 0.07), (0, 0.1, 0.106), (0, 0.26, 0.02), (0, 0.26, 0.03), (0, -0.03, 0.13))


def p90():
    m = g.mats()
    camo = m["camo"]
    g.profile("Body", [(-0.25, 0.08), (0.18, 0.09), (0.24, 0.06), (0.22, -0.02), (0.12, -0.05), (0.08, -0.0), (-0.05, -0.02), (-0.12, 0.0), (-0.25, -0.03)], 0.055, (0, 0, 0), camo, 0.012)
    g.box("ThumbHole", (0.058, 0.04, 0.035), (0, 0.06, -0.012), m["polymer"], 0.008)
    g.box("SightBody", (0.03, 0.1, 0.04), (0, 0.04, 0.115), m["polymer"], 0.005)
    g.box("OpticGlass", (0.024, 0.003, 0.026), (0, 0.09, 0.118), m["lens"], 0.0005)
    g.cyl("Barrel", 0.008, 0.05, (0, 0.26, 0.04), m["metal"], verts=16)
    root = g.empty("Mag", (0, -0.02, 0.095))
    g.box("TopMag", (0.042, 0.3, 0.025), (0, 0.0, 0.0), m["translucent"], 0.004, parent=root)
    markers((0, 0.29, 0.04), (0, 0.04, 0.135), (0, 0.15, -0.03), (0, 0.14, -0.03), (0, -0.04, 0.122))


def mp7():
    m = g.mats()
    camo = m["camo"]
    g.profile("Body", [(-0.06, 0.1), (0.2, 0.1), (0.22, 0.07), (0.2, 0.03), (0.05, 0.03), (-0.06, 0.04)], 0.042, (0, 0, 0), camo, 0.006)
    g.rail("TopRail", 0.22, (0, 0.08, 0.103), m["metal"])
    g.box("FoldGrip", (0.025, 0.03, 0.07), (0, 0.17, 0.0), m["polymer"], 0.005)
    root = g.empty("Mag", (0, 0.0, 0.05))
    g.profile("GripMag", [(-0.02, 0.0), (0.03, 0.0), (0.02, -0.14), (-0.03, -0.14)], 0.03, (0, 0, 0), m["polymer"], 0.005, parent=root)
    g.box("StockRods", (0.04, 0.2, 0.01), (0, -0.15, 0.08), m["metal"], 0.002)
    g.box("StockPad", (0.04, 0.012, 0.06), (0, -0.25, 0.07), m["polymer"], 0.004)
    g.cyl("Barrel", 0.008, 0.06, (0, 0.25, 0.075), m["metal"], verts=16)
    markers((0, 0.28, 0.075), (0, 0.06, 0.106), (0, 0.17, 0.02), (0, 0.17, 0.0), (0, -0.02, 0.125))


def vector():
    m = g.mats()
    camo = m["camo"]
    g.profile("Body", [(-0.05, 0.11), (0.24, 0.11), (0.26, 0.06), (0.2, -0.05), (0.1, -0.06), (0.04, 0.0), (-0.05, 0.02)], 0.046, (0, 0, 0), camo, 0.007)
    g.rail("TopRail", 0.26, (0, 0.1, 0.113), m["metal"])
    g.pistol_grip("Grip", (0, -0.03, 0.01), m["polymer"], angle=10)
    g.box("StockArm", (0.02, 0.22, 0.04), (0, -0.16, 0.07), m["polymer"], 0.004)
    g.box("StockPad", (0.04, 0.02, 0.09), (0, -0.27, 0.05), m["polymer"], 0.004)
    g.cyl("Barrel", 0.01, 0.1, (0, 0.31, 0.085), m["metal"], verts=16)
    g.mag_straight("Mag_body", (0, 0.13, -0.04), 0.13, 0.024, 0.04, m["polymer"], angle=-8)
    markers((0, 0.36, 0.085), (0, 0.08, 0.116), (0, 0.22, 0.0), (0, 0.2, -0.02), (0, -0.03, 0.138))


def mini_uzi():
    m = g.mats()
    camo = m["camo"]
    g.box("Receiver", (0.042, 0.22, 0.05), (0, 0.06, 0.06), camo, 0.004)
    g.box("TopCover", (0.044, 0.18, 0.012), (0, 0.06, 0.09), m["metal"], 0.003)
    g.box("CockingKnob", (0.014, 0.014, 0.014), (0, 0.04, 0.1), m["metal"], 0.004)
    root = g.empty("Mag", (0, 0.0, 0.035))
    g.box("GripMag", (0.03, 0.045, 0.16), (0, 0.0, -0.06), m["polymer"], 0.005, parent=root, rot=(R(-8), 0, 0))
    g.box("TriggerGuard", (0.012, 0.06, 0.025), (0, 0.045, 0.02), m["metal"], 0.002)
    g.box("WireStock", (0.035, 0.22, 0.008), (0, -0.14, 0.06), m["metal"], 0.002)
    g.cyl("Barrel", 0.009, 0.06, (0, 0.2, 0.06), m["metal"], verts=16)
    g.box("FSight", (0.01, 0.01, 0.025), (0, 0.15, 0.105), m["metal"], 0.001)
    g.box("RSight", (0.016, 0.01, 0.02), (0, -0.02, 0.105), m["metal"], 0.001)
    markers((0, 0.23, 0.06), (0, 0.05, 0.096), (0, 0.14, 0.03), (0, 0.13, 0.03), (0, -0.02, 0.112))


# --- LMGs ----------------------------------------------------------------------------

def m249():
    m = g.mats()
    camo = m["camo"]
    g.box("Receiver", (0.06, 0.3, 0.075), (0, 0.06, 0.06), camo, 0.005)
    g.box("FeedCover", (0.062, 0.18, 0.02), (0, 0.04, 0.105), m["metal"], 0.004)
    g.rail("TopRail", 0.16, (0, 0.03, 0.117), m["metal"])
    g.box("Handguard", (0.06, 0.17, 0.05), (0, 0.3, 0.05), m["polymer"], 0.008)
    g.pistol_grip("Grip", (0, -0.05, 0.03), m["polymer"])
    g.trigger_group((0, -0.02, 0.03), m["metal"])
    g.profile("Stock", [(-0.38, 0.1), (-0.09, 0.09), (-0.09, 0.04), (-0.38, -0.02)], 0.05, (0, 0, 0), m["polymer"], 0.008)
    g.cyl("Barrel", 0.013, 0.42, (0, 0.4 + 0.21, 0.065), m["metal"], verts=20)
    g.cyl("CarryHandleB", 0.006, 0.12, (0, 0.5, 0.1), m["metal"])
    flash_hider(0.82, 0.065, m["metal"], 0.014)
    g.box("BipodL", (0.008, 0.008, 0.2), (-0.025, 0.7, 0.0), m["metal"], 0.002, rot=(R(-40), R(10), 0))
    g.box("BipodR", (0.008, 0.008, 0.2), (0.025, 0.7, 0.0), m["metal"], 0.002, rot=(R(-40), R(-10), 0))
    root = g.empty("Mag", (-0.05, 0.08, 0.04))
    g.box("AmmoBox", (0.07, 0.11, 0.1), (-0.0, 0.0, -0.04), m["olive"], 0.006, parent=root)
    g.box("FrontSight", (0.008, 0.01, 0.04), (0, 0.77, 0.095), m["metal"], 0.001)
    markers((0, 0.87, 0.065), (0, 0.03, 0.12), (0, 0.3, 0.02), (0, 0.3, 0.03), (0, -0.04, 0.135))


def m60e4():
    m = g.mats()
    camo = m["camo"]
    g.box("Receiver", (0.058, 0.36, 0.07), (0, 0.06, 0.06), camo, 0.005)
    g.box("FeedCover", (0.06, 0.2, 0.02), (0, 0.04, 0.102), m["metal"], 0.004)
    g.rail("TopRail", 0.18, (0, 0.04, 0.114), m["metal"])
    g.box("Handguard", (0.065, 0.26, 0.06), (0, 0.36, 0.05), m["polymer"], 0.008)
    g.box("ForeGrip", (0.03, 0.035, 0.09), (0, 0.4, -0.01), m["polymer"], 0.006)
    g.pistol_grip("Grip", (0, -0.05, 0.03), m["polymer"])
    g.trigger_group((0, -0.02, 0.03), m["metal"])
    g.profile("Stock", [(-0.42, 0.1), (-0.12, 0.09), (-0.12, 0.03), (-0.42, -0.04)], 0.05, (0, 0, 0), m["polymer"], 0.008)
    g.cyl("Barrel", 0.013, 0.48, (0, 0.5 + 0.24, 0.065), m["metal"], verts=20)
    flash_hider(0.98, 0.065, m["metal"], 0.015, 0.07, "brake")
    root = g.empty("Mag", (-0.05, 0.08, 0.04))
    g.box("AmmoBox", (0.07, 0.12, 0.1), (0, 0, -0.04), m["olive"], 0.006, parent=root)
    markers((0, 1.05, 0.065), (0, 0.04, 0.117), (0, 0.4, 0.02), (0, 0.4, 0.03), (0, -0.04, 0.132))


def pkm():
    m = g.mats()
    camo = m["camo"]
    g.box("Receiver", (0.05, 0.36, 0.06), (0, 0.06, 0.06), camo, 0.004)
    g.box("FeedCover", (0.052, 0.2, 0.018), (0, 0.04, 0.098), m["metal"], 0.003)
    g.profile("Stock", [(-0.12, 0.08), (-0.42, 0.07), (-0.42, -0.04), (-0.38, -0.04), (-0.12, 0.03)], 0.038, (0, 0, 0), m["wood"], 0.006)
    g.box("StockHole", (0.04, 0.15, 0.03), (0, -0.28, 0.02), m["wood"], 0.004)
    g.pistol_grip("Grip", (0, -0.06, 0.03), m["wood"], angle=20)
    g.trigger_group((0, -0.03, 0.03), m["metal"])
    g.cyl("Barrel", 0.012, 0.6, (0, 0.24 + 0.3, 0.06), m["metal"], verts=20)
    g.cyl("GasTube", 0.008, 0.3, (0, 0.36, 0.04), m["metal"], verts=16)
    g.box("CarryHandle", (0.01, 0.1, 0.03), (0, 0.4, 0.09), m["wood"], 0.004)
    flash_hider(0.84, 0.06, m["metal"], 0.013, 0.07)
    g.box("RearSight", (0.02, 0.04, 0.02), (0, 0.13, 0.115), m["metal"], 0.002)
    g.box("FrontSight", (0.008, 0.01, 0.05), (0, 0.8, 0.09), m["metal"], 0.001)
    root = g.empty("Mag", (-0.05, 0.06, 0.04))
    g.box("AmmoBox", (0.07, 0.14, 0.12), (0, 0, -0.05), m["olive"], 0.006, parent=root)
    markers((0, 0.91, 0.06), (0, 0.04, 0.108), (0, 0.4, 0.02), (0, 0.4, 0.03), (0, 0.12, 0.12))


# --- Pistols -------------------------------------------------------------------------

def pistol(name, slide_len=0.2, slide_h=0.034, width=0.028, grip_h=0.115, long_mag=False, burst_grip=False, color_frame=None):
    m = g.mats()
    camo = m["camo"]
    frame = color_frame or m["polymer"]
    g.box("Slide", (width, slide_len, slide_h), (0, slide_len * 0.32, 0.06), camo, 0.003)
    for i in range(7):
        g.box("Serration%d" % i, (width + 0.001, 0.003, slide_h * 0.7), (0, -slide_len * 0.1 + i * 0.006, 0.06), m["metal_worn"], 0.0004)
    g.box("EjectPort", (0.002, 0.04, 0.012), (width / 2, slide_len * 0.3, 0.065), m["metal_worn"], 0.0005)
    g.box("Frame", (width * 0.95, slide_len * 0.85, 0.022), (0, slide_len * 0.3, 0.033), frame, 0.003)
    g.pistol_grip("Grip", (0, -0.035, 0.03), frame, angle=14, height=grip_h, depth=0.048, width=width * 1.05)
    g.box("TriggerGuard", (0.01, 0.05, 0.004), (0, 0.03, 0.003), frame, 0.001)
    g.box("TriggerGuardF", (0.01, 0.004, 0.028), (0, 0.055, 0.016), frame, 0.001)
    g.box("Trigger", (0.004, 0.006, 0.018), (0, 0.025, 0.014), m["metal"], 0.001)
    g.box("Hammer", (0.008, 0.012, 0.014), (0, -0.07, 0.075), m["metal"], 0.002)
    g.box("FrontSight", (0.004, 0.006, 0.008), (0, slide_len * 0.78, 0.081), m["metal"], 0.0006)
    g.box("RearSight", (0.02, 0.008, 0.008), (0, -0.05, 0.081), m["metal"], 0.0008)
    if burst_grip:
        g.box("FoldGrip", (0.02, 0.02, 0.05), (0, slide_len * 0.6, 0.0), m["metal"], 0.003)
        g.cyl("Comp", 0.012, 0.05, (0, slide_len * 0.85, 0.055), m["metal"], verts=16)
    root = g.empty("Mag", (0, -0.03, 0.02))
    mh = 0.11 if not long_mag else 0.17
    g.box("PistolMag", (width * 0.7, 0.035, mh), (0, 0, -mh / 2), m["metal"], 0.002, parent=root, rot=(R(-14), 0, 0))
    g.box("MagBase", (width * 0.9, 0.042, 0.008), (0, -0.012, -mh + 0.002), frame, 0.002, parent=root)
    muz = slide_len * 0.82 + (0.04 if burst_grip else 0)
    markers((0, muz, 0.06), (0, 0.02, 0.078), (0, 0.08, 0.02), (0, -0.02, 0.0), (0, -0.05, 0.085))


def m9():
    pistol("m9", 0.2, 0.034, 0.03)


def usp45():
    pistol("usp45", 0.2, 0.036, 0.031)


def p226():
    pistol("p226", 0.19, 0.036, 0.03, color_frame=g.mats()["metal"])


def m93r():
    pistol("m93r", 0.24, 0.034, 0.03, long_mag=True, burst_grip=True)


def magnum():
    m = g.mats()
    camo = m["camo"]
    g.box("Frame", (0.03, 0.09, 0.05), (0, 0.0, 0.06), camo, 0.004)
    g.cyl("Cylinder", 0.021, 0.045, (0, 0.03, 0.06), m["metal"], verts=6)
    for i in range(6):
        a = i * math.tau / 6
        g.cyl("Flute%d" % i, 0.004, 0.046, (math.cos(a) * 0.02, 0.03, 0.06 + math.sin(a) * 0.02), m["metal_worn"], verts=8)
    g.cyl("Barrel", 0.011, 0.2, (0, 0.16, 0.072), camo, verts=16)
    g.box("BarrelRib", (0.012, 0.2, 0.01), (0, 0.16, 0.085), camo, 0.002)
    g.box("Lug", (0.014, 0.18, 0.016), (0, 0.15, 0.058), camo, 0.002)
    g.box("FrontSight", (0.004, 0.012, 0.012), (0, 0.25, 0.095), m["metal"], 0.0006)
    g.box("Hammer", (0.008, 0.015, 0.02), (0, -0.05, 0.085), m["metal"], 0.002)
    g.pistol_grip("Grip", (0, -0.045, 0.04), m["wood"], angle=25, height=0.11, depth=0.045, width=0.034)
    g.box("TriggerGuard", (0.01, 0.045, 0.004), (0, 0.01, 0.01), camo, 0.001)
    g.empty("Mag", (0, 0.03, 0.06))
    markers((0, 0.27, 0.072), (0, 0.06, 0.09), (0, 0.15, 0.04), (0, -0.03, 0.0), (0, -0.04, 0.095))


def skorpion():
    m = g.mats()
    camo = m["camo"]
    g.box("Receiver", (0.03, 0.17, 0.035), (0, 0.04, 0.06), camo, 0.003)
    g.pistol_grip("Grip", (0, -0.04, 0.04), m["wood"], angle=20, height=0.08)
    g.box("TriggerGuard", (0.01, 0.05, 0.004), (0, 0.015, 0.025), m["metal"], 0.001)
    g.box("WireStock", (0.025, 0.2, 0.01), (0, -0.14, 0.072), m["metal"], 0.002)
    g.cyl("Barrel", 0.008, 0.06, (0, 0.15, 0.06), m["metal"], verts=16)
    g.box("FSight", (0.008, 0.008, 0.02), (0, 0.11, 0.087), m["metal"], 0.001)
    g.box("RSight", (0.014, 0.008, 0.016), (0, -0.03, 0.085), m["metal"], 0.001)
    g.mag_curved("Mag_body", (0, 0.07, 0.045), 0.14, 0.02, 0.03, m["metal"], curve=28)
    markers((0, 0.18, 0.06), (0, 0.03, 0.078), (0, 0.11, 0.03), (0, 0.06, 0.02), (0, -0.03, 0.093))


def tmp():
    m = g.mats()
    camo = m["camo"]
    g.profile("Body", [(-0.08, 0.1), (0.16, 0.1), (0.18, 0.06), (0.15, 0.03), (-0.08, 0.04)], 0.04, (0, 0, 0), camo, 0.006)
    g.rail("TopRail", 0.16, (0, 0.04, 0.103), m["metal"])
    g.box("FrontGrip", (0.022, 0.025, 0.06), (0, 0.13, 0.005), m["polymer"], 0.005)
    root = g.empty("Mag", (0, -0.02, 0.06))
    g.box("GripMag", (0.03, 0.045, 0.15), (0, 0, -0.06), m["polymer"], 0.005, parent=root, rot=(R(-6), 0, 0))
    g.cyl("Barrel", 0.008, 0.05, (0, 0.2, 0.075), m["metal"], verts=16)
    markers((0, 0.225, 0.075), (0, 0.04, 0.106), (0, 0.12, 0.03), (0, 0.13, 0.0), (0, -0.06, 0.125))


# --- Shotguns ------------------------------------------------------------------------

def shotgun(name, barrel=0.47, tube=True, pump=False, stock="fixed", heavy=False):
    m = g.mats()
    camo = m["camo"]
    g.box("Receiver", (0.04, 0.2, 0.06), (0, 0.05, 0.055), camo, 0.005)
    g.rail("TopRail", 0.16, (0, 0.04, 0.088), m["metal"])
    g.pistol_grip("Grip", (0, -0.05, 0.025), m["polymer"])
    g.trigger_group((0, -0.02, 0.025), m["metal"])
    g.box("LoadingPort", (0.03, 0.08, 0.004), (0, 0.07, 0.024), m["metal_worn"], 0.001)
    if stock == "fixed":
        g.profile("Stock", [(-0.4, 0.09), (-0.05, 0.085), (-0.05, 0.04), (-0.4, -0.04)], 0.044, (0, 0, 0), m["polymer"], 0.008)
    elif stock == "folding":
        g.box("FoldStockTop", (0.008, 0.26, 0.01), (0, -0.18, 0.08), m["metal"], 0.002)
        g.box("FoldStockHook", (0.008, 0.05, 0.08), (0, -0.3, 0.05), m["metal"], 0.002)
    else:
        g.cyl("BufferTube", 0.015, 0.18, (0, -0.14, 0.065), m["metal"])
        g.profile("Stock", [(-0.34, 0.09), (-0.2, 0.09), (-0.2, 0.04), (-0.34, 0.0)], 0.042, (0, 0, 0), m["polymer"], 0.005)
    g.cyl("Barrel", 0.0125, barrel, (0, 0.15 + barrel / 2, 0.07), m["metal"], verts=20)
    if tube:
        g.cyl("MagTube", 0.011, barrel * 0.75, (0, 0.15 + barrel * 0.375, 0.042), m["metal"], verts=16)
    if pump:
        g.box("Pump", (0.05, 0.14, 0.045), (0, 0.27, 0.045), m["polymer"], 0.008)
        for i in range(5):
            g.box("PumpRib%d" % i, (0.052, 0.006, 0.04), (0, 0.21 + i * 0.025, 0.045), m["polymer"], 0.001)
    else:
        g.box("Forend", (0.046, 0.15, 0.04), (0, 0.27, 0.045), m["polymer"], 0.007)
    g.box("Bead", (0.004, 0.004, 0.006), (0, 0.15 + barrel - 0.01, 0.087), m["brass"], 0.001)
    g.box("GhostRing", (0.016, 0.008, 0.016), (0, -0.03, 0.1), m["metal"], 0.002)
    if heavy:
        g.mag_drum("Mag_body", (0, 0.05, 0.03), 0.08, 0.06, m["polymer"])
    else:
        g.empty("Mag", (0, 0.07, 0.025))
    muz = 0.15 + barrel
    markers((0, muz, 0.07), (0, 0.03, 0.091), (0, 0.3, 0.02), (0, 0.27, 0.02), (0, -0.03, 0.103))


def m1014():
    shotgun("m1014", 0.47, True, False, "collapsible")


def spas12():
    shotgun("spas12", 0.45, True, True, "folding")


def aa12():
    m = g.mats()
    camo = m["camo"]
    g.box("Body", (0.06, 0.5, 0.09), (0, 0.08, 0.07), camo, 0.008)
    g.box("TopHandle", (0.03, 0.3, 0.014), (0, 0.06, 0.15), m["polymer"], 0.004)
    g.box("HandlePostF", (0.03, 0.02, 0.04), (0, 0.2, 0.13), m["polymer"], 0.004)
    g.box("HandlePostR", (0.03, 0.02, 0.04), (0, -0.08, 0.13), m["polymer"], 0.004)
    g.pistol_grip("Grip", (0, -0.05, 0.025), m["polymer"])
    g.trigger_group((0, -0.02, 0.025), m["metal"])
    g.profile("Stock", [(-0.38, 0.1), (-0.17, 0.11), (-0.17, 0.03), (-0.38, -0.02)], 0.05, (0, 0, 0), m["polymer"], 0.008)
    g.cyl("Barrel", 0.014, 0.18, (0, 0.38, 0.08), m["metal"], verts=20)
    g.mag_drum("Mag_body", (0, 0.1, 0.025), 0.085, 0.07, m["polymer"])
    markers((0, 0.47, 0.08), (0, 0.06, 0.158), (0, 0.25, 0.025), (0, 0.25, 0.03), (0, -0.07, 0.168))


def double_barrel():
    m = g.mats()
    g.profile("Stock", [(-0.42, 0.06), (-0.06, 0.055), (0.0, 0.03), (-0.06, -0.005), (-0.42, -0.07)], 0.04, (0, 0, 0), m["wood"], 0.01)
    g.box("Action", (0.044, 0.08, 0.05), (0, 0.04, 0.045), m["camo"], 0.006)
    for x in (-0.011, 0.011):
        g.cyl("Barrel", 0.011, 0.62, (x, 0.08 + 0.31, 0.06), m["metal"], verts=20)
    g.box("Rib", (0.008, 0.62, 0.006), (0, 0.39, 0.073), m["metal"], 0.001)
    g.box("Forend", (0.04, 0.2, 0.025), (0, 0.22, 0.04), m["wood"], 0.008)
    g.box("TriggerGuard", (0.01, 0.06, 0.004), (0, 0.0, 0.01), m["metal"], 0.001)
    g.box("Bead", (0.004, 0.004, 0.005), (0, 0.69, 0.079), m["brass"], 0.001)
    g.empty("Mag", (0, 0.06, 0.05))
    markers((0, 0.7, 0.06), (0, 0.04, 0.07), (0, 0.25, 0.02), (0, 0.24, 0.02), (0, -0.04, 0.082))


# --- Launchers -----------------------------------------------------------------------

def rpg7():
    m = g.mats()
    g.cyl("Tube", 0.026, 0.95, (0, 0.15, 0.08), m["camo"], verts=24)
    g.cyl("Venturi", 0.04, 0.16, (0, -0.38, 0.08), m["camo"], radius2=0.026, verts=24)
    g.cyl("HeatShield", 0.034, 0.3, (0, 0.02, 0.08), m["wood"], verts=24)
    g.pistol_grip("Grip", (0, -0.01, 0.055), m["wood"])
    g.pistol_grip("Grip2", (0, 0.22, 0.055), m["wood"])
    g.box("SightBody", (0.02, 0.1, 0.05), (-0.04, 0.02, 0.12), m["metal"], 0.004)
    root = g.empty("Mag", (0, 0.62, 0.08))
    g.cyl("Warhead", 0.042, 0.2, (0, 0.14, 0.0), m["olive"], verts=24, radius2=0.0, parent=root)
    g.cyl("WarheadBase", 0.042, 0.06, (0, 0.01, 0.0), m["olive"], verts=24, parent=root)
    g.cyl("Sustainer", 0.02, 0.06, (0, -0.03, 0.0), m["olive"], verts=16, parent=root)
    markers((0, 0.62, 0.08), (0, 0.02, 0.12), (0, 0.3, 0.04), (0, 0.22, 0.03), (-0.04, -0.05, 0.13))


def at4():
    m = g.mats()
    g.cyl("Tube", 0.042, 1.0, (0, 0.18, 0.09), m["camo"], verts=24)
    g.cyl("FrontCap", 0.046, 0.04, (0, 0.67, 0.09), m["rubber"], verts=24)
    g.cyl("RearCap", 0.05, 0.06, (0, -0.3, 0.09), m["rubber"], verts=24)
    g.box("GripBlock", (0.03, 0.04, 0.09), (0, 0.0, 0.02), m["polymer"], 0.005)
    g.box("FrontGrip", (0.03, 0.04, 0.06), (0, 0.25, 0.03), m["polymer"], 0.005)
    g.box("SightFront", (0.02, 0.02, 0.04), (-0.05, 0.3, 0.13), m["metal"], 0.002)
    g.box("SightRear", (0.02, 0.02, 0.04), (-0.05, 0.0, 0.13), m["metal"], 0.002)
    g.empty("Mag", (0, 0.2, 0.09))
    markers((0, 0.7, 0.09), (0, 0.1, 0.14), (0, 0.3, 0.04), (0, 0.25, 0.03), (-0.05, -0.05, 0.15))


def m79():
    m = g.mats()
    g.cyl("Barrel", 0.024, 0.35, (0, 0.24, 0.07), m["camo"], verts=24)
    g.box("Action", (0.044, 0.08, 0.055), (0, 0.04, 0.06), m["metal"], 0.006)
    g.profile("Stock", [(-0.34, 0.08), (0.0, 0.065), (0.0, 0.03), (-0.34, -0.04)], 0.042, (0, 0, 0), m["wood"], 0.01)
    g.box("Forend", (0.04, 0.14, 0.03), (0, 0.17, 0.035), m["wood"], 0.008)
    g.box("LeafSight", (0.02, 0.01, 0.04), (0, 0.12, 0.11), m["metal"], 0.002)
    g.box("TriggerGuard", (0.01, 0.05, 0.004), (0, 0.0, 0.015), m["metal"], 0.001)
    g.empty("Mag", (0, 0.06, 0.07))
    markers((0, 0.42, 0.07), (0, 0.05, 0.098), (0, 0.25, 0.04), (0, 0.17, 0.02), (0, -0.02, 0.12))


WEAPONS = {
    "m4a1": m4a1, "m16a4": m16a4, "hk416": hk416, "ak47": ak47, "ak74": ak74, "rpk": rpk,
    "scar_h": scar_h, "g36c": g36c, "famas": famas, "aug": aug, "fal": fal,
    "m14ebr": m14ebr, "svd": svd, "m24": m24, "m107": m107,
    "mp5": mp5, "ump45": ump45, "p90": p90, "mp7": mp7, "vector": vector, "mini_uzi": mini_uzi,
    "m249": m249, "m60e4": m60e4, "pkm": pkm,
    "m9": m9, "usp45": usp45, "p226": p226, "m93r": m93r, "magnum": magnum, "skorpion": skorpion, "tmp": tmp,
    "m1014": m1014, "spas12": spas12, "aa12": aa12, "double_barrel": double_barrel,
    "rpg7": rpg7, "at4": at4, "m79": m79,
}


# --- Attachments ------------------------------------------------------------------------
# Origin = the mount marker. +Y forward, +Z up.

def att_reflex():
    m = g.mats()
    g.box("Mount", (0.024, 0.04, 0.008), (0, 0, 0.004), m["metal"], 0.0015)
    g.box("Housing", (0.03, 0.03, 0.012), (0, 0.0, 0.014), m["metal"], 0.003)
    g.profile("Hood", [(-0.01, 0.0), (0.012, 0.0), (0.012, 0.03), (0.0, 0.034), (-0.01, 0.03)], 0.03, (0, 0, 0.012), m["metal"], 0.002)
    g.box("Glass", (0.024, 0.002, 0.022), (0, 0.006, 0.03), m["glass"], 0.0)
    g.box("Reticle", (0.0015, 0.0005, 0.0015), (0, 0.004, 0.031), m["red"], 0.0)
    g.empty("Eye", (0, 0.0, 0.031))


def att_holo():
    m = g.mats()
    g.box("Base", (0.034, 0.09, 0.018), (0, 0, 0.009), m["metal"], 0.003)
    for y in (-0.035, 0.035):
        g.box("HoodPost", (0.004, 0.008, 0.035), (-0.018, y, 0.035), m["metal"], 0.001)
        g.box("HoodPost", (0.004, 0.008, 0.035), (0.018, y, 0.035), m["metal"], 0.001)
        g.box("HoodTop", (0.04, 0.008, 0.004), (0, y, 0.054), m["metal"], 0.001)
    g.box("Window", (0.032, 0.002, 0.03), (0, 0.03, 0.036), m["glass"], 0.0)
    g.box("Ring", (0.006, 0.0005, 0.006), (0, 0.028, 0.036), m["red"], 0.0)
    g.empty("Eye", (0, -0.02, 0.036))


def att_scope(thermal=False):
    m = g.mats()
    g.box("Mount", (0.024, 0.06, 0.012), (0, 0, 0.006), m["metal"], 0.002)
    if thermal:
        g.box("Body", (0.05, 0.14, 0.055), (0, 0.0, 0.04), m["polymer"], 0.006)
        g.cyl("Lens", 0.022, 0.03, (0, 0.08, 0.04), m["lens"], verts=24)
        g.cyl("Eyepiece", 0.016, 0.03, (0, -0.08, 0.04), m["rubber"], verts=24)
        g.empty("Eye", (0, -0.05, 0.04))
    else:
        g.profile("Body", [(-0.05, 0.012), (0.05, 0.012), (0.055, 0.03), (0.03, 0.05), (-0.04, 0.045), (-0.055, 0.03)], 0.034, (0, 0, 0), m["metal"], 0.004)
        g.cyl("Objective", 0.016, 0.02, (0, 0.06, 0.033), m["lens"], verts=24)
        g.box("FiberOptic", (0.006, 0.06, 0.006), (0, 0.0, 0.052), g.material("Fiber", (0.9, 0.2, 0.1), 0, 0.3, emission=(0.8, 0.15, 0.05)), 0.001)
        g.empty("Eye", (0, -0.03, 0.033))


def att_suppressor():
    m = g.mats()
    g.cyl("Can", 0.019, 0.17, (0, 0.085, 0), m["metal"], verts=24)
    g.cyl("Mount", 0.016, 0.03, (0, 0.0, 0), m["metal_worn"], verts=24)
    g.cyl("EndCap", 0.018, 0.01, (0, 0.17, 0), m["metal_worn"], verts=24)


def att_gl():
    m = g.mats()
    g.cyl("Tube", 0.022, 0.24, (0, 0.04, -0.035), m["metal"], verts=24)
    g.box("Receiver", (0.034, 0.12, 0.03), (0, -0.04, -0.02), m["camo"], 0.004)
    g.box("Trigger", (0.012, 0.03, 0.03), (0, -0.07, -0.045), m["metal"], 0.002)


def att_masterkey():
    m = g.mats()
    g.cyl("Tube", 0.014, 0.25, (0, 0.03, -0.03), m["metal"], verts=20)
    g.cyl("MagTube", 0.011, 0.2, (0, 0.03, -0.055), m["metal"], verts=16)
    g.box("Receiver", (0.03, 0.1, 0.03), (0, -0.05, -0.025), m["metal"], 0.003)


def att_grip():
    m = g.mats()
    g.box("Clamp", (0.026, 0.035, 0.012), (0, 0, -0.006), m["metal"], 0.002)
    g.cyl("Grip", 0.013, 0.085, (0, 0, -0.05), m["polymer"], axis="Z", verts=16)
    g.cyl("Cap", 0.014, 0.006, (0, 0, -0.093), m["rubber"], axis="Z", verts=16)


def att_pulse():
    m = g.mats()
    g.box("Clamp", (0.026, 0.035, 0.012), (0, 0, -0.006), m["metal"], 0.002)
    g.box("Unit", (0.06, 0.05, 0.06), (0, -0.04, -0.03), m["polymer"], 0.006, rot=(R(30), 0, 0))
    g.box("Screen", (0.05, 0.002, 0.04), (0, -0.065, -0.02), g.material("Screen", (0.1, 0.4, 0.15), 0, 0.2, emission=(0.1, 0.6, 0.2)), 0.0, rot=(R(30), 0, 0))


ATTACHMENTS = {
    "reflex": att_reflex, "holo": att_holo, "marksman_scope": att_scope, "thermal": lambda: att_scope(True),
    "suppressor": att_suppressor, "underbarrel_gl": att_gl, "underbarrel_shotgun": att_masterkey,
    "grip": att_grip, "pulse_tracker": att_pulse,
}


# --- Equipment --------------------------------------------------------------------------

def eq_frag():
    m = g.mats()
    import bpy as _b
    g.sphere("Body", 0.034, (0, 0, 0), m["olive"], scale=(1, 1, 1.15))
    for i in range(6):
        g.box("Seg%d" % i, (0.071, 0.003, 0.07), (0, 0, 0), m["olive"], 0.001, rot=(0, 0, R(i * 30)))
    g.cyl("Fuse", 0.012, 0.025, (0, 0, 0.045), m["metal"], axis="Z", verts=16)
    g.box("Spoon", (0.012, 0.004, 0.07), (0.02, 0, 0.02), m["metal"], 0.001, rot=(0, R(-12), 0))
    g.cyl("Ring", 0.012, 0.003, (-0.018, 0, 0.06), m["metal"], axis="X", verts=16)


def eq_canister(color):
    m = g.mats()
    mat = g.material("Can_%s" % color, {"smoke": (0.15, 0.22, 0.12), "flash": (0.25, 0.25, 0.27), "stun": (0.3, 0.3, 0.15)}[color], 0.5, 0.5)
    g.cyl("Body", 0.025, 0.11, (0, 0, 0), mat, axis="Z", verts=24)
    g.cyl("Top", 0.015, 0.02, (0, 0, 0.065), m["metal"], axis="Z", verts=16)
    g.box("Spoon", (0.01, 0.004, 0.08), (0.022, 0, 0.0), m["metal"], 0.001)
    g.box("Band", (0.052, 0.052, 0.012), (0, 0, 0.02), m["polymer"], 0.004)


def eq_sticky():
    m = g.mats()
    g.cyl("Body", 0.028, 0.08, (0, 0, 0), m["olive"], axis="Z", verts=24)
    g.cyl("Gel", 0.03, 0.012, (0, 0, -0.045), g.material("Gel", (0.6, 0.55, 0.2), 0, 0.2), axis="Z", verts=24)
    g.box("Light", (0.008, 0.008, 0.008), (0, 0, 0.045), m["red"], 0.001)


def eq_hatchet():
    m = g.mats()
    g.box("Handle", (0.018, 0.022, 0.32), (0, 0, 0.0), m["polymer"], 0.004)
    g.profile("Blade", [(-0.02, 0.0), (0.06, 0.02), (0.08, -0.04), (0.06, -0.08), (-0.02, -0.03)], 0.006, (0, 0, 0.17), m["metal"], 0.001)


def eq_mine():
    m = g.mats()
    o = g.box("Body", (0.22, 0.04, 0.12), (0, 0, 0.1), m["olive"], 0.006)
    g.bend(o, 25, "Z")
    for x in (-0.07, 0.07):
        g.box("Leg", (0.006, 0.006, 0.08), (x, 0, 0.03), m["metal"], 0.001, rot=(R(10), 0, 0))
    g.box("Light", (0.01, 0.01, 0.01), (0, -0.025, 0.155), m["red"], 0.001)


def eq_breach():
    m = g.mats()
    g.box("Block", (0.12, 0.08, 0.045), (0, 0, 0), g.material("C4", (0.75, 0.72, 0.6), 0, 0.8), 0.004)
    g.box("Detonator", (0.04, 0.03, 0.02), (0.02, 0, 0.03), m["olive"], 0.003)
    g.box("Antenna", (0.003, 0.003, 0.08), (0.035, 0.005, 0.07), m["metal"], 0.0005)
    g.box("Light", (0.008, 0.008, 0.008), (0.005, 0, 0.042), m["red"], 0.001)


def eq_beacon():
    m = g.mats()
    g.cyl("Body", 0.025, 0.16, (0, 0, 0.08), m["polymer"], axis="Z", verts=16)
    g.cyl("Spike", 0.008, 0.06, (0, 0, -0.02), m["metal"], axis="Z", verts=8, radius2=0.0)
    g.cyl("Light", 0.012, 0.03, (0, 0, 0.175), m["red"], axis="Z", verts=16)


def eq_rocket():
    m = g.mats()
    g.cyl("Warhead", 0.042, 0.2, (0, 0.24, 0), m["olive"], verts=24, radius2=0.0)
    g.cyl("Body", 0.042, 0.12, (0, 0.08, 0), m["olive"], verts=24)
    g.cyl("Motor", 0.02, 0.3, (0, -0.13, 0), m["metal"], verts=16)
    for i in range(4):
        g.box("Fin%d" % i, (0.002, 0.06, 0.04), (0, -0.25, 0), m["metal"], 0.0005, rot=(0, R(i * 45), 0))


def eq_grenade_round():
    m = g.mats()
    g.cyl("Shell", 0.02, 0.04, (0, 0, 0), m["brass"], verts=16)
    g.cyl("Tip", 0.02, 0.03, (0, 0.035, 0), m["olive"], verts=16, radius2=0.008)


EQUIPMENT = {
    "shard_grenade": eq_frag, "flash_pop": lambda: eq_canister("flash"), "dazer": lambda: eq_canister("stun"),
    "smoke_canister": lambda: eq_canister("smoke"), "sticky_charge": eq_sticky, "hatchet": eq_hatchet,
    "tripwire_mine": eq_mine, "breach_charge": eq_breach, "spawn_beacon": eq_beacon,
    "rocket": eq_rocket, "grenade_round": eq_grenade_round,
}


def main():
    """Weapons and attachments are rebuilt by default. Name ids to rebuild only
    those. Pass --equipment to rebuild the equipment models (plain GLB)."""
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    with_equipment = "--equipment" in argv
    argv = [a for a in argv if not a.startswith("--")]
    for d in (OUT_W, OUT_A, OUT_E):
        os.makedirs(d, exist_ok=True)
    jobs = []
    for k, fn in WEAPONS.items():
        jobs.append((k, fn, OUT_W, 2048))
    for k, fn in ATTACHMENTS.items():
        jobs.append((k, fn, OUT_A, 1024))
    if with_equipment:
        for k, fn in EQUIPMENT.items():
            jobs.append((k, fn, OUT_E, 0))
    failed = []
    for name, fn, out, res in jobs:
        if argv and name not in argv:
            continue
        g.reset_scene()
        try:
            fn()
            if res:
                g.export(os.path.join(out, name + ".gltf"), res=res)
            else:
                g.export_glb(os.path.join(out, name + ".glb"))
            print("BUILT", name)
        except Exception as e:  # keep going; report at the end
            import traceback
            traceback.print_exc()
            print("FAILED", name, e)
            failed.append(name)
    if failed:
        print("FAILED MODELS:", " ".join(failed))
        sys.exit(1)


main()
