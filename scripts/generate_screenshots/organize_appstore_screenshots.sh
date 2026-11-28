#!/usr/bin/env bash
# App Store のスクリーンショットの UI テスト (DoquizUITests/AppStoreScreenshotTests.swift) が添付した画像を、
# 言語ごとのディレクトリに、掲載順のファイル名で並べ直す。
#
# 使い方:
#   bash scripts/generate_screenshots/organize_appstore_screenshots.sh <添付の書き出し先> <並べ直す先>
#
# <添付の書き出し先> は `xcrun xcresulttool export attachments --path <xcresult> --output-path <dir>` の <dir> で、
# 画像 (UUID のファイル名) と manifest.json を持つ。manifest.json の suggestedHumanReadableName が
# `appstore-<言語>-<掲載順の 2 桁>-<値>_<番号>_<UUID>.png` の添付だけを `<並べ直す先>/<言語>/iPhone_<掲載順>_<値>.png` に写す。
# ほかの名前の添付は写さない。<言語> は fastlane の deliver のディレクトリ名 (fastlane/screenshots/<言語>/) と同じ。
#
# 終了コード: 0 = 1 枚以上写した / 1 = 当たる添付が 1 枚も無い・manifest.json が無い / 2 = 引数の誤り
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "使い方: $0 <添付の書き出し先> <並べ直す先>" >&2
  exit 2
fi
export_dir=$1
output_dir=$2

if [ ! -f "$export_dir/manifest.json" ]; then
  echo "Error: $export_dir/manifest.json がありません" >&2
  exit 1
fi

copied=0
while IFS=$'\t' read -r exported_file_name human_readable_name; do
  if [[ "$human_readable_name" =~ ^appstore-([a-z]{2}(-[A-Z]{2})?)-([0-9]{2})-([a-z-]+)_[0-9]+_ ]]; then
    locale=${BASH_REMATCH[1]}
    mkdir -p "$output_dir/$locale"
    output_path="$output_dir/$locale/iPhone_${BASH_REMATCH[3]}_${BASH_REMATCH[4]}.png"
    cp "$export_dir/$exported_file_name" "$output_path"
    echo "$output_path"
    copied=$((copied + 1))
  fi
done < <(jq -r '.[].attachments[] | [.exportedFileName, .suggestedHumanReadableName] | @tsv' "$export_dir/manifest.json")

if [ "$copied" -eq 0 ]; then
  echo "Error: App Store のスクリーンショットの添付 (appstore-<言語>-<掲載順>-<値>) が 1 枚もありません" >&2
  exit 1
fi
