#!/usr/bin/env python3
"""
Generate PNG watermark assets from Papirus SVG icons for the Debian BGRT Plymouth theme.
"""

import os
import re
import shutil
import gi

gi.require_version('GdkPixbuf', '2.0')
from gi.repository import GdkPixbuf

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
ASSETS_DIR = os.path.join(REPO_ROOT, 'assets')
SOURCE_DIR = os.path.join(ASSETS_DIR, 'source')
os.makedirs(SOURCE_DIR, exist_ok=True)

PAPIRUS_SVG = '/usr/share/icons/Papirus/64x64/apps/distributor-logo-debian.svg'

def main():
    if not os.path.isfile(PAPIRUS_SVG):
        print(f"Warning: {PAPIRUS_SVG} not found. Ensure the 'papirus-icon-theme' package is installed.")
        return

    # 1. Copy original Papirus Debian SVG
    dest_papirus_svg = os.path.join(SOURCE_DIR, 'distributor-logo-debian.svg')
    shutil.copyfile(PAPIRUS_SVG, dest_papirus_svg)
    print(f"Copied original SVG to {dest_papirus_svg}")

    with open(PAPIRUS_SVG, 'r') as f:
        orig_svg = f.read()

    # 2. Generate Fedora-Style (Badge + white text "debian")
    inner = re.sub(r'<\?xml[^>]*\?>', '', orig_svg)
    inner = re.sub(r'<!DOCTYPE[^>]*>', '', inner)
    inner = re.sub(r'<svg[^>]*>', '', inner)
    inner = re.sub(r'</svg>', '', inner)

    fedora_svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="180" height="48" viewBox="0 0 180 48">
  <!-- Papirus Badge scaled to 44x44 -->
  <g transform="translate(2, 2) scale(0.6875)">
    {inner}
  </g>
  <!-- debian text in white -->
  <text x="54" y="33" font-family="Cantarell, Ubuntu, DejaVu Sans, sans-serif" font-size="26" font-weight="bold" fill="#ffffff" letter-spacing="0.5">debian</text>
</svg>'''
    fedora_svg_path = os.path.join(SOURCE_DIR, 'watermark-badge-with-text.svg')
    with open(fedora_svg_path, 'w') as f:
        f.write(fedora_svg)

    # 3. Generate Swirl Only in Papirus #f9548f
    swirl_match = re.search(r'<path style="fill:#ffffff" d="([^"]+)"', orig_svg)
    if swirl_match:
        d = swirl_match.group(1)
        swirl_svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <path style="fill:#f9548f" d="{d}"/>
</svg>'''
        swirl_svg_path = os.path.join(SOURCE_DIR, 'watermark-swirl.svg')
        with open(swirl_svg_path, 'w') as f:
            f.write(swirl_svg)

    # 4. Render PNG assets using GdkPixbuf
    targets = [
        # (src_svg, out_filename, width, height, preserve_aspect)
        (fedora_svg_path, 'watermark-badge-with-text.png', 180, 48, False),
        (PAPIRUS_SVG, 'watermark-badge.png', 64, 64, True),
        (os.path.join(SOURCE_DIR, 'watermark-swirl.svg'), 'watermark-swirl.png', 64, 64, True),
    ]

    for src, name, w, h, aspect in targets:
        if os.path.isfile(src):
            pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(src, w, h, aspect)
            out_path = os.path.join(ASSETS_DIR, name)
            pb.savev(out_path, 'png', [], [])
            print(f"Generated: {out_path} ({pb.get_width()}x{pb.get_height()})")

    print("\nAll assets generated successfully!")

if __name__ == '__main__':
    main()
