# Fumic Tech Stack

Fumic is a Flutter desktop media player built for Windows first. It is no longer an Electron app. The current version is designed around a native-feeling desktop UI, local media playback, offline library scanning, keyboard-first navigation, and a lightweight release footprint.

## Short Answer

If someone asks what Fumic is built with, say:

> Fumic is built with Flutter and Dart for the desktop UI, media_kit for audio/video playback, local Dart services for scanning and metadata, Flutter CustomPainter for the visualizer, and a small native Windows C++ runner layer for fullscreen/window behavior.

## Main Stack

| Layer | Technology | Why it is used |
| --- | --- | --- |
| UI framework | Flutter | Fast native desktop UI, consistent design system, good animation/rendering performance, and lower overhead than Electron for this type of app. |
| Language | Dart | Clean app logic, async file/library scanning, Flutter integration, and maintainable state handling. |
| Playback engine | media_kit, media_kit_video, media_kit_libs_windows_video | Reliable audio/video playback on Windows with support for common local media formats. |
| Desktop platform | Flutter Windows runner | Native Windows desktop build output with app icon, version info, and release packaging support. |
| Native window behavior | C++ Win32 runner code | Used for fullscreen startup, F11 fullscreen toggle, and native close behavior such as Ctrl+W. |
| File picking | file_picker | Lets users choose local music/video folders without adding unnecessary platform-specific UI code. |
| Metadata/artwork | Dart services, media_kit metadata, custom embedded artwork extraction, image package | Handles duration, thumbnails, embedded cover art, OPUS/Vorbis comments, FLAC/MP3 artwork, and cached thumbnail files. |
| Local storage | path_provider, path, JSON files | Stores local settings, remembered library folders, metadata cache, artwork cache, and visualizer settings without a backend. |
| Visualizer | Flutter CustomPainter and app-side audio analysis | Keeps rendering efficient by painting to canvas instead of building hundreds of widgets every frame. |
| Tests/lints | flutter_test, flutter_lints | Keeps the app stable enough for a public release without adding heavy tooling. |

## Why Flutter Instead Of Electron

The first Fumic generation was Electron-based. The Flutter version exists because the project goal is a lightweight, no-nonsense desktop music player.

Flutter is a better fit here because:

- It avoids bundling a full Chromium browser just to render the interface.
- It gives a smoother native desktop feel with lower UI overhead.
- It has strong layout, theming, animation, and keyboard handling support.
- It can still integrate with native Windows code where needed.
- It produces a cleaner desktop app structure for a focused offline media player.

Electron is still useful for many apps, especially web-heavy tools, but Fumic does not need a browser-based runtime. It needs fast local UI, reliable playback, and a polished desktop experience.

## App Architecture

Fumic is organized into small Flutter/Dart layers:

- `lib/src/app`: application controller, routing, global shortcuts, and app shell behavior.
- `lib/src/models`: media models, playback speed options, page enums, and visualizer settings.
- `lib/src/services`: playback, scanning, metadata extraction, artwork extraction, settings persistence, and audio analysis.
- `lib/src/widgets`: home library, top bar, settings page, info page, player controls, visualizer, and shared UI parts.
- `windows/runner`: native Windows host code for app startup and window behavior.

The main design idea is simple: keep playback and scanning in services, keep visual UI in widgets, and keep Windows-specific behavior in the Windows runner.

## Important Dependencies

### media_kit

Fumic uses the media_kit package family for playback instead of manually wrapping native audio/video APIs. This keeps playback support practical and maintainable while still giving the app desktop-quality media handling.

### file_picker

Used for choosing folders and files from the local machine. Fumic is offline-first, so local file access is a core workflow.

### image

Used for image/artwork processing where needed, especially around extracted embedded artwork and cached thumbnails.

### path and path_provider

Used for safe platform-aware file paths and local application support directories.

## Offline-First Choices

Fumic intentionally avoids:

- Cloud accounts
- Streaming accounts
- Telemetry
- Online library sync
- Remote metadata dependency

This keeps the app fast, private, and usable without internet access.

## Current Release Identity

Current release version:

```text
2.6.2+262
```

Meaning:

- `2.6.2`: current public Flutter release version.
- `262`: Windows build number used by Flutter.

## How To Explain Fumic To Developers

Use this:

> Fumic is a Flutter Windows desktop app using Dart for the application layer, media_kit for local audio/video playback, custom Dart services for metadata and artwork extraction, and a small native Win32 runner layer for fullscreen/window control. The UI is built as a keyboard-first dark desktop app with local JSON settings and cache files, no backend, no account system, and no web runtime.

## Source References

- Flutter Windows deployment: https://docs.flutter.dev/deployment/windows
- Flutter Windows build path: https://docs.flutter.dev/release/breaking-changes/windows-build-architecture
- Flutter Windows platform integration: https://docs.flutter.dev/platform-integration/windows/building
