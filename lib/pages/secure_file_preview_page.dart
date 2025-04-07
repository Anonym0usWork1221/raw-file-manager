import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import '../utils/encryption_util.dart';
import 'dart:typed_data';
import 'file_editor_page.dart';
import 'dart:io';

class SecureFilePreviewPage extends StatefulWidget {
  final File file;
  const SecureFilePreviewPage({super.key, required this.file});
  @override
  SecureFilePreviewPageState createState() => SecureFilePreviewPageState();
}

class SecureFilePreviewPageState extends State<SecureFilePreviewPage> {
  bool _isLoading = true;
  String? _textContent;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _loadAndDecrypt();
  }

  Future<void> _loadAndDecrypt() async {
    try {
      String ext = path.extension(widget.file.path).toLowerCase();
      if (['.txt', '.md', '.json', '.xml'].contains(ext)) {
        String encrypted = await widget.file.readAsString();
        String decrypted = xorDecrypt(encrypted, "my_secret_key");
        setState(() {
          _textContent = decrypted;
          _isLoading = false;
        });
      } else if (['.jpg', '.png', '.jpeg', '.gif', '.bmp'].contains(ext)) {
        Uint8List encryptedBytes = await widget.file.readAsBytes();
        Uint8List decryptedBytes = xorDecryptBytes(encryptedBytes, "my_secret_key");
        setState(() {
          _imageBytes = decryptedBytes;
          _isLoading = false;
        });
      } else {
        setState(() {
          _textContent = "Preview not available for this file type.";
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error decrypting file: $e");
      setState(() {
        _textContent = "Error decrypting file.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String fileName = path.basename(widget.file.path);
    return Scaffold(
      appBar: AppBar(
        title: Text("Secure: $fileName"),
        actions: [
          IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => FileEditorPage(file: widget.file)));
              })
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _textContent != null
          ? SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(_textContent!),
      )
          : _imageBytes != null
          ? Center(child: Image.memory(_imageBytes!))
          : const Center(child: Text("No preview available.")),
    );
  }
}