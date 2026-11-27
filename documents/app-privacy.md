# App Privacy (App Store の「App のプライバシー」) の回答

回答の正は `fastlane/app_privacy_details.json`。App Store Connect への適用と publish は、申請の時に appstore-app-privacy skill (bannzai/castle) で行う。この文書は、回答をそう決めた根拠を残す。

## 回答

| category | purposes | data_protections | 由来 |
| --- | --- | --- | --- |
| `PURCHASE_HISTORY` | `ANALYTICS`・`APP_FUNCTIONALITY` | `DATA_NOT_LINKED_TO_YOU` | RevenueCat の SDK が送る購入の履歴 |

## 根拠 (2026-11-28 の main で確認)

- アプリが外へデータを送る経路は RevenueCat の SDK だけ。`git grep -n -I -i -E 'URLSession|Analytics|Firebase|Crashlytics|Sentry|appUserID|logIn\(|Purchases\.configure|ATTrackingManager|IDFA' origin/main -- Doquiz` に出る送信の経路は `Doquiz/Purchase/RevenueCatPurchaseService.swift` の `Purchases.configure(withAPIKey:)` の 1 件で、依存の package も RevenueCat だけ (`Doquiz.xcodeproj/project.pbxproj`)
- `PURCHASE_HISTORY` の purposes: RevenueCat の文書 ( https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/apple-app-privacy ) が、購入の履歴に Analytics と App Functionality の両方を最低の要件としている
- `DATA_NOT_LINKED_TO_YOU`: 利用者の ID を RevenueCat に渡していない (`Purchases.logIn`・`appUserID` の指定が無く、RevenueCat が作る匿名の ID のまま)。アカウントの機能も無い
- 読書の本文・問い・回答: 端末の中にだけ保存し、サーバーへ送らず CloudKit でも同期しない (`documents/adr/0002-on-device-only-infrastructure.md`)。クイズの生成と判定は端末内のモデルで行う。収集に当たらないため、回答に入れない
- 解析・クラッシュの収集・広告の SDK は入れていない。トラッキングはしない

## 見直す時

- 解析やクラッシュの収集の SDK を足した時、利用者の ID を RevenueCat に渡すようにした時、本文を端末の外へ送るようにした時は、回答を見直す (appstore-app-privacy skill の `references/sdk_privacy_answers.md`「構成が変わったら見直す点」)
