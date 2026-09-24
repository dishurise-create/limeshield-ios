#!/bin/sh
# Compiles the app's real parser and rules sources with the fixtures in
# ParserTests/main.swift and runs them on the Mac. Run after any parser change.
set -e
cd "$(dirname "$0")/.."
SRC=LimeShield
OUT="${TMPDIR:-/tmp}/limeshield-parser-tests"
xcrun swiftc -O -o "$OUT" \
  testbills/ParserTests/main.swift \
  $SRC/BillParser.swift $SRC/Models.swift $SRC/ReferenceData.swift \
  $SRC/RulesEngine.swift $SRC/RulesEngineExtended.swift $SRC/RulesEngineMore.swift
"$OUT"
