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
# それ以外は空の配列を返す。GH_STUB_EMPTY=1 の時は、どの status にも何も返さない。
# GH_STUB_MOVE_STATE_FILE を渡すと、取得の間に status が進む先行 run を作る: run GH_STUB_MOVE_RUNS は
# GH_STUB_MOVE_FROM にいて、GH_STUB_MOVE_AFTER の取得の直後に GH_STUB_MOVE_TO へ進む (進んだことを状態のファイルに残す)
cat > "$work_directory/bin/gh" <<'STUB'
#!/bin/bash
requested_status=""
previous_argument=""
for argument in "$@"; do
  if [ "$previous_argument" = "--status" ]; then requested_status="$argument"; fi
  previous_argument="$argument"
done
if [ -n "${GH_STUB_MOVE_STATE_FILE:-}" ]; then
  if [ -e "$GH_STUB_MOVE_STATE_FILE" ]; then moving_run_status="$GH_STUB_MOVE_TO"; else moving_run_status="$GH_STUB_MOVE_FROM"; fi
  if [ "$requested_status" = "$GH_STUB_MOVE_AFTER" ]; then touch "$GH_STUB_MOVE_STATE_FILE"; fi
  if [ "$requested_status" = "$moving_run_status" ]; then printf '%s' "$GH_STUB_MOVE_RUNS"; else printf '%s' '[]'; fi
  exit 0
fi
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

# 先行 run (ID 100) が、取得の間に次の status へ進んでも止めることを確かめる。
# 引数: <説明> <進む前の status> <進んだ後の status> <この status の取得の直後に進む>
assert_dispatch_with_moving_run() {
  local description="$1" actual=0
  PATH="$work_directory/bin:$PATH" GH_STUB_MOVE_STATE_FILE="$(mktemp -u "$work_directory/moved.XXXXXX")" \
    GH_STUB_MOVE_RUNS='[{"databaseId":100}]' GH_STUB_MOVE_FROM="$2" GH_STUB_MOVE_TO="$3" GH_STUB_MOVE_AFTER="$4" \
    GITHUB_RUN_ATTEMPT=1 GITHUB_REPOSITORY=bannzai/doquiz GITHUB_RUN_ID=200 GH_TOKEN=dummy \
    bash "$fragment" >/dev/null 2>&1 || actual=$?
  assert_exit_code "$description" "$actual" 1
}

assert_dispatch_with_moving_run "先行 run が requested から queued へ進んでも止める" requested queued requested
assert_dispatch_with_moving_run "先行 run が waiting から queued へ進んでも止める (queued の取得の直後に進む)" waiting queued queued
assert_dispatch_with_moving_run "先行 run が waiting から in_progress へ進んでも止める (in_progress の取得の直後に進む)" waiting in_progress in_progress
assert_dispatch_with_moving_run "先行 run が pending から queued へ進んでも止める" pending queued pending
assert_dispatch_with_moving_run "先行 run が queued から in_progress へ進んでも止める" queued in_progress queued

# 名前が step_name の step を、step_directory の下の home を HOME、repository を作業ディレクトリにして実行し、exit code を返す。
# 作業ディレクトリには scripts/write-secrets-xcconfig.sh の写しを置く。GITHUB_ENV は step_directory/github_env
# 引数: <step_directory (mktemp -d で作ったもの)> <step の名前> [環境変数の代入 ...]
run_step_in() {
  local step_directory="$1" step_name="$2"
  shift 2
  mkdir -p "$step_directory/home" "$step_directory/repository/scripts"
  cp "$repository_root/scripts/write-secrets-xcconfig.sh" "$step_directory/repository/scripts/"
  extract_step "$step_name" "$step_directory/step.sh"
  (cd "$step_directory/repository" \
    && env -i PATH="$PATH" HOME="$step_directory/home" GITHUB_ENV="$step_directory/github_env" "$@" bash "$step_directory/step.sh") \
    >/dev/null 2>&1
}

# run_step_in を新しい一時ディレクトリで実行し、exit code を返す (実行の後にファイルを読まない step 用)。
# 引数: <step の名前> [環境変数の代入 ...]
run_secret_step() {
  run_step_in "$(mktemp -d "$work_directory/step.XXXXXX")" "$@"
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

# 結果 (第 2 引数) が期待 (第 3 引数) と一致することを確かめる。
assert_equal() {
  local description="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    echo "PASS: $description"
    pass=$((pass + 1))
  else
    echo "FAIL: $description (expected '$expected', got '$actual')"
    fail=$((fail + 1))
  fi
}

# ビルド番号は run の番号に offset を足した値を GITHUB_ENV に追記する
step_directory="$(mktemp -d "$work_directory/step.XXXXXX")"
actual=0; run_step_in "$step_directory" "Resolve build number" GITHUB_RUN_NUMBER=7 BUILD_NUMBER_OFFSET=0 || actual=$?
assert_exit_code "offset が 0 ならビルド番号を求めて通す" "$actual" 0
assert_equal "offset が 0 ならビルド番号は run の番号 (7)" "$(cat "$step_directory/github_env" 2>/dev/null)" "BUILD_NUMBER=7"
step_directory="$(mktemp -d "$work_directory/step.XXXXXX")"
printf 'EXISTING=1\n' > "$step_directory/github_env"
actual=0; run_step_in "$step_directory" "Resolve build number" GITHUB_RUN_NUMBER=7 BUILD_NUMBER_OFFSET=100 || actual=$?
assert_exit_code "offset が 100 でもビルド番号を求めて通す" "$actual" 0
assert_equal "offset が 100 ならビルド番号は 107 で、GITHUB_ENV の既存の行を残して追記する" \
  "$(cat "$step_directory/github_env" 2>/dev/null)" "$(printf 'EXISTING=1\nBUILD_NUMBER=107')"

# ExportOptions.plist は plist として読め、App Store 用の profile と手動署名を指す
step_directory="$(mktemp -d "$work_directory/step.XXXXXX")"
actual=0; run_step_in "$step_directory" "Generate ExportOptions.plist" DEVELOPMENT_TEAM=FAKETEAM01 || actual=$?
assert_exit_code "ExportOptions.plist を書き出して通す" "$actual" 0
assert_equal "ExportOptions.plist のキーの値" \
  "$(python3 -c '
import plistlib, sys
with open(sys.argv[1], "rb") as plist_file:
    export_options = plistlib.load(plist_file)
for key in sorted(export_options):
    print(f"{key}={export_options[key]!r}")
' "$step_directory/repository/tmp/ExportOptions.plist" 2>&1)" \
  "$(printf '%s\n' \
    "destination='export'" \
    "manageAppVersionAndBuildNumber=False" \
    "method='app-store-connect'" \
    "provisioningProfiles={'app.bannzai.doquiz': 'Doquiz.AppStore'}" \
    "signingCertificate='Apple Distribution'" \
    "signingStyle='manual'" \
    "stripSwiftSymbols=True" \
    "teamID='FAKETEAM01'" \
    "uploadSymbols=True")"

# Cleanup は API の鍵と 2 か所の profile を消し、何も無い時も失敗しない
step_directory="$(mktemp -d "$work_directory/step.XXXXXX")"
mkdir -p "$step_directory/home/.appstoreconnect/private_keys" \
  "$step_directory/home/Library/MobileDevice/Provisioning Profiles" \
  "$step_directory/home/Library/Developer/Xcode/UserData/Provisioning Profiles"
touch "$step_directory/home/.appstoreconnect/private_keys/AuthKey_KEY.p8" \
  "$step_directory/home/Library/MobileDevice/Provisioning Profiles/Doquiz_AppStore.mobileprovision" \
  "$step_directory/home/Library/Developer/Xcode/UserData/Provisioning Profiles/Doquiz_AppStore.mobileprovision"
actual=0; run_step_in "$step_directory" "Cleanup" || actual=$?
assert_exit_code "API の鍵と profile がある時の Cleanup は通す" "$actual" 0
assert_equal "Cleanup の後に API の鍵と 2 か所の profile が残らない" \
  "$(find "$step_directory/home" -type f | wc -l | tr -d ' ')" "0"
actual=0; run_secret_step "Cleanup" || actual=$?
assert_exit_code "何も無い時の Cleanup も通す" "$actual" 0

echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
