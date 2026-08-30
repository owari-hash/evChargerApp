"""Generate Google Play store assets for Eplug.

Palette comes from lib/theme/app_theme.dart:
    darkForest   #0D2619   textDark #0A1E14
    panel        #124A33   forestAccent #1B4D3E
    sageGreen    #25A269   accent(dark) #2FBE7C
    lightSage    #D8ECE1

Everything is drawn at SS x scale and downsampled with LANCZOS, which is how we
get antialiased edges out of Pillow's aliased polygon/ellipse rasteriser.
"""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

OUT = r"D:\evChargerApp\store"
os.makedirs(OUT, exist_ok=True)

SS = 4  # supersample factor

DARK      = (10, 30, 20)
FOREST    = (13, 38, 25)
PANEL     = (18, 74, 51)
DEEP      = (6, 22, 14)
SAGE      = (37, 162, 105)
BRIGHT    = (47, 190, 124)
NEON      = (108, 232, 160)
HOT       = (198, 255, 224)
LIGHTSAGE = (216, 236, 225)
WHITE     = (255, 255, 255)

FONT_BOLD = r"C:\Windows\Fonts\segoeuib.ttf"
FONT_SEMI = r"C:\Windows\Fonts\seguisb.ttf"

# ---------------------------------------------------------------------------
# Brand copy -- edit these three lines and re-run.
# ---------------------------------------------------------------------------
BRAND   = "Eplug"
TAGLINE = "EV цэнэглэх станцаа хурдан ол"
DOMAIN  = "eplug.mn"


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------

def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def linear_gradient(size, c0, c1, angle="diagonal"):
    """Solid RGB gradient image."""
    w, h = size
    img = Image.new("RGB", size)
    d = ImageDraw.Draw(img)
    if angle == "vertical":
        for y in range(h):
            d.line([(0, y), (w, y)], fill=lerp(c0, c1, y / max(1, h - 1)))
    elif angle == "horizontal":
        for x in range(w):
            d.line([(x, 0), (x, h)], fill=lerp(c0, c1, x / max(1, w - 1)))
    else:  # diagonal, top-left -> bottom-right
        n = w + h
        for i in range(n):
            d.line([(i, 0), (0, i)], fill=lerp(c0, c1, i / max(1, n - 1)))
    return img


def fill_mask(mask, c0, c1, angle="vertical"):
    """Paint a gradient through an L-mode mask, returning RGBA."""
    grad = linear_gradient(mask.size, c0, c1, angle).convert("RGBA")
    grad.putalpha(mask)
    return grad


def radial_glow(size, center, radius, colour, max_alpha=110, steps=64):
    """Soft radial falloff, drawn as concentric rings then blurred."""
    layer = Image.new("L", size, 0)
    d = ImageDraw.Draw(layer)
    cx, cy = center
    for i in range(steps, 0, -1):
        t = i / steps
        r = radius * t
        a = int(max_alpha * (1 - t) ** 1.6)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=a)
    layer = layer.filter(ImageFilter.GaussianBlur(radius * 0.12))
    out = Image.new("RGBA", size, colour + (0,))
    out.putalpha(layer)
    return out


# The mark: a lightning bolt whose spine reads as a Z.
# Coordinates in a 100x100 box, y down.
BOLT = [
    (64, 3),
    (20, 58),
    (44, 58),
    (36, 97),
    (82, 39),
    (58, 39),
]


def bolt_mask(size, box, pad=0.0):
    """Render BOLT into an L mask. `box` is (x, y, w, h) in target pixels."""
    x, y, w, h = box
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    pts = [(x + px / 100 * w, y + py / 100 * h) for px, py in BOLT]
    d.polygon(pts, fill=255)
    return mask


def load_font(path, px):
    return ImageFont.truetype(path, px)


def text_w(draw, s, font):
    a = draw.textbbox((0, 0), s, font=font)
    return a[2] - a[0], a[3] - a[1]


# --------------------------------------------------------------------------
# 1. App icon 512 x 512
# --------------------------------------------------------------------------

def build_icon(px=512):
    S = px * SS
    size = (S, S)

    # Background: deep forest diagonal gradient, full bleed (Play masks corners).
    base = linear_gradient(size, (14, 44, 29), (5, 17, 11), "diagonal").convert("RGBA")

    # Ambient glow behind the mark.
    base.alpha_composite(radial_glow(size, (S * 0.5, S * 0.47), S * 0.40, SAGE, 52))

    # Faint concentric rings -> echoes the badge in the existing logo without
    # adding detail that collapses at 48 px.
    rings = Image.new("RGBA", size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(rings)
    for r_frac, a, wd in ((0.404, 58, 0.014), (0.330, 30, 0.009)):
        r = S * r_frac
        rd.ellipse(
            [S / 2 - r, S / 2 - r, S / 2 + r, S / 2 + r],
            outline=BRIGHT + (a,),
            width=max(1, int(S * wd)),
        )
    base.alpha_composite(rings)

    # The bolt, centred in the 66% safe area.
    bw = S * 0.44
    bh = S * 0.60
    bx = S / 2 - bw / 2
    by = S / 2 - bh / 2
    m = bolt_mask(size, (bx, by, bw, bh))

    # Bloom under the bolt.
    bloom = m.filter(ImageFilter.GaussianBlur(S * 0.026)).point(lambda v: int(v * 0.48))
    glow = Image.new("RGBA", size, NEON + (0,))
    glow.putalpha(bloom)
    base.alpha_composite(glow)

    base.alpha_composite(fill_mask(m, HOT, BRIGHT, "vertical"))

    icon = base.resize((px, px), Image.LANCZOS)
    p = os.path.join(OUT, "play-icon-512.png")
    icon.save(p, "PNG")
    print("icon        ", p, icon.size, icon.mode, os.path.getsize(p) // 1024, "KB")
    return icon


# --------------------------------------------------------------------------
# 2. Feature graphic 1024 x 500
# --------------------------------------------------------------------------

def build_feature(w=1024, h=500):
    S = SS
    size = (w * S, h * S)
    W, H = size

    base = linear_gradient(size, (15, 46, 31), (5, 18, 12), "diagonal").convert("RGBA")

    # --- background texture: route polylines + station dots, low alpha ---------
    tex = Image.new("RGBA", size, (0, 0, 0, 0))
    td = ImageDraw.Draw(tex)
    routes = [
        [(-0.05, 0.78), (0.16, 0.62), (0.30, 0.70), (0.47, 0.50), (0.66, 0.58), (0.88, 0.36), (1.05, 0.44)],
        [(-0.05, 0.28), (0.14, 0.36), (0.33, 0.20), (0.52, 0.30), (0.74, 0.14), (1.05, 0.24)],
    ]
    for i, r in enumerate(routes):
        pts = [(x * W, y * H) for x, y in r]
        td.line(pts, fill=BRIGHT + ((30 if i == 0 else 20),), width=int(S * 2.4), joint="curve")
        for pxy in pts[1:-1]:
            rr = S * 4.2
            td.ellipse([pxy[0] - rr, pxy[1] - rr, pxy[0] + rr, pxy[1] + rr],
                       fill=BRIGHT + (46,))
    base.alpha_composite(tex)

    # Warm the left third where the mark sits.
    base.alpha_composite(radial_glow(size, (W * 0.22, H * 0.50), H * 0.78, SAGE, 60))

    # --- measure, then centre the whole mark + type group ----------------
    d = ImageDraw.Draw(base)
    f_title = load_font(FONT_BOLD, int(H * 0.185))
    f_sub = load_font(FONT_SEMI, int(H * 0.068))
    f_dom = load_font(FONT_SEMI, int(H * 0.050))

    tb = d.textbbox((0, 0), BRAND, font=f_title)
    sb = d.textbbox((0, 0), TAGLINE, font=f_sub)
    db = d.textbbox((0, 0), DOMAIN, font=f_dom)
    tw, th_ = tb[2] - tb[0], tb[3] - tb[1]
    sw, sh_ = sb[2] - sb[0], sb[3] - sb[1]
    dw, dh_ = db[2] - db[0], db[3] - db[1]

    bh_ = H * 0.58                 # mark height
    bw_ = bh_ * 0.72
    gap = W * 0.045                # space between mark and type
    text_w_ = max(tw, sw, dw)
    group_w = bw_ + gap + text_w_
    gx = (W - group_w) / 2         # group left edge

    # --- mark ------------------------------------------------------------
    bx = gx
    by = H / 2 - bh_ / 2
    m = bolt_mask(size, (bx, by, bw_, bh_))
    bloom = m.filter(ImageFilter.GaussianBlur(H * 0.022)).point(lambda v: int(v * 0.5))
    glow = Image.new("RGBA", size, NEON + (0,))
    glow.putalpha(bloom)
    base.alpha_composite(glow)
    base.alpha_composite(fill_mask(m, HOT, BRIGHT, "vertical"))

    # --- type ------------------------------------------------------------
    tx = gx + bw_ + gap
    rule_h = int(S * 5)
    pad1 = int(H * 0.055)          # title -> rule
    pad2 = int(H * 0.052)          # rule  -> tagline
    pad3 = int(H * 0.055)          # tagline -> domain

    block_h = th_ + pad1 + rule_h + pad2 + sh_ + pad3 + dh_
    y = H / 2 - block_h / 2

    d.text((tx, y - tb[1]), BRAND, font=f_title, fill=WHITE)
    y += th_ + pad1
    d.rounded_rectangle([tx, y, tx + int(W * 0.085), y + rule_h],
                        radius=int(S * 3), fill=BRIGHT)
    y += rule_h + pad2
    d.text((tx, y - sb[1]), TAGLINE, font=f_sub, fill=LIGHTSAGE)
    y += sh_ + pad3
    d.text((tx, y - db[1]), DOMAIN, font=f_dom, fill=BRIGHT)

    feat = base.resize((w, h), Image.LANCZOS).convert("RGB")  # no alpha allowed
    p = os.path.join(OUT, "play-feature-1024x500.png")
    feat.save(p, "PNG")
    print("feature     ", p, feat.size, feat.mode, os.path.getsize(p) // 1024, "KB")
    return feat


# --------------------------------------------------------------------------
# 3. Preview sheet so the icon can be judged at real sizes
# --------------------------------------------------------------------------

def build_preview(icon):
    pad, gap = 28, 24
    sizes = [192, 96, 64, 48, 36]
    w = pad * 2 + sum(sizes) + gap * (len(sizes) - 1)
    h = pad * 2 + 192 + 34
    sheet = Image.new("RGB", (w, h), (245, 247, 245))
    d = ImageDraw.Draw(sheet)
    f = load_font(FONT_SEMI, 13)
    x = pad
    for s in sizes:
        thumb = icon.resize((s, s), Image.LANCZOS)
        y = pad + (192 - s)
        sheet.paste(thumb, (x, y), thumb)
        d.text((x, pad + 192 + 10), f"{s}px", font=f, fill=(60, 80, 70))
        x += s + gap
    p = os.path.join(OUT, "icon-size-preview.png")
    sheet.save(p, "PNG")
    print("preview     ", p, sheet.size)


if __name__ == "__main__":
    ic = build_icon()
    build_feature()
    build_preview(ic)
