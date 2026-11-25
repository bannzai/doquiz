#!/usr/bin/env bash
# .github/workflows/ios-deploy.yml の「Reject concurrent dispatch」step の shell 本体をそのまま切り出し、
# 偽の gh を PATH の先頭に置いて、先行の未完了 run がある時と、run の一覧を取得できない時に配布を止めることを確かめる。
# 切り出し方と偽の gh は、この workflow の元のテンプレートを確かめる castle の ios-deploy-actions skill の
# scripts/test/test-ios-deploy-actions.sh と同じ。あちらはテンプレートから生成した workflow に当て、ここでは doquiz の workflow に当てる。
# Usage: bash scripts/test/test-ios-deploy-reject-concurrent-dispatch.sh [<ios-deploy.yml のパス>]
#   パスを省くと、このリポジトリの .github/workflows/ios-deploy.yml を使う (壊した写しに当てて落ちることを確かめる時に渡す)
# exit code: 0 = 全件 PASS / 1 = 失敗あり
set -u

workflow="${1:-$(cd "$(dirname "$0")" && pwd)/../../.github/workflows/ios-deploy.yml}"
work_directory="$(mktemp -d)"
fragment="$work_directory/reject-concurrent-dispatch.sh"
{
  # GitHub Actions の run: の既定のシェル (bash -e) に合わせる
  echo 'set -e'
  sed -n '/- name: Reject concurrent dispatch/,/^$/p' "$workflow" \
    | sed -n '/^        run: |$/,$p' | sed '1d' | sed 's/^          //'
} > "$fragment"

mkdir -p "$work_directory/bin"
# 偽の gh。--status の値で応答を切り替える。GH_STUB_FAIL_STATUS の status は取得の失敗、
# GH_STUB_RUNS_STATUS (省くと in_progress) の status は GH_STUB_RUNS、それ以外は空の配列を返す。
# GH_STUB_EMPTY=1 の時は、どの status にも何も返さない
cat > "$work_directory/bin/gh" <<'STUB'
#!/bin/bash
requested_status=""
previous_argument=""
for argument in "$@"; do
  if [ "$previous_argument" = "--status" ]; then requested_status="$argument"; fi
  previous_argument="$argument"
done
if [ -n "${GH_STUB_FAIL_STATUS:-}" ] && [ "$requested_status" = "$GH_STUB_FAIL_STATUS" ]; then
  echo "stub gh: API error (status=${requested_status})" >&2
  exit 1
fi
if [ "${GH_STUB_EMPTY:-0}" = "1" ]; then
  exit 0
fi
if [ "$requested_status" = "${GH_STUB_RUNS_STATUS:-in_progress}" ]; then
  printf '%s' "${GH_STUB_RUNS:-[]}"
else
  printf '%s' '[]'
fi
STUB
chmod +x "$work_directory/bin/gh"

pass=0
fail=0

# 自分の run ID を 200 として step を実行し、exit code が期待と一致することを確かめる。
# 引数: <説明> <期待する exit code> <未完了 run の JSON> <GITHUB_RUN_ATTEMPT> [取得に失敗させる status] [run を返す status] [何も返さないなら 1]
assert_exit_code() {
  local description="$1" expected="$2" actual=0
  PATH="$work_directory/bin:$PATH" GH_STUB_RUNS="$3" GITHUB_RUN_ATTEMPT="$4" GH_STUB_FAIL_STATUS="${5:-}" \
    GH_STUB_RUNS_STATUS="${6:-in_progress}" GH_STUB_EMPTY="${7:-0}" \
    GITHUB_REPOSITORY=bannzai/doquiz GITHUB_RUN_ID=200 GH_TOKEN=dummy \
    bash "$fragment" >/dev/null 2>&1 || actual=$?
  if [ "$actual" -eq "$expected" ]; then
    echo "PASS: $description"
    pass=$((pass + 1))
  else
    echo "FAIL: $description (expected exit $expected, got exit $actual)"
    fail=$((fail + 1))
  fi
}

assert_exit_code "未完了の run が 0 件なら通す" 0 '[]' 1
assert_exit_code "自分より古い未完了の run が 1 件あれば止める" 1 '[{"databaseId":100}]' 1
assert_exit_code "最初の起動では、自分より新しい未完了の run だけなら通す" 0 '[{"databaseId":300}]' 1
assert_exit_code "Re-run では、自分より新しい未完了の run があっても止める" 1 '[{"databaseId":300}]' 2
assert_exit_code "Re-run で、未完了の run が自分だけなら通す" 0 '[{"databaseId":200}]' 2
assert_exit_code "requested の先行の run も数えて止める" 1 '[{"databaseId":100}]' 1 "" requested
assert_exit_code "waiting の先行の run も数えて止める" 1 '[{"databaseId":100}]' 1 "" waiting
assert_exit_code "最初の status (requested) の一覧を取得できなければ止める" 1 '[]' 1 requested
assert_exit_code "途中の status (queued) の一覧を取得できなければ止める" 1 '[]' 1 queued
assert_exit_code "先行の run を持つ status の一覧を取得できなければ止める" 1 '[{"databaseId":100}]' 1 queued queued
assert_exit_code "どの status の応答も空なら、件数を判定できないとして止める" 1 '[]' 1 "" in_progress 1

echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
