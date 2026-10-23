# Fumic privacy policy - draft for publisher review

This draft describes the inspected Flutter desktop implementation. Review and
publish an approved version at a public URL before using it in a Store listing.
Remove this draft notice when publishing. No effective date is assigned until
the publisher approves the policy.

## Local media and storage

Fumic is a desktop player for local audio and video. It does not require an
account. On first launch, it looks for Music and Videos folders under the current
Windows user's profile. Users can also select additional library folders.

The app reads local media files to build the library, play audio/video, extract
metadata and artwork, and generate visualizer information. Library paths,
playlists, settings, metadata and artwork caches are stored locally in application
support storage. A selected custom background image is copied into managed local
app storage.

Fumic does not upload these media files, library paths, playlists, settings or
caches to the developer. The app has no advertising, analytics, telemetry, or
cloud sync service in this release. Local playback does not require internet.

## External links and support

Selecting a link in the Info page copies that link to the system clipboard and
opens it in the default browser. The destination website receives browser traffic
under its own privacy practices; opening a link does not upload the local library
through Fumic.

If you voluntarily contact the developer, send email, or create a GitHub issue,
the information you submit is provided through that service. GitHub issues are
public. Avoid including private file paths, personal media, or other sensitive
information in public reports.

## User control

You can choose which additional folders to add to the library, edit playlists,
and change local settings. Resetting a custom background removes the managed app
copy rather than the original selected image. Your original media files remain
under your control. Removing the app does not delete your original media files.

Microsoft Store and Windows may independently process installation, purchase,
diagnostic or account information under Microsoft's privacy practices. Such
processing is separate from Fumic's local media playback implementation.

## Contact

Questions about Fumic can be submitted through the project's support page:
https://github.com/UnExplainableFish52/Fumic/issues
