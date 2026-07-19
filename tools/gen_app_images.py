"""One-shot generator for QR4Emergency app images.

Sources:
- accident.png   -> Pexels photo 35784044 (Berlin night crash) - Pexels License (free use, no attribution required)
- no_parking.png -> Pexels photo 28921445 (blue car at no-parking sign) - Pexels License
- logo.png       -> generated programmatically (orange gradient + shield + QR motif)
"""
from __future__ import annotations

import io
import math
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent.parent / "assets" / "images"

CAROUSEL_W, CAROUSEL_H = 900, 520

PEXELS = {
    "accident.png":   "https://images.pexels.com/photos/35784044/pexels-photo-35784044.jpeg?auto=compress&cs=tinysrgb&w=1400",
    "no_parking.png": "https://images.pexels.com/photos/28921445/pexels-photo-28921445/free-photo-of-bright-blue-car-in-urban-alley-at-night.jpeg?auto=compress&cs=tinysrgb&w=1400",
}


def fetch(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read()


def cover_crop(im: Image.Image, w: int, h: int) -> Image.Image:
    """Cover-fit crop: scale so im fills (w,h), then center-crop."""
    src_ratio = im.width / im.height
    dst_ratio = w / h
    if src_ratio > dst_ratio:
        new_h = h
        new_w = round(im.width * (h / im.height))
    else:
        new_w = w
        new_h = round(im.height * (w / im.width))
    im = im.resize((new_w, new_h), Image.LANCZOS)
    left = (new_w - w) // 2
    top = (new_h - h) // 2
    return im.crop((left, top, left + w, top + h))


def download_carousel() -> None:
    for name, url in PEXELS.items():
        print(f"Downloading {name} ...")
        data = fetch(url)
        im = Image.open(io.BytesIO(data)).convert("RGB")
        im = cover_crop(im, CAROUSEL_W, CAROUSEL_H)
        out = HERE / name
        im.save(out, "PNG", optimize=True)
        print(f"  -> {out}  {im.size}  {out.stat().st_size // 1024} KB")


# ---------- Logo generation ----------

SIZE = 512  # master logo size; downscales cleanly to 32px in-app


def hex_to_rgba(h: str, a: int = 255) -> tuple[int, int, int, int]:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def radial_gradient_circle(
    size: int,
    inner: tuple[int, int, int, int],
    outer: tuple[int, int, int, int],
) -> Image.Image:
    """A filled circle with a radial gradient inside-out."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    cx = cy = size / 2
    r = size / 2
    for y in range(size):
        for x in range(size):
            dx = x - cx
            dy = y - cy
            d = math.sqrt(dx * dx + dy * dy)
            if d > r:
                continue
            t = (d / r) ** 1.1
            ir, ig, ib, ia = inner
            or_, og, ob, oa = outer
            cr = round(ir + (or_ - ir) * t)
            cg = round(ig + (og - ig) * t)
            cb = round(ib + (ob - ib) * t)
            ca = round(ia + (oa - ia) * t)
            px[x, y] = (cr, cg, cb, ca)
    return img


def draw_qr_corner(draw: ImageDraw.ImageDraw, x: int, y: int, size: int, color) -> None:
    """Draw a QR-style finder pattern: outer ring + inner dot, rounded."""
    outer_w = max(2, size // 7)
    draw.rounded_rectangle(
        [x, y, x + size, y + size],
        radius=size // 5,
        outline=color,
        width=outer_w,
    )
    inset = size // 3
    draw.rounded_rectangle(
        [x + inset, y + inset, x + size - inset, y + size - inset],
        radius=size // 10,
        fill=color,
    )


def draw_qr_dot(draw: ImageDraw.ImageDraw, x: int, y: int, size: int, color) -> None:
    draw.rounded_rectangle(
        [x, y, x + size, y + size], radius=size // 4, fill=color
    )


def build_logo() -> Image.Image:
    s = SIZE
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))

    # 1) Outer orange-gradient disc (matches AppColors.brandGradient)
    #    #FF9A45 -> #FF6A00 -> #E25500 (top-left to bottom-right)
    disc = radial_gradient_circle(
        s,
        inner=hex_to_rgba("FFAE63", 255),   # bright warm center
        outer=hex_to_rgba("D14A00", 255),   # deep edge
    )
    img.alpha_composite(disc)

    # subtle inner stroke for definition
    stroke = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sd = ImageDraw.Draw(stroke)
    pad = s // 24
    sd.ellipse([pad, pad, s - pad, s - pad], outline=(255, 255, 255, 70), width=max(2, s // 180))
    img.alpha_composite(stroke)

    # 2) Soft glow blob top-left for a glassy feel
    glow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([s * 0.08, s * 0.05, s * 0.62, s * 0.45], fill=(255, 255, 255, 70))
    glow = glow.filter(ImageFilter.GaussianBlur(s * 0.06))
    img.alpha_composite(glow)

    # 3) Central white rounded square holding the QR motif
    plate = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    pd = ImageDraw.Draw(plate)
    plate_pad = s // 4
    pd.rounded_rectangle(
        [plate_pad, plate_pad, s - plate_pad, s - plate_pad],
        radius=s // 16,
        fill=(255, 255, 255, 245),
    )
    # drop shadow under plate
    shadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    shd = ImageDraw.Draw(shadow)
    shd.rounded_rectangle(
        [plate_pad, plate_pad + s // 60, s - plate_pad, s - plate_pad + s // 60],
        radius=s // 16,
        fill=(0, 0, 0, 90),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(s * 0.012))
    img.alpha_composite(shadow)
    img.alpha_composite(plate)

    # 4) QR pattern inside the plate
    qr_pad = plate_pad + s // 32
    qr_box = s - 2 * qr_pad
    qr_inset = qr_pad
    ink = hex_to_rgba("0F1626", 255)  # AppColors.backgroundElevated-ish

    d = ImageDraw.Draw(img)
    # 3 finder corners
    corner = qr_box // 3
    draw_qr_corner(d, qr_inset, qr_inset, corner, ink)
    draw_qr_corner(d, qr_inset + qr_box - corner, qr_inset, corner, ink)
    draw_qr_corner(d, qr_inset, qr_inset + qr_box - corner, corner, ink)

    # scattered QR dots in the remaining area
    cell = corner // 4
    dot_positions = [
        # column under top-right finder
        (qr_inset + qr_box - corner, qr_inset + corner + cell),
        (qr_inset + qr_box - corner + cell * 2, qr_inset + corner + cell),
        (qr_inset + qr_box - corner, qr_inset + corner + cell * 3),
        # row right of bottom-left finder
        (qr_inset + corner + cell, qr_inset + qr_box - corner),
        (qr_inset + corner + cell * 3, qr_inset + qr_box - corner),
        (qr_inset + corner + cell, qr_inset + qr_box - corner + cell * 2),
        # center region
        (qr_inset + corner + cell * 2, qr_inset + corner + cell * 2),
        (qr_inset + corner + cell * 3, qr_inset + corner + cell * 3),
        (qr_inset + corner + cell * 4, qr_inset + corner + cell * 2),
        (qr_inset + corner + cell * 2, qr_inset + corner + cell * 4),
    ]
    for (x, y) in dot_positions:
        draw_qr_dot(d, x, y, cell, ink)

    # 5) Small shield in bottom-right of the plate
    shield = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    shd2 = ImageDraw.Draw(shield)
    sh_size = int(corner * 1.05)
    sx = s - plate_pad - sh_size - s // 28
    sy = s - plate_pad - sh_size - s // 28
    # shield outline (rounded pointed shape via polygon + arc approximation)
    pts = [
        (sx + sh_size * 0.5, sy),                       # top
        (sx + sh_size,        sy + sh_size * 0.18),
        (sx + sh_size,        sy + sh_size * 0.6),
        (sx + sh_size * 0.5,  sy + sh_size),            # bottom point
        (sx,                  sy + sh_size * 0.6),
        (sx,                  sy + sh_size * 0.18),
    ]
    shd2.polygon(pts, fill=hex_to_rgba("FF6A00", 255), outline=(255, 255, 255, 230))
    # plus sign in shield
    cx = sx + sh_size / 2
    cy = sy + sh_size * 0.5
    arm = sh_size * 0.22
    bar = sh_size * 0.10
    shd2.rectangle([cx - arm, cy - bar / 2, cx + arm, cy + bar / 2], fill=(255, 255, 255, 255))
    shd2.rectangle([cx - bar / 2, cy - arm, cx + bar / 2, cy + arm], fill=(255, 255, 255, 255))
    img.alpha_composite(shield)

    return img


def build_logo_file() -> None:
    print("Generating logo.png ...")
    logo = build_logo()
    out = HERE / "logo.png"
    logo.save(out, "PNG", optimize=True)
    print(f"  -> {out}  {logo.size}  {out.stat().st_size // 1024} KB")


if __name__ == "__main__":
    download_carousel()
    build_logo_file()
    print("Done.")
