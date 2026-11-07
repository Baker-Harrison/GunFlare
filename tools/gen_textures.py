"""Procedural, seamlessly tiling PBR textures for world materials.

Writes <id>_albedo.png, <id>_normal.png, <id>_rough.png into assets/textures.

    python tools/gen_textures.py [size]
"""
import os
import sys

import numpy as np
from PIL import Image

N = int(sys.argv[1]) if len(sys.argv) > 1 else 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
rng = np.random.default_rng(7)


def periodic_noise(n, cells, seed):
    """Tileable value noise: random grid with wrap-around, smooth interpolation."""
    r = np.random.default_rng(seed)
    g = r.random((cells, cells))
    x = np.linspace(0, cells, n, endpoint=False)
    xi = np.floor(x).astype(int)
    xf = x - xi
    xf = xf * xf * (3 - 2 * xf)
    x0 = xi % cells
    x1 = (xi + 1) % cells
    a = g[np.ix_(x0, x0)]
    b = g[np.ix_(x0, x1)]
    c = g[np.ix_(x1, x0)]
    d = g[np.ix_(x1, x1)]
    fy = xf[:, None]
    fx = xf[None, :]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(n, base_cells, octaves, seed, gain=0.5):
    v = np.zeros((n, n))
    amp = 1.0
    total = 0.0
    cells = base_cells
    for o in range(octaves):
        if cells >= n:
            break
        v += periodic_noise(n, cells, seed + o * 101) * amp
        total += amp
        amp *= gain
        cells *= 2
    return v / total


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * strength
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * strength
    nz = np.ones_like(h)
    l = np.sqrt(dx * dx + dy * dy + nz * nz)
    nx, ny, nz = -dx / l, dy / l, nz / l  # OpenGL-style (Godot expects +Y up)
    return np.stack([(nx + 1) * 0.5, (ny + 1) * 0.5, (nz + 1) * 0.5], axis=-1)


def colorize(t, c0, c1):
    t = np.clip(t, 0, 1)[..., None]
    return np.array(c0)[None, None, :] * (1 - t) + np.array(c1)[None, None, :] * t


def save(name, albedo, height, rough, nstrength=6.0):
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray((np.clip(albedo, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, name + "_albedo.png"))
    nm = normal_from_height(height, nstrength * N / 1024)
    Image.fromarray((np.clip(nm, 0, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, name + "_normal.png"))
    r = (np.clip(np.broadcast_to(rough, height.shape), 0, 1) * 255).astype(np.uint8)
    Image.fromarray(np.stack([r, r, r], axis=-1)).save(os.path.join(OUT, name + "_rough.png"))
    print("  ", name)


def grid():
    y, x = np.mgrid[0:N, 0:N] / N
    return x, y


# --- Materials -----------------------------------------------------------------

def concrete(name, c0, c1, seed):
    base = fbm(N, 4, 8, seed)
    fine = fbm(N, 64, 3, seed + 5)
    stains = fbm(N, 3, 4, seed + 9)
    pores = (periodic_noise(N, 256, seed + 13) > 0.93).astype(float)
    h = base * 0.5 + fine * 0.4 - pores * 0.3
    t = base * 0.6 + fine * 0.3 + (stains - 0.5) * 0.5
    alb = colorize(t, c1, c0) * (1 - pores[..., None] * 0.35)
    rough = 0.82 + fine * 0.15 - (stains < 0.35) * 0.1
    save(name, alb, h, rough, 4.0)


def plaster(name, c0, c1, seed):
    base = fbm(N, 3, 7, seed)
    fine = fbm(N, 96, 2, seed + 3)
    # Hairline cracks from ridges of a noise field.
    ridge = 1.0 - np.abs(fbm(N, 6, 5, seed + 7) - 0.5) * 2.0
    cracks = np.clip((ridge - 0.965) * 30.0, 0, 1)
    dirt = np.clip((fbm(N, 2, 4, seed + 11) - 0.55) * 2.0, 0, 1)
    t = base * 0.7 + fine * 0.3
    alb = colorize(t, c1, c0)
    alb *= (1 - cracks[..., None] * 0.45)
    alb *= (1 - dirt[..., None] * 0.18)
    h = base * 0.4 + fine * 0.3 - cracks * 0.5
    save(name, alb, h, 0.9 + fine * 0.08, 3.0)


def brick(name, c0, c1, mortar, seed, rows=24, cols=8):
    x, y = grid()
    row = np.floor(y * rows).astype(int)
    off = (row % 2) * 0.5
    bx = (x * cols + off) % 1.0
    by = (y * rows) % 1.0
    col = np.floor(x * cols + off).astype(int) % cols
    mw_x = 0.06
    mw_y = 0.12
    edge = np.minimum(np.minimum(bx, 1 - bx) / mw_x, np.minimum(by, 1 - by) / mw_y)
    chip = fbm(N, 32, 4, seed + 3)
    is_brick = (edge + (chip - 0.5) * 0.6) > 1.0
    r = np.random.default_rng(seed)
    tint = r.random((rows, cols))[row % rows, col]
    surface = fbm(N, 48, 4, seed + 1)
    alb_b = colorize(tint * 0.6 + surface * 0.4, c1, c0)
    alb_m = colorize(fbm(N, 64, 3, seed + 2), np.array(mortar) * 0.85, mortar)
    alb = np.where(is_brick[..., None], alb_b, alb_m)
    soot = np.clip((fbm(N, 3, 4, seed + 8) - 0.5) * 1.5, 0, 1)
    alb *= 1 - soot[..., None] * 0.25
    h = np.where(is_brick, 0.7 + surface * 0.25, 0.25 + chip * 0.1)
    rough = np.where(is_brick, 0.85, 0.95)
    save(name, alb, h, rough, 8.0)


def tile(name, c0, c1, grout, seed, n_tiles=6):
    x, y = grid()
    tx = (x * n_tiles) % 1.0
    ty = (y * n_tiles) % 1.0
    ix = np.floor(x * n_tiles).astype(int)
    iy = np.floor(y * n_tiles).astype(int)
    edge = np.minimum(np.minimum(tx, 1 - tx), np.minimum(ty, 1 - ty))
    is_tile = edge > 0.025
    r = np.random.default_rng(seed)
    tint = r.random((n_tiles, n_tiles))[iy, ix]
    surf = fbm(N, 24, 5, seed + 1)
    alb = np.where(is_tile[..., None], colorize(tint * 0.4 + surf * 0.6, c1, c0), np.array(grout)[None, None, :])
    wear = np.clip((fbm(N, 4, 5, seed + 4) - 0.5) * 2, 0, 1)
    alb *= 1 - wear[..., None] * 0.15
    h = np.where(is_tile, 0.8 - (1 - np.clip(edge / 0.06, 0, 1)) * 0.2, 0.2)
    rough = np.where(is_tile, 0.35 + wear * 0.4, 0.95)
    save(name, alb, h, rough, 6.0)


def asphalt(name, seed):
    base = fbm(N, 8, 6, seed)
    agg = periodic_noise(N, 384, seed + 1)
    stones = (agg > 0.78).astype(float) * agg
    ridge = 1.0 - np.abs(fbm(N, 4, 6, seed + 2) - 0.5) * 2.0
    cracks = np.clip((ridge - 0.975) * 40.0, 0, 1)
    tar = np.clip((fbm(N, 3, 4, seed + 3) - 0.6) * 3, 0, 1)
    t = base * 0.5 + stones * 0.6
    alb = colorize(t, (0.09, 0.09, 0.095), (0.3, 0.3, 0.3))
    alb *= 1 - cracks[..., None] * 0.6
    alb *= 1 - tar[..., None] * 0.3
    h = base * 0.3 + stones * 0.5 - cracks * 0.6
    rough = 0.88 - tar * 0.25
    save(name, alb, h, rough, 5.0)


def ground(name, c0, c1, seed, grain_cells=128, ripples=False, pebbles=0.0):
    base = fbm(N, 4, 7, seed)
    grain = periodic_noise(N, grain_cells, seed + 1) * 0.5 + periodic_noise(N, grain_cells * 2, seed + 2) * 0.5
    h = base * 0.5 + grain * 0.3
    if ripples:
        x, y = grid()
        warp = fbm(N, 3, 3, seed + 4)
        h += np.sin((y * 10 + warp * 1.5) * np.pi * 2) * 0.12
    if pebbles > 0:
        p = periodic_noise(N, 160, seed + 6)
        peb = np.clip((p - (1 - pebbles)) * 8, 0, 1)
        h += peb * 0.4
    t = base * 0.6 + grain * 0.4
    alb = colorize(t, c1, c0)
    if pebbles > 0:
        alb = alb * (1 - peb[..., None] * 0.3) + peb[..., None] * np.array([0.45, 0.43, 0.4]) * 0.3
    save(name, alb, h, 0.95 + grain * 0.05, 5.0)


def grass(name, seed):
    base = fbm(N, 4, 6, seed)
    blades = periodic_noise(N, 512, seed + 1)
    blades2 = periodic_noise(N, 256, seed + 2)
    dirt = np.clip((fbm(N, 6, 5, seed + 3) - 0.62) * 3, 0, 1)
    t = base * 0.4 + blades * 0.35 + blades2 * 0.25
    alb = colorize(t, (0.12, 0.18, 0.06), (0.36, 0.44, 0.18))
    alb = alb * (1 - dirt[..., None]) + dirt[..., None] * np.array([0.33, 0.27, 0.19])
    h = blades * 0.5 + blades2 * 0.3 - dirt * 0.2
    save(name, alb, h, 0.95, 4.0)


def metal(name, c0, c1, seed, rust=0.0, brushed=True):
    x, y = grid()
    streak = periodic_noise(N, 8, seed)[:, :1].repeat(N, axis=1) if brushed else 0
    fine = fbm(N, 128, 3, seed + 1)
    base = fbm(N, 4, 6, seed + 2)
    scratches = np.zeros((N, N))
    r = np.random.default_rng(seed)
    for _ in range(120):
        x0, y0 = r.integers(0, N, 2)
        ang = r.uniform(0, np.pi)
        length = r.integers(20, 200)
        for k in range(length):
            px = int(x0 + np.cos(ang) * k) % N
            py = int(y0 + np.sin(ang) * k) % N
            scratches[py, px] = 1.0
    t = base * 0.5 + fine * 0.3 + (periodic_noise(N, 256, seed + 4)[:, :] * 0.2 if brushed else 0)
    alb = colorize(t, c1, c0)
    alb = alb * (1 - scratches[..., None] * 0.0) + scratches[..., None] * 0.25
    rough = 0.45 + fine * 0.2 - scratches * 0.2
    h = fine * 0.2 - scratches * 0.3
    if rust > 0:
        rmask = np.clip((fbm(N, 4, 7, seed + 5) - (1 - rust)) * 4, 0, 1)
        rust_c = colorize(fbm(N, 32, 4, seed + 6), (0.25, 0.1, 0.05), (0.55, 0.3, 0.15))
        alb = alb * (1 - rmask[..., None]) + rust_c * rmask[..., None]
        rough = rough * (1 - rmask) + 0.9 * rmask
        h += rmask * fbm(N, 64, 3, seed + 7) * 0.4
    save(name, alb, h, rough, 3.0)


def corrugated(name, paint, seed, ribs=16):
    x, y = grid()
    wave_ = np.sin(x * ribs * np.pi * 2)
    base = fbm(N, 4, 6, seed)
    wear = np.clip((fbm(N, 6, 6, seed + 1) - 0.6) * 3, 0, 1)
    rust = np.clip((fbm(N, 3, 6, seed + 2) - 0.66) * 4, 0, 1) * np.clip(1 - y * 0.2, 0, 1)
    streaks = periodic_noise(N, 64, seed + 3)[:1, :].repeat(N, axis=0) * fbm(N, 2, 3, seed + 4)
    alb = colorize(base * 0.6 + 0.4, np.array(paint) * 0.75, paint)
    alb *= 1 - streaks[..., None] * 0.25
    alb = alb * (1 - wear[..., None]) + wear[..., None] * np.array([0.4, 0.4, 0.42])
    alb = alb * (1 - rust[..., None]) + rust[..., None] * np.array([0.42, 0.22, 0.1])
    h = wave_ * 0.5 + base * 0.1
    rough = 0.55 + wear * 0.1 + rust * 0.3
    save(name, alb, h, rough, 10.0)


def wood(name, c0, c1, seed, planks=6):
    x, y = grid()
    plank = np.floor(y * planks).astype(int)
    r = np.random.default_rng(seed)
    shift = r.random(planks)[plank % planks]
    warp = fbm(N, 4, 5, seed + 1)
    grain = np.sin((x * 3 + shift * 7 + warp * 2.5) * np.pi * 2 * 6 + y * 40) * 0.5 + 0.5
    rings = (np.sin((y * planks % 1.0) * np.pi * 2 * 3 + warp * 6) * 0.5 + 0.5)
    py = (y * planks) % 1.0
    gap = (np.minimum(py, 1 - py) < 0.025).astype(float)
    # Plank end joints
    ends = (((x * 2 + shift) % 1.0) < 0.006).astype(float)
    t = grain * 0.55 + rings * 0.25 + shift * 0.2
    alb = colorize(t, c1, c0) * (1 - (gap + ends)[..., None].clip(0, 1) * 0.6)
    h = grain * 0.3 - gap * 0.8 - ends * 0.5
    save(name, alb, h, 0.75 + grain * 0.15, 5.0)


def roof(name, seed, rows=14):
    x, y = grid()
    row = np.floor(y * rows).astype(int)
    off = (row % 2) * 0.5
    sx = (x * 10 + off) % 1.0
    sy = (y * rows) % 1.0
    r = np.random.default_rng(seed)
    tint = r.random((rows, 10))[row % rows, np.floor(x * 10 + off).astype(int) % 10]
    shade = 1 - sy * 0.5
    gap = (np.minimum(sx, 1 - sx) < 0.03).astype(float)
    base = fbm(N, 32, 4, seed + 1)
    alb = colorize(tint * 0.5 + base * 0.5, (0.18, 0.16, 0.15), (0.38, 0.32, 0.28)) * shade[..., None]
    alb *= 1 - gap[..., None] * 0.5
    h = sy * 0.6 + base * 0.2 - gap * 0.4
    save(name, alb, h, 0.9, 6.0)


def fabric(name, c0, c1, seed):
    x, y = grid()
    weave = (np.sin(x * N * 0.35) * np.sin(y * N * 0.35)) * 0.5 + 0.5
    base = fbm(N, 6, 5, seed)
    alb = colorize(base * 0.6 + weave * 0.4, c1, c0)
    save(name, alb, weave * 0.3 + base * 0.2, 0.95, 2.0)


def rock(name, seed):
    base = fbm(N, 3, 8, seed)
    ridge = 1.0 - np.abs(fbm(N, 5, 6, seed + 1) - 0.5) * 2.0
    strata = np.sin((np.mgrid[0:N, 0:N][0] / N * 12 + base * 3) * np.pi) * 0.5 + 0.5
    lichen = np.clip((fbm(N, 8, 5, seed + 2) - 0.68) * 4, 0, 1)
    t = base * 0.5 + strata * 0.2 + ridge * 0.3
    alb = colorize(t, (0.26, 0.24, 0.22), (0.6, 0.57, 0.52))
    alb = alb * (1 - lichen[..., None] * 0.6) + lichen[..., None] * np.array([0.42, 0.45, 0.3]) * 0.6
    save(name, alb, base * 0.6 + ridge * 0.4, 0.92, 7.0)


def snow(name, seed):
    base = fbm(N, 4, 7, seed)
    sparkle = (periodic_noise(N, 512, seed + 1) > 0.97).astype(float)
    drift = fbm(N, 2, 4, seed + 2)
    alb = colorize(base * 0.5 + drift * 0.5, (0.78, 0.82, 0.88), (0.96, 0.97, 0.99)) + sparkle[..., None] * 0.08
    save(name, alb, base * 0.4 + drift * 0.4, 0.75 - sparkle * 0.5, 3.0)


def main():
    print("Textures at %dx%d" % (N, N))
    concrete("concrete", (0.6, 0.59, 0.56), (0.4, 0.39, 0.37), 1)
    concrete("concrete_dark", (0.38, 0.38, 0.37), (0.24, 0.24, 0.24), 2)
    plaster("plaster", (0.8, 0.72, 0.6), (0.66, 0.58, 0.47), 3)
    plaster("plaster_white", (0.88, 0.86, 0.82), (0.74, 0.72, 0.68), 4)
    plaster("plaster_blue", (0.48, 0.63, 0.7), (0.36, 0.5, 0.58), 5)
    plaster("plaster_terracotta", (0.75, 0.45, 0.32), (0.58, 0.33, 0.23), 6)
    brick("brick", (0.62, 0.32, 0.22), (0.4, 0.2, 0.14), (0.62, 0.6, 0.55), 7)
    brick("brick_grey", (0.5, 0.49, 0.47), (0.32, 0.31, 0.3), (0.55, 0.54, 0.52), 8)
    ground("sand", (0.82, 0.71, 0.53), (0.64, 0.54, 0.38), 9, 160, ripples=True)
    ground("dirt", (0.45, 0.37, 0.27), (0.28, 0.23, 0.17), 10, 128, pebbles=0.08)
    grass("grass", 11)
    snow("snow", 12)
    asphalt("asphalt", 13)
    metal("metal", (0.5, 0.52, 0.54), (0.33, 0.35, 0.36), 14)
    metal("metal_rust", (0.42, 0.3, 0.22), (0.28, 0.2, 0.15), 15, rust=0.7, brushed=False)
    corrugated("sheet_metal", (0.55, 0.57, 0.58), 16)
    corrugated("container_red", (0.58, 0.17, 0.12), 17)
    corrugated("container_blue", (0.17, 0.32, 0.52), 18)
    corrugated("container_green", (0.21, 0.4, 0.26), 19)
    corrugated("container_yellow", (0.76, 0.58, 0.16), 20)
    wood("wood", (0.55, 0.39, 0.23), (0.36, 0.25, 0.14), 21)
    wood("wood_dark", (0.33, 0.22, 0.13), (0.2, 0.13, 0.07), 22)
    tile("tile", (0.74, 0.71, 0.64), (0.6, 0.57, 0.5), (0.45, 0.43, 0.4), 23)
    roof("roof", 24)
    rock("rock", 25)
    fabric("fabric_red", (0.62, 0.16, 0.12), (0.45, 0.1, 0.08), 26)
    fabric("fabric_blue", (0.2, 0.32, 0.57), (0.12, 0.2, 0.4), 27)
    fabric("fabric_tan", (0.77, 0.68, 0.5), (0.6, 0.52, 0.37), 28)


if __name__ == "__main__":
    main()
