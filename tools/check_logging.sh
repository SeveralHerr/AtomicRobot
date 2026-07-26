#!/bin/bash
# Stop hook: enforces the CLAUDE.md "Logging" convention. If this branch has
# touched code/gameplay files relative to main but log.md/log-devtools.md
# haven't been updated too, emit a systemMessage reminder (non-blocking).
set -uo pipefail

base=$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null)
[ -z "$base" ] && exit 0

changed=$( { git diff --name-only "$base" HEAD 2>/dev/null; git status --porcelain --untracked-files=all 2>/dev/null | cut -c4-; } | sed '/^$/d' | sort -u)
[ -z "$changed" ] && exit 0

code_re='\.(gd|tscn|tres|cfg|import)$|(^|/)(scenes|scripts|sprites|Tiles|Sounds|addons|devtools_ext)/|^project\.godot$'
code_changed=$(printf '%s\n' "$changed" | grep -E "$code_re")
[ -z "$code_changed" ] && exit 0

missing=""
printf '%s\n' "$changed" | grep -qx "log.md" || missing="log.md"
printf '%s\n' "$changed" | grep -qx "log-devtools.md" || missing="$missing${missing:+, }log-devtools.md"
[ -z "$missing" ] && exit 0

msg="CLAUDE.md logging reminder: this branch changed code/gameplay files but has not updated: $missing. Append an entry per the CLAUDE.md Logging section."
printf '{"systemMessage":"%s"}' "$msg"
