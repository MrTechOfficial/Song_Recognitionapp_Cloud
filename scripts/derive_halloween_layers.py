"""Derive Halloween-only layers from the existing art; originals stay intact.
Developer recipe: Pillow, numpy and OpenCV. No app/runtime dependencies.
"""
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1] / 'assets/seasonal/halloween_v2'
cloud = np.array(Image.open(ROOT / 'moon_cloud.png').convert('RGBA'))
cr, cg, cb = (cloud[:, :, i].astype(float) for i in range(3))
# Discard the neutral checkerboard fringe baked into the old cutout, while
# retaining its painted violet cloud and soft translucent edge.
cloud_matte = np.clip((cb - cr) / 10, 0, 1) * np.clip((cb - cg) / 16, 0, 1)
cloud[:, :, 3] = (cloud[:, :, 3] * cloud_matte).astype('uint8')
reliable = cloud[:, :, 3] > 210
assert reliable.any()
# Fill the artificial checker holes, soften the silhouette and extend nearby
# painted color into its edge. Removing only grey pixels left a perforated
# fringe that was visible against the bright moon.
silhouette = cv2.morphologyEx(reliable.astype('uint8') * 255, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
silhouette = (cv2.GaussianBlur(silhouette, (0, 0), 2.4) > 110).astype('uint8') * 255
silhouette = cv2.GaussianBlur(silhouette, (0, 0), 1.1)
_, nearest = cv2.distanceTransformWithLabels((~reliable).astype('uint8'), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
palette = np.zeros((nearest.max() + 1, 3), np.uint8)
palette[nearest[reliable]] = cloud[:, :, :3][reliable]
cloud[:, :, :3][~reliable] = palette[nearest[~reliable]]
cloud[:, :, 3] = silhouette
Image.fromarray(cloud).save(ROOT / 'moon_cloud_clean.png')
base = Image.open(ROOT / 'background.png').convert('RGB')
rgb = np.array(base)
h, w = rgb.shape[:2]
y, x = np.mgrid[:h, :w]
r, g, b = (rgb[:, :, i].astype(float) for i in range(3))
# Exclude the moon, ground, fence and stars. Upper boughs and the lower trunk
# have separate envelopes so warm ground details cannot become moving scenery.
roi = ((x < 293) & (y >= 92) & (y < 390)) | ((y >= 390) & (y < 620) & (x < (114 - (y - 390) * .14)))
roi &= ((x - 318) ** 2 + (y - 96) ** 2 > 52 ** 2)
mask = np.zeros((h, w), np.uint8)
mask[roi] = cv2.GC_PR_BGD
warm = (r > b * 1.18 + 2) & (g > b * .91) & (r > g * 1.12)
dark = (r * .3 + g * .59 + b * .11 < 18)
mask[roi & (warm | dark)] = cv2.GC_PR_FGD
mask[roi & warm & (r > 45)] = cv2.GC_FGD
mask[roi & dark] = cv2.GC_FGD
# Painted purple sky is definite background; black branch ink stays eligible.
purple = (b > r * 1.02) & (b > g * 1.3) & ((r + g + b) > 100)
mask[roi & purple] = cv2.GC_BGD
cv2.grabCut(rgb, mask, None, np.zeros((1, 65)), np.zeros((1, 65)), 8, cv2.GC_INIT_WITH_MASK)
fg = np.isin(mask, [cv2.GC_FGD, cv2.GC_PR_FGD]).astype(np.uint8)
contours, _ = cv2.findContours(fg, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
cv2.drawContours(fg, contours, -1, 1, cv2.FILLED)
num, labels, stats, _ = cv2.connectedComponentsWithStats(fg, 8)
main = 1 + np.argmax(stats[1:, cv2.CC_STAT_AREA])
distance = cv2.distanceTransform((labels != main).astype('uint8'), cv2.DIST_L2, 3)
keep = [i for i in range(1, num) if stats[i, cv2.CC_STAT_AREA] >= 7 and np.min(distance[labels == i]) < 15]
fg = np.isin(labels, keep).astype(np.uint8) * 255
fg = cv2.dilate(fg, np.ones((3, 3), np.uint8))
fg[:, 0] = 0
# Keep the existing texture/ink exactly. Binary coverage means the resting
# composition of these two derived files is pixel-identical to background.png.
layer = np.dstack([rgb, fg])
Image.fromarray(layer).save(ROOT / 'tree_isolated.png')
inpaint_source = rgb.copy()
# The original PNG has a pale one-pixel frame. Do not propagate that frame
# through the hidden trunk area during inpainting.
inpaint_source[:, 0] = rgb[:, 2]
inpaint_source[0, :] = rgb[2, :]
clear = cv2.inpaint(inpaint_source, fg, 4, cv2.INPAINT_TELEA)
for row in range(390, 620):
    columns = np.flatnonzero(fg[row])
    if len(columns):
        start = min(int(columns[-1]) + 8, w - 31)
        texture = rgb[row, start:start + 30]
        clear[row, columns] = texture[np.arange(len(columns)) % len(texture)]
clear[fg == 0] = rgb[fg == 0]
Image.fromarray(clear).save(ROOT / 'background_tree_clear.png')
restored = Image.alpha_composite(Image.fromarray(clear).convert('RGBA'), Image.fromarray(layer)).convert('RGB')
assert np.array_equal(np.array(restored), rgb), 'Resting tree must preserve the original illustration'

# Closed mouth: preserve the classic pumpkin's skin and eyes, replace only its
# open grin with a narrow, warm carved slit in the same painted style.
classic = Image.open(ROOT / 'pumpkin_classic.png').convert('RGBA')
a = np.array(classic)
yy, xx = np.mgrid[:a.shape[0], :a.shape[1]].astype('float32')
# Close the existing painted grin by compressing its vertical aperture. A
# continuous warp keeps the actual belly/rib texture, eyes, stem and outline;
# no pasted skin patch or generated replacement art is introduced.
mapped_y = np.interp(yy, [0, 59, 64, 70, 95], [0, 59, 63, 81, 95])
weight = np.clip((xx - 23) / 10, 0, 1) * np.clip((105 - xx) / 10, 0, 1)
warped = cv2.remap(a[:, :, :3], xx, (yy + (mapped_y - yy) * weight).astype('float32'), cv2.INTER_CUBIC)
closed = Image.fromarray(np.dstack([warped, a[:, :, 3]]))
closed.save(ROOT / 'pumpkin_closed.png')

# White alpha masks follow the actual lit carvings, not a circular orange blob.
for name in ['classic', 'surprised', 'closed']:
    im = np.array(Image.open(ROOT / f'pumpkin_{name}.png').convert('RGBA'))
    rr, gg, bb = (im[:, :, i].astype(float) for i in range(3))
    yy, xx = np.mgrid[:im.shape[0], :im.shape[1]]
    carving = (xx > 23) & (xx < 101) & (yy > 29) & (yy < 83)
    strength = np.clip((gg - 65) / 110, 0, 1) * np.clip((rr - bb - 65) / 100, 0, 1)
    strength *= carving * (im[:, :, 3] / 255)
    glow = np.full_like(im, 255)
    glow[:, :, 3] = (strength * 255).astype('uint8')
    Image.fromarray(glow).save(ROOT / f'pumpkin_{name}_light_mask.png')

# Borrow only the existing painted eyelids. Preserve the open skull's silhouette,
# nose, jaw and neck so a blink cannot resize or flash the whole head.
front = Image.open(ROOT / 'skeleton_head_front.png').convert('RGBA')
blink = Image.open(ROOT / 'skeleton_head_front_blink.png').convert('RGBA')
aligned = Image.new('RGBA', front.size)
aligned.paste(blink, (3, -7))
eyes = Image.new('L', front.size)
d = ImageDraw.Draw(eyes)
d.ellipse((23, 35, 45, 58), fill=255)
d.ellipse((45, 35, 67, 58), fill=255)
eyes = eyes.filter(ImageFilter.GaussianBlur(.55))
aa = np.array(aligned)
aa[:, :, 3] = (aa[:, :, 3].astype(float) * np.array(eyes) / 255).astype('uint8')
aa[:, :, 3][np.array(front)[:, :, 3] < 255] = 0
aa[52:67, 42:53, 3] = 0  # Keep the nose/bridge entirely outside the eyelid mask.
Image.fromarray(aa).save(ROOT / 'skeleton_eyes_closed_overlay.png')
print('Derived tree/clean background, clean cloud, closed pumpkin, three carving masks and eyelid overlay.')
