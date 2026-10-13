#!/bin/bash
set -euo pipefail
export EXPECTED_VERSION=2.14.1
exec bash "$(dirname "$0")/test.sh"
