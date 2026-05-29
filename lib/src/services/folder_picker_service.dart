import 'package:file_picker/file_picker.dart';

abstract class FolderPickerService {
  Future<String?> pickFolder();
}

class FilePickerFolderPickerService implements FolderPickerService {
  const FilePickerFolderPickerService();

  @override
  Future<String?> pickFolder() {
    return FilePicker.getDirectoryPath(
      dialogTitle: 'Choose a Fumic media folder',
      lockParentWindow: true,
    );
  }
}
