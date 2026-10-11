"""bscene : scène Blender d'un dino (armature + cubes liés aux os), lumières, sol et caméras de contrôle.

Tourne seulement dans Blender. Un Empty `RobloxSpace` tourné de +90° en X porte l'armature et le maillage : ses
enfants vivent dans les axes Roblox (X droite, Y haut, -Z avant) et le dino est debout dans la vue Blender (il
regarde vers +Y Blender). Pose bones en mode ZYX : rotation_euler = (rx, ry, rz) donne Rx * Ry * Rz, exactement
CFrame.Angles ; location = (px, py, pz) en studs. Même résultat que DinoBuilder.Solve."""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return bpy.context.scene


def _lin(c):
    return tuple((v / 255.0) ** 2.2 for v in c)


def material(cache, col, mat):
    key = (tuple(col), mat)
    if key in cache:
        return cache[key]
    m = bpy.data.materials.new("m%d" % len(cache))
    lin = _lin(col)
    m.diffuse_color = (*lin, 1.0)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    bsdf.inputs["Base Color"].default_value = (*lin, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.55 if mat == "Plastic" else 0.35
    if mat == "Neon":
        bsdf.inputs["Emission Color"].default_value = (*lin, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 2.5
    elif mat in ("Glass", "Ice"):
        bsdf.inputs["Alpha"].default_value = 0.7
        m.diffuse_color = (*lin, 0.7)
    elif mat == "Metal":
        bsdf.inputs["Metallic"].default_value = 0.8
    cache[key] = m
    return m


def build_rig(model, name="Dino"):
    """Armature (un os Blender par os du modèle) + un maillage de cubes (un groupe de sommets par os)."""
    sc = bpy.context.scene
    space = bpy.data.objects.new("RobloxSpace", None)
    space.rotation_euler = (math.radians(90), 0, 0)
    sc.collection.objects.link(space)
    arm_data = bpy.data.armatures.new(name + "Rig")
    arm = bpy.data.objects.new(name + "Rig", arm_data)
    sc.collection.objects.link(arm)
    arm.parent = space
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = {}
    blen = max(0.25, model["height"] * 0.04)
    for b in model["bones"]:
        e = arm_data.edit_bones.new(b["name"])
        e.head = Vector(b["pivot"])
        e.tail = Vector(b["pivot"]) + Vector((0, blen, 0))
        e.roll = 0
        eb[b["name"]] = e
    for b in model["bones"]:
        if b["parent"]:
            eb[b["name"]].parent = eb[b["parent"]]
            eb[b["name"]].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "ZYX"  # Blender applique Z, Y puis X = Rx * Ry * Rz (CFrame.Angles)
    REST.clear()
    for b in model["bones"]:
        if b.get("rest"):
            REST[b["name"]] = tuple(b["rest"])

    bm = bmesh.new()
    cache, slots, mats = {}, {}, []
    owner = []
    for bx in model["boxes"]:
        key = (tuple(bx["col"]), bx["mat"])
        if key not in slots:
            slots[key] = len(mats)
            mats.append(material(cache, bx["col"], bx["mat"]))
        cx, cy, cz = bx["c"]
        sx, sy, sz = [s / 2 for s in bx["s"]]
        vs = [bm.verts.new((cx + dx * sx, cy + dy * sy, cz + dz * sz)) for dx in (-1, 1) for dy in (-1, 1) for dz in (-1, 1)]
        for idx in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
            f = bm.faces.new([vs[i] for i in idx])
            f.material_index = slots[key]
        owner += [bx["bone"]] * 8
    bm.normal_update()
    me = bpy.data.meshes.new(name + "Voxels")
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    obj = bpy.data.objects.new(name + "Voxels", me)
    sc.collection.objects.link(obj)
    obj.parent = space
    groups = {b["name"]: obj.vertex_groups.new(name=b["name"]) for b in model["bones"]}
    by_bone = {}
    for i, bn in enumerate(owner):
        by_bone.setdefault(bn, []).append(i)
    for bn, idx in by_bone.items():
        groups[bn].add(idx, 1.0, "REPLACE")
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    apply_pose(arm, {})
    return space, arm, obj


REST = {}


def apply_pose(arm, pose):
    """Pose du jeu (rotations de repos des os comprises)."""
    for pb in arm.pose.bones:
        v = pose.get(pb.name) or (0, 0, 0, 0, 0, 0)
        r = REST.get(pb.name) or (0, 0, 0)
        pb.rotation_euler = (math.radians(v[0] + r[0]), math.radians(v[1] + r[1]), math.radians(v[2] + r[2]))
        pb.location = (v[3], v[4], v[5])
    bpy.context.view_layer.update()


def roblox_to_blender(p):
    """Point en axes Roblox -> monde Blender (x, -z, y)."""
    return Vector((p[0], -p[2], p[1]))


# ---------------------------------------------------------------------- rendu
def workbench(size_x, size_y):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x, sc.render.resolution_y = size_x, size_y
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sh = sc.display.shading
    # éclairage plat + cavité + ombres : vraies couleurs des briques, arêtes bien lisibles (rapide)
    sh.light = "FLAT"
    sh.color_type = "MATERIAL"
    sh.show_shadows = True
    sh.shadow_intensity = 0.4
    sh.show_cavity = True
    sh.cavity_type = "BOTH"
    sh.cavity_ridge_factor = 1.0
    sh.cavity_valley_factor = 1.0
    sh.curvature_ridge_factor = 0.8
    sh.curvature_valley_factor = 0.9
    sh.show_object_outline = False
    sc.display.light_direction = (0.45, -0.55, 0.7)
    sc.display.shadow_shift = 0.08
    sc.display.render_aa = "8"
    try:
        sc.view_settings.view_transform = "Standard"
    except Exception:
        pass


def eevee(size_x, size_y, sky=(0.62, 0.78, 0.95)):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = size_x, size_y
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    try:
        sc.eevee.taa_render_samples = 32
    except Exception:
        pass
    world = bpy.data.worlds.new("Sky")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (*[c ** 2.2 for c in sky], 1)
    bg.inputs[1].default_value = 0.8
    sun = bpy.data.lights.new("Sun", "SUN")
    sun.energy = 3.2
    sun.angle = math.radians(8)
    so = bpy.data.objects.new("Sun", sun)
    so.rotation_euler = (math.radians(42), math.radians(-12), math.radians(-35))
    sc.collection.objects.link(so)
    fill = bpy.data.lights.new("Fill", "SUN")
    fill.energy = 0.9
    fo = bpy.data.objects.new("Fill", fill)
    fo.rotation_euler = (math.radians(70), 0, math.radians(150))
    sc.collection.objects.link(fo)
    try:
        sc.view_settings.view_transform = "Standard"
    except Exception:
        pass


def set_world_color(rgb):
    sc = bpy.context.scene
    if sc.world is None:
        sc.world = bpy.data.worlds.new("W")
    sc.world.color = tuple(c ** 2.2 for c in rgb)
    if sc.world.use_nodes and sc.world.node_tree.nodes.get("Background"):
        sc.world.node_tree.nodes["Background"].inputs[0].default_value = (*[c ** 2.2 for c in rgb], 1)


def ground_tiles(extent, tile, colors, z=0.0, name="Ground"):
    """Sol en damier (deux couleurs) : sert de repère pour voir si les pieds glissent. Renvoie l'objet."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    mats = []
    for c in colors:
        m = bpy.data.materials.new(name + "M")
        lin = _lin(c)
        m.diffuse_color = (*lin, 1)
        m.use_nodes = True
        nt = m.node_tree
        nt.nodes.clear()
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(bsdf.outputs[0], out.inputs[0])
        bsdf.inputs["Base Color"].default_value = (*lin, 1)
        bsdf.inputs["Roughness"].default_value = 0.9
        mats.append(m)
        me.materials.append(m)
    n = int(math.ceil(extent / tile))
    for i in range(-n, n):
        for j in range(-n, n):
            vs = [bm.verts.new((i * tile + dx * tile, j * tile + dy * tile, z)) for dx, dy in ((0, 0), (1, 0), (1, 1), (0, 1))]
            f = bm.faces.new(vs)
            f.material_index = (i + j) % 2
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def dummy(x=0.0, y=0.0, color=(160, 170, 185)):
    """Silhouette d'avatar R6 de 5 studs (repère de taille), posée à (x, y) monde Blender, regarde vers +Y."""
    cache = {}
    parts = [((0, 0, 4.5), (1.2, 1.2, 1.0)), ((0, 0, 3.0), (2.0, 1.0, 2.0)), ((-1.5, 0, 3.0), (1.0, 1.0, 2.0)),
             ((1.5, 0, 3.0), (1.0, 1.0, 2.0)), ((-0.5, 0, 1.0), (1.0, 1.0, 2.0)), ((0.5, 0, 1.0), (1.0, 1.0, 2.0))]
    objs = []
    for (px, py, pz), (sx, sy, sz) in parts:
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x + px, y + py, pz))
        o = bpy.context.active_object
        o.scale = (sx, sy, sz)
        o.data.materials.append(material(cache, color, "Plastic"))
        objs.append(o)
    return objs


def ortho_camera(name, target, direction, ortho, dist=200.0):
    cd = bpy.data.cameras.new(name)
    cd.type = "ORTHO"
    cd.ortho_scale = ortho
    cd.clip_start = 0.1
    cd.clip_end = dist * 3
    co = bpy.data.objects.new(name, cd)
    bpy.context.scene.collection.objects.link(co)
    d = Vector(direction).normalized()
    co.location = Vector(target) + d * dist
    co.rotation_euler = (Vector(target) - co.location).to_track_quat("-Z", "Y").to_euler()
    return co


def fit_camera(cam, direction, lo, hi, margin=1.12):
    """Cadre une caméra orthographique sur une boîte (axes Roblox) vue depuis `direction` (monde Blender)."""
    d = Vector(direction).normalized()
    f = -d
    r = f.cross(Vector((0, 0, 1))).normalized()
    up = r.cross(f).normalized()
    pts = [roblox_to_blender((x, y, z)) for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]
    xs = [p.dot(r) for p in pts]
    ys = [p.dot(up) for p in pts]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    c = sum(pts, Vector((0, 0, 0))) / len(pts)
    target = c + r * (cx - c.dot(r)) + up * (cy - c.dot(up))
    cam.data.ortho_scale = max(w, h) * margin
    dist = 200.0
    cam.location = target + d * dist
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()


def render_to(path, cam):
    sc = bpy.context.scene
    sc.camera = cam
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
