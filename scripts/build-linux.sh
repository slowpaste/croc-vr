#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
command -v python3 >/dev/null || { echo 'Install Python 3.10 or newer.' >&2; exit 1; }
if [[ $# -eq 0 ]]; then
  read -r -p 'Croc PlayStation disc image (.bin or .iso): ' disc
  read -r -p 'Headset (frame / quest / both) [both]: ' target
  exec python3 "$root/croc_builder.py" build --iso "$disc" --target "${target:-both}"
fi
exec python3 "$root/croc_builder.py" build "$@"
