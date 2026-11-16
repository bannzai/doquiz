# 引数なしの make は、人が手元の iOS Simulator で触るための入口 (検査・テストは CI が行う)。
# agent はこの Makefile のビルド・起動の target を手元で実行せず、AGENTS.md「検証方法」の外部マシンで確かめる。
.DEFAULT_GOAL := ios

XCODEPROJ := Doquiz.xcodeproj
SCHEME := Doquiz
CONFIGURATION := Debug
BUNDLE_ID := app.bannzai.doquiz
# システムの DerivedData を汚さず、成果物のパスを決め打ちできるようにリポジトリ内に置く。
DERIVED_DATA := tmp/DerivedData
SIMULATOR_APP := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)-iphonesimulator/Doquiz.app
DEVICE_APP := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)-iphoneos/Doquiz.app
SIMULATOR_UDID ?= $(shell SCRIPT_QUIET=1 sim-boot | sed -n 's/^DEVICE_UDID=//p' | tail -n 1)
# 実機ビルドの署名に使う開発チーム。public リポジトリに識別子を置かないため、fastlane と同じ環境変数から受け取る。
DEVELOPMENT_TEAM ?= $(FASTLANE_TEAM_ID)

# build-ios と test は同じ DerivedData を使うため、-j 指定でも並列に起動させない。
.NOTPARALLEL:

.PHONY: build-ios ios device install-device test clean

# Simulator 向けビルド。generic destination のため simulator を起動せずにビルドできる。
build-ios:
	xcodebuild -project $(XCODEPROJ) -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) \
		-destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

# sim-boot で起動したプロジェクト固有の iOS Simulator にインストールして起動する。
ios: build-ios
	@set -e; \
	simulator_udid="$(SIMULATOR_UDID)"; \
	[ -n "$$simulator_udid" ] || { echo "Error: sim-boot で Simulator を解決できません (SIMULATOR_UDID=<UDID> を指定してください)" >&2; exit 1; }; \
	xcrun simctl install "$$simulator_udid" $(SIMULATOR_APP); \
	xcrun simctl launch "$$simulator_udid" $(BUNDLE_ID)

# 実機向けビルド。provisioning profile の自動生成とデバイス登録を CLI から行う。
device:
	@[ -n "$(DEVELOPMENT_TEAM)" ] || { echo "Error: 開発チームが分かりません (FASTLANE_TEAM_ID を export するか DEVELOPMENT_TEAM=<チーム ID> を指定してください)" >&2; exit 1; }
	xcodebuild -project $(XCODEPROJ) -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) \
		-destination 'generic/platform=iOS' -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
		DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) build

# 実機ビルドを iPhone にインストールして起動する。インストール先は DEVICE (名前 / UDID) > 実機が 1 台ならそれ > 複数台なら接続中の 1 台。
# devicectl は起動中の simulator も一覧に載せるため、先に実機だけに絞る。
install-device: device
	@set -e; \
	mkdir -p tmp; \
	device="$(DEVICE)"; \
	if [ -z "$$device" ]; then \
		xcrun devicectl list devices --json-output tmp/devices.json > /dev/null; \
		device=$$(jq -r '[.result.devices[] | select(.hardwareProperties.reality == "physical")] | if length == 1 then .[0] else (map(select(.connectionProperties.tunnelState == "connected")) | if length == 1 then .[0] else empty end) end | .identifier // empty' tmp/devices.json); \
	fi; \
	[ -n "$$device" ] || { echo "Error: インストール先の実機を 1 台に決められません (DEVICE=<名前|UDID> を指定してください)" >&2; exit 1; }; \
	xcrun devicectl device install app --device "$$device" "$(DEVICE_APP)"; \
	xcrun devicectl device process launch --device "$$device" $(BUNDLE_ID)

test:
	@set -e; \
	simulator_udid="$(SIMULATOR_UDID)"; \
	[ -n "$$simulator_udid" ] || { echo "Error: sim-boot で Simulator を解決できません (SIMULATOR_UDID=<UDID> を指定してください)" >&2; exit 1; }; \
	xcodebuild -project $(XCODEPROJ) -scheme $(SCHEME) -derivedDataPath $(DERIVED_DATA) \
		-destination "platform=iOS Simulator,id=$$simulator_udid" CODE_SIGNING_ALLOWED=NO test

clean:
	rm -rf $(DERIVED_DATA)
