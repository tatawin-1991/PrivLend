#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

ACCOUNTS_FILE="github_accounts.csv"
if [[ ! -f "$ACCOUNTS_FILE" ]]; then
  echo "Missing $ACCOUNTS_FILE in repo root" >&2
  exit 1
fi

USERNAME="${1:-tatawin-1991}"
MESSAGE="${2:-chore: token-authenticated push}"

lookup_account() {
  local target="$1"
  while IFS=, read -r u e t; do
    [[ -z "${u:-}" || "$u" == "username" ]] && continue
    if [[ "$u" == "$target" ]]; then
      echo "$u,$e,$t"
      return 0
    fi
  done < "$ACCOUNTS_FILE"
  return 1
}

ACC_LINE="$(lookup_account "$USERNAME" || true)"
if [[ -z "$ACC_LINE" ]]; then
  echo "Account $USERNAME not found in $ACCOUNTS_FILE" >&2
  exit 1
fi

IFS=, read -r A_USER A_EMAIL A_TOKEN <<< "$ACC_LINE"

# prepare askpass helper
ASKPASS="$(pwd)/scripts/.git-askpass.sh"
if [[ ! -f "$ASKPASS" ]]; then
  cat > "$ASKPASS" <<'SH'
#!/bin/sh
case "$1" in
  *Username*) echo "$GIT_USERNAME" ;;
  *Password*) echo "$GIT_PASSWORD" ;;
  *) echo ;;
 esac
SH
  chmod +x "$ASKPASS"
fi

# minimal change so commit is created
mkdir -p docs
printf "%s\n" "- token push by $A_USER at $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> docs/CHANGELOG.md

git add -A

git config user.name "$A_USER"
git config user.email "$A_EMAIL"

# commit with current time (not rewriting history here)
if ! git commit -m "$MESSAGE" --no-gpg-sign >/dev/null 2>&1; then
  echo "No changes to commit; creating a noop marker" >&2
  echo "// noop $(date -u +%s)" >> README.md
  git add README.md
  git commit -m "$MESSAGE" --no-gpg-sign
fi

# push using token
GIT_ASKPASS="$ASKPASS" GIT_USERNAME="$A_USER" GIT_PASSWORD="$A_TOKEN" git -c credential.helper= push -u origin master
