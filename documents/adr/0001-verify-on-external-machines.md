# 0001. ビルドと動作確認は外部マシンで行い、作業用の Mac で動かさない

## Status

Accepted

## Context

- owner の作業用の Mac では複数のプロダクトの agent が並列に動いていて、xcodebuild・iOS Simulator・ブラウザを agent が起動すると Mac の負荷になる
- owner の指示 (2026-11-17、立ち上げの依頼): 「ビルド・simulator・ブラウザの動作確認は外部マシン (public repo は simtunnel / GitHub Actions、private repo は Devin) に頼り、このマシンの負荷を避ける」
- このアプリは画面の取り込みに ScreenCaptureKit を使い、iOS では 27.0 から使える (https://developer.apple.com/documentation/screencapturekit の availability。2026-11-17 に確認)。ビルドには iOS 27 の SDK (Xcode 27) が要る
- GitHub-hosted の runner で Xcode 27 が入っているのは `xcode-27` の image だけで、`macos-26` の image は Xcode 26.6 まで (https://github.com/actions/runner-images の `images/macos/xcode-27-arm64-Readme.md` と `macos-26-arm64-Readme.md`。2026-11-17 に確認)
- simtunnel の session workflow は `runs-on: macos-26` 固定 (bannzai/simtunnel の `.github/workflows/session.yml`、commit 28808c1。2026-11-17 に確認) で、iOS 27 を最低対応にするアプリをビルドできない

## Decision

- agent は、このリポジトリのビルド・テスト・Simulator・ブラウザでの動作確認を外部マシンで行う。作業用の Mac で xcodebuild・Simulator・ブラウザを起動しない
- リポジトリが public の間は GitHub Actions と simtunnel を使う
  - ビルドと単体テスト・UI テスト: PR の CI (`.github/workflows/ci.yml`、runner は `xcode-27`)
  - 画面の見た目: UI テストが添付したスクリーンショットを CI の artifact (`screenshots`) から取り出して見る
  - 画面を操作しながらの確認: simtunnel。simtunnel が Xcode 27 の runner を選べるようになるまでは使えないため、その間は UI テストとスクリーンショットで確かめる
- リポジトリが private に変わったら Devin の macOS セッションを使う (GitHub-hosted の macOS runner は private では有料のため)
- 外部マシンで確かめられない項目 (他のアプリの画面の取り込み、端末内モデルでのクイズ生成、実際の書籍の縦書きの OCR 精度) は、取り込み・OCR・クイズ生成を差し替えられる境界にして、CI では固定の画像と偽の生成器で確かめる。実物での確認は「ユーザー作業の一覧」issue の実機での確認に回す
- Makefile のビルド・起動の target (`make`、`make install-device` 等) は、owner が手元で触るための入口として残す

## Consequences

- 作業用の Mac の負荷が増えない。確認のたびに push と CI の待ち時間 (数分〜十数分) がかかる
- 画面を操作しながらの確認は、simtunnel が Xcode 27 の runner に対応するまで UI テストで書ける範囲に限られる
- GitHub の runner の Simulator で Foundation Models の端末内モデルが動くかは確かめていない。動かない前提で偽の生成器を使う設計にしており、動くと分かったら CI に実モデルのテストを足せる
- `xcode-27` の image は preview の扱い (actions/runner-images の README。2026-11-17 時点) で、ラベルや入っている Xcode が変わることがある。変わった時は `ci.yml` の `runs-on` を直す
