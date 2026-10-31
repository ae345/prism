"""Prism のアプリアイコン（SVG）を生成する。

ルール：角丸の正方形（角の半径は一辺の 22.5%）、上が明るく下が濃いグラデーション、
白い記号にうっすら影、上半分にツヤ、縁に細いハイライト。

使い方: python tools/make_icons.py
出力先: system_files/usr/share/icons/Prism/scalable/apps/
"""

from __future__ import annotations

import math
import os
from pathlib import Path

# MYOS_ICON_OUT で出力先を変えられる
OUT = Path(
    os.environ.get("MYOS_ICON_OUT")
    or Path(__file__).resolve().parent.parent / "system_files/usr/share/icons/Prism/scalable/apps"
)


def gear_path(cx: float, cy: float, outer: float, inner: float, hole: float, teeth: int) -> str:
    points = []
    step = 2 * math.pi / teeth
    for i in range(teeth):
        base = i * step - math.pi / 2
        for angle, radius in (
            (base - step * 0.30, inner),
            (base - step * 0.17, outer),
            (base + step * 0.17, outer),
            (base + step * 0.30, inner),
        ):
            points.append(f"{cx + radius * math.cos(angle):.2f} {cy + radius * math.sin(angle):.2f}")
    ring = "M" + " L".join(points) + " Z"
    circle = (
        f"M{cx + hole} {cy} A{hole} {hole} 0 1 0 {cx - hole} {cy} "
        f"A{hole} {hole} 0 1 0 {cx + hole} {cy} Z"
    )
    return ring + " " + circle


def clock_face() -> str:
    parts = ['<circle cx="50" cy="50" r="36" fill="#fff"/>']
    for i in range(12):
        width, height = (2.6, 7) if i % 3 == 0 else (1.6, 5)
        parts.append(
            f'<rect x="{50 - width / 2}" y="17" width="{width}" height="{height}" rx="0.8" '
            f'fill="#1d1d1f" transform="rotate({i * 30} 50 50)"/>'
        )
    parts += [
        '<line x1="50" y1="50" x2="50" y2="31" stroke="#1d1d1f" stroke-width="4" '
        'stroke-linecap="round" transform="rotate(-60 50 50)"/>',
        '<line x1="50" y1="50" x2="50" y2="24" stroke="#1d1d1f" stroke-width="3" '
        'stroke-linecap="round" transform="rotate(240 50 50)"/>',
        '<line x1="50" y1="58" x2="50" y2="22" stroke="#ff9f0a" stroke-width="1.4" '
        'stroke-linecap="round" transform="rotate(150 50 50)"/>',
        '<circle cx="50" cy="50" r="2.6" fill="#ff9f0a"/>',
    ]
    return "".join(parts)


SPARKLE = (
    "M50 17 C52.6 40 60 47.4 83 50 C60 52.6 52.6 60 50 83 "
    "C47.4 60 40 52.6 17 50 C40 47.4 47.4 40 50 17 Z"
)

ICONS: dict[str, dict] = {
    "browser": {
        "bg": ["#6fd6ff", "#0f6bff"],
        "ids": ["org.mozilla.firefox", "firefox", "web-browser"],
        "glyph": (
            '<clipPath id="globe"><circle cx="50" cy="50" r="28"/></clipPath>'
            '<circle cx="50" cy="50" r="28" fill="#fff"/>'
            '<g clip-path="url(#globe)" fill="none" stroke="#2a7fff" stroke-width="3.2" '
            'stroke-linecap="round">'
            '<ellipse cx="50" cy="50" rx="12" ry="28"/><path d="M20 50 H80"/>'
            '<path d="M24 35 Q50 43 76 35"/><path d="M24 65 Q50 57 76 65"/></g>'
        ),
    },
    "files": {
        "bg": ["#f1f7ff", "#b9d8ff"],
        "ids": ["org.gnome.Nautilus", "system-file-manager"],
        "shadow": 0.12,
        "glyph": (
            '<linearGradient id="front" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#7cc2ff"/><stop offset="1" stop-color="#3a92f4"/>'
            "</linearGradient>"
            '<path d="M21 33 a6 6 0 0 1 6-6 h14 l6 6 h26 a6 6 0 0 1 6 6 v4 H21 Z" fill="#2c86ee"/>'
            '<rect x="21" y="38" width="58" height="37" rx="6" fill="url(#front)"/>'
        ),
    },
    "game": {
        "bg": ["#53698f", "#121a2c"],
        "ids": ["steam", "com.valvesoftware.Steam"],
        "glyph": (
            '<path d="M31 35 h38 a16 16 0 0 1 15.6 12.5 l4.2 18.6 a8 8 0 0 1-13.8 7 L68 66 H32 '
            'l-7 7.1 a8 8 0 0 1-13.8-7 l4.2-18.6 A16 16 0 0 1 31 35 Z" fill="#fff"/>'
            '<rect x="29" y="44" width="6" height="15" rx="1.6" fill="#24314b"/>'
            '<rect x="24.5" y="48.5" width="15" height="6" rx="1.6" fill="#24314b"/>'
            '<circle cx="66" cy="47.5" r="3.4" fill="#24314b"/>'
            '<circle cx="73.5" cy="54.5" r="3.4" fill="#24314b"/>'
        ),
    },
    "assistant": {
        "bg": ["#8f9bff", "#b45bff", "#ff6fd8"],
        "diagonal": True,
        "ids": ["io.github.myos.Assistant"],
        "glyph": (
            f'<path d="{SPARKLE}" fill="#fff"/>'
            f'<path d="{SPARKLE}" fill="#fff" opacity="0.85" '
            'transform="translate(60 8) scale(0.3)"/>'
        ),
    },
    "music": {
        "bg": ["#ff94b4", "#ff2d55"],
        "ids": ["org.gnome.Music", "multimedia-audio-player"],
        "glyph": (
            '<g fill="#fff"><polygon points="38,33 70,25 70,34 38,42"/>'
            '<rect x="37" y="35" width="4.4" height="33" rx="1"/>'
            '<rect x="65.6" y="27" width="4.4" height="34" rx="1"/>'
            '<ellipse cx="32" cy="68" rx="9.5" ry="7.2" transform="rotate(-20 32 68)"/>'
            '<ellipse cx="60.6" cy="61" rx="9.5" ry="7.2" transform="rotate(-20 60.6 61)"/></g>'
        ),
    },
    "claude-code": {
        "bg": ["#33302d", "#0f0d0c"],
        "ids": ["myos-claude-code"],
        "glyph": (
            '<path d="M30 37 L45 50 L30 63" fill="none" stroke="#f3a888" stroke-width="6.5" '
            'stroke-linecap="round" stroke-linejoin="round"/>'
            '<path d="M51 65 H71" stroke="#d97757" stroke-width="6.5" stroke-linecap="round"/>'
        ),
    },
    "terminal": {
        "bg": ["#45454b", "#111113"],
        "ids": ["org.gnome.Ptyxis", "utilities-terminal", "org.gnome.Terminal"],
        "glyph": (
            '<path d="M30 37 L45 50 L30 63" fill="none" stroke="#fff" stroke-width="6.5" '
            'stroke-linecap="round" stroke-linejoin="round"/>'
            '<path d="M51 65 H71" stroke="#fff" stroke-width="6.5" stroke-linecap="round"/>'
        ),
    },
    "settings": {
        "bg": ["#f0f2f5", "#a3aab5"],
        "ids": ["org.gnome.Settings", "preferences-system"],
        "shadow": 0.14,
        "glyph": (
            '<linearGradient id="gear" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#7b8390"/><stop offset="1" stop-color="#3b424d"/>'
            "</linearGradient>"
            f'<path d="{gear_path(50, 50, 33, 26, 10, 9)}" fill="url(#gear)" fill-rule="evenodd" '
            'stroke="url(#gear)" stroke-width="2.5" stroke-linejoin="round"/>'
            '<circle cx="50" cy="50" r="16" fill="none" stroke="#5b636f" stroke-width="2"/>'
        ),
    },
    "photos": {
        "bg": ["#ffd27a", "#ff6a5c"],
        "ids": ["org.gnome.Loupe", "org.gnome.Shotwell", "image-viewer"],
        "glyph": (
            '<circle cx="65" cy="35" r="9" fill="#fff"/>'
            '<path d="M40 76 L63 47 L86 76 Z" fill="#fff" opacity="0.6"/>'
            '<path d="M14 76 L38 46 L62 76 Z" fill="#fff"/>'
        ),
    },
    "calendar": {
        "bg": ["#ffffff", "#f0f0f4"],
        "ids": ["org.gnome.Calendar", "x-office-calendar"],
        "shadow": 0,
        "glyph": (
            '<text x="50" y="33" text-anchor="middle" font-family="Inter, \'Noto Sans CJK JP\', '
            'sans-serif" font-size="13" font-weight="700" fill="#ff3b30">木</text>'
            '<text x="50" y="74" text-anchor="middle" font-family="Inter, sans-serif" '
            'font-size="42" font-weight="300" letter-spacing="-1.5" fill="#1d1d1f">30</text>'
        ),
    },
    "mail": {
        "bg": ["#7bd6ff", "#0a6cff"],
        "ids": ["org.gnome.Geary", "mail-client"],
        "glyph": (
            '<rect x="19" y="29" width="62" height="43" rx="7" fill="#fff"/>'
            '<path d="M22 33 L50 54 L78 33" fill="none" stroke="#2f86ff" stroke-width="3.6" '
            'stroke-linecap="round" stroke-linejoin="round"/>'
        ),
    },
    "notes": {
        "bg": ["#fffdf5", "#f6f1e2"],
        "ids": ["org.gnome.TextEditor", "accessories-text-editor"],
        "shadow": 0,
        "glyph": (
            '<rect x="0" y="0" width="100" height="28" fill="#ffd84d"/>'
            '<path d="M20 47 H80 M20 60 H80 M20 73 H60" stroke="#d9d3c1" stroke-width="2.4" '
            'stroke-linecap="round"/>'
        ),
    },
    "weather": {
        "bg": ["#58bfff", "#1d5fd6"],
        "ids": ["org.gnome.Weather"],
        "glyph": (
            '<circle cx="40" cy="40" r="19" fill="#ffd60a" opacity="0.25"/>'
            '<circle cx="40" cy="40" r="13" fill="#ffd60a"/>'
            '<path d="M33 75 h36 a12.5 12.5 0 0 0 0-25 a16.5 16.5 0 0 0-31.5 5.2 A10 10 0 0 0 33 75 Z" '
            'fill="#fff"/>'
        ),
    },
    "clock": {
        "bg": ["#2c2c2e", "#000000"],
        "ids": ["org.gnome.clocks"],
        "glyph": clock_face(),
    },
    "software": {
        "bg": ["#cbb9ff", "#6a3fe0"],
        "ids": ["org.gnome.Software", "system-software-install"],
        "glyph": (
            '<path d="M40 40 v-5 a10 10 0 0 1 20 0 v5" fill="none" stroke="#fff" '
            'stroke-width="4.5" stroke-linecap="round"/>'
            '<path d="M27 40 h46 l-3.4 33.6 a6 6 0 0 1-6 5.4 H36.4 a6 6 0 0 1-6-5.4 Z" fill="#fff"/>'
            f'<path d="{SPARKLE}" fill="#8a5cf0" transform="translate(39 46) scale(0.22)"/>'
        ),
    },
    "maps": {
        "bg": ["#79ebb7", "#0f9f7c"],
        "ids": ["org.gnome.Maps"],
        "glyph": (
            '<path d="M21 31 L40 25 L40 71 L21 77 Z" fill="#fff" opacity="0.82"/>'
            '<path d="M40 25 L60 31 L60 77 L40 71 Z" fill="#fff"/>'
            '<path d="M60 31 L79 25 L79 71 L60 77 Z" fill="#fff" opacity="0.82"/>'
            '<path d="M60 27 a10 10 0 0 1 10 10 c0 8-10 17-10 17 s-10-9-10-17 a10 10 0 0 1 10-10 Z" '
            'fill="#ff3b30"/><circle cx="60" cy="37" r="3.6" fill="#fff"/>'
        ),
    },
    "video": {
        "bg": ["#ff94c4", "#e0245e"],
        "ids": ["org.gnome.Showtime", "org.gnome.Totem", "multimedia-video-player"],
        "glyph": (
            '<path d="M41 32 L70 50 L41 68 Z" fill="#fff" stroke="#fff" stroke-width="7" '
            'stroke-linejoin="round"/>'
        ),
    },
    "calculator": {
        "bg": ["#848f9c", "#2b3138"],
        "ids": ["org.gnome.Calculator", "accessories-calculator"],
        "glyph": (
            '<rect x="23" y="23" width="24" height="24" rx="7" fill="#fff" opacity="0.2"/>'
            '<rect x="53" y="23" width="24" height="24" rx="7" fill="#fff" opacity="0.2"/>'
            '<rect x="23" y="53" width="24" height="24" rx="7" fill="#fff" opacity="0.2"/>'
            '<rect x="53" y="53" width="24" height="24" rx="7" fill="#ff9f0a"/>'
            '<g stroke="#fff" stroke-width="3.2" stroke-linecap="round">'
            '<path d="M35 29 V41 M29 35 H41"/><path d="M59 35 H71"/>'
            '<path d="M30.5 59.5 L39.5 70.5 M39.5 59.5 L30.5 70.5"/>'
            '<path d="M59 61.5 H71 M59 68.5 H71"/></g>'
        ),
    },
}


def render(name: str, spec: dict) -> str:
    colors = spec["bg"]
    x2, y2 = ("1", "1") if spec.get("diagonal") else ("0", "1")
    stops = "".join(
        f'<stop offset="{i / (len(colors) - 1):.2f}" stop-color="{c}"/>' for i, c in enumerate(colors)
    )
    shadow = spec.get("shadow", 0.2)
    glyph = spec["glyph"]
    if shadow:
        glyph = f'<g filter="url(#shadow)">{glyph}</g>'
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 100 100">'
        "<defs>"
        f'<linearGradient id="bg" x1="0" y1="0" x2="{x2}" y2="{y2}">{stops}</linearGradient>'
        '<linearGradient id="gloss" x1="0" y1="0" x2="0" y2="1">'
        '<stop offset="0" stop-color="#fff" stop-opacity="0.32"/>'
        '<stop offset="0.5" stop-color="#fff" stop-opacity="0"/></linearGradient>'
        '<filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">'
        f'<feDropShadow dx="0" dy="1.6" stdDeviation="1.6" flood-color="#000" flood-opacity="{shadow}"/>'
        "</filter>"
        '<clipPath id="tile"><rect width="100" height="100" rx="22.5"/></clipPath>'
        "</defs>"
        '<g clip-path="url(#tile)">'
        '<rect width="100" height="100" fill="url(#bg)"/>'
        f"{glyph}"
        '<rect width="100" height="100" fill="url(#gloss)"/>'
        "</g>"
        '<rect x="0.6" y="0.6" width="98.8" height="98.8" rx="22" fill="none" '
        'stroke="#fff" stroke-opacity="0.28" stroke-width="1.2"/>'
        "</svg>\n"
    )


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, spec in ICONS.items():
        svg = render(name, spec)
        for icon_id in [f"myos-{name}", *spec["ids"]]:
            (OUT / f"{icon_id}.svg").write_text(svg, encoding="utf-8")
    print(f"wrote {len(ICONS)} icons to {OUT}")


if __name__ == "__main__":
    main()
