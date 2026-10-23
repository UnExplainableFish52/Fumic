# Fumic - Magical Media Player 2.6.2 - Release Notes

Fumic - Magical Media Player `2.6.2` is a small Windows release focused on playback polish and release cleanup. It keeps the new Home timer and video fullscreen behavior, then fixes the shuffle toggle so it no longer restarts the current song.

## What Is Fumic?

Fumic - Magical Media Player is an open-source, offline-first, keyboard-driven media player for Windows. It is built for local music and video playback without accounts, ads, telemetry, streaming lock-in, or unnecessary bloat.

## Changelog

- Added a small session timer in the Home header.
- Videos now open directly in the full-player view.
- `Ctrl+H` now returns to Home, and if you are already there it scrolls back to the top.
- Fixed audio selection getting out of sync after switching from video playback.
- Fixed shuffle so toggling it no longer jumps to the first item or restarts the current song.
- Added regression tests around playback selection, stale video/audio queues, `Ctrl+H`, and shuffle order behavior.

## Existing Flutter Highlights

- Current actively maintained Flutter Windows app.
- Local audio and video playback.
- Keyboard-first app navigation and playback controls.
- Playlist page with protected `Favourites` and user-created playlists.
- Add-to-playlist shortcut with `Ctrl+B`.
- Custom background support for the app and visualizer atmosphere.
- Full-window startup experience with fullscreen support.
- `Ctrl+W` app close shortcut.
- Audio/video tabs with local library scanning.
- Metadata cache for faster library reloads.
- Cover art extraction for supported media formats.
- Playback speed controls, shuffle, loop, seek, volume, mute, and track navigation.
- Performance visualizer mode and stylistic visualizer mode.
- Settings and Info pages with the current Flutter app identity.

## Fixes

- Fixed a mismatch where the highlighted song and the backend playback queue could drift after playing a video, returning to Audio, and selecting a song.
- Fixed Home playback controls so Play/Next starts from the currently highlighted audio item when the old backend queue belongs to another tab.
- Fixed `Ctrl+H` behavior so it is useful even when the user is already on Home.
- Preserved audio behavior while adding automatic full-player opening only for videos.
- Fixed shuffle toggling so it no longer jumps back to the first library item or restarts from the top of the list.

## Install Options

### Recommended Installer

Download:

```text
Fumic-Setup-2.6.2-windows-x64.exe
```

Run the setup file and follow the installer.

### Portable ZIP

Download:

```text
Fumic-2.6.2-windows-x64-portable.zip
```

Extract the ZIP, then run:

```text
fumic.exe
```

Do not run the EXE directly from inside the ZIP archive. Extract the folder first.

## Windows SmartScreen Note

Because this is a Windows desktop release from a small open-source project, some users may see a Windows SmartScreen or "unrecognized app" warning, especially if the installer is not code-signed yet.

Only download Fumic from the official GitHub release page:

```text
https://github.com/UnExplainableFish52/Fumic/releases
```

Future distribution improvements may include code signing and Microsoft Store publishing.

## Known Notes

- This release is Windows-first.
- The app is designed for local/offline media, not streaming accounts.
- Microsoft Store packaging is planned separately from the GitHub release flow.
- If a media file has corrupted or missing artwork, Fumic falls back to a clean default thumbnail.

## License

Fumic is intended to be released under the GNU General Public License v3.0.

Before publishing publicly, make sure a real `LICENSE` file containing GPLv3 is present in the repository root.
