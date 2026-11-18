# SwiftData (端末内の保存データ) の決まり

保存データの形は公開後に変えにくい。形の正は `Doquiz/Models/` の `@Model` の型で、新しい型を足す時は `~/.claude/documents/rules/show-new-data-structure-to-owner.md` に従う (新しい型の定義は owner に見せる。既存の型へのプロパティの追加は見せない)。`documents/design/data-structure-2026-11-17/index.html` は、構想の確認で owner に見せたページで、owner が 2026-11-18 にこの形を採った (`documents/DIRECTION.md` の「決めたこと」の行)。最初の実装はこの形にする。

- `@Model` の型は `Doquiz/Models/` に 1 型 1 ファイルで置く。画面や処理の都合で詰め替えた型を作らず、`@Model` の型をそのまま画面に渡す
- 保存するのは、他の値から求められない値だけにする。正答率・ページ数・問いの数のように保存済みの値から求められるものは保存せず、読む時に求める。回答の判定 (合っていると判定したか) は保存する (穴埋めと記述の判定は端末内モデルの出力で、後から同じ値を求め直せないため。選択式も同じ場所に保存して読む側を 1 通りにする)
- 公開前は、型を変えた時に保存データを作り直してよい (移行のコードを書かない)。App Store か TestFlight に出した後に型を変える時は、`VersionedSchema` と `SchemaMigrationPlan` で移行を書き、前の版の保存データを新しい版で開けることをテストで確かめる
- `ModelContainer` はアプリの入口で 1 つだけ作る。テストと Preview は `isStoredInMemoryOnly: true` の container を使い、端末の保存データに触れない
- 取り込んだ画面の画像は保存しない。保存するのは OCR で抽出した本文だけにする (owner の決定。`documents/DIRECTION.md` の「決めたこと」の 2026-11-18 の行)
- 保存データをサーバーや iCloud に送らない (CloudKit の同期を有効にしない)。CloudKit の同期を有効にする時は、本文を端末の外に出すことになるため `documents/DIRECTION.md` の「決めたこと」に owner の決定を書いてからにする。利用者の端末の iCloud バックアップに保存データが入ることは owner が許しており、バックアップから除外する設定はしない (`documents/adr/0002-on-device-only-infrastructure.md`)
