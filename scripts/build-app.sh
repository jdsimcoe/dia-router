#!/bin/zsh

set -euo pipefail

project_root="${0:A:h:h}"
local_signing_config="$project_root/scripts/signing.local.zsh"
app_bundle="$project_root/build/Dia Router.app"
contents_dir="$app_bundle/Contents"
resources_dir="$contents_dir/Resources"
login_item_bundle="$contents_dir/Library/LoginItems/Dia Router.app"
login_item_contents="$login_item_bundle/Contents"
login_item_resources="$login_item_contents/Resources"
icon_source="$project_root/Resources/Dia Router.icon"

if [[ -f "$local_signing_config" ]]; then
    source "$local_signing_config"
fi

signing_identity="${DIA_ROUTER_SIGNING_IDENTITY:-}"

swift build --package-path "$project_root" -c release

rm -rf "$app_bundle"
mkdir -p "$contents_dir/MacOS"
cp "$project_root/.build/release/DiaRouter" "$contents_dir/MacOS/Dia Router"
cp "$project_root/Resources/Info.plist" "$contents_dir/Info.plist"
mkdir -p "$login_item_contents/MacOS"
cp "$project_root/.build/release/DiaRouterLoginItem" "$login_item_contents/MacOS/Dia Router Login Item"
cp "$project_root/Resources/LoginItem-Info.plist" "$login_item_contents/Info.plist"

if [[ -d "$icon_source" ]]; then
    mkdir -p "$resources_dir"
    xcrun actool "$icon_source" \
        --compile "$resources_dir" \
        --platform macosx \
        --target-device mac \
        --minimum-deployment-target 14.0 \
        --app-icon "Dia Router" \
        --include-all-app-icons \
        --output-partial-info-plist "$project_root/build/icon-info.plist"

    mkdir -p "$login_item_resources"
    cp "$resources_dir/Dia Router.icns" "$login_item_resources/Dia Router.icns"
fi

if [[ -n "$signing_identity" ]] && \
   security find-identity -v -p codesigning | rg -Fq "\"$signing_identity\""; then
    codesign \
        --force \
        --options runtime \
        --timestamp=none \
        --sign "$signing_identity" \
        "$login_item_bundle"
    codesign \
        --force \
        --deep \
        --options runtime \
        --timestamp=none \
        --sign "$signing_identity" \
        "$app_bundle"
    echo "Signed with $signing_identity"
else
    codesign --force --sign - "$login_item_bundle"
    codesign --force --deep --sign - "$app_bundle"
    if [[ -n "$signing_identity" ]]; then
        echo "Warning: the configured signing identity was unavailable; used an ad-hoc signature."
    else
        echo "Built with an ad-hoc signature. Configure DIA_ROUTER_SIGNING_IDENTITY for stable local signing."
    fi
fi

codesign --verify --deep --strict --verbose=2 "$app_bundle"

echo "$app_bundle"
