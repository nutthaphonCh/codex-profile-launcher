#!/usr/bin/env bash
# Submits an artifact to Apple's notary service and staples the ticket.
#
# Does nothing (successfully) unless all three credentials are present, so the
# release workflow can call it unconditionally:
#
#   APPLE_ID             Apple ID email
#   APPLE_TEAM_ID        Developer team identifier
#   APPLE_APP_PASSWORD   app-specific password for that Apple ID
#
# Notarization additionally requires the artifact to have been signed with a
# Developer ID certificate; an ad-hoc signature is rejected by Apple.
set -euo pipefail

ARTIFACT="${1:?usage: notarize.sh <path-to-.dmg-or-.zip>}"

if [[ -z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" || -z "${APPLE_APP_PASSWORD:-}" ]]; then
  echo "==> Notarization credentials not configured; skipping."
  echo "    The artifact will still install, but macOS will warn on first launch."
  exit 0
fi

echo "==> Submitting ${ARTIFACT} for notarization"
xcrun notarytool submit "${ARTIFACT}" \
  --apple-id "${APPLE_ID}" \
  --team-id "${APPLE_TEAM_ID}" \
  --password "${APPLE_APP_PASSWORD}" \
  --wait

echo "==> Stapling ticket"
xcrun stapler staple "${ARTIFACT}"
xcrun stapler validate "${ARTIFACT}"
