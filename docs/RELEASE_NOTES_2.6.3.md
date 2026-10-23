# Fumic 2.6.3

This release improves background playback efficiency, wallpaper handling, and
keyboard control across the library and full-screen player.

- Reduce playback-driven UI updates while Fumic is inactive or minimized, stop
  inactive visualizer animation, and initialize video rendering only for video.
- Validate and resize custom wallpapers before storing them, use unique imports,
  and clean up obsolete managed files and decoded wallpaper cache entries.
- Refresh the bundled wallpapers, with Fumic — Feel the Music as the first default.
- Center playback controls, place the library seek bar above them, and improve
  shuffle/repeat state indicators and library selection borders.
- Replace player volume sliders with a mute/unmute button and a numeric 0–100
  volume display. Muting preserves the previous audible volume.
- Support J/K/L for seeking back five seconds, play/pause, and seeking forward
  five seconds while preserving text entry in search and editors.
- Use F or E to switch between the library and full player without shrinking
  the application window; I minimizes Fumic while music continues playing.
- Let full-player controls hide after a configurable delay or stay manually
  hidden with B or Ctrl+B. The library controls remain visible.
- Allow a clean wallpaper-only full-player view when visualizer effects and
  controls are disabled.
- Clarify Visualizer Screen Options and align visualizer presets to the right.
- Bundle the Visual C++ runtime with Windows releases and exclude generated
  packages, local feedback, and temporary files from source control.

Windows installer: `Fumic-Setup-2.6.3-windows-x64.exe`.
Portable build: `Fumic-2.6.3-windows-x64-portable.zip`.
Microsoft Store upload: `Fumic-2.6.3.0-windows-x64.msix`.

The Store upload preserves the existing package identity and is intentionally
unsigned for Microsoft Store signing. Local package verification does not
replace testing the installed app or Microsoft certification.
