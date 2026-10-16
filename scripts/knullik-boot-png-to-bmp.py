#!/usr/bin/env python3
"""Convert the bundled KNULLIK 8-bit RGB/RGBA PNG to an initramfs-safe BMP.

Runs on the build host with Python's standard library only. Existing user
images are decoded by the full rootfs FFmpeg helper, not by this generator.
"""
import argparse
import struct
import zlib
from pathlib import Path


def convert(png_path: Path, bmp_path: Path) -> None:
    raw = png_path.read_bytes()
    if len(raw) < 67 or len(raw) > 20 * 1024 * 1024:
        raise ValueError("Bundled PNG must be between 67 bytes and 20 MiB")
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Invalid PNG signature")

    cursor = 8
    ihdr = None
    data = bytearray()
    seen_end = False
    while cursor < len(raw):
        if cursor + 12 > len(raw):
            raise ValueError("Truncated PNG chunk header")
        size = struct.unpack_from(">I", raw, cursor)[0]
        name = raw[cursor + 4: cursor + 8]
        end = cursor + 12 + size
        if end > len(raw):
            raise ValueError("Truncated PNG chunk")
        payload = raw[cursor + 8: cursor + 8 + size]
        expected_crc = struct.unpack_from(">I", raw, cursor + 8 + size)[0]
        if zlib.crc32(name + payload) & 0xFFFFFFFF != expected_crc:
            raise ValueError("PNG CRC mismatch for " + repr(name))
        if name == b"IHDR":
            if ihdr is not None or cursor != 8 or size != 13:
                raise ValueError("Invalid PNG IHDR")
            ihdr = struct.unpack(">IIBBBBB", payload)
        elif name == b"IDAT":
            data.extend(payload)
        elif name == b"IEND":
            if size != 0:
                raise ValueError("Invalid PNG IEND")
            seen_end = True
            if end != len(raw):
                raise ValueError("Trailing PNG data")
            break
        elif (name[0] & 0x20) == 0:
            # Critical chunks must be understood, to avoid broken rendering.
            raise ValueError("Unsupported PNG critical chunk: " + repr(name))
        cursor = end

    if not seen_end or ihdr is None or not data:
        raise ValueError("Incomplete PNG")
    width, height, depth, color, compression, filtering, interlace = ihdr
    if not 0 < width <= 4096 or not 0 < height <= 4096:
        raise ValueError("Invalid source dimensions")
    if depth != 8 or color not in (2, 6) or (compression, filtering, interlace) != (0, 0, 0):
        raise ValueError("The built-in image must be non-interlaced 8-bit RGB/RGBA")
    channels = 3 if color == 2 else 4
    row_bytes = width * channels
    expected_bytes = height * (row_bytes + 1)
    stream = zlib.decompressobj()
    decoded = stream.decompress(bytes(data), expected_bytes + 1)
    decoded += stream.flush()
    if not stream.eof or stream.unused_data or stream.unconsumed_tail or len(decoded) != expected_bytes:
        raise ValueError("Invalid or oversized decompressed PNG pixels")

    rows = []
    previous = bytearray(row_bytes)
    pos = 0
    for _ in range(height):
        filter_type = decoded[pos]
        row = bytearray(decoded[pos + 1:pos + 1 + row_bytes])
        pos += 1 + row_bytes
        if filter_type not in range(5):
            raise ValueError("Unsupported PNG scanline filter")
        for i in range(row_bytes):
            a = row[i - channels] if i >= channels else 0
            b = previous[i]
            c = previous[i - channels] if i >= channels else 0
            if filter_type == 1:
                predictor = a
            elif filter_type == 2:
                predictor = b
            elif filter_type == 3:
                predictor = (a + b) // 2
            elif filter_type == 4:
                p = a + b - c
                da, db, dc = abs(p - a), abs(p - b), abs(p - c)
                predictor = a if da <= db and da <= dc else (b if db <= dc else c)
            else:
                predictor = 0
            row[i] = (row[i] + predictor) & 255

        bgr = bytearray()
        for x in range(width):
            start = x * channels
            r, g, b = row[start:start + 3]
            if channels == 4:
                alpha = row[start + 3]
                r, g, b = ((v * alpha + 127) // 255 for v in (r, g, b))
            bgr.extend((b, g, r))
        bgr.extend(b"\x00" * (-(width * 3) % 4))
        rows.append(bgr)
        previous = row

    image_data = b"".join(reversed(rows))
    file_size = 54 + len(image_data)
    if file_size > 12 * 1024 * 1024:
        raise ValueError("Generated default BMP exceeds renderer maximum")
    header = struct.pack("<2sIHHI", b"BM", file_size, 0, 0, 54)
    dib = struct.pack("<IiiHHIIiiII", 40, width, height, 1, 24, 0,
                      len(image_data), 2835, 2835, 0, 0)
    bmp_path.parent.mkdir(parents=True, exist_ok=True)
    bmp_path.write_bytes(header + dib + image_data)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    convert(args.input, args.output)
    print(f"Bundled boot BMP: {args.output} ({args.output.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
