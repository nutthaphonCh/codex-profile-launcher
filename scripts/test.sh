#!/usr/bin/env bash
# Runs the unit test suite.
#
# swift-testing needs Testing.framework. A full Xcode installation provides it
# on the default search paths; a Command Line Tools-only installation ships it
# in a location SwiftPM does not search, so the paths are supplied explicitly.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

CLT_FRAMEWORKS="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
CLT_LIBS="/Library/Developer/CommandLineTools/Library/Developer/usr/lib"

extra_flags=()
if [[ ! -d "$(xcode-select -p 2>/dev/null)/Platforms" && -d "${CLT_FRAMEWORKS}" ]]; then
  echo "==> Command Line Tools toolchain detected; adding Testing.framework search paths"
  extra_flags=(
    -Xswiftc -F -Xswiftc "${CLT_FRAMEWORKS}"
    -Xlinker -F -Xlinker "${CLT_FRAMEWORKS}"
    -Xlinker -rpath -Xlinker "${CLT_FRAMEWORKS}"
    -Xlinker -rpath -Xlinker "${CLT_LIBS}"
  )
fi

swift test "${extra_flags[@]}" "$@"
