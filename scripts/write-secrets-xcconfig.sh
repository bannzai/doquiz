#!/usr/bin/env bash
# 環境変数 REVENUECAT_PUBLIC_API_KEY_IOS の値を、Doquiz.xcconfig が読み込む git 管理外の Secrets.xcconfig に書き出す。
#
# 使い方: bash scripts/write-secrets-xcconfig.sh [出力先のパス]
#   出力先を省くと、リポジトリの直下の Secrets.xcconfig に書く。
#
# - 環境変数が未設定か空の時は、空の値を書く (アプリは RevenueCat の SDK を初期化せず、購入の画面は商品を取得できない時の表示になる)。
# - 何回実行しても、出力先は環境変数の今の値を 1 行持つ同じ内容になる (冪等)。
# - 値は標準出力・標準エラーに出さない。
#
# exit code:
#   0: 書き出した
#   1: 値に英数字と _ 以外の文字がある (xcconfig は // 以降をコメントとして落とし、空白や改行で別の設定を足せるため、書き出さずに止める)
set -euo pipefail

output_path="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/Secrets.xcconfig}"
revenuecat_public_api_key_ios="${REVENUECAT_PUBLIC_API_KEY_IOS:-}"

if [[ ! "$revenuecat_public_api_key_ios" =~ ^[A-Za-z0-9_]*$ ]]; then
  echo "Error: REVENUECAT_PUBLIC_API_KEY_IOS に英数字と _ 以外の文字があります (値は表示しません)" >&2
  exit 1
fi

printf 'REVENUECAT_PUBLIC_API_KEY_IOS = %s\n' "$revenuecat_public_api_key_ios" > "$output_path"

if [ -n "$revenuecat_public_api_key_ios" ]; then
  echo "Secrets.xcconfig に REVENUECAT_PUBLIC_API_KEY_IOS を書き出しました: $output_path"
else
  echo "REVENUECAT_PUBLIC_API_KEY_IOS が空のため、空の値を書き出しました: $output_path"
fi
