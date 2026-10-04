class_name ReadingTime
extends RefCounted

## How long a pop-up with text to READ stays on screen: the one rule every such
## pop-up uses (newspaper card, boss speech bubble, STREET CLEAR!, chat bubbles,
## unlock toasts), so they agree and can be tuned in one place.
##
## Not for pure-juice slams (hit words, WAVE n/N, phase titles): those are glanced,
## not read, and their holds are timed against gameplay (a wave's walk-out, a boss
## stagger), so stretching them would change the fight.
##
## Player report: "pop-up messages need to stay on screen a moment longer". The old
## holds were 0.9-4 s flat, whatever the length of the text.

## Time to notice a pop-up and start reading it.
const BASE := 1.5
## Per character: ~16 characters a second, a relaxed pace for a game in motion.
const PER_CHAR := 0.06
## Even a two-word line stays this long.
const MIN := 3.0
## ...and the longest never parks on screen for longer than this.
const MAX := 9.0


## Seconds `text` should stay readable on screen (whitespace at the ends ignored).
static func seconds(text: String) -> float:
	return clampf(BASE + text.strip_edges().length() * PER_CHAR, MIN, MAX)
