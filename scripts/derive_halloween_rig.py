"""Derive rig textures/contours from the existing painted Halloween artwork.

Developer tools: Pillow, numpy, OpenCV. Original PNGs are never overwritten.
"""
from pathlib import Path
import subprocess
import sys
import cv2
import numpy as np
from PIL import Image, ImageFilter

PROJECT = Path(__file__).resolve().parents[1]
ROOT = PROJECT / 'assets/seasonal/halloween_v2'

# The jaw is part of the moving skull; the old ground/neck fragments are not.
skull = np.array(Image.open(ROOT / 'skeleton_head_front.png').convert('RGBA'))
skull[73:, :, 3] = 0
Image.fromarray(skull).save(ROOT / 'skeleton_skull_rig.png')

def carving_mask(name):
    a = np.array(Image.open(ROOT / f'pumpkin_{name}.png').convert('RGBA'))
    r, g, b = [a[:, :, i].astype(float) for i in range(3)]
    y, x = np.mgrid[:a.shape[0], :a.shape[1]]
    mask = ((g > 132) & (r > 180) & (g - b > 48) &
            (x > 23) & (x < 100) & (y > 28) & (y < 84))
    return a, (mask * 255).astype('uint8')

classic, mask = carving_mask('classic')
# Clear only the carved face, preserving the original silhouette, stem and ribs.
erase = cv2.dilate(mask, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7)))
skin = cv2.inpaint(classic[:, :, :3], erase, 5, cv2.INPAINT_TELEA)
Image.fromarray(np.dstack([skin, classic[:, :, 3]])).save(ROOT / 'pumpkin_shell.png')

# The face morph geometry has its own read-only image-analysis generator.
subprocess.run([sys.executable, str(PROJECT / 'scripts/derive_pumpkin_morph.py')], check=True)

# The original fog strips contain a baked checker pattern. Reuse the clean
# painted cloud brush texture for soft ground wisps instead of that pattern.
cloud = Image.open(ROOT / 'moon_cloud_clean.png').convert('RGBA')
for index, name in enumerate(['fog_far_clean', 'fog_near_clean']):
    fog = Image.new('RGBA', (600, 105))
    for x0, top, width, height in [(-45, 24, 300, 75), (145, 9, 310, 92), (360, 31, 300, 70)]:
        puff = cloud.resize((width, height), Image.Resampling.LANCZOS)
        rgb = np.array(puff)
        rgb[:, :, :3] = np.minimum(rgb[:, :, :3].astype(float) * .88 + [33, 28, 37], 255).astype('uint8')
        fog.alpha_composite(Image.fromarray(rgb), (x0, top + index * 2))
    fog = fog.filter(ImageFilter.GaussianBlur(3.2))
    alpha = np.array(fog)[:, :, 3].astype(float)
    yy, xx = np.mgrid[:105, :600]
    alpha *= np.minimum(1, xx / 55) * np.minimum(1, (599 - xx) / 55)
    fog.putalpha(Image.fromarray(alpha.astype('uint8')))
    fog.save(ROOT / f'{name}.png')

# A broader bank uses the existing painted cloud with softly blended lobes.
# Its fuller vertical silhouette can obscure the moon rather than skim below it.
cloud = Image.open(ROOT / 'moon_cloud_clean.png').convert('RGBA')
bank = Image.new('RGBA', (510, 185))
for box in [(0, 57, 350, 170), (136, 9, 498, 164), (56, 65, 460, 184)]:
    x0, y0, x1, y1 = box
    puff = cloud.resize((x1-x0, y1-y0), Image.Resampling.LANCZOS)
    bank.alpha_composite(puff, (x0, y0))
bank = bank.filter(ImageFilter.GaussianBlur(.65))
bank.save(ROOT / 'moon_cloud_bank.png')
print('Derived skull rig, pumpkin shell/painted carving contours, two clean fog strips and a broad cloud bank.')
