"""Procedural sound design for GunFare.

Every sound in the game is synthesised here from noise, oscillators and
filters, then written to assets/audio as 16-bit 44.1 kHz WAV.

    python tools/gen_audio.py
"""
import math
import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(20261106)


# --- DSP helpers -------------------------------------------------------------

def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def noise(dur):
    return rng.uniform(-1.0, 1.0, int(SR * dur))


def env_exp(dur, decay, attack=0.0005):
    t = t_axis(dur)
    e = np.exp(-t / max(decay, 1e-5))
    if attack > 0:
        e *= np.clip(t / attack, 0.0, 1.0)
    return e


def env_adsr(dur, a, d, s, r):
    n = int(SR * dur)
    e = np.zeros(n)
    ai, di, ri = int(SR * a), int(SR * d), int(SR * r)
    si = max(n - ai - di - ri, 0)
    seg = [np.linspace(0, 1, ai, endpoint=False), np.linspace(1, s, di, endpoint=False),
           np.full(si, s), np.linspace(s, 0, ri)]
    c = np.concatenate(seg)[:n]
    e[:len(c)] = c
    return e


def biquad(x, kind, f, q=0.707, gain_db=0.0):
    """RBJ cookbook biquad."""
    f = min(max(f, 10.0), SR * 0.49)
    w0 = 2 * math.pi * f / SR
    alpha = math.sin(w0) / (2 * q)
    cw = math.cos(w0)
    A = 10 ** (gain_db / 40)
    if kind == "lp":
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "hp":
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "bp":
        b = [alpha, 0, -alpha]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "peak":
        b = [1 + alpha * A, -2 * cw, 1 - alpha * A]
        a = [1 + alpha / A, -2 * cw, 1 - alpha / A]
    elif kind == "lowshelf":
        sq = 2 * math.sqrt(A) * alpha
        b = [A * ((A + 1) - (A - 1) * cw + sq), 2 * A * ((A - 1) - (A + 1) * cw), A * ((A + 1) - (A - 1) * cw - sq)]
        a = [(A + 1) + (A - 1) * cw + sq, -2 * ((A - 1) + (A + 1) * cw), (A + 1) + (A - 1) * cw - sq]
    else:
        raise ValueError(kind)
    b = np.array(b) / a[0]
    a = np.array(a) / a[0]
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    b0, b1, b2 = b
    a1, a2 = a[1], a[2]
    for i in range(len(x)):
        xi = x[i]
        yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, xi
        y2, y1 = y1, yi
        y[i] = yi
    return y


def onepole_lp(x, f):
    a = math.exp(-2 * math.pi * f / SR)
    y = np.zeros_like(x)
    s = 0.0
    for i in range(len(x)):
        s = (1 - a) * x[i] + a * s
        y[i] = s
    return y


def sweep(dur, f0, f1, curve=4.0):
    t = t_axis(dur)
    f = f1 + (f0 - f1) * np.exp(-t * curve / dur)
    phase = 2 * math.pi * np.cumsum(f) / SR
    return np.sin(phase)


def pad(x, dur):
    n = int(SR * dur)
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def at(x, offset, total):
    out = np.zeros(int(SR * total))
    s = int(SR * offset)
    e = min(len(out), s + len(x))
    out[s:e] += x[:e - s]
    return out


def sat(x, drive=2.0):
    return np.tanh(x * drive) / np.tanh(drive)


def reverb(x, decay=1.2, mix=0.3, tone=3000.0):
    """Cheap feedback-delay reverb for environmental tails."""
    total = len(x) + int(SR * decay)
    y = np.zeros(total)
    y[:len(x)] = x
    wet = np.zeros(total)
    delays = [0.0297, 0.0371, 0.0411, 0.0437, 0.053, 0.061]
    for d in delays:
        di = int(SR * d)
        g = 10 ** (-3 * d / decay)
        buf = np.zeros(total)
        buf[:len(x)] = x
        for k in range(1, int(decay / d) + 1):
            s = di * k
            if s >= total:
                break
            buf[s:] += x[:total - s] * (g ** k) if total - s <= len(x) else np.pad(x, (0, total - s - len(x)))[:total - s] * (g ** k)
        wet += buf
    wet = onepole_lp(wet / len(delays), tone)
    return y * (1 - mix) + wet * mix


def mix(*xs):
    n = max(len(x) for x in xs)
    out = np.zeros(n)
    for x in xs:
        out[: len(x)] += x
    return out


def normalize(x, peak=0.95):
    m = np.max(np.abs(x)) if len(x) else 0
    if m < 1e-9:
        return x
    return x / m * peak


def fade_out(x, dur=0.01):
    n = min(int(SR * dur), len(x))
    if n > 0:
        x[-n:] *= np.linspace(1, 0, n)
    return x


def write(name, x, peak=0.95):
    os.makedirs(OUT, exist_ok=True)
    x = fade_out(normalize(np.asarray(x, dtype=np.float64), peak))
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("  ", name)


# --- Weapons -----------------------------------------------------------------

GUNS = {
    #           crack_f  body_f  body_decay thump_f  thump_amt  tail  dur   mech
    "rifle":        (5200, 1500, 0.045, 95, 0.9, 0.55, 0.9, 0.03),
    "rifle_heavy":  (4200, 1100, 0.06, 75, 1.2, 0.7, 1.1, 0.035),
    "smg":          (6200, 1900, 0.03, 120, 0.6, 0.4, 0.7, 0.025),
    "lmg":          (4500, 1200, 0.055, 80, 1.15, 0.65, 1.0, 0.03),
    "sniper":       (3800, 900, 0.09, 60, 1.6, 1.2, 1.9, 0.0),
    "sniper_heavy": (3200, 700, 0.12, 45, 2.0, 1.5, 2.2, 0.0),
    "pistol":       (6500, 2000, 0.03, 140, 0.55, 0.45, 0.8, 0.02),
    "magnum":       (4600, 1200, 0.07, 70, 1.4, 0.9, 1.3, 0.0),
    "shotgun":      (3500, 900, 0.09, 65, 1.6, 0.9, 1.3, 0.0),
}


def gunshot(kind, variant):
    crack_f, body_f, body_decay, thump_f, thump_amt, tail, dur, mech = GUNS[kind]
    jitter = 1.0 + (variant - 1) * 0.05
    # Supersonic crack / transient
    crack = biquad(noise(0.02), "hp", crack_f * jitter) * env_exp(0.02, 0.003)
    # Muzzle blast body
    body = biquad(noise(0.35), "bp", body_f * jitter, 0.6) * env_exp(0.35, body_decay)
    body += biquad(noise(0.35), "lp", body_f * 2.5) * env_exp(0.35, body_decay * 0.6) * 0.6
    # Low thump
    thump = sweep(0.3, thump_f * 2.2, thump_f * 0.7, 6.0) * env_exp(0.3, 0.06 + thump_amt * 0.02) * thump_amt
    shot = at(crack * 1.2, 0, dur) + at(body, 0, dur) + at(thump, 0, dur)
    shot = sat(shot * 1.4, 2.5)
    # Environment slap and tail
    slap = biquad(noise(0.4), "lp", 2200) * env_exp(0.4, 0.09)
    shot += at(slap * 0.25, 0.045, dur)
    shot = reverb(shot, decay=tail, mix=0.35, tone=2800)[: int(SR * dur)]
    # Mechanical action
    if mech > 0:
        clack = biquad(noise(0.03), "bp", 3400, 2.0) * env_exp(0.03, 0.006)
        shot += at(clack * 0.25, mech, dur)
    return shot


def suppressed(variant):
    dur = 0.5
    thud = biquad(noise(0.2), "lp", 900 + variant * 60) * env_exp(0.2, 0.025)
    puff = biquad(noise(0.1), "bp", 2400, 1.2) * env_exp(0.1, 0.012) * 0.6
    mech = biquad(noise(0.04), "bp", 3800, 3.0) * env_exp(0.04, 0.006) * 0.7
    low = sweep(0.15, 180, 70, 5) * env_exp(0.15, 0.03) * 0.5
    return at(thud, 0, dur) + at(puff, 0, dur) + at(mech, 0.018, dur) + at(low, 0, dur)


def distant(variant):
    dur = 2.2
    crack = biquad(noise(0.05), "bp", 1400, 0.8) * env_exp(0.05, 0.01)
    boom = biquad(noise(1.0), "lp", 380) * env_exp(1.0, 0.18, 0.01)
    shot = at(crack, 0, dur) + at(boom * 1.3, 0.01, dur)
    return reverb(shot, decay=1.8, mix=0.6, tone=900)[: int(SR * dur)]


def tail():
    dur = 1.6
    x = biquad(noise(dur), "lp", 1200) * env_exp(dur, 0.35, 0.05)
    return reverb(x, 1.4, 0.5, 1500)[: int(SR * dur)]


def launcher():
    dur = 1.6
    pop = sweep(0.3, 220, 50, 5) * env_exp(0.3, 0.07)
    blast = biquad(noise(0.4), "lp", 1400) * env_exp(0.4, 0.08)
    whoosh = biquad(noise(1.2), "bp", 1800, 0.7) * env_adsr(1.2, 0.05, 0.3, 0.4, 0.8)
    return reverb(sat(at(pop * 1.2, 0, dur) + at(blast, 0, dur) + at(whoosh * 0.5, 0.05, dur), 2.0), 1.2, 0.3)[: int(SR * dur)]


def turret(kind):
    if kind == "heli":
        x = gunshot("lmg", 2)[: int(SR * 0.4)]
        return biquad(x, "lp", 3000)
    if kind == "sentry":
        return gunshot("smg", 3)[: int(SR * 0.35)]
    return x


def gunship(cal):
    if cal == 25:
        return gunshot("rifle_heavy", 1)[: int(SR * 0.4)]
    dur = 2.5 if cal == 105 else 1.4
    boom = sweep(0.8, 120 if cal == 105 else 200, 30, 4) * env_exp(0.8, 0.25 if cal == 105 else 0.12)
    blast = biquad(noise(0.6), "lp", 900) * env_exp(0.6, 0.12)
    return reverb(sat(at(boom * 1.5, 0, dur) + at(blast, 0, dur), 2.5), 2.0, 0.45, 1200)[: int(SR * dur)]


# --- Foley ---------------------------------------------------------------------

def footstep(v):
    dur = 0.22
    heel = biquad(noise(0.06), "bp", 380 + v * 40, 1.2) * env_exp(0.06, 0.012)
    grit = biquad(noise(0.12), "hp", 2500 + v * 300) * env_exp(0.12, 0.02) * 0.35
    toe = biquad(noise(0.05), "bp", 700, 1.5) * env_exp(0.05, 0.01) * 0.6
    return at(heel, 0, dur) + at(grit, 0.005, dur) + at(toe, 0.06 + v * 0.005, dur)


def impact(material, v):
    dur = 0.3
    if material == "metal":
        ring = sum(np.sin(2 * math.pi * f * t_axis(dur)) * env_exp(dur, 0.04 + i * 0.01) for i, f in enumerate([1800 + v * 150, 3100, 4700]))
        hit = biquad(noise(0.02), "hp", 3000) * env_exp(0.02, 0.003)
        return at(hit, 0, dur) + ring * 0.25
    hit = biquad(noise(0.08), "bp", 1800 + v * 200, 0.9) * env_exp(0.08, 0.01)
    debris = biquad(noise(0.25), "hp", 3500) * env_exp(0.25, 0.05) * 0.3
    return at(hit, 0, dur) + at(debris, 0.01, dur)


def explosion(big, v):
    dur = 3.5 if big else 2.6
    boom = sweep(1.2, 90, 25, 3) * env_exp(1.2, 0.35 if big else 0.25)
    blast = biquad(noise(1.5), "lp", 700) * env_exp(1.5, 0.3 if big else 0.2, 0.004)
    crack = biquad(noise(0.05), "hp", 1500) * env_exp(0.05, 0.008)
    debris = np.zeros(int(SR * dur))
    for _ in range(40 if big else 25):
        o = rng.uniform(0.05, dur * 0.6)
        d = biquad(noise(0.02), "bp", rng.uniform(1500, 5000), 2.0) * env_exp(0.02, 0.004) * rng.uniform(0.05, 0.25)
        debris += at(d, o, dur)
    x = at(boom * 1.6, 0, dur) + at(blast * 1.2, 0, dur) + at(crack, 0, dur) + debris
    return reverb(sat(x, 3.0), 2.5 if big else 1.8, 0.4, 900)[: int(SR * dur)]


def flashbang():
    dur = 2.5
    bang = explosion(False, 1)[: int(SR * 0.8)] * 0.8
    ring = np.sin(2 * math.pi * 3600 * t_axis(dur)) * env_exp(dur, 0.9, 0.05) * 0.2
    return at(bang, 0, dur) + ring


def tone(f, dur, decay, wave_="sine", detune=0.0):
    t = t_axis(dur)
    if wave_ == "sine":
        x = np.sin(2 * math.pi * f * t)
    elif wave_ == "square":
        x = np.sign(np.sin(2 * math.pi * f * t)) * 0.5
    elif wave_ == "saw":
        x = 2 * (t * f - np.floor(0.5 + t * f))
    else:
        x = np.sin(2 * math.pi * f * t)
    if detune:
        x = x + np.sin(2 * math.pi * f * (1 + detune) * t)
    return x * env_exp(dur, decay, 0.002)


def click(f=2200, dur=0.05):
    return biquad(noise(dur), "bp", f, 3.0) * env_exp(dur, 0.006)


def mech_sequence(events, dur):
    """events: [(time, freq, q, decay, amp)]"""
    out = np.zeros(int(SR * dur))
    for (o, f, q, d, a) in events:
        x = biquad(noise(d * 6), "bp", f, q) * env_exp(d * 6, d) * a
        out += at(x, o, dur)
    return out


def loop_drone(base, dur=2.0, buzz=0.3):
    t = t_axis(dur)
    x = np.zeros_like(t)
    for h, a in [(1, 1.0), (2, 0.5), (3, 0.3), (4, 0.2), (6, 0.1)]:
        x += np.sin(2 * math.pi * base * h * t + np.sin(2 * math.pi * 0.5 * t) * 0.3) * a
    x += biquad(noise(dur), "bp", base * 8, 1.0) * buzz
    return x


def heli_loop(dur=2.0):
    t = t_axis(dur)
    rate = 5.0
    chop = (0.5 + 0.5 * np.sin(2 * math.pi * rate * t)) ** 6
    blades = biquad(noise(dur), "lp", 500) * chop * 2.0
    engine = loop_drone(95, dur, 0.1) * 0.25
    whine = np.sin(2 * math.pi * 1450 * t) * 0.04
    return blades + engine + whine


def jet(dur=5.0):
    t = t_axis(dur)
    roar = biquad(noise(dur), "lp", 1200)
    env = np.exp(-((t - dur * 0.45) ** 2) / (2 * (dur * 0.15) ** 2))
    hiss = biquad(noise(dur), "hp", 4000) * 0.3
    return (roar + hiss) * env


def siren(dur=4.0):
    t = t_axis(dur)
    f = 600 + 250 * np.sin(2 * math.pi * 0.5 * t)
    x = np.sin(2 * math.pi * np.cumsum(f) / SR)
    return sat(x * 1.5, 2.0) * 0.6


def chord(freqs, dur, decay):
    return sum(tone(f, dur, decay) for f in freqs)


# --- Music ---------------------------------------------------------------------

def music_menu(dur=48.0):
    t = t_axis(dur)
    out = np.zeros_like(t)
    # Slow minor progression with detuned saw pads through a filter.
    prog = [(55.0, [1, 1.189, 1.498]), (43.65, [1, 1.26, 1.498]), (49.0, [1, 1.189, 1.498]), (41.2, [1, 1.26, 1.498])]
    bar = dur / len(prog) / 2
    for k in range(len(prog) * 2):
        root, ratios = prog[k % len(prog)]
        seg = t_axis(bar)
        pad_ = np.zeros_like(seg)
        for r in ratios:
            for oct_ in (2, 4):
                f = root * r * oct_
                pad_ += 2 * (seg * f * 1.003 - np.floor(0.5 + seg * f * 1.003)) + 2 * (seg * f - np.floor(0.5 + seg * f))
        pad_ = biquad(pad_, "lp", 900, 0.8) * env_adsr(bar, 1.5, 1.0, 0.8, 1.5) * 0.12
        bass = np.sin(2 * math.pi * root * seg) * env_adsr(bar, 0.3, 1.0, 0.7, 1.0) * 0.5
        out += at(pad_ + bass, k * bar, dur)
    # Heartbeat kick
    beat = 60.0 / 70.0
    k = 0.0
    while k < dur - 0.5:
        kick = sweep(0.4, 120, 40, 6) * env_exp(0.4, 0.12) * 0.6
        out += at(kick, k, dur)
        out += at(kick * 0.5, k + 0.28, dur)
        k += beat * 2
    return reverb(out, 2.5, 0.35, 2000)[: int(SR * dur)]


def music_match(dur=32.0):
    t = t_axis(dur)
    out = np.zeros_like(t)
    bpm = 110.0
    step = 60.0 / bpm / 4
    root = 41.2
    pattern = [1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0]
    n = int(dur / step)
    for i in range(n):
        o = i * step
        if pattern[i % 16]:
            out += at(sweep(0.25, 110, 45, 6) * env_exp(0.25, 0.08) * 0.5, o, dur)
        if i % 8 == 4:
            out += at(biquad(noise(0.2), "bp", 1800, 0.8) * env_exp(0.2, 0.05) * 0.3, o, dur)
        if i % 2 == 1:
            out += at(biquad(noise(0.05), "hp", 7000) * env_exp(0.05, 0.01) * 0.08, o, dur)
        if i % 4 == 0:
            f = root * (2 if (i // 16) % 4 != 3 else 2.378)
            seg = t_axis(step * 3)
            b = 2 * (seg * f - np.floor(0.5 + seg * f))
            out += at(biquad(b, "lp", 400) * env_exp(step * 3, step) * 0.3, o, dur)
    pad_ = np.zeros_like(t)
    for f in (82.4, 98.0, 123.5):
        pad_ += 2 * (t * f - np.floor(0.5 + t * f))
    out += biquad(pad_, "lp", 500) * 0.04 * (0.6 + 0.4 * np.sin(2 * math.pi * t / dur))
    return reverb(out, 1.2, 0.2, 3000)[: int(SR * dur)]


# --- Build -------------------------------------------------------------------

def main():
    print("Weapons")
    for kind in GUNS:
        for v in (1, 2, 3):
            write("gun_%s%s" % (kind, "" if v == 1 else "_%d" % v), gunshot(kind, v))
    for v in (1, 2):
        write("gun_suppressed%s" % ("" if v == 1 else "_2"), suppressed(v))
        write("gun_distant%s" % ("" if v == 1 else "_2"), distant(v))
    write("gun_tail", tail())
    write("gun_launcher", launcher())
    write("gun_heli", turret("heli"))
    write("gun_sentry", turret("sentry"))
    for cal in (25, 40, 105):
        write("gun_gunship_%d" % cal, gunship(cal))
    print("Foley")
    for v in range(1, 5):
        write("footstep%s" % ("" if v == 1 else "_%d" % v), footstep(v))
    for v in (1, 2, 3):
        write("impact_concrete%s" % ("" if v == 1 else "_%d" % v), impact("concrete", v))
        write("impact_metal%s" % ("" if v == 1 else "_%d" % v), impact("metal", v))
    write("explosion", explosion(False, 1))
    write("explosion_2", explosion(False, 2))
    write("explosion_big", explosion(True, 1))
    write("flashbang", flashbang())
    write("stun", mix(explosion(False, 3)[: int(SR * 1.2)] * 0.7, tone(5200, 1.2, 0.5) * 0.2))
    write("smoke", biquad(noise(2.5), "hp", 1500) * env_adsr(2.5, 0.05, 0.5, 0.6, 1.5))
    write("throw", biquad(noise(0.3), "bp", 900, 0.8) * env_adsr(0.3, 0.08, 0.1, 0.3, 0.1))
    write("place", mech_sequence([(0, 1200, 2, 0.01, 1.0), (0.12, 2400, 3, 0.008, 0.7)], 0.3))
    write("sticky", mech_sequence([(0, 600, 1.5, 0.02, 1.0), (0.05, 3000, 4, 0.005, 0.5)], 0.25))
    write("grenade_bounce", impact("metal", 2)[: int(SR * 0.2)] * 0.6)
    write("mine_trigger", mix(tone(2400, 0.3, 0.08, "square"), tone(3200, 0.3, 0.05, "square")))
    write("rocket_loop", biquad(noise(2.0), "bp", 1600, 0.6) * env_adsr(2.0, 0.02, 0.2, 0.8, 0.5))
    write("knife_swing", biquad(noise(0.3), "bp", 2500, 1.0) * env_adsr(0.3, 0.05, 0.1, 0.2, 0.12))
    write("knife_hit", at(biquad(noise(0.1), "lp", 900) * env_exp(0.1, 0.02), 0, 0.3) + at(click(3500, 0.04), 0, 0.3) * 0.5)
    write("reload_out", mech_sequence([(0, 2600, 3, 0.006, 1.0), (0.05, 1300, 2, 0.012, 0.8), (0.18, 900, 1.5, 0.02, 0.5)], 0.45))
    write("reload_in", mech_sequence([(0, 1600, 2, 0.01, 0.8), (0.07, 3000, 4, 0.005, 1.0), (0.25, 2200, 3, 0.008, 0.9), (0.31, 3600, 4, 0.004, 0.8)], 0.5))
    write("shell_in", mech_sequence([(0, 1800, 2, 0.01, 0.8), (0.05, 900, 1.2, 0.015, 0.6)], 0.2))
    write("ammo_pickup", mech_sequence([(0, 1500, 2, 0.01, 0.8), (0.08, 2000, 2, 0.01, 0.8)], 0.25))
    write("weapon_pickup", mech_sequence([(0, 1100, 1.5, 0.015, 0.8), (0.1, 2600, 3, 0.006, 1.0)], 0.3))
    write("hurt", mix(biquad(noise(0.25), "lp", 600) * env_exp(0.25, 0.06), sweep(0.25, 140, 60, 5) * env_exp(0.25, 0.05)))
    write("hurt_2", biquad(noise(0.25), "lp", 500) * env_exp(0.25, 0.05) + sweep(0.25, 120, 50, 5) * env_exp(0.25, 0.05))
    print("UI / feedback")
    write("hitmarker", at(click(3500, 0.03) * 1.0, 0, 0.08) + at(tone(2800, 0.06, 0.012), 0, 0.08) * 0.4)
    write("ui_click", mix(tone(1400, 0.08, 0.02) * 0.6, click(4000, 0.02) * 0.3))
    write("ui_hover", tone(2100, 0.05, 0.01) * 0.3)
    write("ui_tick", tone(1000, 0.08, 0.02, "square") * 0.4)
    write("match_start", chord([220, 277.2, 329.6], 1.6, 0.6) + at(tone(440, 1.0, 0.4), 0.25, 1.6))
    write("rank_up", sum(at(tone(f, 0.8, 0.3, "saw", 0.004), i * 0.11, 1.6) for i, f in enumerate([392, 523.3, 659.3, 784])))
    write("challenge", sum(at(tone(f, 0.5, 0.15), i * 0.08, 0.9) for i, f in enumerate([659.3, 880, 1046.5])))
    write("streak_ready", sum(at(tone(f, 0.6, 0.2, "square"), i * 0.1, 1.0) for i, f in enumerate([440, 660, 880])) * 0.6)
    write("capture_friendly", chord([392, 493.9, 587.3], 1.2, 0.4))
    write("capture_enemy", chord([311.1, 370, 466.2], 1.2, 0.4))
    write("victory", sum(at(chord([f, f * 1.26, f * 1.5], 1.8, 0.7), i * 0.35, 3.0) for i, f in enumerate([261.6, 329.6, 392])))
    write("defeat", sum(at(chord([f, f * 1.189, f * 1.5], 2.0, 0.8), i * 0.45, 3.2) for i, f in enumerate([220, 174.6, 146.8])))
    write("emp", mix(sweep(1.5, 3000, 40, 3) * env_exp(1.5, 0.5), biquad(noise(1.5), "hp", 3000) * env_exp(1.5, 0.3) * 0.3))
    write("doomsday_siren", siren())
    write("tag_pickup", sum(at(tone(f, 0.25, 0.08), i * 0.05, 0.4) for i, f in enumerate([1200, 1800])))
    write("crate_land", mix(explosion(False, 2)[: int(SR * 0.6)] * 0.4, at(impact("concrete", 1), 0, 0.6) * 0.6))
    write("crate_open", mech_sequence([(0, 700, 1.5, 0.02, 1.0), (0.15, 1200, 2, 0.015, 0.8), (0.3, 2500, 3, 0.008, 0.6)], 0.6))
    print("Vehicles")
    write("drone_loop", loop_drone(140, 2.0, 0.25))
    write("heli_loop", heli_loop(2.0))
    write("gunship_loop", loop_drone(62, 2.0, 0.15))
    write("jet_flyby", jet(5.0))
    print("Music")
    write("music_menu", music_menu(), 0.8)
    write("music_match", music_match(), 0.7)


if __name__ == "__main__":
    main()
