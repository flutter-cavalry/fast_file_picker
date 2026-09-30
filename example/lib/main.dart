import 'dart:io';
import 'dart:typed_data';

import 'package:fast_file_picker/fast_file_picker.dart';
import 'package:material_ui/material_ui.dart';
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
                      try {
                        if (folder.path != null) {
                          final subFileNames =
                              (await Directory(folder.path!).list().toList())
                                  .map((e) => e.path);

                          setState(() {
                            _output =
                                'Folder: $folder\n\nSubfiles: $subFileNames';
                          });
                        } else if (Platform.isAndroid && folder.uri != null) {
                          // Use [saf_util] package to list files in the folder.
                          // Or use [saf_stream] package to read the files.
                          final subFileNames =
                              (await _safUtil.list(folder.uri!))
                                  .map((e) => e.name);

                          setState(() {
                            _output =
                                'Folder: $folder\n\nSubfiles: $subFileNames';
                          });
                        }
                      } finally {
                        // Release the iOS/macOS security-scoped resource.
                        await folder.release();
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
        try {
          // Add file path to output.
          // ignore: use_string_buffers
          s += 'File: $file\n';

          if (file.path != null) {
            final bytes = await File(file.path!).readAsBytes();

            s += 'Bytes: ${_formatBytes(bytes)}\n\n';
          } else if (file.uri != null && Platform.isAndroid) {
            // For example, use [saf_stream] package to read the file.
            final bytes = await _safStream.readFileBytes(file.uri!);

            s += 'Bytes: ${_formatBytes(bytes)}\n\n';
          }
        } finally {
          // Release the iOS/macOS security-scoped resource.
          await file.release();
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
