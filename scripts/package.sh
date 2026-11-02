#!/bin/bash
set -euo pipefail
variant="$1"
label="$2"
mkdir -p "build/package-$variant/Payload"
cp -R "build/$variant/Build/Products/Release-iphoneos/AbitudiniLocale.app" "build/package-$variant/Payload/"
cd "build/package-$variant"
/usr/bin/zip -qr "../AbitudiniLocale-$label-unsigned.ipa" Payload
