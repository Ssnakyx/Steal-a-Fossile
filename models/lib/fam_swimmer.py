"""Famille Swimmer (Mosasaurus, Plesiosaurus, Megalodon) : tous les états du GDD + Dive et Jump (saut hors de l'eau).

Os : Hips (racine, arrière du tronc), Chest, Neck1..N, Head, Jaw, LidL/R, FinF1/FinF2 L/R (nageoires avant),
FinB1/FinB2 L/R (nageoires arrière), Tail1..N (la dernière porte la nageoire de queue). Pas de pattes, pas d'IK.
La nage est une onde qui descend le corps (le bassin et la queue ondulent, la tête reste stable). Y = 0 est le fond
du bassin : le dino nage FLOAT hauteurs de hanche au-dessus (il se pose au fond pour dormir)."""
from __future__ import annotations

import math

from anim import PX, PY, PZ, RX, RY, RZ, Clip, P, bump, clamp, ease, ramp, shake, smooth, win
from motion import aim, blinks, curl, curve, fit_period, follow, jaw, lids, merge, tail_wave

FLOAT = 0.7


def new(rig, name, base, loop=False, nxt=None):
    return Clip(rig, name, rig.T(base), loop, nxt)


def fins(rig, kind):
    return [b for b in rig.sk.order if b.startswith(kind)]


def floating(c, k=1.0):
    c.add("Hips", PY, lambda t: FLOAT * c.rig.u * (k(t) if callable(k) else k))


def undulate(c, T, hips=3.0, tail=12.0, env=None, lag=0.11, phase=0.0):
    """Onde de nage : le bassin balance, le torse et la tête compensent, la queue amplifie avec du retard."""
    rig = c.rig
    e = env or (lambda t: 1.0)
    per = fit_period(c.length, T) if c.loop else T
    ph = lambda t: 2 * math.pi * (t / per - phase)  # noqa: E731
    c.add("Hips", RY, lambda t: hips * e(t) * math.sin(ph(t)))
    c.add("Chest", RY, lambda t: -0.7 * hips * e(t) * math.sin(ph(t) + 0.5))
    for i, b in enumerate(rig.neck):
        c.add(b, RY, lambda t, i=i: -0.25 * hips * e(t) * math.sin(ph(t) + 0.9 + 0.2 * i))
    c.add("Head", RY, lambda t: -0.3 * hips * e(t) * math.sin(ph(t) + 1.2))
    n = len(rig.tail)
    for i, b in enumerate(rig.tail):
        w = 0.45 + 0.55 * i / max(1, n - 1)
        c.add(b, RY, lambda t, i=i, w=w: tail * w * e(t) * math.sin(ph(t) - (i + 1) * 2 * math.pi * lag))


def paddle(c, T, amp=10.0, env=None, rear=0.6):
    """Nageoires : rame lente (avant) et petite correction (arrière), le bout suit avec du retard."""
    e = env or (lambda t: 1.0)
    per = fit_period(c.length, T) if c.loop else T
    for side, sgn in (("L", -1.0), ("R", 1.0)):
        for root, tip, k, off in (("FinF1", "FinF2", 1.0, 0.0), ("FinB1", "FinB2", rear, 0.5)):
            r, tp = root + side, tip + side
            c.add(r, RZ, lambda t, k=k, off=off, sgn=sgn: sgn * amp * k * e(t) * math.sin(2 * math.pi * (t / per - off)))
            c.add(r, RX, lambda t, k=k, off=off: 0.6 * amp * k * e(t) * math.sin(2 * math.pi * (t / per - off) + 1.2))
            c.add(tp, RZ, lambda t, k=k, off=off, sgn=sgn: sgn * 0.8 * amp * k * e(t) * math.sin(2 * math.pi * (t / per - off) - 0.9))


def fin_pose(spread=0.0, tuck=0.0):
    """Nageoires écartées (> 0, vers le haut) ou plaquées contre le corps (tuck > 0)."""
    out = {}
    for side, sgn in (("L", -1.0), ("R", 1.0)):
        out["FinF1" + side] = P(rz=sgn * (spread * 25 - tuck * 10), ry=-sgn * tuck * 35)
        out["FinB1" + side] = P(rz=sgn * spread * 15, ry=-sgn * tuck * 30)
    return out


def bob(c, T, amp):
    per = fit_period(c.length, T) if c.loop else T
    c.add("Hips", PY, lambda t: amp * c.rig.u * math.sin(2 * math.pi * t / per))
    c.add("Hips", RX, lambda t: 1.2 * math.sin(2 * math.pi * t / per + 0.8))


def tail_curl(rig, total):
    return curl(rig.tail, total, RY, 1.15)


# ====================================================================== parc
def idle(rig):
    c = new(rig, "Idle", 4.6, loop=True)
    L = c.length
    floating(c)
    undulate(c, L, 1.5, 6.0)
    paddle(c, L / 2, 9.0)
    bob(c, L, 0.05)
    yaw = curve([(0, 0), (0.2 * L, 0), (0.32 * L, 16), (0.48 * L, 14), (0.6 * L, -14), (0.75 * L, -12), (0.88 * L, 0), (L, 0)])
    pitch = curve([(0, 0), (0.32 * L, 4), (0.6 * L, -3), (0.88 * L, 0), (L, 0)])
    aim(c, yaw, pitch)
    jaw(c, curve([(0, 0), (0.4 * L, 0), (0.46 * L, 8), (0.56 * L, 0), (L, 0)]))
    blinks(c, [0.26 * L, 0.72 * L])
    return c


def idle_sniff(rig):
    c = new(rig, "IdleSniff", 2.8, nxt="Idle")
    L, u = c.length, rig.u
    a, b = 0.28 * L, 0.72 * L
    floating(c, lambda t: 1 - 0.35 * win(t, 0.05 * L, 0.95 * L, 0.3))
    c.key(0, {"Hips": P(rx=0), "Chest": P(rx=0)})
    c.key(a, {"Hips": P(rx=-9), "Chest": P(rx=-6)}, "inout")
    c.key(b, {"Hips": P(rx=-9), "Chest": P(rx=-6)})
    c.rest(L)
    aim(c, curve([(0, 0), (a, 8), (0.5 * L, -8), (b, 6), (L, 0)]), curve([(0, 0), (a, -14), (b, -12), (L, 0)]))
    c.add("Head", RX, lambda t: 3 * shake(t, a, b, 6.0))
    jaw(c, curve([(0, 0), (a, 6), (0.4 * L, 0), (0.5 * L, 8), (0.6 * L, 0), (b, 6), (L, 0)]))
    undulate(c, 1.4, 1.2, 5.0)
    paddle(c, 1.4, 7.0)
    blinks(c, [0.86 * L])
    return c


def idle_scratch(rig):
    """Se roule à moitié sur le côté pour se gratter le dos, nageoires qui battent."""
    c = new(rig, "IdleScratch", 3.0, nxt="Idle")
    L = c.length
    a, b = 0.3 * L, 0.68 * L
    floating(c)
    roll = curve([(0, 0), (a, 75, "inout"), (b, 70), (L, 0, "inout")])
    c.add("Hips", RZ, lambda t: roll.at(t))
    c.add("Hips", RZ, lambda t: 6 * shake(t, a, b, 3.0))
    undulate(c, 0.9, 2.0, 12.0, env=lambda t: win(t, 0.1 * L, 0.9 * L, 0.3))
    paddle(c, 0.6, 18.0, env=lambda t: win(t, a - 0.1 * L, b + 0.1 * L, 0.3))
    aim(c, curve([(0, 0), (a, 16), (b, 14), (L, 0)]), None)
    lids(c, lambda t: 0.7 * win(t, a, b, 0.25))
    return c


def idle_stretch(rig):
    c = new(rig, "IdleStretch", 3.2, nxt="Idle")
    L = c.length
    a, b, d = 0.3 * L, 0.62 * L, 0.84 * L
    floating(c)
    arch = merge({"Chest": P(rx=8), "Hips": P(rx=2)}, {t: {RX: -4} for t in rig.tail}, fin_pose(spread=1.0))
    c.key(0, {k: {ch: 0.0 for ch in v} for k, v in arch.items()})
    c.key(a, arch, "inout")
    c.key(b, arch)
    c.key(d, {k: {ch: 0.0 for ch in v} for k, v in arch.items()}, "inout")
    c.key(L, {k: {ch: 0.0 for ch in v} for k, v in arch.items()})
    aim(c, None, curve([(0, 0), (a, 18), (b, 20), (d, 0), (L, 0)]))
    jaw(c, curve([(0, 0), (a, 0), (0.42 * L, 38), (b, 34), (b + 0.06 * L, 0, "snap"), (L, 0)]))
    lids(c, lambda t: win(t, 0.36 * L, b + 0.02 * L, 0.2))
    c.add("Chest", RZ, lambda t: 4 * shake(t, d, L, 6.0, 3.0))
    undulate(c, 2.0, 1.0, 4.0)
    return c


def idle_shake(rig):
    c = new(rig, "IdleShake", 1.8, nxt="Idle")
    L = c.length
    a, b = 0.14 * L, 0.8 * L
    floating(c)
    sh = lambda t: shake(t, a, b, 6.0, 1.4)  # noqa: E731
    c.add("Head", RY, lambda t: 20 * sh(t))
    c.add("Head", RZ, lambda t: 10 * sh(t - 0.03))
    for nb in rig.neck:
        c.add(nb, RY, lambda t: 8 * sh(t - 0.02))
    c.add("Chest", RZ, lambda t: -6 * sh(t - 0.04))
    c.add("Hips", RZ, lambda t: 4 * sh(t - 0.06))
    follow(c, lambda t: 6 * sh(t), rig.tail, RY, [0.5, 0.7, 0.9, 1.1, 1.3, 1.4], 0.035)
    jaw(c, curve([(0, 0), (a, 10), (b, 6), (L, 0)]))
    lids(c, lambda t: 0.8 * win(t, a + 0.05, b - 0.1, 0.15))
    return c


def idle_yawn(rig):
    c = new(rig, "IdleYawn", 3.0, nxt="Idle")
    L = c.length
    a, b, d = 0.3 * L, 0.6 * L, 0.66 * L
    floating(c)
    aim(c, None, curve([(0, 0), (a, 20), (b, 22), (d + 0.05 * L, 2, "out"), (L, 0)]))
    jaw(c, curve([(0, 0), (0.1 * L, 0), (a, 48, "inout"), (b, 52), (d, 0, "snap"), (L, 0)]))
    c.add("Head", RZ, lambda t: 3 * shake(t, a, b, 7.0))
    c.add("Head", RY, lambda t: 8 * shake(t, d, d + 0.25 * L, 5.0, 2.0))
    lids(c, lambda t: win(t, 0.18 * L, b + 0.02 * L, 0.18))
    undulate(c, 2.0, 1.0, 4.0)
    paddle(c, 2.0, 5.0)
    blinks(c, [0.88 * L])
    return c


def swim(rig, name="Walk", base=1.7, fast=False):
    c = new(rig, name, base, loop=True)
    T = c.length
    floating(c)
    undulate(c, T, 5.0 if fast else 3.5, 22.0 if fast else 15.0)
    if fast:
        c.key(0, fin_pose(tuck=1.0))
        paddle(c, T, 4.0)
        c.key(0, {"Hips": P(rx=-3)})
    else:
        c.key(0, fin_pose(tuck=0.4))
        paddle(c, T, 10.0)
    bob(c, T / 2, 0.03)
    c.speed = rig.height * (2.2 if fast else 0.9)
    jaw(c, curve([(0, 6 if fast else 0), (T, 6 if fast else 0)]))
    blinks(c, [] if fast else [0.5 * T])
    c.event(0.0, "Stroke")
    return c


def happy(rig):
    """Tonneau joyeux : un tour complet sur lui-même, nageoires qui battent, mâchoire qui claque."""
    c = new(rig, "Happy", 1.8, nxt="Idle")
    L = c.length
    a, b = 0.18 * L, 0.7 * L
    floating(c, lambda t: 1 + 0.3 * bump(t, a, b))
    roll = curve([(0, 0), (a, 0), (b, 360, "inout"), (L, 360)])
    c.add("Hips", RZ, lambda t: roll.at(t))
    undulate(c, 0.5, 3.0, 16.0, env=lambda t: win(t, 0.05 * L, 0.95 * L, 0.2))
    paddle(c, 0.4, 22.0, env=lambda t: win(t, 0.05 * L, 0.95 * L, 0.2))
    jaw(c, curve([(0, 0), (a, 20), (a + 0.08 * L, 0, "snap"), (b, 0), (b + 0.08 * L, 24), (b + 0.16 * L, 0, "snap"), (L, 0)]))
    aim(c, None, curve([(0, 0), (a, 10), (b, 8), (L, 0)]))
    return c


def roar(rig):
    c = new(rig, "Roar", 2.4, nxt="Idle")
    L, u = c.length, rig.u
    a, b, h1, h2 = 0.24 * L, 0.34 * L, 0.7 * L, 0.86 * L
    floating(c, lambda t: 1 + 0.6 * win(t, a, h2, 0.2))
    pose = merge({"Hips": P(rx=10), "Chest": P(rx=10)}, fin_pose(spread=1.2))
    c.key(0, {k: {ch: 0.0 for ch in v} for k, v in pose.items()})
    c.key(a, {"Hips": P(rx=-4), "Chest": P(rx=-6)}, "inout")
    c.key(b, pose, "back")
    c.key(h1, pose)
    c.key(h2, {k: {ch: 0.0 for ch in v} for k, v in pose.items()}, "inout")
    c.key(L, {k: {ch: 0.0 for ch in v} for k, v in pose.items()})
    aim(c, None, curve([(0, 0), (a, -14), (b, 24, "back"), (h1, 20), (h2, 0), (L, 0)]))
    jaw(c, curve([(0, 0), (a, 4), (b, 50, "back"), (h1, 46), (h2, 0), (L, 0)]))
    c.add("Head", RY, lambda t: 3 * shake(t, b, h1, 12.0))
    c.add("Jaw", RX, lambda t: 3 * shake(t, b, h1, 15.0))
    tail_wave(c, 10, 0.5, RY, lag=0.05, env=lambda t: win(t, b, h1, 0.15))
    c.event(b, "Roar")
    return c


def eat(rig):
    """Fonce sur un poisson, gueule ouverte, la referme d'un coup sec, avale tête levée."""
    c = new(rig, "Eat", 2.6, nxt="Idle")
    L, u = c.length, rig.u
    open0, snap, back, gulp = 0.2 * L, 0.34 * L, 0.5 * L, 0.66 * L
    floating(c)
    c.add("Hips", PZ, lambda t: -0.8 * u * win(t, 0.1 * L, back + 0.1 * L, 0.4))
    undulate(c, 0.5, 4.0, 20.0, env=lambda t: win(t, 0.05 * L, snap + 0.05 * L, 0.3))
    jaw(c, curve([(0, 0), (open0, 44, "out"), (snap, 0, "snap"), (gulp - 0.04 * L, 0), (gulp, 10), (gulp + 0.06 * L, 0), (L, 0)]))
    aim(c, None, curve([(0, 0), (open0, 6), (snap, -4), (gulp, 20), (0.86 * L, 0), (L, 0)]))
    c.add("Head", RY, lambda t: 9 * shake(t, snap, back, 5.0, 3.0))
    for i, nb in enumerate(rig.neck + ["Chest"]):
        c.add(nb, RX, lambda t, i=i: 4 * bump(t, gulp - 0.04 * L + i * 0.05 * L, gulp + 0.1 * L + i * 0.05 * L))
    paddle(c, 0.6, 12.0)
    blinks(c, [0.84 * L])
    return c


def sleep_pose(rig):
    return merge({"Hips": P(py=-0.15 * rig.u, rz=5), "Chest": P(rx=-3)}, tail_curl(rig, -50), fin_pose(spread=-0.6),
                 {"Head": P(rx=-6, ry=10)})


def sleep(rig):
    c = new(rig, "Sleep", 5.0, loop=True)
    L = c.length
    sp = sleep_pose(rig)
    c.key(0, sp)
    c.key(L, sp)
    lids(c, lambda t: 1.0)
    c.add("Chest", PY, lambda t: 0.02 * rig.u * math.sin(4 * math.pi * t / L))
    c.add("Chest", RX, lambda t: 1.0 * math.sin(4 * math.pi * t / L))
    c.add("Jaw", RX, lambda t: -2.5 * max(0.0, math.sin(4 * math.pi * t / L - 1.2)))
    tail_wave(c, 3, L, RY, lag=0.15)
    return c


def spawn(rig):
    c = new(rig, "Spawn", 3.0, nxt="Idle")
    L, u = c.length, rig.u
    a, b, s0, s1, look, back = 0.08 * L, 0.3 * L, 0.32 * L, 0.6 * L, 0.68 * L, 0.9 * L
    floating(c, lambda t: ramp(t, a, b, "out"))
    curled = merge(tail_curl(rig, -110), {"Chest": P(ry=18, rx=-6)}, fin_pose(tuck=1.0), {"Head": P(rx=-14, ry=14)})
    c.key(0, curled)
    c.key(a, curled)
    c.rest(b, kind="back")
    c.rest(L)
    sh = lambda t: shake(t, s0, s1, 6.0, 3.0)  # noqa: E731
    c.add("Hips", RZ, lambda t: 10 * sh(t))
    c.add("Chest", RZ, lambda t: -7 * sh(t - 0.03))
    follow(c, lambda t: 10 * sh(t), rig.tail, RY, [0.6, 0.8, 1.0, 1.2, 1.3, 1.4], 0.03)
    aim(c, curve([(0, 0), (s1, 0), (look, 20, "inout"), (back, 18), (L, 0)]),
        curve([(0, 0), (b, 8, "back"), (s1, 4), (L, 0)]), curve([(0, 0), (s1, 0), (look, 10), (back, 8), (L, 0)]))
    lids(c, lambda t: 1.0 - ramp(t, a, b - 0.04 * L, "out2"))
    jaw(c, curve([(0, 0), (s0, 0), (s0 + 0.04 * L, 14), (s1, 8), (look, 0), (L, 0)]))
    blinks(c, [0.8 * L])
    return c


# ====================================================================== gardiens
def wake(rig):
    c = new(rig, "Wake", 2.0, nxt="Idle")
    L, u = c.length, rig.u
    jolt, up, sh0, sh1 = 0.12 * L, 0.5 * L, 0.54 * L, 0.86 * L
    sp = sleep_pose(rig)
    floating(c, lambda t: ramp(t, jolt, up, "out"))
    c.key(0, sp)
    c.key(jolt, merge(sp, {"Chest": P(rx=6)}), "snap")
    c.rest(up, kind="back")
    c.rest(L)
    lids(c, lambda t: 1.0 - ramp(t, 0.04 * L, jolt, "snap"))
    c.add("Head", RY, lambda t: 18 * shake(t, sh0, sh1, 5.5, 1.5))
    undulate(c, 0.7, 3.0, 14.0, env=lambda t: win(t, jolt, up + 0.1 * L, 0.3))
    jaw(c, curve([(0, 0), (jolt, 14, "snap"), (up, 0), (L, 0)]))
    return c


def catch(rig):
    """Coup de tête cartoon : se ramasse en S, fonce, cogne gueule fermée, recule."""
    c = new(rig, "Catch", 1.4, nxt="Idle")
    L, u = c.length, rig.u
    wind, hit, rec = 0.36 * L, 0.5 * L, 0.7 * L
    floating(c)
    c.add("Hips", PZ, lambda t: 0.25 * u * win(t, 0.05 * L, wind + 0.05 * L, 0.4) - 0.9 * u * win(t, wind, rec + 0.2 * L, 0.3))
    s_curve = merge({"Chest": P(ry=-14), "Hips": P(ry=6)}, {b: {RY: 10} for b in rig.tail[:3]})
    c.key(0, {k: {ch: 0.0 for ch in v} for k, v in s_curve.items()})
    c.key(wind, s_curve, "inout")
    c.key(hit, {k: {ch: 0.0 for ch in v} for k, v in s_curve.items()}, "snap")
    c.key(L, {k: {ch: 0.0 for ch in v} for k, v in s_curve.items()})
    undulate(c, 0.4, 5.0, 24.0, env=lambda t: win(t, wind - 0.05 * L, rec, 0.3))
    aim(c, None, curve([(0, 0), (wind, 10), (hit, -12, "snap"), (rec, 4, "back"), (L, 0)]))
    jaw(c, curve([(0, 0), (wind, 14), (hit - 0.05 * L, 0), (L, 0)]))
    c.add("Head", RZ, lambda t: 7 * shake(t, hit, rec + 0.1 * L, 8.0, 3.0))
    c.event(hit, "Hit")
    return c


def search(rig):
    c = new(rig, "Search", 4.8, loop=True)
    L = c.length
    floating(c)
    undulate(c, L / 2, 2.0, 9.0)
    paddle(c, L / 3, 10.0)
    yaw = curve([(0, 0), (0.15 * L, 0), (0.25 * L, 40, "inout"), (0.42 * L, 36), (0.52 * L, -38, "inout"), (0.7 * L, -34),
                 (0.8 * L, 0, "inout"), (L, 0)])
    aim(c, yaw, curve([(0, -8), (0.15 * L, -8), (0.25 * L, 4), (0.8 * L, 2), (L, -8)]))
    c.add("Hips", RY, lambda t: 0.3 * yaw.at(t))
    c.add("Head", RX, lambda t: 3 * shake(t, 0.0, 0.12 * L, 6.0) + 3 * shake(t, 0.88 * L, L, 6.0))
    blinks(c, [0.47 * L, 0.74 * L])
    return c


def back_to_sleep(rig):
    c = new(rig, "BackToSleep", 3.6, nxt="Sleep")
    L = c.length
    turn0, turn1, down, close = 0.05 * L, 0.6 * L, 0.88 * L, 0.92 * L
    sp = sleep_pose(rig)
    k = curve([(0, 0), (turn1, 0), (down, 1, "inout"), (L, 1)])
    floating(c, lambda t: 1 - k.at(t))
    for bone, chans in sp.items():
        for ch, v in chans.items():
            c.add(bone, ch, lambda t, v=v: v * k.at(t))
    spin = curve([(0, 0), (turn0, 0), (turn1, 360, "inout"), (L, 360)])
    c.add("Hips", RY, lambda t: spin.at(t))
    undulate(c, 0.8, 3.0, 14.0, env=lambda t: win(t, turn0, turn1 + 0.1 * L, 0.2))
    lids(c, lambda t: ramp(t, close - 0.08 * L, L - 0.02 * L, "inout"))
    jaw(c, curve([(0, 0), (turn1 + 0.04 * L, 0), (turn1 + 0.12 * L, 30), (down, 0), (L, 0)]))
    return c


def fusion(rig):
    c = new(rig, "Fusion", 1.2, loop=True)
    L = c.length
    floating(c, 1.2)
    undulate(c, L / 2, 6.0, 26.0)
    paddle(c, L / 3, 28.0)
    c.add("Hips", RZ, lambda t: 20 * math.sin(2 * math.pi * t / L))
    aim(c, curve([(0, 0), (0.25 * L, 26), (0.5 * L, -24), (0.75 * L, 22), (L, 0)]), curve([(0, 8), (0.5 * L, 16), (L, 8)]))
    jaw(c, curve([(0, 26), (0.5 * L, 36), (L, 26)]))
    return c


def index_pose(rig):
    c = new(rig, "Index", 4.6, loop=True)
    L = c.length
    floating(c)
    s = merge({"Chest": P(ry=8, rx=4), "Hips": P(ry=-5)}, {b: {RY: 5} for b in rig.tail}, fin_pose(spread=0.8))
    c.key(0, s)
    c.key(L, s)
    aim(c, curve([(0, 16), (0.45 * L, 16), (0.55 * L, 10), (0.62 * L, 20, "back"), (L, 16)]),
        curve([(0, 10), (0.45 * L, 10), (0.55 * L, 20, "snap"), (0.66 * L, 8, "back"), (L, 10)]))
    jaw(c, curve([(0, 6), (0.53 * L, 6), (0.58 * L, 26, "snap"), (0.68 * L, 6), (L, 6)]))
    undulate(c, L / 2, 1.0, 4.0)
    paddle(c, L / 2, 6.0)
    blinks(c, [0.3 * L, 0.82 * L])
    return c


# ====================================================================== plongée et saut
def dive(rig):
    c = new(rig, "Dive", 1.8, nxt="Walk")
    L, u = c.length, rig.u
    floating(c, lambda t: 1 - 0.9 * win(t, 0.1 * L, 0.95 * L, 0.35))
    c.key(0, {"Hips": P(rx=0)})
    c.key(0.3 * L, {"Hips": P(rx=-30)}, "inout")
    c.key(0.7 * L, {"Hips": P(rx=-24)})
    c.key(L, {"Hips": P(rx=0)}, "inout")
    c.add("Hips", PZ, lambda t: -1.2 * u * ramp(t, 0.1 * L, L))
    undulate(c, 0.55, 5.0, 24.0)
    c.key(0, fin_pose(tuck=0.0))
    c.key(0.3 * L, fin_pose(tuck=1.0))
    c.key(0.8 * L, fin_pose(tuck=1.0))
    c.key(L, fin_pose(tuck=0.4))
    aim(c, None, curve([(0, 0), (0.3 * L, 8), (0.8 * L, 6), (L, 0)]))
    return c


def jump(rig):
    """Saut hors de l'eau : accélère, jaillit nez en l'air, fait l'arc, retombe nez en bas dans une gerbe."""
    c = new(rig, "Jump", 2.2, nxt="Walk")
    L, u = c.length, rig.u
    acc, out, top, splash = 0.24 * L, 0.36 * L, 0.56 * L, 0.78 * L
    h = 0.9 * rig.model["size"][2]
    lift = curve([(0, 0), (acc, -0.2 * u), (out, 0.35 * h, "in2"), (top, h, "out2"), (splash, 0.1 * h, "in2"), (L, 0, "out")])
    floating(c)
    c.add("Hips", PY, lambda t: lift.at(t))
    pitch = curve([(0, 0), (acc, 8), (out, 52, "out"), (top, 8), (splash, -52, "in2"), (L, 0, "out")])
    c.add("Hips", RX, lambda t: pitch.at(t))
    c.add("Hips", PZ, lambda t: -0.8 * u * ramp(t, 0, L))
    undulate(c, 0.45, 5.0, 26.0, env=lambda t: win(t, 0, out + 0.04 * L, 0.2))
    undulate(c, 0.45, 3.0, 14.0, env=lambda t: win(t, splash - 0.04 * L, L, 0.3))
    for b in rig.tail:
        c.add(b, RX, lambda t: -6 * win(t, out, splash, 0.3))
    c.key(0, fin_pose(tuck=0.4))
    c.key(acc, fin_pose(tuck=1.0))
    c.key(top, fin_pose(spread=1.2))
    c.key(splash, fin_pose(tuck=1.0))
    c.key(L, fin_pose(tuck=0.4))
    jaw(c, curve([(0, 0), (out, 20), (top, 30), (splash, 0), (L, 0)]))
    c.event(round(out, 3), "Splash")
    c.event(round(splash, 3), "Splash")
    return c


def build(rig):
    clips = [idle(rig), idle_sniff(rig), idle_scratch(rig), idle_stretch(rig), idle_shake(rig), idle_yawn(rig),
             swim(rig), swim(rig, "Run", 0.85, fast=True), happy(rig), roar(rig), eat(rig), sleep(rig), spawn(rig),
             wake(rig), catch(rig), search(rig), back_to_sleep(rig), fusion(rig), index_pose(rig), dive(rig), jump(rig)]
    return {c.name: c for c in clips}
