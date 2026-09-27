from pathlib import Path
import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial
from trimesh.visual.texture import TextureVisuals

OUT = Path(__file__).resolve().parents[1] / "assets" / "models" / "okey"
OUT.mkdir(parents=True, exist_ok=True)


def material(name, rgba, metallic=0.0, roughness=0.5):
    return PBRMaterial(
        name=name,
        baseColorFactor=np.array(rgba, dtype=np.uint8),
        metallicFactor=metallic,
        roughnessFactor=roughness,
    )


def box(scene, name, size, position, mat):
    mesh = trimesh.creation.box(extents=size)
    mesh.apply_translation(position)
    mesh.visual = TextureVisuals(material=mat)
    scene.add_geometry(mesh, node_name=name, geom_name=name)


def cylinder(scene, name, radius, height, position, mat, sections=12):
    mesh = trimesh.creation.cylinder(radius=radius, height=height, sections=sections)
    mesh.apply_translation(position)
    mesh.visual = TextureVisuals(material=mat)
    scene.add_geometry(mesh, node_name=name, geom_name=name)


def export(scene, filename):
    (OUT / filename).write_bytes(scene.export(file_type="glb"))


def table(filename, felt_rgba, frame_rgba, accent_rgba):
    scene = trimesh.Scene()
    felt = material("felt", felt_rgba, 0.0, 0.82)
    frame = material("frame", frame_rgba, 0.25, 0.28)
    accent = material("accent", accent_rgba, 0.86, 0.18)
    dark = material("underside", [5, 10, 25, 255], 0.45, 0.34)
    box(scene, "table_underbody", [11.4, 6.9, 0.34], [0, 0, -0.34], dark)
    box(scene, "felt_surface", [10.35, 5.85, 0.22], [0, 0, 0], felt)
    box(scene, "frame_top", [11.2, 0.48, 0.54], [0, 3.15, 0.12], frame)
    box(scene, "frame_bottom", [11.2, 0.48, 0.54], [0, -3.15, 0.12], frame)
    box(scene, "frame_left", [0.48, 5.85, 0.54], [-5.36, 0, 0.12], frame)
    box(scene, "frame_right", [0.48, 5.85, 0.54], [5.36, 0, 0.12], frame)
    for x in (-5.36, 5.36):
        for y in (-3.15, 3.15):
            cylinder(scene, f"corner_{x}_{y}", 0.36, 0.62, [x, y, 0.14], accent)
    box(scene, "accent_top", [9.7, 0.07, 0.08], [0, 2.88, 0.43], accent)
    box(scene, "accent_bottom", [9.7, 0.07, 0.08], [0, -2.88, 0.43], accent)
    box(scene, "accent_left", [0.07, 5.2, 0.08], [-5.09, 0, 0.43], accent)
    box(scene, "accent_right", [0.07, 5.2, 0.08], [5.09, 0, 0.43], accent)
    export(scene, filename)


def rack(filename, wood_rgba, accent_rgba):
    scene = trimesh.Scene()
    wood = material("wood", wood_rgba, 0.18, 0.3)
    wood_dark = material("wood_dark", [22, 8, 5, 255], 0.08, 0.46)
    accent = material("accent", accent_rgba, 0.9, 0.16)
    box(scene, "rack_base", [5.8, 0.72, 0.26], [0, 0, 0], wood_dark)
    box(scene, "rack_back", [5.8, 0.25, 1.0], [0, 0.32, 0.55], wood)
    box(scene, "rack_front", [5.8, 0.18, 0.52], [0, -0.34, 0.22], wood)
    box(scene, "rack_middle_shelf", [5.55, 0.16, 0.18], [0, -0.06, 0.48], accent)
    box(scene, "rack_lower_shelf", [5.55, 0.16, 0.16], [0, -0.28, 0.18], accent)
    box(scene, "rack_left_cap", [0.28, 0.82, 1.18], [-2.92, 0, 0.43], accent)
    box(scene, "rack_right_cap", [0.28, 0.82, 1.18], [2.92, 0, 0.43], accent)
    box(scene, "rack_top_trim", [5.7, 0.08, 0.08], [0, 0.22, 1.06], accent)
    export(scene, filename)


def tile(filename, body_rgba, edge_rgba):
    scene = trimesh.Scene()
    body = material("tile_body", body_rgba, 0.08, 0.2)
    face = material("tile_face", [252, 250, 244, 255], 0.0, 0.16)
    edge = material("tile_edge", edge_rgba, 0.72, 0.2)
    box(scene, "tile_body", [0.56, 0.18, 0.82], [0, 0, 0], body)
    box(scene, "tile_face", [0.49, 0.025, 0.70], [0, -0.102, 0.02], face)
    box(scene, "tile_bottom_edge", [0.52, 0.04, 0.055], [0, -0.125, -0.365], edge)
    export(scene, filename)


def decoration(filename):
    scene = trimesh.Scene()
    gold = material("gold", [255, 190, 50, 255], 0.92, 0.14)
    dark_gold = material("dark_gold", [150, 76, 8, 255], 0.8, 0.24)
    box(scene, "logo_plate", [2.7, 0.08, 0.72], [0, 0, 0], dark_gold)
    box(scene, "logo_bar", [2.3, 0.05, 0.10], [0, -0.07, -0.22], gold)
    for index, x in enumerate((-0.65, 0, 0.65)):
        cone = trimesh.creation.cone(radius=0.25, height=0.62 if index == 1 else 0.48, sections=8)
        cone.apply_translation([x, 0, 0.34])
        cone.visual = TextureVisuals(material=gold)
        scene.add_geometry(cone, node_name=f"crown_peak_{index}", geom_name=f"crown_peak_{index}")
    export(scene, filename)


table("table_emerald.glb", [4, 89, 65, 255], [33, 17, 16, 255], [240, 172, 57, 255])
table("table_midnight.glb", [10, 28, 71, 255], [12, 18, 42, 255], [78, 124, 255, 255])
rack("rack_royal_gold.glb", [72, 26, 14, 255], [231, 166, 61, 255])
rack("rack_obsidian.glb", [18, 21, 33, 255], [94, 115, 178, 255])
tile("tile_crystal.glb", [216, 236, 255, 235], [120, 186, 255, 255])
tile("tile_ivory.glb", [245, 239, 219, 255], [199, 167, 100, 255])
decoration("decoration_okey.glb")
print(f"Generated OKEY 3D assets in {OUT}")
