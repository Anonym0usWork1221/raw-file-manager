import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class PreviewPage extends StatelessWidget {
  final File file;
  const PreviewPage({super.key, required this.file});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(path.basename(file.path))),
      body: Center(child: Image.file(file)),
    );
  }
}