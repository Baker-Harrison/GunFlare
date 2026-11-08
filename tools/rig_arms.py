"""Adds a hand skeleton to the first-person arms.

    python tools/rig_arms.py            # rig assets/characters/arms_*.gltf
    python tools/rig_arms.py --check    # exit 1 if an arms file has no rig

tools/blender/build_characters.py makes the arms as three meshes (ArmR, ArmL,
ArmLPistol) without a skeleton. This script adds one skeleton to each mesh,
so that the game can move the wrist, each finger joint and the forearm by
code:

    <P>_Root
      <P>_Forearm             origin at the elbow, +Y to the wrist
      <P>_Hand                origin at the wrist, +Y to the knuckles
        <P>_Thumb1..3
        <P>_Index1..3, <P>_Middle1..3, <P>_Ring1..3, <P>_Pinky1..3

P is R (right hand), L (left hand) or P (pistol support hand). On each finger
bone, +Y points along the bone and +X is the curl axis: a positive rotation
about +X closes the finger. The rest pose is the modelled grip.

The joints and the skin weights come from tools/hand_anatomy.py, the same
anatomy that the Blender script meshes, so each joint bends at its knuckle.

Run this script after each Blender rebuild of the arms, before the Godot
import. The script needs only Python and numpy.
"""
import json
import math
import os
import sys

try:
    import numpy as np
except ImportError:  # --check needs only json; rigging needs numpy.
    np = None

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
CHARS = os.path.join(ROOT, "assets", "characters")
FACTIONS = ("sentinel", "militia")
SLEEVE_MATERIAL = "Uniform"


def _n(v):
    v = np.asarray(v, dtype=float)
    return v / np.linalg.norm(v)


def bl2gl(v):
    """Blender (x, y, z) to glTF (x, z, -y)."""
    v = np.asarray(v, dtype=float)
    return np.array([v[0], v[2], -v[1]])


def gl2bl(P):
    """glTF (x, y, z) rows to Blender (x, -z, y)."""
    P = np.asarray(P, dtype=float)
    return np.stack([P[:, 0], -P[:, 2], P[:, 1]], axis=1)


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
    """Returns a list of bones (name, parent index, global 4x4 in glTF group
    space) and the arm anatomy."""
    import hand_anatomy as ha
    arm = ha.Arm(prefix)
    h = arm.h
    off = arm.spec["offset"]

    def g(p):
        return bl2gl(np.asarray(p) - off)

    axis_g = bl2gl(h["axis"])
    wrist = g(h["wrist"])
    elbow = g(h["elbow"])
    curl_main = axis_g * h["handed"]
    bones = [{"name": prefix + "_Root", "parent": -1, "m": np.eye(4)}]
    bones.append({"name": prefix + "_Forearm", "parent": 0, "m": mat4(basis(wrist - elbow, curl_main), elbow)})
    knuckles = np.mean([g(h["chains"][f]["pts"][0]) for f in ("Index", "Middle", "Ring", "Pinky")], axis=0)
    bones.append({"name": prefix + "_Hand", "parent": 0, "m": mat4(basis(knuckles - wrist, curl_main), wrist)})
    for fname in ha.CHAIN_NAMES:
        parent = 2
        for k, fr in enumerate(ha.chain_frames(h, fname)):
            m = mat4(basis(bl2gl(fr["y"]), bl2gl(fr["x"])), g(fr["o"]))
            bones.append({"name": "%s_%s%d" % (prefix, fname, k + 1), "parent": parent, "m": m})
            parent = len(bones) - 1
    return bones, arm


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


def weights_for(P_gl, sleeve, bones, arm):
    """Four joints and weights per vertex. P_gl: positions in glTF group space."""
    P = gl2bl(P_gl) + np.asarray(arm.spec["offset"])
    index = {b["name"]: i for i, b in enumerate(bones)}
    W = arm.skin_weights(P, index, sleeve=sleeve)
    order = np.argsort(-W, axis=1)[:, :4]
    J = order.astype(np.uint8)
    Wt = np.take_along_axis(W, order, axis=1)
    Wt[Wt < 0.01] = 0.0
    Wt /= np.maximum(Wt.sum(axis=1, keepdims=True), 1e-9)
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
        bones, arm = build_bones(prefix)
        mesh = j["meshes"][node["mesh"]]
        prims = mesh["primitives"]
        Ps = [gl.read(p["attributes"]["POSITION"]).astype(float) for p in prims]
        mats = [j["materials"][p["material"]]["name"] if "material" in p else "" for p in prims]
        sleeve = np.concatenate([np.full(len(P), m == SLEEVE_MATERIAL) for P, m in zip(Ps, mats)])
        J, W = weights_for(np.concatenate(Ps), sleeve, bones, arm)
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
    if np is None:
        sys.exit("rig_arms.py needs numpy to rig the arms: pip install numpy")
    for f in files:
        rig(f)


if __name__ == "__main__":
    main()
