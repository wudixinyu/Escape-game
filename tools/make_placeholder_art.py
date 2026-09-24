"""生成「解脱」卡面占位素材。

从 levels/LevelLibrary.gd 里抓出所有卡 id 与卡名，画一张占位 PNG 到 assets/cards/<id>.png。
真正的美术素材只要 **按同名文件覆盖过去** 就行，代码不用动一行。

用法：
    python tools/make_placeholder_art.py          # 只补齐缺的，已有的一律不动
    python tools/make_placeholder_art.py --force  # 连已有的也重画（会把你的真素材冲掉，慎用）

素材规格：256 x 384（和卡实际显示的 200 x 300 同比例）。四角建议留成透明的圆角，
不想做圆角也没关系， ui/card_round_corners.gdshader 会把方图也裁圆。
"""

import math
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "levels", "LevelLibrary.gd")
OUT = os.path.join(ROOT, "assets", "cards")

W, H = 256, 384
RADIUS = 24

# 底色 / 描边 / 前景字色，按卡的 kind 分三档
PALETTE = {
    "COMMON": ((44, 49, 63), (86, 94, 114), (206, 214, 226)),
    "GOAL": ((62, 48, 29), (122, 98, 58), (232, 210, 168)),
    "GUIDE": ((31, 60, 71), (68, 116, 133), (188, 220, 232)),
}

FONT_CANDIDATES = [
    r"C:\Windows\Fonts\msyh.ttc",
    r"C:\Windows\Fonts\msyhl.ttc",
    r"C:\Windows\Fonts\simhei.ttf",
]

CARD_BLOCK = re.compile(
    r'_card\(\s*"([a-z_]+)"\s*,\s*"([^"]*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*(?:,\s*\{(.*?)\})?\)',
    re.S,
)


def pick_font(size):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def rounded_mask(w, h, r):
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=r, fill=255)
    return mask


def draw_symbol(draw, kind, box, stroke):
    """中间画个抽象的符号，方便一眼看出这是占位的，不是真素材。"""
    x0, y0, x1, y1 = box
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    n = min(x1 - x0, y1 - y0) / 2

    def colour(alpha):
        return stroke + (int(255 * alpha),)

    wide = 3
    if kind == "GOAL":
        draw.ellipse([cx - n, cy - n, cx + n, cy + n], outline=colour(0.55), width=wide)
        draw.ellipse([cx - n * 0.45, cy - n * 0.45, cx + n * 0.45, cy + n * 0.45],
                     outline=colour(0.3), width=wide)
    elif kind == "GUIDE":
        draw.line([cx - n, cy + n * 0.6, cx + n, cy - n * 0.6], fill=colour(0.5), width=wide)
        draw.line([cx - n, cy + n * 0.6, cx - n * 0.3, cy + n * 0.6], fill=colour(0.5), width=wide)
        draw.ellipse([cx + n * 0.3, cy - n - 4, cx + n, cy - n * 0.55],
                     outline=colour(0.55), width=wide)
    else:
        draw.polygon(
            [(cx, cy - n), (cx + n, cy), (cx, cy + n), (cx - n, cy)],
            outline=colour(0.5),
        )


def build(card_id, name, kind):
    base, edge, ink = PALETTE.get(kind, PALETTE["COMMON"])

    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img, "RGBA")

    draw.rounded_rectangle([0, 0, W - 1, H - 1], radius=RADIUS, fill=base + (255,))
    draw.rounded_rectangle([1, 1, W - 2, H - 2], radius=RADIUS - 1,
                           outline=edge + (255,), width=2)

    # 下半截压暗，给叠在上面的文字条留 readability
    for y in range(int(H * 0.55), H):
        t = (y - H * 0.55) / (H * 0.45)
        draw.line([(0, y), (W, y)], fill=(8, 9, 13, int(150 * t)))

    draw_symbol(draw, kind, (44, 64, W - 44, int(H * 0.55)), edge)

    # 卡名不画在图上 —— 界面的文字条会显示，画上去会叠影。
    # 只在角落标个小 id，替换素材时好认文件。
    id_font = pick_font(18)
    note = card_id
    nb = draw.textbbox((0, 0), note, font=id_font)
    nw, nh = nb[2] - nb[0], nb[3] - nb[1]
    draw.text(((W - nw) / 2 - nb[0], 22 - nb[1]), note, font=id_font,
              fill=ink + (120,))

    img.putalpha(rounded_mask(W, H, RADIUS))
    return img


def collect():
    with open(SRC, "r", encoding="utf-8") as f:
        text = f.read()

    cards = []
    for m in CARD_BLOCK.finditer(text):
        cid, name, _desc, opts = m.groups()
        block_opts = opts or ""
        km = re.search(r'"kind"\s*:\s*CardData\.Kind\.(\w+)', block_opts)
        cards.append((cid, name, km.group(1) if km else "COMMON"))
    return cards


def main():
    force = "--force" in sys.argv
    os.makedirs(OUT, exist_ok=True)

    cards = collect()
    if not cards:
        print("没从 LevelLibrary.gd 里解析出任何卡，检查一下 _card() 的写法")
        return

    made, skipped = [], []
    for cid, name, kind in cards:
        path = os.path.join(OUT, "%s.png" % cid)
        if os.path.exists(path) and not force:
            skipped.append(cid)
            continue
        build(cid, name, kind).save(path, "PNG")
        made.append(cid)

    print("共 %d 张卡 → %s" % (len(cards), OUT))
    print("新生成 %d 张：%s" % (len(made), ", ".join(made) or "无"))
    print("已跳过 %d 张（已存在真实素材，没动它）" % len(skipped))
    if skipped:
        print("  " + ", ".join(skipped))


if __name__ == "__main__":
    main()
