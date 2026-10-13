#!/bin/sh
set -eu

# Only the test harness needs Bash, not the feature installer.
apk add --no-cache bash
exec bash "$(dirname "$0")/test.sh"
