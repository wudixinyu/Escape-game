"""把 tools/_gen 里的背景原图裁成 16:9 并压暗，输出 assets/bg/table.png。

背景要压暗一档：整块画面上还要摆卡牌和文字条，太亮会抢可读性。
想调整体明暗直接改 Main.tscn 里 Veil 那层的 alpha，不必重新出图。

用法：python tools/_pack_bg.py [源图文件名关键字]
"""

import glob
import os
import sys

from PIL import Image, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "tools", "_gen")
OUT_DIR = os.path.join(ROOT, "assets", "bg")
OUT = os.path.join(OUT_DIR, "table.png")

W, H = 1920, 1080
BRIGHTNESS = 0.72   # 整体压暗，给前景卡牌让路


def crop_16x9(img):
    w, h = img.size
    target = float(W) / float(H)
    if float(w) / float(h) > target:
        nw = int(round(h * target))
        left = (w - nw) // 2
        img = img.crop((left, 0, left + nw, h))
    else:
        nh = int(round(w / target))
        top = (h - nh) // 2          # 居中裁：既不留太多天，也不切掉地平线
        img = img.crop((0, top, w, top + nh))
    return img


def main():
    key = sys.argv[1] if len(sys.argv) > 1 else "Chinese_ink"
    hits = sorted(glob.glob(os.path.join(SRC_DIR, "*%s*.png" % key)))
    if not hits:
        print("没找到匹配 %s 的原图，_gen 里有：\n  %s"
              % (key, "\n  ".join(os.path.basename(p) for p in os.listdir(SRC_DIR))))
        return

    src = hits[-1]
    img = Image.open(src).convert("RGB")
    img = crop_16x9(img).resize((W, H), Image.LANCZOS)
    img = ImageEnhance.Brightness(img).enhance(BRIGHTNESS)

    os.makedirs(OUT_DIR, exist_ok=True)
    img.save(OUT, "PNG")
    print("%s\n  → %s (%dx%d)" % (os.path.basename(src), OUT, W, H))


if __name__ == "__main__":
    main()
