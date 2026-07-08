# fast_file_picker

[![pub package](https://img.shields.io/pub/v/fast_file_picker.svg)](https://pub.dev/packages/fast_file_picker)

`fast_file_picker` is a fast file picker for Flutter. To achieve the best performance, it returns OS file info directly and never performs any file copying or conversion. It supports picking files, folders, and save paths on all platforms. Based on [file_selector](https://pub.dev/packages/file_selector).

|                  | iOS                | Android       | macOS              | Windows / Linux |
| ---------------- | ------------------ | ------------- | ------------------ | --------------- |
| Pick files       | ✅ (Name/Path/URL) | ✅ (Name/Uri) | ✅ (Name/Path/URL) | ✅ (Name/Path)  |
| Pick a folder    | ✅ (Name/Path/URL) | ✅ (Name/Uri) | ✅ (Name/Path/URL) | ✅ (Name/Path)  |
| Pick a save path | ❓                 | ❓            | ✅ (Name/Path/URL) | ✅ (Name/Path)  |

- ⚠️: For each operation, please **follow the platform-specific notes below**.
- ⚠️: This package follows the single responsibility principle. It's intended to only return OS file info. It's up to you to handle file access for each platform using the mentioned packages from README or other packages.
- ❓: Supported. But it's recommended to use share menu on iOS and Android to share/save files.

## Usage

### Preqrequisites

On macOS, you need to add the following key to entitlements in order for macOS app to be able to access file system:

```xml
  <key>com.apple.security.files.user-selected.read-write</key>
  <true/>
```

### `FastFilePickerPath`

Since `fast_file_picker` can return path or URI or both, the result is wrapped in `FastFilePickerPath`:

```dart
class FastFilePickerPath {
  // The name of the file or directory.
  final String name;
  final String? path;
  final String? uri;
}
```

### Pick a file or multiple files

**Platform notes:**

- Windows / macOS / Linux: Use Dart IO to access the file path.
- iOS: call `tryUseAppleScopedResource` first. If access is granted.
  - Use Dart IO to access the file path.
  - To trigger iCloud download, use `ns_file_coordinator_util` to access the file URL.
- Android: use [saf_stream](https://pub.dev/packages/saf_stream) for file reading or [saf_util](https://pub.dev/packages/saf_util) for file info.

```dart
class FastFilePicker {
  /// Picks a file and return a [FastFilePickerPath].
  /// If the user cancels the picker, it returns `null`.
  ///
  /// [useFileSelector] whether to force using the internal file_picker plugin.
  /// [acceptedTypeGroups] is a list of [XTypeGroup] that specifies the accepted file types.
  /// [initialDirectory] is the initial directory to open the picker.
  /// [confirmButtonText] is the text to display on the confirm button.
  static Future<FastFilePickerPath?> pickFile(/* Same params as file_selector */);

  /// Picks multiple files and return a list of [FastFilePickerPath].
  /// If the user cancels the picker, it returns `null`.
  ///
  /// [useFileSelector] whether to force using the internal file_picker plugin.
  /// [acceptedTypeGroups] is a list of [XTypeGroup] that specifies the accepted file types.
  /// [initialDirectory] is the initial directory to open the picker.
  /// [confirmButtonText] is the text to display on the confirm button.
  static Future<List<FastFilePickerPath>?> pickMultipleFiles(/* Same params as file_selector */);
}
```

Example:

```dart
final files = await FastFilePicker.pickMultipleFiles();
if (files == null) {
  setState(() {
    _output = 'User canceled the picker';
  });
  return;
}

// Handle selected files.
for (final file in files) {
  if (Platform.isIOS) {
    // Handle iOS file.
    // Use [tryUseAppleScopedResource] to request access to the file.
    await file.tryUseAppleScopedResource((hasAccess, file) async {
      if (!hasAccess) {
        setState(() {
          _output = 'No access to file';
        });
        return;
      }
      // Access granted.

      // Read file path with Dart IO.
      final bytes = await File(file.path!).readAsBytes();
      // Or use `ns_file_coordinator_util` to read the file URL to trigger iCloud download.
      final bytes = await _nsFileCoordinatorUtil.readFileBytes(file.uri!);
    });
  } else if (file.uri != null && Platform.isAndroid) {
    // Handle Android file.
    // For example, use [saf_stream] package to read the file.
    final bytes = await _safStream.readFileBytes(file.uri!);
  } else if (file.path != null) {
    // Handle Windows / macOS / Linux file.
    final bytes = await File(file.path!).readAsBytes();
  }
}
```

### Pick a folder

**Platform notes:**

- Windows / macOS / Linux: Use Dart IO to access the folder.
- iOS: call `tryUseAppleScopedResource` to gain access first. If access is granted:
  - Use Dart IO to access the directory path.
  - To trigger iCloud download, use `ns_file_coordinator_util` to access the directory URL.
- Android: use [saf_stream](https://pub.dev/packages/saf_stream) for file access or [saf_util](https://pub.dev/packages/saf_util) for other things.

```dart
class FastFilePicker {
  /// Picks a folder and return a [FastFilePickerPath].
  /// If the user cancels the picker, it returns `null`.
  ///
  /// [writePermission] is only applicable on Android.
  /// [useFileSelector] whether to force using the internal file_picker plugin.
  /// [initialDirectory] is the initial directory to open the picker.
  /// [confirmButtonText] is the text to display on the confirm button.
  static Future<FastFilePickerPath?> pickFolder(
      {required bool writePermission,
      /* Same params as file_selector */});
}
```

Example:

```dart
// Handle selected folder.
final folder = await FastFilePicker.pickFolder(
    writePermission: false);
if (folder == null) {
  setState(() {
    _output = 'Cancelled';
  });
  return;
}
if (Platform.isIOS) {
  // Handle iOS folder.

  // Use [tryUseAppleScopedResource] to request access to the folder.
  await folder.tryUseAppleScopedResource(
    (hasAccess, folder) async {
    if (!hasAccess) {
      setState(() {
        _output = 'No access to folder';
      });
      return;
    }
    // Access granted.

    // Use Dart IO to access the folder.
    final subFileNames = (await Directory(folder.path!).list().toList())
        .map((e) => e.path);
    // Or use `ns_file_coordinator_util` to read the folder URL to trigger iCloud download.
    final subFileNames = await _nsFileCoordinatorUtil
        .listContents(folder.uri!);

    setState(() {
      _output =
          'Folder: $folder\n\nSubfiles: $subFileNames';
    });
  });
} else if (Platform.isAndroid && folder.uri != null) {
  // Handle Android folder.

  // Use [saf_util] package to list files in the folder.
  // Or use [saf_stream] package to read the files.
  final subFileNames = (await _safUtil.list(folder.uri!))
      .map((e) => e.name);

  setState(() {
    _output =
        'Folder: $folder\n\nSubfiles: $subFileNames';
  });
} else if (folder.path != null) {
  // Handle Windows / macOS / Linux folder.
  final subFileNames =
      (await Directory(folder.path!).list().toList())
          .map((e) => e.path);

  setState(() {
    _output =
        'Folder: $folder\n\nSubfiles: $subFileNames';
  });
}
```

### Pick a save path

**Platform notes:**

- iOS / Android: Not supported. It's recommended to use mobile share menu to save files.
- Windows / macOS / Linux: Use Dart IO to handle the save path.

```dart
class FastFilePicker {
  /// Picks a save file location and return a [String] path.
  /// You can optionally specify a default file name via [suggestedName].
  /// If the user cancels the picker, it returns `null`.
  /// [useFileSelector] whether to force using the internal file_picker plugin.
  /// [suggestedName] is the default file name.
  /// [acceptedTypeGroups] is a list of [XTypeGroup] that specifies the accepted file types.
  /// [initialDirectory] is the initial directory to open the picker.
  /// [confirmButtonText] is the text to display on the confirm button.
  static Future<String?> pickSaveFile(/* Same params as file_selector */);
}
```

Example:

```dart
final savePath = await FastFilePicker.pickSaveFile();
if (savePath == null) {
  setState(() {
    _output = 'User canceled the picker';
  });
  return;
}
// Handle save path using Dart IO.
```

### Switch to `file_selector` implementation

If you want to use `file_selector` implementation for a particular API, pass `useFileSelector: true`:

```dart
final files = await FastFilePicker.pickMultipleFiles(useFileSelector: true);
```
