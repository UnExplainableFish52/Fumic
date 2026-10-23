# Fumic - Magical Media Player

**Fumic - Magical Media Player is an open-source, offline-first, keyboard-driven media player for Windows, now built with Flutter.**

Fumic is made for people who want a fast local music and video player without accounts, ads, telemetry, streaming lock-in, or unnecessary background services. The current actively maintained Fumic media player is the Flutter version, focused on responsive Windows playback, keyboard-first navigation, playlists, local artwork, and a clean desktop interface.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078D6?logo=windows)](https://github.com/UnExplainableFish52/Fumic)
[![Built with Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)

## Download

Download the latest Flutter-based Windows release from GitHub Releases:

https://github.com/UnExplainableFish52/Fumic/releases

For normal users, use the Windows setup installer when it is available. The portable ZIP is useful if you prefer to extract the app manually and run `fumic.exe` directly from the extracted folder.

## Electron Version Deprecated

Note: Fumic was previously built with Electron, but the Electron version is now deprecated and no longer actively maintained. Current and future releases are Flutter-based. For the best performance, latest features, and actively maintained version, download the latest Flutter release from GitHub Releases.

The Electron history is still part of the project, but it is no longer the recommended app for users. The Flutter media player is more efficient, more optimized for this project, and receives the newest Fumic features.

## Features

- Open-source media player for Windows, licensed under GPLv3.
- Offline-first media player behavior with local library scanning and no account requirement.
- Keyboard-driven media player controls for playback, navigation, search, volume, playlists, and fullscreen workflows.
- Flutter desktop interface designed for a responsive native-feeling Windows media player experience.
- Local audio and video playback through `media_kit`.
- Playlist support with a protected `Favourites` playlist and user-created playlists.
- Custom visualizer background options and local app settings.
- Artwork and metadata handling for common local media formats.
- Shuffle, loop, seek, mute, playback speed, and queue navigation.
- No ads, no telemetry, and no cloud sync requirement.

## Keyboard Shortcuts

Fumic is designed around fast keyboard use. Common shortcuts include:

| Shortcut | Action |
| --- | --- |
| `Space` | Play or pause |
| `J` / `K` / `L` | Back 5 seconds / play or pause / forward 5 seconds |
| `Ctrl + Enter` | Play selected media |
| `Ctrl + B` in library / `Ctrl + Shift + B` anywhere | Add selected or current media to a playlist |
| `Ctrl + K` | Focus search |
| `Ctrl + H` | Go to Home |
| `Ctrl + P` | Go to Playlists |
| `Ctrl + S` | Go to Settings |
| `Ctrl + I` | Go to Info |
| `Left` / `Right` | Seek |
| `Ctrl + Left` / `Ctrl + Right` | Previous or next track |
| `Ctrl + Up` / `Ctrl + Down` | Volume up or down |
| `Ctrl + M` | Mute or unmute |
| `Ctrl + N` in Playlists | Create playlist |
| `F2` in Playlists | Rename selected playlist |
| `Delete` in Playlists | Confirm delete selected playlist |
| `Enter` in Playlists | Play selected playlist |
| `Up` / `Down` in Playlists | Move selected playlist |
| `Shift + S` | Toggle shuffle |
| `Shift + L` | Toggle loop |
| `F` / `E` / `Ctrl + F` / `Ctrl + E` | Toggle the video or visualizer player and library |
| `Esc` in player | Return to the library, keeping the window fullscreen |
| `F11` / `Shift + F` | Toggle window fullscreen |
| `I` | Minimize Fumic to the taskbar |
| `B` / `Ctrl + B` in full player | Show or hide full-player controls; Home player stays visible |
| `Ctrl + W` | Close Fumic |

Full-player controls hide after 5 seconds without activity. Moving the pointer,
touching the player, or using a playback shortcut shows them again. In
**Settings > Playback > Full player controls**, you can choose the delay, disable
automatic hiding, or restore controls hidden with `B`. Manually hidden controls
stay hidden until enabled with `B`, `Ctrl+B` in the full player, or in Settings. Shortcuts apply while Fumic
has keyboard focus; use its taskbar icon or Alt+Tab to restore a minimized app.

For music with just the wallpaper, turn off **Settings > Visualizer > Enable
visualizer effects**, open the full player with `F` or `E`, and hide the controls
with `Ctrl+B`. Turning off **Appearance > Center artwork** also removes the
center cover/logo while effects are enabled. Background opacity controls the
wallpaper dimming independently.

## Build From Source

See the [release notes](docs/RELEASE_NOTES_2.6.3.md) for the current changes and
the [public release guide](docs/PUBLIC_RELEASE_GUIDE.md) for Windows packaging.

### Requirements

- Flutter with Windows desktop support enabled.
- Visual Studio Build Tools with the Desktop development with C++ workload.
- Windows 10 or Windows 11.

### Development

```powershell
flutter pub get
flutter run -d windows
```

### Release Build

```powershell
flutter build windows --release --build-name=2.6.3 --build-number=0
```

The Windows release output is generated in:

```text
build\windows\x64\runner\Release
```

That folder must be distributed as a complete folder or packaged into an installer/portable ZIP. Do not upload only `fumic.exe`; the Flutter Windows app also needs its `data` folder and runtime DLLs.

## Project Metadata

Suggested GitHub repository description:

```text
Fumic - Magical Media Player is an open-source, offline-first, keyboard-driven media player for Windows, now built with Flutter.
```

Natural search terms for this project include Fumic media player, Windows media player, Flutter media player, offline-first media player, keyboard-driven media player, and open-source media player.

## Contributing

Bug reports, feature suggestions, UI feedback, documentation improvements, and pull requests are welcome.

1. Fork the repository.
2. Create a feature branch.
3. Make a focused change.
4. Test the app.
5. Open a pull request.

## License

Fumic is intended to stay free and open source under the GNU General Public License v3.0.

## Contact

- GitHub: https://github.com/UnExplainableFish52
- Email: sharma@saksham.info.np
- Email: contactsaksham52@gmail.com
- Email: info@sakshamsharma.com.np
