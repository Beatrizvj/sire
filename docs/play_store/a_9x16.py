"""Encaja una captura 1080x2340 en un lienzo 1080x1920 (9:16) sin deformarla.
Uso: python a_9x16.py entrada.png salida.png [rojo|oscuro]"""
import sys
from PIL import Image

COLORES = {"rojo": (198, 40, 40), "oscuro": (18, 18, 18)}

src, dst = sys.argv[1], sys.argv[2]
fondo = COLORES[sys.argv[3] if len(sys.argv) > 3 else "rojo"]
W, H, MARGEN = 1080, 1920, 60

img = Image.open(src).convert("RGB")
escala = min((W - 2 * MARGEN) / img.width, (H - 2 * MARGEN) / img.height)
img = img.resize((round(img.width * escala), round(img.height * escala)), Image.LANCZOS)
lienzo = Image.new("RGB", (W, H), fondo)
lienzo.paste(img, ((W - img.width) // 2, (H - img.height) // 2))
lienzo.save(dst)
print(dst, lienzo.size)
