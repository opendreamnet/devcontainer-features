#!/bin/bash
set -euo pipefail

source dev-container-features-test-lib

check "tatr is on PATH" command -v tatr
check "tatr reports build information" tatr version
check "tatr displays help" tatr help

reportResults
