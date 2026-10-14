#!/bin/bash
set -euo pipefail

source dev-container-features-test-lib

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Keep Git identity, credentials, hooks and transport configuration local to the test.
for variable in ${!GIT_@}; do
    unset "$variable"
done
unset GH_TOKEN GITHUB_TOKEN
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL="$workdir/gitconfig"
export GIT_TERMINAL_PROMPT=0
export GIT_ALLOW_PROTOCOL=file
git config --global user.name "Feature Test"
git config --global user.email "feature-test@example.invalid"
git config --global commit.gpgsign false
git config --global tag.gpgsign false
git config --global core.hooksPath /dev/null
git config --global credential.helper ''

installed_binary() {
    [[ -x /usr/local/bin/acs && $(command -v acs) -ef /usr/local/bin/acs ]]
}

help_output() {
    local output
    output=$(acs --help) || return 1
    [[ $output == *"Generate shared coding standards from pinned Git profiles"* ]]
}

command_help() {
    local command=$1 output
    output=$(acs "$command" --help) || return 1
    [[ $output == *"Usage: acs $command "* && $output == *"--transport"* ]]
}

coding_matches() {
    local coding="$workdir/consumer/CODING.md"
    [[ -s $coding ]] || return 1
    grep -Eq "^repository: [\"']?feature-test/rules[\"']?$" "$coding" || return 1
    grep -Eq "^version: [\"']?1\\.0\\.0[\"']?$" "$coding" || return 1
    grep -Eq "^revision: [\"']?${revision}[\"']?$" "$coding" || return 1
    grep -Eq '^profiles:' "$coding" || return 1
    grep -Eq '^ *- general$' "$coding" || return 1
    grep -Fxq '# General Feature Rules' "$coding" || return 1
    grep -Fxq 'Keep the selected profile.' "$coding" || return 1
    ! grep -Fq 'Unselected Feature Rules' "$coding"
}

local_workflow() {
    mkdir -p "$workdir/rules/profiles" "$workdir/consumer" || return 1
    printf '# General Feature Rules\n\nKeep the selected profile.\n' > "$workdir/rules/profiles/general.md"
    printf '# Unselected Feature Rules\n\nDo not include this profile.\n' > "$workdir/rules/profiles/other.md"
    git init --template= "$workdir/rules" || return 1
    git -C "$workdir/rules" add profiles || return 1
    git -C "$workdir/rules" commit -m 'Publish fixture rules' || return 1
    git -C "$workdir/rules" tag v1.0.0 || return 1
    revision=$(git -C "$workdir/rules" rev-parse HEAD) || return 1
    git config --global "url.file://$workdir/rules.insteadOf" https://github.com/feature-test/rules.git || return 1
    acs init --repository feature-test/rules --profiles general --version 1.0.0 -C "$workdir/consumer" --yes || return 1
    coding_matches || return 1
    cp "$workdir/consumer/CODING.md" "$workdir/expected.md" || return 1
    acs check -C "$workdir/consumer" || return 1
    printf '\nLocal generated-body drift.\n' >> "$workdir/consumer/CODING.md"
    if acs check -C "$workdir/consumer"; then
        return 1
    fi
    acs sync -C "$workdir/consumer" --yes || return 1
    [[ $(sha256sum < "$workdir/expected.md") == $(sha256sum < "$workdir/consumer/CODING.md") ]] || return 1
    acs update -C "$workdir/consumer" --yes || return 1
    [[ $(sha256sum < "$workdir/expected.md") == $(sha256sum < "$workdir/consumer/CODING.md") ]] || return 1
    coding_matches || return 1
    acs check -C "$workdir/consumer"
}

check "acs is installed on PATH at /usr/local/bin/acs" installed_binary
check "acs displays its CLI description" help_output
for command in init sync update check; do
    check "acs $command displays nonempty command help" command_help "$command"
done
check "acs init/check/sync/update use pinned profiles from local Git only" local_workflow

reportResults
