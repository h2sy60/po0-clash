#!/usr/bin/env bash
# CI-equivalent checks on the build host, with the Go/Rust build hooks off.
# Extra arguments are passed to `flutter test`.
set -euo pipefail

if [[ -f /etc/profile.d/flclash-toolchain.sh ]]; then
  source /etc/profile.d/flclash-toolchain.sh
fi
if [[ -x /opt/toolchains/flutter/bin/flutter ]]; then
  export PATH="/opt/toolchains/flutter/bin:/opt/toolchains/go/bin:$PATH"
fi
cd "$(dirname "$0")/../.."

backup="$(mktemp)"
cp pubspec.yaml "$backup"
trap 'cp "$backup" pubspec.yaml; rm -f "$backup"' EXIT
sed -i 's/build_assets: true/build_assets: false/' pubspec.yaml

flutter pub get
dart format --output=none --set-exit-if-changed lib test tool plugins setup.dart
flutter analyze --no-fatal-infos
flutter test --coverage "$@"
dart run tool/check_coverage.dart coverage/lcov.info 75
