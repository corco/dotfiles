#!/bin/sh
# Make Chromium the default browser for links and HTML files.
# chezmoi runs this on apply, and again only if this file changes.
# It edits only these entries in ~/.config/mimeapps.list; other defaults are kept.
if ! command -v xdg-mime >/dev/null; then
    echo "xdg-mime not found (install xdg-utils); default browser not set" >&2
    exit 0
fi
if [ ! -f /usr/share/applications/chromium.desktop ]; then
    echo "chromium is not installed; default browser not set" >&2
    exit 0
fi
xdg-mime default chromium.desktop \
    x-scheme-handler/http x-scheme-handler/https \
    text/html application/xhtml+xml
