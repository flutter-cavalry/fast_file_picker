import 'dart:io';
import 'dart:typed_data';

import 'package:fast_file_picker/fast_file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ns_file_coordinator_util/ns_file_coordinator_util.dart';
import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _safStream = SafStream();
  final _safUtil = SafUtil();
  final _nsFileCoordinatorUtil = NsFileCoordinatorUtil();

  String _output = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10),
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              OutlinedButton(
                  onPressed: () async {
                    final res = await FastFilePicker.pickFile();
                    if (res == null) {
                      setState(() {
                        _output = 'Cancelled';
                      });
                    } else {
                      await _readFiles([res]);
                    }
                  },
                  child: const Text('Pick File')),
              const SizedBox(height: 10),
              OutlinedButton(
                  onPressed: () async {
                    final files = await FastFilePicker.pickMultipleFiles();
                    if (files == null) {
                      setState(() {
                        _output = 'Cancelled';
                      });
                    } else {
                      await _readFiles(files);
                    }
                  },
                  child: const Text('Pick Files')),
              const SizedBox(height: 10),
              OutlinedButton(
                  onPressed: () async {
                    try {
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
                          // Use `ns_file_coordinator_util` to read the folder.
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
                    } catch (err) {
                      setState(() {
                        _output = err.toString();
                      });
                    }
                  },
                  child: const Text('Pick Folder')),
              const SizedBox(height: 10),
              OutlinedButton(
                  onPressed: () async {
                    try {
                      final savePath = await FastFilePicker.pickSaveFile();
                      setState(() {
                        _output = savePath?.toString() ?? 'Cancelled';
                      });
                    } catch (err) {
                      setState(() {
                        _output = err.toString();
                      });
                    }
                  },
                  child: const Text('Pick Save File')),
              const SizedBox(height: 10),
              Text(_output),
            ],
          ),
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Future<void> _readFiles(List<FastFilePickerPath> files) async {
    try {
      String s = '';
      for (final file in files) {
        // Add file path to output.
        // ignore: use_string_buffers
        s += 'File: $file\n';

        if (Platform.isIOS) {
          // Handle iOS file.
          // Use [tryUseAppleScopedResource] to request access to the file.
          await file.tryUseAppleScopedResource((hasAccess, file) async {
            if (!hasAccess) {
              s += 'No access to file\n\n';
              return;
            }
            // Access granted.
            // Read the file using `ns_file_coordinator_util`.
            // You can also use Dart IO to read the file path, but it may not trigger iCloud download.
            final bytes = await _nsFileCoordinatorUtil.readFileBytes(file.uri!);

            s += 'Bytes: ${_formatBytes(bytes)}\n\n';
          });
        } else if (file.uri != null && Platform.isAndroid) {
          // Handle Android file.
          // For example, use [saf_stream] package to read the file.
          final bytes = await _safStream.readFileBytes(file.uri!);

          s += 'Bytes: ${_formatBytes(bytes)}\n\n';
        } else if (file.path != null) {
          // Handle Windows / macOS / Linux file.
          final bytes = await File(file.path!).readAsBytes();

          s += 'Bytes: ${_formatBytes(bytes)}\n\n';
        }
      }

      setState(() {
        _output = s;
      });
    } catch (err) {
      setState(() {
        _output = 'Error: $err';
      });
    }
  }

  String _formatBytes(Uint8List bytes) {
    return '${bytes.length} bytes';
  }
}
