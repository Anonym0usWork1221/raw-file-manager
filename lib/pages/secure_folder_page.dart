import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'secure_file_preview_page.dart';

class SecureFolderPage extends StatefulWidget {
  const SecureFolderPage({super.key});
  @override
  SecureFolderPageState createState() => SecureFolderPageState();
}

class SecureFolderPageState extends State<SecureFolderPage> {
  bool authenticated = false;
  List<FileSystemEntity> secureFiles = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    String? input = await _showPasswordDialog();
    if (input == '1234') {
      setState(() {
        authenticated = true;
      });
      _loadSecureFolder();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Incorrect password. Please try again.")));
      _authenticate();
    }
  }

  Future<String?> _showPasswordDialog() async {
    String password = "";
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Enter Secure Folder Password"),
          content: TextField(
            obscureText: true,
            onChanged: (value) {
              password = value;
            },
          ),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(context, password);
                },
                child: const Text("OK")),
          ],
        );
      },
    );
  }

  Future<void> _loadSecureFolder() async {
    String securePath =
    path.join("/storage/emulated/0", "RawFileManager", "SecureFolder");
    Directory secureDir = Directory(securePath);
    if (!(await secureDir.exists())) {
      await secureDir.create(recursive: true);
    }
    List<FileSystemEntity> files = await secureDir.list().toList();
    setState(() {
      secureFiles = files;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!authenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text("Secure Folder")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text("Secure Folder")),
      body: RefreshIndicator(
        onRefresh: _loadSecureFolder,
        child: ListView.builder(
          itemCount: secureFiles.length,
          itemBuilder: (context, index) {
            FileSystemEntity entity = secureFiles[index];
            return ListTile(
              leading: Icon(entity is Directory
                  ? Icons.folder
                  : Icons.insert_drive_file),
              title: Text(path.basename(entity.path)),
              onTap: () {
                // Only navigate if the entity is a file.
                if (entity is File) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              SecureFilePreviewPage(file: entity)));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Directories are not supported.")));
                }
              },
            );
          },
        ),
      ),
    );
  }
}