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
