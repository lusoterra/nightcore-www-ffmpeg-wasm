# nightcore-www-ffmpeg-wasm

Custom `ffmpeg-core` WebAssembly build for
[nightcore-www](https://git.lusosterone.net/lev/nightcore-www). Stock
`@ffmpeg/core` lacks the rubberband filter, so this adds exactly that
(`--enable-librubberband`) plus the SoX resampler (`--enable-libsoxr`,
selected via `aresample ...:resampler=soxr`), plus LAME MP3 and Opus
(fixed-point) encoding. Single-threaded: no COOP/COEP headers needed
on the server.

## Build

```sh
./build.sh            # ends up in build/ffmpeg-core.js + build/ffmpeg-core.wasm
NONFREE=1 ./build.sh  # adds FDK-AAC (see below)
```

Copy `build/ffmpeg-core.js` + `build/ffmpeg-core.wasm` into the
website's `public/core/` to ship them. Pinned versions live in
`versions.env` - bump those and rerun `build.sh` to update. The build
is idempotent: finished steps are marked in `prefix/` and skipped on
rerun.

## Notes

- Strict-minimum audio-only FFmpeg configure (see
  `ffmpeg-config.sh`): in `mp3/flac/m4a-aac/alac/ogg-vorbis/opus/wav/aiff`
  (+ cover art), out `opus/mp3/flac/alac`; filters: `asetrate` +
  `aresample=soxr` + `rubberband` (with `atempo` fallback) +
  `volume` anti-clip trim.
- `bridge/` holds the Emscripten glue (`bridge.c`, `prelude.js`) and
  the small patches `build.sh` applies (progress reporting, rerun
  state reset, soxr wasm sigmatch, rubberband CLI parity).

## Non-free variant

`NONFREE=1 ./build.sh` adds the FDK-AAC encoder
(`--enable-nonfree` + `--enable-libfdk-aac`). That binary is
non-redistributable - personal/local use only. It takes precedence as
a separate, incompatible build: it is not covered by the AGPL
licensing of this repository.

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

See [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) for upstream URLs.
Note: FFmpeg is built with `--enable-gpl`, and GPLv3 section 13
permits combining it with AGPLv3, so the redistributable core above
can be shipped as AGPL-3.0-or-later.
