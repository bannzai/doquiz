#!/usr/bin/env bash
# .github/workflows/ios-deploy.yml の step のうち、secret の値が無くても動かせる shell の分岐を、step の shell 本体を
# workflow からそのまま切り出して確かめる。
# - 「Reject concurrent dispatch」: 偽の gh を PATH の先頭に置き、先行の未完了 run がある時と、run の一覧を取得できない時に
#   配布を止めること。切り出し方と偽の gh は、この workflow の元のテンプレートを確かめる castle の ios-deploy-actions skill の
#   scripts/test/test-ios-deploy-actions.sh と同じ。あちらはテンプレートから生成した workflow に当て、ここでは doquiz の workflow に当てる
# - secret の空の検査 (App Store Connect API の鍵・署名の証明書・provisioning profile・RevenueCat の公開 SDK キー):
#   secret が空なら止め、偽の値があれば通ること。書き出し先は一時ディレクトリ (HOME と作業ディレクトリ) にする
# Usage: bash scripts/test/test-ios-deploy-workflow-steps.sh [<ios-deploy.yml のパス>]
#   パスを省くと、このリポジトリの .github/workflows/ios-deploy.yml を使う (壊した写しに当てて落ちることを確かめる時に渡す)
# exit code: 0 = 全件 PASS / 1 = 失敗あり
set -u

repository_root="$(cd "$(dirname "$0")/../.." && pwd)"
workflow="${1:-$repository_root/.github/workflows/ios-deploy.yml}"
work_directory="$(mktemp -d)"

# 名前が step_name の step の `run: |` の本体を、GitHub Actions の run: の既定のシェル (bash -e) に合わせて先頭に set -e を置いて
# output_path に書き出す。
extract_step() {
  local step_name="$1" output_path="$2"
  {
    echo 'set -e'
    sed -n "/- name: ${step_name}\$/,/^\$/p" "$workflow" \
      | sed -n '/^        run: |$/,$p' | sed '1d' | sed 's/^          //'
  } > "$output_path"
}

fragment="$work_directory/reject-concurrent-dispatch.sh"
extract_step "Reject concurrent dispatch" "$fragment"

mkdir -p "$work_directory/bin"
# 偽の gh。--status の値で応答を切り替える。GH_STUB_FAIL_STATUS の status は取得の失敗、
# GH_STUB_RUNS_STATUS (省くと in_progress) の status は GH_STUB_RUNS、GH_STUB_EXTRA_STATUS の status は GH_STUB_EXTRA_RUNS、
# それ以外は空の配列を返す。GH_STUB_EMPTY=1 の時は、どの status にも何も返さない
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
elif [ -n "${GH_STUB_EXTRA_STATUS:-}" ] && [ "$requested_status" = "$GH_STUB_EXTRA_STATUS" ]; then
  printf '%s' "${GH_STUB_EXTRA_RUNS:-[]}"
else
  printf '%s' '[]'
fi
STUB
chmod +x "$work_directory/bin/gh"

pass=0
fail=0

# 結果の exit code (第 2 引数) が期待 (第 3 引数) と一致することを確かめる。
assert_exit_code() {
  local description="$1" actual="$2" expected="$3"
  if [ "$actual" -eq "$expected" ]; then
    echo "PASS: $description"
    pass=$((pass + 1))
  else
    echo "FAIL: $description (expected exit $expected, got exit $actual)"
    fail=$((fail + 1))
  fi
}

# 自分の run ID を 200 として多重起動の判定の step を実行し、exit code を確かめる。
# 引数: <説明> <期待する exit code> <in_progress (GH_STUB_RUNS_STATUS) の未完了 run の JSON> <GITHUB_RUN_ATTEMPT>
#       [取得に失敗させる status] [GH_STUB_RUNS を返す status] [何も返さないなら 1] [別の status] [別の status の未完了 run の JSON]
assert_dispatch() {
  local description="$1" expected="$2" actual=0
  PATH="$work_directory/bin:$PATH" GH_STUB_RUNS="$3" GITHUB_RUN_ATTEMPT="$4" GH_STUB_FAIL_STATUS="${5:-}" \
    GH_STUB_RUNS_STATUS="${6:-in_progress}" GH_STUB_EMPTY="${7:-0}" \
    GH_STUB_EXTRA_STATUS="${8:-}" GH_STUB_EXTRA_RUNS="${9:-[]}" \
    GITHUB_REPOSITORY=bannzai/doquiz GITHUB_RUN_ID=200 GH_TOKEN=dummy \
    bash "$fragment" >/dev/null 2>&1 || actual=$?
  assert_exit_code "$description" "$actual" "$expected"
}

assert_dispatch "未完了の run が 0 件なら通す" 0 '[]' 1
assert_dispatch "最初の起動で、未完了の run が自分だけなら通す" 0 '[{"databaseId":200}]' 1
assert_dispatch "自分より古い未完了の run が 1 件あれば止める" 1 '[{"databaseId":100}]' 1
assert_dispatch "最初の起動では、自分より新しい未完了の run だけなら通す" 0 '[{"databaseId":300}]' 1
assert_dispatch "Re-run では、自分より新しい未完了の run があっても止める" 1 '[{"databaseId":300}]' 2
assert_dispatch "Re-run で、未完了の run が自分だけなら通す" 0 '[{"databaseId":200}]' 2
assert_dispatch "requested の先行の run も数えて止める" 1 '[{"databaseId":100}]' 1 "" requested
assert_dispatch "waiting の先行の run も数えて止める" 1 '[{"databaseId":100}]' 1 "" waiting
assert_dispatch "自分は in_progress、先行の run は queued と、status が分かれていても止める" 1 '[{"databaseId":200}]' 1 "" in_progress 0 queued '[{"databaseId":100}]'
assert_dispatch "自分は in_progress、自分より新しい run は queued なら、最初の起動では通す" 0 '[{"databaseId":200}]' 1 "" in_progress 0 queued '[{"databaseId":300}]'
assert_dispatch "最初の status (requested) の一覧を取得できなければ止める" 1 '[]' 1 requested
assert_dispatch "途中の status (queued) の一覧を取得できなければ止める" 1 '[]' 1 queued
assert_dispatch "先行の run を持つ status の一覧を取得できなければ止める" 1 '[{"databaseId":100}]' 1 queued queued
assert_dispatch "どの status の応答も空なら、件数を判定できないとして止める" 1 '[]' 1 "" in_progress 1

# secret の空の検査の step を、HOME と作業ディレクトリを一時ディレクトリにして実行し、exit code を返す。
# 引数: <step の名前> [環境変数の代入 ...]
run_secret_step() {
  local step_name="$1"
  shift
  local step_directory
  step_directory="$(mktemp -d "$work_directory/step.XXXXXX")"
  mkdir -p "$step_directory/home" "$step_directory/repository/scripts"
  cp "$repository_root/scripts/write-secrets-xcconfig.sh" "$step_directory/repository/scripts/"
  extract_step "$step_name" "$step_directory/step.sh"
  (cd "$step_directory/repository" && env -i PATH="$PATH" HOME="$step_directory/home" "$@" bash "$step_directory/step.sh") \
    >/dev/null 2>&1
}

# base64 の偽の値 ("dummy" を base64 にしたもの)。どの step も値を復号して書き出すだけで、中身を検証しない
fake_base64="ZHVtbXk="

actual=0; run_secret_step "Restore App Store Connect API key" ASC_API_KEY_ID= ASC_API_KEY_ISSUER_ID=issuer ASC_API_KEY_P8_BASE64="$fake_base64" || actual=$?
assert_exit_code "ASC_API_KEY_ID が空なら API の鍵を置かずに止める" "$actual" 1
actual=0; run_secret_step "Restore App Store Connect API key" ASC_API_KEY_ID=KEY ASC_API_KEY_ISSUER_ID= ASC_API_KEY_P8_BASE64="$fake_base64" || actual=$?
assert_exit_code "ASC_API_KEY_ISSUER_ID が空なら API の鍵を置かずに止める" "$actual" 1
actual=0; run_secret_step "Restore App Store Connect API key" ASC_API_KEY_ID=KEY ASC_API_KEY_ISSUER_ID=issuer ASC_API_KEY_P8_BASE64= || actual=$?
assert_exit_code "ASC_API_KEY_P8_BASE64 が空なら API の鍵を置かずに止める" "$actual" 1
actual=0; run_secret_step "Restore App Store Connect API key" ASC_API_KEY_ID=KEY ASC_API_KEY_ISSUER_ID=issuer ASC_API_KEY_P8_BASE64="$fake_base64" || actual=$?
assert_exit_code "API の鍵の 3 つが揃っていれば通す" "$actual" 0

actual=0; run_secret_step "Check code signing secrets" IOS_P12_CERTIFICATE_BASE64= IOS_P12_PASSWORD=password || actual=$?
assert_exit_code "IOS_P12_CERTIFICATE_BASE64 が空なら止める" "$actual" 1
actual=0; run_secret_step "Check code signing secrets" IOS_P12_CERTIFICATE_BASE64="$fake_base64" IOS_P12_PASSWORD= || actual=$?
assert_exit_code "IOS_P12_PASSWORD が空なら止める" "$actual" 1
actual=0; run_secret_step "Check code signing secrets" IOS_P12_CERTIFICATE_BASE64="$fake_base64" IOS_P12_PASSWORD=password || actual=$?
assert_exit_code "署名の証明書と password が揃っていれば通す" "$actual" 0

actual=0; run_secret_step "Install provisioning profiles" IOS_PROVISIONING_PROFILE_BASE64= || actual=$?
assert_exit_code "IOS_PROVISIONING_PROFILE_BASE64 が空なら profile を置かずに止める" "$actual" 1
actual=0; run_secret_step "Install provisioning profiles" IOS_PROVISIONING_PROFILE_BASE64="$fake_base64" || actual=$?
assert_exit_code "provisioning profile があれば通す" "$actual" 0

actual=0; run_secret_step "RevenueCat の公開 SDK キーを書き出す" REVENUECAT_PUBLIC_API_KEY_IOS= || actual=$?
assert_exit_code "RevenueCat の公開 SDK キーが空なら、配布では止める" "$actual" 1
actual=0; run_secret_step "RevenueCat の公開 SDK キーを書き出す" REVENUECAT_PUBLIC_API_KEY_IOS=appl_dummy || actual=$?
assert_exit_code "RevenueCat の公開 SDK キーがあれば通す" "$actual" 0

echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
