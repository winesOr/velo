#!/usr/bin/env python3
"""Generate deterministic test artwork without third-party images or libraries."""

import math
from pathlib import Path
import struct
import zlib


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "test/fixtures/artwork"
PALETTES = {
    "dune": ((168, 92, 42), (36, 26, 34)),
    "interstellar": ((62, 100, 158), (12, 22, 42)),
    "spirited": ((76, 142, 102), (15, 39, 44)),
    "blade": ((154, 57, 95), (30, 16, 46)),
    "interstellar-backdrop": ((54, 89, 132), (12, 20, 36)),
}


def chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


def artwork(width: int, height: int, top: tuple[int, ...], bottom: tuple[int, ...]) -> bytes:
    pixels = bytearray()
    for y in range(height):
        pixels.append(0)
        mix = y / (height - 1)
        for x in range(width):
            glow = max(0.0, 1.0 - math.hypot(x / width - 0.65, y / height - 0.3) * 2)
            band = 12 if (x + y // 2) // 36 % 2 == 0 else 0
            for a, b in zip(top, bottom):
                pixels.append(min(255, max(0, round(a * (1 - mix) + b * mix + glow * 32 + band))))
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(pixels), level=9))
        + chunk(b"IEND", b"")
    )


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, (top, bottom) in PALETTES.items():
        size = (480, 270) if name.endswith("backdrop") else (240, 360)
        (OUTPUT / f"{name}.png").write_bytes(artwork(*size, top, bottom))
    print(f"Generated {len(PALETTES)} synthetic artwork fixtures")


if __name__ == "__main__":
    main()
