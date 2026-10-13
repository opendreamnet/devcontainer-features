#!/bin/bash
set -euo pipefail

source dev-container-features-test-lib

expected_version=${EXPECTED_VERSION:-2.14.2}
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Ignore ambient Git configuration, especially signing and commit hooks.
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null
unset GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

version_matches() {
    [[ $(git-cliff --version) == "git-cliff $expected_version" ]]
}

initialize_config() {
    (cd "$workdir" && git-cliff --init) || return 1
    [[ -s "$workdir/cliff.toml" ]]
}

generate_changelog() {
    git -C "$workdir" init || return 1
    git -C "$workdir" config user.name "Feature Test" || return 1
    git -C "$workdir" config user.email "feature-test@example.invalid" || return 1
    git -C "$workdir" config commit.gpgsign false || return 1
    git -C "$workdir" config tag.gpgsign false || return 1
    git -C "$workdir" config core.hooksPath /dev/null || return 1
    git -C "$workdir" -c commit.gpgsign=false commit --allow-empty -m "feat: verify feature changelog" || return 1
    (cd "$workdir" && git-cliff --output CHANGELOG.md) || return 1
    [[ -s "$workdir/CHANGELOG.md" ]] || return 1
    grep -Fiq "verify feature changelog" "$workdir/CHANGELOG.md"
}

check "git-cliff is on PATH" command -v git-cliff
check "git-cliff reports version $expected_version" version_matches
check "git-cliff displays help" git-cliff --help
check "git-cliff initializes configuration" initialize_config
check "git-cliff generates a changelog from a conventional commit" generate_changelog

reportResults
