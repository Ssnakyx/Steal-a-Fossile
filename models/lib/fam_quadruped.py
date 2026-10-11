"""Famille Quadruped (Triceratops, Stegosaurus, Ankylosaurus, Brachiosaurus...) : tous les états du GDD.

Os attendus : Hips, Chest, Neck1..N, Head, Jaw, LidL/R, Thigh/Shin/Foot L/R (pattes arrière), Arm/Forearm/Hand L/R
(pattes avant), Tail1..N, facultatif Frill (collerette, plaques). Points ToeL/R et FrontToeL/R. Les quatre pattes
sont en IK : les pieds restent posés au sol tant qu'un état ne les lève pas.
Personnalité : tempo, weight, stride, bob, tail, diet, happy ("stomp"), catch ("toss" ou "ram")."""
from __future__ import annotations

import math

from anim import PX, PY, PZ, RX, RY, RZ, Clip, P, bump, clamp, ease, ramp, shake, smooth, win
from motion import (aim, airborne_multi, blinks, breathe, curl, curve, fit_period, fold_legs, follow, gait, jaw, lids,
                    merge, tail_lift, tail_wave)

HIND = ("LegL", "LegR")
FRONT = ("FrontL", "FrontR")


def new(rig, name, base, loop=False, nxt=None):
    return Clip(rig, name, rig.T(base), loop, nxt)


def frill(c, fn):
    """Collerette ou plaques : mouvement retardé (fn(t) en degrés autour de X)."""
    if "Frill" in c.rig.has:
        c.add("Frill", RX, fn)


def sleep_pose(rig):
    """Couché sur le ventre, menton posé, queue ramenée sur le côté gauche, yeux fermés."""
    u = rig.u
    drop = rig.P.get("sleepDrop", 0.5)
    pose = {"Hips": P(py=-drop * u, rx=2, rz=4), "Chest": P(rx=-3, py=-0.04 * u)}
    if rig.neck:
        pose[rig.neck[0]] = P(rx=-12, ry=10)
    pose["Head"] = P(rx=-6, ry=8, rz=6)
    if "Frill" in rig.has:
        pose["Frill"] = P(rx=-4)
    return merge(pose, curl(rig.tail, -70, RY, 1.3), tail_lift(rig, -6))


def idle_life(c, breath=1.0, tail=1.0, sway=1.0):
    rig, L, u = c.rig, c.length, c.rig.u
    breathe(c, L / 2 if c.loop else 1.8, breath * 1.2)
    per = L if c.loop else 3.5
    c.add("Hips", PX, lambda t: 0.02 * u * sway * math.sin(2 * math.pi * t / per))
    c.add("Hips", RZ, lambda t: 0.8 * sway * math.sin(2 * math.pi * t / per))
    tail_wave(c, 4.0 * tail * rig.P["tail"], L if c.loop else 3.0, RY, lag=0.14)
    tail_wave(c, 1.5 * tail, (L / 2) if c.loop else 1.5, RX, lag=0.12)


# ====================================================================== parc
def idle(rig):
    c = new(rig, "Idle", 4.6, loop=True)
    L = c.length
    idle_life(c)
    yaw = curve([(0, 0), (0.15 * L, 0), (0.3 * L, 18), (0.45 * L, 16), (0.6 * L, -14), (0.75 * L, -12), (0.88 * L, 0), (L, 0)])
    pitch = curve([(0, 0), (0.3 * L, 4), (0.45 * L, 3), (0.6 * L, -3), (0.75 * L, -2), (0.88 * L, 0), (L, 0)])
    roll = curve([(0, 0), (0.3 * L, 4), (0.45 * L, 3), (0.6 * L, -3), (0.88 * L, 0), (L, 0)])
    aim(c, yaw, pitch, roll)
    frill(c, lambda t: -1.5 * math.sin(2 * math.pi * (t / (L / 2)) - 0.8))
    blinks(c, [0.24 * L, 0.7 * L])
    # petit souffle par le nez : la tête donne un coup
    c.add("Head", RX, lambda t: 3 * shake(t, 0.52 * L, 0.58 * L, 12.0))
    return c


def idle_sniff(rig):
    c = new(rig, "IdleSniff", 2.8, nxt="Idle")
    L, u = c.length, rig.u
    a, b = 0.28 * L, 0.74 * L
    c.key(0, {"Hips": P(py=0), "Chest": P(rx=0, py=0)})
    c.key(a, {"Hips": P(py=-0.04 * u), "Chest": P(rx=-5, py=-0.06 * u)}, "inout")
    c.key(b, {"Hips": P(py=-0.04 * u), "Chest": P(rx=-5, py=-0.06 * u)})
    c.rest(L)
    pitch = curve([(0, 0), (a, -34), (b, -32), (L, 0)])
    yaw = curve([(0, 0), (a, 8), (0.5 * L, -10), (b, 6), (L, 0)])
    aim(c, yaw, pitch)
    c.add("Head", RX, lambda t: 3 * shake(t, a + 0.04 * L, b, 6.5))
    frill(c, lambda t: 2 * shake(t - 0.03, a + 0.04 * L, b, 6.5))
    tail_wave(c, 4, 1.4, RY, lag=0.12)
    breathe(c, 1.4, 0.9)
    blinks(c, [0.88 * L])
    return c


def idle_scratch(rig):
    """Se gratte le flanc avec une patte arrière, la tête tournée vers la démangeaison."""
    c = new(rig, "IdleScratch", 3.0, nxt="Idle")
    L, u = c.length, rig.u
    t1, t2, t3, t4 = 0.16 * L, 0.3 * L, 0.7 * L, 0.84 * L
    c.key(0, {"Hips": P(px=0, rz=0, py=0), "Chest": P(rz=0)})
    c.key(t1, {"Hips": P(px=0.1 * u, rz=-4, py=-0.03 * u), "Chest": P(rz=2)}, "inout")
    c.key(t3, {"Hips": P(px=0.1 * u, rz=-4, py=-0.03 * u), "Chest": P(rz=2)})
    c.rest(t4 + 0.06 * L)
    c.rest(L)
    yaw = curve([(0, 0), (t2, 34), (t3, 32), (t4, 0), (L, 0)])
    pitch = curve([(0, 0), (t2, -10), (t3, -10), (t4, 0), (L, 0)])
    roll = curve([(0, 0), (t2, -12), (t3, -12), (t4, 0), (L, 0)])
    aim(c, yaw, pitch, roll)
    c.add("Chest", RY, lambda t: 6 * win(t, t1, t4, 0.25))
    dr = c.drive("LegL")
    if dr:
        l = dr.limb
        x0, y0, z0 = l.toe0
        lift = curve([(0, 0), (t1, 0), (t2, 1, "out"), (t3, 1), (t4, 0, "in2"), (L, 0)])

        def toe(t):
            k = lift.at(t)
            scr = shake(t, t2, t3, 6.5)
            return (x0 - 0.04 * u * k, y0 + (0.28 * u + 0.05 * u * scr) * k, z0 - (0.38 * u + 0.08 * u * scr) * k)
        dr.toe = toe
        dr.tilt = lambda t: -30 * lift.at(t)
    frill(c, lambda t: 3 * shake(t - 0.04, t2, t3, 6.5))
    tail_wave(c, 7, 0.8, RY, lag=0.08, env=lambda t: win(t, t2, t3, 0.2))
    blinks(c, [0.5 * L])
    lids(c, lambda t: 0.6 * win(t, t2 + 0.05 * L, t3 - 0.05 * L, 0.2))
    return c


def idle_stretch(rig):
    """S'étire comme un chien : pattes avant tendues, poitrine basse, croupe haute, puis se secoue un peu."""
    c = new(rig, "IdleStretch", 3.4, nxt="Idle")
    L, u = c.length, rig.u
    a, b, e = 0.26 * L, 0.6 * L, 0.8 * L
    c.key(0, {"Chest": P(rx=0, py=0), "Hips": P(rx=0, py=0)})
    c.key(a, {"Chest": P(rx=-9, py=-0.2 * u), "Hips": P(rx=-6, py=0.02 * u)}, "inout")
    c.key(b, {"Chest": P(rx=-10, py=-0.22 * u), "Hips": P(rx=-6, py=0.02 * u)})
    c.key(e, {"Chest": P(rx=2, py=0), "Hips": P(rx=1, py=0)}, "inout")
    c.rest(L)
    for name in FRONT:
        dr = c.drive(name)
        if dr:
            l = dr.limb
            reach = curve([(0, 0), (0.08 * L, 0), (a, 1, "inout"), (b, 1), (e, 0, "inout"), (L, 0)])
            lift = curve([(0, 0), (0.06 * L, 0), (0.15 * L, 1), (a, 0), (b, 0), (0.68 * L, 1), (e, 0), (L, 0)])
            dr.toe = (lambda t, l=l, reach=reach, lift=lift:
                      (l.toe0[0], l.toe0[1] + 0.12 * u * lift.at(t), l.toe0[2] - 0.35 * u * reach.at(t)))
            dr.tilt = lambda t, reach=reach: 12 * reach.at(t)
    pitch = curve([(0, 0), (a, 14), (b, 16), (e, 8), (L, 0)])
    aim(c, None, pitch)
    jaw(c, curve([(0, 0), (a, 0), (0.4 * L, 34), (b, 30), (b + 0.06 * L, 0, "snap"), (L, 0)]))
    lids(c, lambda t: win(t, 0.34 * L, b + 0.02 * L, 0.2))
    c.key(0, tail_lift(rig, 0))
    c.key(a, tail_lift(rig, 16))
    c.key(b, tail_lift(rig, 18))
    c.key(e, tail_lift(rig, 0))
    c.key(L, tail_lift(rig, 0))
    frill(c, lambda t: -6 * win(t, a, b, 0.3) + 4 * shake(t, e, L, 7.0, 3.0))
    c.add("Hips", RZ, lambda t: 3 * shake(t, e, L, 7.0, 3.0))
    return c


def idle_shake(rig):
    c = new(rig, "IdleShake", 1.9, nxt="Idle")
    L = c.length
    a, b = 0.14 * L, 0.8 * L
    pitch = curve([(0, 0), (a, -8), (b, -4), (L, 0)])
    aim(c, None, pitch)
    sh = lambda t: shake(t, a, b, 5.5, 1.4)  # noqa: E731
    c.add("Head", RY, lambda t: 20 * sh(t))
    c.add("Head", RZ, lambda t: 12 * sh(t - 0.03))
    if rig.neck:
        c.add(rig.neck[0], RY, lambda t: 8 * sh(t - 0.02))
    frill(c, lambda t: 6 * sh(t - 0.06))
    c.add("Chest", RZ, lambda t: -3 * sh(t - 0.04))
    jaw(c, curve([(0, 0), (a, 8), (b, 6), (L, 0)]))
    follow(c, lambda t: 5 * sh(t), rig.tail, RY, [0.6, 0.8, 1.0, 1.2, 1.3], 0.04)
    lids(c, lambda t: 0.8 * win(t, a + 0.05, b - 0.1, 0.15))
    breathe(c, 1.0, 0.6)
    return c


def idle_yawn(rig):
    c = new(rig, "IdleYawn", 3.0, nxt="Idle")
    L = c.length
    a, b, d = 0.32 * L, 0.6 * L, 0.66 * L
    c.key(0, {"Chest": P(rx=0)})
    c.key(a, {"Chest": P(rx=5)}, "inout")
    c.key(b, {"Chest": P(rx=6)})
    c.rest(L)
    pitch = curve([(0, 0), (a, 26), (b, 28), (d + 0.05 * L, 3, "out"), (L, 0)])
    aim(c, None, pitch)
    jaw(c, curve([(0, 0), (0.1 * L, 0), (a, 44, "inout"), (b, 48), (d, 0, "snap"), (L, 0)]))
    c.add("Head", RZ, lambda t: 3 * shake(t, a, b, 7.0))
    c.add("Head", RY, lambda t: 7 * shake(t, d, d + 0.25 * L, 5.0, 2.0))
    frill(c, lambda t: -5 * win(t, 0.1 * L, b, 0.3))
    lids(c, lambda t: win(t, 0.18 * L, b + 0.02 * L, 0.18))
    blinks(c, [0.88 * L])
    tail_wave(c, 4, 1.6, RY, lag=0.12)
    return c


def walk(rig, name="Walk", base=1.25, run=False):
    c = new(rig, name, base, loop=True)
    T, u, Pp = c.length, rig.u, rig.P
    if run:
        S, beta, lift, heel, curl_d = 1.7 * u * Pp["stride"], 0.42, 0.26 * u, 12, 24
        phases = {"LegL": 0.0, "FrontR": 0.0, "LegR": 0.5, "FrontL": 0.5}
    else:
        S, beta, lift, heel, curl_d = 0.66 * u * Pp["stride"], 0.72, 0.11 * u, 6, 10
        phases = {"LegL": 0.0, "FrontL": 0.25, "LegR": 0.5, "FrontR": 0.75}
    c.speed = S / T
    gait(c, phases, T, S, beta, lift, heel, curl_d)
    for limb, ph in phases.items():
        c.event(round((ph % 1.0) * T, 3), "Step", ("Foot" if limb.startswith("Leg") else "Hand") + limb[-1])
    w = rig.weight
    bob = (0.07 if run else 0.03) * u * Pp["bob"] * (0.8 + 0.25 * w)
    two = lambda t, ph=0.0: math.cos(2 * math.pi * (2 * t / T - ph))  # noqa: E731
    one = lambda t, ph=0.0: math.cos(2 * math.pi * (t / T - ph))  # noqa: E731
    if run:
        # charge : tête basse, queue haute, corps qui rebondit
        c.key(0, {"Hips": P(rx=-3, py=-0.04 * u), "Chest": P(rx=-2)})
        c.add("Hips", PY, lambda t: -bob * two(t, beta / 2))
        c.add("Chest", PY, lambda t: -0.5 * bob * two(t, beta / 2 + 0.08))
    else:
        c.key(0, {"Hips": P(py=-0.03 * u), "Chest": P(py=-0.03 * u)})
        c.add("Hips", PY, lambda t: -bob * two(t, 0.1))
        c.add("Chest", PY, lambda t: -0.8 * bob * two(t, 0.35))
        c.add("Chest", RX, lambda t: 1.2 * two(t, 0.35))
    roll = 2.0 if not run else 2.6
    c.add("Hips", RZ, lambda t: roll * one(t, beta / 2))
    c.add("Chest", RZ, lambda t: -roll * one(t, beta / 2) + roll * 0.8 * one(t, (0.25 if not run else 0.5) + beta / 2))
    yaw = 2.5 if not run else 3.0
    hips_yaw = lambda t: -yaw * one(t)  # noqa: E731
    c.add("Hips", RY, hips_yaw)
    c.add("Chest", RY, lambda t: 0.8 * yaw * one(t, 0.05))
    nk = rig.neck
    if run:
        if nk:
            c.key(0, {nk[0]: P(rx=-10)})
        c.key(0, {"Head": P(rx=-8)})
    nod = (2.5 if not run else 4.0)
    if nk:
        c.add(nk[0], RX, lambda t: 0.4 * nod * two(t, 0.3))
    c.add("Head", RX, lambda t: nod * two(t, 0.38))
    c.add("Head", RY, lambda t: -0.6 * hips_yaw(t))
    frill(c, lambda t: 2.5 * two(t, 0.5))
    tl = rig.tail
    if run:
        c.key(0, tail_lift(rig, 8))
    follow(c, hips_yaw, tl, RY, [-0.7, -0.9, -1.1, -1.3, -1.5], T * 0.06)
    follow(c, lambda t: (1.8 if not run else 3.5) * Pp["tail"] * two(t, 0.1), tl, RX, [0.5, 0.7, 0.9, 1.1, 1.2], T * 0.05)
    blinks(c, [0.55 * T] if not run else [])
    return c


def happy(rig):
    """Joie d'un lourd : se cabre un peu, tape deux fois des pattes avant, secoue la tête, la queue frétille."""
    c = new(rig, "Happy", 1.7, nxt="Idle")
    L, u = c.length, rig.u
    up1, dn1, up2, dn2 = 0.2 * L, 0.36 * L, 0.5 * L, 0.64 * L
    c.key(0, {"Hips": P(rx=0, py=0), "Chest": P(rx=0, py=0)})
    c.key(0.1 * L, {"Hips": P(rx=-2, py=-0.05 * u), "Chest": P(rx=-3, py=-0.06 * u)}, "inout")
    c.key(up1, {"Hips": P(rx=6, py=0.02 * u), "Chest": P(rx=8, py=0.1 * u)}, "out")
    c.key(dn1, {"Hips": P(rx=-1, py=-0.04 * u), "Chest": P(rx=-3, py=-0.08 * u)}, "in2")
    c.key(up2, {"Hips": P(rx=4, py=0.01 * u), "Chest": P(rx=6, py=0.07 * u)}, "out")
    c.key(dn2, {"Hips": P(rx=-1, py=-0.03 * u), "Chest": P(rx=-2, py=-0.06 * u)}, "in2")
    c.rest(L)
    for name, off in (("FrontL", 0.0), ("FrontR", 0.03)):
        dr = c.drive(name)
        if dr:
            l = dr.limb
            lift = curve([(0, 0), (0.1 * L, 0), (up1 + off * L, 1, "out"), (dn1 + off * L, 0, "in2"), (up2 + off * L, 0.8, "out"),
                          (dn2 + off * L, 0, "in2"), (L, 0)])
            dr.toe = lambda t, l=l, lift=lift: (l.toe0[0], l.toe0[1] + 0.32 * u * lift.at(t), l.toe0[2] - 0.08 * u * lift.at(t))
            dr.tilt = lambda t, lift=lift: -20 * lift.at(t)
    c.event(dn1, "Step", "HandL")
    c.event(dn2, "Step", "HandL")
    pitch = curve([(0, 0), (up1, 16), (dn1, -4), (up2, 14), (dn2, -2), (L, 0)])
    aim(c, None, pitch)
    c.add("Head", RY, lambda t: 14 * shake(t, dn2, L, 5.0, 2.0))
    frill(c, lambda t: 5 * shake(t - 0.05, 0.1 * L, L, 4.0, 1.0))
    jaw(c, curve([(0, 0), (up1, 20), (dn1, 4), (up2, 18), (dn2, 0), (L, 0)]))
    tail_wave(c, 14 * rig.P["tail"], 0.36, RY, lag=0.05, env=lambda t: win(t, 0.05 * L, L, 0.2))
    return c


def roar(rig):
    c = new(rig, "Roar", 2.3, nxt="Idle")
    L, u = c.length, rig.u
    a, b, h1, h2 = 0.26 * L, 0.36 * L, 0.7 * L, 0.86 * L
    c.key(0, {"Hips": P(py=0, pz=0), "Chest": P(rx=0, py=0)})
    c.key(a, {"Hips": P(py=-0.06 * u, pz=0.05 * u), "Chest": P(rx=-6, py=-0.06 * u)}, "inout")
    c.key(b, {"Hips": P(py=0, pz=-0.06 * u), "Chest": P(rx=8, py=0.06 * u)}, "out")
    c.key(h1, {"Hips": P(py=0, pz=-0.05 * u), "Chest": P(rx=7, py=0.05 * u)})
    c.rest(h2)
    c.rest(L)
    pitch = curve([(0, 0), (a, -18), (b, 30, "back"), (h1, 26), (h2, 2), (L, 0)])
    aim(c, None, pitch)
    jaw(c, curve([(0, 0), (a, 4), (b, 42, "back"), (h1, 38), (h2, 0), (L, 0)]))
    c.add("Head", RY, lambda t: 2.5 * shake(t, b, h1, 12.0))
    c.add("Head", RZ, lambda t: 2.0 * shake(t - 0.02, b, h1, 10.0))
    frill(c, lambda t: 5 * shake(t, b, h1, 9.0) - 6 * win(t, a, h2, 0.2))
    c.key(0, tail_lift(rig, 0))
    c.key(a, tail_lift(rig, -6))
    c.key(b, tail_lift(rig, 12), "back")
    c.key(h1, tail_lift(rig, 10))
    c.key(L, tail_lift(rig, 0))
    tail_wave(c, 6, 0.4, RY, lag=0.05, env=lambda t: win(t, b, h1, 0.15))
    c.event(b, "Roar")
    return c


def eat(rig):
    c = new(rig, "Eat", 3.6, nxt="Idle")
    L, u = c.length, rig.u
    meat = rig.P["diet"] == "meat"
    down, graze_end, up, chew_end, gulp = 0.16 * L, 0.48 * L, 0.56 * L, 0.8 * L, 0.88 * L
    c.key(0, {"Hips": P(py=0), "Chest": P(rx=0, py=0)})
    c.key(down, {"Hips": P(py=-0.03 * u), "Chest": P(rx=-6, py=-0.08 * u)}, "inout")
    c.key(graze_end, {"Hips": P(py=-0.03 * u), "Chest": P(rx=-6, py=-0.08 * u)})
    c.key(up, {"Hips": P(py=0), "Chest": P(rx=1, py=0)}, "inout")
    c.rest(L)
    pitch = curve([(0, 0), (down, -40), (graze_end, -38), (up, 6), (chew_end, 6), (gulp, 14), (L, 0)])
    aim(c, None, pitch)
    j = [(0, 0), (down, 22), (down + 0.05 * L, 0, "snap"), (down + 0.11 * L, 22), (down + 0.16 * L, 0, "snap"),
         (down + 0.22 * L, 22), (graze_end, 0, "snap"), (up, 0)]
    # arrache les feuilles : petits coups de tête en arrière à chaque bouchée
    for k in range(3):
        tb = down + 0.05 * L + k * 0.11 * L
        c.add("Head", RX, lambda t, tb=tb: 7 * bump(t, tb, tb + 0.06 * L))
    t0 = up + 0.01 * L
    k = 0
    while t0 + 0.1 * L <= chew_end:
        j.append((t0 + 0.05 * L, 12 if k % 2 == 0 else 9))
        j.append((t0 + 0.1 * L, 1))
        t0 += 0.1 * L
        k += 1
    j += [(gulp, 0), (L, 0)]
    jaw(c, curve(j))
    c.add("Head", RZ, lambda t: 3 * shake(t, up, chew_end, 3.0))
    frill(c, lambda t: 2.5 * shake(t, down, graze_end, 9.0))
    for i, nb in enumerate(rig.neck):
        c.add(nb, RX, lambda t, i=i: 5 * bump(t, gulp - 0.07 * L + i * 0.03 * L, gulp + 0.04 * L + i * 0.03 * L))
    tail_wave(c, 4, 1.4, RY, lag=0.12)
    blinks(c, [0.66 * L, 0.95 * L])
    return c


def sleep(rig):
    c = new(rig, "Sleep", 5.0, loop=True)
    L = c.length
    sp = sleep_pose(rig)
    c.key(0, sp)
    c.key(L, sp)
    fold_legs(c, lambda t: 1.0)
    lids(c, lambda t: 1.0)
    breathe(c, L / 2, 2.6)
    c.add("Hips", PY, lambda t: 0.018 * rig.u * math.sin(4 * math.pi * t / L))
    c.add("Jaw", RX, lambda t: -2.5 * max(0.0, math.sin(4 * math.pi * t / L - 1.2)))
    frill(c, lambda t: 1.2 * math.sin(4 * math.pi * t / L - 1.0))
    if rig.tail:
        c.add(rig.tail[-1], RY, lambda t: 8 * shake(t, 0.55 * L, 0.7 * L, 4.0))
    return c


def spawn(rig):
    c = new(rig, "Spawn", 3.2, nxt="Idle")
    L, u = c.length, rig.u
    a, b, s0, s1, look, back = 0.08 * L, 0.28 * L, 0.31 * L, 0.62 * L, 0.7 * L, 0.9 * L
    sp = sleep_pose(rig)
    crouch = {k: v for k, v in sp.items()}
    crouch[rig.neck[0] if rig.neck else "Head"] = P(rx=-20)
    crouch["Head"] = P(rx=-14)
    c.key(0, crouch)
    c.key(a, crouch)
    c.rest(b, kind="back")
    c.rest(L)
    fold = curve([(0, 1), (a, 1), (b, 0, "out")])
    fold_legs(c, lambda t: fold.at(t))
    pitch = curve([(0, 0), (b, 8, "back"), (s1, 4), (look, 6), (back, 2), (L, 0)])
    yaw = curve([(0, 0), (s1, 0), (look, 20, "inout"), (back, 18), (L, 0)])
    roll = curve([(0, 0), (s1, 0), (look, 10, "back"), (back, 8), (L, 0)])
    aim(c, yaw, pitch, roll)
    lids(c, lambda t: 1.0 - ramp(t, a, b - 0.04 * L, "out2"))
    blinks(c, [0.8 * L])
    sh = lambda t: shake(t, s0, s1, 6.0, 3.0)  # noqa: E731
    c.add("Hips", RZ, lambda t: 6 * sh(t))
    c.add("Chest", RZ, lambda t: -5 * sh(t - 0.02))
    c.add("Head", RY, lambda t: 10 * sh(t - 0.04))
    frill(c, lambda t: 7 * sh(t - 0.06))
    follow(c, lambda t: 8 * sh(t), rig.tail, RY, [0.8, 1.0, 1.2, 1.3, 1.4], 0.035)
    jaw(c, curve([(0, 0), (s0, 0), (s0 + 0.04 * L, 10), (s1, 6), (look, 0), (L, 0)]))
    return c


# ====================================================================== gardiens
def wake(rig):
    c = new(rig, "Wake", 2.0, nxt="Idle")
    L, u = c.length, rig.u
    jolt, up, sh0, sh1 = 0.12 * L, 0.55 * L, 0.58 * L, 0.88 * L
    sp = sleep_pose(rig)
    c.key(0, sp)
    c.key(jolt, merge(sp, {"Chest": P(py=0.08 * u)}), "snap")
    c.rest(up, kind="back")
    c.rest(L)
    fold = curve([(0, 1), (jolt, 0.85, "snap"), (up, 0, "out")])
    fold_legs(c, lambda t: fold.at(t))
    lids(c, lambda t: 1.0 - ramp(t, 0.04 * L, jolt, "snap"))
    pitch = curve([(0, 0), (jolt, 16, "snap"), (up, 8), (sh1, 4), (L, 0)])
    aim(c, None, pitch)
    c.add("Head", RY, lambda t: 16 * shake(t, sh0, sh1, 5.5, 1.5))
    frill(c, lambda t: 6 * shake(t - 0.05, sh0, sh1, 5.5, 1.5))
    jaw(c, curve([(0, 0), (jolt, 10, "snap"), (up, 0), (L, 0)]))
    return c


def catch(rig):
    """Charge tête basse puis relève les cornes d'un coup : le joueur est projeté (cartoon, sans blessure)."""
    c = new(rig, "Catch", 1.4, nxt="Idle")
    L, u = c.length, rig.u
    wind, hit, rec = 0.38 * L, 0.5 * L, 0.68 * L
    c.key(0, {"Hips": P(py=0, pz=0, rx=0), "Chest": P(rx=0, py=0)})
    c.key(wind, {"Hips": P(py=-0.05 * u, pz=0.12 * u, rx=2), "Chest": P(rx=-7, py=-0.1 * u)}, "inout")
    c.key(hit, {"Hips": P(py=-0.02 * u, pz=-0.32 * u, rx=-2), "Chest": P(rx=4, py=0.04 * u)}, "snap")
    c.key(rec, {"Hips": P(py=-0.02 * u, pz=-0.18 * u, rx=0), "Chest": P(rx=1, py=0)}, "back")
    c.rest(L)
    pitch = curve([(0, 0), (wind, -26), (hit - 0.04 * L, -24), (hit, 26, "snap"), (rec, 10, "back"), (L, 0)])
    aim(c, None, pitch)
    frill(c, lambda t: 7 * shake(t, hit, rec + 0.1 * L, 8.0, 3.0))
    c.add("Head", RZ, lambda t: 5 * shake(t, hit, rec + 0.1 * L, 7.0, 3.0))
    for name in FRONT:
        dr = c.drive(name)
        if dr:
            l = dr.limb
            step = curve([(0, 0), (wind, 0), (hit, 1, "snap"), (L, 1)])
            lift = curve([(0, 0), (wind, 0), (wind + 0.06 * L, 1, "out"), (hit, 0, "in2"), (L, 0)])
            dr.toe = (lambda t, l=l, step=step, lift=lift:
                      (l.toe0[0], l.toe0[1] + 0.12 * u * lift.at(t), l.toe0[2] - 0.3 * u * step.at(t)))
    c.event(hit, "Hit")
    c.event(hit, "Step", "HandL")
    tail_wave(c, 6, 0.5, RY, lag=0.06, env=lambda t: win(t, wind, L, 0.2))
    c.key(0, tail_lift(rig, 0))
    c.key(wind, tail_lift(rig, 10))
    c.key(L, tail_lift(rig, 0))
    return c


def search(rig):
    c = new(rig, "Search", 4.8, loop=True)
    L, u = c.length, rig.u
    s1, r0, l0, l1, rr0, rr1, f0 = 0.16 * L, 0.25 * L, 0.32 * L, 0.48 * L, 0.55 * L, 0.7 * L, 0.8 * L
    low = {"Chest": P(rx=-5, py=-0.06 * u)}
    c.key(0, low)
    c.key(s1, low)
    c.key(r0, {"Chest": P(rx=0, py=0)}, "inout")
    c.key(f0, {"Chest": P(rx=0, py=0)})
    c.key(L, low, "inout")
    pitch = curve([(0, -30), (s1, -30), (r0, 6, "out"), (l1, 4), (rr1, 4), (f0, 2), (L, -30, "inout")])
    yaw = curve([(0, 0), (r0, 0), (l0, 40, "inout"), (l1, 36), (rr0, -38, "inout"), (rr1, -34), (f0, 0, "inout"), (L, 0)])
    roll = curve([(0, 0), (l0, 6), (l1, 6), (rr0, -6), (rr1, -6), (f0, 10), (0.9 * L, 8), (L, 0)])
    aim(c, yaw, pitch, roll)
    c.add("Hips", RY, lambda t: 0.2 * yaw.at(t))
    c.add("Chest", RY, lambda t: 0.15 * yaw.at(t))
    c.add("Head", RX, lambda t: 3 * shake(t, 0.02 * L, s1, 6.0) + 3 * shake(t, 0.86 * L, L, 6.0))
    frill(c, lambda t: -0.08 * yaw.at(t) + 2 * shake(t, 0.02 * L, s1, 6.0))
    blinks(c, [0.5 * L, 0.75 * L])
    tail_wave(c, 5, L / 2, RY, lag=0.12)
    breathe(c, L / 3, 1.0)
    return c


def back_to_sleep(rig):
    c = new(rig, "BackToSleep", 3.8, nxt="Sleep")
    L, u = c.length, rig.u
    turn0, turn1, down, close = 0.06 * L, 0.58 * L, 0.88 * L, 0.92 * L
    sp = sleep_pose(rig)
    c.key(0, {b: {ch: 0.0 for ch in chans} for b, chans in sp.items()})
    c.key(turn1, {b: {ch: 0.0 for ch in chans} for b, chans in sp.items()})
    c.key(down, sp, "inout")
    c.key(L, sp)
    spin = curve([(0, 0), (turn0, 0), (turn1, 360, "inout"), (L, 360)])
    c.add("Hips", RY, lambda t: spin.at(t))
    steps = 8

    def stomp(t, ph):
        if t < turn0 or t > turn1:
            return 0.0
        q = (t - turn0) / (turn1 - turn0) * steps + ph
        return max(0.0, math.sin(math.pi * (q % 1.0))) if int(q) % 2 == 0 else 0.0

    def rel(t):
        return win(t, turn0 - 0.02 * L, turn1 + 0.02 * L, 0.06)
    fold = curve([(0, 0), (turn1, 0), (down, 1, "inout"), (L, 1)])
    fold_legs(c, lambda t: fold.at(t))
    for name, ph in (("LegL", 0.0), ("FrontR", 0.0), ("LegR", 1.0), ("FrontL", 1.0)):
        dr = c.drive(name)
        if dr:
            dr.rel = rel
            dr.rel_toe = lambda t, ph=ph: (0, 0.1 * u * stomp(t, ph), 0)
    pitch = curve([(0, 0), (turn0, -8), (turn1, -10), (down, 0), (L, 0)])
    aim(c, None, pitch)
    lids(c, lambda t: ramp(t, close - 0.08 * L, L - 0.02 * L, "inout"))
    jaw(c, curve([(0, 0), (turn1 + 0.04 * L, 0), (turn1 + 0.12 * L, 26), (down, 0), (L, 0)]))
    c.add("Hips", PY, lambda t: -0.04 * u * shake(t, turn0, turn1, steps / (turn1 - turn0) / 2))
    return c


def fusion(rig):
    c = new(rig, "Fusion", 1.3, loop=True)
    L, u = c.length, rig.u
    for dr in c.drives.values():
        dr.weight = lambda t: 0.0
    c.key(0, {"Hips": P(py=0.2 * u, rx=-8), "Chest": P(rx=6)})
    f = 2.0 / L
    for b, ph in (("ThighL", 0.0), ("ThighR", 0.5), ("ArmL", 0.5), ("ArmR", 0.0)):
        if b in rig.has:
            c.add(b, RX, lambda t, ph=ph: 28 * math.sin(2 * math.pi * (f * t - ph)))
    for b, ph in (("ShinL", 0.0), ("ShinR", 0.5)):
        if b in rig.has:
            c.add(b, RX, lambda t, ph=ph: -20 + 20 * math.sin(2 * math.pi * (f * t - ph - 0.2)))
    for b, ph in (("ForearmL", 0.5), ("ForearmR", 0.0)):
        if b in rig.has:
            c.add(b, RX, lambda t, ph=ph: 20 + 20 * math.sin(2 * math.pi * (f * t - ph - 0.2)))
    yaw = curve([(0, 0), (0.25 * L, 26), (0.5 * L, -24), (0.75 * L, 22), (L, 0)])
    pitch = curve([(0, 8), (0.5 * L, 16), (L, 8)])
    aim(c, yaw, pitch)
    jaw(c, curve([(0, 22), (0.5 * L, 30), (L, 22)]))
    frill(c, lambda t: 6 * math.sin(2 * math.pi * 3 * t / L))
    tail_wave(c, 18, L / 2, RY, lag=0.07)
    tail_wave(c, 8, L / 3, RX, lag=0.07)
    return c


def index_pose(rig):
    c = new(rig, "Index", 4.6, loop=True)
    L, u = c.length, rig.u
    proud = merge({"Hips": P(rx=2), "Chest": P(rx=5, py=0.04 * u)}, tail_lift(rig, 6))
    c.key(0, proud)
    c.key(L, proud)
    dr = c.drive("FrontL")
    if dr:
        l = dr.limb
        dr.toe = lambda t: (l.toe0[0] - 0.03 * u, l.toe0[1], l.toe0[2] - 0.2 * u)
    yaw = curve([(0, 16), (0.45 * L, 16), (0.55 * L, 10), (0.62 * L, 18, "back"), (L, 16)])
    pitch = curve([(0, 12), (0.45 * L, 12), (0.55 * L, 22, "snap"), (0.66 * L, 10, "back"), (L, 12)])
    roll = curve([(0, 5), (0.5 * L, 5), (0.58 * L, -6, "snap"), (0.7 * L, 5, "inout"), (L, 5)])
    aim(c, yaw, pitch, roll)
    frill(c, lambda t: -3 + 3 * shake(t, 0.55 * L, 0.75 * L, 6.0, 2.0))
    breathe(c, L / 2, 1.4)
    tail_wave(c, 6, L, RY, lag=0.14)
    blinks(c, [0.3 * L, 0.82 * L])
    jaw(c, curve([(0, 0), (0.53 * L, 0), (0.58 * L, 14, "snap"), (0.68 * L, 0), (L, 0)]))
    return c


def build(rig):
    clips = [idle(rig), idle_sniff(rig), idle_scratch(rig), idle_stretch(rig), idle_shake(rig), idle_yawn(rig),
             walk(rig), walk(rig, "Run", 0.62, run=True), happy(rig), roar(rig), eat(rig), sleep(rig), spawn(rig),
             wake(rig), catch(rig), search(rig), back_to_sleep(rig), fusion(rig), index_pose(rig)]
    return {c.name: c for c in clips}
