"""motion : briques d'animation communes aux familles (souffle, clignements, regard, queue, marche en IK, sauts).

Toutes les briques ajoutent des couches additives à un Clip (anim.py) ; elles ne se marchent pas dessus et
s'ajoutent aux clés écrites à la main. Unité de déplacement : rig.u = hauteur de hanche en studs."""
from __future__ import annotations

import math

from anim import PX, PY, PZ, RX, RY, RZ, Track, bump, clamp, ease, ramp, smooth, win  # noqa: F401


def curve(points, kind="inout"):
    """Courbe à clés [(t, v)] ou [(t, v, courbe)] (évaluée par Track.at)."""
    tr = Track()
    for p in points:
        tr.put(float(p[0]), float(p[1]), p[2] if len(p) > 2 else kind)
    return tr


def fit_period(length, period):
    """Période ajustée pour tomber juste dans une boucle."""
    n = max(1, round(length / period))
    return length / n


def wrapt(c, t):
    return t % c.length if c.loop else t


# ---------------------------------------------------------------------- souffle, yeux
def breathe(c, period, amp=1.0, env=None):
    rig = c.rig
    per = fit_period(c.length, period) if c.loop else period
    e = env or (lambda t: 1.0)

    def s(t):
        return math.sin(2 * math.pi * t / per) * e(t)
    c.add("Chest", RX, lambda t: 1.6 * amp * s(t))
    c.add("Chest", PY, lambda t: 0.012 * rig.u * amp * s(t))
    if rig.neck:
        c.add(rig.neck[0], RX, lambda t: -1.2 * amp * s(t))
    c.add("Hips", PY, lambda t: 0.008 * rig.u * amp * s(t))


def blink_amount(t, at, dur=0.2):
    a, b = at - dur * 0.35, at + dur * 0.65
    if t <= a or t >= b:
        return 0.0
    if t < at:
        return ease("in2", (t - a) / (at - a))
    return 1 - ease("out2", (t - at) / (b - at))


def lids(c, amount):
    """amount(t) : 0 ouvert, 1 fermé. Les paupières descendent devant les yeux."""
    rig = c.rig
    for lid, sx in (("LidL", -1.0), ("LidR", 1.0)):
        if lid in rig.has:
            c.add(lid, PY, lambda t: -rig.lid_drop * amount(t))
            c.add(lid, PX, lambda t, sx=sx: sx * 0.04 * rig.voxel * min(1.0, amount(t) * 4))


def blinks(c, times, dur=0.2):
    lids(c, lambda t: max([blink_amount(t, a, dur) for a in times] + [0.0]))


# ---------------------------------------------------------------------- regard (cou + tête)
def neck_spread(rig):
    n = len(rig.neck)
    if n == 0:
        return {"Head": 1.0}
    if n == 1:
        return {rig.neck[0]: 0.4, "Head": 0.6}
    if n == 2:
        return {rig.neck[0]: 0.25, rig.neck[1]: 0.3, "Head": 0.45}
    out = {b: 0.55 / n for b in rig.neck}
    out["Head"] = 0.45
    return out


def aim(c, yaw=None, pitch=None, roll=None, spread=None):
    """Regard réparti sur le cou et la tête. yaw > 0 : regarde à gauche ; pitch > 0 : lève la tête."""
    sp = spread or neck_spread(c.rig)
    for b, k in sp.items():
        if yaw is not None:
            c.add(b, RY, lambda t, k=k: k * yaw.at(t))
        if pitch is not None:
            c.add(b, RX, lambda t, k=k: k * pitch.at(t))
        if roll is not None and b == "Head":
            c.add(b, RZ, lambda t: roll.at(t))


def jaw(c, tr):
    """Ouverture de la mâchoire en degrés (valeur positive = gueule ouverte)."""
    if "Jaw" in c.rig.has:
        c.add("Jaw", RX, lambda t: -tr.at(t))


# ---------------------------------------------------------------------- queue et chaînes
def tail_wave(c, amp, period, ch=RY, lag=0.08, env=None, phase=0.0, chain=None):
    """Onde qui descend la queue (amplitude croissante vers le bout). Boucle sans à-coup si period divise la durée."""
    chain = chain or c.rig.tail
    n = len(chain)
    if n == 0:
        return
    per = fit_period(c.length, period) if c.loop else period
    e = env or (lambda t: 1.0)
    for i, b in enumerate(chain):
        w = 0.55 + 0.45 * i / max(1, n - 1)
        c.add(b, ch, lambda t, i=i, w=w: amp * w * e(t) * math.sin(2 * math.pi * ((t - i * lag) / per - phase)))


def follow(c, src, chain, ch, gains, lag):
    """Retard en chaîne : chaque segment reprend la valeur de `src` avec un temps de retard (queue qui suit)."""
    for i, b in enumerate(chain):
        g = gains[i] if isinstance(gains, (list, tuple)) else gains
        c.add(b, ch, lambda t, i=i, g=g: g * src(wrapt(c, t - (i + 1) * lag)))


def curl(chain, total, ch=RY, bias=1.2):
    """Pose de chaîne enroulée : angle total réparti, plus fort vers le bout. -> {os: {canal: v}}."""
    n = len(chain)
    w = [bias ** i for i in range(n)]
    s = sum(w)
    return {b: {ch: total * w[i] / s} for i, b in enumerate(chain)}


def merge(*poses):
    out = {}
    for p in poses:
        for b, chans in p.items():
            d = out.setdefault(b, {})
            for ch, v in chans.items():
                d[ch] = d.get(ch, 0.0) + v
    return out


# ---------------------------------------------------------------------- marche en IK
def swing_lift(u):
    u = clamp(u)
    return math.sin(math.pi * u ** 0.8) * (1 - 0.15 * u)


def gait(c, phases, T, S, beta, lift, heel=18.0, curl_deg=30.0, start=0.0, env=None, lift_scale=None):
    """Pieds posés au sol qui reculent pendant l'appui puis reviennent en arc (marche sur place, le sol défile).
    phases : {membre: décalage 0..1}. S : longueur d'un cycle (studs). beta : part du cycle au sol."""
    e = env or (lambda t: 1.0)
    for name, ph in phases.items():
        dr = c.drive(name)
        if dr is None:
            continue
        l = dr.limb
        x0, y0, z0 = l.toe0
        ls = (lift_scale or {}).get(name, 1.0)

        def p_of(t, ph=ph):
            return ((t - start) / T - ph) % 1.0

        def toe(t, p_of=p_of, x0=x0, y0=y0, z0=z0, ls=ls):
            k = e(t)
            p = p_of(t)
            if p < beta:
                z = z0 - beta * S / 2 + p * S
                y = 0.0
            else:
                # retour en avant : cubique d'Hermite dont les vitesses aux bouts sont celles de l'appui (pas de
                # cassure au décollage ni à la pose, le pied « accompagne » le sol avant de le quitter)
                u = (p - beta) / (1 - beta)
                za, zb, m = z0 + beta * S / 2, z0 - beta * S / 2, S * (1 - beta)
                u2, u3 = u * u, u * u * u
                z = (2 * u3 - 3 * u2 + 1) * za + (u3 - 2 * u2 + u) * m + (-2 * u3 + 3 * u2) * zb + (u3 - u2) * m
                y = lift * ls * swing_lift(u)
            return (x0, y0 + y * k, z0 + (z - z0) * k)

        def tilt(t, p_of=p_of):
            k = e(t)
            p = p_of(t)
            if p < beta:
                return -heel * ease("in2", clamp((p - 0.55 * beta) / (0.45 * beta))) * k
            u = (p - beta) / (1 - beta)
            return -(heel * (1 - u) + curl_deg * math.sin(math.pi * u)) * k

        dr.toe = toe
        dr.tilt = tilt


def step_phase(t, T, ph):
    return ((t / T) - ph) % 1.0


def airborne(c, t_off, t_land, tuck=None, fade=0.05):
    """Pieds qui quittent le sol entre t_off et t_land (ils suivent le corps). tuck(t) -> (x, y, z) dans l'espace du
    parent pour replier les pattes en l'air."""
    def rel(t):
        if t <= t_off - fade or t >= t_land + fade:
            return 0.0
        if t < t_off + fade:
            return smooth((t - (t_off - fade)) / (2 * fade))
        if t > t_land - fade:
            return 1 - smooth((t - (t_land - fade)) / (2 * fade))
        return 1.0
    for dr in c.drives.values():
        dr.rel = rel
        if tuck:
            dr.rel_toe = tuck


def tail_lift(rig, deg):
    """Relève (deg > 0) ou baisse la queue, réparti sur les segments (rx < 0 lève une chaîne tournée vers +Z)."""
    n = len(rig.tail)
    return {b: {RX: -deg * (0.5 if i == 0 else 0.5 / max(1, n - 1))} for i, b in enumerate(rig.tail)}


def fold_legs(c, amount):
    """Pattes repliées sous le corps (couché) quand amount(t) = 1 : le métatarse se pose à plat au sol."""
    rig = c.rig
    for name, dr in c.drives.items():
        l = dr.limb
        fx, fy, fz = l.ankle0[0] - l.toe0[0], l.ankle0[1] - l.toe0[1], l.ankle0[2] - l.toe0[2]
        flat = math.degrees(math.atan2(fy, fz))  # rotation qui couche le pied

        def toe(t, l=l):
            a = amount(t)
            return (l.toe0[0], l.toe0[1], l.toe0[2] + 0.12 * rig.u * a)

        def tilt(t, flat=flat):
            return flat * amount(t)
        dr.toe = toe
        dr.tilt = tilt


def airborne_multi(c, spans, tuck=None, fade=0.05):
    def rel(t):
        v = 0.0
        for a, b in spans:
            if a - fade < t < b + fade:
                if t < a + fade:
                    v = max(v, smooth((t - (a - fade)) / (2 * fade)))
                elif t > b - fade:
                    v = max(v, 1 - smooth((t - (b - fade)) / (2 * fade)))
                else:
                    v = 1.0
        return v
    for dr in c.drives.values():
        dr.rel = rel
        if tuck:
            dr.rel_toe = tuck
