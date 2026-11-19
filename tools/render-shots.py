#!/usr/bin/env python3
"""render-shots.py — draw the screenshots for Brainrot Bazaar.

One job: turn the place into pictures. It reads the same
default.project.json the place is built from — every island, conveyor,
plot, palm, sign and sample brainrot is a part the generator placed,
at its real position, size and colour — and draws it in an isometric
view, then overlays the same HUD text Hud.client.luau draws. The
brainrot labels come from tools/world-manifest.json, the same catalog
data the server uses at runtime. Nothing pictured is gameplay the code
does not have. See SCREENSHOTS.md.

Usage: python3 tools/render-shots.py
Writes screenshots/1-start.jpg, 2-play.jpg, 3-end.jpg (1280x720,
each under 256 KiB).
"""

import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
W = 1280
H = 720

BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def font(size, bold=True):
    return ImageFont.truetype(BOLD if bold else REG, int(size))


# Rarity colours, the same values Catalog.luau holds.
RARITY_COLORS = {
    "Common": (200, 200, 200),
    "Rare": (80, 160, 255),
    "Epic": (180, 90, 255),
    "Legendary": (255, 170, 0),
    "Mythic": (255, 70, 90),
    "Secret": (0, 230, 200),
}
MUTATION_COLORS = {
    "Normal": (255, 255, 255),
    "Golden": (255, 215, 0),
    "Diamond": (120, 220, 255),
    "Rainbow": (255, 120, 220),
}


# ---------------------------------------------------------------- world
def walk_project(node, path, parts, models):
    """Collect every Part-like instance, grouped by parent Model."""
    if not isinstance(node, dict):
        return
    cls = node.get("$className")
    props = node.get("$properties", {}) or {}
    name = path[-1] if path else "root"
    if cls in ("Part", "WedgePart", "SpawnLocation"):
        parts.append({
            "name": name,
            "class": cls,
            "pos": props.get("Position", [0, 0, 0]),
            "size": props.get("Size", [1, 1, 1]),
            "color": props.get("Color", [0.5, 0.5, 0.5]),
            "transparency": props.get("Transparency", 0),
            "shape": props.get("Shape", "Block"),
            "model": path[-2] if len(path) >= 2 and path[-2] in models else None,
        })
    if cls == "Model":
        models.add(name)
    for key, child in node.items():
        if key.startswith("$"):
            continue
        walk_project(child, path + [key], parts, models)


def load_world():
    with open(os.path.join(ROOT, "default.project.json")) as f:
        project = json.load(f)
    with open(os.path.join(HERE, "world-manifest.json")) as f:
        manifest = json.load(f)
    parts, models = [], set()
    walk_project(project["tree"]["Workspace"], ["Workspace"], parts, models)
    return parts, manifest


# ------------------------------------------------------------- projection
class Camera:
    """Isometric camera: +X runs right-down, +Z left-down, +Y up."""

    def __init__(self, focus, margin=40):
        # focus: ((xmin, ymin, zmin), (xmax, ymax, zmax)) world box.
        (x0, y0, z0), (x1, y1, z1) = focus
        corners = [(x, y, z) for x in (x0, x1) for y in (y0, y1) for z in (z0, z1)]
        px = [self.raw_x(x, z) for x, y, z in corners]
        py = [self.raw_y(x, y, z) for x, y, z in corners]
        bw, bh = max(px) - min(px), max(py) - min(py)
        self.s = min((W - 2 * margin) / bw, (H - 2 * margin) / bh)
        self.cx = W / 2 - (min(px) + max(px)) / 2 * self.s
        self.cy = H / 2 - (min(py) + max(py)) / 2 * self.s

    @staticmethod
    def raw_x(x, z):
        return (x - z) * 0.866

    @staticmethod
    def raw_y(x, y, z):
        return (x + z) * 0.5 - y

    def project(self, x, y, z):
        return (self.cx + self.raw_x(x, z) * self.s,
                self.cy + self.raw_y(x, y, z) * self.s)


def shade(rgb, factor):
    return tuple(max(0, min(255, int(c * 255 * factor))) for c in rgb)


def rgba(rgb, alpha=255):
    """An (r, g, b) triple in 0-255 (as shade() returns) plus alpha."""
    r, g, b = (max(0, min(255, int(c))) for c in rgb)
    return (r, g, b, alpha)


# ---------------------------------------------------------------- drawing
class Scene:
    """Collects faces, then paints far-to-near. A face's depth is the
    smallest x+y+z over its corners: in this view larger x+y+z is
    nearer the camera, so the farthest face paints first. That keeps
    small things sitting on big planes (chevrons on the belt, a
    brainrot on a plot) visible instead of painted over."""

    def __init__(self, camera):
        self.cam = camera
        self.img = Image.new("RGB", (W, H), (126, 200, 247))
        self.draw_sky()
        self.faces = []  # (depth, kind, payload)

    def draw_sky(self):
        d = ImageDraw.Draw(self.img)
        for y in range(H):
            t = y / H
            r = int(126 + (207 - 126) * t)
            g = int(200 + (238 - 200) * t)
            b = int(247 + (251 - 247) * t)
            d.line([(0, y), (W, y)], fill=(r, g, b))
        # Sun, top-right.
        d.ellipse([W - 190, 50, W - 110, 130], fill=(255, 244, 180))

    def overlay(self):
        """A transparent layer to draw one face on, then composite."""
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        return layer, ImageDraw.Draw(layer)

    def commit(self, layer):
        self.img = Image.alpha_composite(self.img.convert("RGBA"), layer).convert("RGB")

    def draw_box(self, pos, size, color, transparency=0):
        """A part as three faces: top (light), +Z (mid), +X (dark)."""
        cx, cy, cz = pos
        sx, sy, sz = size
        corners = {}
        for dx in (-1, 1):
            for dy in (-1, 1):
                for dz in (-1, 1):
                    corners[(dx, dy, dz)] = self.cam.project(
                        cx + dx * sx / 2, cy + dy * sy / 2, cz + dz * sz / 2)
        alpha = int(255 * (1 - transparency))
        # +Z face (left-down), +X face (right-down), top face. Each
        # face carries the smallest x+y+z of its corners as its depth.
        def face_depth(keys):
            return min(cx + dx * sx / 2 + cy + dy * sy / 2 + cz + dz * sz / 2
                       for dx, dy, dz in keys)
        self.faces.append((face_depth([(-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]),
                           "poly", (corners[(-1, -1, 1)], corners[(1, -1, 1)],
                                    corners[(1, 1, 1)], corners[(-1, 1, 1)]),
                           rgba(shade(color, 0.85), alpha)))
        self.faces.append((face_depth([(1, -1, -1), (1, -1, 1), (1, 1, 1), (1, 1, -1)]),
                           "poly", (corners[(1, -1, -1)], corners[(1, -1, 1)],
                                    corners[(1, 1, 1)], corners[(1, 1, -1)]),
                           rgba(shade(color, 0.7), alpha)))
        self.faces.append((face_depth([(-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1)]),
                           "poly", (corners[(-1, 1, -1)], corners[(1, 1, -1)],
                                    corners[(1, 1, 1)], corners[(-1, 1, 1)]),
                           rgba(shade(color, 1.12), alpha)))

    def draw_ball(self, pos, size, color, transparency=0):
        cx, cy, cz = pos
        sx, sy, sz = size
        px, py = self.cam.project(cx, cy, cz)
        rx = max(sx, sz) * 0.866 * self.cam.s * 0.62
        ry = max(sy * self.cam.s * 0.62, rx * 0.75)
        alpha = int(255 * (1 - transparency))
        depth = cx + cy + cz - max(sx, sy, sz) / 2
        self.faces.append((depth, "ball",
                           (px - rx, py - ry, px + rx, py + ry),
                           rgba(shade(color, 1.0), alpha)))
        self.faces.append((depth + 0.01, "ball",
                           (px - rx * 0.7, py - ry * 0.75, px + rx * 0.1, py - ry * 0.1),
                           rgba(shade(color, 1.18), int(alpha * 0.55))))

    def flush(self):
        """Paint every collected face, far first."""
        for _, kind, geom, fill in sorted(self.faces, key=lambda f: f[0]):
            layer, d = self.overlay()
            if kind == "poly":
                d.polygon(list(geom), fill=fill)
            else:
                d.ellipse(list(geom), fill=fill)
            self.commit(layer)
        self.faces = []

    def draw_part(self, part):
        if part["shape"] == "Ball":
            self.draw_ball(part["pos"], part["size"], part["color"], part["transparency"])
        else:
            self.draw_box(part["pos"], part["size"], part["color"], part["transparency"])

    def draw_avatar(self, x, y, z):
        """A generic blocky Roblox avatar stand-in, for scale."""
        s = self.cam.s
        # Legs, torso, arms, head — small boxes at the given spot.
        leg_w = 0.9 * s
        self.draw_box([x - 0.55, y + 0.9, z], [0.9, 1.8, 0.9], (60, 160, 60))
        self.draw_box([x + 0.55, y + 0.9, z], [0.9, 1.8, 0.9], (60, 160, 60))
        self.draw_box([x, y + 2.7, z], [2.2, 1.8, 1.1], (40, 110, 220))
        self.draw_box([x - 1.5, y + 2.7, z], [0.7, 1.8, 0.9], (250, 210, 110))
        self.draw_box([x + 1.5, y + 2.7, z], [0.7, 1.8, 0.9], (250, 210, 110))
        self.draw_box([x, y + 4.4, z], [1.9, 1.6, 1.6], (250, 210, 110))

    def draw_character_label(self, char):
        """Name + rarity + $/s above a brainrot, as the server labels it."""
        px, py = self.cam.project(char["x"], char["y"] + 5.6, char["z"])
        name = char["name"]
        if char["mutation"] != "Normal":
            name = char["mutation"] + " " + name
        line2 = f"{char['rarity']}  ${char['income']}/s"
        f1, f2 = font(17), font(14)
        w1 = f1.getlength(name)
        w2 = f2.getlength(line2)
        bw = max(w1, w2) + 18
        bh = 46
        layer, d = self.overlay()
        d.rounded_rectangle([px - bw / 2, py - bh, px + bw / 2, py],
                            radius=8, fill=(20, 20, 32, 215))
        d.text((px - w1 / 2, py - bh + 5), name, font=f1,
               fill=MUTATION_COLORS[char["mutation"]] + (255,))
        d.text((px - w2 / 2, py - bh + 25), line2, font=f2,
               fill=RARITY_COLORS[char["rarity"]] + (255,))
        self.commit(layer)

    def draw_sign_text(self, sign):
        """The text on a sign board, centred on its facing face."""
        x, y, z = sign["pos"]
        w, h = sign["size"]
        face = sign["face"]
        normal = {"Front": (0, 0, 1), "Back": (0, 0, -1),
                  "Right": (1, 0, 0), "Left": (-1, 0, 0)}[face]
        # Face centre: board centre pushed half a stud out along the face.
        cx, cy, cz = x + normal[0] * 0.6, y, z + normal[2] * 0.6
        px, py = self.cam.project(cx, cy, cz)
        # Face width on screen: the board's long axis projected.
        if face in ("Front", "Back"):
            ax, az = self.cam.project(cx + w / 2, cy, cz)
            bx, bz = self.cam.project(cx - w / 2, cy, cz)
            face_w = abs(ax - bx)
        else:
            ax, az = self.cam.project(cx, cy, cz + w / 2)
            bx, bz = self.cam.project(cx, cy, cz - w / 2)
            face_w = abs(ax - bx)
        face_h = h * self.cam.s * 0.9
        text = sign["text"]
        size = min(face_w / max(1, len(text) * 0.62), face_h * 0.72, 64)
        f = font(max(10, size))
        tw = f.getlength(text)
        d = ImageDraw.Draw(self.img)
        d.text((px - tw / 2, py - size * 0.55), text, font=f,
               fill=(255, 210, 90) if "BAZAAR" in text else
               ((255, 90, 90) if "TSUNAMI" in text else (255, 255, 255)))


# ------------------------------------------------------------------- HUD
def panel(d, box, fill=(25, 25, 38, 215)):
    d.rounded_rectangle(box, radius=10, fill=fill)


def hud_top_bar(img, cash, income, rebirths):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    panel(d, [W / 2 - 260, 10, W / 2 + 260, 74])
    d.text((W / 2 - 244, 20), cash, font=font(36), fill=(255, 255, 255, 255))
    d.text((W / 2 - 20, 28), income, font=font(24), fill=(90, 230, 130, 255))
    d.text((W / 2 + 105, 30), rebirths, font=font(20), fill=(255, 210, 90, 255))
    panel(d, [W - 240, 10, W - 16, 58], fill=(60, 120, 230, 230))
    d.text((W - 228, 22), "LOCK BASE (60s)", font=font(18), fill=(255, 255, 255, 255))
    panel(d, [W - 240, 66, W - 16, 114], fill=(200, 130, 30, 230))
    d.text((W - 228, 78), "REBIRTH $10,000", font=font(18), fill=(255, 255, 255, 255))
    return Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")


def hud_shop(img, cash):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    panel(d, [12, 90, 312, 340])
    d.text((26, 100), "NEXT TIERS", font=font(22), fill=(255, 210, 90, 255))
    rows = [
        ("General Gherkin", "Legendary", 40, 2600),
        ("Queen Quokka", "Legendary", 65, 5200),
        ("Lord Lox", "Mythic", 120, 12000),
        ("The Grand Toaster", "Mythic", 200, 26000),
        ("Emperor Eggroll", "Secret", 400, 65000),
    ]
    for i, (name, rarity, per, cost) in enumerate(rows):
        y = 132 + i * 40
        d.text((26, y), f"{name}  ${per}/s  ${cost:,}", font=font(16),
               fill=RARITY_COLORS[rarity] + (255,))
    return Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")


def hud_base(img):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    panel(d, [W - 312, 130, W - 12, 300])
    d.text((W - 298, 140), "YOUR BASE", font=font(22), fill=(120, 220, 255, 255))
    rows = [
        ("Sir Picklefoot", "$1/s", 25),
        ("Madame Croissant", "$5/s", 150),
        ("Professor Bananas", "$15/s", 650),
    ]
    for i, (name, per, cost) in enumerate(rows):
        y = 172 + i * 40
        d.text((W - 298, y), name, font=font(17), fill=(230, 230, 230, 255))
        d.rounded_rectangle([W - 96, y - 2, W - 28, y + 26], radius=8, fill=(180, 60, 60, 235))
        d.text((W - 84, y + 1), "SELL", font=font(15), fill=(255, 255, 255, 255))
    return Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")


def hud_hint(img, text):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    f = font(20)
    tw = f.getlength(text)
    panel(d, [W / 2 - tw / 2 - 16, H - 52, W / 2 + tw / 2 + 16, H - 16])
    d.text((W / 2 - tw / 2, H - 44), text, font=f, fill=(255, 255, 255, 255))
    return Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")


def hud_slap(img):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([W - 160, H - 120, W - 20, H - 64], radius=10, fill=(200, 50, 70, 235))
    d.text((W - 140, H - 106), "SLAP  (F)", font=font(22), fill=(255, 255, 255, 255))
    return Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")


def hud_toast(img, text):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    f = font(18)
    panel(d, [12, H - 200, 12 + f.getlength(text) + 28, H - 166])
    d.text((26, H - 192), text, font=f, fill=(255, 255, 255, 255))
    return Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")


def start_screen(img):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rectangle([0, 0, W, H], fill=(15, 15, 28, 150))
    # Solid panel behind the title block so the world labels do not
    # collide with the how-to text; the world still shows around it.
    # Fully opaque: a translucent panel still lets white label text
    # bleed through over the dark fill.
    d.rounded_rectangle([W / 2 - 420, 110, W / 2 + 420, 510], radius=16,
                        fill=(20, 20, 35, 255))
    title = "BRAINROT BAZAAR"
    f = font(64)
    d.text(((W - f.getlength(title)) / 2, 130), title, font=f, fill=(255, 210, 90, 255))
    sub = "Collect the snack-creatures. Guard your base. Outrun the wave."
    f2 = font(24)
    d.text(((W - f2.getlength(sub)) / 2, 210), sub, font=f2, fill=(255, 255, 255, 255))
    lines = [
        "1. Buy brainrots off the conveyor (press E)",
        "2. They earn money every second on your base",
        "3. Steal from rivals - and SLAP thieves with F",
        "4. When the TSUNAMI comes, run home!",
    ]
    f3 = font(22)
    for i, line in enumerate(lines):
        d.text(((W - f3.getlength(line)) / 2, 265 + i * 34), line, font=f3,
               fill=(230, 230, 230, 255))
    d.rounded_rectangle([W / 2 - 110, 425, W / 2 + 110, 489], radius=10, fill=(60, 180, 80, 255))
    fp = font(32)
    d.text((W / 2 - fp.getlength("PLAY") / 2, 437), "PLAY", font=fp, fill=(255, 255, 255, 255))
    return Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")


def wave_banner(img, text):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    f = font(26)
    tw = f.getlength(text)
    d.rounded_rectangle([W / 2 - tw / 2 - 20, 84, W / 2 + tw / 2 + 20, 140],
                        radius=10, fill=(200, 40, 40, 235))
    d.text((W / 2 - tw / 2, 98), text, font=f, fill=(255, 255, 255, 255))
    return Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")


def rebirth_banner(img):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    text = "REBIRTH! Income x2 forever"
    f = font(30)
    tw = f.getlength(text)
    d.rounded_rectangle([W / 2 - tw / 2 - 24, 580, W / 2 + tw / 2 + 24, 660],
                        radius=10, fill=(200, 130, 30, 240))
    d.text((W / 2 - tw / 2, 602), text, font=f, fill=(255, 255, 255, 255))
    return Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")


def wave_wall(scene):
    """The tsunami wall sweeping in from the west: a tall translucent
    blue slab across the map, drawn after the world, before the HUD."""
    cam = scene.cam
    x = -20
    corners = []
    for (px, py, pz) in [(x - 5, -2, -130), (x + 5, -2, -130), (x + 5, 50, -130),
                         (x - 5, 50, -130), (x - 5, -2, 130), (x + 5, -2, 130),
                         (x + 5, 50, 130), (x - 5, 50, 130)]:
        corners.append(cam.project(px, py, pz))
    layer, d = scene.overlay()
    # Front face of the wall (the +X side, facing the camera).
    d.polygon([corners[5], corners[6], corners[2], corners[1]], fill=(40, 120, 220, 110))
    d.polygon([corners[4], corners[5], corners[6], corners[7]], fill=(90, 160, 240, 90))
    scene.commit(layer)


# ------------------------------------------------------------------- shots
def render_shot(parts, manifest, focus, avatar, wave=False):
    cam = Camera(focus)
    scene = Scene(cam)
    # Faces carry their own depth, so parts can be drawn in any order;
    # the flush paints them far-to-near.
    for p in parts:
        scene.draw_part(p)
    if avatar:
        scene.draw_avatar(*avatar)
    scene.flush()
    for ch in manifest["characters"]:
        scene.draw_character_label(ch)
    for sign in manifest["signs"]:
        scene.draw_sign_text(sign)
    if wave:
        wave_wall(scene)
    return scene.img


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    for quality in (82, 75, 68):
        img.save(path, "JPEG", quality=quality, optimize=True)
        if os.path.getsize(path) <= 256 * 1024:
            return quality
    raise SystemExit(f"{path} still over 256 KiB at quality 68")


def main():
    parts, manifest = load_world()
    print(f"{len(parts)} parts, {len(manifest['characters'])} characters")

    # 1 — start: the bazaar from the conveyor's west end, start screen on.
    img = render_shot(parts, manifest,
                      focus=((-60, -4, -55), (40, 25, 45)),
                      avatar=(-45, 1.0, -6))
    img = start_screen(img)
    save(img, os.path.join(ROOT, "screenshots", "1-start.jpg"))
    print("1-start.jpg", os.path.getsize(os.path.join(ROOT, "screenshots", "1-start.jpg")))

    # 2 — play: the conveyor and the south-centre base, full HUD.
    # Cash $1,284 at +$21/s: the three placed brainrots earn
    # $1 + $5 + $15 a second. The shop lists the five cheapest
    # brainrots above the player's cash.
    img = render_shot(parts, manifest,
                      focus=((-48, -4, -14), (48, 18, 44)),
                      avatar=(-6, 1.0, -8))
    img = hud_top_bar(img, "$1,284", "+$21/s", "REBIRTH x1")
    img = hud_shop(img, 1284)
    img = hud_base(img)
    img = hud_hint(img, "Walk to the conveyor - press E on a brainrot to buy it!")
    img = hud_slap(img)
    img = hud_toast(img, "Bought Sir Picklefoot for $25 - earning $1/s!")
    save(img, os.path.join(ROOT, "screenshots", "2-play.jpg"))
    print("2-play.jpg", os.path.getsize(os.path.join(ROOT, "screenshots", "2-play.jpg")))

    # 3 — end: the tsunami sweeping in, rebirth banner up.
    img = render_shot(parts, manifest,
                      focus=((-70, -4, -55), (60, 30, 45)),
                      avatar=(0, 0.6, 30), wave=True)
    img = hud_top_bar(img, "$3,420", "+$21/s", "REBIRTH x2")
    img = wave_banner(img, "TSUNAMI INCOMING - RUN TO YOUR BASE!  7s")
    img = rebirth_banner(img)
    img = hud_hint(img, "The wave is here - get on your base!")
    save(img, os.path.join(ROOT, "screenshots", "3-end.jpg"))
    print("3-end.jpg", os.path.getsize(os.path.join(ROOT, "screenshots", "3-end.jpg")))


if __name__ == "__main__":
    main()
