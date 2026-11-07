"""Anatomy of the first-person hands and arms, for the model and for the rig.

The module needs only Python and numpy. Two scripts use it:

- tools/blender/build_characters.py builds the glove and sleeve meshes from
  the signed distance field (SDF) here: anatomical parts (finger bones,
  palm rows, the thenar muscle at the thumb, the wrist, a glove cuff and a
  folded sleeve) are joined with smooth blends, then meshed with surface nets.
- tools/rig_arms.py adds the skeleton. The bones use the same joint points,
  and the skin weights come from the same parts, so each joint bends where
  the model has its knuckle.

All positions are in Blender weapon space (x right, y muzzle, z up, origin at
the top of the pistol grip). The rest pose is the grip on the weapon: each
finger wraps a cylinder (the grip or the handguard), as in the old wrap_hand().

On each finger bone, +Y points along the bone, +X is the curl axis (a positive
rotation closes the finger) and +Z points to the palm side.
"""
import itertools
import math

import numpy as np

FINGERS = [  # name, proximal, middle, distal lengths, radius
    ("Index", 0.044, 0.026, 0.022, 0.0098),
    ("Middle", 0.048, 0.03, 0.023, 0.0102),
    ("Ring", 0.045, 0.028, 0.022, 0.0098),
    ("Pinky", 0.036, 0.021, 0.019, 0.0086),
]
CHAIN_NAMES = ("Thumb", "Index", "Middle", "Ring", "Pinky")
FINGER_SPACING = 0.0205
R18 = math.radians(18)
GRIP_TOP = (0.0, -0.02, 0.0)
GRIP_AXIS = (0.0, -math.sin(R18), -math.cos(R18))
LEFT_REF = (0.0, 0.25, 0.04)

# Material zones of the glove.
ZONE_LEATHER = 0  # palm, finger pads and finger tips
ZONE_FABRIC = 1  # stretch fabric on the back of the hand
ZONE_PAD = 2  # moulded knuckle armour
ZONE_CUFF = 3  # cuff and strap
ZONE_SLEEVE = 4


def _n(v):
    v = np.asarray(v, dtype=float)
    return v / np.linalg.norm(v)


# --- Hand placement ----------------------------------------------------------------

def hand_spec(prefix):
    """Grip cylinder and finger layout for R (right hand), L (left hand on the
    handguard) and P (pistol support hand around the right fist)."""
    top = np.array(GRIP_TOP)
    gax = np.array(GRIP_AXIS)
    left = np.array(LEFT_REF)
    if prefix == "R":
        return dict(centre=top + gax * 0.045, axis=-gax, side=(0.55, -1.0, 0.0), radius=0.019,
                    handed=1, arc=1.35, index_straight=((0, 1, 0.05), (-1, 0, 0), (0, 0, -1)), thumb=("wrap", 0.95),
                    starts=[0.65, 0.66, 0.71, 0.78], curls=[1.0, 0.97, 1.03, 1.1], elbow=(0.06, -0.3, -0.16), offset=np.zeros(3))
    if prefix == "L":
        hc = left + np.array([0.0, 0.0, 0.024])
        return dict(centre=hc + np.array([0.0, -0.02, 0.0]), axis=(0, 1, 0), side=(-0.45, 0.0, -1.0), radius=0.026,
                    handed=-1, arc=1.2, index_straight=None, thumb=("straight", 1.0),
                    starts=[0.6, 0.62, 0.66, 0.71], curls=[0.58, 0.66, 0.7, 0.76], elbow=(-0.12, -0.24, -0.2),
                    offset=left)
    pc = top + gax * 0.05 + np.array([-0.012, 0.01, 0.0])
    return dict(centre=pc, axis=-gax, side=(-1.0, 0.6, 0.0), radius=0.04, handed=-1, arc=1.0,
                index_straight=None, thumb=("straight", 1.0), starts=[0.55, 0.57, 0.61, 0.66],
                curls=[0.92, 0.97, 1.0, 1.04], elbow=(-0.14, -0.26, -0.16), offset=np.zeros(3))


class Cylinder:
    def __init__(self, s):
        self.axis = _n(s["axis"])
        sd = np.asarray(s["side"], dtype=float)
        self.side = _n(sd - self.axis * sd.dot(self.axis))
        self.other = np.cross(self.axis, self.side) * s["handed"]
        self.c = np.asarray(s["centre"], dtype=float)
        self.radius = s["radius"]
        self.handed = s["handed"]

    def at(self, theta, rad, along):
        return self.c + self.axis * along + (self.side * math.cos(theta) + self.other * math.sin(theta)) * rad

    def inward(self, p):
        rel = np.asarray(p) - self.c
        return _n(-(rel - self.axis * rel.dot(self.axis)))

    def tangent(self, theta):
        """Direction of increasing theta."""
        return _n(-self.side * math.sin(theta) + self.other * math.cos(theta))


def hand_chains(s):
    """Joint points of the thumb and the four fingers, and the wrist and elbow."""
    cy = Cylinder(s)
    arc = s["arc"]
    pr = s["radius"] + 0.012
    width = 0.084
    top = width * 0.55
    th0 = -arc * 0.5
    wrist = cy.at(th0, pr, 0.0) - cy.tangent(th0) * 0.05
    chains = {}
    for fi, (name, l1, l2, l3, fr) in enumerate(FINGERS):
        along = top - 0.012 - fi * FINGER_SPACING
        fr *= 1.08
        rad = s["radius"] + fr
        th = s["starts"][fi]
        if s["index_straight"] and fi == 0:
            fwd, inward, down = (_n(v) for v in s["index_straight"])
            p0 = cy.at(th, rad, along)
            p1 = p0 + fwd * l1
            p2 = p1 + _n(fwd * 0.55 + inward * 0.75 + down * 0.2) * l2
            p3 = p2 + _n(fwd * 0.05 + inward * 0.75 + down * 0.65) * l3
            pts = [p0, p1, p2, p3]
        else:
            pts = [cy.at(th, rad, along)]
            for L in (l1, l2, l3):
                th += 2 * math.asin(min(L / (2 * rad), 0.99)) * s["curls"][fi]
                pts.append(cy.at(th, rad, along))
        chains[name] = {"pts": pts, "radius": fr, "straight": bool(s["index_straight"] and fi == 0),
                        "along": along, "start": s["starts"][fi]}
    mode, amount = s["thumb"]
    tr = 0.0105
    t_base = cy.at(-arc * 0.5 + 0.25, pr + 0.004, top - 0.004)
    rad = s["radius"] + tr
    if mode == "wrap":
        th = -arc * 0.5 - 0.1
        pts = [t_base, cy.at(th, rad, top + 0.01)]
        for L in (0.032, 0.026):
            th -= 2 * math.asin(min(L / (2 * rad), 0.99)) * amount
            pts.append(cy.at(th, rad, top + 0.014))
    else:
        th = -arc * 0.5 - 0.35
        p1 = cy.at(th, rad, top + 0.012)
        p2 = p1 + cy.axis * 0.03
        p3 = p2 + cy.axis * 0.024 + _n(cy.c - p2) * 0.004
        pts = [t_base, p1, p2, p3]
    chains["Thumb"] = {"pts": pts, "radius": tr * 1.1, "straight": False}
    return {"chains": chains, "wrist": wrist, "elbow": wrist + np.asarray(s["elbow"], dtype=float),
            "axis": cy.axis, "centre": cy.c, "handed": s["handed"], "cyl": cy, "top": top, "pr": pr, "th0": th0}


def chain_frames(h, name):
    """Per bone of a chain: origin, X (curl axis), Y (along), Z (palm side), length."""
    ch = h["chains"][name]
    cy = h["cyl"]
    pts = [np.asarray(p, dtype=float) for p in ch["pts"]]
    dirs = [_n(pts[k + 1] - pts[k]) for k in range(3)]
    out = []
    for k in range(3):
        if ch["straight"]:
            a = np.cross(dirs[min(k, 1)], dirs[min(k, 1) + 1])
        else:
            a = np.cross(dirs[k], cy.inward(pts[k]))
        if np.linalg.norm(a) < 1e-5:
            a = cy.axis * h["handed"]
        y = dirs[k]
        x = _n(a - y * a.dot(y))
        z = np.cross(x, y)
        out.append({"o": pts[k], "x": x, "y": y, "z": z, "len": float(np.linalg.norm(pts[k + 1] - pts[k]))})
    return out


# --- Parts -------------------------------------------------------------------------

class Seg:
    """Round cone with an elliptical section: rw across (along x), rt deep
    (along z). Radii go from (rw0, rt0) at a to (rw1, rt1) at b."""

    def __init__(self, a, b, r0, r1, x, z, bone, chain, zone=ZONE_LEATHER, seam=False, tip=False, crease=False):
        self.a = np.asarray(a, dtype=float)
        self.b = np.asarray(b, dtype=float)
        d = self.b - self.a
        self.L = float(np.linalg.norm(d))
        self.y = d / self.L
        x = np.asarray(x, dtype=float)
        self.x = _n(x - self.y * x.dot(self.y))
        self.z = np.cross(self.x, self.y)
        if np.dot(self.z, z) < 0:
            self.z = -self.z
        self.r0 = r0
        self.r1 = r1
        self.bone = bone
        self.chain = chain
        self.zone = zone
        self.seam = seam
        self.tip = tip
        self.crease = crease

    def local(self, P):
        q = P - self.a
        h = q @ self.y
        t = np.clip(h / self.L, 0.0, 1.0)
        rw = self.r0[0] + (self.r1[0] - self.r0[0]) * t
        rt = self.r0[1] + (self.r1[1] - self.r0[1]) * t
        u = q @ self.x
        v = q @ self.z
        e = h - t * self.L
        return t, u, v, e, rw, rt

    def dist(self, P):
        t, u, v, e, rw, rt = self.local(P)
        r = np.sqrt(rw * rt)
        l2 = (u * r / rw) ** 2 + (v * r / rt) ** 2
        d = np.sqrt(l2 + e * e) - r
        if self.seam:
            # Side seam where the palm leather meets the back fabric.
            side = np.abs(u) > rw * 0.5
            d = d + 0.00034 * np.exp(-((v / 0.00075) ** 2)) * side
            # Stitches: short raised dashes beside the seam.
            hh = t * self.L + e
            dash = np.clip((np.cos(hh * (2 * np.pi / 0.0026)) - 0.2) / 0.8, 0.0, 1.0)
            d = d - 0.00018 * dash * np.exp(-(((np.abs(v) - 0.0013) / 0.0005) ** 2)) * side
        if self.crease:
            # Compression creases on the palm side of the joint, and two
            # smaller folds just past it.
            h = t * self.L + e
            palm_side = np.clip((v / rt - 0.15) / 0.45, 0.0, 1.0)
            g = np.exp(-((h - 0.0004) / 0.0011) ** 2) + 0.45 * np.exp(-((h - 0.0042) / 0.0008) ** 2)
            d = d + 0.00055 * g * palm_side
            # Stretch lines across the back of the joint.
            back = np.clip((-v / rt - 0.3) / 0.4, 0.0, 1.0)
            d = d + 0.00022 * back * np.exp(-(h / 0.004) ** 2) * (0.5 + 0.5 * np.cos(h * 2400.0))
        return d

    def zone_of(self, P):
        if self.zone != ZONE_LEATHER:
            return np.full(len(P), self.zone)
        t, u, v, e, rw, rt = self.local(P)
        zone = np.where(v / rt > -0.05, ZONE_LEATHER, ZONE_FABRIC)
        if self.tip:
            zone = np.where(t > 0.5, ZONE_LEATHER, zone)
        return zone

    def bounds(self):
        r = max(self.r0 + self.r1)
        return np.minimum(self.a, self.b) - r, np.maximum(self.a, self.b) + r


class Ell:
    """Ellipsoid with semi-axes rx, ry, rz along the columns of basis."""

    def __init__(self, c, basis, radii, bone, chain, zone=ZONE_LEATHER):
        self.c = np.asarray(c, dtype=float)
        self.B = np.asarray(basis, dtype=float)
        self.r = np.asarray(radii, dtype=float)
        self.bone = bone
        self.chain = chain
        self.zone = zone

    def dist(self, P):
        q = (P - self.c) @ self.B / self.r
        k = np.linalg.norm(q, axis=1)
        return (k - 1.0) * self.r.min()

    def zone_of(self, P):
        return np.full(len(P), self.zone)

    def bounds(self):
        r = self.r.max()
        return self.c - r, self.c + r


def _tube(dx, dy):
    """Capped cylinder from the radial and axial excess distances."""
    return np.minimum(np.maximum(dx, dy), 0.0) + np.sqrt(np.maximum(dx, 0.0) ** 2 + np.maximum(dy, 0.0) ** 2)


def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1 - h) + a * h - k * h * (1 - h)


def _polyline(pts, radii, x_of, z_of, bone, chain, zone=ZONE_LEATHER):
    return [Seg(pts[i], pts[i + 1], radii[i], radii[i + 1], x_of(i), z_of(i), bone, chain, zone) for i in range(len(pts) - 1)]


class Arm:
    """All parts of one arm, grouped for the SDF:

    glove = min over fingers of smin(palm, finger), then smooth-joined with the
    pads and the cuff. The fingers do not blend with each other, so they stay
    separate when the hand opens. sleeve = folded shell from the wrist to past
    the elbow, open at the wrist end.
    """

    def __init__(self, prefix):
        self.prefix = prefix
        self.spec = hand_spec(prefix)
        self.h = hand_chains(self.spec)
        h = self.h
        cy = h["cyl"]
        th0 = h["th0"]
        top = h["top"]
        self.wrist = np.asarray(h["wrist"])
        self.elbow = np.asarray(h["elbow"])
        self.fore_dir = _n(self.elbow - self.wrist)
        self.palm = []
        self.fingers = {}
        self.pads = []
        # Palm: one row of tissue per metacarpal, along the grip arc from the
        # heel of the hand to the knuckle. The rows overlap into one solid palm.
        pr_row = cy.radius + 0.0118
        along_c = top - 0.012 - 1.5 * FINGER_SPACING
        for fi, (name, *_rest) in enumerate(FINGERS):
            ch = h["chains"][name]
            along_f = ch["along"]
            th_end = ch["start"] - 0.06
            if ch["straight"]:
                th_end = ch["start"] - 0.06
            pts = []
            n = 6
            for i in range(n + 1):
                f = i / n
                th = th0 + (th_end - th0) * f
                al = along_c + (along_f - along_c) * (0.55 + 0.45 * f)
                pts.append(cy.at(th, pr_row, al))
            heel = cy.at(th0, pr_row, along_c + (along_f - along_c) * 0.5) - cy.tangent(th0) * 0.024
            pts = [heel] + pts
            spread = 0.0118 if fi in (1, 2) else 0.011
            radii = [(spread * 0.9, 0.0125)] + [(spread, 0.0108 - 0.0012 * (i / n)) for i in range(n + 1)]
            seg = _polyline(pts, radii, lambda i: cy.axis, lambda i, p=pts: cy.inward(p[i]), "Hand", name)
            self.palm += seg
        # Thenar (thumb ball) and hypothenar (outer edge) muscles, thumb metacarpal.
        t_ch = h["chains"]["Thumb"]
        t_base = np.asarray(t_ch["pts"][0])
        thenar_c = cy.at(th0 + 0.22, pr_row - 0.0035, top - 0.01)
        tb = np.stack([cy.axis, cy.tangent(th0 + 0.22), cy.inward(thenar_c)], axis=1)
        self.palm.append(Ell(thenar_c, tb, (0.0115, 0.017, 0.0085), "Hand", "Thumb"))
        hyp_c = cy.at(th0 + 0.3, pr_row - 0.003, top - 0.012 - 3.15 * FINGER_SPACING)
        hb = np.stack([cy.axis, cy.tangent(th0 + 0.3), cy.inward(hyp_c)], axis=1)
        self.palm.append(Ell(hyp_c, hb, (0.0085, 0.018, 0.0078), "Hand", "Pinky"))
        t_meta0 = cy.at(th0 + 0.02, pr_row, top - 0.02) - cy.tangent(th0) * 0.012
        self.palm.append(Seg(t_meta0, t_base, (0.0125, 0.0125), (0.0122, 0.0118), cy.axis, cy.inward(t_base), "Hand", "Thumb"))
        # Wrist: a flat oval between the heel of the hand and the forearm.
        wz = cy.inward(self.wrist)
        wx = _n(cy.axis - self.fore_dir * cy.axis.dot(self.fore_dir))
        self.palm.append(Seg(self.wrist - self.fore_dir * 0.012, self.wrist + self.fore_dir * 0.03,
                             (0.029, 0.021), (0.03, 0.022), wx, wz, "Wrist", None))
        # Metacarpal heads: the knuckle ridge on the back of the hand.
        for name in ("Index", "Middle", "Ring", "Pinky"):
            fz = chain_frames(h, name)[0]
            rt0 = [f for f in FINGERS if f[0] == name][0][4]
            c = np.asarray(h["chains"][name]["pts"][0]) - fz["z"] * rt0 * 0.42 - fz["y"] * 0.003
            kb = np.stack([fz["x"], fz["y"], fz["z"]], axis=1)
            self.palm.append(Ell(c, kb, (rt0 * 0.88, rt0 * 0.75, rt0 * 0.62), "Hand", name, ZONE_FABRIC))
        # Thumb web between the thumb and the index finger.
        i0 = np.asarray(h["chains"]["Index"]["pts"][0])
        t1 = np.asarray(t_ch["pts"][1])
        web_a = t_base + (t1 - t_base) * 0.35
        self.palm.append(Seg(web_a, i0 - cy.axis * 0.004, (0.0075, 0.0055), (0.0068, 0.005), cy.axis, cy.inward(i0), "Hand", "Thumb"))
        # Fingers: three tapered phalanges with a dorsal knuckle bump at each
        # joint, a seam on each side and leather on the palm side and the tip.
        for name in CHAIN_NAMES:
            ch = h["chains"][name]
            frames = chain_frames(h, name)
            pts = [np.asarray(p) for p in ch["pts"]]
            if name == "Thumb":
                rws = [0.0118, 0.0108, 0.0101, 0.0092]
                rts = [0.0112, 0.0104, 0.0097, 0.0088]
            else:
                fr = [f for f in FINGERS if f[0] == name][0][4]
                rw = min(fr * 1.02, FINGER_SPACING * 0.5 - 0.0015)
                rt = fr * 0.9
                rws = [rw * t for t in (1.0, 0.92, 0.84, 0.72)]
                rts = [rt * t for t in (1.0, 0.91, 0.82, 0.66)]
            parts = []
            for k in range(3):
                fz = frames[k]
                parts.append(Seg(pts[k], pts[k + 1], (rws[k], rts[k]), (rws[k + 1], rts[k + 1]), fz["x"], fz["z"],
                                 "%s%d" % (name, k + 1), name, seam=True, tip=(k == 2), crease=True))
            for k in (1, 2):
                fz = frames[k]
                c = pts[k] - fz["z"] * rts[k] * 0.38
                kb = np.stack([fz["x"], fz["y"], fz["z"]], axis=1)
                parts.append(Ell(c, kb, (rws[k] * 0.72, rts[k] * 0.42, rts[k] * 0.55), "%s%d" % (name, k), name, ZONE_FABRIC))
            self.fingers[name] = parts
            if name != "Thumb":
                # Moulded pad on the back of the proximal phalanx.
                fz = frames[0]
                a = pts[0] + fz["y"] * fz["len"] * 0.28 - fz["z"] * rts[0] * 0.92
                b = pts[0] + fz["y"] * fz["len"] * 0.7 - fz["z"] * rts[1] * 0.9
                self.pads.append(Seg(a, b, (rws[0] * 0.62, 0.0032), (rws[1] * 0.58, 0.003), fz["x"], fz["z"],
                                     "%s1" % name, name, ZONE_PAD))
        # Knuckle armour across the four metacarpal heads.
        knuck = []
        for name in ("Index", "Middle", "Ring", "Pinky"):
            fz = chain_frames(h, name)[0]
            rt = [f for f in FINGERS if f[0] == name][0][4]
            knuck.append(np.asarray(h["chains"][name]["pts"][0]) - fz["z"] * (rt + 0.0035) - fz["y"] * 0.004)
        for i in range(3):
            fz = chain_frames(h, ("Index", "Middle", "Ring")[i])[0]
            self.pads.append(Seg(knuck[i], knuck[i + 1], (0.0072, 0.0042), (0.0068, 0.004), fz["y"], fz["z"], "Hand", None, ZONE_PAD))
        # Glove cuff with a turned hem and a strap on the back of the wrist.
        self.cuff = [Seg(self.wrist + self.fore_dir * 0.0, self.wrist + self.fore_dir * 0.058,
                         (0.0315, 0.0245), (0.034, 0.0275), wx, wz, "Wrist", None, ZONE_CUFF),
                     Seg(self.wrist + self.fore_dir * 0.052, self.wrist + self.fore_dir * 0.06,
                         (0.0355, 0.029), (0.0355, 0.029), wx, wz, "Wrist", None, ZONE_CUFF),
                     # Hook-and-loop strap round the wrist, with a pull tab.
                     Seg(self.wrist + self.fore_dir * 0.016, self.wrist + self.fore_dir * 0.036,
                         (0.0335, 0.0265), (0.0345, 0.0275), wx, wz, "Wrist", None, ZONE_PAD),
                     Seg(self.wrist + self.fore_dir * 0.014 - wz * 0.027 + wx * 0.012, self.wrist + self.fore_dir * 0.038 - wz * 0.028 + wx * 0.018,
                         (0.012, 0.004), (0.011, 0.004), wx, wz, "Wrist", None, ZONE_PAD)]
        self.wx = wx
        self.wz = wz
        rng = np.random.default_rng({"R": 11, "L": 23, "P": 37}[prefix])
        self._fold_waves = [(rng.uniform(0.35, 1.2) * rng.choice([-1, 1]), rng.uniform(45.0, 95.0), rng.uniform(0, 6.3),
                             rng.uniform(0.0035, 0.0055), rng.uniform(15.0, 40.0)) for _ in range(6)]
        self.sleeve_a = self.wrist + self.fore_dir * 0.036
        self.sleeve_b = self.elbow + self.fore_dir * 0.08

    # --- Field -------------------------------------------------------------------

    def glove_parts(self):
        out = list(self.palm) + list(self.pads) + list(self.cuff)
        for p in self.fingers.values():
            out += p
        return out

    def glove_sdf(self, P):
        palm = None
        for p in self.palm:
            d = p.dist(P)
            palm = d if palm is None else smin(palm, d, 0.0075)
        hand = None
        for name, parts in self.fingers.items():
            f = None
            for p in parts:
                d = p.dist(P)
                f = d if f is None else smin(f, d, 0.0035)
            joined = smin(palm, f, 0.0065 if name != "Thumb" else 0.009)
            hand = joined if hand is None else np.minimum(hand, joined)
        for p in self.pads:
            hand = smin(hand, p.dist(P), 0.0018)
        cuff = None
        for p in self.cuff:
            d = p.dist(P)
            cuff = d if cuff is None else smin(cuff, d, 0.003)
        return smin(hand, cuff, 0.008)

    def sleeve_sdf(self, P):
        a, b = self.sleeve_a, self.sleeve_b
        y = _n(b - a)
        L = float(np.linalg.norm(b - a))
        q = P - a
        h = q @ y
        t = np.clip(h / L, 0.0, 1.0)
        u = q @ self.wx
        v = q @ self.wz
        phi = np.arctan2(v, u)
        rad = np.sqrt(u * u + v * v)
        # Forearm volume: narrow at the wrist, the muscle swell below the
        # elbow, then the elbow.
        r_out = 0.039 + 0.016 * np.sqrt(t) + 0.0075 * np.sin(np.clip(t * 1.4, 0.0, 1.0) * np.pi) ** 2
        # Loose cuff: the sleeve end stands off the glove.
        r_out = r_out + 0.0045 * np.exp(-np.maximum(h, 0.0) / 0.018)
        # Fabric folds: sharp compression ridges that bunch near the cuff, and
        # long soft folds that spiral up the arm.
        bunch = np.exp(-np.maximum(h - 0.03, 0.0) / 0.08)
        folds = np.zeros_like(h)
        for k, (ang, freq, ph, amp, warp) in enumerate(self._fold_waves):
            # Ridge waves at random angles on the unrolled sleeve, each faded
            # in and out along the arm so no pattern repeats.
            arc = phi * 0.045
            x = arc * math.cos(ang) + h * math.sin(ang)
            x = x + 0.004 * np.sin(h * warp + phi * (k % 3 + 1))
            ridge = (0.5 + 0.5 * np.cos(x * freq + ph)) ** 1.8
            fade = np.clip(0.5 + 0.9 * np.sin(h * (7.0 + 2.5 * k) + phi * (k % 3) + ph * 2.0), 0.0, 1.0)
            folds = folds + amp * ridge * fade
        folds = folds * (0.45 + 0.85 * bunch) + 0.0012 * np.sin(phi * 2.0 + h * 26.0)
        # Cuff band at the end, with a fold line where it joins the sleeve.
        band = 0.0018 * np.clip((0.03 - h) / 0.004, 0.0, 1.0) - 0.0008 * np.exp(-((h - 0.031) / 0.0015) ** 2)
        hem = 0.0012 * np.exp(-((h - 0.002) / 0.003) ** 2)
        r = r_out * (1.0 + 0.07 * np.cos(2 * phi)) + folds + band + hem
        outer = _tube(rad - r, np.abs(h - L * 0.5) - L * 0.5)
        # Opening at the wrist end, 22 mm deep, so the glove cuff goes into
        # the sleeve. The walls stay thick enough for a clean mesh.
        hole = _tube(rad - (r - 0.006), np.abs(h + 0.039) - 0.061)
        return np.maximum(outer, -hole)

    def glove_bounds(self, pad=0.006):
        lo = np.full(3, np.inf)
        hi = np.full(3, -np.inf)
        for p in self.glove_parts():
            a, b = p.bounds()
            lo = np.minimum(lo, a)
            hi = np.maximum(hi, b)
        return lo - pad, hi + pad

    def sleeve_bounds(self, pad=0.01):
        r = 0.07
        lo = np.minimum(self.sleeve_a, self.sleeve_b) - r
        hi = np.maximum(self.sleeve_a, self.sleeve_b) + r
        return lo - pad, hi + pad

    # --- Zones and weights ---------------------------------------------------------

    def _dists(self, P, parts):
        return np.stack([p.dist(P) for p in parts], axis=1)

    def glove_zones(self, P):
        parts = self.glove_parts()
        D = self._dists(P, parts)
        near = np.argmin(D, axis=1)
        zone = np.zeros(len(P), dtype=int)
        for i, p in enumerate(parts):
            m = near == i
            if m.any():
                zone[m] = p.zone_of(P[m])
        return zone

    def skin_weights(self, P, bone_index, tau=0.0016, sleeve=None):
        """Weights per vertex over the bones in bone_index (name -> column).

        Each vertex takes weights from the parts of its nearest chain (one
        finger, or the palm) with a soft minimum over the distances, so joints
        blend smoothly and touching fingers do not pull on each other. Wrist,
        cuff and sleeve vertices blend from the hand to the forearm along the
        forearm."""
        prefix = self.prefix
        nb = len(bone_index)
        W = np.zeros((len(P), nb))
        along = (P - self.wrist) @ self.fore_dir
        tw = np.clip((along - 0.004) / (0.07 - 0.004), 0.0, 1.0)
        tw = tw * tw * (3 - 2 * tw)
        hand_col = bone_index[prefix + "_Hand"]
        fore_col = bone_index[prefix + "_Forearm"]
        if sleeve is not None:
            m = sleeve
            W[m, hand_col] = 1 - tw[m]
            W[m, fore_col] = tw[m]
        rest = np.ones(len(P), dtype=bool) if sleeve is None else ~sleeve
        if rest.any():
            Q = P[rest]
            parts = self.glove_parts()
            D = self._dists(Q, parts)
            near = np.argmin(D, axis=1)
            chains = np.array([CHAIN_NAMES.index(p.chain) if p.chain in CHAIN_NAMES else -1 for p in parts])
            near_chain = chains[near]
            dmin = D[np.arange(len(Q)), near]
            Wq = np.zeros((len(Q), nb))
            twq = tw[rest]
            for i, p in enumerate(parts):
                allowed = (chains[i] == near_chain) | (chains[i] == -1)
                w = np.exp(-(D[:, i] - dmin) / tau) * allowed
                if p.bone == "Wrist":
                    Wq[:, hand_col] += w * (1 - twq)
                    Wq[:, fore_col] += w * twq
                else:
                    Wq[:, bone_index[prefix + "_" + p.bone]] += w
            W[rest] = Wq
        W /= np.maximum(W.sum(axis=1, keepdims=True), 1e-9)
        return W


# --- Meshing -------------------------------------------------------------------------

def sample_band(fn, lo, hi, h, coarse=4, chunk=600000):
    """Samples fn on a grid with spacing h. Only points near the surface are
    evaluated at full resolution; the rest keep the coarse value."""
    n = np.ceil((hi - lo) / h).astype(int) + 1
    nc = (n - 1) // coarse + 2
    axes_c = [lo[i] + np.arange(nc[i]) * h * coarse for i in range(3)]
    Pc = np.stack(np.meshgrid(*axes_c, indexing="ij"), axis=-1).reshape(-1, 3)
    dc = np.concatenate([fn(Pc[i:i + chunk]) for i in range(0, len(Pc), chunk)]).reshape(nc)
    vol = dc
    for ax in range(3):
        vol = np.repeat(vol, coarse, axis=ax)
    vol = vol[:n[0], :n[1], :n[2]].astype(np.float32)
    band = np.abs(vol) < h * coarse * 2.2
    idx = np.argwhere(band)
    P = lo + idx * h
    d = np.concatenate([fn(P[i:i + chunk]) for i in range(0, len(P), chunk)]) if len(P) else np.zeros(0)
    vol[band] = d
    return vol


def surface_nets(vol, lo, h):
    """Naive surface nets: one vertex per surface cell, one quad per crossed
    grid edge. Returns vertices (N, 3) and quads (M, 4), outward-facing."""
    nx, ny, nz = vol.shape
    inside = vol < 0
    corners = list(itertools.product((0, 1), repeat=3))
    cv = [vol[i:nx - 1 + i, j:ny - 1 + j, k:nz - 1 + k] for i, j, k in corners]
    ci = [c < 0 for c in cv]
    any_in = np.logical_or.reduce(ci)
    all_in = np.logical_and.reduce(ci)
    active = any_in & ~all_in
    cells = np.argwhere(active)
    acc = np.zeros((len(cells), 3))
    cnt = np.zeros(len(cells))
    for a, ca in enumerate(corners):
        for b, cb in enumerate(corners):
            if b <= a or sum(x != y for x, y in zip(ca, cb)) != 1:
                continue
            va = cv[a][active]
            vb = cv[b][active]
            cross = (va < 0) != (vb < 0)
            t = np.where(cross, va / np.where(cross, va - vb, 1.0), 0.0)
            pa = np.array(ca, dtype=float)
            pb = np.array(cb, dtype=float)
            pos = pa[None] + t[:, None] * (pb - pa)[None]
            acc[cross] += pos[cross]
            cnt += cross
    verts = (cells + acc / np.maximum(cnt, 1)[:, None]) * h + lo
    vid = -np.ones(active.shape, dtype=np.int64)
    vid[active] = np.arange(len(cells))
    quads = []
    # Edges along x between (i,j,k) and (i+1,j,k): cells (i, j-1|j, k-1|k).
    for ax in range(3):
        sl0 = [slice(None)] * 3
        sl1 = [slice(None)] * 3
        sl0[ax] = slice(0, -1)
        sl1[ax] = slice(1, None)
        o1, o2 = [a for a in range(3) if a != ax]
        for o in (o1, o2):
            sl0[o] = slice(1, -1)
            sl1[o] = slice(1, -1)
        s0 = inside[tuple(sl0)]
        s1 = inside[tuple(sl1)]
        e = np.argwhere(s0 != s1)
        if not len(e):
            continue
        flip = s0[tuple(e.T)]
        base = e.copy()
        base[:, o1] += 1
        base[:, o2] += 1

        def cell(d1, d2):
            c = base.copy()
            c[:, o1] -= d1
            c[:, o2] -= d2
            return vid[tuple(c.T)]

        q = np.stack([cell(1, 1), cell(0, 1), cell(0, 0), cell(1, 0)], axis=1)
        if (ax == 1):
            q = q[:, ::-1]
        q = np.where(flip[:, None], q[:, ::-1], q)
        quads.append(q)
    quads = np.concatenate(quads)
    quads = quads[(quads >= 0).all(axis=1)]
    return verts, quads[:, ::-1].copy()


def smooth(verts, quads, iterations=6, lam=0.45, mu=-0.47):
    """Taubin smoothing: removes the grid steps without shrinking the shape."""
    n = len(verts)
    e = np.concatenate([quads[:, [0, 1]], quads[:, [1, 2]], quads[:, [2, 3]], quads[:, [3, 0]]])
    e = np.concatenate([e, e[:, ::-1]])
    deg = np.bincount(e[:, 0], minlength=n).astype(float)
    v = verts.copy()
    for _ in range(iterations):
        for f in (lam, mu):
            s = np.zeros_like(v)
            np.add.at(s, e[:, 0], v[e[:, 1]])
            avg = s / np.maximum(deg, 1)[:, None]
            v = v + f * (avg - v)
    return v


def build_mesh(fn, lo, hi, h, smooth_iter=6):
    vol = sample_band(fn, np.asarray(lo), np.asarray(hi), h)
    v, q = surface_nets(vol, np.asarray(lo), h)
    v = smooth(v, q, smooth_iter)
    return v, q
