#!/bin/bash
set -euo pipefail

# Standalone host tests: no container test library or package installation needed.
test_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
installer=${1:-"$test_dir/../../src/git-cliff/install.sh"}
shell=$(command -v sh)
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

[[ -f "$installer" ]] || { printf 'Installer not found: %s\n' "$installer" >&2; exit 1; }
mkdir "$workdir/bin"
cp "$test_dir/validation-stub.sh" "$workdir/stub"
chmod 0755 "$workdir/stub"
for command in id uname apt-get apk dnf microdnf yum curl wget git tar gzip sha512sum install mkdir chmod mktemp rm cp mv; do
    ln -s "$workdir/stub" "$workdir/bin/$command"
done

failures=0
check() {
    local description=$1
    shift
    if "$@"; then
        printf 'PASS: %s\n' "$description"
    else
        printf 'FAIL: %s\n' "$description" >&2
        failures=$((failures + 1))
    fi
}

reportResults() {
    [[ $failures -eq 0 ]]
}

rejects() {
    local version=$1 dependencies=$2 uid=$3 os=$4 arch=$5 pattern=$6
    local status=0
    : > "$workdir/effects"
    PATH="$workdir/bin" GITCLIFFVERSION="$version" INSTALLDEPENDENCIES="$dependencies" \
        STUB_UID="$uid" STUB_OS="$os" STUB_ARCH="$arch" STUB_EFFECT_LOG="$workdir/effects" \
        "$shell" "$installer" > "$workdir/output" 2>&1 || status=$?
    if [[ $status -eq 0 ]] || ! grep -Eiq "$pattern" "$workdir/output" || [[ -s "$workdir/effects" ]]; then
        printf 'Exit status: %s\n' "$status" >&2
        cat "$workdir/output" "$workdir/effects" >&2
        return 1
    fi
}

check "rejects version with v prefix" rejects v2.14.2 true 0 Linux x86_64 'version|GITCLIFFVERSION'
check "rejects empty version" rejects '' true 0 Linux x86_64 'version|GITCLIFFVERSION'
check "rejects incomplete version" rejects 2.14 true 0 Linux x86_64 'version|GITCLIFFVERSION'
check "rejects latest instead of a pinned stable version" rejects latest true 0 Linux x86_64 'version|GITCLIFFVERSION'
check "rejects prerelease version" rejects 2.14.2-rc.1 true 0 Linux x86_64 'version|GITCLIFFVERSION'
check "rejects shell syntax in version" rejects '2.14.2;false' true 0 Linux x86_64 'version|GITCLIFFVERSION'
check "rejects invalid dependency option" rejects 2.14.2 maybe 0 Linux x86_64 'installDependencies|INSTALLDEPENDENCIES|true.*false|boolean'
check "rejects nonroot installation" rejects 2.14.2 true 1000 Linux x86_64 'root|privilege'
check "rejects unsupported operating system" rejects 2.14.2 true 0 Darwin x86_64 'Linux|operating system|unsupported.*OS'
check "rejects unsupported architecture" rejects 2.14.2 true 0 Linux riscv64 'architecture|amd64.*arm64|unsupported.*arch'
for tool in curl git tar gzip sha512sum install mktemp; do
    rm "$workdir/bin/$tool"
    check "rejects missing $tool when installation is disabled" rejects 2.14.2 false 0 Linux x86_64 "Missing required tool: $tool"
    ln -s "$workdir/stub" "$workdir/bin/$tool"
done

reportResults
