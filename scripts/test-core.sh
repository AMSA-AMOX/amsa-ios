#!/bin/zsh
# Runs the AMSATests logic suites on macOS with only the Command Line Tools (no Xcode, no simulator).
# Compiles the Foundation-only app sources plus the tests into one swift-testing executable.
# Skipped here (they need the iOS app): ContractTests and the US-map path check.
# Extra arguments go to swift-testing, e.g. `scripts/test-core.sh --filter Social`.
set -euo pipefail
ROOT=${0:A:h:h}
CLT=/Library/Developer/CommandLineTools
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export TMPDIR=$WORK

# App sources whose imports are all available on macOS without UIKit/SwiftUI.
for f in $ROOT/AMSA/Core/**/*.swift $ROOT/AMSA/Shell/Route.swift; do
  if ! grep -qE '^import (SwiftUI|UIKit|WebKit|PhotosUI|EventKitUI|SafariServices)' "$f"; then
    cp "$f" "$WORK/$(basename "$f")"
  fi
done
for f in $ROOT/AMSATests/*.swift; do
  [[ $(basename "$f") == ContractTests.swift ]] && continue
  sed -e 's/^@testable import AMSA$//' -e '/USMapGeometry/d' "$f" > "$WORK/T_$(basename "$f")"
done
cp $ROOT/AMSA/Resources/Data/*.json "$WORK/" # StaticData reads Bundle.main = the executable's folder
cat > "$WORK/Runner.swift" <<'EOF'
import Foundation
import Testing

@main
struct Runner {
    static func main() async { exit(await Testing.__swiftPMEntryPoint()) }
}
EOF

cd "$WORK"
swiftc -parse-as-library -swift-version 6 -module-name AMSACoreTests -Onone \
  -F $CLT/Library/Developer/Frameworks -plugin-path $CLT/usr/lib/swift/host/plugins/testing \
  -Xlinker -rpath -Xlinker $CLT/Library/Developer/Frameworks -Xlinker -rpath -Xlinker $CLT/Library/Developer/usr/lib \
  *.swift -o amsa-core-tests
./amsa-core-tests "$@"
