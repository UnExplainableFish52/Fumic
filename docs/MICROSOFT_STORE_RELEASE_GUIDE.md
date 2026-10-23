# Fumic Microsoft Store release

Prepared against Microsoft documentation on 8 October 2026. This is a submission
workflow, not a certification result. The developer performs app testing and
Partner Center steps; local packaging does not publish anything.

## Agreed release and identity

| Field | Confirmed value |
| --- | --- |
| Reserved app name | Fumic |
| Package/Identity/Name | TheIdealDev52.Fumic |
| Package/Identity/Publisher | CN=53B47373-7933-42A9-AF08-A830D467B5E3 |
| Package/Properties/PublisherDisplayName | TheIdealDev52 |
| Package family name | TheIdealDev52.Fumic_xkcybdby99xzj |
| Store ID | 9P1F9S2TDBWJ |
| Current Store update | 2.6.3.0 |
| Price / account | Free / Individual |
| Initial architecture / device family | x64 / Windows.Desktop |
| Initial listing language | English (en-us), matching the current interface |

The three manifest identity values come directly from Partner Center. The PFN,
SID and Store ID are not substitutes for those manifest values.

## Version rules

A first submission can start at 2.6.2.0. It does not have to start at 1.0.0.0.
MSIX uses four numeric parts: major.minor.build.revision. For Store packages,
revision must be zero. Major is 1..65535; minor and build are 0..65535.

Recommended sequence: 2.6.2.0 -> 2.6.3.0 -> 2.7.0.0 -> 3.0.0.0. These examples
are suggestions, not versions already assigned. Use a higher version to update
the same supported devices. Rolling back code also needs a higher package
version to update customers who already received the problematic release.

`pubspec.yaml` keeps the existing public version `2.6.3+263`. `msix_version` is
explicitly `2.6.3.0`; `windows_build_args` overrides the executable's suffix to
zero for the Store build. Do not rely on a packaging tool to infer the Store
version from `+263`. For future releases, update both the MSIX version and the
Store build arguments, and pass the new version to the verification script.

## Build and verify

Run from the project root. Dependency resolution adds the MSIX development tool;
it does not update the app's runtime dependencies to their latest versions.

```powershell
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
dart run msix:create
& .\installer\windows\verify-store-package.ps1
```

`msix:create` performs the Windows release build, generates tile assets from the
existing icon, bundles the runtime, and produces:

```text
dist\store\Fumic-2.6.3.0-windows-x64.msix
```

This package is intentionally unsigned, with certificate installation disabled.
Microsoft signs MSIX packages distributed through the Store. A paid signing
certificate is not needed for this Store submission. Double-click installation
of this unsigned upload artifact is not the local test workflow.

The verifier reads the archive without installing it. It checks the agreed
identity, version, publisher/name, desktop family, runFullTrust capability,
important runtime files, license text, and VC++ runtime files or framework
declaration. It prints a SHA256 hash. It does not replace full package validation,
runtime testing, Windows App Certification Kit, or Microsoft's certification.

## Local testing under package identity

Enable Developer Mode in Windows Settings if needed. The unsigned package can
be extracted and its manifest registered for development testing; see Microsoft's
run/debug/test guide. Keep the extracted folder in place while it is registered.

After extracting the current package into the following test folder, run in PowerShell:

```powershell
Add-AppxPackage -Register "$PWD\dist\store\local-test-2.6.3.0\AppxManifest.xml"
```

Launch **Fumic from the Start menu**. Running the portable EXE alone does not test
package identity, package storage, or the packaged launch path. Verify which app
is registered if an older GitHub installation also exists:

```powershell
Get-AppxPackage -Name TheIdealDev52.Fumic |
    Select-Object Name, Version, PackageFamilyName, InstallLocation
```

Check:

- First launch, default Music/Videos scanning, and adding another folder.
- Local audio and video playback, seeking, shuffle, repeat, and volume.
- Creating a playlist, adding items, closing/reopening, and saved settings.
- Embedded artwork, custom backgrounds, and visualizer behavior.
- Keyboard shortcuts, fullscreen, and closing the app.
- Info page GitHub/contact links opening in the default browser.
- Behavior without internet and with missing/unavailable media files.
- A clean test Windows account or machine without Flutter/Visual Studio installed.

MSIX can redirect AppData. Do not promise automatic migration of playlists and
settings from the old GitHub installation until that has been tested.

Run **Windows App Certification Kit** from the Windows SDK, choose the installed
Store app validation workflow, and save its report. If the kit is missing, add
the applicable Windows SDK component through your existing development setup.
Report failures so they can be investigated before certification submission.
Production installation/uninstallation and Store update delivery should also be
tested with a properly signed package or a Store-distributed test release.

## Partner Center submission steps

1. Open Partner Center, select **Fumic**, and verify the developer account is
   active. From **Product release**, choose **Start submission**.
2. In **Pricing and availability**, set the base price to **Free**. Review markets,
   public audience, discoverability, and release schedule. Markets and publication
   timing remain decisions for the publisher; review defaults before saving.
3. In **Properties**, choose the current category that best matches a music/video
   player. Review declarations against the actual app. The draft privacy policy is
   in `docs/PRIVACY_POLICY_DRAFT.md`; publish an approved public version before
   entering a URL. Microsoft requires a privacy policy if personal information is
   collected/transmitted. Do not assume local-file access eliminates all policy
   considerations. A clear policy is useful even for an offline app.
4. In **Age ratings**, answer the complete questionnaire based on Fumic's actual
   features. No rating is preselected here. A player showing users' own files is
   different from a service supplying content, community features, or purchases.
5. In **Packages**, upload the `.msix` listed above. This is a supported upload
   format. Microsoft recommends `.msixupload`/`.appxupload` where the packaging
   workflow provides one; do not rename an MSIX to make an upload container.
   Inspect validation errors and warnings. Confirm Desktop availability. A
   package marked Validated does not necessarily complete the Packages section;
   finish all required package settings.
6. In **Store listings**, add English description and feature copy from
   `docs/STORE_LISTING_DRAFT.md`, after reviewing every claim. Add screenshots and
   optional support/source links. Only advertise architectures and features that
   have been tested.
7. In **Submission options**, explain **runFullTrust** using the draft below. This
   is a desktop Flutter/Win32 process using native playback and local filesystem
   access, running as the ordinary user. It does not request administrator
   privileges. Review every capability Partner Center detects.
8. Review all completed sections and the planned publication timing. Resolve
   local testing, source/license, and asset checks below. Then click **Submit for
   certification**. Certification is Microsoft's review; upload validation does
   not guarantee approval. A publishing hold can separate approval from release.

## Certification notes draft

Fumic is a free Flutter/Win32 desktop player for local audio and video. No account
or sign-in is required. On first launch it scans existing Music and Videos folders
under the current user's profile. Users can also choose library folders through
the app. To test playback, put a supported local media file in a library folder,
scan the library, select the file, and press Ctrl+Enter. Ctrl+B adds the selected
file to a playlist. Ctrl+P opens playlists; Ctrl+S opens settings. Closing and
reopening the app should preserve playlists/settings. Internet is not required
for local playback. Links on the Info page open an external browser.

Restricted capability justification: runFullTrust is required to launch the
Flutter Windows desktop executable, use the native media_kit/libmpv playback
engine, and read local media files. The application runs as the interactive user,
stores settings/cache in application support storage, and does not require
administrator elevation, Windows services, or drivers.

## Assets and source checks before submission

- Capture current screenshots from the installed app. Dimensions must meet
  Desktop's minimum 1366 x 768. Each must be at most 50 MB. Review them for current
  UI, personal paths, and media/artwork rights before uploading. At least one is
  required; four or more are recommended. Capture fresh screenshots from the
  registered packaged release if old screenshots are no longer representative.
- `icons/icon.png` is a 512 x 512 source for generated package icons. An optional
  separate Store app tile image is 300 x 300; the Store can use the package icon
  when that optional image is absent. Follow the size of each Partner Center
  image slot; do not assume one PNG fits every slot.
- The official GPLv3 license is now in `LICENSE` and installed into release
  packages. Flutter's generated third-party `NOTICES.Z` is also bundled.
- Publish the exact corresponding source for this binary, including these Store
  changes, at a stable tag/commit. The repository URL alone does not prove that
  the corresponding source for this binary is available.
- Complete the native dependency source/license review. The build includes
  `libmpv-2.dll`, ANGLE, SwiftShader/Vulkan and zlib. The Dart wrapper's MIT license
  does not establish the license/source obligations of every bundled native
  library. Preserve upstream notices and identify matching native build sources;
  adding Fumic's GPL text alone is not a full dependency license audit.
- Confirm any public privacy policy URL and support destination before entering
  them in Partner Center. Draft files are not published URLs.

## Documentation used

- [Create an app submission](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/create-app-submission)
- [Package requirements and version rules](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/app-package-requirements)
- [Product identity](https://learn.microsoft.com/en-us/windows/apps/publish/view-app-identity-details)
- [Package upload](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/upload-app-packages)
- [Screenshot and image requirements](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/screenshots-and-images)
- [Desktop packaging preparation](https://learn.microsoft.com/en-us/windows/msix/desktop/desktop-to-uwp-prepare)
- [Run, debug, and test an MSIX](https://learn.microsoft.com/en-us/windows/msix/desktop/desktop-to-uwp-debug)
- [App capabilities](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/app-capability-declarations)
- [Flutter Windows distribution](https://docs.flutter.dev/platform-integration/windows/building)
- [MSIX tool documentation](https://pub.dev/packages/msix)
