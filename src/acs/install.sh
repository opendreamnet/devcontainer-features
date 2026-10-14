#!/bin/sh
set -eu

# Validate options and the upstream binary's ABI before changing the image.
if [ "$(id -u)" -ne 0 ]; then
  echo "This feature must be installed as root." >&2
  exit 1
fi
if [ "$(uname -s)" != "Linux" ]; then
  echo "acs supports Linux containers only." >&2
  exit 1
fi
case "$(uname -m)" in
  x86_64|amd64) ;;
  *) echo "Upstream acs releases support amd64 Linux containers only." >&2; exit 1 ;;
esac

ACS_VERSION="${ACSVERSION-0.1.0}"
INSTALL_DEPENDENCIES="${INSTALLDEPENDENCIES-true}"
case "$ACS_VERSION" in
  ''|*[!0-9.]*|.*|*.|*..*|*.*.*.*)
    echo "acsVersion must be a stable version in x.y.z format (without a v prefix)." >&2
    exit 1 ;;
  *.*.*) ;;
  *) echo "acsVersion must be a stable version in x.y.z format (without a v prefix)." >&2; exit 1 ;;
esac
case "$INSTALL_DEPENDENCIES" in
  true|false) ;;
  *) echo "installDependencies must be true or false." >&2; exit 1 ;;
esac

# UPX hides ELF dependencies: v0.1.0 requires GLIBC_2.38 in libm, not musl.
LIBC="$(getconf GNU_LIBC_VERSION 2>/dev/null || true)"
case "$LIBC" in
  'glibc '*) LIBC="${LIBC#glibc }" ;;
  *) echo "acs requires glibc 2.38 or newer and getconf; musl/Alpine is unsupported." >&2; exit 1 ;;
esac
MAJOR="${LIBC%%.*}"
MINOR="${LIBC#*.}"
case "$MAJOR" in
  ''|*[!0-9]*) echo "Unable to determine the glibc version." >&2; exit 1 ;;
esac
case "$MINOR" in
  ''|*[!0-9]*) echo "Unable to determine the glibc version." >&2; exit 1 ;;
esac
if [ "$MAJOR" -lt 2 ] || { [ "$MAJOR" -eq 2 ] && [ "$MINOR" -lt 38 ]; }; then
  echo "acs requires glibc 2.38 or newer; found $LIBC. Use a newer base image, such as Ubuntu 24.04 or Debian Trixie." >&2
  exit 1
fi

if [ "$INSTALL_DEPENDENCIES" = "true" ]; then
  set -- ca-certificates git
  if ! command -v curl >/dev/null 2>&1; then
    set -- "$@" curl
  fi
  if ! command -v install >/dev/null 2>&1 || ! command -v sha256sum >/dev/null 2>&1; then
    set -- "$@" coreutils
  fi
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends "$@"
    apt-get clean
    rm -rf /var/lib/apt/lists/*
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y --setopt=install_weak_deps=False "$@"
    dnf clean all
  elif command -v microdnf >/dev/null 2>&1; then
    microdnf install -y "$@"
    microdnf clean all
  else
    echo "Unsupported package manager. Expected apt-get, dnf or microdnf; otherwise preinstall dependencies and set installDependencies=false." >&2
    exit 1
  fi
fi
for tool in curl git sha256sum install mktemp chmod; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool. Install dependencies or set installDependencies=true." >&2
    exit 1
  fi
done

WORK_DIR="$(mktemp -d)"
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

URL="https://github.com/opendreamnet/agent-coding-standards-cli/releases/download/v${ACS_VERSION}"
curl --proto '=https' --proto-redir '=https' --fail --location --silent --show-error --retry 3 \
  --output "$WORK_DIR/acs" "$URL/acs"
curl --proto '=https' --proto-redir '=https' --fail --location --silent --show-error --retry 3 \
  --output "$WORK_DIR/SHA256SUMS.txt" "$URL/SHA256SUMS.txt"

# Select exactly one acs digest without trusting paths from the checksum manifest.
DIGEST=""
while read -r HASH NAME; do
  case "$NAME" in
    acs|'*acs')
      if [ -n "$DIGEST" ]; then
        echo "Duplicate acs entry in SHA256SUMS.txt." >&2
        exit 1
      fi
      DIGEST="$HASH"
      ;;
  esac
done < "$WORK_DIR/SHA256SUMS.txt"
case "$DIGEST" in
  ''|*[!0-9a-fA-F]*) echo "Missing or invalid acs SHA-256 checksum." >&2; exit 1 ;;
esac
if [ "${#DIGEST}" -ne 64 ]; then
  echo "Invalid acs SHA-256 checksum length." >&2
  exit 1
fi
printf '%s  %s\n' "$DIGEST" "$WORK_DIR/acs" | sha256sum -c || {
  echo "SHA-256 verification failed for acs." >&2
  exit 1
}
chmod 0755 "$WORK_DIR/acs"
# Validate the executable before replacing an existing installation.
"$WORK_DIR/acs" --help
mkdir -p /usr/local/bin
install -m 0755 "$WORK_DIR/acs" /usr/local/bin/acs
/usr/local/bin/acs --help
