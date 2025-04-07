import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class FileEditorPage extends StatefulWidget {
  final File file;
  const FileEditorPage({super.key, required this.file});
  @override
  FileEditorPageState createState() => FileEditorPageState();
}

class FileEditorPageState extends State<FileEditorPage> {
  late TextEditingController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadFileContent();
  }

  Future<void> _loadFileContent() async {
    try {
      String content = await widget.file.readAsString();
      _controller.text = content;
    } catch (e) {
      print("Error reading file: $e");
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveFileContent() async {
    try {
      await widget.file.writeAsString(_controller.text);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("File saved.")));
    } catch (e) {
      print("Error saving file: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Edit ${path.basename(widget.file.path)}"),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveFileContent,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _controller,
          maxLines: null,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: "Edit file content here...",
          ),
        ),
      ),
    );
  }
}