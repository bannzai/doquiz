## 判断の根拠

- 仕様・機能・デザインの判断は `documents/DIRECTION.md` (方向性の文書) を根拠にする。文書に無い問いは可逆な方に決めて、同文書の「決めたこと」に記録する
- プロダクト固有の言葉の意味は `documents/DIRECTION.md` の「用語」で確かめる

## 検証方法

ビルド・テスト・Simulator・ブラウザでの動作確認は外部マシンで行う。agent は owner の作業用の Mac で xcodebuild・iOS Simulator・ブラウザを起動しない (`documents/adr/0001-verify-on-external-machines.md`)。xcodebuildmcp・xcode MCP のビルドと実行、`sim-boot`、`make build-ios`・`make ios`・`make test` も同じ扱いにする。

- ビルド・単体テスト・UI テスト: 変更を push して PR の CI (`.github/workflows/ci.yml`。runner は Xcode 27 が入っている `xcode-27`) で確かめる。結果は `gh pr checks --watch` で待ち、失敗した時は `gh run view <run ID> --log-failed` でログを読む
- 画面の見た目: 確かめたい画面を `DoquizUITests` の UI テストで開いて `XCTAttachment(screenshot:)` で添付し、CI の artifact `screenshots` を `gh run download <run ID> -n screenshots -D tmp/screenshots` で取り出して見る。UI に影響する変更は、この画像を PR に貼ってから完了と報告する
- 画面を操作しながらの確認: `/ios-simulator` skill を起点にし、リポジトリが public の間は、特別な理由がない限り simtunnel (GitHub Actions の macOS runner 上のリモート iOS Simulator) で行う。ローカルの simulator (sim-boot) には倒さない。issue や手順書にローカル前提の記述 (`make ios` 等) があっても、それだけではローカルに倒す理由にしない
  - 手順: 確かめるブランチを push してから `SIMTUNNEL_REPO=bannzai/doquiz ~/ghq/github.com/bannzai/simtunnel/local/simtunnel up <セッション名> --ref <ブランチ> --wait` で起動する (`--ref` を省くと main がビルドされる)。caller workflow は `.github/workflows/simulator-session.yml` (runner は Xcode 27 が入っている `xcode-27`)。セッション名は `doquiz-<worktree 名>` (例: `doquiz-issue-12`) にする。操作とスクリーンショットは `/ios-simulator` skill の `scripts/ios-wda.sh --session <セッション名>` で行う。終わったら `SIMTUNNEL_REPO=bannzai/doquiz ~/ghq/github.com/bannzai/simtunnel/local/simtunnel down <セッション名>` で閉じる (macOS runner の並列の枠を CI と共有するため放置しない)
  - `gh secret list -R bannzai/doquiz` に `TS_OIDC_CLIENT_ID` と `TS_OIDC_AUDIENCE` が無い間は、セッションが Tailscale の認証で失敗する。その間は上の UI テストとスクリーンショットで確かめる
  - 到達しにくい状態 (読書の記録がある状態・回答の履歴がある状態等) は、DEBUG ビルドだけの開発者メニューで作る
- リポジトリが private に変わった時: GitHub-hosted の macOS runner と simtunnel を使わず、`/devin-macos-e2e` skill の Devin の macOS セッションで確かめる
- 外部マシンで確かめられない項目: 他のアプリ (Kindle 等) の画面の取り込み、端末内モデル (Foundation Models) でのクイズ生成、実際の書籍の縦書き・ルビの OCR 精度。これらに触れる実装は、取り込み・OCR・クイズ生成を差し替えられる境界にして、CI では固定の画像と偽の生成器でテストする。実物での確認は実装 issue の完了条件に入れず、「ユーザー作業の一覧」issue の「実機・実環境での確認」に書く
- owner が手元で触る入口: `make` (iOS Simulator にインストールして起動)、`make install-device` (接続中の iPhone にインストールして起動)。agent は実行しない

## Xcode プロジェクトの構成

- `Doquiz.xcodeproj` を唯一の正とする。プロジェクト構成は Xcode の GUI か `project.pbxproj` の直接編集で変える
- Swift ファイルは `Doquiz/`・`DoquizTests/`・`DoquizUITests/` に置くだけで、それぞれのターゲットのビルドとテストの対象になる (フォルダ同期。`project.pbxproj` の `PBXFileSystemSynchronizedRootGroup`)。ファイルの追加・移動・削除で `project.pbxproj` を編集しない
- `xcodegen generate` を実行しない。`project.yml` をリポジトリに置かない (機械検査: `bash ~/.agents/skills/create-new-app/scripts/check-setup.sh --root .` の `xcode-project-source` 項目)

<!-- ai-review-config begin -->
<!--
このブロックは自動生成です。直接編集せず、テンプレートを更新してから再生成してください。
内容は AI コードレビュー時の挙動指示であり、コードベース自体への規約ではありません。
-->

## レビュー時の応答スタイル

- 応答は日本語で行う

## レビュー範囲外

以下は自動レビューで指摘しない (別の検出経路があるため):

- コンパイルエラー・型エラー (ローカル/CI のビルドで検出される)
- Lint/フォーマット違反 (リンター・フォーマッターで検出される)
<!-- ai-review-config end -->
