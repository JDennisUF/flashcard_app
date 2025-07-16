#!/usr/bin/env bash
set -e
sed -i 's|<base href=\"/\">|<base href=\"/flashcards/\">|' build/web/index.html
