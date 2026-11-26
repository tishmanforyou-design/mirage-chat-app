# Mirage Chat App (Offline On-Device Flutter VLM)

A standalone, dark-mode ChatGPT-style Flutter mobile app running [Cactus Compute's Mirage](https://huggingface.co/Cactus-Compute/mirage) (`mirage.cact`, 21.6 MB 2-bit quantized vision-language model) completely offline on-device using `dart:ffi` and the [Cactus 4.x native C/C++ runtime](https://huggingface.co/Cactus-Compute/cactus).

## Why `dart:ffi` + Cactus 4.x instead of `pub.dev/packages/cactus`?
- The legacy [`cactus`](https://pub.dev/packages/cactus) Flutter plugin (`v1.3.0`, [`cactus-compute/cactus-flutter`](https://github.com/cactus-compute/cactus-flutter)) was **archived on July 24, 2026** and predates Mirage (released November 2026).
- Mirage runs on the unified **Cactus 4.x runtime** (`libcactus.a` + `cactus.h` from [`Cactus-Compute/cactus`](https://huggingface.co/Cactus-Compute/cactus)), exposing `cactus_set_threads`, `cactus_load`, and `cactus_describe`.
- This project wires a lightweight C wrapper (`android/app/src/main/cpp/mirage_ffi.c`) directly to Flutter via `dart:ffi` inside a background `Isolate` so UI scrolling stays smooth at 60 fps.

## Quick Start (One-Command Setup & Release APK Build)

```bash
chmod +x setup_and_build.sh
./setup_and_build.sh
```

`setup_and_build.sh` automatically:
1. Scaffolds any missing Flutter Android/iOS runner files (`flutter create .`).
2. Downloads `libcactus.a` and `cactus.h` (`android-arm64`, `android-armv7`) from [`Cactus-Compute/cactus`](https://huggingface.co/Cactus-Compute/cactus).
3. Downloads `mirage.cact` (21.6 MB) from [`Cactus-Compute/mirage`](https://huggingface.co/Cactus-Compute/mirage) into `assets/models/mirage.cact` for 100% offline bundling.
4. Runs `flutter pub get` and `flutter analyze`.
5. Builds the Android release APK (`build/app/outputs/flutter-apk/app-release.apk`).

## iOS Setup
1. Download `ios-arm64/libcactus.a` and `ios-arm64/cactus.h` from [`Cactus-Compute/cactus`](https://huggingface.co/Cactus-Compute/cactus).
2. Add `mirage_ffi.c`, `mirage_ffi.h`, `cactus.h`, and `libcactus.a` to your `ios/Runner` Xcode target and link `libc++.tbd`.
3. Add the camera and photo library usage descriptions from `ios/INFO_PLIST_KEYS.xml` into `ios/Runner/Info.plist`.
4. Run `cd ios && pod install && cd .. && flutter run --release`.

## Features
- **100% Offline Inference**: Bundles `mirage.cact` in app assets and caches it locally on first launch (with optional first-launch download fallback if omitted from assets).
- **Dark-Mode ChatGPT-Style UI**: Scrollable history with user image thumbnails, latency pill (`ms • On-device`), bounding-box overlay toggle, raw JSON toggle, and one-tap copy.
- **Camera & Gallery Capture**: Powered by `image_picker` with EXIF orientation correction and 1024px downscaling before RGB24 conversion.
- **Quick-Action Preset Chips**: *Describe Scene*, *Extract Text (OCR)*, *Detect Objects*, *Spatial Relations*, and *Full Analysis*.
