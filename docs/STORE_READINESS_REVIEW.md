# Store readiness review — 18 October 2026

Historical review of the earlier interface pass. For the 2.6.3 release changes,
see [the release notes](RELEASE_NOTES_2.6.3.md). Its current automated validation
is recorded in [the release validation](RELEASE_VALIDATION_2.6.3.md). The older
test count and binary hash below do not describe the new release.

The first enhancement pass prioritizes interface and usability, as requested.
The project already includes a Windows MSIX configuration, a package verifier,
and draft Store listing, privacy, and submission documents. Publication remains
pending visual review, packaged runtime testing, and the release items below.

## Interface changes in this pass

- A smaller brand/header with separate layouts for wide, medium, and narrow
  desktop windows. Search retains useful space alongside navigation.
- Add folder and Refresh actions directly on Home, including first launch.
- Library counts, search result counts, and a short playback hint.
- Separate messages for a new library, an empty media tab, scanning, and no
  search matches. Search can be cleared from its empty state; empty tabs offer
  navigation to the other media type when it has files.
- Explicit play buttons on media cards. The current file has a playing/paused
  marker independent of the selected card.
- Smaller alphabet headings, more compact card typography, and a scrollbar.
- A narrower-window player layout, clearer idle/selected/playing/paused/loading
  labels, and visible playback failure feedback with details in a tooltip.
- Search changes return the library to the top. Initial scanning no longer
  scrolls the Home actions out of view to reveal the first selection.

## Verified release configuration

Validation of the final source changes:

- `flutter analyze --no-pub`: no issues found.
- `flutter test --no-pub --reporter expanded`: all 69 tests passed.
- Five new widget tests cover empty-search recovery, adding folders from Home,
  direct card playback, switching from an empty tab, and desktop layouts at
  1024 × 768, 800 × 600, and 640 × 600.

Visual review and native Windows playback testing are still assigned to the
developer; automated widget tests do not establish native playback performance.

The existing `dist/store/Fumic-2.6.2.0-windows-x64.msix` passed
`installer/windows/verify-store-package.ps1` in this review. Its SHA256 was:

```text
3C1D68C62BFBDEAF64FC07A1B1A81F7A5517848C36D220250368BFB5D604CA89
```

This is the pre-existing binary. It does not contain this interface pass. The
verifier checks package contents, not runtime behavior or Store certification.
Rebuild and rerun it after the UI and release version have been agreed. If
2.6.2.0 has already been distributed through the Store, select a higher version
before packaging the update.

## Next reliability work

| Priority | Finding | Follow-up |
| --- | --- | --- |
| High | Library folders and visualizer preferences independently read and rewrite `fumic_settings.json`. Concurrent saves can overwrite each other's changes. | Serialize updates through a shared settings store and preserve the existing data format. Test concurrent saves and interrupted/corrupt writes. |
| High | The recursive filesystem scanner has no per-directory error handling. A permission error or disconnected drive can fail a scan. Overlapping library roots can also return duplicate files. | Preserve accessible results, report unavailable folders, and deduplicate file paths. |
| Before submission | Root screenshots show an older interface. | Capture fresh screenshots after approving the current UI. |
| Before submission | Privacy policy and Store listing are still drafts. | Review the claims, publish the policy, and enter the actual URL in Partner Center. |
| Before submission | Native dependency notices and corresponding-source review are still outstanding in the release guide. | Resolve this against the exact libraries included in the final binary. |

The first two findings come from source inspection; this pass does not change
the persistence or scanning implementation.

## Visual review to run locally

```powershell
flutter run -d windows
```

Review Home both maximized and in a smaller window. Try a search with no matches,
clear it, add a folder from Home, play a card with its play button, then select a
different card while playback continues. Check audio/video switching, keyboard
navigation, Playlists, Settings, and fullscreen playback. Send screenshots and
feedback before extending the visual direction to further screens.

For Store screenshots, capture the approved packaged app. Microsoft currently
requires PNG Desktop screenshots at least 1366 × 768 pixels and no larger than
50 MB each. At least one is required; four or more are recommended. Use media and
artwork suitable for public promotional use and avoid personal paths.

Source: [Microsoft screenshot and image requirements](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/screenshots-and-images).

After visual approval, follow
[the Microsoft Store release guide](MICROSOFT_STORE_RELEASE_GUIDE.md) to rebuild,
test under package identity, run Windows App Certification Kit, and complete the
Partner Center submission.
