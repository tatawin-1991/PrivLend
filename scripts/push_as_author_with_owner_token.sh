#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

ACCOUNTS_FILE="github_accounts.csv"
if [[ ! -f "$ACCOUNTS_FILE" ]]; then
  echo "Missing $ACCOUNTS_FILE in repo root" >&2
  exit 1
fi

AUTHOR_USER="${1:?usage: $0 <author-username> [commit-message]}"
MESSAGE="${2:-chore: owner-auth push on behalf of $AUTHOR_USER}"
OWNER_USER="tatawin-1991"

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

# 作者信息
ACC_AUTHOR="$(lookup_account "$AUTHOR_USER" || true)"
if [[ -z "$ACC_AUTHOR" ]]; then
  echo "Author $AUTHOR_USER not found in $ACCOUNTS_FILE" >&2
  exit 1
fi
IFS=, read -r A_USER A_EMAIL _ <<< "$ACC_AUTHOR"

# 所有者 token
ACC_OWNER="$(lookup_account "$OWNER_USER" || true)"
if [[ -z "$ACC_OWNER" ]]; then
  echo "Owner $OWNER_USER not found in $ACCOUNTS_FILE" >&2
  exit 1
fi
IFS=, read -r _ OWNER_EMAIL OWNER_TOKEN <<< "$ACC_OWNER"

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

# 最小变更
mkdir -p docs
printf "%s\n" "- owner-auth push for $A_USER at $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> docs/CHANGELOG.md

git add -A

git config user.name "$A_USER"
git config user.email "$A_EMAIL"

if ! git commit -m "$MESSAGE" --no-gpg-sign >/dev/null 2>&1; then
  echo "No changes to commit; creating marker" >&2
  echo "// marker $(date -u +%s) for $A_USER" >> README.md
  git add README.md
  git commit -m "$MESSAGE" --no-gpg-sign
fi

# 使用所有者 token 推送
GIT_ASKPASS="$ASKPASS" GIT_USERNAME="$OWNER_USER" GIT_PASSWORD="$OWNER_TOKEN" git -c credential.helper= push -u origin master
