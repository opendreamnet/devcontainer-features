
# UPX (upx)

Installs UPX from verified official Linux releases.

## Example Usage

```json
"features": {
    "ghcr.io/opendreamnet/devcontainer-features/upx:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| upxVersion | Stable UPX release version in x.y.z format. The release must publish a Linux archive with a GitHub SHA-256 digest. | string | 5.2.1 |
| installDependencies | Install curl, jq and xz utilities required to download and verify UPX. On Arch Linux this performs a full system upgrade. Disable only on pre-provisioned images. | boolean | true |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/opendreamnet/devcontainer-features/blob/main/src/upx/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
