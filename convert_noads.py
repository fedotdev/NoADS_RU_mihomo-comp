#!/usr/bin/env python3
"""Конвертер NoADS_RU -> доменный список Mihomo (behavior: domain, format: text).

  hosts   : строки "0.0.0.0 domain" (hosts/blocker.txt, hosts/blockerFL.txt) -> точные имена
  adblock : только чистые правила "||domain^" из браузерного фильтра -> "+.domain"
            (косметика ##, правила с $-опциями, пути, @@-исключения пропускаются)
"""
import argparse, ipaddress, re, sys, urllib.request
from datetime import datetime, timezone

LABEL = r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?"
DOMAIN = re.compile(rf"^(?:{LABEL}\.)+{LABEL}$")
BAD_TLD = {"localhost", "local", "lan", "invalid", "test", "example"}
ADB = re.compile(r"^\|\|([^/\s^$*|]+)\^$")


def ok(d):
    if len(d) > 253 or not DOMAIN.match(d) or d.rsplit(".", 1)[-1] in BAD_TLD:
        return False
    try:
        ipaddress.ip_address(d)
        return False
    except ValueError:
        return True


def read(src):
    if src.startswith(("http://", "https://")):
        with urllib.request.urlopen(src, timeout=120) as r:
            return r.read().decode("utf-8", "replace")
    return open(src, encoding="utf-8", errors="replace").read()


def convert(text, mode):
    out = set()
    for line in text.splitlines():
        line = line.strip()
        if mode == "hosts":
            parts = line.split("#", 1)[0].split()
            if len(parts) < 2 or parts[0] not in ("0.0.0.0", "127.0.0.1", "::", "::1"):
                continue
            for raw in parts[1:]:
                d = raw.lower().rstrip(".")
                if ok(d):
                    out.add(d)
        else:
            m = ADB.match(line)
            if m:
                d = m.group(1).lower().rstrip(".")
                if ok(d):
                    out.add("+." + d)
    return sorted(out)


def main():
    a = argparse.ArgumentParser()
    a.add_argument("--mode", choices=["hosts", "adblock"], required=True)
    a.add_argument("--src", required=True)
    a.add_argument("--out", required=True)
    a.add_argument("--min", type=int, default=1000, help="защита от пустого/битого источника")
    a = a.parse_args()
    items = convert(read(a.src), a.mode)
    if len(items) < a.min:
        sys.exit(f"Слишком мало записей ({len(items)}); файл не перезаписан")
    head = ["# Mihomo domain list, mode=" + a.mode, "# Source: " + a.src]
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(head + items) + "\n")
    print(f"{len(items)} записей -> {a.out}")


if __name__ == "__main__":
    main()
