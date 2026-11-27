# TestFlight への配布

`.github/workflows/ios-deploy.yml` が、Release のビルドを TestFlight (App Store Connect。App ID 6837255318) へアップロードする。署名は手動署名で、配布証明書と provisioning profile を GitHub Actions の environment `ios-deploy` の secret から復元する。方式を選んだ理由は ios-deploy-actions skill (bannzai/castle) の `references/signing-design.md` にある。

## 起動

- main へのマージ (push) で自動で起動する
- 配布し直す時だけ手動で起動する。environment `ios-deploy` がデプロイできるブランチを main だけに絞っているため、`--ref` は main にする

```sh
gh workflow run ios-deploy.yml --repo bannzai/doquiz --ref main
RUN_ID="$(gh run list --repo bannzai/doquiz --workflow ios-deploy.yml --limit 1 --json databaseId --jq '.[0].databaseId')"
gh run watch "$RUN_ID" --repo bannzai/doquiz
```

- 配布は同時に 1 本だけ。先に起動した run が終わっていないと、最初の step (Reject concurrent dispatch) で失敗する。先の run が終わってから起動し直す

## ビルド番号

- ビルド番号は `github.run_number + BUILD_NUMBER_OFFSET`。offset は 0 (この workflow を足した 2026-11-25 の時点で、TestFlight にビルドが 1 件も無かったため)
- workflow を作り直して run_number が戻る時は、TestFlight の最大のビルド番号を超えるように offset を上げる

## 失敗した run のやり直し

- Upload to TestFlight まで進んで失敗した run は Re-run しない。原因を直して新しく起動する (Re-run はビルド番号が変わらず、アップロード済みと同じ番号の再送として拒否される)
- Upload より前の step で失敗した run は Re-run してよい (その番号はまだアップロードされていない)

## 署名

- 配布証明書はチーム (TQPN82UBBY) で 1 枚を使い回す。原本は 1Password の vault `bannzai` の `IOS_P12_CERTIFICATE_BASE64` と `IOS_P12_PASSWORD`
- provisioning profile の名前は `Doquiz.AppStore`。`Doquiz.xcodeproj/project.pbxproj` の `PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]` と、workflow の ExportOptions の名前を同じにする
- 手動署名にしているのは Release の実機向け (`[sdk=iphoneos*]`) だけ。Debug と iOS Simulator は自動署名のまま
- profile の期限は証明書と同じ日に切れる。切れる前に、profile を発行し直して secret `IOS_PROVISIONING_PROFILE_BASE64` を更新する。アプリに App Extension を足した時は、Extension の profile も一緒に発行し直し、対応する secret を全部更新する (workflow は渡した profile を全部必須にする)

```sh
bash ~/.claude/skills/ios-deploy-actions/scripts/signing-assets.sh create-profile \
  --name "Doquiz.AppStore" --bundle-id "app.bannzai.doquiz" \
  --certificate-id 68L9PY6PX2 \
  --out ./tmp/signing --entitlements Doquiz/Doquiz.entitlements --recreate
bash ~/.claude/skills/ios-deploy-actions/scripts/register-secrets.sh --repo bannzai/doquiz --env ios-deploy \
  --secret-base64-file IOS_PROVISIONING_PROFILE_BASE64=./tmp/signing/Doquiz_AppStore.mobileprovision
```

`--certificate-id` は、secret `IOS_P12_CERTIFICATE_BASE64` に入っている証明書の id (2026-11-25 の時点で `68L9PY6PX2`。期限は 2027-01-17) にする。証明書を更新した時は、`signing-assets.sh list-certificates` の出力で新しい id を確かめて書き換える。

## secret

environment `ios-deploy` の secret: `ASC_API_KEY_ID`・`ASC_API_KEY_ISSUER_ID`・`ASC_API_KEY_P8_BASE64`・`IOS_P12_CERTIFICATE_BASE64`・`IOS_P12_PASSWORD`・`IOS_PROVISIONING_PROFILE_BASE64`。

リポジトリの secret: `REVENUECAT_PUBLIC_API_KEY_IOS` (ci.yml と共用。配布では空の時に止まる)。
