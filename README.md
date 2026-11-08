# nightcore-www-ffmpeg-wasm

Custom `ffmpeg-core` WebAssembly build for
[nightcore.py ★ web edition](https://nightcore.lusosterone.net/).

## Build

```sh
./build.sh            # ends up in build/ffmpeg-core.js + build/ffmpeg-core.wasm
NONFREE=1 ./build.sh  # adds FDK-AAC (non redistributable)
```

## License

This project is licensed under the **GNU Affero General Public License v3.0 or later** (AGPL-3.0-or-later) - see the [LICENSE](LICENSE) file for details.

[![AGPL-3.0](https://www.gnu.org/graphics/agplv3-with-text-162x68.png)](https://www.gnu.org/licenses/agpl-3.0.html)

### Third-party components

- **FFmpeg** (https://ffmpeg.org) - GPLv2 or later. This build
  enables `--enable-gpl` (required by librubberband), so the linked
  core is GPL. Source: https://github.com/FFmpeg/FFmpeg
- **Rubber Band Library** (https://breakfastquay.com/rubberband) -
  GPLv2. Source included via the release tarballs in the build.
- **LAME** (MP3 encoding) - LGPLv2
- **Opus** - BSD-3-Clause
- **libogg** - BSD-3-Clause
- **libsoxr** (SoX Resampler) - LGPLv2.1
- **zlib** - zlib license
- **Emscripten** - MIT (build tool only, not shipped)
- **FDK-AAC** (optional, only with `NONFREE=1`) - non-free,
  non-redistributable
