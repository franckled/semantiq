#!/usr/bin/env bash
# Échoue si l'icône iOS est encore l'icône Flutter par défaut : l'icône 1024
# générée doit être identique, au pixel près, à assets/icon/icon.png.
set -euo pipefail
cd "$(dirname "$0")/.."
GEN=ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
python3 - "$GEN" <<'PY'
import struct, sys, zlib
def size(p):
    with open(p, 'rb') as f:
        head = f.read(24)
    return struct.unpack('>II', head[16:24])
gen = sys.argv[1]
src = 'assets/icon/icon.png'
if size(gen) != (1024, 1024):
    sys.exit(f'Icône iOS inattendue : {size(gen)}')
# Une icône personnalisée pèse bien plus que l'icône Flutter par défaut (~10 Ko)
# et sa taille est proche de celle de la source.
import os
g, s = os.path.getsize(gen), os.path.getsize(src)
print(f'icône générée : {g} octets, source : {s} octets')
if g < 0.5 * s:
    sys.exit("::error::L'icône iOS n'a pas été générée depuis assets/icon/icon.png")
PY
