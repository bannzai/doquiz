# 0002. サーバーを持たず、保存と処理を端末内で行う

## Status

Accepted

## Context

- doquiz は、読書アプリを表示している間の画面を取り込み、OCR で抽出した本文からクイズを作る iOS アプリ (`documents/DIRECTION.md` の「仮説」)
- 取り込む本文は、利用者が買った書籍の本文そのもの。端末の外に送ると、著作権と読書アプリの規約の面の懸念が増える (位置づけは確かめきれていない。https://github.com/bannzai/doquiz/issues/2 の本文「先に知っておいてほしいこと」)
- owner の決定 (`documents/DIRECTION.md` の「決めたこと」の行):
  - 配信先は App Store (2026-11-17。https://github.com/bannzai/doquiz/issues/2#issuecomment-6947812806 )
  - 課金を最初の版に入れ、トライアルを付ける (2026-11-18。https://github.com/bannzai/doquiz/issues/2#issuecomment-6968187060 )
  - iOS だけで始める、本文を端末の外に出さない、取り込んだ画像は保存しない (2026-11-18。https://github.com/bannzai/doquiz/issues/2#issuecomment-6968190153 )
  - トライアルは 1 週間、課金の形は月額・年額のサブスクリプションと買い切り (2026-11-18。https://github.com/bannzai/doquiz/issues/2#issuecomment-6968984895 、https://github.com/bannzai/doquiz/issues/2#issuecomment-6968986791 )
  - 保存した本文が iCloud バックアップに入ることを許す、課金の実装には RevenueCat を使う (2026-11-18。https://github.com/bannzai/doquiz/issues/2#issuecomment-6969064488 )
  - 値段は月額 500 円・年額 5,000 円・買い切り 20,000 円、1 週間のトライアルは月額と年額だけに付ける、無料で使える範囲は置かない (2026-11-18。https://github.com/bannzai/doquiz/issues/2#issuecomment-6969509870 )
  - 無料で使える範囲は、2026-11-19 に owner が「読書を 20 回まで無料」に改めた ( https://github.com/bannzai/doquiz/issues/20#issuecomment-7001615361 )
- クイズの生成に使う端末内のモデル (Foundation Models) は文脈が 4K トークンで、Private Cloud Compute を使うと 32K に増えるが本文を Apple のサーバーへ送ることになる (https://github.com/bannzai/doquiz/issues/2 の本文「4. 本文を端末の外に出さないか」に書いた評価時の調べ。この ADR を書く時には Apple の文書を読み直していない)
- 新規アプリの立ち上げで決める項目は、DB・画像等のストレージ・ホスティング / バックエンド・認証方式・Analytics (create-new-app skill の SKILL.md「Phase 3: インフラ構成の決定と通知基盤」)

## Decision

| 項目 | 決定 |
| --- | --- |
| DB | 端末内の SwiftData。CloudKit の同期は有効にしない (保存の決まりは `.claude/rules/swiftdata.md`) |
| 画像等のストレージ | 持たない。取り込んだ画面の画像は保存せず、OCR で抽出した本文だけを SwiftData に保存する |
| ホスティング / バックエンド | 持たない。アプリから自前のサーバーへ通信しない |
| クイズの生成と判定 | 端末内のモデルで行う。Private Cloud Compute を使わない |
| 認証 | 持たない。アカウントの登録もログインも無い |
| 配信 | App Store。対応は iOS だけで始める |
| 端末のバックアップ | 保存した本文が iCloud バックアップに入ることを許す。バックアップから除外する設定をしない |
| 課金 | 最初の版に入れる。月額・年額のサブスクリプションと買い切りを用意し、1 週間のトライアルを月額と年額に付ける (買い切りには付けない)。値段は月額 500 円・年額 5,000 円・買い切り 20,000 円。(2026-11-18 の owner の決定。https://github.com/bannzai/doquiz/issues/2#issuecomment-6969509870 )。購入もトライアルもしていない利用者は、読書を 20 回まで無料で使える (2026-11-19 の owner の決定。2026-11-18 の「無料で使える範囲は置かない」を改めた。https://github.com/bannzai/doquiz/issues/20#issuecomment-7001615361 ) |
| 課金の実装の方式 | RevenueCat を使う。新しい外部サービスとの連携になり、RevenueCat の project と API キーが要る (revenuecat-product-setup skill が project の作成から行う) |

この ADR を最初に書いた時 (2026-11-18) に「決めていないこと」にあった項目を、同じ日に owner が決めたので表に反映した: 「端末のバックアップ」「課金の実装の方式」の行を足し、前からあった「課金」の行に、決まった形・トライアルの長さと付ける範囲・値段・無料で使える範囲を書き足した。ほかの行は変えていない。

「本文を端末の外に出さない」について、この ADR はアプリが次をしないことを決める: 本文をサーバーへ送る、CloudKit で同期する、Private Cloud Compute に渡す。利用者自身の端末のバックアップに本文が入ることは、owner が許している。SwiftData の保存データが既定でバックアップに入るかは、実機で確かめていない (`documents/design/data-structure-2026-11-17/index.html` の「決まった点」の 1)。

RevenueCat の SDK がアプリから RevenueCat へ何を送るかは、この ADR を書く時には確かめていない。課金を実装する時に RevenueCat の文書で確かめ、プライバシーポリシーと App Store のプライバシーの申告に反映する。

### 決めていないこと

agent が決めず、owner が決めてから実装する。

- 目標の月間収益。owner が保留にしている
- アプリ内の計測 (画面の表示・操作の記録)。判定基準の指標 (初回ダウンロード数・課金の売上) は App Store Connect の数値で、アプリに計測の SDK を入れなくても取れる。アプリ内の計測を足す場合は Firebase Analytics 等の新しい外部サービスが要るため、足すかどうかと何を使うかは未決
- クラッシュの通知。Crashlytics は Firebase のプロジェクトが要るため未決
- お問い合わせ等のサービス通知の宛先 (Slack のチャンネル)

### 対象外

- GCP の課金・エラーのアラート: GCP を使わない間は作らない。アプリ内の計測かクラッシュの通知で Firebase を選んだ時は、Firebase のプロジェクトが GCP のプロジェクトでもあるため、作るかを見直す

## Consequences

- サーバーの費用と運用が無い (`documents/DIRECTION.md` の「費用」の固定費の月額上限は 0 USD)
- 本文をアプリからサーバーへ送らないため、プライバシーポリシーと App Store のプライバシーの申告で、本文をサーバーへ送る処理について書くことが無い。利用者自身の端末のバックアップを App Store のプライバシーの申告に書く必要があるかは、確かめていない。RevenueCat へ送る情報を確かめた時と、アプリ内の計測が決まった時に、申告する情報が増えるかを見直す
- RevenueCat の障害や仕様の変更が、購入と購入の状態の判定に影響しうる。RevenueCat の料金は、この ADR を書く時には確かめていない (`documents/DIRECTION.md` の「費用」に書く前に確かめる)
- 端末を替えた時や、アプリを消した時に、読書の記録と履歴は引き継がれない (同期を持たないため。端末のバックアップからの復元で戻るかは確かめていない)
- クイズに使える本文は端末内のモデルの文脈の大きさに収まる分だけで、長い範囲は選んで渡す (`documents/DIRECTION.md` の「agent に任せること」)。端末内のモデルが使えない端末・設定ではクイズを出せない
- 認証が無いため、アプリのアカウントで購入の状態を引き継ぐ仕組みは持たない。RevenueCat で利用者をどう識別し、端末を替えた時に購入をどう復元するかは、課金を実装する時に確かめる
- サーバーを足す、CloudKit の同期を有効にする、本文を端末の外に送る処理を足す時は、owner の決定を `documents/DIRECTION.md` の「決めたこと」に書き、この ADR を置き換える新しい ADR を書く
