"""Reversible layers from existing artwork; originals stay intact.
Developer-only dependencies: Pillow, numpy, OpenCV.
"""
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1] / 'assets/seasonal'
h = ROOT / 'halloween_v2'
base = np.array(Image.open(h / 'background_tree_clear.png').convert('RGB'))
original = np.array(Image.open(h / 'background.png').convert('RGB'))
tree = np.array(Image.open(h / 'tree_isolated.png').convert('RGBA'))[:, :, 3] > 0
r, g, b = [original[:, :, i].astype(float) for i in range(3)]
yy, xx = np.mgrid[:696, :406]
clouds = (g / np.maximum(r, 1) > .56) & (b - g > 11) & (r > 52) & (yy < 535) & (yy > 53) & ~tree
moon = (xx - 318) ** 2 + (yy - 96) ** 2 < 47 ** 2
clouds[moon] = ((b > r) & (r < 180) & (yy > 70))[moon]
# Each original cloud band becomes a separate drifting layer.
bands = [(53, 112), (112, 155), (155, 212), (300, 388), (388, 470), (470, 535)]
erase = np.zeros((696, 406), np.uint8)
for i, (top, bottom) in enumerate(bands):
    mask = np.zeros_like(erase)
    mask[top:bottom] = clouds[top:bottom].astype('uint8') * 255
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    mask[tree] = 0
    erase = np.maximum(erase, cv2.dilate(mask, np.ones((5, 5), np.uint8)))
    layer = np.dstack([original, cv2.GaussianBlur(mask, (0, 0), .8)])
    strip=layer[top:bottom].copy()
    sy,sx=np.mgrid[:bottom-top,:406]
    feather=np.minimum(1,sy/5)*np.minimum(1,(bottom-top-1-sy)/5)
    feather*=np.minimum(1,sx/7)*np.minimum(1,(405-sx)/7)
    strip[:,:,3]=(strip[:,:,3]*feather).astype('uint8')
    Image.fromarray(strip).save(h / f'sky_cloud_{i}.png')
# Build a quiet textured sky under the extracted cloud artwork. Inpainting
# entire cloud banks produced obvious smears; a painted-color sky plate avoids
# frozen cloud ghosts and also removes the old static bat.
keys = np.array([0, 130, 300, 480, 535])
colors = np.array([[23, 12, 43], [39, 20, 64], [48, 24, 78], [78, 46, 109], [85, 51, 117]])
rows = np.column_stack([np.interp(np.arange(696), keys, colors[:, i]) for i in range(3)])
rng = np.random.default_rng(26)
grain = rng.normal(0, 1, (45, 27)).astype('float32')
grain = cv2.resize(grain, (406, 696), interpolation=cv2.INTER_CUBIC)
sky = np.clip(rows[:, None, :] + grain[:, :, None] * 3.5, 0, 255)
# Retain the small painted amber stars without retaining stationary clouds.
stars = (r > 102) & (r > b * 1.12) & (g > 57) & (yy < 480) & ~tree & ~moon
count, labels, stats, _ = cv2.connectedComponentsWithStats(stars.astype('uint8'))
small = np.isin(labels, [i for i in range(1, count) if stats[i, cv2.CC_STAT_AREA] <= 8])
sky[small] = original[small]
# Preserve original warm moon/crater paint. Fill only the old cloud stripe and
# its edge with matching moon colors before moving clouds are drawn over it.
moon_distance = np.sqrt((xx-318)**2+(yy-96)**2)
moon_alpha = np.clip(46 - moon_distance, 0, 1)
warm = (r > 165) & (g > 100) & (r > b * 1.25)
moon_color = np.zeros_like(sky) + [246, 195, 108]
moon_color += grain[:, :, None] * 1.6
moon_color[warm] = original[warm]
sky = sky * (1-moon_alpha[:, :, None]) + moon_color * moon_alpha[:, :, None]
# Leave the distant graveyard and entire ground intact, with a broad soft join.
join = np.clip((yy - 480) / 60, 0, 1)[:, :, None]
clear = np.clip(sky * (1-join) + base * join, 0, 255).astype('uint8')
# Extend adjacent artwork through the uploaded image's white frame.
clear[:2] = clear[2]; clear[-2:] = clear[-3]
clear[:, :2] = clear[:, 2:3]; clear[:, -2:] = clear[:, -3:-2]
Image.fromarray(clear).save(h / 'background_living_sky.png')

# Strict warm eye apertures: no mouth, skin glow or visible flame overlay.
for name in ['classic','surprised','sly']:
    a=np.array(Image.open(h / f'pumpkin_{name}.png').convert('RGBA'))
    pr,pg,pb=[a[:,:,j].astype(float) for j in range(3)]
    ey,ex=np.mgrid[:a.shape[0],:a.shape[1]]
    alpha=((pr>200)&(pg>135)&(pr-pb>90)&(ey>30)&(ey<55)&(ex>24)&(ex<100))
    out=np.full_like(a,255);out[:,:,3]=alpha.astype('uint8')*255
    Image.fromarray(out).save(h / f'pumpkin_{name}_eyes_mask.png')

c = ROOT / 'christmas'
winter=np.array(Image.open(c / 'christmas_background_clean.png').convert('RGB'))
winter[:2]=winter[2];winter[-2:]=winter[-3]
winter[:,:2]=winter[:,2:3];winter[:,-2:]=winter[:,-3:-2]
Image.fromarray(winter).save(c / 'christmas_background_edge_fill.png')
art = Image.open(c / 'snowman_skate_right.png').convert('RGBA')
polygons = {
    'skate_back': [(145, 756), (312, 747), (434, 820), (401, 924), (276, 1038), (141, 1038)],
    'skate_front': [(669, 951), (792, 939), (842, 1027), (1009, 1053), (1032, 1220), (654, 1220), (654, 1081)],
    'scarf_tail': [(563, 423), (506, 415), (356, 321), (299, 294), (257, 339), (317, 378), (191, 398), (223, 443), (189, 499), (268, 541), (364, 505), (547, 519), (568, 486)],
}
body = art.copy()
body_alpha = np.array(body)[:, :, 3]
for name, polygon in polygons.items():
    mask = Image.new('L', art.size); ImageDraw.Draw(mask).polygon(polygon, fill=255)
    a = np.array(art); coverage = np.array(mask)
    a[:, :, 3] = np.minimum(a[:, :, 3], coverage)
    Image.fromarray(a).resize((400, 400), Image.Resampling.LANCZOS).save(c / f'snowman_{name}.png')
    body_alpha[coverage > 0] = 0
# Drop disconnected scraps left after separating the scarf fringe.
count, labels, stats, _ = cv2.connectedComponentsWithStats((body_alpha>0).astype('uint8'))
keep=max(range(1,count),key=lambda i:stats[i,cv2.CC_STAT_AREA])
body_alpha[labels!=keep]=0
body.putalpha(Image.fromarray(body_alpha))
body.resize((400, 400), Image.Resampling.LANCZOS).save(c / 'snowman_body_rig.png')
print('Derived six moving painted sky bands, border-free sky base and four 400px snowman rig layers.')
