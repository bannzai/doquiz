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
| 課金 | 最初の版に入れ、トライアルを付ける。実装の方式は下の「決めていないこと」 |

「本文を端末の外に出さない」は、アプリが次をしないことを指す: 本文をサーバーへ送る、CloudKit で同期する、Private Cloud Compute に渡す。端末のバックアップに保存データが入るかは別の話で、実機で確かめていない (`documents/design/data-structure-2026-11-17/index.html` の「決まった点」の 1)。

### 決めていないこと

agent が決めず、owner が決めてから実装する。

- 課金の中身: トライアルの長さ (owner の原文は「1習慣」で、owner に確認中)、課金の形 (月額 / 年額 / 買い切り)、値段、無料で使える範囲。目標の月間収益は owner が保留にしている
- 課金の実装の方式。候補:
  - Apple の StoreKit をアプリから直接使う。商品は App Store Connect に登録する。App Store Connect の他に新しい外部サービスは足さない
  - RevenueCat を使う。RevenueCat の project と API キーが要り (revenuecat-product-setup skill が project の作成から行う)、新しい外部サービスとの連携になる。アプリから RevenueCat へ何が送られるかは、この ADR を書く時には確かめていない
- アプリ内の計測 (画面の表示・操作の記録)。判定基準の指標 (初回ダウンロード数・課金の売上) は App Store Connect の数値で、アプリに計測の SDK を入れなくても取れる。アプリ内の計測を足す場合は Firebase Analytics 等の新しい外部サービスが要るため、足すかどうかと何を使うかは未決
- クラッシュの通知。Crashlytics は Firebase のプロジェクトが要るため未決
- お問い合わせ等のサービス通知の宛先 (Slack のチャンネル)

### 対象外

- GCP の課金・エラーのアラート: GCP を使わないため作らない

## Consequences

- サーバーの費用と運用が無い (`documents/DIRECTION.md` の「費用」の固定費の月額上限は 0 USD)
- 本文がアプリから外部へ送られないため、プライバシーポリシーと App Store のプライバシーの申告で、本文について書く範囲が端末内の保存に限られる。課金の方式とアプリ内の計測が決まった時に、送る情報が増えるかを見直す
- 端末を替えた時や、アプリを消した時に、読書の記録と履歴は引き継がれない (同期を持たないため。端末のバックアップからの復元で戻るかは確かめていない)
- クイズに使える本文は端末内のモデルの文脈の大きさに収まる分だけで、長い範囲は選んで渡す (`documents/DIRECTION.md` の「agent に任せること」)。端末内のモデルが使えない端末・設定ではクイズを出せない
- 認証が無いため、利用者ごとの購入の状態は Apple のアカウントに紐づく購入の情報だけで判定することになる (方式が決まった時に確かめる)
- サーバーを足す、CloudKit の同期を有効にする、本文を端末の外に送る処理を足す時は、owner の決定を `documents/DIRECTION.md` の「決めたこと」に書き、この ADR を置き換える新しい ADR を書く
