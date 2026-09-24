"""把 tools/_gen 里生成的原图打包成卡面素材，写进 assets/cards/<卡id>.png。

做的事：按 2:3 居中裁切（保留上方，主体都画在上半部）→ 缩放到 512x768 →
四角切圆角 → 下半截压暗（界面那条半透明文字条要压在上面）。

用法：python tools/_pack_art.py
"""

import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "_gen")
OUT = os.path.join(ROOT, "assets", "cards")

W, H = 512, 768
RADIUS = 48
SHADE_FROM = 0.55   # 从这个高度开始往下压暗
SHADE_MAX = 150     # 最底部的压暗强度

# 原图文件名里的主题词 → 卡 id
TOPIC = {
    "封魔锁链": "chain",
    "灯油": "oil",
    "灯芯": "light",
    "浓夜": "dark",
    "被困之魂": "soul",
    "撕符": "talisman",
    "净露": "water",
    "观": "watch",
    "悔": "regret",
    "恕": "forgive",
    "放": "letgo",
    "怒": "anger",
    "执": "grasp",
    "静水": "still",
    "迷魂": "lost",
    "引铃": "bell",
    "提灯": "lantern",
    "渡舟": "boat",
    "买路钱": "coin",
    "妄镜": "mirror",
    "引路火": "flame",
}
# 第一张生成时还没加主题词前缀，靠排除法认领
FALLBACK_ID = "key"


def match(path):
    name = os.path.basename(path)
    for topic, cid in TOPIC.items():
        if topic in name:
            return cid
    return FALLBACK_ID


def crop_2x3(img):
    """按 2:3 覆盖式裁切，顶部对齐 —— 主体画在上半部，宁可裁掉脚下。"""
    w, h = img.size
    scale = max(float(W) / float(w), float(H) / float(h))
    nw, nh = max(int(round(w * scale)), W), max(int(round(h * scale)), H)
    img = img.resize((nw, nh), Image.LANCZOS)
    left = (nw - W) // 2
    return img.crop((left, 0, left + W, H))


def finish(img):
    img = img.convert("RGBA")
    draw = ImageDraw.Draw(img, "RGBA")
    top = int(H * SHADE_FROM)
    span = H - top
    for y in range(top, H):
        t = float(y - top) / float(span)
        draw.line([(0, y), (W, y)], fill=(8, 9, 13, int(SHADE_MAX * t)))

    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, W - 1, H - 1], radius=RADIUS, fill=255)
    img.putalpha(mask)
    return img


def main():
    files = [f for f in os.listdir(SRC) if f.lower().endswith(".png")]
    if not files:
        print("没在 %s 里找到原图" % SRC)
        return

    os.makedirs(OUT, exist_ok=True)
    done, seen = [], set()
    for f in sorted(files):
        cid = match(f)
        if cid in seen:
            print("重复认领 %s（%s），跳过" % (cid, f))
            continue
        seen.add(cid)
        img = Image.open(os.path.join(SRC, f))
        finish(crop_2x3(img)).save(os.path.join(OUT, cid + ".png"), "PNG")
        done.append(cid)
        print("%-10s ← %s" % (cid, f))

    print("\n写入 %d 张到 %s" % (len(done), OUT))


if __name__ == "__main__":
    sys.exit(main())
