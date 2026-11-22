import 'dart:io';

import 'package:example/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'folder picker receives the optional identifier',
    (tester) async {
      const channel = MethodChannel('macos_file_picker');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final identifiers = <String?>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'pick');
        final arguments = call.arguments as Map<Object?, Object?>;
        identifiers.add(arguments['identifier'] as String?);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Pick Folder'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'documents');
      await tester.tap(find.text('Pick Folder'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'images');
      await tester.tap(find.text('Pick Folder'));
      await tester.pumpAndSettle();

      expect(identifiers, [null, 'documents', 'images']);
    },
    skip: !Platform.isMacOS,
  );
}
