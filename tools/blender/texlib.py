"""PBR surfacing and texture baking for GunFare models. Runs inside Blender.

The model scripts build plain geometry and give each material a "kind"
(metal, polymer, wood, fabric ...). This module then:

1. Joins the parts into a small number of meshes (fewer draw calls).
2. Unwraps all baked meshes into one shared UV atlas.
3. Bakes, with Cycles, a mask texture from ray-traced shaders:
   R = convex edges (AO "inside" trick), G = cavities, B = ambient occlusion.
4. Bakes a tangent-space normal map. The Bevel shader rounds every hard edge,
   and procedural bump adds surface detail (stipple, grain, weave, scratches).
5. Bakes albedo and ORM (occlusion, roughness, metallic) from procedural
   layers: base colour variation, edge wear, scratches, grime in cavities,
   dust, and wood grain or camouflage where the kind asks for it.
6. Replaces each material with a plain glTF material that uses the baked
   textures, so the game gets standard PBR materials.

Set GUNFARE_BAKE_CPU=1 to bake on the CPU instead of the GPU.
"""
import math
import os

import bpy
import numpy as np

NOBAKE_KINDS = {"glass", "lens", "emissive", "translucent"}

# Ray distances in metres for the mask pass, per asset class.
PROFILES = {
    "weapon": {"edge": 0.0022, "cavity": 0.006, "ao": 0.05, "bevel": 1.0, "dust": False},
    "character": {"edge": 0.006, "cavity": 0.02, "ao": 0.18, "bevel": 2.2, "dust": True},
    "arms": {"edge": 0.003, "cavity": 0.01, "ao": 0.06, "bevel": 1.5, "dust": False},
}


# --- Small node-graph helper -------------------------------------------------

class G:
    def __init__(self, mat):
        self.nt = mat.node_tree
        self.nt.nodes.clear()
        self.n = self.nt.nodes
        self.l = self.nt.links
        tc = self.n.new("ShaderNodeTexCoord")
        self.obj = tc.outputs["Object"]
        self.uv = tc.outputs["UV"]
        geo = self.n.new("ShaderNodeNewGeometry")
        self.normal = geo.outputs["Normal"]
        self.position = geo.outputs["Position"]

    def _set(self, sock, v):
        if isinstance(v, bpy.types.NodeSocket):
            self.l.new(v, sock)
        elif isinstance(v, (tuple, list)) and sock.type == "RGBA" and len(v) == 3:
            sock.default_value = (*v, 1.0)
        else:
            sock.default_value = v

    def math(self, op, a, b=0.0, clamp=False):
        nd = self.n.new("ShaderNodeMath")
        nd.operation = op
        nd.use_clamp = clamp
        self._set(nd.inputs[0], a)
        self._set(nd.inputs[1], b)
        return nd.outputs[0]

    def add(self, a, b, clamp=False):
        return self.math("ADD", a, b, clamp)

    def mul(self, a, b, clamp=False):
        return self.math("MULTIPLY", a, b, clamp)

    def sub(self, a, b, clamp=False):
        return self.math("SUBTRACT", a, b, clamp)

    def mixf(self, fac, a, b):
        nd = self.n.new("ShaderNodeMix")
        nd.data_type = "FLOAT"
        nd.clamp_factor = True
        self._set(nd.inputs[0], fac)
        self._set(nd.inputs[2], a)
        self._set(nd.inputs[3], b)
        return nd.outputs[0]

    def mixc(self, fac, a, b, blend="MIX"):
        nd = self.n.new("ShaderNodeMix")
        nd.data_type = "RGBA"
        nd.blend_type = blend
        nd.clamp_factor = True
        self._set(nd.inputs[0], fac)
        self._set(nd.inputs[6], a)
        self._set(nd.inputs[7], b)
        return nd.outputs[2]

    def smooth(self, v, lo, hi):
        nd = self.n.new("ShaderNodeMapRange")
        nd.interpolation_type = "SMOOTHSTEP"
        nd.clamp = True
        self._set(nd.inputs[0], v)
        nd.inputs[1].default_value = lo
        nd.inputs[2].default_value = hi
        return nd.outputs[0]

    def remap(self, v, a, b, c, d):
        nd = self.n.new("ShaderNodeMapRange")
        nd.clamp = True
        self._set(nd.inputs[0], v)
        nd.inputs[1].default_value = a
        nd.inputs[2].default_value = b
        nd.inputs[3].default_value = c
        nd.inputs[4].default_value = d
        return nd.outputs[0]

    def mapping(self, vec, scale=(1, 1, 1), loc=(0, 0, 0), rot=(0, 0, 0)):
        nd = self.n.new("ShaderNodeMapping")
        self._set(nd.inputs[0], vec)
        nd.inputs["Location"].default_value = loc
        nd.inputs["Rotation"].default_value = rot
        nd.inputs["Scale"].default_value = scale
        return nd.outputs[0]

    def noise(self, scale, detail=4.0, rough=0.5, vec=None, distortion=0.0, color=False):
        nd = self.n.new("ShaderNodeTexNoise")
        self._set(nd.inputs["Vector"], vec if vec is not None else self.obj)
        nd.inputs["Scale"].default_value = scale
        nd.inputs["Detail"].default_value = detail
        nd.inputs["Roughness"].default_value = rough
        nd.inputs["Distortion"].default_value = distortion
        return nd.outputs[1] if color else nd.outputs[0]

    def voronoi(self, scale, feature="F1", vec=None, rand=1.0, out="Distance"):
        nd = self.n.new("ShaderNodeTexVoronoi")
        nd.feature = feature
        self._set(nd.inputs["Vector"], vec if vec is not None else self.obj)
        nd.inputs["Scale"].default_value = scale
        nd.inputs["Randomness"].default_value = rand
        return nd.outputs[out]

    def wave(self, scale, direction="X", vec=None, distortion=0.0, detail=0.0, kind="BANDS", profile="SIN"):
        nd = self.n.new("ShaderNodeTexWave")
        nd.wave_type = kind
        if kind == "BANDS":
            nd.bands_direction = direction
        else:
            nd.rings_direction = direction
        nd.wave_profile = profile
        self._set(nd.inputs["Vector"], vec if vec is not None else self.obj)
        nd.inputs["Scale"].default_value = scale
        nd.inputs["Distortion"].default_value = distortion
        nd.inputs["Detail"].default_value = detail
        return nd.outputs[1]

    def ao(self, distance, inside=False, local=True, samples=16):
        nd = self.n.new("ShaderNodeAmbientOcclusion")
        nd.inside = inside
        nd.only_local = local
        nd.samples = samples
        nd.inputs["Distance"].default_value = distance
        return nd.outputs["AO"]

    def bevel(self, radius, samples=8):
        nd = self.n.new("ShaderNodeBevel")
        nd.samples = samples
        nd.inputs[0].default_value = radius
        return nd.outputs[0]

    def bump(self, height, distance, normal=None, strength=1.0):
        nd = self.n.new("ShaderNodeBump")
        nd.inputs["Strength"].default_value = strength
        nd.inputs["Distance"].default_value = distance
        self._set(nd.inputs["Height"], height)
        if normal is not None:
            self._set(nd.inputs["Normal"], normal)
        return nd.outputs[0]

    def dot(self, a, b):
        nd = self.n.new("ShaderNodeVectorMath")
        nd.operation = "DOT_PRODUCT"
        self._set(nd.inputs[0], a)
        self._set(nd.inputs[1], b)
        return nd.outputs[1]

    def image(self, img):
        nd = self.n.new("ShaderNodeTexImage")
        nd.image = img
        self._set(nd.inputs[0], self.uv)
        return nd

    def rgb(self, r, g, b):
        nd = self.n.new("ShaderNodeCombineColor")
        self._set(nd.inputs[0], r)
        self._set(nd.inputs[1], g)
        self._set(nd.inputs[2], b)
        return nd.outputs[0]

    def sep(self, col):
        nd = self.n.new("ShaderNodeSeparateColor")
        self._set(nd.inputs[0], col)
        return nd.outputs[0], nd.outputs[1], nd.outputs[2]

    def hsv(self, col, h=0.5, s=1.0, v=1.0):
        nd = self.n.new("ShaderNodeHueSaturation")
        self._set(nd.inputs["Color"], col)
        self._set(nd.inputs["Hue"], h)
        self._set(nd.inputs["Saturation"], s)
        self._set(nd.inputs["Value"], v)
        return nd.outputs[0]

    def out(self, shader):
        o = self.n.new("ShaderNodeOutputMaterial")
        o.target = "ALL"
        self.l.new(shader, o.inputs["Surface"])
        return o

    def emit(self, col):
        e = self.n.new("ShaderNodeEmission")
        self._set(e.inputs["Color"], col)
        e.inputs["Strength"].default_value = 1.0
        self.out(e.outputs[0])

    def target(self, img):
        nd = self.n.new("ShaderNodeTexImage")
        nd.image = img
        self.n.active = nd
        nd.select = True
        return nd


# --- Material description -----------------------------------------------------

def params(mat):
    """Base colour, roughness, metallic and kind stored on the material."""
    col = tuple(mat.get("base", (0.5, 0.5, 0.5)))
    return {
        "kind": mat.get("kind", "polymer"),
        "base": col,
        "base2": tuple(mat.get("base2", col)),
        "base3": tuple(mat.get("base3", col)),
        "base4": tuple(mat.get("base4", col)),
        "rough": float(mat.get("rough", 0.5)),
        "metal": float(mat.get("metal", 0.0)),
        "pattern": int(mat.get("pattern", -1)),
        "wear": float(mat.get("wear", 1.0)),
        "seed": float(mat.get("seed", 0.0)),
        "crease": float(mat.get("crease", 1.0)),
    }


def tag(mat, kind, base, rough, metal, **extra):
    mat["kind"] = kind
    mat["base"] = tuple(base)
    mat["rough"] = rough
    mat["metal"] = metal
    for k, v in extra.items():
        mat[k] = tuple(v) if isinstance(v, (list, tuple)) else v
    return mat


def _camo(g, p, vec):
    """Camouflage pattern in object space. 0 woodland blotch, 1 digital, 2 multicam-like."""
    c0, c1, c2, c3 = p["base"], p["base2"], p["base3"], p["base4"]
    pat = p["pattern"]
    if pat == 1:
        # Digital: quantise the coordinates into 9 mm pixels.
        q = g.n.new("ShaderNodeVectorMath")
        q.operation = "SNAP"
        g._set(q.inputs[0], vec)
        q.inputs[1].default_value = (0.009, 0.009, 0.009)
        v = q.outputs[0]
        n1 = g.noise(9.0, 2.0, 0.6, v)
        n2 = g.noise(14.0, 2.0, 0.6, g.mapping(v, loc=(3.1, 1.7, 9.2)))
        n3 = g.noise(20.0, 1.0, 0.5, g.mapping(v, loc=(7.7, 2.2, 1.3)))
        col = g.mixc(g.smooth(n1, 0.49, 0.5), c0, c1)
        col = g.mixc(g.smooth(n2, 0.56, 0.57), col, c2)
        return g.mixc(g.smooth(n3, 0.6, 0.61), col, c3)
    # Organic blotches with soft breakup.
    n1 = g.noise(5.0, 3.0, 0.55, vec, distortion=0.4)
    n2 = g.noise(8.0, 3.0, 0.55, g.mapping(vec, loc=(4.1, 8.3, 2.7)), distortion=0.3)
    n3 = g.noise(13.0, 2.0, 0.5, g.mapping(vec, loc=(1.9, 6.4, 5.5)))
    col = g.mixc(g.smooth(n1, 0.5, 0.53), c0, c1)
    col = g.mixc(g.smooth(n2, 0.56, 0.59), col, c2)
    return g.mixc(g.smooth(n3, 0.6, 0.62), col, c3)


def layers(g, p, masks, dust_on=True):
    """Returns albedo, roughness, metallic, height and bump distance sockets."""
    k = p["kind"]
    base = p["base"]
    o = g.mapping(g.obj, loc=(p["seed"] * 3.7, p["seed"] * 1.3, p["seed"] * 5.1))
    convex, cavity, occl = masks
    wear_amt = p["wear"]
    breakup = g.noise(90.0, 6.0, 0.65, o)
    fine = g.noise(400.0, 4.0, 0.6, o)
    scratches = g.sub(1.0, g.smooth(g.voronoi(55.0, "DISTANCE_TO_EDGE", g.mapping(o, scale=(1.0, 6.0, 1.0)), out="Distance"), 0.0, 0.012))
    scratches = g.mul(scratches, g.smooth(g.noise(12.0, 2.0, 0.5, o), 0.5, 0.65))
    grime = g.mul(g.smooth(cavity, 0.15, 0.75), g.add(0.6, g.mul(breakup, 0.6)))
    tint = g.add(0.88, g.mul(g.noise(18.0, 3.0, 0.5, o), 0.24))

    if k in ("metal", "camo_metal"):
        coat = g.mixc(0.5, base, g.mixc(tint, (0, 0, 0), base, "MULTIPLY"))
        coat = g.mixc(g.mul(tint, 0.6), base, coat)
        edge = g.smooth(g.add(g.mul(convex, 1.6), g.mul(g.sub(breakup, 0.5), 0.9)), 0.55, 0.75)
        edge = g.mul(edge, wear_amt)
        bare = (0.38, 0.38, 0.39)
        col = g.mixc(edge, coat, bare)
        col = g.mixc(g.mul(scratches, 0.35 * wear_amt), col, (0.3, 0.3, 0.31))
        col = g.mixc(g.mul(grime, 0.7), col, (0.11, 0.095, 0.08))
        rough = g.add(p["rough"], g.mul(g.sub(g.noise(25.0, 3.0, 0.5, o), 0.5), 0.25))
        rough = g.mixf(edge, rough, 0.22)
        rough = g.mixf(g.mul(grime, 0.8), rough, 0.85)
        metal = g.mixf(edge, p["metal"], 1.0)
        metal = g.mixf(grime, metal, 0.0)
        height = g.sub(g.mul(fine, 0.25), g.mul(scratches, 0.5))
        return col, rough, metal, height, 0.00012
    if k == "polymer":
        stip = g.voronoi(1100.0, "F1", o)
        col = g.mixc(tint, base, g.mixc(0.5, base, (0, 0, 0), "MULTIPLY"))
        col = g.mixc(0.5, base, col)
        edge = g.mul(g.smooth(g.add(convex, g.mul(g.sub(breakup, 0.5), 0.6)), 0.45, 0.8), wear_amt)
        col = g.mixc(g.mul(edge, 0.45), col, g.hsv(col, v=1.9))
        col = g.mixc(g.mul(grime, 0.65), col, (0.14, 0.12, 0.1))
        col = g.mixc(g.mul(scratches, 0.2 * wear_amt), col, g.hsv(col, v=1.6))
        rough = g.add(p["rough"], g.mul(g.sub(stip, 0.5), 0.2))
        rough = g.mixf(edge, rough, p["rough"] - 0.22)
        rough = g.mixf(grime, rough, 0.9)
        height = g.add(g.mul(stip, 0.6), g.mul(fine, 0.2))
        return col, rough, 0.0, height, 0.00018
    if k == "rubber":
        col = g.mixc(g.mul(grime, 0.8), g.mixc(tint, base, (0.0, 0.0, 0.0), "MULTIPLY"), (0.13, 0.12, 0.1))
        col = g.mixc(0.6, base, col)
        rough = g.mixf(grime, p["rough"], 0.95)
        height = g.add(g.mul(g.voronoi(700.0, "F1", o), 0.7), g.mul(fine, 0.3))
        return col, rough, 0.0, height, 0.00025
    if k == "wood":
        warp = g.mapping(o, scale=(14.0, 0.5, 14.0))
        grain = g.wave(4.0, "Y", g.add(warp, g.noise(3.0, 2.0, 0.5, o, color=True)), distortion=7.0, detail=4.0, kind="RINGS", profile="SAW")
        fibres = g.noise(900.0, 3.0, 0.5, g.mapping(o, scale=(1.0, 0.04, 1.0)))
        figure = g.noise(25.0, 4.0, 0.6, g.mapping(o, scale=(1.0, 0.25, 1.0)))
        dark = g.hsv(base, s=1.15, v=0.62)
        light = g.hsv(base, s=0.95, v=1.08)
        col = g.mixc(g.mul(g.smooth(grain, 0.35, 0.95), 0.6), light, dark)
        col = g.mixc(g.mul(figure, 0.5), col, g.hsv(base, s=1.2, v=0.7))
        col = g.mixc(g.mul(fibres, 0.35), col, dark)
        edge = g.mul(g.smooth(g.add(convex, g.mul(g.sub(breakup, 0.5), 0.8)), 0.5, 0.8), wear_amt)
        col = g.mixc(g.mul(edge, 0.55), col, g.hsv(base, s=0.75, v=1.5))
        col = g.mixc(g.mul(grime, 0.8), col, (0.06, 0.04, 0.025))
        col = g.mixc(g.mul(scratches, 0.3 * wear_amt), col, g.hsv(base, s=0.7, v=1.7))
        rough = g.add(p["rough"], g.mul(g.smooth(grain, 0.3, 0.9), 0.15))
        rough = g.mixf(edge, rough, 0.72)
        rough = g.mixf(grime, rough, 0.8)
        dents = g.smooth(g.noise(60.0, 2.0, 0.5, o), 0.62, 0.7)
        height = g.sub(g.add(g.mul(grain, 0.25), g.mul(fibres, 0.4)), g.add(dents, g.mul(scratches, 0.6)))
        return col, rough, 0.0, height, 0.0002
    if k == "brass":
        tarnish = g.smooth(g.noise(40.0, 4.0, 0.6, o), 0.45, 0.75)
        col = g.mixc(tarnish, base, g.hsv(base, s=1.2, v=0.55))
        col = g.mixc(grime, col, (0.12, 0.09, 0.05))
        rough = g.mixf(tarnish, p["rough"], 0.5)
        return col, rough, 1.0, g.mul(fine, 0.2), 0.0001
    if k in ("fabric", "webbing", "nylon"):
        if p["pattern"] >= 0:
            col = _camo(g, p, o)
        else:
            col = g.mixc(0.5, base, g.mixc(tint, (0, 0, 0), base, "MULTIPLY"))
        weave_s = 2600.0 if k == "fabric" else 1500.0
        wx = g.wave(weave_s, "X", o)
        wz = g.wave(weave_s, "Z", o)
        weave = g.mul(g.add(wx, wz), 0.5)
        wrinkle = g.noise(14.0, 5.0, 0.62, g.mapping(o, scale=(1.4, 1.4, 0.35)), distortion=0.6)
        wrinkle = g.smooth(wrinkle, 0.35, 0.75)
        height = g.add(g.mul(weave, 0.18), g.mul(wrinkle, 1.0))
        if k == "webbing":
            # MOLLE rows: 25 mm webbing bands with 10 mm gaps, stitched.
            rows = g.wave(0.5 / 0.035 * math.pi, "Z", o, profile="SAW")
            band = g.smooth(rows, 0.25, 0.32)
            height = g.add(g.mul(weave, 0.3), g.mul(band, 0.8))
            col = g.mixc(g.mul(g.sub(1.0, band), 0.35), col, g.hsv(col, v=0.6))
        dust = g.mul(g.smooth(g.sub(0.6, g.sep(g.position)[2]), 0.0, 0.6), 0.6) if dust_on else 0.0
        col = g.mixc(g.mul(grime, 0.55), col, g.hsv(col, s=0.6, v=0.5))
        col = g.mixc(g.mul(dust, g.smooth(breakup, 0.35, 0.7)), col, (0.2, 0.17, 0.13))
        col = g.mixc(g.mul(g.smooth(convex, 0.3, 0.9), 0.35), col, g.hsv(col, s=0.7, v=1.35))
        col = g.mixc(g.mul(wrinkle, 0.25), col, g.hsv(col, v=0.75))
        rough = g.add(p["rough"], g.mul(g.sub(weave, 0.5), 0.08))
        return col, rough, 0.0, height, 0.0009 if k == "fabric" else 0.0007
    if k == "leather":
        crease = g.smooth(g.noise(70.0, 5.0, 0.6, g.mapping(o, scale=(1.0, 0.4, 1.0)), distortion=0.5), 0.55, 0.65)
        grain = g.voronoi(900.0, "F1", o)
        col = g.mixc(tint, base, g.hsv(base, v=0.7))
        edge = g.smooth(g.add(convex, g.mul(g.sub(breakup, 0.5), 0.6)), 0.4, 0.8)
        col = g.mixc(g.mul(edge, 0.5), col, g.hsv(base, s=0.7, v=1.8))
        dust = g.smooth(g.sub(0.25, g.sep(g.position)[2]), 0.0, 0.2) if dust_on else 0.0
        col = g.mixc(g.mul(g.add(grime, g.mul(dust, 0.7)), 0.5), col, (0.17, 0.145, 0.11))
        rough = g.mixf(edge, p["rough"], p["rough"] - 0.15)
        rough = g.mixf(g.add(grime, dust), rough, 0.92)
        height = g.sub(g.mul(grain, 0.35), g.mul(crease, p["crease"]))
        return col, rough, 0.0, height, 0.0004
    if k == "skin":
        blotch = g.noise(35.0, 4.0, 0.55, o)
        col = g.mixc(g.smooth(blotch, 0.4, 0.7), base, g.hsv(base, h=0.49, s=1.25, v=0.92))
        col = g.mixc(g.mul(cavity, 0.6), col, g.hsv(base, s=1.3, v=0.55))
        pores = g.voronoi(2200.0, "F1", o)
        rough = g.add(p["rough"], g.mul(g.sub(blotch, 0.5), 0.15))
        height = g.add(g.mul(pores, 0.25), g.mul(g.noise(300.0, 3.0, 0.5, o), 0.15))
        return col, rough, 0.0, height, 0.00012
    if k == "paint":
        # Painted composite or steel (helmets, launchers): chips show the dark substrate.
        col = g.mixc(0.5, base, g.mixc(tint, (0, 0, 0), base, "MULTIPLY"))
        chips = g.mul(g.smooth(g.add(g.mul(convex, 1.4), g.mul(g.sub(breakup, 0.5), 1.1)), 0.6, 0.72), wear_amt)
        col = g.mixc(chips, col, (0.05, 0.05, 0.05))
        col = g.mixc(g.mul(grime, 0.6), col, (0.2, 0.18, 0.14))
        col = g.mixc(g.mul(scratches, 0.4 * wear_amt), col, g.hsv(base, s=0.5, v=1.5))
        rough = g.add(p["rough"], g.mul(g.sub(g.noise(20.0, 3.0, 0.5, o), 0.5), 0.2))
        rough = g.mixf(chips, rough, 0.45)
        metal = g.mixf(chips, p["metal"], p["metal"])
        height = g.sub(g.mul(fine, 0.3), g.add(chips, g.mul(scratches, 0.4)))
        return col, rough, metal, height, 0.00015
    # Fallback: plain material with light grime.
    col = g.mixc(g.mul(grime, 0.5), base, (0.12, 0.1, 0.08))
    return col, p["rough"], p["metal"], g.mul(fine, 0.2), 0.0001


# --- Baking --------------------------------------------------------------------

def setup_cycles():
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    if not os.environ.get("GUNFARE_BAKE_CPU"):
        try:
            prefs = bpy.context.preferences.addons["cycles"].preferences
            for t in ("HIP", "OPTIX", "CUDA", "ONEAPI", "METAL"):
                try:
                    prefs.compute_device_type = t
                except TypeError:
                    continue
                prefs.refresh_devices()
                gpus = [d for d in prefs.devices if d.type == t]
                if gpus:
                    for d in prefs.devices:
                        d.use = d.type == t
                    sc.cycles.device = "GPU"
                    break
        except Exception as e:  # noqa: BLE001
            print("GPU setup failed, using CPU:", e)
    sc.cycles.use_denoising = False
    sc.render.bake.margin = 12
    sc.render.bake.margin_type = "EXTEND"
    sc.render.bake.use_clear = True
    print("BAKE DEVICE", sc.cycles.device)


def _material_kind(mat):
    return mat.get("kind", "polymer") if mat else None


def bakeable(obj):
    if obj.type != "MESH" or not obj.data.materials:
        return False
    return all(m is not None and _material_kind(m) not in NOBAKE_KINDS for m in obj.data.materials)


def _select(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


def unwrap(objs, margin=0.004):
    _select(objs)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=margin * 0.5, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(rotate=True, margin=margin)
    bpy.ops.object.mode_set(mode="OBJECT")


def _new_image(name, res, colour):
    img = bpy.data.images.get(name)
    if img:
        bpy.data.images.remove(img)
    img = bpy.data.images.new(name, res, res, alpha=False, float_buffer=False)
    img.colorspace_settings.name = "sRGB" if colour else "Non-Color"
    return img


def _bake(objs, kind, samples):
    sc = bpy.context.scene
    sc.cycles.samples = samples
    _select(objs)
    if kind == "NORMAL":
        bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", margin=sc.render.bake.margin)
    else:
        bpy.ops.object.bake(type=kind, margin=sc.render.bake.margin)


def _bake_from_high(objs, high, samples):
    """Normal bake, one low object at a time, from its high objects."""
    sc = bpy.context.scene
    sc.cycles.samples = samples
    bk = sc.render.bake
    bk.use_selected_to_active = True
    bk.cage_extrusion = 0.0015
    bk.max_ray_distance = 0.004
    first = True
    for o in objs:
        src = high.get(o.name) or []
        if not src:
            bk.use_selected_to_active = False
            _select([o])
        else:
            bk.use_selected_to_active = True
            _select([o] + list(src))
            bpy.context.view_layer.objects.active = o
        bk.use_clear = first
        bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", margin=bk.margin, use_clear=first,
                            use_selected_to_active=bool(src), cage_extrusion=bk.cage_extrusion,
                            max_ray_distance=bk.max_ray_distance)
        first = False
    bk.use_selected_to_active = False
    bk.use_clear = True


def _gltf_output_group():
    grp = bpy.data.node_groups.get("glTF Material Output")
    if grp:
        return grp
    grp = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
    grp.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
    grp.interface.new_socket("Thickness", in_out="INPUT", socket_type="NodeSocketFloat")
    return grp


def bake_textures(objs, out_dir, prefix, res=2048, profile="weapon", normal_strength=1.0, high=None):
    """Bakes the PBR set for objs and rewires their materials. Returns file paths.

    high: optional {low object name: [high-detail objects]}. The normal pass
    then bakes the detail of the high objects (with their procedural bump)
    onto the low object, selected to active. The high objects must use the
    same materials as their low object."""
    prof = PROFILES[profile]
    objs = [o for o in objs if bakeable(o)]
    if not objs:
        return {}
    setup_cycles()
    unwrap(objs, margin=0.003 if res >= 2048 else 0.005)
    mats = []
    for o in objs:
        for m in o.data.materials:
            if m not in mats:
                mats.append(m)
    img_mask = _new_image(prefix + "_mask", res, False)
    img_n = _new_image(prefix + "_normal", res, False)
    img_c = _new_image(prefix + "_albedo", res, True)
    img_orm = _new_image(prefix + "_orm", res, False)

    # Pass 1: ray-traced masks.
    for m in mats:
        g = G(m)
        convex = g.sub(1.0, g.ao(prof["edge"], inside=True, local=True))
        cavity = g.sub(1.0, g.ao(prof["cavity"], inside=False, local=True))
        occl = g.ao(prof["ao"], inside=False, local=False)
        g.emit(g.rgb(convex, cavity, occl))
        g.target(img_mask)
    _bake(objs, "EMIT", 48)

    # Pass 2: normals (rounded edges from the Bevel shader + procedural bump).
    for m in mats:
        p = params(m)
        g = G(m)
        mask = g.image(img_mask)
        r, gg, b = g.sep(mask.outputs[0])
        _, _, _, height, dist = layers(g, p, (r, gg, b), prof["dust"])
        bev = g.bevel(prof["bevel"] * 0.001 * (1.6 if p["kind"] in ("polymer", "rubber", "wood") else 1.0))
        nrm = g.bump(height, dist * normal_strength, bev)
        bsdf = g.n.new("ShaderNodeBsdfPrincipled")
        g._set(bsdf.inputs["Normal"], nrm)
        g.out(bsdf.outputs[0])
        g.target(img_n)
    if high:
        _bake_from_high(objs, high, 24)
    else:
        _bake(objs, "NORMAL", 24)

    # Pass 3 and 4: albedo and ORM from procedural layers.
    for pass_name, img in (("albedo", img_c), ("orm", img_orm)):
        for m in mats:
            p = params(m)
            g = G(m)
            mask = g.image(img_mask)
            r, gg, b = g.sep(mask.outputs[0])
            col, rough, metal, _, _ = layers(g, p, (r, gg, b), prof["dust"])
            occl = g.remap(b, 0.0, 1.0, 0.25, 1.0)
            if pass_name == "albedo":
                g.emit(g.mixc(g.mul(g.sub(1.0, b), 0.35), col, (0, 0, 0)))
            else:
                g.emit(g.rgb(occl, g.math("MINIMUM", g.math("MAXIMUM", rough, 0.05), 1.0), metal))
            g.target(img)
        _bake(objs, "EMIT", 4)

    _fix_normals(img_n)
    os.makedirs(out_dir, exist_ok=True)
    files = {}
    for img, q in ((img_c, 90), (img_orm, 92), (img_n, 94)):
        path = os.path.join(out_dir, img.name + ".webp")
        img.filepath_raw = path
        img.file_format = "WEBP"
        img.save(filepath=path, quality=q)
        img.filepath = path
        img.source = "FILE"
        img.reload()
        files[img.name] = path
    bpy.data.images.remove(img_mask)

    # Final materials: plain glTF PBR.
    for m in mats:
        nt = m.node_tree
        nt.nodes.clear()
        tc = nt.nodes.new("ShaderNodeTexCoord")
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
        tc_c = nt.nodes.new("ShaderNodeTexImage")
        tc_c.image = img_c
        nt.links.new(tc.outputs["UV"], tc_c.inputs[0])
        nt.links.new(tc_c.outputs[0], bsdf.inputs["Base Color"])
        t_orm = nt.nodes.new("ShaderNodeTexImage")
        t_orm.image = img_orm
        nt.links.new(tc.outputs["UV"], t_orm.inputs[0])
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(t_orm.outputs[0], sep.inputs[0])
        nt.links.new(sep.outputs[1], bsdf.inputs["Roughness"])
        nt.links.new(sep.outputs[2], bsdf.inputs["Metallic"])
        grp = nt.nodes.new("ShaderNodeGroup")
        grp.node_tree = _gltf_output_group()
        nt.links.new(sep.outputs[0], grp.inputs["Occlusion"])
        t_n = nt.nodes.new("ShaderNodeTexImage")
        t_n.image = img_n
        nt.links.new(tc.outputs["UV"], t_n.inputs[0])
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(t_n.outputs[0], nm.inputs["Color"])
        nt.links.new(nm.outputs[0], bsdf.inputs["Normal"])
    return files


def _fix_normals(img):
    """Ray-traced bevel normals can flip on thin or overlapping parts. Blend
    any texel that points away from the surface back towards flat."""
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(-1, 4)
    n = px[:, :3] * 2.0 - 1.0
    z = n[:, 2]
    t = np.clip((z - 0.15) / 0.45, 0.0, 1.0)[:, None]
    flat = np.array([0.0, 0.0, 1.0], dtype=np.float32)
    n = n * t + flat * (1.0 - t)
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-6)
    px[:, :3] = n * 0.5 + 0.5
    img.pixels.foreach_set(px.ravel())
    img.update()


def join(objs, name, parent=None):
    """Joins mesh objects into one, keeping world placement. Returns the result."""
    objs = [o for o in objs if o.type == "MESH"]
    if not objs:
        return None
    for i, o in enumerate(objs):
        o.name = "__join_%d" % i
    _select(objs)
    if len(objs) > 1:
        bpy.ops.object.join()
    res = bpy.context.view_layer.objects.active
    res.name = name
    res.data.name = name
    if parent is not None and res.parent != parent:
        mw = res.matrix_world.copy()
        res.parent = parent
        res.matrix_world = mw
    return res


def export_gltf(path):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLTF_SEPARATE",
        export_keep_originals=True,
        export_image_format="AUTO",
        export_yup=True,
        export_apply=True,
        export_materials="EXPORT",
        export_animations=False,
        export_skins=True,
        export_def_bones=False,
        use_selection=False,
    )
