# `xcrun devicectl list devices --json-output` の JSON から、アプリを入れる実機の identifier を 1 つ選ぶ。
# devicectl は起動中の simulator も一覧に載せるため、先に実機だけに絞る。
# 実機が 1 台ならそれを選び、複数台なら接続中 (tunnelState が connected) の 1 台だけを選ぶ。
# 1 台に決められない時は何も出さない (呼び出し側が DEVICE の指定を求める)。
[.result.devices[] | select(.hardwareProperties.reality == "physical")]
| if length == 1 then .[0]
  else (map(select(.connectionProperties.tunnelState == "connected")) | if length == 1 then .[0] else empty end)
  end
| .identifier // empty
