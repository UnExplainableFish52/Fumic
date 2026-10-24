# Fumic - Magical Media Player

Fumic is a free, open-source music and video player for Windows, built with Flutter and Dart. It plays the files on your computer, with keyboard shortcuts, playlists, and a customizable visualizer. No account or internet connection is needed for playback.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078D6?logo=windows)](https://github.com/UnExplainableFish52/Fumic)
[![Built with Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)

## Download

Get [Fumic 2.6.4 for Windows x64](https://github.com/UnExplainableFish52/Fumic/releases/tag/v2.6.4), or browse [all releases](https://github.com/UnExplainableFish52/Fumic/releases).

| Download | How to use it |
| --- | --- |
| `Fumic-Setup-2.6.4-windows-x64.exe` | Run the installer to install Fumic. |
| `Fumic-2.6.4-windows-x64-portable.zip` | Extract the ZIP, then run `fumic.exe` from the extracted folder. Keep the other files alongside it. |
| `SHA256SUMS.txt` | SHA-256 checksums for verifying the downloads. |

See the [2.6.4 release notes](docs/RELEASE_NOTES_2.6.4.md) for the latest changes.

## Features

- **Local music and video:** Play audio and video through `media_kit`, with metadata and embedded cover art where available.
- **Folder-based library:** Scan your Music and Videos folders, add other folders, search your library, and refresh it when files change.
- **Playlists:** Create and rename playlists, add tracks, and keep favourites in the built-in `Favourites` playlist.
- **Playback controls:** Seek, shuffle the queue, loop the current track, adjust volume, and change playback speed from 0.5× to 3×.
- **Keyboard shortcuts:** Control playback, browse the library, manage playlists, and switch views from the keyboard.
- **Customizable appearance:** Choose a bundled wallpaper or import your own image, adjust background and card opacity, and show or hide center artwork.
- **Visualizer and full player:** Adjust visualizer quality, particles, glow, and intensity. Let player controls hide automatically, hide them manually, or use a wallpaper-only view.
- **Background playback:** Minimize Fumic while music keeps playing. Visualizer animation stops and playback-driven UI updates are reduced while the app is inactive or minimized.
- **Local storage:** Settings, playlists, library paths, and artwork caches stay on your device. Fumic has no ads, analytics, telemetry, or cloud sync.

## Getting started

1. Open Fumic. On first launch, it looks for media in your Windows Music and Videos folders.
2. Use **Add folder** in the library or under **Settings > Library** to include other folders.
3. Select a track or video and press `Ctrl + Enter` to play it. Use `Ctrl + K` to search and `Ctrl + R` to refresh the library.
4. Press `F` or `E` to switch between the library and the full player. Use `F11` to toggle window fullscreen.

### Media formats

The library scanner recognizes these file extensions:

| Audio | Video |
| --- | --- |
| AAC, AIF, AIFF, ALAC, FLAC, M4A, M4B, MP3, OGA, OGG, OPUS, WAV, WMA | AVI, M4V, MKV, MOV, MP4, WEBM, WMV |

Playback depends on the codecs inside each file and support in the bundled playback engine.

## Keyboard shortcuts

These shortcuts work while Fumic has keyboard focus. Most playback shortcuts are disabled while typing in search or an editor.

| Shortcut | Action |
| --- | --- |
| `Space` | Play or pause |
| `J` / `K` / `L` | Back 5 seconds / play or pause / forward 5 seconds |
| `Ctrl + Enter` | Play selected media |
| `Ctrl + B` in library / `Ctrl + Shift + B` anywhere | Add selected or current media to a playlist |
| `Ctrl + K` | Focus search |
| `Ctrl + R` | Refresh the library |
| `Ctrl + A` / `Ctrl + V` | Switch to the audio or video tab |
| `Ctrl + H` | Go to Home |
| `Ctrl + P` | Go to Playlists |
| `Ctrl + S` | Go to Settings |
| `Ctrl + I` | Go to Info |
| `Left` / `Right` | Seek back or forward 5 seconds |
| `Shift + Left` / `Shift + Right` | Seek back or forward 10 seconds |
| `0`–`9` | Jump to 0%–90% of the current track or video |
| `Ctrl + Left` / `Ctrl + Right` | Previous or next track |
| `Ctrl + Up` / `Ctrl + Down` | Volume up or down |
| `Ctrl + M` | Mute or unmute |
| `Ctrl + N` in Playlists | Create playlist |
| `F2` in Playlists | Rename selected playlist |
| `Delete` in Playlists | Confirm delete selected playlist |
| `Enter` in Playlists | Play selected playlist |
| `Up` / `Down` in library or Playlists | Select the previous or next item |
| `Shift + S` | Toggle shuffle |
| `Shift + L` | Toggle looping the current track |
| `Shift + ,` / `Shift + .` | Decrease or increase playback speed |
| `F` / `E` / `Ctrl + F` / `Ctrl + E` | Toggle the video or visualizer player and library |
| `Esc` in player | Return to the library, keeping the window fullscreen |
| `F11` / `Shift + F` | Toggle window fullscreen |
| `I` | Minimize Fumic to the taskbar |
| `B` / `Ctrl + B` in full player | Show or hide full-player controls |
| `Ctrl + W` | Close Fumic |

The **Keyboard Shortcuts** reference on the Info page (`Ctrl + I`) lists additional visualizer controls.

### Full player and wallpapers

Full-player controls hide after 5 seconds of inactivity by default. Moving the pointer, touching the player, or using a playback shortcut shows them again. Change the delay or disable automatic hiding in **Settings > Playback > Full player controls**. Controls hidden manually with `B` stay hidden until you restore them with `B`, `Ctrl + B` in the full player, or the setting. The library's playback controls stay visible.

For music with just a wallpaper, turn off **Settings > Visualizer > Enable visualizer effects**, open the full player with `F` or `E`, and hide the controls with `B`. To keep the effects but remove the center cover or logo, turn off **Settings > Appearance > Center artwork**. **Background opacity** adjusts wallpaper dimming independently.

## Build from source

The current release targets Windows x64.

### Requirements

- Windows 10 or Windows 11.
- Flutter with Windows desktop support and Dart 3.9.2 or later, compatible with the SDK constraint in `pubspec.yaml`.
- Visual Studio or Visual Studio Build Tools with the **Desktop development with C++** workload.

### Development

```powershell
flutter pub get
flutter run -d windows
```

### Release build

```powershell
flutter build windows --release --build-name=2.6.4 --build-number=0
```

The Windows release output is generated in:

```text
build\windows\x64\runner\Release
```

Distribute the complete release folder: `fumic.exe` needs the accompanying `data` folder and runtime DLLs. See the [public release guide](docs/PUBLIC_RELEASE_GUIDE.md) for installer, portable ZIP, and Microsoft Store packaging instructions.

## Privacy

Fumic processes your library on your computer and does not automatically send your media, file paths, playlists, or usage activity to the developer. See the [privacy policy](docs/PRIVACY_POLICY.md) for details about local storage, external links, and support requests.

## Contributing

Bug reports, feature suggestions, UI feedback, documentation improvements, and pull requests are welcome. Use [GitHub Issues](https://github.com/UnExplainableFish52/Fumic/issues) to report a problem or suggest a change. For bugs, include your Fumic version, Windows version, and steps to reproduce the issue.

1. Fork the repository.
2. Create a feature branch.
3. Make a focused change.
4. Test the app and run `flutter analyze` and `flutter test`.
5. Open a pull request.

## License

Fumic is licensed under the [GNU General Public License v3.0](LICENSE).

## Contact

- GitHub: [UnExplainableFish52](https://github.com/UnExplainableFish52)
- Email: sharma@saksham.info.np
- Email: contactsaksham52@gmail.com
- Email: info@sakshamsharma.com.np
