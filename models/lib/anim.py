"""anim : écriture des animations (clés + couches + IK des pattes), échantillonnage et réduction des clés.

Pur Python. Une animation (Clip) = des pistes (os, canal) avec des clés (t, valeur, courbe d'arrivée), des couches
additives f(t) (souffle, ondulation de queue, tremblement...), et des membres en IK (cuisse, jambe, pied) dont les
pieds restent posés au sol quand le corps bouge. Canaux : 0 rx, 1 ry, 2 rz (degrés), 3 px, 4 py, 5 pz (studs).

    c = Clip(rig, "Roar", 2.2)
    c.key(0.0, {"Head": P(rx=0)})
    c.key(0.5, {"Head": P(rx=-12), "Jaw": P(rx=0)}, "inout")         # anticipation
    c.key(0.8, {"Head": P(rx=28), "Jaw": P(rx=-40)}, "back")          # rugissement (dépasse puis revient)
    c.add("Head", RY, lambda t: 2 * shake(t, 0.8, 1.6, 13))           # couche additive
    c.rest(2.2)                                                        # tout revient au repos
"""
from __future__ import annotations

import math

from rig import ang, ik2, inverse, apply, mvec, pitch_in, rot, sub, add, compose, IDENT

RX, RY, RZ, PX, PY, PZ = range(6)
CH = {"rx": RX, "ry": RY, "rz": RZ, "px": PX, "py": PY, "pz": PZ}


def clamp(x, a=0.0, b=1.0):
    return a if x < a else b if x > b else x


def smooth(x):
    x = clamp(x)
    return x * x * (3 - 2 * x)


def ease(kind, x):
    x = clamp(x)
    if kind == "inout":
        return 0.5 - 0.5 * math.cos(math.pi * x)
    if kind == "in":
        return x * x * x
    if kind == "in2":
        return x * x
    if kind == "out":
        return 1 - (1 - x) ** 3
    if kind == "out2":
        return 1 - (1 - x) ** 2
    if kind == "snap":
        return 1 - (1 - x) ** 5
    if kind == "back":  # dépasse la cible puis revient
        c1 = 1.70158
        return 1 + (c1 + 1) * (x - 1) ** 3 + c1 * (x - 1) ** 2
    if kind == "back2":  # dépassement plus fort
        c1 = 2.6
        return 1 + (c1 + 1) * (x - 1) ** 3 + c1 * (x - 1) ** 2
    if kind == "elastic":
        if x <= 0 or x >= 1:
            return x
        return 2 ** (-9 * x) * math.sin((x * 10 - 0.75) * (2 * math.pi / 3)) + 1
    if kind == "lin":
        return x
    if kind == "hold":
        return 0.0 if x < 1 else 1.0
    return smooth(x)


def P(**kw):
    """Pose partielle d'un os : P(rx=20, py=-0.3) -> {0: 20, 4: -0.3}."""
    return {CH[k]: float(v) for k, v in kw.items() if v is not None}


# ---------------------------------------------------------------------- petites fonctions de temps
def win(t, a, b, fade=0.25):
    """Enveloppe 0 -> 1 -> 0 entre a et b (fondu = part de la durée)."""
    if t <= a or t >= b:
        return 0.0
    p = (t - a) / (b - a)
    return smooth(p / fade) * smooth((1 - p) / fade)


def ramp(t, a, b, k="inout"):
    return ease(k, (t - a) / max(b - a, 1e-6))


def bump(t, a, b):
    if t <= a or t >= b:
        return 0.0
    return math.sin(math.pi * (t - a) / (b - a))


def shake(t, a, b, freq, decay=0.0):
    """Tremblement sinusoïdal entre a et b, amorti si decay > 0, avec fondus."""
    if t <= a or t >= b:
        return 0.0
    e = win(t, a, b, 0.12)
    return e * math.sin(2 * math.pi * freq * (t - a)) * math.exp(-decay * (t - a))


def osc(t, period, phase=0.0):
    return math.sin(2 * math.pi * (t / period - phase))


class Track:
    __slots__ = ("keys",)

    def __init__(self):
        self.keys = []  # (t, v, ease)

    def put(self, t, v, kind):
        self.keys = [k for k in self.keys if abs(k[0] - t) > 1e-6]
        self.keys.append((t, v, kind))
        self.keys.sort(key=lambda k: k[0])

    def at(self, t):
        ks = self.keys
        if not ks:
            return 0.0
        if t <= ks[0][0]:
            return ks[0][1]
        for a, b in zip(ks, ks[1:]):
            if t <= b[0]:
                return a[1] + (b[1] - a[1]) * ease(b[2], (t - a[0]) / max(b[0] - a[0], 1e-9))
        return ks[-1][1]


class Limb:
    """Membre en IK : os1 (cuisse / bras), os2 (jambe / avant-bras), os3 (pied / main, facultatif).
    Le bout (toe) est le point du pied qui touche le sol. Par défaut il reste posé à sa place de repos."""

    def __init__(self, name, bones, parent, bend, toe0, sk):
        self.name = name
        self.bones = bones
        self.parent = parent
        self.bend = bend
        self.toe0 = tuple(toe0)
        self.hip0 = sk.pivot[bones[0]]
        self.knee0 = sk.pivot[bones[1]]
        self.ankle0 = sk.pivot[bones[2]] if len(bones) > 2 else tuple(toe0)
        self.foot = len(bones) > 2


def lerp_vec(a, b, k):
    return (a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k)


def keep_below(l, a):
    """Garde la cible de la cheville sous la hanche et pas trop près d'elle (sinon l'IK retourne la patte)."""
    hy, hz = l.hip0[1], l.hip0[2]
    l1 = math.hypot(l.knee0[1] - hy, l.knee0[2] - hz)
    l2 = math.hypot(l.ankle0[1] - l.knee0[1], l.ankle0[2] - l.knee0[2])
    top = hy - 0.25 * (l1 + l2)
    y = min(a[1], top)
    dy, dz = y - hy, a[2] - hz
    d = math.hypot(dy, dz)
    dmin = max(abs(l1 - l2) * 1.05, 0.3 * (l1 + l2))
    if d < dmin and d > 1e-6:
        k = dmin / d
        dy, dz = dy * k, dz * k
    return (a[0], hy + dy, hz + dz)


class LimbDrive:
    """Ce qu'une animation demande à un membre (fonctions du temps)."""

    def __init__(self, limb):
        self.limb = limb
        self.toe = None        # f(t) -> (x, y, z) monde ; None = position de repos
        self.rel = None        # f(t) -> 0..1 : 1 = le pied suit le corps (en l'air), 0 = posé au monde
        self.rel_toe = None    # f(t) -> décalage (x, y, z) dans l'espace du parent quand rel > 0
        self.tilt = None       # f(t) -> rotation du pied (degrés, autour de X, monde) par rapport au repos
        self.weight = None     # f(t) -> 0..1 : part de l'IK (0 = angles écrits à la main)


class Clip:
    def __init__(self, rig, name, length, loop=False, nxt=None):
        self.rig = rig
        self.sk = rig.sk
        self.name = name
        self.length = float(length)
        self.loop = loop
        self.next = nxt
        self.speed = None      # studs/s à l'échelle 1 pour les marches (le jeu cale la cadence sur la vitesse)
        self.tracks = {}
        self.layers = []
        self.events = []
        self.drives = {name: LimbDrive(l) for name, l in rig.limbs.items()}
        self.forced = set()    # instants qui gardent une clé (impacts)
        self.procs = []        # f(t, pose) : poses calculées (ailes orientées, IK 3D), après clés et couches

    # ------------------------------------------------------------- écriture
    def key(self, t, poses, kind="inout"):
        for bone, chans in poses.items():
            if bone not in self.sk.pivot:
                continue
            for ch, v in chans.items():
                self.tracks.setdefault((bone, ch), Track()).put(float(t), float(v), kind)

    def keyall(self, t, bones, chans, kind="inout"):
        for b in bones:
            self.key(t, {b: dict(chans)}, kind)

    def rest(self, t, bones=None, kind="inout"):
        """Clé à 0 à l'instant t pour toutes les pistes déjà écrites (ou seulement ces os)."""
        for (bone, ch), tr in self.tracks.items():
            if bones is None or bone in bones:
                tr.put(float(t), 0.0, kind)

    def hold(self, t, bones=None):
        """Clé qui garde la valeur courante à l'instant t (pour tenir une pose)."""
        for (bone, ch), tr in self.tracks.items():
            if bones is None or bone in bones:
                tr.put(float(t), tr.at(t), "inout")

    def add(self, bone, ch, fn):
        if bone in self.sk.pivot:
            self.layers.append((bone, ch, fn))

    def event(self, t, kind, data=None):
        self.events.append((round(float(t), 3), kind, data))
        self.forced.add(float(t))

    def drive(self, limb):
        return self.drives.get(limb)

    # ------------------------------------------------------------- lecture
    def base(self, bone, ch, t):
        tr = self.tracks.get((bone, ch))
        return tr.at(t) if tr else 0.0

    def channels(self):
        out = set(self.tracks)
        for bone, ch, _ in self.layers:
            out.add((bone, ch))
        return out

    def pose_at(self, t):
        """Pose écrite (clés + couches) puis IK des membres."""
        pose = {}
        for (bone, ch), tr in self.tracks.items():
            pose.setdefault(bone, [0.0] * 6)[ch] += tr.at(t)
        for bone, ch, fn in self.layers:
            pose.setdefault(bone, [0.0] * 6)[ch] += fn(t)
        for fn in self.procs:
            fn(t, pose)
        cache = {}
        for name, dr in self.drives.items():
            w = dr.weight(t) if dr.weight else 1.0
            if w <= 0:
                continue
            l = dr.limb
            M = self.sk.world(l.parent, pose, cache)
            toe_w = dr.toe(t) if dr.toe else l.toe0
            rel = dr.rel(t) if dr.rel else 0.0
            if rel > 0:
                off = dr.rel_toe(t) if dr.rel_toe else (0.0, 0.0, 0.0)
                toe_b = apply(M, add(l.toe0, off))
                toe_w = tuple(toe_w[i] + (toe_b[i] - toe_w[i]) * rel for i in range(3))
            tilt = dr.tilt(t) if dr.tilt else 0.0
            Rf = rot(tilt, 0, 0)
            if l.foot:
                # pied : la cheville se déduit du bout et de l'inclinaison du pied (rotation autour du bout) ;
                # au sol l'inclinaison est prise dans le monde, en l'air (rel) elle suit le corps
                foot_vec = mvec(Rf, sub(l.ankle0, l.toe0))
                if rel > 0:
                    foot_vec = lerp_vec(foot_vec, mvec(M[0], foot_vec), rel)
                ankle_w = add(toe_w, foot_vec)
            else:
                ankle_w = toe_w
            Mi = inverse(M)
            a_loc = apply(Mi, ankle_w)
            a_loc = keep_below(l, a_loc)
            r1, r2 = ik2(l.hip0, l.knee0, l.ankle0, a_loc, l.bend)
            for b, r in ((l.bones[0], r1), (l.bones[1], r2)):
                v = pose.setdefault(b, [0.0] * 6)
                v[0] = v[0] * (1 - w) + r * w
            if l.foot:
                # inclinaison voulue du pied (monde) ramenée dans l'espace du parent
                rest_vec = sub(l.toe0, l.ankle0)
                want = mvec(Rf, rest_vec)
                if rel > 0:
                    want = lerp_vec(want, mvec(M[0], want), rel)
                a_want = pitch_in(M, want)
                a_rest = ang(rest_vec[1], rest_vec[2])
                r3 = math.degrees(math.atan2(math.sin(a_want - a_rest), math.cos(a_want - a_rest))) - r1 - r2
                v = pose.setdefault(l.bones[2], [0.0] * 6)
                v[0] = v[0] * (1 - w) + r3 * w
        return pose

    def sample(self, fps=60):
        n = max(2, int(round(self.length * fps)))
        times = [self.length * i / n for i in range(n + 1)]
        frames = [self.pose_at(t) for t in times]
        # angles continus d'une image à l'autre (pas de saut de 360 degrés)
        prev = {}
        for f in frames:
            for bone, v in f.items():
                p = prev.get(bone)
                if p:
                    for ch in range(3):
                        while v[ch] - p[ch] > 180:
                            v[ch] -= 360
                        while v[ch] - p[ch] < -180:
                            v[ch] += 360
                prev[bone] = v
        return times, frames


# ---------------------------------------------------------------------- lecture du jeu : cubique monotone (pchip)
# Le jeu (DinoBuilder.Sample) interpole chaque piste avec une cubique d'Hermite dont les pentes sont celles de pchip
# (Fritsch-Butland) : pente nulle aux extremums (pas de dépassement), pente continue ailleurs (pas d'arrêt à chaque
# clé). Bouts d'une animation simple : pente nulle. Boucle : la pente du début est celle de la fin (raccord lisse).
def _pchip(d0, d1, h0, h1):
    if d0 * d1 <= 0:
        return 0.0
    w1, w2 = 2 * h1 + h0, h1 + 2 * h0
    return (w1 + w2) / (w1 / d0 + w2 / d1)


def tangents(t, v, loop):
    k = len(t)
    m = [0.0] * k
    if k < 3:
        return m
    h = [t[j + 1] - t[j] for j in range(k - 1)]
    d = [(v[j + 1] - v[j]) / h[j] if h[j] > 1e-9 else 0.0 for j in range(k - 1)]
    for j in range(1, k - 1):
        m[j] = _pchip(d[j - 1], d[j], h[j - 1], h[j])
    if loop:
        m[0] = _pchip(d[k - 2], d[0], h[k - 2], h[0])
        m[k - 1] = m[0]
    return m


def hermite(ta, va, ma, tb, vb, mb, t):
    h = tb - ta
    if h <= 1e-9:
        return vb
    x = (t - ta) / h
    x2 = x * x
    x3 = x2 * x
    return (2 * x3 - 3 * x2 + 1) * va + (x3 - 2 * x2 + x) * h * ma + (-2 * x3 + 3 * x2) * vb + (x3 - x2) * h * mb


def _recon_error(T, V, idx, loop):
    t = [T[i] for i in idx]
    v = [V[i] for i in idx]
    m = tangents(t, v, loop)
    worst, wi = 0.0, -1
    for j in range(len(idx) - 1):
        a, b = idx[j], idx[j + 1]
        for i in range(a + 1, b):
            e = abs(hermite(t[j], v[j], m[j], t[j + 1], v[j + 1], m[j + 1], T[i]) - V[i])
            if e > worst:
                worst, wi = e, i
    return worst, wi


def reduce_track(T, V, tol, forced=(), loop=False):
    """Garde le moins de clés possible pour que la lecture du jeu (cubique monotone) reste à moins de `tol`
    partout. T, V : listes. Renvoie la liste des indices gardés."""
    n = len(T)
    if loop:
        V = list(V)
        V[-1] = V[0]
    keys = {0, n - 1}
    for f in forced:
        keys.add(min(range(n), key=lambda j: abs(T[j] - f)))
    # extremums marqués (les petites bosses sous la tolérance sont ignorées)
    last = V[0]
    for i in range(1, n - 1):
        a, b = V[i] - V[i - 1], V[i + 1] - V[i]
        if a * b < 0 and abs(V[i] - last) > 2 * tol:
            keys.add(i)
            last = V[i]
    while True:
        idx = sorted(keys)
        worst, wi = _recon_error(T, V, idx, loop)
        if worst <= tol or wi < 0:
            return idx
        keys.add(wi)


def bake(clip, times, frames, tol_deg=0.6, tol_stud=0.018):
    """Pistes réduites : {(os, canal): [(t, v), ...]} ; les pistes nulles partout sont retirées."""
    chans = {}
    for f in frames:
        for bone, v in f.items():
            for ch in range(6):
                if abs(v[ch]) > 1e-4:
                    chans[(bone, ch)] = True
    out = {}
    unit = max(1.0, clip.rig.height / 8.0)
    for (bone, ch) in sorted(chans, key=lambda k: (clip.sk.order.index(k[0]), k[1])):
        V = [f.get(bone, [0.0] * 6)[ch] for f in frames]
        if max(abs(x) for x in V) < (0.15 if ch < 3 else 0.004 * unit):
            continue
        tol = tol_deg if ch < 3 else tol_stud * unit
        idx = reduce_track(times, V, tol, clip.forced, clip.loop)
        d = 1 if ch < 3 else 3
        vals = [(round(times[i] * 60) / 60, round(V[i], d)) for i in idx]
        if clip.loop:
            vals[-1] = (vals[-1][0], vals[0][1])
        out[(bone, ch)] = vals
    return out


def game_sample(tracks, t, length, loop, cache=None):
    """Même lecture que DinoBuilder.Sample (cubique monotone par piste)."""
    if loop and length > 0:
        t = t % length
    pose = {}
    for key, keys in tracks.items():
        bone, ch = key
        tt = [k[0] for k in keys]
        vv = [k[1] for k in keys]
        if cache is not None and key in cache:
            m = cache[key]
        else:
            m = tangents(tt, vv, loop)
            if cache is not None:
                cache[key] = m
        if t <= tt[0]:
            v = vv[0]
        elif t >= tt[-1]:
            v = vv[-1]
        else:
            v = vv[-1]
            for j in range(len(tt) - 1):
                if t <= tt[j + 1]:
                    v = hermite(tt[j], vv[j], m[j], tt[j + 1], vv[j + 1], m[j + 1], t)
                    break
        pose.setdefault(bone, [0.0] * 6)[ch] = v
    return pose
