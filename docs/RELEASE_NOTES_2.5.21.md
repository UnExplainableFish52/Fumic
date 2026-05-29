# Fumic 2.5.21 - Flutter Public Release

Fumic `2.5.21` is the current public release of the Flutter generation of Fumic.

The version number is intentional:

- `2` marks the Flutter generation of the app.
- `5.21` marks the May 21 release session.
- `2521` is the internal Windows build number.

## What Is Fumic?

Fumic is an offline-first, keyboard-first desktop media player built for people who want a fast local music and video experience without accounts, paywalls, streaming lock-in, or unnecessary bloat.

It is built out of frustration with heavy media apps and love for clean software.

## Highlights

- Rebuilt as a Flutter desktop app for Windows.
- Local audio and video playback.
- Keyboard-first app navigation and playback controls.
- Full-window startup experience with fullscreen support.
- Ctrl+W app close shortcut.
- Audio/video tabs with local library scanning.
- Metadata cache for faster library reloads.
- Cover art extraction for MP3, OPUS, OGG/OGA, FLAC, and other supported formats.
- OPUS embedded artwork support through Vorbis-style metadata handling.
- Playback speed options from slow playback up to 3.0x.
- Shuffle, loop, seek, volume, mute, and track navigation controls.
- Playlist playback now advances through the full queue instead of stopping after one song, including when shuffle is enabled.
- Loop starts off by default; enabling loop repeats the current track intentionally.
- Performance visualizer mode for lower CPU use.
- Stylistic visualizer mode with center artwork and audio-reactive visuals.
- Polished Settings and Info pages.
- Searchable keyboard shortcuts section.
- Cleaner dark desktop UI with a lightweight premium feel.

## Install Options

### Recommended

Download:

```text
Fumic-Setup-2.5.21-windows-x64.exe
```

Run the setup file and follow the installer.

### Portable

Download:

```text
Fumic-2.5.21-windows-x64-portable.zip
```

Extract the ZIP, then run:

```text
Fumic.exe
```

Do not run the EXE directly from inside the ZIP archive. Extract the folder first.

## Windows SmartScreen Note

Because this is a new public Windows release, some users may see a Windows SmartScreen or "unrecognized app" warning, especially if the installer is not code-signed yet.

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

Fumic is intended to be released under:

```text
GNU General Public License v3.0
```

In simple terms:

- You can use it.
- You can modify it.
- You can share it.
- You cannot turn it into a closed proprietary redistribution.

Before publishing publicly, make sure a real `LICENSE` file containing GPLv3 is present in the repository root.

## Feedback And Contributions

Repository:

```text
https://github.com/UnExplainableFish52/Fumic
```

Feedback, bug reports, UI/UX suggestions, documentation improvements, and pull requests are welcome.

Contact:

```text
sharma@saksham.info.np
contactsaksham52@gmail.com
info@sakshamsharma.com.np
```

Website contact form:

```text
https://sakshamsharma.com.np/#contact
```
