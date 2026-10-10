"""families : description du squelette d'une espèce (RigInfo) et choix de la famille de mouvement.

Noms d'os communs à toutes les espèces (le jeu et les hybrides en dépendent) :
  Hips (racine, bassin), Chest (torse avant), Neck1..NeckN, Head, Jaw, LidL/LidR, Tail1..TailN,
  Thigh/Shin/Foot L/R (pattes arrière), Arm/Forearm/Hand L/R (bras ou pattes avant),
  Wing1..3 L/R (ailes), FinF1..2 / FinB1..2 L/R (nageoires), Frill, Crest (décor de tête).
Groupes (pour les hybrides) : Head, Body, Tail, Legs, Arms, Wings, Fins."""
from __future__ import annotations

import math

from anim import Limb

FAMILIES = ("Biped", "Quadruped", "Flyer", "Swimmer")

DEFAULT_PERSONALITY = {
    "tempo": 1.0, "weight": 1.0, "stride": 1.0, "bob": 1.0, "headBob": 0.0, "tail": 1.0,
    "diet": "plants", "happy": "hop", "catch": "headbutt",
}


def group_of(bone):
    if bone.startswith(("Neck", "Head", "Jaw", "Lid", "Frill", "Crest", "Horn")):
        return "Head"
    if bone.startswith("Tail"):
        return "Tail"
    if bone.startswith(("Thigh", "Shin", "Foot")):
        return "Legs"
    if bone.startswith(("Arm", "Forearm", "Hand")):
        return "Arms"
    if bone.startswith("Wing"):
        return "Wings"
    if bone.startswith("Fin"):
        return "Fins"
    return "Body"


class RigInfo:
    def __init__(self, model, sk, species):
        self.model = model
        self.sk = sk
        self.family = species.FAMILY
        self.name = model["name"]
        self.P = dict(DEFAULT_PERSONALITY)
        self.P.update(getattr(species, "PERSONALITY", {}))
        self.height = model["height"]
        self.voxel = model["voxel"]
        names = sk.order
        self.has = set(names)
        self.neck = sorted([n for n in names if n.startswith("Neck")], key=lambda n: int(n[4:] or 0))
        self.tail = sorted([n for n in names if n.startswith("Tail")], key=lambda n: int(n[4:] or 0))
        self.lids = [n for n in ("LidL", "LidR") if n in self.has]
        self.lid_drop = max(model.get("lids", {}).values() or [self.voxel * 2])
        self.hip_h = sk.pivot["Hips"][1]
        self.u = self.hip_h                         # unité de déplacement : hauteur de hanche (studs)
        self.limbs = {}
        pts = model["points"]
        if self.family in ("Biped", "Quadruped", "Flyer"):
            for s in ("L", "R"):
                if "Thigh" + s in self.has:
                    self.limbs["Leg" + s] = Limb("Leg" + s, ("Thigh" + s, "Shin" + s, "Foot" + s), sk.parent["Thigh" + s],
                                                 +1, pts["Toe" + s]["p"], sk)
        if self.family == "Quadruped":
            for s in ("L", "R"):
                self.limbs["Front" + s] = Limb("Front" + s, ("Arm" + s, "Forearm" + s, "Hand" + s), sk.parent["Arm" + s],
                                               -1, pts["FrontToe" + s]["p"], sk)
        # volants : les ailes sont posées par fam_flyer (orientations + IK 3D des mains), pas par Limb
        self.tempo = float(self.P["tempo"])
        self.weight = float(self.P["weight"])

    def T(self, seconds):
        """Durée de base -> durée pour cette espèce (cadence)."""
        return round(seconds / self.tempo, 3)

    def groups(self):
        out = {}
        for n in self.sk.order:
            out.setdefault(group_of(n), []).append(n)
        return out


def make_rig(model, sk, species):
    return RigInfo(model, sk, species)


def build_clips(rig):
    if rig.family == "Biped":
        import fam_biped as fam
    elif rig.family == "Quadruped":
        import fam_quadruped as fam
    elif rig.family == "Flyer":
        import fam_flyer as fam
    elif rig.family == "Swimmer":
        import fam_swimmer as fam
    else:
        raise ValueError("famille inconnue : %s" % rig.family)
    clips = fam.build(rig)
    for c in clips.values():
        if c.loop:
            check_loop(c)
    return clips


def check_loop(c):
    """Une boucle doit finir comme elle commence (sinon saut visible)."""
    a = c.pose_at(0.0)
    b = c.pose_at(c.length)
    worst = 0.0
    for bone in set(a) | set(b):
        va, vb = a.get(bone, [0.0] * 6), b.get(bone, [0.0] * 6)
        for i in range(6):
            d = abs(va[i] - vb[i]) / (1.0 if i < 3 else 0.02)
            worst = max(worst, d)
    if worst > 1.0:
        print("[anim] attention : la boucle %s ne se referme pas (écart %.2f)" % (c.name, worst))
