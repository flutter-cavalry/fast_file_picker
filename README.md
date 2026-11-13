# fast_file_picker

[![pub package](https://img.shields.io/pub/v/fast_file_picker.svg)](https://pub.dev/packages/fast_file_picker)

`fast_file_picker` is a fast file picker for Flutter. To achieve the best performance, it returns OS file info directly and never performs any file copying or conversion. It supports picking files, folders, and save paths on all platforms. Based on [file_selector](https://pub.dev/packages/file_selector).

> Starting from v2.0.0, [UIScene adoption](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate) is required.

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

  // Releases access held by an iOS or macOS picker result.
  Future<void> release();
}
```

iOS and macOS picker results acquire security-scoped access automatically.
Call `release()` after finishing with each result. It is a no-op for results
from other platforms or `file_selector`.

### Pick a file or multiple files

**Platform notes:**

- iOS / macOS / Windows / Linux: Use Dart IO to access the file path.
  - iOS / macOS: Security-scoped access is acquired automatically.
    - To trigger iCloud download, use `ns_file_coordinator_util` to access the file URL.
- Android: use [saf_stream](https://pub.dev/packages/saf_stream) for file reading or [saf_util](https://pub.dev/packages/saf_util) for file info.

Example: pick one file

```dart
// Pick one file and pass it to the same handler used for multiple files (see below).
final res = await FastFilePicker.pickFile();
if (res == null) {
  print('Cancelled');
} else {
  await _readFiles([res]);
}
```

Example: pick multiple files

```dart
// Use pickMultipleFiles when the user should be able to select more than one.
final files = await FastFilePicker.pickMultipleFiles();
if (files == null) {
  print('Cancelled');
} else {
  await _readFiles(files);
}
```

The example app uses this helper to read selected files and release each
result's access when finished:

```dart
Future<void> _readFiles(List<FastFilePickerPath> files) async {
  try {
    for (final file in files) {
      try {
        // Include the selected item in the result shown by the example app.
        print('File: $file');

        // Read the file directly when the picker returns a local path.
        if (file.path != null) {
          final bytes = await File(file.path!).readAsBytes();
          print('Bytes: ${_formatBytes(bytes)}');
        } else if (file.uri != null && Platform.isAndroid) {
          // Android document selections are URIs; read them with saf_stream.
          final bytes = await _safStream.readFileBytes(file.uri!);
          print('Bytes: ${_formatBytes(bytes)}');
        }
      } finally {
        // Releases security-scoped access on iOS/macOS; no-op elsewhere.
        await file.release();
      }
    }

  } catch (err) {
    print('Error: $err');
  }
}
```

### Pick a folder

**Platform notes:**

- iOS / macOS / Windows / Linux: Use Dart IO to access the folder.
  - iOS / macOS: Security-scoped access is acquired automatically.
    - To trigger iCloud download, use `ns_file_coordinator_util` to access the file URL.
- Android: use [saf_stream](https://pub.dev/packages/saf_stream) for file access or [saf_util](https://pub.dev/packages/saf_util) for other things.

Example:

```dart
try {
  final folder = await FastFilePicker.pickFolder(writePermission: false);
  if (folder == null) {
    print('Cancelled');
    return;
  }

  try {
    // Use Dart IO when the picker returns a local path.
    if (folder.path != null) {
      final subFileNames = (await Directory(folder.path!).list().toList())
          .map((entry) => entry.path);
        print('Folder: $folder\n\nSubfiles: $subFileNames');
    } else if (Platform.isAndroid && folder.uri != null) {
      // Android returns a URI, which saf_util can list.
      final subFileNames = (await _safUtil.list(folder.uri!))
          .map((entry) => entry.name);
        print('Folder: $folder\n\nSubfiles: $subFileNames');
    }
  } finally {
    // Release the security-scoped resource after the folder is accessed.
    await folder.release();
  }
} catch (err) {
  print(err);
}
```

### Pick a save path

**Platform notes:**

- iOS / Android: Not supported. It's recommended to use mobile share menu to save files.
- Windows / macOS / Linux: Use Dart IO to handle the save path.

Example:

```dart
try {
  final savePath = await FastFilePicker.pickSaveFile();
  // A null path means the user canceled the save dialog.
  print(savePath ?? 'Cancelled');
} catch (err) {
  print(err);
}
```

### Switch to `file_selector` implementation

If you want to use `file_selector` implementation for a particular API, pass `useFileSelector: true`:

```dart
final files = await FastFilePicker.pickMultipleFiles(useFileSelector: true);
```
