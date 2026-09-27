# يولّد خامة خشب الماهوغني الملكي — القاعدة الافتراضية للطاولة والاستكانة
from PIL import Image, ImageDraw, ImageFilter
import math, random, os

OUT = r'assets\skins'
os.makedirs(OUT, exist_ok=True)
W, H = 2048, 1024  # مقاس كبير يكفي للطاولة ويُقصّ للاستكانة


def hx(h):
    return ((h >> 16) & 255, (h >> 8) & 255, h & 255)


def main():
    top, bot = hx(0x6B4226), hx(0x2E1508)
    dark, light = hx(0x1E0C04), hx(0x9C6633)
    img = Image.new('RGB', (W, H))
    d = ImageDraw.Draw(img, 'RGBA')
    rnd = random.Random(777)

    # تدرج عمودي دافئ
    for y in range(H):
        t = y / (H - 1)
        col = tuple(int(top[i] * (1 - t) + bot[i] * t) for i in range(3))
        d.line([(0, y), (W, y)], fill=col)

    # عروق خشبية أفقية كثيفة متموجة (حبيبات حقيقية)
    for i in range(340):
        y0 = rnd.uniform(0, H)
        amp = rnd.uniform(2, 10)
        wv = rnd.uniform(0.003, 0.010)
        c = light if rnd.random() < 0.40 else dark
        pts = [(x, y0 + amp * math.sin(x * wv + i * 1.3)) for x in range(0, W, 6)]
        d.line(pts, fill=c + (rnd.randint(10, 34),), width=rnd.choice([1, 1, 2]))

    # حبيبات دقيقة إضافية
    for i in range(500):
        y0 = rnd.uniform(0, H)
        x0 = rnd.uniform(0, W)
        ln = rnd.uniform(30, 200)
        c = light if rnd.random() < 0.5 else dark
        d.line([(x0, y0), (x0 + ln, y0 + rnd.uniform(-2, 2))],
               fill=c + (rnd.randint(6, 18),), width=1)

    # فواصل ألواح أفقية خفيفة
    for p in range(1, 4):
        y = H * p / 4 + rnd.uniform(-8, 8)
        d.line([(0, y), (W, y)], fill=dark + (130,), width=2)
        d.line([(0, y + 3), (W, y + 3)], fill=light + (60,), width=1)

    # عقد خشبية واقعية
    for k in range(9):
        cx = rnd.uniform(0.06, 0.94) * W
        cy = rnd.uniform(0.10, 0.90) * H
        r = rnd.uniform(9, 20)
        for rr in range(int(r), 0, -2):
            d.ellipse([cx - rr * 2, cy - rr, cx + rr * 2, cy + rr],
                      outline=dark + (55,), width=1)
        d.ellipse([cx - 3, cy - 2, cx + 3, cy + 2], fill=dark + (130,))
        # لمعة حول العقدة
        d.ellipse([cx - r * 2, cy - r - 3, cx + r * 2, cy - r + 3],
                  outline=light + (60,), width=2)

    # لمعان علوي ناعم (إضاءة طاولة)
    for y in range(140):
        a = int(26 * (1 - y / 140))
        d.line([(0, y), (W, y)], fill=(255, 235, 200, a))

    # فينييت
    for i in range(30):
        a = int(80 * i / 30)
        d.rectangle([i, i, W - i - 1, H - i - 1], outline=(0, 0, 0, a))

    img = img.filter(ImageFilter.GaussianBlur(0.5))
    img.save(os.path.join(OUT, 'wood_premium.jpg'), quality=88)
    print('wood_premium.jpg', os.path.getsize(os.path.join(OUT, 'wood_premium.jpg')) // 1024, 'KB')


main()
