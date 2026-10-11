"""Famille Flyer (Pteranodon, Quetzalcoatlus) : tous les états du GDD + TakeOff, Fly, Glide, Land.

Modèle construit ailes déployées (repos = plaques horizontales). Os : Hips, Chest, Neck1..N, Head, Jaw, LidL/R,
Wing1/2/3 L/R (bras, avant-bras + main, doigt-aile ; membrane portée par les trois), Thigh/Shin/Foot L/R, Tail1..N.
Points : HandL/R (griffes de la main, au sol quand il marche), WingTipL/R, ToeL/R.

Les ailes sont posées par orientation (axe de l'os + normale de la membrane) : repliées le long du corps au sol,
déployées en vol, avec battement, balayage et flexion du poignet. Au sol, une IK à deux os en 3D pose les mains
(marche sur les ailes repliées). Les pattes arrière sont en IK comme chez les bipèdes."""
from __future__ import annotations

import math

from anim import PX, PY, PZ, RX, RY, RZ, Clip, P, bump, clamp, ease, ramp, shake, smooth, win
from motion import (aim, airborne_multi, blinks, breathe, curl, curve, fit_period, fold_legs, follow, gait, jaw, lids,
                    merge, tail_lift, tail_wave, swing_lift)
from rig import (add, apply, axis_angle, euler, frame_rotation, ik2_3d, inverse, mmul, mvec, norm, rot, sub, transpose,
                 I3)

# directions repliées (espace du torse, aile gauche) : bras vers le bas et l'arrière, avant-bras vers le sol,
# doigt-aile replié vers le haut le long du corps ; membrane tournée vers l'extérieur
FOLD = {
    "Wing1": ((-0.42, -0.5, 0.76), (-1.0, 0.0, 0.0)),
    "Wing2": ((-0.12, -0.92, -0.38), (-1.0, 0.0, 0.0)),
    "Wing3": ((0.08, 0.5, 0.86), (-1.0, 0.0, 0.0)),
}
# directions déployées (aile gauche) avant battement
SPREAD = {
    "Wing1": ((-1.0, 0.06, -0.02), (0.0, 1.0, 0.0)),
    "Wing2": ((-1.0, 0.02, -0.06), (0.0, 1.0, 0.0)),
    "Wing3": ((-0.96, -0.02, 0.27), (0.0, 1.0, 0.0)),
}


def new(rig, name, base, loop=False, nxt=None):
    return Clip(rig, name, rig.T(base), loop, nxt)


def const(v):
    return lambda t: v


def _mirror(v):
    return (-v[0], v[1], v[2])


def _nlerp(a, b, k):
    return norm((a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k))


class Wings:
    """Commande des deux ailes d'une animation (courbes du temps) :
    fold 0 déployé -> 1 replié ; flap (degrés, > 0 = ailes vers le haut) ; sweep (> 0 = bouts vers l'arrière) ;
    flex (poignet replié en remontée, degrés) ; ground 0..1 = mains posées au sol (IK) ; hand(side, t) cible monde."""

    def __init__(self, c):
        self.c = c
        self.rig = c.rig
        sk = c.sk
        self.sk = sk
        self.fold = const(1.0)
        self.flap = const(0.0)
        self.sweep = const(0.0)
        self.flex = const(0.0)
        self.ground = const(1.0)
        self.lag = 0.05
        self.side_flap = {"L": const(0.0), "R": const(0.0)}  # en plus, par côté (une aile levée...)
        self.side_fold = {"L": const(0.0), "R": const(0.0)}
        self.hand = {}
        self.base_hand = {}
        pts = self.rig.model["points"]
        self.rest = {}
        for s in ("L", "R"):
            p1, p2, p3 = sk.pivot["Wing1" + s], sk.pivot["Wing2" + s], sk.pivot["Wing3" + s]
            tip = tuple(pts["WingTip" + s]["p"])
            self.rest[s] = {
                "Wing1": (norm(sub(p2, p1)), (0.0, 1.0, 0.0)),
                "Wing2": (norm(sub(p3, p2)), (0.0, 1.0, 0.0)),
                "Wing3": (norm(sub(tip, p3)), (0.0, 1.0, 0.0)),
            }
            self.base_hand[s] = tuple(pts["Hand" + s]["p"])
        c.procs.append(self.solve)

    def dirs(self, s, t):
        """Directions voulues (espace du torse) des trois os d'une aile à l'instant t."""
        fold = clamp(self.fold(t) + self.side_fold[s](t))
        out = {}
        for i, b in enumerate(("Wing1", "Wing2", "Wing3")):
            lag = self.lag * i
            fl = self.flap(t - lag) + self.side_flap[s](t - lag)
            sw = self.sweep(t) + (self.flex(t - lag) if b == "Wing3" else 0.0) + (0.4 * self.flex(t) if b == "Wing2" else 0.0)
            ax, nm = SPREAD[b]
            R = mmul(rot(0, 0, -fl), rot(0, sw, 0))  # aile gauche : battement autour de Z, balayage autour de Y
            ax, nm = mvec(R, ax), mvec(R, nm)
            fax, fnm = FOLD[b]
            ax, nm = _nlerp(ax, fax, fold), _nlerp(nm, fnm, fold)
            if s == "R":
                ax, nm = _mirror(ax), _mirror(nm)
            out[b] = (ax, nm)
        return out

    def solve(self, t, pose):
        sk = self.sk
        Mc = sk.world("Chest", pose)
        for s in ("L", "R"):
            d = self.dirs(s, t)
            rest = self.rest[s]
            R1 = frame_rotation(rest["Wing1"][0], rest["Wing1"][1], *d["Wing1"])
            W2 = frame_rotation(rest["Wing2"][0], rest["Wing2"][1], *d["Wing2"])
            W3 = frame_rotation(rest["Wing3"][0], rest["Wing3"][1], *d["Wing3"])
            R2 = mmul(transpose(R1), W2)
            g = clamp(self.ground(t))
            if g > 0.001:
                S, E, H = sk.pivot["Wing1" + s], sk.pivot["Wing2" + s], self.base_hand[s]
                E1 = add(S, mvec(R1, sub(E, S)))
                H1 = add(E1, mvec(mmul(R1, R2), sub(H, E)))
                hw = apply(Mc, H1)
                target = self.hand[s](t) if s in self.hand else hw
                tw = tuple(hw[i] + (target[i] - hw[i]) * g for i in range(3))
                tl = apply(inverse(Mc), tw)
                R1, R2 = ik2_3d(S, E, H, tl, R1, R2)
                W2 = mmul(R1, R2)
            R3 = mmul(transpose(W2), W3)
            for b, R in (("Wing1", R1), ("Wing2", R2), ("Wing3", R3)):
                v = pose.setdefault(b + s, [0.0] * 6)
                v[0], v[1], v[2] = euler(R)

    def standing_hands(self, pose_fn, ground_y=None):
        """Mains plantées là où la pose repliée de départ les pose, ramenées au sol."""
        p0 = pose_fn(0.0)
        Mc = self.sk.world("Chest", p0)
        for s in ("L", "R"):
            d = self.dirs(s, 0.0)
            rest = self.rest[s]
            R1 = frame_rotation(rest["Wing1"][0], rest["Wing1"][1], *d["Wing1"])
            W2 = frame_rotation(rest["Wing2"][0], rest["Wing2"][1], *d["Wing2"])
            R2 = mmul(transpose(R1), W2)
            S, E, H = self.sk.pivot["Wing1" + s], self.sk.pivot["Wing2" + s], self.base_hand[s]
            E1 = add(S, mvec(R1, sub(E, S)))
            H1 = add(E1, mvec(mmul(R1, R2), sub(H, E)))
            hw = apply(Mc, H1)
            gy = self.rig.voxel * 0.5 if ground_y is None else ground_y
            spot = (hw[0], gy, hw[2])
            self.hand[s] = (lambda t, spot=spot: spot)
        return self.hand


# ---------------------------------------------------------------------- pose de base debout (replié)
def stand(c, k=1.0):
    """Debout replié : avant du corps relevé, cou dressé, tête à l'horizontale (k = part de la pose)."""
    rig = c.rig
    c.key(0, {"Hips": P(rx=10 * k, py=0.02 * rig.u * k), "Chest": P(rx=8 * k)})
    if rig.neck:
        c.key(0, {rig.neck[0]: P(rx=10 * k)})
    c.key(0, {"Head": P(rx=-24 * k)})


def body_fn(c):
    """Pose écrite (clés + couches) du corps, sans les ailes : sert à placer les mains au départ."""
    def f(t):
        pose = {}
        for (bone, ch), tr in c.tracks.items():
            pose.setdefault(bone, [0.0] * 6)[ch] += tr.at(t)
        for bone, ch, fn in c.layers:
            pose.setdefault(bone, [0.0] * 6)[ch] += fn(t)
        return pose
    return f


def standing(c, name):
    """Animation au sol : ailes repliées, mains plantées. Renvoie la commande des ailes."""
    stand(c)
    w = Wings(c)
    return w


def plant_hands(c, w):
    w.standing_hands(body_fn(c))


def legs_fk(c, amount, thigh=-70, shin=40, foot=-30):
    """Pattes repliées vers l'arrière en vol (amount(t) = part du vol), IK coupée d'autant."""
    rig = c.rig
    for name, dr in c.drives.items():
        dr.weight = lambda t, amount=amount: 1.0 - clamp(amount(t))
        s = name[-1]
        for b, v in (("Thigh" + s, thigh), ("Shin" + s, shin), ("Foot" + s, foot)):
            if b in rig.has:
                c.add(b, RX, lambda t, v=v, amount=amount: v * clamp(amount(t)))


def fly_body(c, amount, height):
    """Corps en vol : à l'horizontale, monté de `height` studs, cou tendu vers l'avant, queue droite."""
    rig = c.rig
    c.add("Hips", PY, lambda t: height * amount(t))
    c.add("Hips", RX, lambda t: -10 * amount(t))
    c.add("Chest", RX, lambda t: -8 * amount(t))
    if rig.neck:
        c.add(rig.neck[0], RX, lambda t: -22 * amount(t))
    c.add("Head", RX, lambda t: 46 * amount(t))
    legs_fk(c, amount)


def flap_curve(T, up=34, down=-30, frac_down=0.42):
    """Battement : descente rapide (part frac_down du cycle) puis remontée plus lente."""
    def f(t):
        q = (t / T) % 1.0
        if q < frac_down:
            return up + (down - up) * ease("inout", q / frac_down)
        return down + (up - down) * ease("inout", (q - frac_down) / (1 - frac_down))
    return f


def flex_curve(T, amount=40, frac_down=0.42):
    """Poignet replié pendant la remontée (moins de résistance)."""
    def f(t):
        q = (t / T) % 1.0
        if q < frac_down:
            return 0.0
        return amount * math.sin(math.pi * (q - frac_down) / (1 - frac_down))
    return f


# ====================================================================== au sol
def idle(rig):
    c = new(rig, "Idle", 4.0, loop=True)
    L = c.length
    w = standing(c, "Idle")
    breathe(c, L / 2, 1.0)
    yaw = curve([(0, 0), (0.15 * L, 0), (0.2 * L, 30, "snap"), (0.42 * L, 28), (0.48 * L, -24, "snap"), (0.68 * L, -22),
                 (0.76 * L, 0, "inout"), (L, 0)])
    roll = curve([(0, 0), (0.2 * L, 10, "snap"), (0.42 * L, 8), (0.48 * L, -8, "snap"), (0.68 * L, -6), (0.78 * L, 0), (L, 0)])
    aim(c, yaw, None, roll)
    blinks(c, [0.34 * L, 0.86 * L])
    # petit frisson des ailes repliées
    w.side_fold["L"] = lambda t: -0.08 * win(t, 0.55 * L, 0.66 * L, 0.3)
    w.side_fold["R"] = lambda t: -0.08 * win(t, 0.57 * L, 0.68 * L, 0.3)
    tail_wave(c, 4, L / 2, RY, lag=0.1)
    plant_hands(c, w)
    return c


def idle_sniff(rig):
    """Pique le sol du bec (cherche un coquillage)."""
    c = new(rig, "IdleSniff", 2.6, nxt="Idle")
    L, u = c.length, rig.u
    w = standing(c, "IdleSniff")
    a, b = 0.25 * L, 0.75 * L
    c.key(0, {"Hips": P(py=0)})
    c.key(a, {"Hips": P(py=-0.06 * u)}, "inout")
    c.key(b, {"Hips": P(py=-0.06 * u)})
    c.key(L, {"Hips": P(py=0)}, "inout")
    pitch = curve([(0, 0), (a, -50), (b, -48), (L, 0)])
    yaw = curve([(0, 0), (a, 6), (0.5 * L, -8), (b, 4), (L, 0)])
    aim(c, yaw, pitch)
    # trois coups de bec rapides au sol
    for k in range(3):
        tb = a + 0.05 * L + k * 0.13 * L
        c.add("Head", RX, lambda t, tb=tb: -9 * bump(t, tb, tb + 0.07 * L))
    jaw(c, curve([(0, 0), (a, 8), (b, 6), (L, 0)]))
    blinks(c, [0.88 * L])
    plant_hands(c, w)
    return c


def idle_scratch(rig):
    """Lisse son aile : lève un peu l'aile gauche, y plonge le bec."""
    c = new(rig, "IdleScratch", 2.8, nxt="Idle")
    L = c.length
    w = standing(c, "IdleScratch")
    a, b = 0.22 * L, 0.74 * L
    w.side_fold["L"] = lambda t: -0.35 * win(t, 0.08 * L, b + 0.08 * L, 0.3)
    w.side_flap["L"] = lambda t: 22 * win(t, 0.08 * L, b + 0.08 * L, 0.3)
    yaw = curve([(0, 0), (a, 70), (b, 66), (L, 0)])
    pitch = curve([(0, 0), (a, -24), (b, -24), (L, 0)])
    roll = curve([(0, 0), (a, -14), (b, -14), (L, 0)])
    aim(c, yaw, pitch, roll)
    c.add("Head", RX, lambda t: 5 * shake(t, a, b, 6.0))
    c.add("Head", RY, lambda t: 4 * shake(t + 0.03, a, b, 6.0))
    c.add("Hips", RZ, lambda t: -4 * win(t, 0.05 * L, b + 0.1 * L, 0.3))
    lids(c, lambda t: 0.6 * win(t, a, b, 0.2))
    plant_hands(c, w)
    return c


def idle_stretch(rig):
    """S'étire : ouvre grand les deux ailes, les tend vers le haut, puis les replie."""
    c = new(rig, "IdleStretch", 3.2, nxt="Idle")
    L = c.length
    w = standing(c, "IdleStretch")
    a, b, d = 0.3 * L, 0.62 * L, 0.88 * L
    w.fold = lambda t: 1 - 0.95 * win(t, 0.06 * L, d, 0.32)
    w.flap = lambda t: 26 * win(t, 0.12 * L, d, 0.35) + 6 * shake(t, a, b, 3.0)
    w.ground = lambda t: 1 - win(t, 0.06 * L, d, 0.3)
    c.add("Hips", RX, lambda t: 8 * win(t, 0.06 * L, d, 0.3))
    pitch = curve([(0, 0), (a, 24), (b, 26), (d, 0), (L, 0)])
    aim(c, None, pitch)
    jaw(c, curve([(0, 0), (a, 0), (0.45 * L, 30), (b, 26), (b + 0.05 * L, 0, "snap"), (L, 0)]))
    lids(c, lambda t: win(t, 0.4 * L, b, 0.2))
    plant_hands(c, w)
    return c


def idle_shake(rig):
    c = new(rig, "IdleShake", 1.8, nxt="Idle")
    L = c.length
    w = standing(c, "IdleShake")
    a, b = 0.12 * L, 0.78 * L
    sh = lambda t: shake(t, a, b, 7.0, 1.4)  # noqa: E731
    c.add("Head", RY, lambda t: 24 * sh(t))
    c.add("Head", RZ, lambda t: 12 * sh(t - 0.03))
    if rig.neck:
        c.add(rig.neck[0], RY, lambda t: 10 * sh(t - 0.02))
    c.add("Chest", RZ, lambda t: -4 * sh(t - 0.04))
    w.side_fold["L"] = lambda t: -0.1 * abs(sh(t - 0.05))
    w.side_fold["R"] = lambda t: -0.1 * abs(sh(t - 0.07))
    jaw(c, curve([(0, 0), (a, 10), (b, 6), (L, 0)]))
    lids(c, lambda t: 0.8 * win(t, a + 0.05, b - 0.1, 0.15))
    plant_hands(c, w)
    return c


def idle_yawn(rig):
    c = new(rig, "IdleYawn", 2.8, nxt="Idle")
    L = c.length
    w = standing(c, "IdleYawn")
    a, b, d = 0.3 * L, 0.58 * L, 0.64 * L
    pitch = curve([(0, 0), (a, 34), (b, 36), (d + 0.05 * L, 4, "out"), (L, 0)])
    aim(c, None, pitch)
    jaw(c, curve([(0, 0), (0.1 * L, 0), (a, 44, "inout"), (b, 48), (d, 0, "snap"), (L, 0)]))
    c.add("Head", RZ, lambda t: 3 * shake(t, a, b, 8.0))
    c.add("Head", RY, lambda t: 9 * shake(t, d, d + 0.25 * L, 6.0, 2.0))
    lids(c, lambda t: win(t, 0.18 * L, b + 0.02 * L, 0.18))
    w.side_fold["L"] = lambda t: -0.12 * win(t, 0.2 * L, b, 0.3)
    w.side_fold["R"] = lambda t: -0.12 * win(t, 0.2 * L, b, 0.3)
    blinks(c, [0.86 * L])
    plant_hands(c, w)
    return c


def walk(rig):
    """Marche à quatre pattes sur les ailes repliées (pieds et mains posés au sol)."""
    c = new(rig, "Walk", 1.0, loop=True)
    T, u = c.length, rig.u
    w = standing(c, "Walk")
    S, beta, lift = 1.1 * u, 0.66, 0.16 * u
    c.speed = S / T
    gait(c, {"LegL": 0.0, "LegR": 0.5}, T, S, beta, lift, 12, 24)
    plant_hands(c, w)
    base = dict(w.hand)
    for s, ph in (("L", 0.25), ("R", 0.75)):
        spot = base[s](0)

        def hand(t, spot=spot, ph=ph):
            p = ((t / T) - ph) % 1.0
            if p < beta:
                z = spot[2] - beta * S / 2 + p * S
                y = 0.0
            else:
                q = (p - beta) / (1 - beta)
                za, zb, m = spot[2] + beta * S / 2, spot[2] - beta * S / 2, S * (1 - beta)
                q2, q3 = q * q, q * q * q
                z = (2 * q3 - 3 * q2 + 1) * za + (q3 - 2 * q2 + q) * m + (-2 * q3 + 3 * q2) * zb + (q3 - q2) * m
                y = lift * 1.2 * swing_lift(q)
            return (spot[0], spot[1] + y, z)
        w.hand[s] = hand
    c.event(0.0, "Step", "FootL")
    c.event(round(T / 2, 3), "Step", "FootR")
    two = lambda t, ph=0.0: math.cos(2 * math.pi * (2 * t / T - ph))  # noqa: E731
    one = lambda t, ph=0.0: math.cos(2 * math.pi * (t / T - ph))  # noqa: E731
    c.add("Hips", PY, lambda t: -0.04 * u * two(t, 0.1))
    c.add("Chest", RZ, lambda t: 3 * one(t, 0.35))
    c.add("Hips", RZ, lambda t: 2.5 * one(t, beta / 2))
    c.add("Hips", RY, lambda t: -3 * one(t))
    if rig.neck:
        c.add(rig.neck[0], RX, lambda t: 4 * two(t, 0.2))
    c.add("Head", RX, lambda t: -4 * two(t, 0.2))
    c.add("Head", RY, lambda t: 3 * one(t))
    tail_wave(c, 5, T, RY, lag=0.06)
    return c


def happy(rig):
    """Deux petits bonds en battant des ailes, cri joyeux."""
    c = new(rig, "Happy", 1.6, nxt="Idle")
    L, u = c.length, rig.u
    w = standing(c, "Happy")
    a, up, top, land, hop, top2, land2 = 0.1 * L, 0.18 * L, 0.32 * L, 0.46 * L, 0.56 * L, 0.66 * L, 0.78 * L
    c.key(0, {"Hips": P(py=0.02 * u)})
    c.key(a, {"Hips": P(py=-0.1 * u)}, "inout")
    c.key(top, {"Hips": P(py=0.55 * u)}, "out2")
    c.key(land, {"Hips": P(py=-0.06 * u)}, "in2")
    c.key(top2, {"Hips": P(py=0.35 * u)}, "out2")
    c.key(land2, {"Hips": P(py=-0.04 * u)}, "in2")
    c.key(L, {"Hips": P(py=0.02 * u)}, "inout")
    air = curve([(0, 0), (up, 0), (up + 0.04 * L, 1), (land - 0.03 * L, 1), (land, 0), (hop, 0), (hop + 0.03 * L, 1),
                 (land2 - 0.03 * L, 1), (land2, 0), (L, 0)])
    w.fold = lambda t: 1 - 0.8 * win(t, a, land2 + 0.08 * L, 0.15)
    fl = flap_curve(0.32 * L, 40, -24, 0.45)
    w.flap = lambda t: fl(t) * win(t, a, land2 + 0.06 * L, 0.12)
    w.ground = lambda t: 1 - win(t, a, land2 + 0.08 * L, 0.12)
    airborne_multi(c, [(up, land), (hop, land2)], tuck=lambda t: (0, 0.1 * u, 0.05 * u))
    pitch = curve([(0, 0), (top, 12), (land, -4), (top2, 10), (L, 0)])
    aim(c, None, pitch)
    jaw(c, curve([(0, 0), (up, 0), (top, 30), (land, 8), (top2, 26), (land2, 0), (L, 0)]))
    c.add("Head", RZ, lambda t: 12 * shake(t, land2, L, 7.0, 2.0))
    tail_wave(c, 10, 0.3, RY, lag=0.04, env=lambda t: win(t, 0.05 * L, L, 0.2))
    plant_hands(c, w)
    return c


def roar(rig):
    """Cri perçant : se dresse, ailes grandes ouvertes vers le haut, bec grand ouvert."""
    c = new(rig, "Roar", 2.2, nxt="Idle")
    L, u = c.length, rig.u
    w = standing(c, "Roar")
    a, b, h1, h2 = 0.24 * L, 0.34 * L, 0.7 * L, 0.86 * L
    c.key(0, {"Hips": P(py=0.02 * u)})
    c.key(a, {"Hips": P(py=-0.06 * u)}, "inout")
    c.key(b, {"Hips": P(py=0.12 * u)}, "out")
    c.key(h1, {"Hips": P(py=0.1 * u)})
    c.key(h2, {"Hips": P(py=0.02 * u)}, "inout")
    c.key(L, {"Hips": P(py=0.02 * u)})
    c.add("Hips", RX, lambda t: 12 * win(t, a, h2, 0.2))
    w.fold = lambda t: 1 - 0.9 * win(t, a - 0.05 * L, h2 + 0.05 * L, 0.2)
    w.flap = lambda t: 34 * win(t, a, h2, 0.25) + 3 * shake(t, b, h1, 9.0)
    w.sweep = lambda t: -14 * win(t, a, h2, 0.25)
    w.ground = lambda t: 1 - win(t, a - 0.05 * L, h2 + 0.05 * L, 0.2)
    pitch = curve([(0, 0), (a, -16), (b, 22, "back"), (h1, 18), (h2, 0), (L, 0)])
    aim(c, None, pitch)
    jaw(c, curve([(0, 0), (a, 4), (b, 46, "back"), (h1, 42), (h2, 0), (L, 0)]))
    c.add("Head", RY, lambda t: 2.5 * shake(t, b, h1, 13.0))
    c.add("Jaw", RX, lambda t: 3 * shake(t, b, h1, 15.0))
    c.event(b, "Roar")
    plant_hands(c, w)
    return c


def eat(rig):
    """Happe un poisson au sol, le lance en l'air et l'avale tête levée."""
    c = new(rig, "Eat", 2.8, nxt="Idle")
    L = c.length
    w = standing(c, "Eat")
    down, snap, toss, gulp = 0.18 * L, 0.26 * L, 0.46 * L, 0.66 * L
    pitch = curve([(0, 0), (down, -54), (snap, -50), (toss - 0.06 * L, 10), (toss, 40, "snap"), (gulp, 36), (0.86 * L, 0), (L, 0)])
    aim(c, None, pitch)
    jaw(c, curve([(0, 0), (down - 0.04 * L, 30), (snap, 0, "snap"), (toss - 0.02 * L, 0), (toss, 34, "snap"),
                  (toss + 0.06 * L, 0, "snap"), (gulp, 0), (L, 0)]))
    for i, nb in enumerate(rig.neck):
        c.add(nb, RX, lambda t, i=i: 8 * bump(t, gulp - 0.06 * L + i * 0.04 * L, gulp + 0.08 * L + i * 0.04 * L))
    c.add("Head", RY, lambda t: 10 * shake(t, gulp + 0.05 * L, L, 5.0, 2.0))
    blinks(c, [0.8 * L])
    plant_hands(c, w)
    return c


def sleep_pose(rig):
    """Couché, ailes serrées, tête tournée vers l'arrière posée sur le dos, yeux fermés."""
    u = rig.u
    pose = {"Hips": P(py=-0.5 * u, rx=4), "Chest": P(rx=-2)}
    if rig.neck:
        pose[rig.neck[0]] = P(rx=-20, ry=120)
    pose["Head"] = P(rx=-16, ry=40, rz=10)
    return pose


def sleep(rig):
    c = new(rig, "Sleep", 4.4, loop=True)
    L = c.length
    w = Wings(c)
    sp = sleep_pose(rig)
    c.key(0, sp)
    c.key(L, sp)
    fold_legs(c, lambda t: 1.0)
    lids(c, lambda t: 1.0)
    breathe(c, L / 2, 2.2)
    w.ground = const(0.0)
    w.side_fold["L"] = lambda t: 0.0
    c.add("Jaw", RX, lambda t: -2.5 * max(0.0, math.sin(4 * math.pi * t / L - 1.2)))
    return c


def spawn(rig):
    c = new(rig, "Spawn", 3.0, nxt="Idle")
    L, u = c.length, rig.u
    a, b, s0, s1, look, back = 0.08 * L, 0.26 * L, 0.3 * L, 0.6 * L, 0.68 * L, 0.9 * L
    stand(c)
    w = Wings(c)
    crouch = {"Hips": P(py=-0.4 * u, rx=6), "Chest": P(rx=-14)}
    if rig.neck:
        crouch[rig.neck[0]] = P(rx=-30)
    crouch["Head"] = P(rx=-20)
    for bone, chans in crouch.items():
        for ch, v in chans.items():
            c.add(bone, ch, lambda t, v=v: v * (1 - ramp(t, a, b, "out")))
    fold = curve([(0, 1), (a, 1), (b, 0, "out")])
    fold_legs(c, lambda t: fold.at(t))
    w.fold = lambda t: 1 - 0.75 * win(t, s0 - 0.04 * L, s1 + 0.04 * L, 0.25)
    sh = lambda t: shake(t, s0, s1, 7.0, 3.0)  # noqa: E731
    w.flap = lambda t: 18 * win(t, s0 - 0.04 * L, s1 + 0.04 * L, 0.25) + 10 * sh(t)
    w.ground = lambda t: 1 - win(t, s0 - 0.04 * L, s1 + 0.04 * L, 0.25)
    c.add("Hips", RZ, lambda t: 7 * sh(t))
    c.add("Head", RY, lambda t: 12 * sh(t - 0.04))
    yaw = curve([(0, 0), (s1, 0), (look, 24, "inout"), (back, 22), (L, 0)])
    roll = curve([(0, 0), (s1, 0), (look, 14, "back"), (back, 12), (L, 0)])
    aim(c, yaw, None, roll)
    lids(c, lambda t: 1.0 - ramp(t, a, b - 0.04 * L, "out2"))
    blinks(c, [0.8 * L])
    plant_hands(c, w)
    return c


# ====================================================================== gardiens
def wake(rig):
    c = new(rig, "Wake", 1.8, nxt="Idle")
    L, u = c.length, rig.u
    jolt, up, sh0, sh1 = 0.12 * L, 0.5 * L, 0.54 * L, 0.86 * L
    stand(c)
    w = Wings(c)
    sp = sleep_pose(rig)
    k = curve([(0, 1), (jolt, 0.85, "snap"), (up, 0, "out")])
    for bone, chans in sp.items():
        for ch, v in chans.items():
            c.add(bone, ch, lambda t, v=v: v * k.at(t))
    fold_legs(c, lambda t: k.at(t))
    w.ground = lambda t: 1 - k.at(t)
    lids(c, lambda t: 1.0 - ramp(t, 0.04 * L, jolt, "snap"))
    c.add("Head", RY, lambda t: 18 * shake(t, sh0, sh1, 6.0, 1.5))
    w.side_fold["L"] = lambda t: -0.2 * win(t, sh0, sh1, 0.3)
    w.side_fold["R"] = lambda t: -0.2 * win(t, sh0, sh1, 0.3)
    jaw(c, curve([(0, 0), (jolt, 14, "snap"), (up, 0), (L, 0)]))
    plant_hands(c, w)
    return c


def catch(rig):
    """Coup de bec plongé (bec fermé à l'impact), ailes à demi ouvertes pour l'équilibre."""
    c = new(rig, "Catch", 1.2, nxt="Idle")
    L, u = c.length, rig.u
    w = standing(c, "Catch")
    wind, hit, rec = 0.36 * L, 0.48 * L, 0.68 * L
    c.add("Hips", PZ, lambda t: 0.12 * u * win(t, 0.1 * L, wind + 0.04 * L, 0.4) - 0.28 * u * win(t, wind, rec + 0.15 * L, 0.3))
    c.add("Hips", RX, lambda t: 6 * win(t, 0.1 * L, wind + 0.04 * L, 0.4) - 14 * win(t, wind, rec + 0.15 * L, 0.3))
    pitch = curve([(0, 0), (wind, 22), (hit, -36, "snap"), (rec, -10, "back"), (L, 0)])
    aim(c, None, pitch)
    if rig.neck:
        c.add(rig.neck[0], RX, lambda t: 14 * win(t, 0.1 * L, wind + 0.03 * L, 0.4) - 18 * win(t, wind, rec + 0.1 * L, 0.3))
    w.fold = lambda t: 1 - 0.55 * win(t, 0.15 * L, rec + 0.15 * L, 0.3)
    w.flap = lambda t: 20 * win(t, 0.15 * L, rec + 0.15 * L, 0.3)
    w.ground = lambda t: 1 - 0.8 * win(t, 0.15 * L, rec + 0.15 * L, 0.3)
    jaw(c, curve([(0, 0), (wind, 20), (hit - 0.04 * L, 0), (L, 0)]))
    c.add("Head", RZ, lambda t: 6 * shake(t, hit, rec + 0.1 * L, 9.0, 4.0))
    c.event(hit, "Hit")
    plant_hands(c, w)
    return c


def search(rig):
    c = new(rig, "Search", 4.2, loop=True)
    L, u = c.length, rig.u
    w = standing(c, "Search")
    s1, r0, l0, l1, rr0, rr1, f0 = 0.16 * L, 0.24 * L, 0.3 * L, 0.46 * L, 0.52 * L, 0.68 * L, 0.78 * L
    pitch = curve([(0, -46), (s1, -46), (r0, 8, "out"), (l1, 6), (rr1, 6), (f0, 2), (L, -46, "inout")])
    yaw = curve([(0, 0), (r0, 0), (l0, 56, "snap"), (l1, 52), (rr0, -54, "snap"), (rr1, -50), (f0, 0, "inout"), (L, 0)])
    roll = curve([(0, 0), (l0, 10), (l1, 10), (rr0, -10), (rr1, -10), (f0, 16), (0.9 * L, 14), (L, 0)])
    aim(c, yaw, pitch, roll)
    c.add("Hips", RY, lambda t: 0.2 * yaw.at(t))
    c.add("Head", RX, lambda t: -6 * shake(t, 0.02 * L, s1, 6.0) - 6 * shake(t, 0.86 * L, L, 6.0))
    w.side_fold["L"] = lambda t: -0.1 * win(t, l0, l1, 0.3)
    w.side_fold["R"] = lambda t: -0.1 * win(t, rr0, rr1, 0.3)
    blinks(c, [0.49 * L, 0.74 * L])
    breathe(c, L / 3, 1.0)
    plant_hands(c, w)
    return c


def back_to_sleep(rig):
    c = new(rig, "BackToSleep", 3.2, nxt="Sleep")
    L, u = c.length, rig.u
    turn0, turn1, down, close = 0.06 * L, 0.56 * L, 0.88 * L, 0.92 * L
    stand(c)
    w = Wings(c)
    spin = curve([(0, 0), (turn0, 0), (turn1, 360, "inout"), (L, 360)])
    c.add("Hips", RY, lambda t: spin.at(t))
    sp = sleep_pose(rig)
    k = curve([(0, 0), (turn1, 0), (down, 1, "inout"), (L, 1)])
    for bone, chans in sp.items():
        for ch, v in chans.items():
            c.add(bone, ch, lambda t, v=v: v * k.at(t))
    fold_legs(c, lambda t: k.at(t))
    steps = 6

    def stomp(t, ph):
        if t < turn0 or t > turn1:
            return 0.0
        q = (t - turn0) / (turn1 - turn0) * steps + ph
        return max(0.0, math.sin(math.pi * (q % 1.0))) if int(q) % 2 == 0 else 0.0

    def rel(t):
        return win(t, turn0 - 0.02 * L, turn1 + 0.02 * L, 0.06)
    for name, ph in (("LegL", 0.0), ("LegR", 1.0)):
        dr = c.drive(name)
        if dr:
            dr.rel = rel
            dr.rel_toe = lambda t, ph=ph: (0, 0.12 * u * stomp(t, ph), 0)
    # mains : suivent le corps pendant le tour, puis se lèvent (couché, ailes serrées)
    w.ground = lambda t: (1 - win(t, turn0 - 0.02 * L, turn1 + 0.02 * L, 0.06)) * (1 - k.at(t))
    lids(c, lambda t: ramp(t, close - 0.08 * L, L - 0.02 * L, "inout"))
    jaw(c, curve([(0, 0), (turn1 + 0.04 * L, 0), (turn1 + 0.12 * L, 28), (down, 0), (L, 0)]))
    plant_hands(c, w)
    return c


def fusion(rig):
    c = new(rig, "Fusion", 1.2, loop=True)
    L, u = c.length, rig.u
    w = Wings(c)
    w.ground = const(0.0)
    w.fold = lambda t: 0.4 + 0.25 * math.sin(2 * math.pi * 2 * t / L)
    w.flap = lambda t: 30 * math.sin(2 * math.pi * 3 * t / L)
    w.side_flap["L"] = lambda t: 12 * math.sin(2 * math.pi * 2 * t / L)
    w.side_flap["R"] = lambda t: -12 * math.sin(2 * math.pi * 2 * t / L)
    c.key(0, {"Hips": P(py=0.3 * u, rx=-10)})
    for dr in c.drives.values():
        dr.weight = lambda t: 0.0
    f = 2.0 / L
    for b, ph in (("ThighL", 0.0), ("ThighR", 0.5)):
        c.add(b, RX, lambda t, ph=ph: 30 * math.sin(2 * math.pi * (f * t - ph)))
    for b, ph in (("ShinL", 0.0), ("ShinR", 0.5)):
        c.add(b, RX, lambda t, ph=ph: -20 + 20 * math.sin(2 * math.pi * (f * t - ph - 0.2)))
    yaw = curve([(0, 0), (0.25 * L, 30), (0.5 * L, -28), (0.75 * L, 26), (L, 0)])
    aim(c, yaw, curve([(0, 10), (0.5 * L, 18), (L, 10)]))
    jaw(c, curve([(0, 26), (0.5 * L, 34), (L, 26)]))
    tail_wave(c, 14, L / 2, RY, lag=0.06)
    return c


def index_pose(rig):
    """Présentation : debout sur ses pattes, ailes grandes ouvertes, tête tournée vers le joueur (boucle)."""
    c = new(rig, "Index", 4.0, loop=True)
    L, u = c.length, rig.u
    c.key(0, {"Hips": P(rx=12, py=0.04 * u), "Chest": P(rx=8)})
    c.key(L, {"Hips": P(rx=12, py=0.04 * u), "Chest": P(rx=8)})
    if rig.neck:
        c.key(0, {rig.neck[0]: P(rx=8)})
        c.key(L, {rig.neck[0]: P(rx=8)})
    c.key(0, {"Head": P(rx=-18)})
    c.key(L, {"Head": P(rx=-18)})
    w = Wings(c)
    w.ground = const(0.0)
    w.fold = const(0.08)
    w.flap = lambda t: 14 + 5 * math.sin(2 * math.pi * t / (L / 2)) + 10 * shake(t, 0.5 * L, 0.7 * L, 3.0, 1.0)
    w.sweep = const(-6)
    yaw = curve([(0, 18), (0.45 * L, 18), (0.55 * L, 10), (0.62 * L, 20, "back"), (L, 18)])
    pitch = curve([(0, 8), (0.45 * L, 8), (0.55 * L, 18, "snap"), (0.66 * L, 6, "back"), (L, 8)])
    aim(c, yaw, pitch)
    breathe(c, L / 2, 1.2)
    blinks(c, [0.3 * L, 0.82 * L])
    jaw(c, curve([(0, 0), (0.53 * L, 0), (0.58 * L, 20, "snap"), (0.68 * L, 0), (L, 0)]))
    return c


# ====================================================================== vol
FLY_H = 1.4  # hauteur du vol dans les animations, en hauteurs de hanche (le jeu monte le modèle en plus)


def fly(rig, name="Fly", base=0.85, fast=False):
    c = new(rig, name, base, loop=True)
    T, u = c.length, rig.u
    w = Wings(c)
    w.ground = const(0.0)
    w.fold = const(0.0)
    up, down = (40, -34) if fast else (34, -30)
    w.flap = flap_curve(T, up, down, 0.42)
    w.flex = flex_curve(T, 46 if fast else 38, 0.42)
    w.sweep = const(6 if fast else 2)
    fly_body(c, const(1.0), FLY_H * u)
    # le corps monte pendant la descente des ailes et retombe pendant la remontée
    c.add("Hips", PY, lambda t: 0.08 * u * math.cos(2 * math.pi * (t / T - 0.32)))
    c.add("Hips", RX, lambda t: (-8 if fast else 0) + 2 * math.cos(2 * math.pi * (t / T - 0.3)))
    c.add("Head", RX, lambda t: -2 * math.cos(2 * math.pi * (t / T - 0.32)))
    tail_wave(c, 4, T, RX, lag=0.05)
    c.speed = (18.0 if fast else 12.0)
    return c


def glide(rig):
    c = new(rig, "Glide", 3.6, loop=True)
    L, u = c.length, rig.u
    w = Wings(c)
    w.ground = const(0.0)
    w.fold = const(0.0)
    w.flap = lambda t: 6 + 3 * math.sin(2 * math.pi * t / L)
    w.side_flap["L"] = lambda t: 6 * math.sin(2 * math.pi * t / L)
    w.side_flap["R"] = lambda t: -6 * math.sin(2 * math.pi * t / L)
    w.sweep = const(4)
    fly_body(c, const(1.0), FLY_H * u)
    c.add("Hips", RZ, lambda t: 10 * math.sin(2 * math.pi * t / L))
    c.add("Hips", PY, lambda t: 0.06 * u * math.sin(2 * math.pi * 2 * t / L))
    yaw = curve([(0, 0), (0.3 * L, 18), (0.5 * L, 16), (0.75 * L, -14), (L, 0)])
    aim(c, yaw, None, curve([(0, 0), (0.25 * L, -8), (0.75 * L, 8), (L, 0)]))
    blinks(c, [0.4 * L])
    c.speed = 10.0
    return c


def takeoff(rig):
    """Décolle : s'accroupit, bondit en poussant sur les bras, déplie les ailes, premiers battements."""
    c = new(rig, "TakeOff", 1.5, nxt="Fly")
    L, u = c.length, rig.u
    crouch, leap, open1 = 0.22 * L, 0.36 * L, 0.5 * L
    stand(c)
    w = Wings(c)
    air = curve([(0, 0), (leap - 0.04 * L, 0), (open1, 0.7, "out"), (L, 1.0)])
    c.key(0, {"Hips": P(py=0)})
    c.key(crouch, {"Hips": P(py=-0.22 * u)}, "inout")
    c.key(leap, {"Hips": P(py=0.1 * u)}, "out")
    c.key(L, {"Hips": P(py=0)})
    # le reste de la montée est porté par fly_body (part `air`) ; on annule la pose debout au fur et à mesure
    fly_body(c, lambda t: air.at(t), FLY_H * u)
    c.add("Hips", RX, lambda t: -10 * air.at(t))
    c.add("Chest", RX, lambda t: -8 * air.at(t))
    if rig.neck:
        c.add(rig.neck[0], RX, lambda t: -10 * air.at(t))
    c.add("Head", RX, lambda t: 24 * air.at(t))
    w.fold = lambda t: 1 - ramp(t, leap - 0.06 * L, open1 + 0.04 * L, "inout")
    fl = flap_curve(0.34 * L, 44, -36, 0.42)
    w.flap = lambda t: fl(t - open1) * ramp(t, open1 - 0.06 * L, open1 + 0.04 * L) - 20 * win(t, leap - 0.06 * L, open1, 0.4)
    w.flex = lambda t: flex_curve(0.34 * L, 40, 0.42)(t - open1) * ramp(t, open1, open1 + 0.05 * L)
    w.ground = lambda t: 1 - ramp(t, leap - 0.05 * L, leap + 0.02 * L)
    plant_hands(c, w)
    airborne_multi(c, [(leap - 0.02 * L, L + 1)], tuck=lambda t: (0, 0.05 * u, 0.1 * u))
    c.event(leap, "Step", "FootL")
    return c


def land(rig):
    """Atterrit : se cabre en freinant ailes en avant, pattes tendues, se pose, replie les ailes."""
    c = new(rig, "Land", 1.6, nxt="Idle")
    L, u = c.length, rig.u
    flare, touch, settle = 0.3 * L, 0.52 * L, 0.78 * L
    stand(c)
    w = Wings(c)
    air = curve([(0, 1), (flare, 0.75), (touch, 0.0, "in2"), (L, 0)])
    fly_body(c, lambda t: air.at(t), FLY_H * u)
    c.add("Hips", RX, lambda t: -10 * air.at(t) + 22 * win(t, 0.1 * L, touch + 0.06 * L, 0.3))
    c.add("Chest", RX, lambda t: -8 * air.at(t))
    if rig.neck:
        c.add(rig.neck[0], RX, lambda t: -10 * air.at(t))
    c.add("Head", RX, lambda t: 24 * air.at(t) - 16 * win(t, 0.1 * L, touch + 0.06 * L, 0.3))
    c.add("Hips", PY, lambda t: -0.12 * u * bump(t, touch - 0.02 * L, settle))
    w.fold = lambda t: ramp(t, touch, settle + 0.06 * L, "inout")
    w.flap = lambda t: 26 * win(t, 0.05 * L, touch + 0.04 * L, 0.3) + 8 * shake(t, flare, touch, 4.0)
    w.sweep = lambda t: -22 * win(t, 0.05 * L, touch + 0.04 * L, 0.3)
    w.ground = lambda t: ramp(t, touch, settle, "inout")
    plant_hands(c, w)
    airborne_multi(c, [(-1, touch)], tuck=lambda t: (0, 0.0, -0.12 * u))
    c.event(touch, "Step", "FootL")
    return c


def build(rig):
    clips = [idle(rig), idle_sniff(rig), idle_scratch(rig), idle_stretch(rig), idle_shake(rig), idle_yawn(rig),
             walk(rig), fly(rig, "Run", 0.6, fast=True), happy(rig), roar(rig), eat(rig), sleep(rig), spawn(rig),
             wake(rig), catch(rig), search(rig), back_to_sleep(rig), fusion(rig), index_pose(rig),
             takeoff(rig), fly(rig), glide(rig), land(rig)]
    return {c.name: c for c in clips}
