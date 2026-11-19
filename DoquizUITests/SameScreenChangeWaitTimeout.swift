import XCTest

/// 同じ画面の中の表示の変化 (要素が出る・無くなる・表示の文字が変わる) を待つ上限の秒数。
///
/// 上限を過ぎても条件が成り立たない時は、待った側がテストを失敗にする。条件が先に成り立てばその時点で進むため、通るテストの時間は延びない。
// 30 秒は、GitHub の runner が遅い時に画面の要素を 1 回探すだけで約 9 秒かかった実測
// (https://github.com/bannzai/doquiz/actions/runs/44524256588 の 1 回目の実行。10 秒の上限では確かめ直しが間に合わずに落ちた。
// https://github.com/bannzai/doquiz/issues/58 ) でも 3 回は確かめられる長さとして選んだ。
// 偽のクイズが問いを返すまでの待ち (3 秒) もこの中に収まる。
let sameScreenChangeWaitTimeout: TimeInterval = 30
