#!/bin/zsh
# Packs the browser extension for the Chrome Web Store: the Chromium manifest without the local "key"
# (the store assigns the public ID), no Firefox or Safari manifests. Usage: chrome-web-store.sh <out-dir>
set -eu
OUT="${1:?output directory}"; mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd); cd "$(dirname "$0")/../.."
VERSION=$(python3 -c "import json;print(json.load(open('Browser Extension/manifest.json'))['version'])")
STAGE=$(mktemp -d /tmp/lesspull-cws.XXXXXX)
ditto --norsrc "Browser Extension" "$STAGE/ext"
rm -f "$STAGE/ext/manifest.firefox.json" "$STAGE/ext/manifest.safari.json"
python3 - "$STAGE/ext/manifest.json" <<'PY'
import json,sys
p=sys.argv[1]; m=json.load(open(p)); m.pop('key',None)
m['homepage_url']='https://github.com/Archangeloi89/less-pull'
json.dump(m,open(p,'w'),indent=2,ensure_ascii=False); open(p,'a').write('\n')
PY
ZIP="$OUT/Less-Pull-Chrome-Web-Store-$VERSION.zip"; rm -f "$ZIP"
(cd "$STAGE/ext" && zip -q -X -r "$ZIP" . -x '.*' -x '__MACOSX')
rm -rf "$STAGE"; echo "$ZIP"; unzip -l "$ZIP" | tail -n +4 | awk '{print "  " $4}' | sed '/^  $/d' | head -12
