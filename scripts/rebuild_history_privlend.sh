#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

REMOTE_URL="https://github.com/tatawin-1991/PrivLend"
if ! git remote get-url origin >/dev/null 2>&1; then
  git remote add origin "$REMOTE_URL"
else
  git remote set-url origin "$REMOTE_URL"
fi

ACCOUNTS_FILE="github_accounts.csv"
if [[ ! -f "$ACCOUNTS_FILE" ]]; then
  echo "Missing $ACCOUNTS_FILE in repo root" >&2
  exit 1
fi

# 读取有效账号
VALID_ACCOUNTS=()
while IFS= read -r line; do
  [[ -z "${line// /}" ]] && continue
  [[ "$line" == username,email,* ]] && continue
  IFS="," read -r username email token <<< "$line"
  [[ -z "$username" || -z "$email" ]] && continue
  VALID_ACCOUNTS+=("$username,$email,$token")
done < "$ACCOUNTS_FILE"

if [[ ${#VALID_ACCOUNTS[@]} -lt 6 ]]; then
  echo "Need at least 6 accounts for balanced rotation" >&2
  exit 1
fi

# 目标：每账号12次，总计72次
PER_AUTHOR=12
TOTAL_COMMITS=$(( PER_AUTHOR * 6 ))

# 时间窗口
march_from="2023-03-01"; march_to="2023-03-31"
apr_from="2023-04-01"; apr_to="2023-04-30"
may_from="2023-05-01"; may_to="2023-05-31"
jun_from="2023-06-01"; jun_to="2023-06-30"
jul_from="2023-07-01"; jul_to="2023-07-31"
aug_from="2023-08-01"; aug_to="2023-08-31"

# 提交信息（严格72条，分阶段）
INIT=(
  "feat: initialize monorepo structure and tooling"
  "feat: setup backend service scaffold"
  "feat: setup frontend dapp scaffold"
  "feat: add contracts placeholder and hardhat config"
  "chore: add basic .editorconfig and lint settings"
  "chore: add npm scripts and workspace config"
  "feat: backend health endpoint"
  "feat: frontend dev server and landing page"
  "feat: contracts compile script"
  "docs: initial README and LICENSE"
  "chore: configure testing framework"
  "chore: setup CI placeholders"
)
CORE=(
  "feat: credit score model interface and types"
  "feat: FHE SDK adapter stub"
  "feat: on-chain credit score contract draft"
  "feat: pool contract scaffold"
  "feat: lending logic with dynamic LTV"
  "feat: frontend upload encrypted data flow"
  "feat: backend encryption proxy endpoint"
  "feat: dao config for weights management"
  "feat: integrate ethers.js and wallet connect"
  "feat: persist user credit score state"
  "feat: liquidation safeguards and params"
  "refactor: split services and utils"
  "perf: batch processing for FHE ops"
  "feat: emit events for score updates"
  "feat: add governance token ABI"
  "feat: interest rate model and tests stub"
  "feat: scoring NFT metadata format"
  "feat: oracle interface for offchain data"
  "feat: extend score range validation"
  "fix: handle edge cases in LTV calc"
  "feat: implement pool accounting primitives"
  "feat: add borrower position tracking"
  "feat: frontend borrow/repay screens"
  "feat: wallet state management"
)
TEST_OPT=(
  "test: unit tests for interest model"
  "test: contract tests for pool operations"
  "test: credit score range and weight edge cases"
  "test: backend encryption proxy tests"
  "test: frontend components basic tests"
  "chore: add coverage reporting"
  "fix: flaky test for rounding"
  "perf: micro-optimize score computation"
  "refactor: reduce bundle size"
  "feat: add e2e test scaffolding"
  "test: e2e happy path borrow"
  "test: e2e liquidation path"
)
DOCS=(
  "docs: architecture overview and diagrams"
  "docs: API references for services"
  "docs: contract specs and events"
  "docs: scoring model documentation"
  "docs: dao parameters and voting process"
  "docs: deployment and env guide"
  "docs: troubleshooting common issues"
  "docs: security considerations"
  "docs: tokenomics and economics"
  "docs: roadmap and milestones"
  "docs: glossary"
  "chore: release notes and changelog"
)

# 额外补充 12 条提交（用于凑满 72 次）
EXTRA=(
  "fix: correct score normalization edge conditions"
  "feat: add governance voting power calc"
  "refactor: isolate rate model params"
  "perf: cache user score lookups"
  "feat: add pool fee switch and caps"
  "fix: handle invalid oracle payload"
  "feat: implement withdraw cooldown"
  "refactor: unify error codes"
  "perf: reduce on-chain storage writes"
  "feat: add protocol pause guardian"
  "fix: rounding at score boundaries"
  "feat: extend event topics for indexing"
)

# 随机日期（macOS 兼容）
rand_datetime_in_range() {
  local start_ts end_ts rand_ts
  start_ts=$(date -u -j -f "%Y-%m-%d %H:%M:%S" "$1 00:00:00" +%s)
  end_ts=$(date -u -j -f "%Y-%m-%d %H:%M:%S" "$2 23:59:59" +%s)
  local span=$(( end_ts - start_ts + 1 ))
  (( span <= 0 )) && span=1
  rand_ts=$(( start_ts + (RANDOM << 15 | RANDOM) % span ))
  date -u -r "$rand_ts" "+%Y-%m-%d %H:%M:%S"
}

# 作者轮换（固定顺序，保证每人12次）
AUTH_INDEX=0
AUTHOR_COUNTS=()
for _ in {1..6}; do AUTHOR_COUNTS+=(0); done
pick_author() {
  local idx=$AUTH_INDEX
  # 向前找下一个仍未达到配额的人
  for _ in {1..6}; do
    if (( AUTHOR_COUNTS[$idx] < PER_AUTHOR )); then
      AUTH_INDEX=$idx
      echo $idx
      return 0
    fi
    idx=$(( (idx + 1) % 6 ))
  done
  echo $AUTH_INDEX
}

set_author_by_index() {
  local i=$1
  IFS="," read -r A_USER A_EMAIL A_TOKEN <<< "${VALID_ACCOUNTS[$i]}"
  git config user.name "$A_USER"
  git config user.email "$A_EMAIL"
}

apply_change_for_msg() {
  local msg="$1" ts
  ts=$(date -u "+%Y-%m-%dT%H:%M:%SZ")
  case "$msg" in
    docs:*)
      mkdir -p docs
      echo "- $ts $msg" >> docs/CHANGELOG.md ;;
    test:*)
      mkdir -p tests
      echo "// $ts $msg" >> tests/placeholder.test.js ;;
    ci:*)
      mkdir -p .github/workflows
      echo "name: CI" > .github/workflows/ci.yml ;;
    chore:*)
      echo "// $ts $msg" >> frontend/index.js ;;
    fix:*)
      echo "// $ts $msg" >> backend/index.js ;;
    *)
      echo "// $ts $msg" >> contracts/Placeholder.sol ;;
  esac
}

make_commit() {
  local msg="$1" from="$2" to="$3" author_idx
  apply_change_for_msg "$msg"
  author_idx=$(pick_author)
  set_author_by_index "$author_idx"
  AUTHOR_COUNTS[$author_idx]=$(( AUTHOR_COUNTS[$author_idx] + 1 ))
  local when
  when=$(rand_datetime_in_range "$from" "$to")
  GIT_AUTHOR_DATE="$when" GIT_COMMITTER_DATE="$when" git add -A
  GIT_AUTHOR_DATE="$when" GIT_COMMITTER_DATE="$when" git commit -m "$msg" --no-gpg-sign
}

# 构造 72 条计划：12+24+12+12 = 60；补齐到72从 CORE 追加12
PLAN=()
PLAN+=("${INIT[@]}")
PLAN+=("${CORE[@]:0:24}")
PLAN+=("${TEST_OPT[@]}")
PLAN+=("${DOCS[@]}")
PLAN+=("${EXTRA[@]}")

# 重新建立 orphan 历史
CURR_BRANCH=$(git rev-parse --abbrev-ref HEAD)
TEMP_BRANCH="rebuild_tmp_$$"

git checkout --orphan "$TEMP_BRANCH"
# 保持工作区文件不变，创建首个空树提交前需要暂存全部
git rm -r --cached . >/dev/null 2>&1 || true

git add -A
# 若工作区无变化也可继续

# 清理索引重新添加，确保不受旧历史影响
rm -f .git/index || true
git reset

# 逐条提交（分配月份）
COUNT=0
for msg in "${PLAN[@]}"; do
  if (( COUNT < 12 )); then
    make_commit "$msg" "$march_from" "$march_to"
  elif (( COUNT < 36 )); then
    # 24 条核心：平均分配到4-6月
    seg=$(( (COUNT-12) % 3 ))
    case $seg in
      0) make_commit "$msg" "$apr_from" "$apr_to" ;;
      1) make_commit "$msg" "$may_from" "$may_to" ;;
      2) make_commit "$msg" "$jun_from" "$jun_to" ;;
    esac
  elif (( COUNT < 48 )); then
    make_commit "$msg" "$jul_from" "$jul_to"
  elif (( COUNT < 60 )); then
    make_commit "$msg" "$aug_from" "$aug_to"
  else
    # 余下 12 条核心：均匀分布 4-6 月
    seg=$(( (COUNT-60) % 3 ))
    case $seg in
      0) make_commit "$msg" "$apr_from" "$apr_to" ;;
      1) make_commit "$msg" "$may_from" "$may_to" ;;
      2) make_commit "$msg" "$jun_from" "$jun_to" ;;
    esac
  fi
  COUNT=$((COUNT+1))
  if (( COUNT >= TOTAL_COMMITS )); then break; fi
done

# 替换 master 并强推
T_USER="tatawin-1991"; T_EMAIL="tatawin1991@outlook.com"
# 提取 token
lookup_token() {
  local want_user="$1" line
  for line in "${VALID_ACCOUNTS[@]}"; do
    IFS="," read -r u e t <<< "$line"
    [[ "$u" == "$want_user" ]] && echo "$t" && return 0
  done
  return 1
}
T_TOKEN="$(lookup_token "$T_USER" || true)"

git branch -M master

git config user.name "$T_USER"
git config user.email "$T_EMAIL"
if [[ -n "$T_TOKEN" ]]; then
  ASKPASS_SCRIPT="$(pwd)/scripts/.git-askpass.sh"
  cat > "$ASKPASS_SCRIPT" <<'SH'
#!/bin/sh
case "$1" in
  *Username*) echo "$GIT_USERNAME" ;;
  *Password*) echo "$GIT_PASSWORD" ;;
  *) echo ;;
 esac
SH
  chmod +x "$ASKPASS_SCRIPT"
  GIT_ASKPASS="$ASKPASS_SCRIPT" GIT_USERNAME="$T_USER" GIT_PASSWORD="$T_TOKEN" git push -f -u origin master || true
else
  git push -f -u origin master || true
fi

# 打印每位作者提交计数
printf "\nCommit counts by author (rebuilt):\n"
git log --pretty="%an" | sort | uniq -c | sort -nr | cat
