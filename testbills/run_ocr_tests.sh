#!/bin/sh
# Runs the rendered test bills through Vision OCR, the real parser and rules.
set -e
cd "$(dirname "$0")/.."
SRC=LimeShield
OUT="${TMPDIR:-/tmp}/limeshield-ocr-tests"
xcrun swiftc -O -o "$OUT" testbills/OCRTests/main.swift \
  $SRC/BillParser.swift $SRC/Models.swift $SRC/ReferenceData.swift \
  $SRC/RulesEngine.swift $SRC/RulesEngineExtended.swift $SRC/RulesEngineMore.swift
"$OUT" testbills
