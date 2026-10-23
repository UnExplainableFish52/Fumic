# Fumic 2.6.3 release validation

## Completed checks

- `flutter analyze --no-pub`: no issues found.
- `flutter test --no-pub --reporter expanded --concurrency=1`: 126 tests passed.
- `flutter build windows --release --no-pub --build-name=2.6.3 --build-number=0`:
  successful Windows x64 release build.
- Inno Setup compilation: successful, with required Visual C++ runtime checks.
- Portable ZIP inspection: executable, app code, license, and required runtime
  DLLs present.
- `dart run msix:create --build-windows false`: successful Store package build.
- `installer/windows/verify-store-package.ps1`: Store identity, version 2.6.3.0,
  desktop target, runFullTrust capability, required files, and runtime verified.
- MSIX executable, app code, required runtime DLLs, and refreshed Fumic/Matrix
  wallpapers match the rebuilt Windows release by SHA256.
- Generated packages, local screenshots, caches, credentials, and signing material
  are excluded from version control.

## Files

- `dist/Fumic-Setup-2.6.3-windows-x64.exe`: installer for local installation.
- `dist/Fumic-2.6.3-windows-x64-portable.zip`: extract before launching.
- `dist/store/Fumic-2.6.3.0-windows-x64.msix`: unsigned Microsoft Store upload.
- `dist/SHA256SUMS-2.6.3.txt`: checksums for all three artifacts.

Build the installer and portable ZIP before running MSIX packaging. The MSIX tool
temporarily changes the release folder and removes its runtime DLLs during
cleanup; rebuilding Windows restores that folder. Packaging must run sequentially.

## Remaining manual checks

The developer should test installation, audio/video playback, background resource
use, keyboard shortcuts, wallpaper selection, and uninstallation on Windows.
These checks do not establish installed-app performance or Store certification.
Windows App Certification Kit and Partner Center validation remain separate.

Two source findings from the earlier readiness review remain outside this release
cleanup: library-folder and appearance settings still write the same settings file
through separate repositories, and recursive scanning still needs per-directory
error recovery and overlapping-root deduplication. Rapid appearance writes are
serialized, but that does not resolve concurrent writes between the repositories.
See [the earlier review](STORE_READINESS_REVIEW.md) for follow-up scope.
