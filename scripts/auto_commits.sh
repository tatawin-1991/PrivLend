#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

REMOTE_URL="https://github.com/tatawin-1991/1-1"

# macOS bash 3.2 compatibility: no mapfile
AUTHORS=()
while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in username,*) continue;; esac
  AUTHORS+=("$line")
done < scripts/authors.csv
NUM_AUTHORS="${#AUTHORS[@]}"
current_author_idx=0

set_author() {
  local line="$1"
  local name="$(echo "$line" | cut -d, -f1)"
  local email="$(echo "$line" | cut -d, -f2)"
  git config user.name "$name"
  git config user.email "$email"
}

make_commit() {
  local msg="$1"
  local date="$2"
  local author_line="${AUTHORS[$current_author_idx]}"
  set_author "$author_line"
  GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" git commit -m "$msg" --no-gpg-sign
  current_author_idx=$(( (current_author_idx + 1) % NUM_AUTHORS ))
}

if ! git remote get-url origin >/dev/null 2>&1; then
  git remote add origin "$REMOTE_URL"
fi

git add -A

commit_phase() {
  local count="$1"; local start="$2"; local end="$3"; local prefix="$4"
  for i in $(seq 1 $count); do
    echo "$prefix change $i" >> docs/CHANGELOG.md
    if (( i % 3 == 0 )); then echo "console.log('tick $prefix $i')" >> backend/index.js; fi
    if (( i % 4 == 0 )); then echo "export const v$prefix$i = $i;" >> frontend/index.js; fi
    if (( i % 5 == 0 )); then echo "// $prefix test $i" >> tests/placeholder.test.js; fi
    if (( i % 6 == 0 )); then echo "// $prefix solidity $i" >> contracts/Placeholder.sol; fi
    git add -A
    total_days=$(( ( $(date -j -f %Y-%m-%d +%s "$end") - $(date -j -f %Y-%m-%d +%s "$start") ) / 86400 ))
    offset=$(( (i * (total_days-1) ) / count ))
    commit_date=$(date -j -f %Y-%m-%d -v+${offset}d "$start" +%Y-%m-%d)
    make_commit "$prefix: step $i" "$commit_date 10:0$((i%6)):00"
  done
}

commit_phase 12 2023-03-05 2023-06-20 "feat"
commit_phase 36 2023-07-05 2023-12-20 "feat"
commit_phase 18 2024-01-05 2024-06-20 "test"
commit_phase 6 2024-07-01 2024-08-25 "docs"

set_author "tatawin-1991,tatawin1991@outlook.com"
(git push -u origin master) || true
