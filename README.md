# OpenDreamnet Dev Container Features

A collection of reusable features for installing the tools the company needs in its development containers. Each feature includes its installer, options, and tests.

## Usage

Add features to `.devcontainer/devcontainer.json`:

```json
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/opendreamnet/devcontainer-features/tatr:1": {
      "tatrVersion": "main",
      "runTests": false
    },
    "ghcr.io/opendreamnet/devcontainer-features/git-cliff:1": {
      "gitCliffVersion": "2.14.2"
    }
  }
}
```

This example requires the feature to be published and accessible on GHCR. Use `:1` to track a major version or an exact version, such as `:1.1.0`, to pin the feature. The tool revision is configured separately; for `tatr`, use a full SHA in `tatrVersion` to pin the source code.

## Features

| Feature | Description | Options |
| --- | --- | --- |
| [tatr](src/tatr) | Builds and installs tsoding's task tracker on Linux. | [Metadata and defaults](src/tatr/devcontainer-feature.json) |
| [upx](src/upx) | Installs UPX from verified upstream Linux releases. | [Metadata and defaults](src/upx/devcontainer-feature.json) |
| [git-cliff](src/git-cliff) | Installs git-cliff from SHA-512 verified Linux releases for generating changelogs. | [Metadata and defaults](src/git-cliff/devcontainer-feature.json) |

The `git-cliff` feature supports amd64 and arm64 Linux containers using upstream static musl binaries on both glibc and musl images. Its default tool version is `2.14.2`; set `gitCliffVersion` to pin another stable release. Dependency installation supports Debian/Ubuntu, Alpine, Fedora, Rocky Linux and Amazon Linux package managers. Set `installDependencies` to `false` only when Git, CA certificates and the download/archive/checksum tools are already available. The feature installs the tool only; it does not create `cliff.toml` or modify your repository's changelog.

## Development

- `src/<id>/`: `devcontainer-feature.json`, `install.sh`, and any files needed to install the feature.
- `test/<id>/`: `test.sh`, `scenarios.json`, and one script per scenario.
- `.github/workflows/`: publishing to GHCR and generating per-feature documentation.
- `.devcontainer/`: the repository's development environment.

Requires a working Docker installation and the [Dev Container CLI](https://github.com/devcontainers/cli), which is installed automatically in the repository's devcontainer. Outside that environment:

```sh
npm install -g @devcontainers/cli
```

From the repository root, run tests for one feature or the entire collection:

```sh
devcontainer features test --project-folder . --features tatr --skip-duplicated
devcontainer features test --project-folder . --skip-duplicated
```

See [AGENTS.md](AGENTS.md) for instructions on adding features. The configured workflows run on pushes to `main` or manual dispatch; they do not currently run tests.

## References

- [Features specification](https://containers.dev/implementors/features/).
- [Official reference collection](https://github.com/devcontainers/features).
- The repository's [MIT license](LICENSE); installed tools retain their own licenses.
