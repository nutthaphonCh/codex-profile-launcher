#!/usr/bin/env bash
# Imports a Developer ID signing certificate into a temporary keychain.
#
# Used only by the release workflow, and only when the signing secrets are
# configured. Kept separate from build.sh so that ordinary compilation never
# depends on certificates existing.
#
#   MACOS_CERTIFICATE_P12       base64-encoded .p12
#   MACOS_CERTIFICATE_PASSWORD  password for that .p12
set -euo pipefail

: "${MACOS_CERTIFICATE_P12:?MACOS_CERTIFICATE_P12 is not set}"
: "${MACOS_CERTIFICATE_PASSWORD:?MACOS_CERTIFICATE_PASSWORD is not set}"

KEYCHAIN_PATH="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/codex-profile-launcher-signing.keychain-db"
# Random, single-use: this keychain exists only for the life of the job.
KEYCHAIN_PASSWORD="$(openssl rand -base64 24)"
CERTIFICATE_PATH="$(mktemp -t signing-certificate).p12"
trap 'rm -f "${CERTIFICATE_PATH}"' EXIT

echo "${MACOS_CERTIFICATE_P12}" | base64 --decode > "${CERTIFICATE_PATH}"

security create-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"
security set-keychain-settings -lut 21600 "${KEYCHAIN_PATH}"
security unlock-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN_PATH}"

security import "${CERTIFICATE_PATH}" \
  -k "${KEYCHAIN_PATH}" \
  -P "${MACOS_CERTIFICATE_PASSWORD}" \
  -T /usr/bin/codesign

# Lets codesign use the key without an interactive prompt.
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s -k "${KEYCHAIN_PASSWORD}" \
  "${KEYCHAIN_PATH}" > /dev/null

security list-keychain -d user -s "${KEYCHAIN_PATH}" login.keychain-db

echo "==> Imported signing identities:"
security find-identity -v -p codesigning "${KEYCHAIN_PATH}"
