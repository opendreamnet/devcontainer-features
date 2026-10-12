#!/bin/sh

set -eu

# Validate the installation environment and options before changing the image.
if [ "$(id -u)" -ne 0 ]; then
  echo "This feature must be installed as root." >&2
  exit 1
fi

if [ "$(uname -s)" != "Linux" ]; then
  echo "UPX currently supports Linux containers only." >&2
  exit 1
fi

UPX_VERSION="${UPXVERSION:-5.2.1}"
INSTALL_DEPENDENCIES="${INSTALLDEPENDENCIES-true}"

case "$UPX_VERSION" in
  ''|*[!0-9.]*|.*|*.|*..*|*.*.*.*)
    echo "upxVersion must be a stable version in x.y.z format (without a v prefix)." >&2
    exit 1
    ;;
  *.*.*) ;;
  *)
    echo "upxVersion must be a stable version in x.y.z format (without a v prefix)." >&2
    exit 1
    ;;
esac

case "$INSTALL_DEPENDENCIES" in
  true|false) ;;
  *) echo "installDependencies must be true or false." >&2; exit 1 ;;
esac

case "$(uname -m)" in
  x86_64|amd64) UPX_ARCH="amd64" ;;
  aarch64|arm64) UPX_ARCH="arm64" ;;
  *)
    echo "UPX release archives are currently supported for amd64 and arm64 Linux containers." >&2
    exit 1
    ;;
esac

# Install download, JSON and archive tools using the image's package manager.
if [ "$INSTALL_DEPENDENCIES" = "true" ]; then
  set -- ca-certificates curl jq tar
  if ! command -v install >/dev/null 2>&1 || ! command -v sha256sum >/dev/null 2>&1; then
    set -- "$@" coreutils
  fi

  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends "$@" xz-utils
    apt-get clean
    rm -rf /var/lib/apt/lists/*
  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache "$@" xz
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y --setopt=install_weak_deps=False "$@" xz
    dnf clean all
  elif command -v microdnf >/dev/null 2>&1; then
    microdnf install -y "$@" xz
    microdnf clean all
  elif command -v tdnf >/dev/null 2>&1; then
    tdnf install -y "$@" xz
    tdnf clean all
  elif command -v yum >/dev/null 2>&1; then
    yum install -y "$@" xz
    yum clean all
  elif command -v zypper >/dev/null 2>&1; then
    zypper --non-interactive install --no-recommends "$@" xz
    zypper --non-interactive clean --all
  elif command -v pacman >/dev/null 2>&1; then
    # Arch requires a full upgrade when refreshing package databases.
    pacman -Syu --needed --noconfirm "$@" xz
    pacman -Scc --noconfirm
  else
    echo "Unsupported package manager. Expected apt-get, apk, dnf, microdnf, tdnf, yum, zypper or pacman." >&2
    exit 1
  fi
fi

# Check tools even when dependency installation is disabled.
for tool in curl jq tar xz sha256sum install; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool. Install dependencies or set installDependencies=true." >&2
    exit 1
  fi
done

# Keep downloaded archives and extracted files temporary on all exit paths.
WORK_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

ARCHIVE="upx-${UPX_VERSION}-${UPX_ARCH}_linux.tar.xz"
API_URL="https://api.github.com/repos/upx/upx/releases/tags/v${UPX_VERSION}"
RELEASE_JSON="$(curl --fail --location --silent --show-error --retry 3 \
  --header 'Accept: application/vnd.github+json' "$API_URL")"

# GitHub's release API publishes a SHA-256 digest for each asset.
if ! ASSET_SHA256="$(printf '%s' "$RELEASE_JSON" | jq --exit-status --raw-output --arg name "$ARCHIVE" \
  'select(.draft == false and .prerelease == false) | .assets[] | select(.name == $name) | .digest | select(type == "string" and test("^sha256:[0-9a-f]{64}$")) | ltrimstr("sha256:")')"; then
  echo "UPX release v${UPX_VERSION} has no supported archive or SHA-256 digest for ${UPX_ARCH}." >&2
  exit 1
fi

ARCHIVE_PATH="$WORK_DIR/$ARCHIVE"
DOWNLOAD_URL="https://github.com/upx/upx/releases/download/v${UPX_VERSION}/${ARCHIVE}"
curl --fail --location --silent --show-error --retry 3 --output "$ARCHIVE_PATH" "$DOWNLOAD_URL"
printf '%s  %s\n' "$ASSET_SHA256" "$ARCHIVE_PATH" | sha256sum -c || {
  echo "SHA-256 verification failed for $ARCHIVE." >&2
  exit 1
}

tar -xJf "$ARCHIVE_PATH" -C "$WORK_DIR"
UPX_BINARY="$WORK_DIR/upx-${UPX_VERSION}-${UPX_ARCH}_linux/upx"
if [ ! -f "$UPX_BINARY" ]; then
  echo "The UPX archive did not contain the expected executable." >&2
  exit 1
fi

mkdir -p /usr/local/bin
install -m 0755 "$UPX_BINARY" /usr/local/bin/upx
/usr/local/bin/upx --version
