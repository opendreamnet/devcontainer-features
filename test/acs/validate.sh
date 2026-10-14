#!/bin/bash
set -euo pipefail

# Narrow PATH stubs prevent package changes, downloads and installation on the host.
test_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
installer=${1:-"$test_dir/../../src/acs/install.sh"}
shell=$(command -v sh)
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

[[ -f $installer ]] || { printf 'Installer not found: %s\n' "$installer" >&2; exit 1; }
mkdir "$workdir/bin"
cp "$test_dir/validation-stub.sh" "$workdir/stub"
chmod 0755 "$workdir/stub"
for command in id uname getconf apt-get dnf microdnf apk yum curl wget git sha256sum install mktemp chmod mkdir rm cp mv; do
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

rejects() {
    local version=$1 dependencies=$2 uid=$3 os=$4 arch=$5 libc=$6 pattern=$7 status=0
    : > "$workdir/effects"
    PATH="$workdir/bin" ACSVERSION="$version" INSTALLDEPENDENCIES="$dependencies" \
        STUB_UID="$uid" STUB_OS="$os" STUB_ARCH="$arch" STUB_LIBC="$libc" \
        STUB_EFFECT_LOG="$workdir/effects" \
        "$shell" "$installer" > "$workdir/output" 2>&1 || status=$?
    if [[ $status -eq 0 ]] || ! grep -Eiq "$pattern" "$workdir/output" || [[ -s $workdir/effects ]]; then
        printf 'Exit status: %s\n' "$status" >&2
        cat "$workdir/output" "$workdir/effects" >&2
        return 1
    fi
}

for version in v0.1.0 '' 0.1 latest 0.1.0-rc.1 '0.1.0;false'; do
    check "rejects invalid version '$version' before modification" rejects "$version" true 0 Linux x86_64 'glibc 2.39' 'version|ACSVERSION'
done
check "rejects invalid dependency option" rejects 0.1.0 maybe 0 Linux x86_64 'glibc 2.39' 'installDependencies|INSTALLDEPENDENCIES|true.*false|boolean'
check "rejects nonroot installation" rejects 0.1.0 true 1000 Linux x86_64 'glibc 2.39' 'root|privilege'
check "rejects non-Linux before modification" rejects 0.1.0 true 0 Darwin x86_64 'glibc 2.39' 'Linux|operating system|unsupported.*OS'
check "rejects arm64 before modification" rejects 0.1.0 true 0 Linux aarch64 'glibc 2.39' 'architecture|amd64|x86_64'
check "rejects musl before modification" rejects 0.1.0 true 0 Linux x86_64 musl 'glibc|musl|GNU libc'
check "rejects glibc 2.36 before modification" rejects 0.1.0 true 0 Linux x86_64 'glibc 2.36' 'glibc|2\.38|GNU libc'
rm "$workdir/bin/getconf"
check "rejects unavailable libc detection before modification" rejects 0.1.0 true 0 Linux x86_64 'glibc 2.39' 'getconf|glibc|GNU libc'
ln -s "$workdir/stub" "$workdir/bin/getconf"
for tool in curl git sha256sum install mktemp chmod; do
    rm "$workdir/bin/$tool"
    check "rejects missing $tool when installation is disabled" rejects 0.1.0 false 0 Linux x86_64 'glibc 2.39' "Missing required tool: $tool"
    ln -s "$workdir/stub" "$workdir/bin/$tool"
done

[[ $failures -eq 0 ]]
