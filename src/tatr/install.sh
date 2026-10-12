#!/bin/sh

set -eu

# Validate installation prerequisites.
if [ "$(id -u)" -ne 0 ]; then
  echo "This feature must be installed as root." >&2
  exit 1
fi

if [ "$(uname -s)" != "Linux" ]; then
  echo "tatr currently supports Linux containers only." >&2
  exit 1
fi

# Read and validate feature options.
TATR_VERSION="${TATRVERSION:-main}"
INSTALL_DEPENDENCIES="${INSTALLDEPENDENCIES-true}"
RUN_TESTS="${RUNTESTS-false}"

for value in "$INSTALL_DEPENDENCIES" "$RUN_TESTS"; do
  case "$value" in
    true|false) ;;
    *) echo "installDependencies and runTests must be true or false." >&2; exit 1 ;;
  esac
done

# Install native build dependencies and clear package caches.
if [ "$INSTALL_DEPENDENCIES" = "true" ]; then
  # RPM and SUSE images may already provide install via coreutils-single.
  set -- gcc glibc-devel make ca-certificates git
  if ! command -v install >/dev/null 2>&1; then
    set -- "$@" coreutils
  fi

  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends build-essential ca-certificates git
    apt-get clean
    rm -rf /var/lib/apt/lists/*
  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache build-base ca-certificates git
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y --setopt=install_weak_deps=False "$@"
    dnf clean all
  elif command -v microdnf >/dev/null 2>&1; then
    microdnf install -y "$@"
    microdnf clean all
  elif command -v tdnf >/dev/null 2>&1; then
    # Photon GCC needs explicit assembler and Linux API headers.
    tdnf install -y "$@" binutils linux-api-headers
    tdnf clean all
  elif command -v yum >/dev/null 2>&1; then
    yum install -y "$@"
    yum clean all
  elif command -v zypper >/dev/null 2>&1; then
    zypper --non-interactive install --no-recommends "$@"
    zypper --non-interactive clean --all
  elif command -v pacman >/dev/null 2>&1; then
    # Arch requires a full upgrade when refreshing package databases.
    pacman -Syu --needed --noconfirm gcc make ca-certificates git coreutils
    pacman -Scc --noconfirm
  else
    echo "Unsupported package manager. Expected apt-get, apk, dnf, microdnf, yum, tdnf, zypper or pacman." >&2
    echo "On a pre-provisioned Linux image, set installDependencies=false." >&2
    exit 1
  fi
fi

# Check tools even when dependency installation is disabled.
for tool in cc git install; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool. Provide a C toolchain, libc headers, git and install." >&2
    exit 1
  fi
done

# Keep sources temporary, including on failure or interruption.
SOURCE_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$SOURCE_DIR"
}

trap cleanup EXIT
trap 'exit 1' HUP INT TERM

# Fetch only the requested revision and build from a detached checkout.
git init "$SOURCE_DIR/tatr" >/dev/null
git -C "$SOURCE_DIR/tatr" remote add origin https://github.com/tsoding/tatr.git
git -C "$SOURCE_DIR/tatr" fetch --depth 1 -- origin "$TATR_VERSION" >/dev/null
git -C "$SOURCE_DIR/tatr" checkout --detach FETCH_HEAD >/dev/null

# Bootstrap the upstream build tool and optionally run its tests.
cd "$SOURCE_DIR/tatr"
cc -o nob nob.c
if [ "$RUN_TESTS" = "true" ]; then
  ./nob -test
else
  ./nob
fi

# Install the executable and verify it runs in this container.
mkdir -p /usr/local/bin
install -m 0755 build/tatr /usr/local/bin/tatr
/usr/local/bin/tatr version
