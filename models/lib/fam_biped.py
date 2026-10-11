"""Famille Biped (Velociraptor, T-Rex, Compy, Carnotaurus...) : tous les états du GDD.

Os attendus : Hips, Chest, Neck1..N, Head, Jaw, LidL/R, Arm/Forearm L/R, Thigh/Shin/Foot L/R, Tail1..N, et les
points ToeL/ToeR. Les pattes sont en IK (pieds posés au sol tant qu'un état ne les lève pas).
Personnalité (PERSONALITY de l'espèce) : tempo, weight, stride, bob, headBob, tail, diet, happy, catch."""
from __future__ import annotations

import math

from anim import PX, PY, PZ, RX, RY, RZ, Clip, P, bump, clamp, ease, ramp, shake, smooth, win
from motion import (aim, airborne, airborne_multi, blinks, breathe, curl, curve, fit_period, fold_legs, follow, gait,
                    jaw, lids, merge, tail_lift, tail_wave)

L_SIDE = ("L", -1.0)
R_SIDE = ("R", 1.0)


def new(rig, name, base, loop=False, nxt=None):
    return Clip(rig, name, rig.T(base), loop, nxt)


def arms(rig):
    return [b for b in ("ArmL", "ArmR", "ForearmL", "ForearmR") if b in rig.has]


def sleep_pose(rig):
    """Couché sur le ventre, tête posée sur le côté gauche, queue enroulée du même côté, yeux fermés."""
    u = rig.u
    pose = {
        "Hips": P(py=-0.62 * u, rx=3, rz=7),
        "Chest": P(rx=-5, rz=-3),
        "ArmL": P(rx=-25), "ArmR": P(rx=-25), "ForearmL": P(rx=40), "ForearmR": P(rx=40),
    }
    neck = rig.neck
    if len(neck) >= 2:
        pose[neck[0]] = P(rx=-22, ry=30)
        pose[neck[1]] = P(rx=-12, ry=22)
    elif neck:
        pose[neck[0]] = P(rx=-30, ry=45)
    pose["Head"] = P(rx=-6, ry=14, rz=12)
    pose = merge(pose, curl(rig.tail, -95, RY, 1.25), tail_lift(rig, -6))
    return pose


def idle_life(c, breath=1.0, tail=1.0, sway=1.0):
    """Vie de base : souffle, poids qui bascule doucement, queue qui ondule."""
    rig, L, u = c.rig, c.length, c.rig.u
    breathe(c, L / 2 if c.loop else 1.6, breath)
    per = fit_period(L, L) if c.loop else 3.0
    c.add("Hips", PX, lambda t: 0.025 * u * sway * math.sin(2 * math.pi * t / per))
    c.add("Hips", RZ, lambda t: 1.1 * sway * math.sin(2 * math.pi * t / per))
    tail_wave(c, 5.0 * tail * rig.P["tail"], L if c.loop else 2.4, RY, lag=0.12)
    tail_wave(c, 2.0 * tail, (L / 2) if c.loop else 1.2, RX, lag=0.1)


# ====================================================================== états du parc
def idle(rig):
    c = new(rig, "Idle", 4.0, loop=True)
    L = c.length
    idle_life(c)
    nerv = rig.P["headBob"] > 0.5
    k = "snap" if nerv else "inout"
    yaw = curve([(0, 0), (0.17 * L, 0), (0.23 * L, 26, k), (0.44 * L, 24), (0.5 * L, -20, k), (0.69 * L, -18),
                 (0.78 * L, 0, "inout"), (L, 0)])
    pitch = curve([(0, 0), (0.23 * L, 5, k), (0.44 * L, 4), (0.5 * L, -4, k), (0.69 * L, -3), (0.78 * L, 0), (L, 0)])
    roll = curve([(0, 0), (0.25 * L, 8, k), (0.44 * L, 7), (0.52 * L, -5, k), (0.69 * L, -5), (0.8 * L, 0), (L, 0)])
    aim(c, yaw, pitch, roll)
    blinks(c, [0.36 * L, 0.88 * L])
    for b, s in (("ArmL", 1), ("ArmR", -1)):
        c.add(b, RX, lambda t, s=s: 3 * math.sin(2 * math.pi * (t / (L / 2)) + s * 0.6))
    return c


def idle_sniff(rig):
    c = new(rig, "IdleSniff", 2.6, nxt="Idle")
    L, u = c.length, rig.u
    a, b = 0.28 * L, 0.72 * L
    c.key(0, {"Hips": P(rx=0, py=0), "Chest": P(rx=0)})
    c.key(a, {"Hips": P(rx=-6, py=-0.08 * u), "Chest": P(rx=-8)}, "inout")
    c.key(b, {"Hips": P(rx=-6, py=-0.08 * u), "Chest": P(rx=-8)})
    c.rest(L)
    pitch = curve([(0, 0), (a, -38), (b, -36), (L, 0)])
    yaw = curve([(0, 0), (a, 6), (0.5 * L, -8), (b, 4), (L, 0)])
    aim(c, yaw, pitch)
    # reniflements : petits coups de tête rapides
    c.add("Head", RX, lambda t: 3.5 * shake(t, a + 0.05 * L, b, 7.0))
    c.add("Jaw", RX, lambda t: -2.5 * max(0.0, shake(t, a + 0.05 * L, b, 7.0)))
    c.key(0, tail_lift(rig, 0))
    c.key(a, tail_lift(rig, 10))
    c.key(b, tail_lift(rig, 10))
    c.key(L, tail_lift(rig, 0))
    tail_wave(c, 4, 1.2, RY, lag=0.1)
    breathe(c, 1.3, 0.8)
    blinks(c, [0.86 * L])
    return c


def idle_scratch(rig):
    """Se gratte le cou avec une patte arrière, comme un oiseau, en tenant sur l'autre patte."""
    c = new(rig, "IdleScratch", 2.9, nxt="Idle")
    L, u = c.length, rig.u
    t1, t2, t3, t4 = 0.16 * L, 0.3 * L, 0.68 * L, 0.82 * L
    c.key(0, {"Hips": P(px=0, rz=0, rx=0, py=0), "Chest": P(rx=0)})
    c.key(t1, {"Hips": P(px=0.14 * u, rz=-7, rx=-3, py=-0.05 * u), "Chest": P(rx=-6)}, "inout")
    c.key(t3, {"Hips": P(px=0.14 * u, rz=-7, rx=-3, py=-0.05 * u), "Chest": P(rx=-6)})
    c.rest(t4 + 0.08 * L)
    c.rest(L)
    pitch = curve([(0, 0), (t2, -28), (t3, -28), (t4, 0)])
    yaw = curve([(0, 0), (t2, 28), (t3, 26), (t4, 0)])
    roll = curve([(0, 0), (t2, -22), (t3, -22), (t4, 0)])
    aim(c, yaw, pitch, roll)
    c.add("Head", RZ, lambda t: 5 * shake(t, t2, t3, 7.5))
    dr = c.drive("LegL")
    if dr:
        l = dr.limb
        x0, y0, z0 = l.toe0
        lift = curve([(0, 0), (t1, 0), (t2, 1, "out"), (t3, 1), (t4, 0, "in2"), (L, 0)])

        def toe(t):
            k = lift.at(t)
            scr = shake(t, t2, t3, 7.5)
            return (x0 - 0.05 * u * k, y0 + (0.55 * u + 0.05 * u * scr) * k, z0 - (0.55 * u + 0.06 * u * scr) * k)
        dr.toe = toe
        dr.tilt = lambda t: -55 * lift.at(t)
    c.key(0, tail_lift(rig, 0))
    c.key(t2, tail_lift(rig, 8))
    c.key(t3, tail_lift(rig, 8))
    c.key(L, tail_lift(rig, 0))
    tail_wave(c, 6, 0.9, RY, lag=0.08, env=lambda t: win(t, t2, t3, 0.2))
    blinks(c, [0.45 * L, 0.6 * L])
    return c


def idle_stretch(rig):
    c = new(rig, "IdleStretch", 3.2, nxt="Idle")
    L, u = c.length, rig.u
    a, b, d, e = 0.22 * L, 0.45 * L, 0.62 * L, 0.82 * L
    c.key(0, {"Hips": P(rx=0, py=0, pz=0), "Chest": P(rx=0), "ArmL": P(rx=0), "ArmR": P(rx=0)})
    # étirement vers l'avant : poitrine basse, cou tendu, queue haute
    c.key(a, {"Hips": P(rx=-10, py=-0.14 * u, pz=0.1 * u), "Chest": P(rx=-10), "ArmL": P(rx=35), "ArmR": P(rx=35)}, "inout")
    c.key(b, {"Hips": P(rx=-11, py=-0.15 * u, pz=0.12 * u), "Chest": P(rx=-11), "ArmL": P(rx=38), "ArmR": P(rx=38)})
    # puis dos cambré, tête haute
    c.key(d, {"Hips": P(rx=5, py=0.02 * u, pz=0), "Chest": P(rx=9), "ArmL": P(rx=-10), "ArmR": P(rx=-10)}, "inout")
    c.key(e, {"Hips": P(rx=4, py=0.01 * u, pz=0), "Chest": P(rx=8), "ArmL": P(rx=-8), "ArmR": P(rx=-8)})
    c.rest(L)
    pitch = curve([(0, 0), (a, 6), (b, 8), (d, 30), (e, 26), (L, 0)])
    aim(c, None, pitch)
    if rig.neck:
        c.add(rig.neck[0], RX, lambda t: -14 * win(t, 0.05 * L, b + 0.05 * L, 0.35))
    c.key(0, tail_lift(rig, 0))
    c.key(a, tail_lift(rig, 16))
    c.key(b, tail_lift(rig, 18))
    c.key(d, tail_lift(rig, -6))
    c.key(e, tail_lift(rig, -5))
    c.key(L, tail_lift(rig, 0))
    j = curve([(0, 0), (d - 0.05 * L, 0), (d + 0.03 * L, 34), (e, 30), (e + 0.06 * L, 0, "snap"), (L, 0)])
    jaw(c, j)
    lids(c, lambda t: win(t, d - 0.04 * L, e + 0.04 * L, 0.2))
    c.add("Head", RZ, lambda t: 4 * shake(t, d, e, 9.0))
    breathe(c, 1.5, 0.6)
    return c


def idle_shake(rig):
    c = new(rig, "IdleShake", 1.8, nxt="Idle")
    L = c.length
    a, b = 0.14 * L, 0.78 * L
    pitch = curve([(0, 0), (a, -6), (b, -4), (L, 0)])
    aim(c, None, pitch)
    sp = {rig.neck[0]: 0.3, "Head": 1.0} if rig.neck else {"Head": 1.0}
    if len(rig.neck) > 1:
        sp[rig.neck[1]] = 0.55
    for bone, k in sp.items():
        c.add(bone, RY, lambda t, k=k: 26 * k * shake(t, a, b, 6.5, 1.2))
        c.add(bone, RZ, lambda t, k=k: 10 * k * shake(t - 0.03, a, b, 6.5, 1.2))
    c.add("Chest", RY, lambda t: -4 * shake(t - 0.02, a, b, 6.5, 1.2))
    c.add("Hips", RZ, lambda t: 2.5 * shake(t - 0.04, a, b, 6.5, 1.2))
    jaw(c, curve([(0, 0), (a, 10), (b, 6), (L, 0)]))
    follow(c, lambda t: 6 * shake(t, a, b, 6.5, 1.2), rig.tail, RY, [0.5, 0.7, 0.9, 1.1, 1.3, 1.4], 0.035)
    lids(c, lambda t: 0.8 * win(t, a + 0.05, b - 0.1, 0.15))
    breathe(c, 1.0, 0.6)
    return c


def idle_yawn(rig):
    c = new(rig, "IdleYawn", 2.9, nxt="Idle")
    L = c.length
    a, b, d = 0.3 * L, 0.58 * L, 0.64 * L
    c.key(0, {"Chest": P(rx=0), "ArmL": P(rz=0), "ArmR": P(rz=0)})
    c.key(a, {"Chest": P(rx=7), "ArmL": P(rz=-18), "ArmR": P(rz=18)}, "inout")
    c.key(b, {"Chest": P(rx=8), "ArmL": P(rz=-20), "ArmR": P(rz=20)})
    c.rest(L)
    pitch = curve([(0, 0), (a, 30), (b, 32), (d + 0.05 * L, 4, "out"), (L, 0)])
    aim(c, None, pitch)
    jaw(c, curve([(0, 0), (0.1 * L, 0), (a, 50, "inout"), (b, 54), (d, 0, "snap"), (L, 0)]))
    c.add("Head", RZ, lambda t: 3 * shake(t, a, b, 8.0))
    c.add("Head", RY, lambda t: 9 * shake(t, d, d + 0.25 * L, 6.0, 2.0))
    lids(c, lambda t: max(win(t, 0.18 * L, b + 0.02 * L, 0.18), 0.0))
    blinks(c, [0.86 * L])
    tail_wave(c, 5, 1.4, RY, lag=0.1)
    c.key(0, tail_lift(rig, 0))
    c.key(a, tail_lift(rig, -5))
    c.key(b, tail_lift(rig, -5))
    c.key(L, tail_lift(rig, 0))
    return c


def walk(rig, name="Walk", base=1.0, run=False):
    c = new(rig, name, base, loop=True)
    T, u, Pp = c.length, rig.u, rig.P
    if run:
        S, beta, lift, heel, curl_d = 2.7 * u * Pp["stride"], 0.38, 0.3 * u, 22, 38
    else:
        S, beta, lift, heel, curl_d = 1.45 * u * Pp["stride"], 0.6, 0.18 * u, 16, 26
    c.speed = S / T
    gait(c, {"LegL": 0.0, "LegR": 0.5}, T, S, beta, lift, heel, curl_d)
    c.event(0.0, "Step", "FootL")
    c.event(round(T / 2, 3), "Step", "FootR")
    w = rig.weight
    bob = (0.08 if run else 0.045) * u * Pp["bob"] * (0.8 + 0.3 * w)
    two = lambda t, ph=0.0: math.cos(2 * math.pi * (2 * t / T - ph))  # noqa: E731
    one = lambda t, ph=0.0: math.cos(2 * math.pi * (t / T - ph))  # noqa: E731
    if run:
        c.key(0, {"Hips": P(rx=-11, py=-0.07 * u), "Chest": P(rx=3)})
        c.add("Hips", PY, lambda t: -bob * two(t, beta / 2))
    else:
        c.key(0, {"Hips": P(rx=-3), "Chest": P(rx=1)})
        c.add("Hips", PY, lambda t: -bob * two(t, 0.12))
    c.add("Hips", RX, lambda t: (1.6 if run else 1.0) * two(t, 0.2))
    roll = 2.6 if not run else 3.2
    c.add("Hips", RZ, lambda t: roll * one(t, beta / 2))
    c.add("Hips", PX, lambda t: -(0.035 if not run else 0.02) * u * one(t, beta / 2))
    yaw = 4.5 if not run else 6.0
    hips_yaw = lambda t: -yaw * one(t)  # noqa: E731
    c.add("Hips", RY, hips_yaw)
    c.add("Chest", RY, lambda t: 0.75 * yaw * one(t, 0.03))
    c.add("Chest", RZ, lambda t: -0.6 * roll * one(t, beta / 2 + 0.03))
    # cou et tête : la tête reste stable (compense le rebond), petit coup de tête d'oiseau
    nk = rig.neck
    if run:
        if nk:
            c.key(0, {nk[0]: P(rx=-16)})
        if len(nk) > 1:
            c.key(0, {nk[1]: P(rx=4)})
        c.key(0, {"Head": P(rx=18)})
        jaw(c, curve([(0, 14), (T, 14)]))
    else:
        if nk:
            c.key(0, {nk[0]: P(rx=2)})
        c.key(0, {"Head": P(rx=1)})
    stab = (5.0 if run else 3.0)
    if nk:
        c.add(nk[0], RX, lambda t: stab * two(t, 0.12 if not run else beta / 2))
    c.add("Head", RX, lambda t: -stab * two(t, 0.12 if not run else beta / 2) - (1.6 if run else 1.0) * two(t, 0.2))
    c.add("Head", RY, lambda t: -0.8 * hips_yaw(t) - 0.75 * 0.75 * yaw * one(t, 0.03))
    hb = Pp["headBob"] * (5.0 if not run else 2.0)
    if hb and len(nk) > 1:
        def saw(t):
            q = (2 * t / T) % 1.0
            return (q / 0.72) if q < 0.72 else (1 - (q - 0.72) / 0.28)
        c.add(nk[1], RX, lambda t: hb * (saw(t) - 0.5))
        c.add("Head", RX, lambda t: -hb * (saw(t) - 0.5))
    # queue : suit le bassin avec du retard, rebondit
    tl = rig.tail
    if run:
        c.key(0, tail_lift(rig, -4))
    follow(c, hips_yaw, tl, RY, [-0.6, -0.8, -1.0, -1.2, -1.4, -1.5], T * 0.07)
    follow(c, lambda t: (2.5 if not run else 4.0) * Pp["tail"] * two(t, 0.12), tl, RX, [0.6, 0.8, 1.0, 1.2, 1.3, 1.4], T * 0.05)
    # bras
    for b, s in (("ArmL", 1), ("ArmR", -1)):
        if run:
            c.key(0, {b: P(rx=-18)})
        c.add(b, RX, lambda t, s=s: s * (5 if not run else 8) * math.sin(2 * math.pi * t / T))
    for b, s in (("ForearmL", 1), ("ForearmR", -1)):
        if run:
            c.key(0, {b: P(rx=34)})
        c.add(b, RX, lambda t, s=s: s * 4 * math.sin(2 * math.pi * t / T - 0.8))
    blinks(c, [0.55 * T] if not run else [])
    return c


def happy(rig):
    """Petit saut de joie : accroupi, saut avec un tour complet, réception, petit rebond et queue qui frétille."""
    c = new(rig, "Happy", 1.5, nxt="Idle")
    L, u = c.length, rig.u
    a, up, top, land, sq, hop, land2 = 0.13 * L, 0.2 * L, 0.33 * L, 0.5 * L, 0.56 * L, 0.68 * L, 0.78 * L
    w = rig.weight
    hgt = 0.42 * u / max(0.6, w)
    c.key(0, {"Hips": P(py=0, rx=0, ry=0)})
    c.key(a, {"Hips": P(py=-0.16 * u, rx=4)}, "inout")
    c.key(up, {"Hips": P(py=0.02 * u, rx=-4)}, "out2")
    c.key(top, {"Hips": P(py=hgt, rx=-2)}, "out2")
    c.key(land, {"Hips": P(py=0.0, rx=2)}, "in2")
    c.key(sq, {"Hips": P(py=-0.13 * u, rx=4)}, "out2")
    c.key(hop, {"Hips": P(py=0.16 * u / max(0.6, w), rx=-2)}, "out2")
    c.key(land2, {"Hips": P(py=-0.06 * u, rx=2)}, "in2")
    c.rest(L)
    # tour complet pendant le grand saut
    spin = curve([(0, 0), (up, 0), (land - 0.02 * L, 360, "inout"), (L, 360)])
    if rig.P["happy"] == "hop":
        c.add("Hips", RY, lambda t: spin.at(t))
    airborne_multi(c, [(up, land), (hop - 0.06 * L, land2)], tuck=lambda t: (0, 0.12 * u, -0.05 * u))
    pitch = curve([(0, 0), (a, 14), (top, 8), (land, -6), (sq, -4), (hop, 10), (L, 0)])
    aim(c, None, pitch)
    c.add("Head", RZ, lambda t: 12 * shake(t, land2 - 0.1 * L, L, 7.0, 1.5))
    jaw(c, curve([(0, 0), (a, 0), (top, 26), (land, 10), (hop, 24), (land2, 18), (L, 0)]))
    for b, s in (("ArmL", -1), ("ArmR", 1)):
        c.add(b, RZ, lambda t, s=s: s * 22 * win(t, up, land2, 0.2) + s * 8 * shake(t, up, land2, 6.0))
    c.key(0, tail_lift(rig, 0))
    c.key(a, tail_lift(rig, -8))
    c.key(top, tail_lift(rig, 14))
    c.key(sq, tail_lift(rig, -6))
    c.key(L, tail_lift(rig, 0))
    tail_wave(c, 16 * rig.P["tail"], 0.28, RY, lag=0.04, env=lambda t: win(t, land, L, 0.2))
    return c


def roar(rig):
    c = new(rig, "Roar", 2.2, nxt="Idle")
    L, u = c.length, rig.u
    a, b, h1, h2 = 0.25 * L, 0.33 * L, 0.68 * L, 0.84 * L
    c.key(0, {"Hips": P(py=0, rx=0, pz=0), "Chest": P(rx=0)})
    c.key(a, {"Hips": P(py=-0.1 * u, rx=4, pz=0.06 * u), "Chest": P(rx=-6)}, "inout")
    c.key(b, {"Hips": P(py=-0.04 * u, rx=-4, pz=-0.06 * u), "Chest": P(rx=10)}, "out")
    c.key(h1, {"Hips": P(py=-0.05 * u, rx=-3, pz=-0.05 * u), "Chest": P(rx=9)})
    c.rest(h2)
    c.rest(L)
    pitch = curve([(0, 0), (a, -20), (b, 34, "back"), (h1, 30), (h2, 2), (L, 0)])
    aim(c, None, pitch)
    if rig.neck:
        c.add(rig.neck[0], RX, lambda t: -12 * win(t, 0.05 * L, b + 0.04 * L, 0.4))
    jaw(c, curve([(0, 0), (a, 4), (b, 48, "back"), (h1, 44), (h2, 0, "inout"), (L, 0)]))
    c.add("Head", RY, lambda t: 2.5 * shake(t, b, h1, 13.0))
    c.add("Head", RZ, lambda t: 2.0 * shake(t - 0.02, b, h1, 11.0))
    c.add("Jaw", RX, lambda t: 3.0 * shake(t, b, h1, 15.0))
    c.add("Chest", RZ, lambda t: 1.0 * shake(t, b, h1, 12.0))
    for bone, s in (("ArmL", -1), ("ArmR", 1)):
        c.key(0, {bone: P(rz=0, rx=0)})
        c.key(a, {bone: P(rz=s * 6, rx=-10)})
        c.key(b, {bone: P(rz=s * 28, rx=20)}, "back")
        c.key(h1, {bone: P(rz=s * 26, rx=18)})
        c.key(h2, {bone: P(rz=0, rx=0)})
    c.key(0, tail_lift(rig, 0))
    c.key(a, tail_lift(rig, -10))
    c.key(b, tail_lift(rig, 16), "back")
    c.key(h1, tail_lift(rig, 14))
    c.key(L, tail_lift(rig, 0))
    tail_wave(c, 7, 0.35, RY, lag=0.05, env=lambda t: win(t, b, h1, 0.15))
    c.event(b, "Roar")
    lids(c, lambda t: 0.0)
    return c


def eat(rig):
    c = new(rig, "Eat", 3.4, nxt="Idle")
    L, u = c.length, rig.u
    meat = rig.P["diet"] == "meat"
    down, bite, tug, up, chew_end, gulp = 0.15 * L, 0.22 * L, 0.4 * L, 0.48 * L, 0.74 * L, 0.84 * L
    c.key(0, {"Hips": P(rx=0, py=0, pz=0), "Chest": P(rx=0)})
    c.key(down, {"Hips": P(rx=-8, py=-0.12 * u, pz=0.04 * u), "Chest": P(rx=-10)}, "inout")
    c.key(bite, {"Hips": P(rx=-9, py=-0.13 * u, pz=0.02 * u), "Chest": P(rx=-11)})
    if meat:
        c.key(tug, {"Hips": P(rx=-2, py=-0.06 * u, pz=0.14 * u), "Chest": P(rx=-3)}, "inout")
    else:
        c.key(tug, {"Hips": P(rx=-8, py=-0.12 * u, pz=0.04 * u), "Chest": P(rx=-10)})
    c.key(up, {"Hips": P(rx=0, py=0, pz=0), "Chest": P(rx=2)}, "inout")
    c.rest(L)
    pitch = curve([(0, 0), (down, -42), (bite, -46), (tug, -20 if meat else -40), (up, 8), (chew_end, 8), (gulp, 20),
                   (L, 0)])
    aim(c, None, pitch)
    if meat:
        # tire sur le morceau : la tête tire en arrière en secouant
        c.add("Head", RY, lambda t: 12 * shake(t, bite + 0.02 * L, tug, 4.5))
        c.add("Chest", RY, lambda t: -3 * shake(t, bite + 0.02 * L, tug, 4.5))
        j = [(0, 0), (down - 0.04 * L, 28), (bite, 0, "snap"), (tug, 0), (up, 0)]
    else:
        # broute : trois coups de dents au ras du sol
        j = [(0, 0), (down, 20), (down + 0.05 * L, 0, "snap"), (down + 0.1 * L, 20), (down + 0.15 * L, 0, "snap"),
             (down + 0.2 * L, 20), (tug, 0, "snap"), (up, 0)]
        c.add("Head", RY, lambda t: 8 * shake(t, down, tug, 2.0))
    t0 = up + 0.02 * L
    k = 0
    while t0 + 0.12 * L <= chew_end:
        j.append((t0 + 0.06 * L, 16 if k % 2 == 0 else 13))
        j.append((t0 + 0.12 * L, 1))
        t0 += 0.12 * L
        k += 1
    j += [(gulp, 0), (L, 0)]
    jaw(c, curve(j))
    c.add("Head", RZ, lambda t: 3 * shake(t, up, chew_end, 4.0))
    # déglutition : petite vague qui descend le cou
    for i, nb in enumerate(rig.neck):
        c.add(nb, RX, lambda t, i=i: 6 * bump(t, gulp - 0.08 * L + i * 0.03 * L, gulp + 0.04 * L + i * 0.03 * L))
    c.key(0, tail_lift(rig, 0))
    c.key(down, tail_lift(rig, 12))
    c.key(tug, tail_lift(rig, 10 if not meat else 4))
    c.key(up, tail_lift(rig, 0))
    tail_wave(c, 5, 1.1, RY, lag=0.1)
    blinks(c, [0.62 * L, 0.93 * L])
    return c


def sleep(rig):
    c = new(rig, "Sleep", 4.4, loop=True)
    L = c.length
    sp = sleep_pose(rig)
    c.key(0, sp)
    c.key(L, sp)
    fold_legs(c, lambda t: 1.0)
    lids(c, lambda t: 1.0)
    breathe(c, L / 2, 2.4)
    c.add("Hips", PY, lambda t: 0.02 * rig.u * math.sin(4 * math.pi * t / L))
    # ronflement : la gueule s'entrouvre à l'expiration, petit frisson du bout de la queue
    c.add("Jaw", RX, lambda t: -3.0 * max(0.0, math.sin(4 * math.pi * t / L - 1.2)))
    if rig.tail:
        c.add(rig.tail[-1], RY, lambda t: 9 * shake(t, 0.55 * L, 0.72 * L, 5.0))
        c.add(rig.tail[-2], RY, lambda t: 4 * shake(t, 0.56 * L, 0.72 * L, 5.0))
    return c


def spawn(rig):
    """Sort de la cuve : roulé en boule, se déplie, s'ébroue, regarde le joueur."""
    c = new(rig, "Spawn", 3.0, nxt="Idle")
    L, u = c.length, rig.u
    a, b, s0, s1, look, back = 0.08 * L, 0.24 * L, 0.27 * L, 0.6 * L, 0.68 * L, 0.9 * L
    crouch = merge({"Hips": P(py=-0.42 * u, rx=6), "Chest": P(rx=-14),
                    "ArmL": P(rx=-30), "ArmR": P(rx=-30), "ForearmL": P(rx=45), "ForearmR": P(rx=45)},
                   curl(rig.tail, -70, RY, 1.2), tail_lift(rig, -10))
    c.key(0, crouch)
    c.key(a, crouch)
    c.rest(b, kind="back")
    c.rest(L)
    fold = curve([(0, 0.55), (a, 0.55), (b, 0, "out")])
    fold_legs(c, lambda t: fold.at(t))
    pitch = curve([(0, -40), (a, -40), (b, 10, "back"), (s1, 4), (look, 6), (back, 2), (L, 0)])
    yaw = curve([(0, 0), (s1, 0), (look, 22, "inout"), (back, 20), (L, 0)])
    roll = curve([(0, 0), (s1, 0), (look, 14, "back"), (back, 12), (L, 0)])
    aim(c, yaw, pitch, roll)
    lids(c, lambda t: 1.0 - ramp(t, a, b - 0.04 * L, "out2"))
    blinks(c, [0.78 * L])
    # s'ébroue : tout le corps tremble, la tête et la queue suivent avec du retard
    sh = lambda t: shake(t, s0, s1, 7.0, 3.0)  # noqa: E731
    c.add("Hips", RZ, lambda t: 9 * sh(t))
    c.add("Chest", RZ, lambda t: -7 * sh(t - 0.02))
    c.add("Chest", RY, lambda t: 5 * sh(t - 0.03))
    for i, nb in enumerate(rig.neck + ["Head"]):
        c.add(nb, RY, lambda t, i=i: 10 * sh(t - 0.03 * (i + 1)))
    follow(c, lambda t: 10 * sh(t), rig.tail, RY, [0.8, 1.0, 1.2, 1.3, 1.4, 1.5], 0.03)
    for bone, s in (("ArmL", -1), ("ArmR", 1)):
        c.add(bone, RZ, lambda t, s=s: s * 14 * sh(t - 0.02))
    jaw(c, curve([(0, 0), (s0, 0), (s0 + 0.04 * L, 14), (s1, 8), (look, 0), (L, 0)]))
    return c


# ====================================================================== gardiens
def wake(rig):
    """Du sommeil à debout : sursaut, se relève, secoue la tête."""
    c = new(rig, "Wake", 1.8, nxt="Idle")
    L, u = c.length, rig.u
    jolt, up, sh0, sh1 = 0.12 * L, 0.5 * L, 0.52 * L, 0.86 * L
    sp = sleep_pose(rig)
    c.key(0, sp)
    jolted = merge(sp, {"Hips": P(py=0.08 * u)})
    c.key(jolt, jolted, "snap")
    c.rest(up, kind="back")
    c.rest(L)
    fold = curve([(0, 1), (jolt, 0.9, "snap"), (up, 0, "out")])
    fold_legs(c, lambda t: fold.at(t))
    lids(c, lambda t: 1.0 - ramp(t, 0.04 * L, jolt, "snap"))
    pitch = curve([(0, 0), (jolt, 22, "snap"), (up, 12), (sh1, 6), (L, 0)])
    aim(c, None, pitch)
    for nb, k in (("Head", 1.0),) + tuple((n, 0.4) for n in rig.neck[-1:]):
        c.add(nb, RY, lambda t, k=k: 20 * k * shake(t, sh0, sh1, 6.0, 1.5))
        c.add(nb, RZ, lambda t, k=k: 8 * k * shake(t - 0.02, sh0, sh1, 6.0, 1.5))
    jaw(c, curve([(0, 0), (jolt, 12, "snap"), (up, 0), (L, 0)]))
    return c


def catch(rig):
    """Coup de tête cartoon qui fait tomber le joueur (pas de morsure, gueule fermée à l'impact)."""
    c = new(rig, "Catch", 1.25, nxt="Idle")
    L, u = c.length, rig.u
    wind, hit, rec = 0.36 * L, 0.48 * L, 0.66 * L
    c.key(0, {"Hips": P(py=0, rx=0, pz=0), "Chest": P(rx=0)})
    c.key(wind, {"Hips": P(py=-0.12 * u, rx=5, pz=0.14 * u), "Chest": P(rx=-4)}, "inout")
    c.key(hit, {"Hips": P(py=-0.06 * u, rx=-12, pz=-0.3 * u), "Chest": P(rx=-6)}, "snap")
    c.key(rec, {"Hips": P(py=-0.04 * u, rx=-3, pz=-0.12 * u), "Chest": P(rx=2)}, "back")
    c.rest(L)
    pitch = curve([(0, 0), (wind, -18), (hit, -16, "snap"), (rec, 12, "back"), (L, 0)])
    aim(c, None, pitch)
    if rig.neck:
        c.add(rig.neck[0], RX, lambda t: -14 * win(t, wind - 0.1 * L, rec, 0.3))
    jaw(c, curve([(0, 0), (wind, 8), (hit - 0.04 * L, 0), (rec, 0), (L, 0)]))
    c.add("Head", RZ, lambda t: 6 * shake(t, hit, rec + 0.1 * L, 9.0, 4.0))
    c.key(0, tail_lift(rig, 0))
    c.key(wind, tail_lift(rig, 14))
    c.key(hit, tail_lift(rig, 4), "snap")
    c.key(L, tail_lift(rig, 0))
    follow(c, lambda t: 6 * shake(t, hit, L, 4.0, 2.0), rig.tail, RY, [0.6, 0.8, 1.0, 1.2, 1.4, 1.5], 0.03)
    for bone, s in (("ArmL", -1), ("ArmR", 1)):
        c.add(bone, RZ, lambda t, s=s: s * 15 * win(t, wind, rec, 0.3))
    c.event(hit, "Hit")
    return c


def search(rig):
    """A perdu le joueur : renifle le sol, regarde à gauche, à droite, hésite (boucle)."""
    c = new(rig, "Search", 4.4, loop=True)
    L, u = c.length, rig.u
    s1, r0, l0, l1, rr0, rr1, f0 = 0.16 * L, 0.24 * L, 0.3 * L, 0.46 * L, 0.52 * L, 0.68 * L, 0.78 * L
    low = {"Hips": P(rx=-6, py=-0.08 * u), "Chest": P(rx=-7)}
    c.key(0, low)
    c.key(s1, low)
    c.key(r0, {"Hips": P(rx=0, py=0), "Chest": P(rx=0)}, "inout")
    c.key(f0, {"Hips": P(rx=0, py=0), "Chest": P(rx=0)})
    c.key(L, low, "inout")
    pitch = curve([(0, -36), (s1, -36), (r0, 8, "out"), (l1, 6), (rr1, 6), (f0, 2), (L, -36, "inout")])
    yaw = curve([(0, 0), (r0, 0), (l0, 48, "snap"), (l1, 44), (rr0, -46, "snap"), (rr1, -42), (f0, 0, "inout"), (L, 0)])
    roll = curve([(0, 0), (l0, 8), (l1, 8), (rr0, -8), (rr1, -8), (f0, 14), (0.9 * L, 12), (L, 0)])
    aim(c, yaw, pitch, roll)
    c.add("Hips", RY, lambda t: 0.25 * yaw.at(t))
    c.add("Head", RX, lambda t: 3.5 * shake(t, 0.02 * L, s1, 7.0) + 3.5 * shake(t, 0.86 * L, L, 7.0))
    blinks(c, [0.49 * L, 0.74 * L])
    tail_wave(c, 6, L / 2, RY, lag=0.1)
    breathe(c, L / 3, 1.0)
    return c


def back_to_sleep(rig):
    """Tourne sur lui-même en piétinant puis se recouche (finit sur la pose de Sleep)."""
    c = new(rig, "BackToSleep", 3.4, nxt="Sleep")
    L, u = c.length, rig.u
    turn0, turn1, down, close = 0.06 * L, 0.56 * L, 0.86 * L, 0.92 * L
    sp = sleep_pose(rig)
    c.key(0, {b: {ch: 0.0 for ch in chans} for b, chans in sp.items()})
    c.key(turn1, {b: {ch: 0.0 for ch in chans} for b, chans in sp.items()})
    c.key(down, sp, "inout")
    c.key(L, sp)
    spin = curve([(0, 0), (turn0, 0), (turn1, 360, "inout"), (L, 360)])
    c.add("Hips", RY, lambda t: spin.at(t))
    # piétine pendant le tour : les pieds suivent le corps et se lèvent à tour de rôle
    steps = 6

    def stomp(t, side):
        if t < turn0 or t > turn1:
            return 0.0
        q = (t - turn0) / (turn1 - turn0) * steps + (0.5 if side == "R" else 0.0)
        return max(0.0, math.sin(math.pi * (q % 1.0))) if int(q) % 2 == 0 else 0.0

    def rel(t):
        return win(t, turn0 - 0.02 * L, turn1 + 0.02 * L, 0.06)
    for name, dr in c.drives.items():
        side = name[-1]
        dr.rel = rel
        dr.rel_toe = lambda t, side=side: (0, 0.14 * u * stomp(t, side), 0)
    fold = curve([(0, 0), (turn1, 0), (down, 1, "inout"), (L, 1)])
    base_toe = {n: dr.rel_toe for n, dr in c.drives.items()}
    fold_legs(c, lambda t: fold.at(t))
    for n, dr in c.drives.items():
        dr.rel_toe = base_toe[n]
        dr.rel = rel
    pitch = curve([(0, 0), (turn0, -10), (turn1, -12), (down, 0), (L, 0)])
    aim(c, None, pitch)
    lids(c, lambda t: ramp(t, close - 0.08 * L, L - 0.02 * L, "inout"))
    jaw(c, curve([(0, 0), (turn1 + 0.04 * L, 0), (turn1 + 0.12 * L, 30), (down, 0), (L, 0)]))
    c.add("Hips", PY, lambda t: -0.05 * u * shake(t, turn0, turn1, steps / (turn1 - turn0) / 2))
    return c


def fusion(rig):
    """Aspiré dans le tourbillon : pattes qui pédalent, bras et queue qui battent, tête affolée (boucle)."""
    c = new(rig, "Fusion", 1.2, loop=True)
    L, u = c.length, rig.u
    for dr in c.drives.values():
        dr.weight = lambda t: 0.0
    c.key(0, {"Hips": P(py=0.25 * u, rx=-10), "Chest": P(rx=8)})
    f = 2.0 / L
    for b, ph in (("ThighL", 0.0), ("ThighR", 0.5)):
        if b in rig.has:
            c.add(b, RX, lambda t, ph=ph: 32 * math.sin(2 * math.pi * (f * t - ph)))
    for b, ph in (("ShinL", 0.0), ("ShinR", 0.5)):
        if b in rig.has:
            c.add(b, RX, lambda t, ph=ph: -26 + 26 * math.sin(2 * math.pi * (f * t - ph - 0.2)))
    for b, ph in (("FootL", 0.0), ("FootR", 0.5)):
        if b in rig.has:
            c.add(b, RX, lambda t, ph=ph: 20 * math.sin(2 * math.pi * (f * t - ph - 0.35)))
    for bone, s in (("ArmL", -1), ("ArmR", 1)):
        c.add(bone, RZ, lambda t, s=s: s * (25 + 18 * math.sin(2 * math.pi * (3 / L) * t + (0 if s < 0 else 1.5))))
    yaw = curve([(0, 0), (0.25 * L, 30), (0.5 * L, -28), (0.75 * L, 26), (L, 0)])
    pitch = curve([(0, 10), (0.5 * L, 18), (L, 10)])
    aim(c, yaw, pitch)
    jaw(c, curve([(0, 26), (0.5 * L, 34), (L, 26)]))
    tail_wave(c, 22, L / 2, RY, lag=0.06)
    tail_wave(c, 10, L / 3, RX, lag=0.06)
    return c


def index_pose(rig):
    """Pose de présentation pour l'Index : poitrine bombée, tête haute tournée vers le joueur (boucle)."""
    c = new(rig, "Index", 4.4, loop=True)
    L, u = c.length, rig.u
    proud = merge({"Hips": P(rx=3, py=0.02 * u), "Chest": P(rx=8),
                   "ArmL": P(rx=12, rz=-10), "ArmR": P(rx=12, rz=10)}, tail_lift(rig, 8))
    c.key(0, proud)
    c.key(L, proud)
    dr = c.drive("LegL")
    if dr:
        l = dr.limb
        dr.toe = lambda t: (l.toe0[0] - 0.04 * u, l.toe0[1], l.toe0[2] - 0.22 * u)
    yaw = curve([(0, 18), (0.45 * L, 18), (0.55 * L, 12), (0.62 * L, 20, "back"), (L, 18)])
    pitch = curve([(0, 12), (0.45 * L, 12), (0.55 * L, 24, "snap"), (0.66 * L, 10, "back"), (L, 12)])
    roll = curve([(0, 6), (0.5 * L, 6), (0.58 * L, -8, "snap"), (0.7 * L, 6, "inout"), (L, 6)])
    aim(c, yaw, pitch, roll)
    breathe(c, L / 2, 1.4)
    tail_wave(c, 7, L, RY, lag=0.14)
    blinks(c, [0.3 * L, 0.82 * L])
    jaw(c, curve([(0, 0), (0.53 * L, 0), (0.58 * L, 16, "snap"), (0.68 * L, 0), (L, 0)]))
    return c


def build(rig):
    clips = [idle(rig), idle_sniff(rig), idle_scratch(rig), idle_stretch(rig), idle_shake(rig), idle_yawn(rig),
             walk(rig), walk(rig, "Run", 0.52, run=True), happy(rig), roar(rig), eat(rig), sleep(rig), spawn(rig),
             wake(rig), catch(rig), search(rig), back_to_sleep(rig), fusion(rig), index_pose(rig)]
    return {c.name: c for c in clips}
