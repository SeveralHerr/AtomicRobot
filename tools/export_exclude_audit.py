"""Keep unreferenced art/audio out of the web pck, and never exclude a used one.

The browser holds the whole index.pck in RAM (the Pi cabinet has ~400 MB for the tab),
so assets nothing loads are dropped through the Web/Picade presets' exclude_filter.
The list is DERIVED here, not hand-kept, and checked in both directions:

  * every unreferenced asset is matched by an exclude pattern (nothing wasted ships);
  * every exclude pattern matches at least one file and no referenced one (a later
    change that starts using an excluded file fails here instead of shipping a broken
    preload - boss.wav once was excluded while audio_manager.gd preloaded it, which
    killed the AudioManager autoload in the web build).

"Referenced" is deliberately loose: the asset's res:// path, its uid://, or its bare
file name appears in any .tscn/.tres/.gd/.gdshader/.cfg/project.godot, tests included.
That covers runtime-built loads too, since every load() path in the game is a string
literal somewhere (interactive_mailbox PHOTOS, jamcraft_splash DEFAULT_LOGO_PATH).

    python tools/export_exclude_audit.py           # exit 1 on any drift
    python tools/export_exclude_audit.py --write   # rewrite both presets' exclude_filter
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PRESETS = os.path.join(ROOT, "export_presets.cfg")
AUDITED_PRESETS = ("Web", "Picade")
# Hand-kept, non-asset excludes: the autoplay bot and the test tree.
KEEP_PATTERNS = ("tools/autoplay/*", "test/*")
ASSET_EXT = (".png", ".jpg", ".jpeg", ".webp", ".svg", ".wav", ".ogg", ".mp3", ".ttf", ".otf")
SOURCE_EXT = (".tscn", ".tres", ".gd", ".gdshader", ".cfg", ".godot")
# Only game-asset folders are candidates; these never hold shipped art we prune here.
NOT_CANDIDATE_DIRS = ("test", "tools", "skills", "docs", "addons")
SKIP_DIRS = {".git", ".godot", "bin", "autoplay_out", "__pycache__"}


def _walk():
    for d, dirs, files in os.walk(ROOT):
        dirs[:] = [x for x in dirs if x not in SKIP_DIRS
                   and not os.path.exists(os.path.join(d, x, ".gdignore"))]
        for f in files:
            yield os.path.relpath(os.path.join(d, f), ROOT).replace(os.sep, "/")


def _read(rel: str) -> str:
    with open(os.path.join(ROOT, rel), encoding="utf-8", errors="replace") as f:
        return f.read()


def _uid(rel: str) -> str:
    imp = os.path.join(ROOT, rel + ".import")
    if not os.path.exists(imp):
        return ""
    m = re.search(r'^uid="(uid://[^"]+)"', _read(rel + ".import"), re.M)
    return m.group(1) if m else ""


def scan() -> tuple[list[str], list[str], list[str]]:
    """(all project files, referenced assets, unreferenced assets)."""
    files = list(_walk())
    corpus = "\n".join(_read(f) for f in files
                       if f.endswith(SOURCE_EXT) and f != "export_presets.cfg")
    low = corpus.lower()
    used, unused = [], []
    for f in files:
        if not f.lower().endswith(ASSET_EXT) or f.split("/")[0] in NOT_CANDIDATE_DIRS:
            continue
        uid = _uid(f)
        hit = os.path.basename(f).lower() in low or (uid and uid in corpus)
        (used if hit else unused).append(f)
    return files, sorted(used), sorted(unused)


def pattern_for(rel: str) -> str:
    """exclude_filter is split on ',' and edge-stripped; Godot's matchn knows * and ?."""
    return re.sub(r"[,\[\]]", "?", rel)


def matchn(pattern: str, rel: str) -> bool:
    rx = "".join(".*" if c == "*" else "." if c == "?" else re.escape(c) for c in pattern)
    return re.fullmatch(rx, rel, re.I | re.S) is not None


def read_filters() -> dict[str, list[str]]:
    out, name = {}, None
    for line in _read("export_presets.cfg").splitlines():
        if line.startswith("name="):
            name = line[5:].strip('"')
        elif line.startswith("exclude_filter=") and name in AUDITED_PRESETS:
            raw = line[len("exclude_filter="):].strip('"')
            out[name] = [p.strip() for p in raw.split(",") if p.strip()]
    return out


def write_filters(patterns: list[str]) -> None:
    value = ", ".join(list(KEEP_PATTERNS) + patterns)
    lines, name = _read("export_presets.cfg").splitlines(keepends=True), None
    for i, line in enumerate(lines):
        if line.startswith("name="):
            name = line[5:].strip().strip('"')
        elif line.startswith("exclude_filter=") and name in AUDITED_PRESETS:
            lines[i] = f'exclude_filter="{value}"\n'
    with open(PRESETS, "w", encoding="utf-8", newline="") as f:
        f.write("".join(lines))


def audit(files: list[str], used: list[str], unused: list[str],
          filters: dict[str, list[str]]) -> list[str]:
    errors = [f"preset {p!r} missing from export_presets.cfg"
              for p in AUDITED_PRESETS if p not in filters]
    if len({tuple(v) for v in filters.values()}) > 1:
        errors.append("Web and Picade exclude_filter differ")
    for preset, pats in filters.items():
        for keep in KEEP_PATTERNS:
            if keep not in pats:
                errors.append(f"{preset}: lost the {keep!r} exclude")
        asset_pats = [p for p in pats if p not in KEEP_PATTERNS]
        for p in asset_pats:
            hits = [f for f in files if matchn(p, f)]
            if not hits:
                errors.append(f"{preset}: stale pattern {p!r} matches nothing")
            for f in hits:
                if f in used:
                    errors.append(f"{preset}: {p!r} excludes REFERENCED {f}")
                elif f not in unused:
                    errors.append(f"{preset}: {p!r} excludes non-asset {f}")
        for f in unused:
            if not any(matchn(p, f) for p in asset_pats):
                errors.append(f"{preset}: unreferenced {f} still ships")
    return errors


def main() -> int:
    files, used, unused = scan()
    if "--write" in sys.argv:
        write_filters([pattern_for(f) for f in unused])
    mb = sum(os.path.getsize(os.path.join(ROOT, f)) for f in unused) / 1e6
    print(f"assets: {len(used)} referenced, {len(unused)} unreferenced ({mb:.1f} MB source)")
    errors = audit(files, used, unused, read_filters())
    for e in errors:
        print("FAIL", e)
    print("OK: exclude_filter matches the unreferenced assets exactly" if not errors
          else f"{len(errors)} problem(s); fix the reference or run with --write")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
