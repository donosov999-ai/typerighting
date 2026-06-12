# Генерация icon-source.png (1024x1024) для cargo tauri icon.
# Дизайн: клавиша-кейкап с буквой T и зелёным курсором — тренажёр печати.
from PIL import Image, ImageDraw, ImageFont

S = 1024

def vgrad(size, top, bot):
    col = Image.new("RGBA", (1, size))
    px = col.load()
    for y in range(size):
        t = y / (size - 1)
        px[0, y] = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(4))
    return col.resize((size, size))

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

# Внешний корпус клавиши (бевел)
m, r = 70, 190
outer = vgrad(S, (99, 102, 241, 255), (49, 46, 129, 255))   # #6366f1 -> #312e81
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([m, m, S - m, S - m], radius=r, fill=255)
img.paste(outer, (0, 0), mask)

# Внутренняя площадка клавиши (свет сверху)
inner = vgrad(S, (129, 140, 248, 255), (67, 56, 202, 255))  # #818cf8 -> #4338ca
mask2 = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask2).rounded_rectangle([m + 58, m + 48, S - m - 58, S - m - 78], radius=150, fill=255)
img.paste(inner, (0, 0), mask2)

d = ImageDraw.Draw(img)

# Буква T (Menlo Bold)
font = None
for path, idx in [("/System/Library/Fonts/Menlo.ttc", 1), ("/System/Library/Fonts/Menlo.ttc", 0),
                  ("/System/Library/Fonts/Helvetica.ttc", 1), ("/System/Library/Fonts/Helvetica.ttc", 0)]:
    try:
        font = ImageFont.truetype(path, 540, index=idx)
        break
    except Exception:
        continue
if font is None:
    raise SystemExit("no usable font found")

d.text((S // 2 + 2, 438 + 14), "T", font=font, anchor="mm", fill=(20, 18, 60, 110))  # тень
d.text((S // 2, 438), "T", font=font, anchor="mm", fill=(255, 255, 255, 255))

# Зелёный курсор-подчёркивание
cw, ch, cy = 300, 58, 790
d.rounded_rectangle([S // 2 - cw // 2, cy, S // 2 + cw // 2, cy + ch], radius=ch // 2, fill=(34, 197, 94, 255))

img.save("/Users/denisonosov/dev/typerighting/src-tauri/icon-source.png")
print("ok: icon-source.png", img.size)
