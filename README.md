# imxp-build

**A cross-platform C++ build scaffold for X-Plane 11/12 plugins with integrated Dear ImGui**

Build once from any Linux host and produce plugins for all three platforms:

| Platform          | Output                                  |
| ----------------- | --------------------------------------- |
| Linux x86_64      | `<PluginName>/lin_x64/<PluginName>.xpl` |
| Windows x86_64    | `<PluginName>/win_x64/<PluginName>.xpl` |
| macOS (universal) | `<PluginName>/mac_x64/<PluginName>.xpl` |

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

## Customization

All plugin identity is configured in one place — the top of `CMakeLists.txt`:

```cmake
set(PLUGIN_NAME "MyPlugin")
set(PLUGIN_VERSION "0.1.0")
set(PLUGIN_SIGNATURE "com.${PLUGIN_NAME}")
set(PLUGIN_DESC "${PLUGIN_NAME} v${PLUGIN_VERSION}")
set(IMGUI_FONT "Roboto-Medium.ttf")
```

These values propagate automatically to:

- **`config.h`** — Generated at build time from `src/config.h.in` via CMake's `configure_file()`. Provides `PLUGIN_NAME`, `PLUGIN_VERSION`, `PLUGIN_SIGNATURE`, `PLUGIN_DESC`, and `IMGUI_FONT` as preprocessor defines for use in source code.
- **Build scripts** (`scripts/build-all.sh`, `scripts/build-nomacos.sh`) — Receive the plugin name as a command-line argument from the CMake custom targets. Output directories and zip archives are named accordingly.
- **GitHub Actions** (`.github/workflows/release.yml`) — Extracts the plugin name from `CMakeLists.txt` at CI time, so the Docker image, build command, and release artifact are all derived automatically.

To customize your plugin, change `PLUGIN_NAME` and `PLUGIN_VERSION` in `CMakeLists.txt` — no other files need editing.

### Additional customization

1. **Add source files**: Add to the `SRC_FILES` list in `CMakeLists.txt`.
2. **Add dependencies**: Consider using `FetchContent` (see the ImGui example in `CMakeLists.txt`).
3. **Add resources**: Copy them in the `deploy` target.
4. **ImGui font**: The `IMGUI_FONT` options are part of the Dear ImGui source tree in its `./misc/fonts` directory.

## Available Presets

### Quick Start

```bash
cmake --preset config                  # cmake configure step
cmake --build --preset local:build     # build linux-x64 via Docker
cmake --build --preset local:install   # build & local plugin install
```

### Local Development

These presets build for linux-x64 via _Docker_, then deploy and install locally:

```bash
cmake --build --preset local:build      # build linux-x64 via Docker
cmake --build --preset local:deploy     # assemble plugin directory
cmake --build --preset local:install    # build & local plugin install
```

### Release

These presets manage the Docker build environment and cross-compilation:

```bash
cmake --build --preset docker:deploy           # cross-compile all platforms + zip
cmake --build --preset docker:deploy-nomacos   # cross-compile Linux & Windows only + zip
cmake --build --preset docker:rebuild-image    # rebuild the Docker image
cmake --build --preset docker:clean-image      # remove the Docker image
```

`docker:deploy` produces the final plugin directory and zip archive under `build/docker/deploy/`.

`docker:deploy-nomacos` does the same but skips macOS.

## Project Structure

```
├── CMakeLists.txt                  # Build configuration (X-Plane SDK + ImGui)
├── CMakePresets.json               # Cross-compilation presets (Docker/Zig)
├── CMakeUserPresets.json.example   # Local dev presets template
├── Dockerfile                      # Build environment (Ubuntu + Zig + CMake)
├── scripts/
│   ├── build-all.sh               # Cross-compile all platforms (runs in Docker)
│   └── build-nomacos.sh           # Cross-compile Linux & Windows (runs in Docker)
├── cmake/
│   └── toolchains/                # Zig cross-compilation toolchains
├── src/
│   ├── config.h.in                # Generated config template (plugin name, version, etc.)
│   └── main.cpp                   # Plugin entry point (X-Plane API)
└── .github/
    └── workflows/
        └── release.yml            # GitHub Actions: tag -> build -> release
```

## Releasing

Push a version tag to trigger the GitHub Actions workflow:

```bash
git tag v0.1.0
git push origin v0.1.0
```

This builds all platforms via Docker and creates a GitHub Release with the plugin zip.

## How It Works

- **Zig** is used as a drop-in C/C++ cross-compiler, targeting Linux (glibc 2.17), Windows, and macOS (x86_64 + arm64)
- **llvm-lipo** creates a macOS universal binary from the two architecture builds
- **Docker** ensures a reproducible build environment regardless of the host OS
- The X-Plane SDK and Dear ImGui are fetched automatically via CMake's `FetchContent`
