#!/usr/bin/env python3
"""Builds `windows/runner/resources/app_icon.ico` from the brand PNG.

    python3 tool/make_windows_icon.py

## Why this exists

`flutter create` scaffolds the Windows runner with **Flutter's own** icon, and
nothing in a Flutter build ever replaces it. The result ships as a kitchen
application with somebody else's logo on the taskbar — reported by the owner
2026-11-23: *"on the computer it has no software icon yet on samsung the kds
has one"*. Android gets its launcher icon from `android/app/src/main/res`,
which was generated; Windows reads one `.ico` and that file was the template's.

Written here rather than done once by hand so the brand asset stays the single
source: change `assets/branding/app_icon.png` and run this again.

## Why it is written out by hand

ImageMagick and Pillow are both absent on the machine this ships from, and
adding either to build an icon would put a toolchain between the brand asset
and the binary. The ICO container is a 6-byte header, a 16-byte directory
entry per size, and the payloads — and since Vista those payloads may be PNG,
which is what `sips` already produces.
"""

import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets" / "branding" / "app_icon.png"
TARGET = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"

# 16 through 256. Windows picks per context — 16 in the title bar, 32 in the
# taskbar, 256 in a large Explorer view — and an .ico missing a size is
# rescaled from another one, which is how a crisp logo turns into a smudge.
SIZES = (16, 24, 32, 48, 64, 128, 256)


def render(size: int, out: Path) -> bytes:
    """One square PNG at `size`, through macOS's own resampler."""
    subprocess.run(
        ["sips", "-s", "format", "png", "-z", str(size), str(size),
         str(SOURCE), "--out", str(out)],
        check=True, capture_output=True,
    )
    return out.read_bytes()


def main() -> int:
    if not SOURCE.exists():
        print(f"missing {SOURCE}", file=sys.stderr)
        return 1

    work = Path("/tmp/timma-icon")
    work.mkdir(exist_ok=True)
    images = [(size, render(size, work / f"{size}.png")) for size in SIZES]

    header = struct.pack("<HHH", 0, 1, len(images))
    offset = len(header) + 16 * len(images)
    directory = b""
    for size, data in images:
        directory += struct.pack(
            "<BBBBHHII",
            # ⚠ 256 is written as 0. The field is one byte, so the largest
            # size a directory entry can state literally is 255; 0 is the
            # format's way of saying 256, and an icon that writes 256 here
            # wraps to 0 anyway on some writers and to garbage on others.
            0 if size == 256 else size,
            0 if size == 256 else size,
            0,   # no colour palette
            0,   # reserved
            1,   # colour planes
            32,  # bits per pixel
            len(data),
            offset,
        )
        offset += len(data)

    TARGET.write_bytes(header + directory + b"".join(data for _, data in images))
    print(f"{TARGET.relative_to(ROOT)}: {len(SIZES)} sizes, "
          f"{TARGET.stat().st_size} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
