#!/usr/bin/env bash
# fastlane/metadata/<locale>/ のストアの掲載文が、App Store Connect の文字数の上限に収まっているかを確かめる。
# 上限の出典 (2026-11-28 に取得して確認):
# - promotional_text 170 文字・description と release_notes 4000 文字・keywords 100:
#   https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
# - name と subtitle 30 文字: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information
# keywords は、上の文書が「100 bytes」と書いている。ここでは文字数で数える (公開中の bannzai/Focus の日本語の keywords が
# 90 文字・246 バイトで、バイト数では 100 を超えているため)。App Store Connect が日本語をどう数えるかは、文書では確かめていない。
#
# 使い方: bash scripts/check-store-metadata.sh
# 終了コード: 0 = 全部収まっている、1 = 上限を超えたファイルか、無いファイルがある
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
status=0

# 改行を除いた文字数で数える (文字コードを UTF-8 に固定する)
check() {
  local file="$1" max="$2" count
  if [ ! -f "$file" ]; then
    echo "NG: ファイルが無い: ${file#"$root"/}" >&2
    status=1
    return
  fi
  count="$(LC_ALL=en_US.UTF-8 tr -d '\n' < "$file" | LC_ALL=en_US.UTF-8 wc -m | tr -d ' ')"
  if [ "$count" -le "$max" ]; then
    echo "OK: ${file#"$root"/} ($count / $max 文字)"
  else
    echo "NG: ${file#"$root"/} ($count / $max 文字)" >&2
    status=1
  fi
}

for locale_dir in "$root"/fastlane/metadata/*/; do
  check "${locale_dir}name.txt" 30
  check "${locale_dir}subtitle.txt" 30
  check "${locale_dir}keywords.txt" 100
  check "${locale_dir}promotional_text.txt" 170
  check "${locale_dir}description.txt" 4000
  check "${locale_dir}release_notes.txt" 4000
done

exit "$status"
