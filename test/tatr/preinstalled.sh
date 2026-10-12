#!/bin/bash
set -euo pipefail
source dev-container-features-test-lib

check "tatr is on PATH" command -v tatr
check "tatr displays help" tatr help
check "requested commit was built" bash -c 'tatr version | grep -q "tatr commit 9b0d752"'
reportResults
