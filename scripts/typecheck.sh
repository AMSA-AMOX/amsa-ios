#!/bin/zsh
# Typechecks the app (Swift 6, strict concurrency) as Mac Catalyst using only the Command Line
# Tools SDK, for machines without Xcode. Not a substitute for `xcodebuild`: no asset catalog,
# no linking, no iOS-only availability checks.
#
# The `@Entry` macro plugin ships only with Xcode, so a scratch copy swaps in manual EnvironmentKeys.
set -euo pipefail
ROOT=${0:A:h:h}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

rsync -a --include='*/' --include='*.swift' --exclude='*' "$ROOT/AMSA/" "$WORK/src/"
python3 - "$WORK/src/App/AMSAApp.swift" <<'PY'
import re, sys
path = sys.argv[1]
lines = open(path).read().split("\n")
out, group = [], None

def flush():
    m = re.match(r"\s*@Entry var (\w+): (.+?) = (.*)$", " ".join(l.strip() for l in group), re.S)
    name, type_, default = m.groups()
    key = f"__{name}Key"
    out.append(f"    private struct {key}: EnvironmentKey {{ static var defaultValue: {type_} {{ {default} }} }}")
    out.append(f"    var {name}: {type_} {{ get {{ self[{key}.self] }} set {{ self[{key}.self] = newValue }} }}")

for line in lines:
    starts = line.lstrip().startswith("@Entry ")
    if group is not None and (starts or not line.startswith("     ")):
        flush()
        group = None
    if starts:
        group = [line]
    elif group is not None:
        group.append(line)
    else:
        out.append(line)
if group is not None:
    flush()
open(path, "w").write("\n".join(out))
PY

SDK=$(xcrun --show-sdk-path)
IOS=$SDK/System/iOSSupport
LOG=$WORK/typecheck.log
swiftc -typecheck -target arm64-apple-ios17.0-macabi -sdk "$SDK" -Fsystem "$IOS/System/Library/Frameworks" \
  -I "$IOS/usr/lib/swift" -swift-version 6 -module-name AMSA $(find "$WORK/src" -name '*.swift') >"$LOG" 2>&1 || true

grep -E "^/.*(error|warning):" "$LOG" | sed "s|$WORK/src/|AMSA/|" | sort -u || true
errors=$(grep -cE "^/.*error:" "$LOG" || true)
echo "errors: $errors"
[[ "$errors" == 0 ]]
