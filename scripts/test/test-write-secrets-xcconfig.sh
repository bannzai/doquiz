#!/usr/bin/env bash
# scripts/write-secrets-xcconfig.sh が、環境変数 REVENUECAT_PUBLIC_API_KEY_IOS の値を xcconfig の 1 行として書き出し、
# xcconfig を壊す値では書き出さずに止まることを確かめる。値はテスト用の偽物だけを使う。
# Usage: bash scripts/test/test-write-secrets-xcconfig.sh
# exit code: 0 = 全件 PASS / 1 = 失敗あり
set -u

script="$(cd "$(dirname "$0")" && pwd)/../write-secrets-xcconfig.sh"
work_directory="$(mktemp -d)"

pass=0
fail=0

# 結果 (第 2 引数) が期待 (第 3 引数) と一致することを確かめる。
assert_equal() {
  local description="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    echo "PASS: $description"
    pass=$((pass + 1))
  else
    echo "FAIL: $description (期待: '$expected' / 実際: '$actual')"
    fail=$((fail + 1))
  fi
}

# 環境変数の値 (第 1 引数。"unset" なら未設定) でスクリプトを実行し、出力先 (第 2 引数) に書く。
# 標準出力と標準エラーは出力先に .log を付けたファイルに残し、exit code を返す。
run_script() {
  local value="$1" output_path="$2"
  if [ "$value" = "unset" ]; then
    env -u REVENUECAT_PUBLIC_API_KEY_IOS bash "$script" "$output_path" > "$output_path.log" 2>&1
  else
    REVENUECAT_PUBLIC_API_KEY_IOS="$value" bash "$script" "$output_path" > "$output_path.log" 2>&1
  fi
}

run_script "appl_FakeKey123" "$work_directory/key.xcconfig"
assert_equal "値がある時は exit 0" "$?" "0"
assert_equal "値がある時は、その値を 1 行で書き出す" "$(cat "$work_directory/key.xcconfig")" "REVENUECAT_PUBLIC_API_KEY_IOS = appl_FakeKey123"
assert_equal "値を標準出力と標準エラーに出さない" "$(grep -c "appl_FakeKey123" "$work_directory/key.xcconfig.log")" "0"

run_script "appl_FakeKey123" "$work_directory/key.xcconfig"
assert_equal "2 回実行しても同じ 1 行のまま" "$(cat "$work_directory/key.xcconfig")" "REVENUECAT_PUBLIC_API_KEY_IOS = appl_FakeKey123"

run_script "" "$work_directory/key.xcconfig"
assert_equal "値が空の時は exit 0" "$?" "0"
assert_equal "値が空の時は、前の値を残さず空の値を書き出す" "$(cat "$work_directory/key.xcconfig")" "REVENUECAT_PUBLIC_API_KEY_IOS = "

run_script "unset" "$work_directory/unset.xcconfig"
assert_equal "環境変数が未設定の時は exit 0" "$?" "0"
assert_equal "環境変数が未設定の時は、空の値を書き出す" "$(cat "$work_directory/unset.xcconfig")" "REVENUECAT_PUBLIC_API_KEY_IOS = "

# xcconfig を壊す値 (止まる側) と、形が近いが壊さない値 (通る側) を並べる。
run_script "appl_Fake//Key" "$work_directory/slash.xcconfig"
assert_equal "// を含む値 (xcconfig のコメントになる) は exit 1" "$?" "1"
assert_equal "// を含む値では出力先を作らない" "$([ -e "$work_directory/slash.xcconfig" ] && echo exists || echo missing)" "missing"
assert_equal "止まった時も値を標準出力と標準エラーに出さない" "$(grep -c "appl_Fake" "$work_directory/slash.xcconfig.log")" "0"

run_script "appl_Fake Key" "$work_directory/space.xcconfig"
assert_equal "空白を含む値は exit 1" "$?" "1"

run_script "$(printf 'appl_Fake\nOTHER_SETTING = 1')" "$work_directory/newline.xcconfig"
assert_equal "改行を含む値 (別の設定を足せる) は exit 1" "$?" "1"
assert_equal "改行を含む値では出力先を作らない" "$([ -e "$work_directory/newline.xcconfig" ] && echo exists || echo missing)" "missing"

run_script "appl_Fake_Key_9" "$work_directory/underscore.xcconfig"
assert_equal "_ と数字を含む値は exit 0" "$?" "0"
assert_equal "_ と数字を含む値は、そのまま書き出す" "$(cat "$work_directory/underscore.xcconfig")" "REVENUECAT_PUBLIC_API_KEY_IOS = appl_Fake_Key_9"

run_script 'appl_$(OTHER_SETTING)' "$work_directory/expansion.xcconfig"
assert_equal '$(…) を含む値 (xcconfig がほかの設定の値に置き換える) は exit 1' "$?" "1"
assert_equal '$(…) を含む値では出力先を作らない' "$([ -e "$work_directory/expansion.xcconfig" ] && echo exists || echo missing)" "missing"

run_script "appl_Fake=Key" "$work_directory/equal.xcconfig"
assert_equal "= を含む値は exit 1" "$?" "1"

run_script 'appl_"Fake"' "$work_directory/quote.xcconfig"
assert_equal '" を含む値は exit 1' "$?" "1"

# 出力先を省いた時は、スクリプトの 1 つ上のディレクトリの Secrets.xcconfig に書く。
# リポジトリの直下の Secrets.xcconfig に触れないよう、スクリプトを一時ディレクトリの scripts/ に写して実行する。
mkdir -p "$work_directory/repository/scripts"
cp "$script" "$work_directory/repository/scripts/write-secrets-xcconfig.sh"
REVENUECAT_PUBLIC_API_KEY_IOS="appl_DefaultPath" bash "$work_directory/repository/scripts/write-secrets-xcconfig.sh" > "$work_directory/default-path.log" 2>&1
assert_equal "出力先を省いた時は exit 0" "$?" "0"
assert_equal "出力先を省いた時は、スクリプトの 1 つ上のディレクトリの Secrets.xcconfig に書く" "$(cat "$work_directory/repository/Secrets.xcconfig")" "REVENUECAT_PUBLIC_API_KEY_IOS = appl_DefaultPath"
assert_equal "出力先を省いた時は、scripts/ の中に書かない" "$([ -e "$work_directory/repository/scripts/Secrets.xcconfig" ] && echo exists || echo missing)" "missing"

echo "passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
