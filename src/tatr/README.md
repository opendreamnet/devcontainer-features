
# tatr (tatr)

Builds and installs the tatr task tracker from tsoding/tatr on Linux using apt-get, apk, dnf, microdnf, yum, tdnf, zypper or pacman.

## Example Usage

```json
"features": {
    "ghcr.io/opendreamnet/devcontainer-features/tatr:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| tatrVersion | Git ref or commit to build from tsoding/tatr. Use a full commit SHA for a reproducible source revision. | string | main |
| installDependencies | Install the native C toolchain, libc headers, Git and CA certificates. Disable only on pre-provisioned images. Arch Linux performs a full upgrade to avoid partial upgrades. | boolean | true |
| runTests | Run upstream tests with nob -test before installing. The selected tatr revision must support this flag. | boolean | false |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/opendreamnet/devcontainer-features/blob/main/src/tatr/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
