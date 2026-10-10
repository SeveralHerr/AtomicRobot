"""Per-platform captions for one reel.
python captions.py "<one sentence>" "<alt text>" [out=captions.json] [--title="<YouTube title>"]
Prints each platform's text + length check; exits 1 if any limit is blown."""
import json, sys

ITCH = "https://severalherr.itch.io/atomic-robot"
IG_URL = "https://www.instagram.com/atomicrobottattoo/"
IG = "@atomicrobottattoo"
TAGS = {
    "youtube": "#Shorts #indiegame #beatemup",
    "bluesky": "#indiegame #gamedev #pixelart",
    "tiktok": "#indiegame #gamedev #beatemup #pixelart #retrogaming",
    "instagram": "#indiegame #gamedev #pixelart #beatemup #retrogaming #siouxfalls",
}
LIMITS = {"youtube_title": 100, "youtube": 5000, "bluesky": 300, "tiktok": 2200, "instagram": 2200}


def build(sentence, alt, title=None):
    s = sentence.strip()
    if s.count(". ") or s.count("! ") or s.count("? "):
        raise SystemExit("one sentence only: " + s)
    # A long sentence used to fall back to a generic title; pass --title for a hook instead.
    title = f"{(title or s).rstrip('.!')} #Shorts"
    if len(title) > LIMITS["youtube_title"]:
        title = "Atomic Robot - arcade beat-em-up #Shorts"
    return {
        # YouTube: links clickable in the description; first 3 hashtags show above the title.
        "youtube_title": title,
        "youtube": f"{s}\n\nPlay free: {ITCH}\nInstagram: {IG_URL}\n\n{TAGS['youtube']}",
        # Bluesky: 300-char cap, links auto-link; alt text goes in the video's ALT field.
        "bluesky": f"{s}\n\nPlay free: {ITCH}\nIG: {IG}\n\n{TAGS['bluesky']}",
        "bluesky_alt": alt,
        # TikTok / Instagram: caption links are NOT clickable — write them as plain text.
        "tiktok": f"{s} Play free on itch.io: severalherr.itch.io/atomic-robot | IG {IG} {TAGS['tiktok']}",
        "instagram": f"{s}\n\nPlay free on itch.io: severalherr.itch.io/atomic-robot\nIG {IG}\n\n{TAGS['instagram']}",
    }


def main():
    title = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--title=")), None)
    args = [a for a in sys.argv[1:] if not a.startswith("--title=")]
    if len(args) < 2:
        raise SystemExit(__doc__)
    caps = build(args[0], args[1], title)
    bad = 0
    for k, v in caps.items():
        lim = LIMITS.get(k)
        ok = lim is None or len(v) <= lim
        bad += not ok
        print(f"--- {k} ({len(v)}{'/' + str(lim) if lim else ''}){'' if ok else '  OVER LIMIT'}\n{v}")
    out = args[2] if len(args) > 2 else "captions.json"
    with open(out, "w", encoding="utf-8") as f:
        json.dump(caps, f, indent=2, ensure_ascii=False)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
