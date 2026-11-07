"""Adds a hand skeleton to the first-person arms.

    python tools/rig_arms.py            # rig assets/characters/arms_*.gltf
    python tools/rig_arms.py --check    # exit 1 if an arms file has no rig

tools/blender/build_characters.py makes the arms as three rigid meshes (ArmR,
ArmL, ArmLPistol). This script adds one skeleton to each mesh, so that the
game can move the wrist, each finger joint and the forearm by code:

    <P>_Root
      <P>_Forearm             origin at the elbow, +Y to the wrist
      <P>_Hand                origin at the wrist, +Y to the knuckles
        <P>_Thumb1..3
        <P>_Index1..3, <P>_Middle1..3, <P>_Ring1..3, <P>_Pinky1..3

P is R (right hand), L (left hand) or P (pistol support hand). On each finger
bone, +Y points along the bone and +X is the curl axis: a positive rotation
about +X closes the finger. The rest pose is the modelled grip.

The joint positions come from the same maths as wrap_hand() in the Blender
script, so the bones sit on the modelled fingers. Each finger is a separate
mesh part; the script finds the parts and weights each vertex by its
position along the finger, with smooth blends at the knuckles and the wrist.

Run this script after each Blender rebuild of the arms, before the Godot
import. The script needs only Python and numpy.
"""
import json
import math
import os
import sys

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CHARS = os.path.join(ROOT, "assets", "characters")
FACTIONS = ("sentinel", "militia")

# --- Hand geometry (Blender space: x right, y muzzle, z up) -----------------------
# These values must agree with tools/blender/build_characters.py.

FINGERS = [  # name, proximal, middle, distal lengths, radius
    ("Index", 0.044, 0.026, 0.022, 0.0098),
    ("Middle", 0.048, 0.03, 0.023, 0.0102),
    ("Ring", 0.045, 0.028, 0.022, 0.0098),
    ("Pinky", 0.036, 0.021, 0.019, 0.0086),
]
R18 = math.radians(18)
GRIP_TOP = np.array([0.0, -0.02, 0.0])
GRIP_AXIS = np.array([0.0, -math.sin(R18), -math.cos(R18)])
LEFT_REF = np.array([0.0, 0.25, 0.04])


def _n(v):
    v = np.asarray(v, dtype=float)
    return v / np.linalg.norm(v)


def hand_spec(prefix):
    if prefix == "R":
        return dict(centre=GRIP_TOP + GRIP_AXIS * 0.045, axis=-GRIP_AXIS, side=(0.55, -1.0, 0.0), radius=0.019,
                    handed=1, arc=1.35, index_straight=((0, 1, 0.05), (-1, 0, 0), (0, 0, -1)), thumb=("wrap", 0.75),
                    starts=[0.65, 0.68, 0.7, 0.72], curls=[1.0] * 4, elbow=(0.06, -0.3, -0.16), offset=np.zeros(3))
    if prefix == "L":
        hc = LEFT_REF + np.array([0.0, 0.0, 0.024])
        return dict(centre=hc + np.array([0.0, -0.02, 0.0]), axis=(0, 1, 0), side=(-0.45, 0.0, -1.0), radius=0.026,
                    handed=-1, arc=1.2, index_straight=None, thumb=("straight", 1.0),
                    starts=[0.62, 0.62, 0.64, 0.66], curls=[0.62, 0.66, 0.66, 0.66], elbow=(-0.12, -0.24, -0.2),
                    offset=LEFT_REF)
    pc = GRIP_TOP + GRIP_AXIS * 0.05 + np.array([-0.012, 0.01, 0.0])
    return dict(centre=pc, axis=-GRIP_AXIS, side=(-1.0, 0.6, 0.0), radius=0.04, handed=-1, arc=1.0,
                index_straight=None, thumb=("straight", 1.0), starts=[0.55, 0.55, 0.58, 0.6],
                curls=[0.8, 0.85, 0.85, 0.85], elbow=(-0.14, -0.26, -0.16), offset=np.zeros(3))


def hand_chains(s):
    """Joint points of the thumb and the four fingers, as in wrap_hand()."""
    axis = _n(s["axis"])
    sd = np.asarray(s["side"], dtype=float)
    side = _n(sd - axis * sd.dot(axis))
    other = np.cross(axis, side) * s["handed"]
    c = np.asarray(s["centre"], dtype=float)
    arc = s["arc"]

    def at(theta, rad, along):
        return c + axis * along + (side * math.cos(theta) + other * math.sin(theta)) * rad

    pr = s["radius"] + 0.012
    width = 0.084
    top = width * 0.55
    th0 = -arc * 0.5
    tangent = -(side * -math.sin(th0) + other * math.cos(th0))
    wrist = at(th0, pr, 0.0) + tangent * 0.05
    chains = {}
    for fi, (name, l1, l2, l3, fr) in enumerate(FINGERS):
        along = top - 0.012 - fi * 0.0205
        fr *= 1.08
        rad = s["radius"] + fr
        th = s["starts"][fi]
        if s["index_straight"] and fi == 0:
            fwd, inward, down = (_n(v) for v in s["index_straight"])
            p0 = at(th, rad, along)
            p1 = p0 + fwd * l1
            p2 = p1 + _n(fwd * 0.55 + inward * 0.75 + down * 0.2) * l2
            p3 = p2 + _n(fwd * 0.05 + inward * 0.75 + down * 0.65) * l3
            pts = [p0, p1, p2, p3]
        else:
            pts = [at(th, rad, along)]
            for L in (l1, l2, l3):
                th += 2 * math.asin(min(L / (2 * rad), 0.99)) * s["curls"][fi]
                pts.append(at(th, rad, along))
        chains[name] = {"pts": pts, "radius": fr, "straight": bool(s["index_straight"] and fi == 0)}
    mode, amount = s["thumb"]
    tr = 0.0105
    t_base = at(-arc * 0.5 + 0.25, pr + 0.004, top - 0.004)
    rad = s["radius"] + tr
    if mode == "wrap":
        th = -arc * 0.5 - 0.1
        pts = [t_base, at(th, rad, top + 0.01)]
        for L in (0.032, 0.026):
            th -= 2 * math.asin(min(L / (2 * rad), 0.99)) * amount
            pts.append(at(th, rad, top + 0.014))
    else:
        th = -arc * 0.5 - 0.35
        p1 = at(th, rad, top + 0.012)
        p2 = p1 + axis * 0.03
        p3 = p2 + axis * 0.024 + _n(c - p2) * 0.004
        pts = [t_base, p1, p2, p3]
    chains["Thumb"] = {"pts": pts, "radius": tr * 1.1, "straight": False}
    return {"chains": chains, "wrist": wrist, "elbow": wrist + np.asarray(s["elbow"], dtype=float),
            "axis": axis, "centre": c, "handed": s["handed"]}


def bl2gl(v):
    """Blender (x, y, z) to glTF (x, z, -y)."""
    v = np.asarray(v, dtype=float)
    return np.array([v[0], v[2], -v[1]])


# --- Maths --------------------------------------------------------------------------

def basis(y, x_hint):
    y = _n(y)
    x = np.asarray(x_hint, dtype=float) - y * np.dot(x_hint, y)
    if np.linalg.norm(x) < 1e-6:
        x = np.cross(y, [0.0, 0.0, 1.0])
        if np.linalg.norm(x) < 1e-6:
            x = np.cross(y, [1.0, 0.0, 0.0])
    x = _n(x)
    z = np.cross(x, y)
    return np.stack([x, y, z], axis=1)  # columns


def mat4(b, t):
    m = np.eye(4)
    m[:3, :3] = b
    m[:3, 3] = t
    return m


def quat(m):
    """Rotation matrix to a glTF quaternion (x, y, z, w)."""
    t = np.trace(m)
    if t > 0:
        s = math.sqrt(t + 1.0) * 2
        w, x, y, z = 0.25 * s, (m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = math.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        w, x, y, z = (m[2, 1] - m[1, 2]) / s, 0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s
    elif m[1, 1] > m[2, 2]:
        s = math.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        w, x, y, z = (m[0, 2] - m[2, 0]) / s, (m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s
    else:
        s = math.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        w, x, y, z = (m[1, 0] - m[0, 1]) / s, (m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s
    q = np.array([x, y, z, w])
    return q / np.linalg.norm(q)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


# --- Skeleton -------------------------------------------------------------------------

def build_bones(prefix):
    """Returns a list of bones: name, parent index, global 4x4 (glTF, group space)."""
    s = hand_spec(prefix)
    h = hand_chains(s)
    off = s["offset"]

    def g(p):
        return bl2gl(np.asarray(p) - off)

    axis_g = bl2gl(h["axis"])
    centre_g = g(h["centre"])
    wrist = g(h["wrist"])
    elbow = g(h["elbow"])
    curl_main = axis_g * h["handed"]
    bones = [{"name": prefix + "_Root", "parent": -1, "m": np.eye(4)}]
    bones.append({"name": prefix + "_Forearm", "parent": 0, "m": mat4(basis(wrist - elbow, curl_main), elbow)})
    knuckles = np.mean([g(h["chains"][f]["pts"][0]) for f in ("Index", "Middle", "Ring", "Pinky")], axis=0)
    bones.append({"name": prefix + "_Hand", "parent": 0, "m": mat4(basis(knuckles - wrist, curl_main), wrist)})
    chains = {}
    for fname in ("Thumb", "Index", "Middle", "Ring", "Pinky"):
        ch = h["chains"][fname]
        pts = [g(p) for p in ch["pts"]]
        dirs = [_n(pts[k + 1] - pts[k]) for k in range(3)]
        parent = 2
        for k in range(3):
            if ch["straight"]:
                a = np.cross(dirs[min(k, 1)], dirs[min(k, 1) + 1])
            else:
                rel = pts[k] - centre_g
                inward = -(rel - axis_g * rel.dot(axis_g))
                a = np.cross(dirs[k], inward)
            if np.linalg.norm(a) < 1e-5:
                a = curl_main
            bones.append({"name": "%s_%s%d" % (prefix, fname, k + 1), "parent": parent, "m": mat4(basis(dirs[k], _n(a)), pts[k])})
            parent = len(bones) - 1
        chains[fname] = {"pts": np.array(pts), "radius": ch["radius"], "first": len(bones) - 3}
    return bones, chains, wrist, elbow


# --- glTF IO --------------------------------------------------------------------------

class Gltf:
    def __init__(self, path):
        self.path = path
        self.j = json.load(open(path))
        self.bin_path = os.path.join(os.path.dirname(path), self.j["buffers"][0]["uri"])
        self.buf = bytearray(open(self.bin_path, "rb").read())

    def read(self, i):
        a = self.j["accessors"][i]
        bv = self.j["bufferViews"][a["bufferView"]]
        dt = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}[a["componentType"]]
        n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
        off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        arr = np.frombuffer(bytes(self.buf), dt, a["count"] * n, off)
        return arr.reshape(a["count"], n) if n > 1 else arr

    def add(self, arr, ctype, atype, target=None):
        while len(self.buf) % 4:
            self.buf.append(0)
        data = np.ascontiguousarray(arr).tobytes()
        bv = {"buffer": 0, "byteOffset": len(self.buf), "byteLength": len(data)}
        if target:
            bv["target"] = target
        self.buf += data
        self.j["bufferViews"].append(bv)
        acc = {"bufferView": len(self.j["bufferViews"]) - 1, "componentType": ctype, "count": int(arr.shape[0]), "type": atype}
        self.j["accessors"].append(acc)
        return len(self.j["accessors"]) - 1

    def save(self):
        while len(self.buf) % 4:
            self.buf.append(0)
        self.j["buffers"][0]["byteLength"] = len(self.buf)
        with open(self.bin_path, "wb") as f:
            f.write(self.buf)
        with open(self.path, "w") as f:
            # Same layout as the Blender exporter: tabs, no space after ":".
            json.dump(self.j, f, indent="\t", separators=(",", ":"))


def components(P, I):
    """Connected parts of a mesh; vertices at the same position are joined."""
    key = np.round(P / 1e-5).astype(np.int64)
    _, weld = np.unique(key, axis=0, return_inverse=True)
    weld = weld.ravel()
    parent = np.arange(weld.max() + 1)

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for t in I:
        a = find(weld[t[0]])
        for v in t[1:]:
            b = find(weld[v])
            if a != b:
                parent[b] = a
    return np.array([find(w) for w in weld])


def project(chain, P):
    """Arc position s and distance of each point to a 4-point polyline."""
    pts = chain
    best_d = np.full(len(P), np.inf)
    best_s = np.zeros(len(P))
    acc = 0.0
    for k in range(len(pts) - 1):
        a, b = pts[k], pts[k + 1]
        L = np.linalg.norm(b - a)
        d = (b - a) / L
        t = (P - a) @ d
        lo = -np.inf if k == 0 else 0.0
        hi = np.inf if k == len(pts) - 2 else L
        tc = np.clip(t, lo, hi)
        q = a + np.outer(tc, d)
        dist = np.linalg.norm(P - q, axis=1)
        m = dist < best_d
        best_d[m] = dist[m]
        best_s[m] = acc + tc[m]
        acc += L
    return best_s, best_d


def weights_for(P, I, bones, chains, wrist, elbow):
    n = len(P)
    W = np.zeros((n, len(bones)))
    roots = components(P, I)
    hand = 2
    fore = 1
    dir_we = _n(elbow - wrist)
    along = (P - wrist) @ dir_we
    t = smoothstep(0.005, 0.075, along)
    base_w = np.stack([1 - t, t], axis=1)  # hand, forearm
    names = []
    for r in np.unique(roots):
        m = roots == r
        Q = P[m]
        best = None
        for fname, ch in chains.items():
            s, d = project(ch["pts"], Q)
            total = sum(np.linalg.norm(ch["pts"][k + 1] - ch["pts"][k]) for k in range(3))
            span = (np.clip(s, 0, total).max() - np.clip(s, 0, total).min()) / total
            md = d.mean()
            if md < ch["radius"] * 2.0 and span > 0.55 and (best is None or md < best[1]):
                best = (fname, md, s)
        idx = np.nonzero(m)[0]
        if best is None:
            W[idx, hand] = base_w[m, 0]
            W[idx, fore] = base_w[m, 1]
            continue
        fname, _, s = best
        names.append(fname)
        ch = chains[fname]
        pts = ch["pts"]
        s1 = np.linalg.norm(pts[1] - pts[0])
        s2 = s1 + np.linalg.norm(pts[2] - pts[1])
        b = ch["radius"] * 0.8
        t0 = smoothstep(-0.004, 0.006, s)
        t1 = smoothstep(s1 - b, s1 + b, s)
        t2 = smoothstep(s2 - b, s2 + b, s)
        f = ch["first"]
        W[idx, hand] = 1 - t0
        W[idx, f] = t0 * (1 - t1)
        W[idx, f + 1] = t0 * (t1 - t2)
        W[idx, f + 2] = t0 * t2
    missing = {"Thumb", "Index", "Middle", "Ring", "Pinky"} - set(names)
    if missing or len(names) != 5:
        raise SystemExit("finger parts not found: %s (found %s)" % (sorted(missing), names))
    # Keep the four largest weights.
    order = np.argsort(-W, axis=1)[:, :4]
    J = order.astype(np.uint8)
    Wt = np.take_along_axis(W, order, axis=1)
    Wt /= Wt.sum(axis=1, keepdims=True)
    J[Wt == 0] = 0
    return J, Wt.astype(np.float32)


def rig(path):
    gl = Gltf(path)
    j = gl.j
    if j.get("skins"):
        print("already rigged:", os.path.relpath(path, ROOT))
        return
    prefixes = {"ArmR": "R", "ArmL": "L", "ArmLPistol": "P"}
    old_nodes = j["nodes"]
    new_nodes = []
    scene_roots = []
    j["skins"] = []
    for node in old_nodes:
        name = node["name"]
        prefix = prefixes[name]
        bones, chains, wrist, elbow = build_bones(prefix)
        mesh = j["meshes"][node["mesh"]]
        prims = mesh["primitives"]
        Ps = [gl.read(p["attributes"]["POSITION"]).astype(float) for p in prims]
        Is = []
        o = 0
        for p, P in zip(prims, Ps):
            Is.append(gl.read(p["indices"]).astype(np.int64).reshape(-1, 3) + o)
            o += len(P)
        P_all = np.concatenate(Ps)
        J, W = weights_for(P_all, np.concatenate(Is), bones, chains, wrist, elbow)
        o = 0
        for p, P in zip(prims, Ps):
            p["attributes"]["JOINTS_0"] = gl.add(J[o:o + len(P)], 5121, "VEC4", 34962)
            p["attributes"]["WEIGHTS_0"] = gl.add(W[o:o + len(P)], 5126, "VEC4", 34962)
            o += len(P)
        # Joint nodes.
        first = len(new_nodes) + 2
        for i, b in enumerate(bones):
            pm = bones[b["parent"]]["m"] if b["parent"] >= 0 else np.eye(4)
            local = np.linalg.inv(pm) @ b["m"]
            jn = {"name": b["name"], "translation": [round(float(v), 7) for v in local[:3, 3]],
                  "rotation": [round(float(v), 7) for v in quat(local[:3, :3])]}
            kids = [first + k for k, c in enumerate(bones) if c["parent"] == i]
            if kids:
                jn["children"] = kids
            b["node"] = jn
        ibm = np.stack([np.linalg.inv(b["m"]).T.reshape(16) for b in bones]).astype(np.float32)
        j["skins"].append({"name": prefix + "_Skin", "joints": [first + i for i in range(len(bones))],
                           "inverseBindMatrices": gl.add(ibm, 5126, "MAT4"), "skeleton": first})
        group = {"name": name, "children": [len(new_nodes) + 1, first]}
        for k in ("translation", "rotation", "scale"):
            if k in node:
                group[k] = node[k]
        scene_roots.append(len(new_nodes))
        new_nodes.append(group)
        new_nodes.append({"name": name + "Mesh", "mesh": node["mesh"], "skin": len(j["skins"]) - 1})
        new_nodes += [b["node"] for b in bones]
    j["nodes"] = new_nodes
    j["scenes"][0]["nodes"] = scene_roots
    gl.save()
    print("rigged:", os.path.relpath(path, ROOT))


def main():
    files = [os.path.join(CHARS, "arms_%s.gltf" % f) for f in FACTIONS]
    if "--check" in sys.argv:
        bad = [f for f in files if not json.load(open(f)).get("skins")]
        for f in bad:
            print("no rig:", os.path.relpath(f, ROOT))
        sys.exit(1 if bad else 0)
    for f in files:
        rig(f)


if __name__ == "__main__":
    main()
