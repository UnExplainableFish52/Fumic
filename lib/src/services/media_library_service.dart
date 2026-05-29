import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/media_item.dart';
import 'folder_picker_service.dart';
import 'library_settings_repository.dart';
import 'media_scanner.dart';

abstract class DefaultLibraryFolderProvider {
  Future<List<String>> defaultFolders();
}

class WindowsDefaultLibraryFolderProvider
    implements DefaultLibraryFolderProvider {
  const WindowsDefaultLibraryFolderProvider();

  @override
  Future<List<String>> defaultFolders() async {
    if (!Platform.isWindows) {
      return const [];
    }

    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile == null || userProfile.trim().isEmpty) {
      return const [];
    }

    final candidates = [
      p.join(userProfile, 'Music'),
      p.join(userProfile, 'Videos'),
    ];
    final existing = <String>[];
    for (final candidate in candidates) {
      if (await Directory(candidate).exists()) {
        existing.add(p.normalize(candidate));
      }
    }
    return _dedupeFolders(existing);
  }
}

class MediaLibraryService {
  const MediaLibraryService({
    required this.settingsRepository,
    required this.folderPicker,
    required this.scanner,
    this.defaultLibraryFolders = const WindowsDefaultLibraryFolderProvider(),
  });

  factory MediaLibraryService.production() {
    return const MediaLibraryService(
      settingsRepository: JsonLibrarySettingsRepository(),
      folderPicker: FilePickerFolderPickerService(),
      scanner: FileSystemMediaScanner(),
    );
  }

  final LibrarySettingsRepository settingsRepository;
  final FolderPickerService folderPicker;
  final MediaScanner scanner;
  final DefaultLibraryFolderProvider defaultLibraryFolders;

  Future<List<String>> loadFolders() async {
    final saved = _dedupeFolders(await settingsRepository.loadFolders());
    final hasStoredFolders = await settingsRepository.hasStoredLibraryFolders();
    final hasInitializedDefaults = await settingsRepository
        .hasInitializedDefaultLibraries();

    if (hasStoredFolders || hasInitializedDefaults) {
      if (!hasInitializedDefaults) {
        await settingsRepository.saveFolders(saved);
      }
      return saved;
    }

    final defaults = await defaultLibraryFolders.defaultFolders();
    final initialized = _dedupeFolders([...saved, ...defaults]);
    await settingsRepository.saveFoldersWithDefaultInitialization(initialized);
    return initialized;
  }

  Future<List<MediaItem>> scan(List<String> folders) {
    return scanner.scanFolders(folders);
  }

  Future<String?> pickFolder() => folderPicker.pickFolder();

  Future<List<String>> addFolder(List<String> existingFolders) async {
    final folder = await pickFolder();
    if (folder == null || folder.trim().isEmpty) {
      return existingFolders;
    }
    final next = <String>[...existingFolders];
    final normalizedFolder = p.normalize(folder);
    if (!next.any((value) => _sameFolder(value, normalizedFolder))) {
      next.add(normalizedFolder);
      await settingsRepository.saveFolders(next);
    }
    return next;
  }

  Future<List<String>> removeFolder(
    List<String> existingFolders,
    String folder,
  ) async {
    final next = existingFolders
        .where((value) => !_sameFolder(value, folder))
        .toList(growable: false);
    await settingsRepository.saveFolders(next);
    return next;
  }

  Future<List<String>> clearFolders() async {
    await settingsRepository.saveFolders(const []);
    return const [];
  }
}

bool _sameFolder(String a, String b) {
  return p.normalize(a).toLowerCase() == p.normalize(b).toLowerCase();
}

List<String> _dedupeFolders(List<String> folders) {
  final seen = <String>{};
  final deduped = <String>[];
  for (final folder in folders) {
    final trimmed = folder.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final normalized = p.normalize(trimmed);
    final key = normalized.toLowerCase();
    if (seen.add(key)) {
      deduped.add(normalized);
    }
  }
  return deduped;
}
