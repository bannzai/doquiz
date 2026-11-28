#!/usr/bin/env bash
# scripts/generate_screenshots/check_appstore_screenshots.sh が、1206 x 2622 px で alpha の無い画像だけを通すことを確かめる。
# 画像の大きさは macOS の sips で変える (検査するスクリプトと同じく macOS で動かす。.github/workflows/appstore-screenshots.yml が実行する)。
# Usage: bash scripts/test/test-check-appstore-screenshots.sh
# exit code: 0 = 全件 PASS / 1 = 失敗あり
set -u

script="$(cd "$(dirname "$0")" && pwd)/../generate_screenshots/check_appstore_screenshots.sh"
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

# 幅 (第 2 引数)・高さ (第 3 引数) の PNG を第 1 引数のパスに作る。第 4 引数が alpha の時は透明の情報を持つ画像にする。
# 1 x 1 の PNG を書いて、sips で伸ばす (sips の伸ばしは alpha の有無を変えない)。
make_png() {
  local path="$1" width="$2" height="$3" alpha="${4:-}"
  mkdir -p "$(dirname "$path")"
  if [ "$alpha" = alpha ]; then
    # 1 x 1 の半透明の赤 (色の形式 6 = RGBA) の PNG。
    printf '\x89\x50\x4e\x47\x0d\x0a\x1a\x0a\x00\x00\x00\x0d\x49\x48\x44\x52\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\x0d\x49\x44\x41\x54\x78\x9c\x63\xf8\xcf\xc0\xd0\x00\x00\x04\x81\x01\x80\x2c\x55\xce\xb0\x00\x00\x00\x00\x49\x45\x4e\x44\xae\x42\x60\x82' > "$path"
  else
    # 1 x 1 の不透明な赤 (色の形式 2 = RGB) の PNG。
    printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\xcf\xc0\x00\x00\x03\x01\x01\x00\xc9\xfe\x92\xef\x00\x00\x00\x00IEND\xaeB`\x82' > "$path"
  fi
  sips -z "$height" "$width" "$path" > /dev/null
}

make_png "$work_directory/ok/ja/iPhone_01_quiz.png" 1206 2622
make_png "$work_directory/ok/ja/iPhone_02_reading.png" 1206 2622
bash "$script" "$work_directory/ok" > /dev/null 2>&1
assert_equal "全部が 1206 x 2622 で alpha 無しなら exit 0" "$?" "0"

make_png "$work_directory/other-size/ja/iPhone_01_quiz.png" 1206 2622
make_png "$work_directory/other-size/ja/iPhone_02_reading.png" 1179 2556
bash "$script" "$work_directory/other-size" > /dev/null 2>&1
assert_equal "同じ区分でも 1179 x 2556 が混ざると exit 1" "$?" "1"

make_png "$work_directory/landscape/ja/iPhone_01_quiz.png" 2622 1206
bash "$script" "$work_directory/landscape" > /dev/null 2>&1
assert_equal "横向き (2622 x 1206) は exit 1" "$?" "1"

make_png "$work_directory/height-off-by-one/ja/iPhone_01_quiz.png" 1206 2623
bash "$script" "$work_directory/height-off-by-one" > /dev/null 2>&1
assert_equal "高さが 1 px 違う (1206 x 2623) と exit 1" "$?" "1"

make_png "$work_directory/width-off-by-one/ja/iPhone_01_quiz.png" 1207 2622
bash "$script" "$work_directory/width-off-by-one" > /dev/null 2>&1
assert_equal "幅が 1 px 違う (1207 x 2622) と exit 1" "$?" "1"

make_png "$work_directory/alpha/ja/iPhone_01_quiz.png" 1206 2622 alpha
bash "$script" "$work_directory/alpha" > /dev/null 2>&1
assert_equal "1206 x 2622 でも alpha を持つと exit 1" "$?" "1"

mkdir -p "$work_directory/empty/ja"
bash "$script" "$work_directory/empty" > /dev/null 2>&1
assert_equal "画像が 1 枚も無いと exit 1" "$?" "1"

bash "$script" > /dev/null 2>&1
assert_equal "引数が無いと exit 2" "$?" "2"

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
