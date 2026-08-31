#!/usr/bin/env bash
#
# Codemagic pre-build step for this repo.
#
# The native android/ and ios/ folders are NOT committed (see README). This
# script regenerates them on the build machine and then generates the launcher
# icon and startup splash into them, before `flutter build` runs.
#
# How to wire it up:
#   * Codemagic UI (Workflow Editor):  paste  `bash scripts/codemagic_pre_build.sh`
#     into  Workflow > Build > "Pre-build script".
#   * codemagic.yaml:  already calls this script (see the scripts: section).
#
# Safe to run more than once. `flutter create` on an existing project only
# fills in the missing native folders; it leaves lib/, pubspec.yaml, etc.
# alone (and .metadata + the unmanaged_files list guard the rest).

set -euo pipefail

ORG="com.oshomeditation"
PROJECT_NAME="osho_meditation"

# Which platforms to materialise. Override from the caller, e.g.
#   PLATFORMS=android bash scripts/codemagic_pre_build.sh
PLATFORMS="${PLATFORMS:-android,ios}"

echo "==> flutter create ($PLATFORMS)"
flutter create \
  --org "$ORG" \
  --project-name "$PROJECT_NAME" \
  --platforms="$PLATFORMS" \
  .

case ",$PLATFORMS," in
  *,android,*) test -d android || { echo "ERROR: android/ was not generated"; exit 1; } ;;
esac
case ",$PLATFORMS," in
  *,ios,*) test -d ios || { echo "ERROR: ios/ was not generated"; exit 1; } ;;
esac

echo "==> flutter pub get"
flutter pub get

echo "==> flutter_native_splash (logo splash: foreground + background)"
dart run flutter_native_splash:create

echo "==> flutter_launcher_icons (logo icon: adaptive foreground + background)"
dart run flutter_launcher_icons

echo "==> pre-build done"
