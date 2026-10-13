#!/bin/sh
set -eu

# Validate the environment and options before modifying the image.
if [ "$(id -u)" -ne 0 ]; then
  echo "This feature must be installed as root." >&2
  exit 1
fi
if [ "$(uname -s)" != "Linux" ]; then
  echo "git-cliff currently supports Linux containers only." >&2
  exit 1
fi

GIT_CLIFF_VERSION="${GITCLIFFVERSION-2.14.2}"
INSTALL_DEPENDENCIES="${INSTALLDEPENDENCIES-true}"
case "$GIT_CLIFF_VERSION" in
  ''|*[!0-9.]*|.*|*.|*..*|*.*.*.*)
    echo "gitCliffVersion must be a stable version in x.y.z format (without a v prefix)." >&2
    exit 1 ;;
  *.*.*) ;;
  *)
    echo "gitCliffVersion must be a stable version in x.y.z format (without a v prefix)." >&2
    exit 1 ;;
esac
case "$INSTALL_DEPENDENCIES" in
  true|false) ;;
  *) echo "installDependencies must be true or false." >&2; exit 1 ;;
esac
case "$(uname -m)" in
  x86_64|amd64) ARCH="x86_64" ;;
  aarch64|arm64) ARCH="aarch64" ;;
  *) echo "git-cliff supports amd64 and arm64 Linux containers only." >&2; exit 1 ;;
esac

# Static musl releases also run on glibc images without a glibc version requirement.
if [ "$INSTALL_DEPENDENCIES" = "true" ]; then
  set -- ca-certificates git tar gzip
  if ! command -v curl >/dev/null 2>&1; then
    set -- "$@" curl
  fi
  if ! command -v install >/dev/null 2>&1 || ! command -v sha512sum >/dev/null 2>&1; then
    set -- "$@" coreutils
  fi
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends "$@"
    apt-get clean
    rm -rf /var/lib/apt/lists/*
  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache "$@"
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y --setopt=install_weak_deps=False "$@"
    dnf clean all
  elif command -v microdnf >/dev/null 2>&1; then
    microdnf install -y "$@"
    microdnf clean all
  elif command -v yum >/dev/null 2>&1 && ! command -v tdnf >/dev/null 2>&1; then
    yum install -y "$@"
    yum clean all
  else
    echo "Unsupported package manager. Expected apt-get, apk, dnf, microdnf or yum; otherwise preinstall dependencies and set installDependencies=false." >&2
    exit 1
  fi
fi
for tool in curl git tar gzip sha512sum install mktemp; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool. Install dependencies or set installDependencies=true." >&2
    exit 1
  fi
done

WORK_DIR="$(mktemp -d)"
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

ARCHIVE="git-cliff-${GIT_CLIFF_VERSION}-${ARCH}-unknown-linux-musl.tar.gz"
URL="https://github.com/orhun/git-cliff/releases/download/v${GIT_CLIFF_VERSION}/${ARCHIVE}"
curl --proto '=https' --proto-redir '=https' --fail --location --silent --show-error --retry 3 \
  --output "$WORK_DIR/$ARCHIVE" "$URL"
curl --proto '=https' --proto-redir '=https' --fail --location --silent --show-error --retry 3 \
  --output "$WORK_DIR/checksum" "$URL.sha512"

# Use only the digest, not paths from the remote checksum file.
read -r DIGEST _ < "$WORK_DIR/checksum"
case "$DIGEST" in
  ''|*[!0-9a-fA-F]*) echo "Invalid SHA-512 checksum for $ARCHIVE." >&2; exit 1 ;;
esac
if [ "${#DIGEST}" -ne 128 ]; then
  echo "Invalid SHA-512 checksum for $ARCHIVE." >&2
  exit 1
fi
printf '%s  %s\n' "$DIGEST" "$WORK_DIR/$ARCHIVE" | sha512sum -c || {
  echo "SHA-512 verification failed for $ARCHIVE." >&2
  exit 1
}
tar -xzf "$WORK_DIR/$ARCHIVE" -C "$WORK_DIR" "git-cliff-${GIT_CLIFF_VERSION}/git-cliff"
BINARY="$WORK_DIR/git-cliff-${GIT_CLIFF_VERSION}/git-cliff"
if [ ! -f "$BINARY" ] || [ -L "$BINARY" ]; then
  echo "The git-cliff archive did not contain the expected executable." >&2
  exit 1
fi
"$BINARY" --version
mkdir -p /usr/local/bin
install -m 0755 "$BINARY" /usr/local/bin/git-cliff
/usr/local/bin/git-cliff --version
