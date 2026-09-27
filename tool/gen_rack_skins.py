from PIL import Image, ImageDraw, ImageFilter
import math, random, os

OUT = r'assets\skins'
os.makedirs(OUT, exist_ok=True)
W, H = 1600, 448


def hx(h):
    return ((h >> 16) & 255, (h >> 8) & 255, h & 255)


def shade(c, f):
    return tuple(max(0, min(255, int(x * f))) for x in c)


def vgrad(d, top, bot):
    for y in range(H):
        t = y / (H - 1)
        col = tuple(int(top[i] * (1 - t) + bot[i] * t) for i in range(3))
        d.line([(0, y), (W, y)], fill=col)


def vignette(d, strength=80):
    for i in range(26):
        a = int(strength * i / 26)
        d.rectangle([i, i, W - i - 1, H - i - 1], outline=(0, 0, 0, a))


def wood(name, top_hex, bot_hex, dark_hex, light_hex, planks=3, knots=4):
    top, bot, dark, light = hx(top_hex), hx(bot_hex), hx(dark_hex), hx(light_hex)
    img = Image.new('RGB', (W, H))
    d = ImageDraw.Draw(img, 'RGBA')
    vgrad(d, top, bot)
    rnd = random.Random(sum(map(ord, name)))
    # عروق خشبية أفقية متموجة
    for i in range(150):
        y0 = rnd.uniform(0, H)
        amp = rnd.uniform(2, 9)
        wv = rnd.uniform(0.004, 0.012)
        c = light if rnd.random() < 0.42 else dark
        pts = [(x, y0 + amp * math.sin(x * wv + i * 1.3)) for x in range(0, W, 7)]
        d.line(pts, fill=c + (rnd.randint(12, 40),), width=rnd.choice([1, 1, 2]))
    # فواصل ألواح
    for p in range(1, planks):
        y = H * p / planks + rnd.uniform(-5, 5)
        d.line([(0, y), (W, y)], fill=dark + (150,), width=3)
        d.line([(0, y + 4), (W, y + 4)], fill=light + (70,), width=1)
    # عقد خشبية
    for k in range(knots):
        cx = rnd.uniform(0.08, 0.92) * W
        cy = rnd.uniform(0.15, 0.85) * H
        r = rnd.uniform(7, 15)
        for rr in range(int(r), 0, -2):
            d.ellipse([cx - rr * 2, cy - rr, cx + rr * 2, cy + rr],
                      outline=dark + (60,), width=1)
        d.ellipse([cx - 3, cy - 2, cx + 3, cy + 2], fill=dark + (120,))
    vignette(d, 60)
    img = img.filter(ImageFilter.GaussianBlur(0.4))
    img.save(os.path.join(OUT, name), quality=90)
    print(name)


def metal(name, top_hex, bot_hex, rivet_hex):
    top, bot, rivet = hx(top_hex), hx(bot_hex), hx(rivet_hex)
    img = Image.new('RGB', (W, H))
    d = ImageDraw.Draw(img, 'RGBA')
    vgrad(d, top, bot)
    rnd = random.Random(sum(map(ord, name)))
    # خدشات فرشاة أفقية (brushed)
    for i in range(900):
        y = rnd.uniform(0, H)
        x0 = rnd.uniform(-100, W)
        ln = rnd.uniform(60, 420)
        c = (255, 255, 255) if rnd.random() < 0.5 else (0, 0, 0)
        d.line([(x0, y), (x0 + ln, y)], fill=c + (rnd.randint(5, 16),), width=1)
    # لمعانات أفقية عريضة
    for i in range(3):
        y = H * (0.22 + i * 0.28)
        d.line([(0, y), (W, y)], fill=(255, 255, 255, 26), width=6)
    # فواصل صفائح عمودية
    for x in (int(W * 0.33), int(W * 0.66)):
        d.line([(x, 0), (x, H)], fill=(0, 0, 0, 90), width=3)
        d.line([(x + 3, 0), (x + 3, H)], fill=(255, 255, 255, 45), width=1)
    # براغي على الأطراف العلوية والسفلية
    for x in range(30, W, 74):
        for y in (14, H - 14):
            d.ellipse([x - 4, y - 4, x + 4, y + 4],
                      fill=shade(rivet, 0.55), outline=(0, 0, 0, 140), width=1)
            d.ellipse([x - 3, y - 3, x + 1, y + 1], fill=(255, 255, 255, 110))
    vignette(d, 70)
    img.save(os.path.join(OUT, name), quality=90)
    print(name)


def carpet(name, bg_hex, deep_hex, gold_hex, accent_hex):
    bg, deep, gold, accent = hx(bg_hex), hx(deep_hex), hx(gold_hex), hx(accent_hex)
    img = Image.new('RGB', (W, H))
    d = ImageDraw.Draw(img, 'RGBA')
    vgrad(d, bg, deep)
    rnd = random.Random(sum(map(ord, name)))

    def band(y0, y1):
        d.rectangle([0, y0, W, y1], fill=shade(deep, 0.9))
        d.line([(0, y0), (W, y0)], fill=gold + (220,), width=2)
        d.line([(0, y1), (W, y1)], fill=gold + (220,), width=2)
        mid = (y0 + y1) // 2
        x = 12
        while x < W - 10:
            s = (y1 - y0) * 0.30
            d.polygon([(x, mid - s), (x + s, mid), (x, mid + s), (x - s, mid)],
                      outline=gold + (235,), width=2)
            d.ellipse([x - 2, mid - 2, x + 2, mid + 2], fill=accent + (255,))
            x += s * 2 + 18

    band(0, 58)
    band(H - 58, H)
    # شبكة معينات مركزية
    my = H / 2
    x = 0
    while x < W:
        for yy in (my - 52, my, my + 52):
            s = 13
            d.polygon([(x, yy - s), (x + s, yy), (x, yy + s), (x - s, yy)],
                      outline=gold + (120,), width=1)
            d.ellipse([x - 2.5, yy - 2.5, x + 2.5, yy + 2.5],
                      fill=accent + (160,))
        x += 44
    # نسيج قماشي خفيف
    for i in range(1400):
        x = rnd.uniform(0, W)
        y = rnd.uniform(58, H - 58)
        d.point((x, y), fill=(255, 255, 255, rnd.randint(4, 14)))
    vignette(d, 80)
    img.save(os.path.join(OUT, name), quality=90)
    print(name)


# خشبية
wood('rack_walnut.jpg', 0x6A3B1E, 0x2E1408, 0x241006, 0x9C6633)
wood('rack_oak.jpg', 0xC89A5E, 0x7A4E22, 0x5C3A16, 0xE8C489)
wood('rack_ebony.jpg', 0x3A2A22, 0x120B08, 0x0A0503, 0x5C4634)
# صاجية
metal('rack_steel.jpg', 0xB9C2CC, 0x5A646E, 0x3A424A)
metal('rack_copper.jpg', 0xC98A54, 0x6E3E1E, 0x4A2810)
# مفروشات مزخرفة
carpet('rack_carpet_red.jpg', 0x8E1F2B, 0x4A0E16, 0xD4AF37, 0xE8D9A0)
carpet('rack_carpet_navy.jpg', 0x1E3A5C, 0x0C1A30, 0xC9A84C, 0x9FD8E8)
print('done')
