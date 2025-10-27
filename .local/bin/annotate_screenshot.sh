#!/usr/bin/env bash
# Annotate last screenshot taken with satty.
set -eo pipefail

SCREENSHOT_FILE="$HOME/Pictures/Screenshots/$(ls -t ~/Pictures/Screenshots | head -n 1)"
echo $SCREENSHOT_FILE

/usr/bin/env satty --early-exit --copy-command wl-copy -f "$SCREENSHOT_FILE" -o "$SCREENSHOT_FILE" --initial-tool arrow --save-after-copy --actions-on-enter save-to-clipboard
