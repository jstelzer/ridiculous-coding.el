#!/bin/bash

# ridiculous-coding.el installer
#
# A small convenience for installing from a local clone. It puts this checkout
# on your Emacs load path and prints the snippet to drop in your init file.
#
# sounds/ and images/ are resolved relative to ridiculous-coding.el itself, so
# they come along automatically -- nothing extra to copy.
#
# Prefer a package manager? You don't need this script at all. With straight.el
# / use-package:
#
#   (use-package ridiculous-coding
#     :straight (:type git :host github :repo "jstelzer/ridiculous-coding.el"
#                :files (:defaults "sounds" "images"))
#     :commands (ridiculous-coding-mode
#                global-ridiculous-coding-mode
#                ridiculous-coding-set-intensity))
#
# Usage:
#   ./install.sh           # symlink into ~/.emacs.d/lisp (default)
#   ./install.sh --copy    # copy instead of symlink
#   EMACS_DIR=~/x ./install.sh   # install under a different emacs dir

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMACS_DIR="${EMACS_DIR:-$HOME/.emacs.d}"
TARGET="$EMACS_DIR/lisp/ridiculous-coding"

MODE="symlink"
if [ "$1" = "--copy" ]; then
    MODE="copy"
fi

echo "ridiculous-coding.el installer"
echo "  from: $SCRIPT_DIR"
echo "  to:   $TARGET  ($MODE)"
echo ""

# Back up anything real already sitting at the target; clear stale symlinks.
if [ -L "$TARGET" ]; then
    rm "$TARGET"
elif [ -e "$TARGET" ]; then
    echo "Backing up existing: $TARGET -> $TARGET.backup"
    rm -rf "$TARGET.backup"
    mv "$TARGET" "$TARGET.backup"
fi

mkdir -p "$(dirname "$TARGET")"

if [ "$MODE" = "copy" ]; then
    cp -R "$SCRIPT_DIR" "$TARGET"
else
    ln -s "$SCRIPT_DIR" "$TARGET"
fi

echo "Installed."
echo ""
echo "Add to your init file (~/.emacs.d/init.el):"
echo ""
echo "  (add-to-list 'load-path \"$TARGET\")"
echo "  (require 'ridiculous-coding)"
echo ""
echo "or with use-package:"
echo ""
echo "  (use-package ridiculous-coding"
echo "    :load-path \"$TARGET\""
echo "    :commands (ridiculous-coding-mode"
echo "               global-ridiculous-coding-mode"
echo "               ridiculous-coding-set-intensity))"
echo ""
echo "Then:  M-x ridiculous-coding-mode      (this buffer)"
echo "       M-x global-ridiculous-coding-mode  (full chaos)"
