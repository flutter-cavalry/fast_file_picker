import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:uuid/uuid.dart';
import 'package:win32/win32.dart';

String windowsFolderContextGuid(String context) => const Uuid().v5(
  Namespace.url.value,
  'https://github.com/flutter-cavalry/fast_file_picker/pickFolder/$context',
);

Future<String?> pickWindowsFolderWithIdentifier(
  String context, {
  String? confirmButtonText,
}) {
  final guid = windowsFolderContextGuid(context);
  // The native modal dialog blocks its calling thread until it is dismissed.
  return Isolate.run(() => _showFolderDialog(guid, confirmButtonText));
}

String? _showFolderDialog(String guid, String? confirmButtonText) {
  final result = CoInitializeEx(
    COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE,
  );
  if (result.isError) {
    throw WindowsException(result);
  }
  try {
    return using((arena) {
      final dialog = arena.com<IFileOpenDialog>(FileOpenDialog);
      dialog.setClientGuid(GUID(guid).toNative(allocator: arena));
      dialog.setOptions(
        dialog.getOptions() | FOS_PICKFOLDERS | FOS_FORCEFILESYSTEM,
      );
      if (confirmButtonText != null) {
        dialog.setOkButtonLabel(arena.pcwstr(confirmButtonText));
      }

      final window = GetForegroundWindow();
      final processId = arena<Uint32>();
      GetWindowThreadProcessId(window, processId);
      final owner = processId.value == GetCurrentProcessId() ? window : null;
      try {
        dialog.show(owner);
      } on WindowsException catch (error) {
        if (error.hr == ERROR_CANCELLED.toHRESULT()) {
          return null;
        }
        rethrow;
      }

      final item = dialog.getResult();
      if (item == null) {
        throw StateError('The Windows folder dialog returned no selection.');
      }
      arena.adopt(item);
      final path = arena.using(item.getDisplayName(SIGDN_FILESYSPATH), free);
      return path.toDartString();
    });
  } finally {
    CoUninitialize();
  }
}
