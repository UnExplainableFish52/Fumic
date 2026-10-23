# Fumic - Magical Media Player Public Release Guide

This guide is for publishing Fumic - Magical Media Player `2.6.3` as a public Windows release on GitHub and preparing for Microsoft Store distribution later.

## Release Strategy

Publish two downloadable files:

1. A normal Windows setup installer:

```text
Fumic-Setup-2.6.3-windows-x64.exe
```

2. An optional portable ZIP for technical users:

```text
Fumic-2.6.3-windows-x64-portable.zip
```

Do not upload only this file:

```text
build\windows\x64\runner\Release\fumic.exe
```

That EXE is not enough by itself. Flutter Windows release builds also need the `data` folder and several DLL files beside the executable. If you upload only `fumic.exe`, the app can fail to start on another machine.

## Recommended GitHub Release Assets

Upload these to the GitHub release:

| File | Purpose |
| --- | --- |
| `Fumic-Setup-2.6.3-windows-x64.exe` | Main download for normal users. |
| `Fumic-2.6.3-windows-x64-portable.zip` | Optional portable build for users who do not want an installer. |
| `SHA256SUMS.txt` | Lets users verify downloads. |

GitHub automatically adds source code ZIP/TAR archives for the tagged commit, so you do not need to upload source manually unless you want a custom source package.

## Build Commands

From the repository root:

```powershell
flutter clean
flutter pub get
flutter test
flutter analyze
flutter build windows --release --build-name=2.6.3 --build-number=0
```

The Windows build output should be here:

```text
build\windows\x64\runner\Release
```

The folder should contain `fumic.exe`, `data`, Flutter DLLs, media_kit DLLs, and other runtime files.

Create the portable ZIP and setup installer before running `dart run msix:create`.
Run these packaging steps sequentially: the MSIX tool temporarily adds files to
the release directory and removes runtime DLLs when it cleans up. Rebuild Windows
if you need another portable ZIP or installer after MSIX packaging. The CMake
install step bundles the Visual C++ runtime needed on machines without developer
tools; the installer script rejects a bundle missing those DLLs.

## Create The Portable ZIP

Create a `dist` folder and ZIP the entire release folder contents:

```powershell
New-Item -ItemType Directory -Force dist
Compress-Archive -Path build\windows\x64\runner\Release\* -DestinationPath dist\Fumic-2.6.3-windows-x64-portable.zip -Force
```

Users install the portable version by extracting the ZIP and running:

```text
fumic.exe
```

## Create The Setup Installer

This repository includes an Inno Setup script:

```text
installer\windows\fumic-inno.iss
```

Install Inno Setup 6, then compile the script:

```powershell
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\windows\fumic-inno.iss
```

Expected output:

```text
dist\Fumic-Setup-2.6.3-windows-x64.exe
```

This setup file should be the main GitHub release download.

## Important Windows Warning Reality

A setup installer is better for normal users than a raw executable, but it does not magically remove all Windows warnings.

Windows SmartScreen mainly cares about:

- Whether the file is signed.
- Whether the publisher has reputation.
- Whether this exact file hash has enough clean download history.
- Whether the app is installed through a trusted channel like Microsoft Store.

This means:

- An unsigned portable EXE can show a stronger warning.
- An unsigned setup EXE can still show a warning.
- A signed installer usually looks more trustworthy because it shows a verified publisher name.
- A brand new signed build can still show SmartScreen warnings until reputation builds.
- Microsoft Store distribution is the cleanest path for avoiding SmartScreen download warnings.

For the smoothest public experience, the best long-term path is:

1. Publish a signed setup installer on GitHub.
2. Publish on Microsoft Store when ready.
3. Keep release file names and publisher identity consistent.
4. Add checksums and clear install instructions.

## GitHub Release Steps

1. Make sure the app version is correct in `pubspec.yaml`.
2. Run tests and analysis.
3. Build the Windows release.
4. Create the installer and portable ZIP.
5. Generate SHA256 checksums.
6. Create a Git tag:

```powershell
git tag v2.6.3
git push origin v2.6.3
```

7. On GitHub, open the repository and go to Releases.
8. Click "Draft a new release".
9. Choose tag `v2.6.3`.
10. Title it:

```text
Fumic - Magical Media Player 2.6.3 - Flutter release
```

11. Paste the release notes from:

```text
docs\RELEASE_NOTES_2.6.3.md
```

12. Upload the installer, portable ZIP, and checksum file.
13. Publish the release.

## Generate Checksums

After creating release files:

```powershell
Get-FileHash dist\Fumic-Setup-2.6.3-windows-x64.exe -Algorithm SHA256
Get-FileHash dist\Fumic-2.6.3-windows-x64-portable.zip -Algorithm SHA256
```

Put the output into:

```text
SHA256SUMS.txt
```

Recommended format:

```text
<hash>  Fumic-Setup-2.6.3-windows-x64.exe
<hash>  Fumic-2.6.3-windows-x64-portable.zip
```

## Microsoft Store Plan

For Microsoft Store, MSIX is the cleaner long-term direction for a Flutter Windows app. Microsoft Store distribution gives users a more trusted install flow, built-in update delivery, and Store-level signing.

Recommended later path:

1. Create a Microsoft Partner Center developer account.
2. Reserve the Fumic app name.
3. Prepare Store listing assets.
4. Package the Flutter Windows app as MSIX.
5. Validate the package locally.
6. Submit it to Microsoft Store.

For GitHub releases, the Inno Setup installer is a practical first step. For Store distribution, prefer MSIX unless you intentionally choose Microsoft Store's Win32 MSI/EXE path.

## Before Publishing Checklist

- [ ] `flutter test` passes.
- [ ] `flutter analyze` has no issues.
- [ ] Windows release build launches.
- [ ] Fullscreen startup works.
- [ ] Ctrl+W closes the app.
- [ ] Audio playback works.
- [ ] Video playback works.
- [ ] Keyboard shortcuts work after switching pages.
- [ ] Visualizer performance and stylistic modes work.
- [ ] OPUS artwork still appears.
- [ ] Installer installs and uninstalls cleanly on a test machine.
- [ ] Portable ZIP works after extraction.
- [ ] Release notes are included.
- [ ] Checksums are included.
- [ ] README says the current maintained app is Flutter-based and the old Electron version is deprecated.
- [ ] GPLv3 `LICENSE` file exists in the repository before publishing.

## Source References

- Flutter Windows release guide: https://docs.flutter.dev/deployment/windows
- Flutter Windows build output path: https://docs.flutter.dev/release/breaking-changes/windows-build-architecture
- GitHub releases: https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases
- Managing GitHub releases: https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository
- Windows distribution paths: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/choose-distribution-path
- SmartScreen reputation: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation
- Code signing options: https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options
