#!/bin/sh
set -eu

# Only the test library needs Bash; the feature installer does not.
apk add --no-cache bash
exec bash "$(dirname "$0")/test.sh"
