import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'file_editor_page.dart';

class TextPreviewPage extends StatelessWidget {
  final File file;
  const TextPreviewPage({super.key, required this.file});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(path.basename(file.path)),
        actions: [
          IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.push(
                    context, MaterialPageRoute(builder: (_) => FileEditorPage(file: file)));
              })
        ],
      ),
      body: FutureBuilder<String>(
        future: file.readAsString(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return snapshot.hasData
                ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(snapshot.data!),
            )
                : const Center(child: Text("No data"));
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}