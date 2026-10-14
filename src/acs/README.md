
# Agent Coding Standards CLI (acs)

Installs acs from SHA-256 verified upstream releases for amd64 Linux containers with glibc 2.38 or newer.

## Example Usage

```json
"features": {
    "ghcr.io/opendreamnet/devcontainer-features/acs:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| acsVersion | Stable CLI version in x.y.z format, without a v prefix. Requires upstream acs and SHA256SUMS.txt release assets. Independent of the rules version. | string | 0.1.0 |
| installDependencies | Install Git, CA certificates, curl and checksum/install tools using apt, dnf or microdnf. Disable only on pre-provisioned images. | boolean | true |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/opendreamnet/devcontainer-features/blob/main/src/acs/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
