import SwiftUI

// 色の値は、主要画面のモック (`documents/design/mock-2026-11-18/`) の値をそのまま使う
// (`documents/DIRECTION.md`「デザインの方向」)。

/// 強調の色 (深い緑)。押せる文字・主要なボタン・選んだ状態の枠に使う。
let doquizAccentColor = Color(red: 0x0F / 255, green: 0x6B / 255, blue: 0x5C / 255)

/// 画面の地の色 (白)。
let doquizBackgroundColor = Color.white

/// 本文と見出しの文字の色 (濃い色)。
let doquizTextColor = Color(red: 0x15 / 255, green: 0x18 / 255, blue: 0x1C / 255)

/// 補足の文字の色。見出しの下の説明や、本の読書の回数の行に使う。
let doquizSecondaryTextColor = Color(red: 0x4A / 255, green: 0x52 / 255, blue: 0x60 / 255)

/// 枠の線の色。本の行・入力欄・選んでいない問いの種類の枠に使う。
let doquizBorderColor = Color(red: 0xD5 / 255, green: 0xD9 / 255, blue: 0xE0 / 255)
