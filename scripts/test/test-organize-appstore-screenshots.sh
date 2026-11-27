#!/usr/bin/env bash
# scripts/generate_screenshots/organize_appstore_screenshots.sh が、xcresulttool が書き出した添付のうち
# App Store のスクリーンショットの名前の添付だけを、言語ごとのディレクトリに掲載順のファイル名で写すことを確かめる。
# 添付の manifest.json は、CI の run 46071542424 の書き出しと同じ形の偽物を使う。
# Usage: bash scripts/test/test-organize-appstore-screenshots.sh
# exit code: 0 = 全件 PASS / 1 = 失敗あり
set -u

script="$(cd "$(dirname "$0")" && pwd)/../generate_screenshots/organize_appstore_screenshots.sh"
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

# 書き出し先 (第 1 引数) に、suggestedHumanReadableName が第 2 引数以降の添付を 1 つずつ持つ manifest.json と画像を作る。
# 画像の中身は、どの添付から写したかを見分けるため、suggestedHumanReadableName の文字列にする。
make_export() {
  local export_directory="$1"
  shift
  mkdir -p "$export_directory"
  local index=0 attachments="" name
  for name in "$@"; do
    index=$((index + 1))
    printf '%s' "$name" > "$export_directory/EXPORTED-$index.png"
    attachments+="{\"exportedFileName\":\"EXPORTED-$index.png\",\"suggestedHumanReadableName\":\"$name\"},"
  done
  printf '[{"testIdentifier":"AppStoreScreenshotTests/test()","attachments":[%s]}]' "${attachments%,}" > "$export_directory/manifest.json"
}

make_export "$work_directory/export" \
  "appstore-ja-01-quiz_0_FAA49178-47B0-4CCE-A782-0D48B29C1892.png" \
  "appstore-ja-03-question-kinds_0_1FB8BC5C-1735-471D-8FD0-377C72D8EA18.png" \
  "appstore-en-US-02-reading_0_6AE6B443-7C45-488B-96C3-A3A8303B2A97.png" \
  "book-list_0_8CBC885E-10D0-4CB6-B242-259C499E96D6.png" \
  "appstore-ja-1-quiz_0_95FA80C0-1D9C-4683-8AB3-6A6F01BE4689.png" \
  "xappstore-ja-04-evidence_0_3882F9BE-C2A5-488E-B99F-044DD76CF6B3.png"
bash "$script" "$work_directory/export" "$work_directory/output" > "$work_directory/output.log" 2>&1
assert_equal "当たる添付がある時は exit 0" "$?" "0"
assert_equal "言語と掲載順の 2 桁と値から、掲載順のファイル名で写す" \
  "$(cd "$work_directory/output" && find . -type f | sort | tr '\n' ' ')" \
  "./en-US/iPhone_02_reading.png ./ja/iPhone_01_quiz.png ./ja/iPhone_03_question-kinds.png "
assert_equal "写した画像は、その名前の添付の画像" \
  "$(cat "$work_directory/output/ja/iPhone_03_question-kinds.png")" \
  "appstore-ja-03-question-kinds_0_1FB8BC5C-1735-471D-8FD0-377C72D8EA18.png"

bash "$script" "$work_directory/export" "$work_directory/output" > /dev/null 2>&1
assert_equal "2 回実行しても exit 0" "$?" "0"
assert_equal "2 回実行しても同じ 3 枚のまま" "$(find "$work_directory/output" -type f | wc -l | tr -d ' ')" "3"

make_export "$work_directory/export-without-appstore" "book-list_0_8CBC885E-10D0-4CB6-B242-259C499E96D6.png"
bash "$script" "$work_directory/export-without-appstore" "$work_directory/output-without-appstore" > /dev/null 2>&1
assert_equal "当たる添付が 1 枚も無い時は exit 1" "$?" "1"

mkdir -p "$work_directory/export-without-manifest"
bash "$script" "$work_directory/export-without-manifest" "$work_directory/output-without-manifest" > /dev/null 2>&1
assert_equal "manifest.json が無い時は exit 1" "$?" "1"

bash "$script" "$work_directory/export" > /dev/null 2>&1
assert_equal "引数が 1 つの時は exit 2" "$?" "2"

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
