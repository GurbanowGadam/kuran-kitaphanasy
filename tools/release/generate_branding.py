#!/usr/bin/env python3
"""Render Flutter's real auto_stories_outlined outline, never a substitute book.
Use --flutter-root to re-extract after explicit SDK/glyph review; otherwise use
committed original outline. Requirements: tools/release/branding-requirements.txt.
"""
import argparse
import hashlib
import io
import json
import re
from pathlib import Path
import cairosvg
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BRAND = ROOT / 'assets/branding'
BG = '#18685f'

def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flutter-root', type=Path)
    args = parser.parse_args()
    BRAND.mkdir(parents=True, exist_ok=True)
    if args.flutter_root:
        from fontTools.ttLib import TTFont
        from fontTools.pens.svgPathPen import SVGPathPen
        from fontTools.pens.transformPen import TransformPen
        from fontTools.pens.boundsPen import BoundsPen
        sdk = args.flutter_root
        source = sdk / 'packages/flutter/lib/src/material/icons.dart'
        codepoint = int(re.search(r'auto_stories_outlined = IconData\(0x([0-9a-f]+)', source.read_text())[1], 16)
        font_path = sdk / 'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
        font = TTFont(font_path)
        glyph_name = font.getBestCmap()[codepoint]
        glyphs = font.getGlyphSet()
        bounds = BoundsPen(glyphs)
        glyphs[glyph_name].draw(bounds)
        x0, y0, x1, y1 = bounds.bounds
        # Uniform scaling and y inversion only: preserve original outline geometry.
        scale = 24 / max(x1-x0, y1-y0)
        dx = (24-(x1-x0)*scale)/2-x0*scale
        dy = (24-(y1-y0)*scale)/2+y1*scale
        pen = SVGPathPen(glyphs)
        glyphs[glyph_name].draw(TransformPen(pen, (scale, 0, 0, -scale, dx, dy)))
        write(BRAND/'auto_stories_outlined.path', pen.getCommands()+'\n')
        write(BRAND/'glyph-provenance.json', json.dumps({
            'icon': 'Icons.auto_stories_outlined', 'fontFamily': 'MaterialIcons',
            'codepoint': hex(codepoint), 'glyphName': glyph_name,
            'fontSha256': hashlib.sha256(font_path.read_bytes()).hexdigest(),
            'iconsDartSha256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'source': 'Flutter SDK bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            'transformation': 'Uniform scale, center, y-axis inversion only; no redrawing',
            'license': 'Apache-2.0; see MaterialIcons-LICENSE.txt'
        }, indent=2)+'\n')
    outline = (BRAND/'auto_stories_outlined.path').read_text().strip()
    def svg(foreground=False):
        # 52% width keeps all geometry inside adaptive-icon safe circle.
        return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108">'
                + ('' if foreground else f'<path fill="{BG}" d="M0 0h108v108H0z"/>')
                + f'<path fill="#ffffff" transform="translate(26 26) scale({56/24})" d="{outline}"/></svg>\n')
    write(BRAND/'app-icon.svg', svg())
    write(BRAND/'app-icon-foreground.svg', svg(True))
    generated = {}
    def png(path, size, foreground=False):
        path.parent.mkdir(parents=True, exist_ok=True)
        raw = cairosvg.svg2png(bytestring=svg(foreground).encode(), output_width=size, output_height=size)
        image = Image.open(io.BytesIO(raw)).convert('RGBA' if foreground else 'RGB')
        image.save(path)
        generated[str(path.relative_to(ROOT))] = size
    res = ROOT/'android/app/src/main/res'
    for density, size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
        png(res/f'mipmap-{density}/ic_launcher.png', size)
        png(res/f'mipmap-{density}/ic_launcher_foreground.png', round(size * 108 / 48), True)
    # Vector uses the identical extracted path, full adaptive foreground canvas.
    write(res/'drawable/ic_launcher_foreground.xml',
          '<?xml version="1.0" encoding="utf-8"?>\n'
          '<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">'
          f'<group android:translateX="26" android:translateY="26" android:scaleX="{56/24}" android:scaleY="{56/24}">'
          f'<path android:fillColor="#FFFFFFFF" android:pathData="{outline}"/></group></vector>\n')
    write(res/'values/icon_colors.xml', f'<resources><color name="ic_launcher_background">{BG}</color></resources>\n')
    write(res/'mipmap-anydpi-v26/ic_launcher.xml', '<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@color/ic_launcher_background"/><foreground android:drawable="@drawable/ic_launcher_foreground"/></adaptive-icon>\n')
    write(res/'mipmap-anydpi-v33/ic_launcher.xml', '<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@color/ic_launcher_background"/><foreground android:drawable="@drawable/ic_launcher_foreground"/><monochrome android:drawable="@drawable/ic_launcher_foreground"/></adaptive-icon>\n')
    catalog = ROOT/'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    contents = json.loads((catalog/'Contents.json').read_text())
    for icon in contents['images']:
        if 'filename' not in icon:
            continue
        size = round(float(icon['size'].split('x')[0])*float(icon['scale'].rstrip('x')))
        png(catalog/icon['filename'], size)
    for size in (192, 512):
        png(ROOT/f'web/icons/Icon-{size}.png', size)
        png(ROOT/f'web/icons/Icon-maskable-{size}.png', size)
    png(ROOT/'web/favicon.png', 32)
    png(BRAND/'app-icon-1024.png', 1024)
    png(BRAND/'play-store-icon-512.png', 512)
    write(BRAND/'generated-icons.json', json.dumps(generated, indent=2)+'\n')
    print(f'Generated {len(generated)} PNGs, original SVG and Android adaptive vectors from {outline[:24]}…')

if __name__ == '__main__':
    main()
