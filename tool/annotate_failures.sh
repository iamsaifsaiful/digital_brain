#!/usr/bin/env bash
# Turns the failing part of a log into a GitHub annotation, so the reason
# a step failed can be read from the run summary and the API.
# Usage: bash tool/annotate_failures.sh <log file> <title>
set -uo pipefail
log="$1"
title="$2"

# Keep the lines that explain failures, with some context around them.
details=$(grep -n -E -A12 'EXCEPTION CAUGHT|Expected:|Actual:|Which:|\[E\]|error •|warning •|Error:|FAILURE|What went wrong|Test failed|was thrown|overflowed' "$log" | head -n 220)
if [ -z "$details" ]; then
  details=$(tail -n 120 "$log")
fi

# Annotation messages are one line: encode %, CR and LF.
encoded=$(printf '%s' "$details" | sed -e 's/%/%25/g' | sed -e ':a;N;$!ba;s/\r/%0D/g;s/\n/%0A/g')
echo "::error title=${title}::${encoded}"
