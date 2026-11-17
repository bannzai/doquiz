#!/usr/bin/env bash
# scripts/select-physical-device.jq が、devicectl の JSON からインストール先の実機を正しく選ぶことを確かめる。
# Usage: bash scripts/test/test-select-physical-device.sh
# exit code: 0 = 全件 PASS / 1 = 失敗あり
set -u

filter="$(cd "$(dirname "$0")" && pwd)/../select-physical-device.jq"

pass=0
fail=0

# devicectl の JSON (第 3 引数) にフィルターを当てた出力が、期待 (第 2 引数) と一致することを確かめる。
assert_selected() {
  local description="$1" expected="$2" devices_json="$3" actual
  actual="$(printf '%s' "$devices_json" | jq -r -f "$filter")"
  if [ "$actual" = "$expected" ]; then
    echo "PASS: $description"
    pass=$((pass + 1))
  else
    echo "FAIL: $description (期待: '$expected' / 実際: '$actual')"
    fail=$((fail + 1))
  fi
}

# devicectl が返す 1 台分の JSON を作る (identifier・実機か simulator か・接続の状態)。
device() {
  printf '{"identifier":"%s","hardwareProperties":{"reality":"%s"},"connectionProperties":{"tunnelState":"%s"}}' "$1" "$2" "$3"
}

assert_selected "実機が 1 台なら、待機中 (disconnected) でもそれを選ぶ" "PHONE-A" \
  "{\"result\":{\"devices\":[$(device PHONE-A physical disconnected)]}}"

assert_selected "起動中の simulator (connected) があっても、実機の方を選ぶ" "PHONE-A" \
  "{\"result\":{\"devices\":[$(device SIM-1 simulated connected),$(device PHONE-A physical disconnected)]}}"

assert_selected "simulator だけなら何も選ばない" "" \
  "{\"result\":{\"devices\":[$(device SIM-1 simulated connected)]}}"

assert_selected "実機が複数台なら、接続中の 1 台を選ぶ" "PHONE-B" \
  "{\"result\":{\"devices\":[$(device PHONE-A physical disconnected),$(device PHONE-B physical connected)]}}"

assert_selected "実機が複数台とも接続中なら何も選ばない" "" \
  "{\"result\":{\"devices\":[$(device PHONE-A physical connected),$(device PHONE-B physical connected)]}}"

assert_selected "実機が複数台とも待機中なら何も選ばない" "" \
  "{\"result\":{\"devices\":[$(device PHONE-A physical disconnected),$(device PHONE-B physical disconnected)]}}"

assert_selected "端末が 1 台も無ければ何も選ばない" "" \
  '{"result":{"devices":[]}}'

echo "passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
