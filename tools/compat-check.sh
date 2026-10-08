#!/bin/zsh
# Lists what a fork of Less Pull changed since a release, by compatibility tier (see docs/compat.json).
# Usage: compat-check.sh <fork-dir> <base-ref, e.g. v1.4.4-33>
set -eu
FORK="${1:?fork directory}"; BASE="${2:?base ref or tag}"
cd "$FORK"
git rev-parse --verify "$BASE" >/dev/null 2>&1 || { echo "Base '$BASE' is not known here. Fetch the upstream tags first: git fetch https://github.com/Archangeloi89/less-pull --tags"; exit 2; }
changed=$( (git diff --name-only "$BASE"; git ls-files --others --exclude-standard) | sort -u)
[ -z "$changed" ] && { echo "No changes since $BASE. Fully compatible."; exit 0; }
t2=(); t3=()
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in
    Source/Sounds/*|Source/MenuBar/*|docs/*|tools/*|README.md) t2+=("$f");;
    *) t3+=("$f");;
  esac
done <<< "$changed"
echo "Changes since $BASE"
if (( ${#t2[@]} )); then echo; echo "In the compatible range (tier 2): updates do not rewrite these."; for f in "${t2[@]}"; do echo "  ok   $f"; done; fi
if (( ${#t3[@]} )); then echo; echo "Outside the compatible range (tier 3): a future update may conflict here."; for f in "${t3[@]}"; do echo "  !!   $f"; done; echo; echo "Each file marked !! leaves the compatible range. Keeping it means merging it by hand after updates, or staying on this build. That is a conscious choice; say so to whoever owns this copy."; exit 1; fi
echo; echo "Everything is in the compatible range."
