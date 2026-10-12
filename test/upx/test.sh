#!/bin/bash
set -euo pipefail

source dev-container-features-test-lib

check "upx is on PATH" command -v upx
check "upx reports its version" upx --version
check "upx displays help" upx --help

reportResults
