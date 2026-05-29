# Fumic

**Fumic is an open-source, offline-first, keyboard-driven media player for Windows, built with Flutter.**

Fumic is for people who want a fast local music and video player without accounts, ads, telemetry, streaming lock-in, or unnecessary background services. The current actively maintained Fumic media player is the Flutter version, focused on responsive Windows playback, keyboard-first navigation, playlists, local artwork, and a clean desktop interface.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078D6?logo=windows)](https://github.com/UnExplainableFish52/Fumic)
[![Built with Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)

## About

Fumic is a desktop media player designed around speed, clarity, and keyboard control. It focuses on local playback and keeps the app offline-first with no telemetry or cloud dependency.

## Features

- Open-source media player for Windows, licensed under GPLv3.
- Offline-first behavior with local library scanning and no account requirement.
- Keyboard-driven controls for playback, navigation, search, volume, playlists, and fullscreen workflows.
- Flutter desktop UI for a responsive native-feeling Windows media player experience.
- Local audio and video playback through `media_kit`.
- Playlist support with a protected `Favourites` playlist and user-created playlists.
- Custom visualizer background options and local app settings.
- Artwork and metadata handling for common local media formats.
- Shuffle, loop, seek, mute, playback speed, and queue navigation.
- No ads, no telemetry, and no cloud sync requirement.

## Install

1. Open the GitHub Releases page and look at the right sidebar for the latest release.
2. Click the latest release, scroll down, and download the Windows installer or portable ZIP.
3. If your OS is not listed in the release assets, build the app from source instead.

Releases: https://github.com/UnExplainableFish52/Fumic/releases

After installation, review the keyboard shortcuts below to navigate quickly.

By default, Fumic scans your Windows Music and Videos folders for media files. You can change this in Settings and add multiple folders.

## Keyboard Shortcuts

Fumic is designed around fast keyboard use. Common shortcuts include:

| Shortcut | Action |
| --- | --- |
| `Space` | Play or pause |
| `Ctrl + Enter` | Play selected media |
| `Ctrl + B` | Add selected or current media to a playlist |
| `Ctrl + K` | Focus search |
| `Ctrl + H` | Go to Home |
| `Ctrl + A` | Go to Audio |
| `Ctrl + V` | Go to Video |
| `Ctrl + P` | Go to Playlists |
| `Ctrl + S` | Go to Settings |
| `Ctrl + E` | Go to Equalizer |
| `Ctrl + I` | Go to Info |
| `Left` / `Right` | Seek backward or forward 5 seconds |
| `Shift + Left` / `Shift + Right` | Seek backward or forward 10 seconds |
| `Ctrl + Left` / `Ctrl + Right` | Previous or next track |
| `Ctrl + Up` / `Ctrl + Down` | Volume up or down |
| `Ctrl + M` | Mute or unmute |
| `Shift + S` | Toggle shuffle |
| `Shift + L` | Toggle loop |
| `Shift + <` / `Shift + >` | Cycle playback speed |
| `Ctrl + F` | Toggle fullscreen player |
| `Ctrl + W` | Close Fumic |
| `Esc` | Exit focus on current control |

## Build From Source

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
flutter build windows --release --build-name=2.6.2 --build-number=262
```

The Windows release output is generated in:

```text
build\windows\x64\runner\Release
```

That folder must be distributed as a complete folder or packaged into an installer/portable ZIP. Do not upload only `Fumic.exe`; the Flutter Windows app also needs its `data` folder and runtime DLLs.


## Contributing

If you find Fumic helpful, please leave a star on the repository.

Bug reports, feature suggestions, UI feedback, documentation improvements, and pull requests are welcome.

1. Fork the repository.
2. Create a feature branch.
3. Make a focused change.
4. Test the app.
5. Open a pull request so it can be reviewed and merged if it adds value.

## License

Fumic is intended to stay free and open source under the GNU General Public License v3.0.

## Contact

- GitHub: https://github.com/UnExplainableFish52
- Email: sharma@saksham.info.np
- Email: contactsaksham52@gmail.com
- Email: info@sakshamsharma.com.np
