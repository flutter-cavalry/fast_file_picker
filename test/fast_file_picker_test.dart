import 'dart:io';
import 'dart:isolate';

import 'package:fast_file_picker/fast_file_picker.dart';
import 'package:fast_file_picker/src/windows_folder_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const macosChannel = MethodChannel('macos_file_picker');
  const selectorChannel = MethodChannel('plugins.flutter.io/file_selector');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(macosChannel, null);
    messenger.setMockMethodCallHandler(selectorChannel, null);
  });

  test(
    'Windows context GUIDs are stable across isolates and distinct',
    () async {
      final first = windowsFolderContextGuid('documents');
      final second = windowsFolderContextGuid('images');
      expect(
        await Isolate.run(() => windowsFolderContextGuid('documents')),
        first,
      );
      expect(second, isNot(first));
      expect(windowsFolderContextGuid(''), isNot(first));
      expect(first, '6c0f3eb2-421d-5555-8956-565d23c6a115');
    },
  );

  test('forcing file_selector ignores the context', () async {
    final initialDirectories = <String?>[];
    messenger.setMockMethodCallHandler(selectorChannel, (call) async {
      expect(call.method, 'getDirectoryPath');
      final arguments = call.arguments as Map<Object?, Object?>;
      initialDirectories.add(arguments['initialDirectory'] as String?);
      expect(arguments['confirmButtonText'], 'Choose');
      return '/selected';
    });

    final result = await FastFilePicker.pickFolder(
      writePermission: false,
      useFileSelector: true,
      identifier: 'documents',
      confirmButtonText: 'Choose',
    );
    expect(result?.path, '/selected');
    await FastFilePicker.pickFolder(
      writePermission: false,
      useFileSelector: true,
      initialDirectory: '/explicit',
      identifier: 'documents',
      confirmButtonText: 'Choose',
    );
    expect(initialDirectories, [null, '/explicit']);
  });

  test(
    'macOS forwards context and preserves initial directory precedence',
    () async {
      final calls = <Map<Object?, Object?>>[];
      messenger.setMockMethodCallHandler(macosChannel, (call) async {
        expect(call.method, 'pick');
        calls.add(call.arguments as Map<Object?, Object?>);
        if (calls.length == 1) {
          return [
            {'name': 'folder', 'path': '/folder', 'url': 'file:///folder'},
          ];
        }
        return null;
      });

      final result = await FastFilePicker.pickFolder(
        writePermission: false,
        identifier: 'documents',
      );
      expect(result?.path, '/folder');
      expect(result?.uri, 'file:///folder');
      expect(calls[0]['identifier'], 'documents');
      expect(calls[0]['initialDirectory'], isNull);

      expect(
        await FastFilePicker.pickFolder(
          writePermission: false,
          initialDirectory: '/explicit',
          identifier: 'documents',
        ),
        isNull,
      );
      expect(calls[1]['identifier'], isNull);
      expect(calls[1]['initialDirectory'], '/explicit');
    },
    skip: !Platform.isMacOS,
  );
}
