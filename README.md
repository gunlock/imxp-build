# imxp-build

**A cross-platform C++ build scaffold for X-Plane 11/12 plugins with integrated Dear ImGui**

Build once from any Linux host and produce plugins for all three platforms:

| Platform | Output |
|----------|--------|
| Linux x86_64 | `MyPlugin/lin_x64/MyPlugin.xpl` |
| Windows x86_64 | `MyPlugin/win_x64/MyPlugin.xpl` |
| macOS (universal) | `MyPlugin/mac_x64/MyPlugin.xpl` |

## Prerequisites

- **Linux** host build environment
- **Docker** (for cross-compilation)
- **CMake** >= 3.25 and **Ninja** (for local dev preset configuration)

## Setup

Copy the example presets file and edit it for your environment:

```bash
cp CMakeUserPresets.json.example CMakeUserPresets.json
```

Edit `CMakeUserPresets.json` and set `XPLANE_PLUGIN_DIR` to your X-Plane plugins directory:

```json
"XPLANE_PLUGIN_DIR": "/path/to/X-Plane 11/Resources/plugins"
```

This file is git-ignored so your local paths stay out of version control.

## Available Presets

### Quick Start

```bash
cmake --preset config                  # cmake configure step
cmake --build --preset local:build     # build linux-x64 via Docker
cmake --build --preset local:install    # build & local plugin install
```

### Local Development

These presets build for linux-x64 via *Docker*, then deploy and install locally:

```bash
cmake --build --preset local:build      # build linux-x64 via Docker
cmake --build --preset local:deploy     # assemble plugin directory
cmake --build --preset local:install    # build & local plugin install
```

### Release

These presets manage the Docker build environment and cross-compilation:

```bash
cmake --build --preset docker:deploy         # cross-compile all platforms + zip
cmake --build --preset docker:rebuild-image  # rebuild the Docker image
cmake --build --preset docker:clean-image    # remove the Docker image
```

`docker:deploy` produces the final plugin directory and zip archive under `build/docker/deploy/`.

## Project Structure

```
├── CMakeLists.txt                  # Build configuration (X-Plane SDK + ImGui)
├── CMakePresets.json               # Cross-compilation presets (Docker/Zig)
├── CMakeUserPresets.json.example   # Local dev presets template
├── Dockerfile                      # Build environment (Ubuntu + Zig + CMake)
├── scripts/
│   └── build-all.sh               # Cross-compile all platforms (runs in Docker)
├── cmake/
│   └── toolchains/                # Zig cross-compilation toolchains
├── src/
│   └── main.cpp                   # Plugin entry point (X-Plane API)
└── .github/
    └── workflows/
        └── release.yml            # GitHub Actions: tag -> build -> release
```

## Customizing

1. **Rename the plugin**: search and replace `MyPlugin` / `myplugin` / `MYPLUGIN` across all files
2. **Add source files**: add them to the `SRC_FILES` list in `CMakeLists.txt`
3. **Add dependencies**: use `FetchContent` in `CMakeLists.txt` (see the ImGui example)
4. **Add resources**: copy them in the `deploy` target in `CMakeLists.txt`

## Releasing

Push a version tag to trigger the GitHub Actions workflow:

```bash
git tag v0.1.0
git push origin v0.1.0
```

This builds all platforms via Docker and creates a GitHub Release with the plugin zip.

## How It Works

- **Zig** is used as a drop-in C/C++ cross-compiler, targeting Linux (glibc 2.17), Windows (MinGW), and macOS (x86_64 + arm64)
- **llvm-lipo** creates a macOS universal binary from the two architecture builds
- **Docker** ensures a reproducible build environment regardless of the host OS
- The X-Plane SDK and Dear ImGui are fetched automatically via CMake's `FetchContent`
