#!/usr/bin/env python3
"""Generate platform artwork from the approved design/branding/velo mark.

Requires Pillow. Bundle IDs, deep links and on-disk settings keep their existing
identities so a Velo update can reuse the installed client's data.
"""

from __future__ import annotations

from pathlib import Path
import json
import re
import shutil
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "design/branding/velo"
RES = ROOT / "android/app/src/main/res"
ICON = Image.open(SOURCE / "velo-icon-1024.png").convert("RGBA")
SVG_NS = "{http://www.w3.org/2000/svg}"
ET.register_namespace("", SVG_NS[1:-1])
SVG = ET.parse(SOURCE / "velo-icon.svg")
GLYPH_PATH = SVG.find(f".//{SVG_NS}path[@id='silhouette']").get("d")


def save_square(path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    ICON.resize((size, size), Image.Resampling.LANCZOS).save(path)


def glyph(size: int) -> Image.Image:
    # Render the canonical filled silhouette at 4x, then downsample. Sample its
    # cubic curves so notification and monochrome artwork share the same shape.
    scale = size * 4 / 1024
    image = Image.new("RGBA", (size * 4, size * 4))
    draw = ImageDraw.Draw(image)
    tokens = iter(re.findall(r"[MCLZ]|-?\d+(?:\.\d+)?", GLYPH_PATH))
    points = []
    current = (0, 0)
    for command in tokens:
        if command in ("M", "L"):
            current = (float(next(tokens)), float(next(tokens)))
            points.append(current)
        elif command == "C":
            p0 = current
            p1, p2, p3 = [(float(next(tokens)), float(next(tokens))) for _ in range(3)]
            for step in range(1, 65):
                t = step / 64
                points.append(tuple((1-t)**3*p0[i] + 3*(1-t)**2*t*p1[i]
                                    + 3*(1-t)*t*t*p2[i] + t**3*p3[i] for i in (0, 1)))
            current = p3
        elif command != "Z":
            raise ValueError(f"Unsupported silhouette command: {command}")
    draw.polygon([(x * scale, y * scale) for x, y in points], fill="white")
    return image.resize((size, size), Image.Resampling.LANCZOS)


def centered(size: tuple[int, int], background=(0, 0, 0, 0), edge: int | None = None) -> Image.Image:
    image = Image.new("RGBA", size, background)
    side = edge or min(size)
    image.alpha_composite(ICON.resize((side, side), Image.Resampling.LANCZOS),
                          ((size[0] - side) // 2, (size[1] - side) // 2))
    return image


def android_vectors() -> None:
    header = ('<?xml version="1.0" encoding="utf-8"?>\n'
              '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
              '    xmlns:aapt="http://schemas.android.com/aapt"\n'
              '    android:width="108dp" android:height="108dp"\n'
              '    android:viewportWidth="1024" android:viewportHeight="1024">\n')
    # Project gradients and surfaces from the SVG instead of retaining a second,
    # hand-maintained Android design.
    gradients = {g.get("id"): g for g in SVG.findall(f".//{SVG_NS}linearGradient")}
    paths = []
    for node in SVG.findall(f".//{SVG_NS}g[@id='mark']/{SVG_NS}path"):
        attrs = [f'android:pathData="{node.get("d")}"']
        body = []
        opacity = float(node.get("opacity", "1"))
        for svg_attr, android_attr in (("fill", "fillColor"), ("stroke", "strokeColor")):
            color = node.get(svg_attr, "none")
            alpha = opacity * float(node.get(f"{svg_attr}-opacity", "1"))
            if color.startswith("url(#"):
                g = gradients[color[5:-1]]
                body.append(f'<aapt:attr name="android:{android_attr}"><gradient android:type="linear" '
                            f'android:startX="{g.get("x1")}" android:startY="{g.get("y1")}" '
                            f'android:endX="{g.get("x2")}" android:endY="{g.get("y2")}">')
                for stop in g:
                    a = round(255 * float(stop.get("stop-opacity", "1")))
                    body.append(f'<item android:color="#{a:02X}{stop.get("stop-color")[1:]}" '
                                f'android:offset="{stop.get("offset", "0")}"/>')
                body.append('</gradient></aapt:attr>')
            else:
                attrs.append(f'android:{android_attr}="{color if color != "none" else "#00000000"}"')
            if alpha != 1:
                attrs.append(f'android:{svg_attr}Alpha="{alpha:g}"')
        if node.get("stroke-width"):
            attrs.append(f'android:strokeWidth="{node.get("stroke-width")}"')
            attrs.append(f'android:strokeLineCap="{node.get("stroke-linecap", "butt")}"')
        path = '<path ' + ' '.join(attrs) + '>' + ''.join(body) + '</path>'
        transform = node.get("transform", "")
        if transform:
            transforms = []
            for op, args in re.findall(r"(translate|scale)\(([^)]+)\)", transform):
                values = args.split()
                for axis, value in zip(("X", "Y"), values):
                    transforms.append(f'android:{op}{axis}="{value}"')
            path = '<group ' + ' '.join(transforms) + '>' + path + '</group>'
        paths.append(path)
    (RES / "drawable/ic_launcher_foreground.xml").write_text(header + '\n'.join(paths) + '\n</vector>\n')
    # Android 12 places this drawable in a 288dp system icon area. Halving the
    # artwork yields the same small, unframed glyph as Flutter's 144dp canvas.
    (RES / "drawable/splash_icon.xml").write_text(
        header + '<group android:scaleX="0.5" android:scaleY="0.5" '
        'android:pivotX="512" android:pivotY="512">\n' + '\n'.join(paths)
        + '\n</group>\n</vector>\n'
    )
    (RES / "drawable/ic_launcher_monochrome.xml").write_text(
        header + f'<path android:pathData="{GLYPH_PATH}" android:fillColor="#FFFFFFFF"/>\n</vector>\n')


def main() -> None:
    shutil.copyfile(SOURCE / "velo-icon-1024.png", ROOT / "assets/velo.png")
    shutil.copyfile(SOURCE / "velo-icon.svg", ROOT / "assets/velo_icon.svg")
    android_vectors()
    for density, launcher_size, notification_size in [
        ("mdpi", 48, 24), ("hdpi", 72, 36), ("xhdpi", 96, 48),
        ("xxhdpi", 144, 72), ("xxxhdpi", 192, 96),
    ]:
        save_square(RES / f"mipmap-{density}/ic_launcher.png", launcher_size)
        # Crop transparent source margins so the notification glyph remains legible.
        mark = glyph(256)
        mark = mark.crop(mark.getbbox())
        mark.thumbnail((notification_size - 2, notification_size - 2), Image.Resampling.LANCZOS)
        image = Image.new("RGBA", (notification_size, notification_size))
        image.alpha_composite(mark, ((notification_size - mark.width) // 2, (notification_size - mark.height) // 2))
        image.save(RES / f"drawable-{density}/ic_stat_notification.png")
    for density, width, height in [("xhdpi", 320, 180), ("xxhdpi", 480, 270), ("xxxhdpi", 640, 360)]:
        image = Image.new("RGBA", (width, height), (14, 15, 18, 255))
        edge = round(height * .68)
        image.alpha_composite(ICON.resize((edge, edge), Image.Resampling.LANCZOS), (round(width * .12), (height - edge) // 2))
        draw = ImageDraw.Draw(image)
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", round(height * .27))
        draw.text((round(width * .52), height // 2), "Velo", font=font, fill="white", anchor="lm")
        image.convert("RGB").save(RES / f"drawable-{density}/tv_banner.png")

    # Icon Composer supplies the platform background; use only the approved glyph.
    svg = ET.parse(SOURCE / "velo-icon.svg")
    root = svg.getroot()
    for child in list(root):
        if child.get("id") == "background":
            root.remove(child)
    ET.indent(svg, space="  ")
    svg.write(ROOT / "assets/velo_glyph.svg", encoding="unicode")
    for platform in ("ios", "macos"):
        icon = ROOT / platform / "plezy.icon"
        svg.write(icon / "Assets/plezy-cropped.svg", encoding="unicode")
        config = json.loads((icon / "icon.json").read_text())
        config["groups"][0]["layers"][0]["position"]["scale"] = 1
        (icon / "icon.json").write_text(json.dumps(config, indent=2) + "\n")

    ICON.save(ROOT / "windows/runner/resources/app_icon.ico", sizes=[(n, n) for n in (16, 24, 32, 48, 64, 128, 256)])
    for path in (ROOT / "windows/msix/assets").glob("*.png"):
        with Image.open(path) as old:
            size = old.size
        centered(size).save(path)
    for path in (ROOT / "tvos/Runner/Assets.xcassets/AppIcon.brandassets").rglob("*.png"):
        with Image.open(path) as old:
            size = old.size
        if "Front.imagestacklayer" in str(path):
            image = centered(size, edge=round(size[1] * .84))
        elif "Middle.imagestacklayer" in str(path):
            image = Image.new("RGBA", size)
        elif "Back.imagestacklayer" in str(path):
            image = Image.new("RGBA", size, (242, 242, 247, 255))
        else:
            image = centered(size, (14, 15, 18, 255), round(size[1] * .72))
        image.save(path)
    print("Generated Velo Flutter, Android, Apple, TV and Windows artwork.")


if __name__ == "__main__":
    main()
