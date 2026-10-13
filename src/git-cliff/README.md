
# git-cliff (git-cliff)

Installs git-cliff from SHA-512 verified upstream releases for amd64 and arm64 Linux containers (glibc or musl).

## Example Usage

```json
"features": {
    "ghcr.io/opendreamnet/devcontainer-features/git-cliff:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| gitCliffVersion | Stable git-cliff version in x.y.z format, without a v prefix. Requires an upstream Linux musl archive and SHA-512 checksum. | string | 2.14.2 |
| installDependencies | Install Git, CA certificates, curl and archive/checksum tools using apt, apk, dnf, microdnf or yum. Disable only on pre-provisioned images. | boolean | true |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/opendreamnet/devcontainer-features/blob/main/src/git-cliff/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
