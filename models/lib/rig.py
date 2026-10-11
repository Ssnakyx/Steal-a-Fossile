"""rig : poses des os (même calcul que DinoBuilder.Solve côté jeu) et IK des pattes.

Une pose = {os: [rx, ry, rz, px, py, pz]} : rotations en degrés dans l'ordre de CFrame.Angles (R = Rx * Ry * Rz),
déplacements en studs. Transformation d'un os : M = M_parent * T(pivot + offset) * R * T(-pivot), pivots en espace
modèle (au repos). Conventions : rx > 0 lève le nez / avance une patte pendante, ry > 0 tourne le nez vers la gauche
(-X), rz > 0 envoie le bas de l'os vers la droite (+X)."""
from __future__ import annotations

import math

I3 = ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0))
ZERO = (0.0, 0.0, 0.0)


def rot(rx, ry, rz):
    """Matrice 3x3 de CFrame.Angles(rad(rx), rad(ry), rad(rz)) = Rx * Ry * Rz."""
    a, b, c = math.radians(rx), math.radians(ry), math.radians(rz)
    ca, sa, cb, sb, cc, sc = math.cos(a), math.sin(a), math.cos(b), math.sin(b), math.cos(c), math.sin(c)
    # Rx * Ry * Rz
    return (
        (cb * cc, -cb * sc, sb),
        (ca * sc + sa * sb * cc, ca * cc - sa * sb * sc, -sa * cb),
        (sa * sc - ca * sb * cc, sa * cc + ca * sb * sc, ca * cb),
    )


def mmul(A, B):
    return tuple(tuple(sum(A[i][k] * B[k][j] for k in range(3)) for j in range(3)) for i in range(3))


def mvec(A, v):
    return (A[0][0] * v[0] + A[0][1] * v[1] + A[0][2] * v[2],
            A[1][0] * v[0] + A[1][1] * v[1] + A[1][2] * v[2],
            A[2][0] * v[0] + A[2][1] * v[1] + A[2][2] * v[2])


def transpose(A):
    return tuple(tuple(A[j][i] for j in range(3)) for i in range(3))


def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def scale(a, k):
    return (a[0] * k, a[1] * k, a[2] * k)


def lerp3(a, b, k):
    return (a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k)


# transformation affine = (R, t) : p -> R p + t
def compose(M, N):
    return (mmul(M[0], N[0]), add(mvec(M[0], N[1]), M[1]))


def apply(M, p):
    return add(mvec(M[0], p), M[1])


def inverse(M):
    Rt = transpose(M[0])
    return (Rt, scale(mvec(Rt, M[1]), -1.0))


def bone_local(pivot, v):
    """T(pivot + off) * R * T(-pivot)."""
    R = rot(v[0], v[1], v[2])
    t = sub(add(pivot, (v[3], v[4], v[5])), mvec(R, pivot))
    return (R, t)


IDENT = (I3, ZERO)


class Skeleton:
    """Os du modèle (données de vox.Dino.data())."""

    def __init__(self, model):
        self.order = [b["name"] for b in model["bones"]]
        self.parent = {b["name"]: b["parent"] for b in model["bones"]}
        self.pivot = {b["name"]: tuple(b["pivot"]) for b in model["bones"]}
        self.rest = {b["name"]: tuple(b["rest"]) for b in model["bones"] if b.get("rest")}
        self.children = {n: [] for n in self.order}
        for n in self.order:
            if self.parent[n]:
                self.children[self.parent[n]].append(n)

    def chain_to_root(self, bone):
        out = []
        while bone:
            out.append(bone)
            bone = self.parent[bone]
        return list(reversed(out))

    def world(self, bone, pose, cache=None):
        """Transformation monde de l'os `bone` pour la pose (calcule seulement la chaîne jusqu'à la racine)."""
        cache = {} if cache is None else cache
        if bone in cache:
            return cache[bone]
        par = self.parent[bone]
        M = self.world(par, pose, cache) if par else IDENT
        v = pose.get(bone)
        r = self.rest.get(bone)
        if r:
            v = [r[0] + (v[0] if v else 0.0), r[1] + (v[1] if v else 0.0), r[2] + (v[2] if v else 0.0),
                 v[3] if v else 0.0, v[4] if v else 0.0, v[5] if v else 0.0]
        if v is not None and any(v):
            M = compose(M, bone_local(self.pivot[bone], v))
        cache[bone] = M
        return M

    def solve(self, pose):
        cache = {}
        for n in self.order:
            self.world(n, pose, cache)
        return cache

    def subtree(self, bone):
        out = [bone]
        for c in self.children[bone]:
            out += self.subtree(c)
        return out


# ---------------------------------------------------------------------- IK plane (Y, Z) d'une patte
def ang(y, z):
    """Angle d'un vecteur du plan (Y, Z) : Rx(a) ajoute a à cet angle."""
    return math.atan2(z, y)


def wrap(a):
    while a > math.pi:
        a -= 2 * math.pi
    while a < -math.pi:
        a += 2 * math.pi
    return a


def ik2(hip, knee0, ankle0, target, bend=1.0):
    """IK 2 os dans le plan (Y, Z) de l'espace du parent. Renvoie (rx_os1, rx_os2) en degrés (rx_os2 relatif à os1).
    bend = +1 : l'articulation du milieu passe devant (genou des pattes arrière), -1 : derrière (coude des pattes
    avant). Les X sont ignorés (patte supposée dans un plan parallèle à YZ)."""
    hy, hz = hip[1], hip[2]
    l1 = math.hypot(knee0[1] - hy, knee0[2] - hz)
    l2 = math.hypot(ankle0[1] - knee0[1], ankle0[2] - knee0[2])
    a1 = ang(knee0[1] - hy, knee0[2] - hz)
    a2 = ang(ankle0[1] - knee0[1], ankle0[2] - knee0[2])
    ty, tz = target[1] - hy, target[2] - hz
    d = math.hypot(ty, tz)
    d = max(abs(l1 - l2) + 1e-4, min(l1 + l2 - 1e-4, d))
    cosb = (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)
    b = math.acos(max(-1.0, min(1.0, cosb)))
    phi = ang(ty, tz)
    p1 = phi + bend * b
    ky, kz = l1 * math.cos(p1), l1 * math.sin(p1)
    p2 = ang(ty - ky, tz - kz) if d > 1e-6 else p1
    r1 = wrap(p1 - a1)
    r2 = wrap(p2 - a2 - r1)
    return math.degrees(r1), math.degrees(r2)


def pitch_in(M, v_world):
    """Angle (plan YZ) d'un vecteur monde ramené dans l'espace local de M."""
    loc = mvec(transpose(M[0]), v_world)
    return ang(loc[1], loc[2])


# ---------------------------------------------------------------------- orientations (ailes, nageoires)
def norm(v):
    m = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
    return (v[0] / m, v[1] / m, v[2] / m) if m > 1e-12 else (0.0, 0.0, 0.0)


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def frame(axis, normal):
    """Repère orthonormé (colonnes : axe, normale redressée, axe x normale)."""
    a = norm(axis)
    n = norm(sub(normal, scale(a, dot(normal, a))))
    b = cross(a, n)
    return ((a[0], n[0], b[0]), (a[1], n[1], b[1]), (a[2], n[2], b[2]))


def frame_rotation(rest_axis, rest_normal, axis, normal):
    """Rotation qui amène le repère de repos (axe, normale) sur le repère voulu."""
    return mmul(frame(axis, normal), transpose(frame(rest_axis, rest_normal)))


def axis_angle(axis, ang_rad):
    x, y, z = norm(axis)
    c, s = math.cos(ang_rad), math.sin(ang_rad)
    C = 1 - c
    return ((c + x * x * C, x * y * C - z * s, x * z * C + y * s),
            (y * x * C + z * s, c + y * y * C, y * z * C - x * s),
            (z * x * C - y * s, z * y * C + x * s, c + z * z * C))


def euler(R):
    """Angles (degrés) tels que R = Rx(rx) * Ry(ry) * Rz(rz) (ordre de CFrame.Angles)."""
    sy = max(-1.0, min(1.0, R[0][2]))
    ry = math.asin(sy)
    if abs(sy) < 0.99999:
        rx = math.atan2(-R[1][2], R[2][2])
        rz = math.atan2(-R[0][1], R[0][0])
    else:  # blocage de cardan : rz porté par rx
        rx = math.atan2(R[2][1], R[1][1])
        rz = 0.0
    return math.degrees(rx), math.degrees(ry), math.degrees(rz)


def ik2_3d(S, E, H, target, R1b, R2b, hint=(1.0, 0.0, 0.0)):
    """IK à deux os dans l'espace (épaule S, coude E, main H : positions de repos dans l'espace du parent).
    R1b, R2b : rotations de base (pose repliée) des deux os. Renvoie (R1, R2) qui posent la main sur `target`
    (espace du parent) en gardant le plan de pliage de la pose de base."""
    E1 = add(S, mvec(R1b, sub(E, S)))
    H1 = add(E1, mvec(mmul(R1b, R2b), sub(H, E)))
    a = math.dist(S, E1)
    b = math.dist(E1, H1)
    to = sub(target, S)
    d = max(abs(a - b) + 1e-4, min(a + b - 1e-4, math.sqrt(dot(to, to))))
    u = sub(S, E1)
    v = sub(H1, E1)
    n = cross(u, v)
    if dot(n, n) < 1e-10:
        n = hint
    n = norm(n)
    cos0 = max(-1.0, min(1.0, dot(norm(u), norm(v))))
    th0 = math.acos(cos0)
    th1 = math.acos(max(-1.0, min(1.0, (a * a + b * b - d * d) / (2 * a * b))))
    Rb = axis_angle(n, th1 - th0)
    H2 = add(E1, mvec(Rb, v))
    w0 = norm(sub(H2, S))
    w1 = norm(to)
    m = cross(w0, w1)
    if dot(m, m) < 1e-12:
        Ra = I3
    else:
        Ra = axis_angle(m, math.acos(max(-1.0, min(1.0, dot(w0, w1)))))
    R1 = mmul(Ra, R1b)
    n_loc = mvec(transpose(R1b), n)
    R2 = mmul(axis_angle(n_loc, th1 - th0), R2b)
    return R1, R2
