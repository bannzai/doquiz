#!/usr/bin/env bash
# 並べ直した App Store のスクリーンショット (organize_appstore_screenshots.sh の出力) が、
# App Store Connect に上げられる大きさで、透明の情報 (alpha) を持たないことを確かめる。macOS の sips を使う。
#
# 使い方:
#   bash scripts/generate_screenshots/check_appstore_screenshots.sh <並べ直した先>
#
# 確かめる大きさは、Apple が申請に必須にしている「iPhone with Dynamic Island (medium display)」の縦向きの 1206 x 2622 px
# (https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications 。2026-11-28 に確認。
# 同じ区分のもう 1 つの大きさ 1179 x 2556 は、撮影に使う iPhone 17 の Simulator の大きさではないため受け付けない)。
#
# 終了コード: 0 = 全部の画像が条件を満たす / 1 = 条件を満たさない画像がある・画像が 1 枚も無い / 2 = 引数の誤り
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "使い方: $0 <並べ直した先>" >&2
  exit 2
fi

expected_width=1206
expected_height=2622
checked=0
failed=0
while IFS= read -r image; do
  width=$(sips -g pixelWidth "$image" | awk '/pixelWidth/ {print $2}')
  height=$(sips -g pixelHeight "$image" | awk '/pixelHeight/ {print $2}')
  has_alpha=$(sips -g hasAlpha "$image" | awk '/hasAlpha/ {print $2}')
  echo "$image ${width}x${height} hasAlpha=$has_alpha"
  if [ "$width" != "$expected_width" ] || [ "$height" != "$expected_height" ] || [ "$has_alpha" != "no" ]; then
    echo "Error: $image は ${expected_width}x${expected_height} で alpha の無い画像ではありません" >&2
    failed=1
  fi
  checked=$((checked + 1))
done < <(find "$1" -name '*.png' | sort)

if [ "$checked" -eq 0 ]; then
  echo "Error: $1 に画像がありません" >&2
  exit 1
fi
exit "$failed"
