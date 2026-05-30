#!/usr/bin/env python3
"""Generate fbboot fallback MOTD from Knulli's shell welcome script.

This keeps a single human-edited source of truth:
  board/fsoverlay/etc/profile.d/30-welcome.sh

The generated file is intentionally simple because it is used inside initramfs,
where runtime helpers such as knulli-info may not be available yet.
"""
from __future__ import annotations

import argparse
import os
import re
import shlex
from pathlib import Path

DEFAULT_LOGO = [
    r" _  ___   _ _   _ _     _     ___",
    r"| |/ / \ | | | | | |   | |   |_ _|",
    r"| ' /|  \| | | | | |   | |    | |",
    r"| . \| |\  | |_| | |___| |___ | |",
    r"|_|\_\_| \_|\___/|_____|_____|___|",
]

ASCII_HINT = re.compile(r"[_|\\/]{2,}|___|\bKNULLI\b", re.I)


def _read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return ""


def extract_heredoc_blocks(text: str) -> list[list[str]]:
    lines = text.splitlines()
    blocks: list[list[str]] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.search(r"<<-?\s*['\"]?([A-Za-z0-9_]+)['\"]?", line)
        if not m:
            i += 1
            continue
        delim = m.group(1)
        block: list[str] = []
        i += 1
        while i < len(lines) and lines[i].strip() != delim:
            block.append(lines[i])
            i += 1
        blocks.append(block)
        i += 1
    return blocks


def extract_echo_logo(text: str) -> list[str]:
    out: list[str] = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line.startswith("echo"):
            if out and ("knulli-info" in line or "Model:" in line or "OS version" in line):
                break
            continue
        rest = line[4:].strip()
        if not rest:
            if out:
                break
            continue
        try:
            parts = shlex.split(rest)
            value = " ".join(parts)
        except Exception:
            value = rest.strip('"\'')
        if ASCII_HINT.search(value):
            out.append(value)
        elif out:
            break
    return out


def extract_logo(text: str, max_lines: int) -> list[str]:
    candidates: list[list[str]] = []
    for block in extract_heredoc_blocks(text):
        compact = [ln.rstrip("\n") for ln in block]
        if any(ASCII_HINT.search(ln) for ln in compact):
            candidates.append(compact)
    echo_logo = extract_echo_logo(text)
    if echo_logo:
        candidates.append(echo_logo)
    if not candidates:
        return DEFAULT_LOGO[:max_lines]

    # Prefer the first plausible compact ASCII logo block, but drop leading/trailing blanks.
    logo = candidates[0]
    while logo and not logo[0].strip():
        logo.pop(0)
    while logo and not logo[-1].strip():
        logo.pop()
    return logo[:max_lines] if logo else DEFAULT_LOGO[:max_lines]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--welcome", required=True, help="Path to 30-welcome.sh")
    ap.add_argument("--output", required=True, help="Output MOTD path")
    ap.add_argument("--max-logo-lines", type=int, default=9)
    ap.add_argument("--model", default=os.environ.get("KNULLI_BOOT_MOTD_MODEL", "KNULLI"))
    ap.add_argument("--build", default=os.environ.get("KNULLI_BOOT_MOTD_BUILD", "INITIALIZING"))
    args = ap.parse_args()

    text = _read(Path(args.welcome))
    logo = extract_logo(text, args.max_logo_lines)
    model = (args.model or "KNULLI").strip()
    build = (args.build or "INITIALIZING").strip()

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    content = "\n".join(logo) + "\n\n" + f"MODEL: {model}\nBUILD: {build}\n"
    out.write_text(content, encoding="utf-8")
    print(f"Generated boot MOTD from {args.welcome} -> {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
